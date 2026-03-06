"""TPSM Pipeline - Dataset downloading and loading."""
import os
import io
import zipfile
import gzip
import requests
import pandas as pd
import warnings
import time


def _normalize_col_token(name: str) -> str:
    """Normalize column labels for tolerant matching across R/Python loaders."""
    s = str(name).strip()
    out = []
    prev_sep = False
    for ch in s:
        if ch.isalnum():
            out.append(ch.lower())
            prev_sep = False
        else:
            if not prev_sep:
                out.append(".")
                prev_sep = True
    return "".join(out).strip(".")


def _rename_columns_from_config(df: pd.DataFrame, ds_cfg: dict) -> pd.DataFrame:
    """Rename columns to configured identifiers when names differ only by punctuation."""
    rename_map = {}
    normalized_cols = {_normalize_col_token(c): c for c in df.columns}

    desired_names = []
    for key in ("target", "time_col", "rename_target_from"):
        val = ds_cfg.get(key)
        if val:
            desired_names.append(val)
    desired_names.extend(ds_cfg.get("exog_cols") or [])
    desired_names.extend(ds_cfg.get("exclude_cols") or [])

    for desired in desired_names:
        if desired in df.columns:
            continue
        actual = normalized_cols.get(_normalize_col_token(desired))
        if actual and actual not in rename_map and actual != desired:
            rename_map[actual] = desired

    if rename_map:
        ds_cfg["_column_match_diagnostics"] = {
            "renamed_columns": rename_map,
            "matched_by_normalized_name": True,
        }
        df = df.rename(columns=rename_map)
    else:
        ds_cfg["_column_match_diagnostics"] = {
            "renamed_columns": {},
            "matched_by_normalized_name": False,
        }
    return df


def download_with_retry(url: str, dest: str, max_retries: int = 3, timeout: int = 15):
    """Download a file with retry logic."""
    for attempt in range(1, max_retries + 1):
        try:
            resp = requests.get(url, timeout=timeout, stream=True)
            resp.raise_for_status()
            with open(dest, "wb") as f:
                for chunk in resp.iter_content(chunk_size=8192):
                    f.write(chunk)

            # Check if we got an HTML error page
            fsize = os.path.getsize(dest)
            if fsize > 100:
                with open(dest, "rb") as f:
                    head = f.read(200)
                if b"<!DOCTYPE" in head or b"<html" in head.lower():
                    raise ValueError("Downloaded HTML error page instead of data")
            return True
        except Exception as e:
            if attempt == max_retries:
                raise RuntimeError(f"Failed to download after {max_retries} retries: {e}")
            time.sleep(2 ** attempt)
    return False


def _load_from_zip(dest: str, ds_cfg: dict) -> pd.DataFrame:
    """Extract and read data from a ZIP archive."""
    with zipfile.ZipFile(dest) as zf:
        names = zf.namelist()
        if ds_cfg.get("zip_file"):
            target_name = ds_cfg["zip_file"]
        else:
            # Find first CSV or TXT file
            csv_files = [n for n in names if n.lower().endswith(".csv")]
            txt_files = [n for n in names if n.lower().endswith(".txt")]
            xlsx_files = [n for n in names if n.lower().endswith((".xlsx", ".xls"))]
            target_name = (csv_files or txt_files or xlsx_files or names)[0]

        with zf.open(target_name) as f:
            content = f.read()

        ext = target_name.rsplit(".", 1)[-1].lower()

        if ext in ("xlsx", "xls"):
            return pd.read_excel(io.BytesIO(content))
        else:
            sep = ds_cfg.get("separator") or ","
            if ext == "txt" and sep == ",":
                # Auto-detect for txt files
                first_line = content.split(b"\n")[0].decode("utf-8", errors="replace")
                if "\t" in first_line:
                    sep = "\t"
                elif ";" in first_line:
                    sep = ";"

            header_names = ds_cfg.get("header_names")
            read_kwargs = {
                "sep": sep,
                "na_values": ds_cfg.get("na_strings") or "NA",
                "decimal": ds_cfg.get("decimal") or ".",
            }
            if header_names:
                read_kwargs["header"] = None
                read_kwargs["names"] = header_names
            return pd.read_csv(io.BytesIO(content), **read_kwargs)


def load_dataset(ds_cfg: dict, data_dir: str = ".") -> pd.DataFrame:
    """Download (if needed) and load a dataset."""
    path = os.path.join(data_dir, ds_cfg["path"])
    os.makedirs(os.path.dirname(path), exist_ok=True)

    if not os.path.exists(path):
        url = ds_cfg.get("url")
        if not url:
            raise FileNotFoundError(f"Dataset file not found and no URL: {ds_cfg['id']}")

        # Determine download destination
        ext = url.rsplit(".", 1)[-1].lower().split("?")[0]
        if ext == "gz":
            dest = path + ".gz"
        elif ext == "zip":
            dest = path + ".zip"
        else:
            dest = path

        download_with_retry(url, dest)

        # Handle archives
        if dest.endswith(".zip"):
            df = _load_from_zip(dest, ds_cfg)
        elif dest.endswith(".gz"):
            with gzip.open(dest, "rt") as f:
                sep = ds_cfg.get("separator") or ","
                df = pd.read_csv(f, sep=sep, na_values=ds_cfg.get("na_strings") or "NA")
        elif url.lower().endswith((".xlsx", ".xls")):
            df = pd.read_excel(dest)
        else:
            # Direct download — might be .data, .dat, .txt with custom separator
            sep = ds_cfg.get("separator") or ","
            header_names = ds_cfg.get("header_names")
            read_kwargs = {
                "sep": sep,
                "na_values": ds_cfg.get("na_strings") or "NA",
                "decimal": ds_cfg.get("decimal") or ".",
            }
            if header_names:
                read_kwargs["header"] = None
                read_kwargs["names"] = header_names
            df = pd.read_csv(dest, **read_kwargs)

        # Clean junk columns before saving
        junk = [c for c in df.columns if str(c).startswith('Unnamed') or str(c).strip() == '']
        if junk:
            df = df.drop(columns=junk)

        # Save as standard comma-separated CSV
        df.to_csv(path, index=False)

    # Determine separator
    sep = ds_cfg.get("separator")
    with open(path) as f:
        first_line = f.readline()
    if sep and sep != ",":
        # Check if the on-disk file actually uses this separator
        # (files converted by to_csv() are always comma-separated)
        if sep not in first_line:
            sep = ","
    elif sep is None:
        sep = ";" if ";" in first_line else ","

    header_names = ds_cfg.get("header_names")
    na_vals = ds_cfg.get("na_strings") or "NA"
    decimal = ds_cfg.get("decimal") or "."

    read_kwargs = {"sep": sep, "na_values": na_vals, "decimal": decimal}
    if header_names:
        # Check if the file already has a header row matching our expected names
        # (happens when file was previously saved by to_csv() with headers)
        file_cols = [c.strip().strip('"').strip("'") for c in first_line.strip().split(sep)]
        expected = [c.strip() for c in header_names]
        if file_cols == expected:
            # File already has matching headers — read normally
            pass
        else:
            read_kwargs["header"] = None
            read_kwargs["names"] = header_names

    df = pd.read_csv(path, **read_kwargs)
    df = _rename_columns_from_config(df, ds_cfg)

    # Handle target rename
    rename_from = ds_cfg.get("rename_target_from")
    if rename_from:
        if rename_from in df.columns:
            df = df.rename(columns={rename_from: ds_cfg["target"]})
        # No need for make.names() — Python doesn't sanitize column names

    # Drop junk columns (Unnamed, empty headers from R's write.csv)
    junk_cols = [c for c in df.columns if str(c).startswith('Unnamed') or str(c).strip() == '']
    if junk_cols:
        df = df.drop(columns=junk_cols)

    # Exclude columns
    exclude = ds_cfg.get("exclude_cols") or []
    df = df.drop(columns=[c for c in exclude if c in df.columns], errors="ignore")

    # Limit rows
    max_rows = ds_cfg.get("max_rows")
    if max_rows and len(df) > max_rows:
        df = df.tail(max_rows).reset_index(drop=True)

    # Validate
    target = ds_cfg["target"]
    if target not in df.columns:
        raise ValueError(
            f"Target column '{target}' not found in '{ds_cfg['id']}'. "
            f"Columns: {list(df.columns)}"
        )

    ncols = len(df.columns)
    if ncols <= 1:
        raise ValueError(
            f"Dataset '{ds_cfg['id']}' has only {ncols} column(s) — likely wrong separator."
        )

    return df
