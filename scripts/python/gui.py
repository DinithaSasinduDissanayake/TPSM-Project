#!/usr/bin/env python3
"""Local web UI for resumable Python pipeline runs."""

from __future__ import annotations

import argparse
import html
import json
import os
import subprocess
import sys
import urllib.parse
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import yaml

project_root = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, project_root)

from scripts.python.run_state import load_json, utc_now


def parse_args():
    parser = argparse.ArgumentParser(description="TPSM Pipeline local GUI")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=8787)
    parser.add_argument("--output-root", default="outputs/gui_runs")
    return parser.parse_args()


def _is_pid_alive(pid: int | None) -> bool:
    if not pid:
        return False
    try:
        os.kill(pid, 0)
        return True
    except OSError:
        return False


def _load_raw_yaml(path: str) -> dict:
    with open(path, "r", encoding="utf-8") as f:
        return yaml.safe_load(f)


def _apply_task_filter(raw_cfg: dict, selected_tasks: set[str], dataset_ids: set[str]):
    for task_name in ["classification", "regression", "timeseries"]:
        if task_name not in raw_cfg:
            continue
        if selected_tasks and task_name not in selected_tasks:
            raw_cfg.pop(task_name, None)
            continue
        if dataset_ids:
            raw_cfg[task_name]["datasets"] = [
                ds for ds in raw_cfg[task_name].get("datasets", []) if ds["id"] in dataset_ids
            ]


def _dataset_catalog() -> dict[str, list[dict]]:
    base = _load_raw_yaml(os.path.join(project_root, "config", "datasets.yaml"))
    out = {}
    for task_name in ("classification", "regression", "timeseries"):
        block = base.get(task_name, {})
        out[task_name] = [
            {"id": ds["id"], "label": ds["id"].replace("_", " ")}
            for ds in block.get("datasets", [])
        ]
    return out


def _apply_numeric_overrides(raw_cfg: dict, folds: str, repeats: str, ts_splits: str):
    for task_name in ("classification", "regression"):
        if task_name in raw_cfg:
            if folds:
                raw_cfg[task_name]["folds"] = int(folds)
            if repeats:
                raw_cfg[task_name]["repeats"] = int(repeats)
    if "timeseries" in raw_cfg and ts_splits:
        raw_cfg["timeseries"]["splits"] = int(ts_splits)


def _build_config_from_form(form: dict[str, list[str]]) -> tuple[str, dict]:
    preset = form.get("preset", ["balanced"])[0]
    if preset == "quick":
        base_path = os.path.join(project_root, "config", "smoke_test.yaml")
    else:
        base_path = os.path.join(project_root, "config", "datasets.yaml")
    raw_cfg = _load_raw_yaml(base_path)

    if preset == "balanced":
        _apply_numeric_overrides(raw_cfg, "5", "2", "5")
    elif preset == "quick":
        pass

    selected_tasks = set(form.get("task"))
    dataset_ids = set(form.get("dataset", []))
    _apply_task_filter(raw_cfg, selected_tasks, dataset_ids)

    _apply_numeric_overrides(
        raw_cfg,
        form.get("folds", [""])[0].strip(),
        form.get("repeats", [""])[0].strip(),
        form.get("ts_splits", [""])[0].strip(),
    )

    timeout = form.get("timeout", ["300"])[0].strip() or "300"
    raw_cfg.setdefault("global", {})
    raw_cfg["global"]["timeout_seconds"] = int(timeout)
    raw_cfg["global"]["parallel_workers"] = 1
    return preset, raw_cfg


def _list_runs(output_root: str):
    runs = []
    if not os.path.exists(output_root):
        return runs
    for name in sorted(os.listdir(output_root), reverse=True):
        run_dir = os.path.join(output_root, name)
        state_path = os.path.join(run_dir, "state", "run_state.json")
        if not os.path.exists(state_path):
            continue
        state = load_json(state_path)
        runs.append(
            {
                "run_id": state["run_id"],
                "run_dir": run_dir,
                "status": state["status"],
                "progress": state.get("progress", {}),
                "updated_at_utc": state.get("updated_at_utc"),
                "runner_alive": _is_pid_alive(state.get("runner_pid")),
            }
        )
    return runs


def _find_active_run(output_root: str):
    active_statuses = {"running", "paused"}
    runs = _list_runs(output_root)
    for run in runs:
        if run["status"] in active_statuses:
            return run
    return None


def _current_dataset_summary(run_dir: str):
    state_path = os.path.join(run_dir, "state", "run_state.json")
    if not os.path.exists(state_path):
        return None
    state = load_json(state_path)
    current = state.get("current_unit_id")
    if current:
        return current
    datasets = state.get("datasets", {})
    pending = [d for d in datasets.values() if d["status"] in ("running", "paused", "pending")]
    pending.sort(key=lambda x: (x["status"] != "running", x["task_name"], x["dataset_id"]))
    if pending:
        d = pending[0]
        return f"{d['task_name']} / {d['dataset_id']} ({d['completed_units']}/{d['total_units']} splits)"
    return "-"


def _tail_log(run_dir: str, n: int = 40):
    path = os.path.join(run_dir, "run_log.txt")
    if not os.path.exists(path):
        return []
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()[-n:]
    out = []
    for line in lines:
        try:
            out.append(json.loads(line))
        except Exception:
            pass
    return out


def _spawn_runner(args, run_id: str, run_dir: str, snapshot_path: str, timeout: int, resume: bool = False):
    python_bin = sys.executable
    if resume:
        cmd = [python_bin, "-m", "scripts.python.main", "--resume-run", run_dir]
    else:
        cmd = [
            python_bin,
            "-m",
            "scripts.python.main",
            "--config",
            snapshot_path,
            "--output-dir",
            args.output_root,
            "--run-id",
            run_id,
            "--timeout",
            str(timeout),
        ]
    return subprocess.Popen(
        cmd,
        cwd=project_root,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        start_new_session=True,
    )


def render_index(output_root: str) -> str:
    runs = _list_runs(output_root)
    active_run = _find_active_run(output_root)
    history_runs = [run for run in runs if not active_run or run["run_id"] != active_run["run_id"]]
    table_rows = []
    for run in history_runs:
        pct = run["progress"].get("pct_complete", 0.0)
        alive = "yes" if run["runner_alive"] else "no"
        table_rows.append(
            f"<tr><td><a href='/runs/{html.escape(run['run_id'])}'>{html.escape(run['run_id'])}</a></td>"
            f"<td>{html.escape(run['status'])}</td>"
            f"<td><progress max='100' value='{pct:.2f}'></progress> {pct:.2f}%</td>"
            f"<td>{alive}</td>"
            f"<td>{html.escape(str(run['updated_at_utc']))}</td></tr>"
        )
    dataset_catalog = _dataset_catalog()
    dataset_sections = []
    for task_name, items in dataset_catalog.items():
        checks = "".join(
            f"<label class='ds-item'><input type='checkbox' name='dataset' value='{html.escape(item['id'])}' checked> {html.escape(item['label'])}</label>"
            for item in items
        )
        dataset_sections.append(
            f"<div class='dataset-group'><strong>{html.escape(task_name.title())}</strong>"
            f"<div class='dataset-grid'>{checks}</div></div>"
        )
    if active_run:
        pct = active_run["progress"].get("pct_complete", 0.0)
        active_html = f"""
<div class='hero card'>
<h2>Current Run</h2>
<p class='big'>{html.escape(active_run['status'].title())}</p>
<p><progress max='100' value='{pct:.2f}'></progress> <strong>{pct:.2f}%</strong></p>
<p>Current work: <code>{html.escape(_current_dataset_summary(active_run['run_dir']) or '-')}</code></p>
<p>Runner alive: {'yes' if active_run['runner_alive'] else 'no'}</p>
<p>Updated: {html.escape(str(active_run['updated_at_utc']))}</p>
<div class='actions'>
<a class='btn' href='/runs/{html.escape(active_run["run_id"])}'>Open Current Run</a>
<form method='post' action='/runs/{html.escape(active_run["run_id"])}/pause'><button type='submit'>Pause</button></form>
<form method='post' action='/runs/{html.escape(active_run["run_id"])}/resume'><button type='submit'>Resume</button></form>
<form method='post' action='/runs/{html.escape(active_run["run_id"])}/stop'><button type='submit'>Stop</button></form>
</div>
</div>
<div class='card muted'>
<h2>Start New Run</h2>
<p>A run is already active. Finish, pause, or stop it before starting another.</p>
</div>
"""
    else:
        active_html = f"""
<div class='card'>
<h2>Start New Run</h2>
<form method='post' action='/runs/start'>
<label>Preset</label>
<select name='preset'>
<option value='quick'>Quick Test</option>
<option value='balanced' selected>Balanced</option>
<option value='full'>Full Production</option>
</select>
<label>Tasks</label><br>
<label><input type='checkbox' name='task' value='classification' checked> Classification</label>
<label><input type='checkbox' name='task' value='regression' checked> Regression</label>
<label><input type='checkbox' name='task' value='timeseries' checked> Timeseries</label><br><br>
<details>
<summary>Advanced Settings</summary>
<label>Folds override</label><input type='number' name='folds' min='2' max='20'>
<label>Repeats override</label><input type='number' name='repeats' min='1' max='10'>
<label>Timeseries splits override</label><input type='number' name='ts_splits' min='1' max='20'>
<label>Timeout per dataset (sec)</label><input type='number' name='timeout' value='300' min='30'>
<div class='dataset-wrap'>
<h3>Datasets</h3>
<p class='muted-text'>All datasets are selected by default. Deselect any you do not want.</p>
{''.join(dataset_sections)}
</div>
</details>
<button class='primary' type='submit'>Start Run</button>
</form>
</div>
"""
    return f"""<!doctype html>
<html><head><meta charset='utf-8'><meta http-equiv='refresh' content='5'><title>TPSM Runner</title>
<style>
body{{font-family:sans-serif;max-width:1100px;margin:20px auto;padding:0 16px;background:#f6f6f4;color:#1d1d1b}}
table{{border-collapse:collapse;width:100%}}td,th{{border:1px solid #ccc;padding:6px;text-align:left}}
.row{{display:flex;gap:24px;align-items:flex-start;flex-wrap:wrap}}.card{{flex:1;border:1px solid #ccc;padding:16px;background:#fff;border-radius:10px}}
.hero{{width:100%}} .muted{{opacity:.7}}
input[type=text],input[type=number],select{{width:100%;padding:8px;margin:4px 0 10px;box-sizing:border-box}}
.actions form{{display:inline-block;margin-right:8px}} .actions .btn, button{{padding:8px 12px;border:1px solid #333;background:#fff;cursor:pointer;text-decoration:none;color:#111;border-radius:6px}}
button.primary{{background:#111;color:#fff}}
.dataset-grid{{display:grid;grid-template-columns:repeat(2,minmax(180px,1fr));gap:6px 16px;margin:8px 0 12px}}
.ds-item{{display:block}} .big{{font-size:1.5rem;font-weight:700}} .muted-text{{color:#666}} progress{{width:140px}}
</style></head><body>
<h1>TPSM Python Runner</h1>
<div class='row'>
{active_html}
<div class='card'>
<h2>Run History</h2>
<table><thead><tr><th>Run</th><th>Status</th><th>Progress</th><th>Alive</th><th>Updated</th></tr></thead>
<tbody>{''.join(table_rows) or '<tr><td colspan=5>No runs yet</td></tr>'}</tbody></table>
</div>
</div>
</body></html>"""


def render_run_detail(output_root: str, run_id: str) -> str:
    run_dir = os.path.join(output_root, run_id)
    state_path = os.path.join(run_dir, "state", "run_state.json")
    if not os.path.exists(state_path):
        return "<h1>Run not found</h1>"
    state = load_json(state_path)
    logs = _tail_log(run_dir, 60)
    current = state.get("current_unit_id") or "-"
    progress = state.get("progress", {})
    dataset_rows = []
    for ds in state.get("datasets", {}).values():
        pct = (ds["completed_units"] / ds["total_units"] * 100.0) if ds["total_units"] else 0.0
        dataset_rows.append(
            f"<tr><td>{html.escape(ds['task_name'])}</td><td>{html.escape(ds['dataset_id'])}</td>"
            f"<td>{html.escape(ds['status'])}</td><td>{ds['completed_units']}/{ds['total_units']}</td>"
            f"<td><progress max='100' value='{pct:.2f}'></progress> {pct:.2f}%</td></tr>"
        )
    log_html = "".join(
        f"<li><code>{html.escape(item.get('timestamp_utc',''))}</code> "
        f"<strong>{html.escape(item.get('event',''))}</strong> "
        f"{html.escape(json.dumps(item.get('data', {}), sort_keys=True))}</li>"
        for item in logs
    )
    return f"""<!doctype html>
<html><head><meta charset='utf-8'><meta http-equiv='refresh' content='5'><title>{html.escape(run_id)}</title>
<style>
body{{font-family:sans-serif;max-width:1200px;margin:20px auto;padding:0 16px}}
table{{border-collapse:collapse;width:100%}}td,th{{border:1px solid #ccc;padding:6px;text-align:left}}
.row{{display:flex;gap:24px;align-items:flex-start}}.card{{flex:1;border:1px solid #ccc;padding:16px}}
.actions form{{display:inline-block;margin-right:8px}}
</style></head><body>
<p><a href='/'>Back</a></p>
<h1>Run {html.escape(run_id)}</h1>
<div class='actions'>
<form method='post' action='/runs/{html.escape(run_id)}/pause'><button type='submit'>Pause After Split</button></form>
<form method='post' action='/runs/{html.escape(run_id)}/resume'><button type='submit'>Resume</button></form>
<form method='post' action='/runs/{html.escape(run_id)}/stop'><button type='submit'>Stop After Split</button></form>
</div>
<div class='row'>
<div class='card'>
<h2>Summary</h2>
<p>Status: <strong>{html.escape(state['status'])}</strong></p>
<p>Overall progress: <progress max='100' value='{progress.get('pct_complete', 0.0):.2f}'></progress> <strong>{progress.get('pct_complete', 0.0):.2f}%</strong></p>
<p>Completed units: {progress.get('completed_units', 0)}/{progress.get('total_units', 0)}</p>
<p>Completed datasets: {progress.get('completed_datasets', 0)}/{progress.get('total_datasets', 0)}</p>
<p>Current unit: <code>{html.escape(current)}</code></p>
<p>Runner alive: {'yes' if _is_pid_alive(state.get('runner_pid')) else 'no'}</p>
<p>Updated: {html.escape(str(state.get('updated_at_utc')))}</p>
</div>
<div class='card'>
<h2>Dataset Progress</h2>
<table><thead><tr><th>Task</th><th>Dataset</th><th>Status</th><th>Units</th><th>Progress</th></tr></thead>
<tbody>{''.join(dataset_rows)}</tbody></table>
</div>
</div>
<div class='card'>
<h2>Recent Events</h2>
<ul>{log_html}</ul>
</div>
</body></html>"""


class Handler(BaseHTTPRequestHandler):
    args = None

    def _send_html(self, body: str, code: int = 200):
        payload = body.encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "text/html; charset=utf-8")
        self.send_header("Content-Length", str(len(payload)))
        self.end_headers()
        self.wfile.write(payload)

    def _send_json(self, payload: dict, code: int = 200):
        body = json.dumps(payload, indent=2).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _redirect(self, location: str, code: int = 303):
        self.send_response(code)
        self.send_header("Location", location)
        self.end_headers()

    def _parse_form(self):
        length = int(self.headers.get("Content-Length", "0"))
        raw = self.rfile.read(length).decode("utf-8")
        return urllib.parse.parse_qs(raw)

    def do_GET(self):
        if self.path == "/":
            return self._send_html(render_index(self.args.output_root))
        if self.path.startswith("/runs/"):
            run_id = self.path.split("/runs/", 1)[1]
            return self._send_html(render_run_detail(self.args.output_root, run_id))
        if self.path == "/api/runs":
            return self._send_json({"runs": _list_runs(self.args.output_root), "timestamp_utc": utc_now()})
        if self.path.startswith("/api/runs/"):
            run_id = self.path.split("/api/runs/", 1)[1]
            run_dir = os.path.join(self.args.output_root, run_id)
            state_path = os.path.join(run_dir, "state", "run_state.json")
            if not os.path.exists(state_path):
                return self._send_json({"error": "not_found"}, 404)
            return self._send_json({"state": load_json(state_path), "logs": _tail_log(run_dir, 60)})
        return self._send_json({"error": "not_found"}, 404)

    def do_POST(self):
        if self.path == "/runs/start":
            active_run = _find_active_run(self.args.output_root)
            if active_run:
                return self._redirect(f"/runs/{active_run['run_id']}")
            form = self._parse_form()
            preset, raw_cfg = _build_config_from_form(form)
            run_id = _safe_run_id()
            run_dir = os.path.join(self.args.output_root, run_id)
            os.makedirs(run_dir, exist_ok=True)
            snapshot_path = os.path.join(run_dir, "config_snapshot.yaml")
            with open(snapshot_path, "w", encoding="utf-8") as f:
                yaml.safe_dump(raw_cfg, f, sort_keys=False)
            timeout = int(raw_cfg.get("global", {}).get("timeout_seconds", 300))
            _spawn_runner(self.args, run_id, run_dir, snapshot_path, timeout, resume=False)
            return self._redirect(f"/runs/{run_id}")

        if self.path.startswith("/runs/"):
            rest = self.path.split("/runs/", 1)[1]
            parts = rest.split("/")
            if len(parts) != 2:
                return self._send_json({"error": "bad_request"}, 400)
            run_id, action = parts
            run_dir = os.path.join(self.args.output_root, run_id)
            if not os.path.exists(run_dir):
                return self._send_json({"error": "not_found"}, 404)
            pause_path = os.path.join(run_dir, "PAUSE")
            stop_path = os.path.join(run_dir, "STOP")
            state_path = os.path.join(run_dir, "state", "run_state.json")
            state = load_json(state_path) if os.path.exists(state_path) else {}

            if action == "pause":
                open(pause_path, "a", encoding="utf-8").close()
                return self._redirect(f"/runs/{run_id}")
            if action == "stop":
                open(stop_path, "a", encoding="utf-8").close()
                return self._redirect(f"/runs/{run_id}")
            if action == "resume":
                if os.path.exists(pause_path):
                    os.remove(pause_path)
                if os.path.exists(stop_path):
                    os.remove(stop_path)
                if not _is_pid_alive(state.get("runner_pid")):
                    _spawn_runner(self.args, run_id, run_dir, "", 300, resume=True)
                return self._redirect(f"/runs/{run_id}")

        if self.path == "/api/runs/start":
            form = self._parse_form()
            preset, raw_cfg = _build_config_from_form(form)
            run_id = _safe_run_id()
            run_dir = os.path.join(self.args.output_root, run_id)
            os.makedirs(run_dir, exist_ok=True)
            snapshot_path = os.path.join(run_dir, "config_snapshot.yaml")
            with open(snapshot_path, "w", encoding="utf-8") as f:
                yaml.safe_dump(raw_cfg, f, sort_keys=False)
            timeout = int(raw_cfg.get("global", {}).get("timeout_seconds", 300))
            proc = _spawn_runner(self.args, run_id, run_dir, snapshot_path, timeout, resume=False)
            return self._send_json(
                {
                    "ok": True,
                    "run_id": run_id,
                    "preset": preset,
                    "pid": proc.pid,
                    "run_dir": run_dir,
                },
                201,
            )

        if self.path.startswith("/api/runs/"):
            rest = self.path.split("/api/runs/", 1)[1]
            parts = rest.split("/")
            if len(parts) != 2:
                return self._send_json({"error": "bad_request"}, 400)
            run_id, action = parts
            run_dir = os.path.join(self.args.output_root, run_id)
            if not os.path.exists(run_dir):
                return self._send_json({"error": "not_found"}, 404)
            pause_path = os.path.join(run_dir, "PAUSE")
            stop_path = os.path.join(run_dir, "STOP")
            state_path = os.path.join(run_dir, "state", "run_state.json")
            state = load_json(state_path) if os.path.exists(state_path) else {}

            if action == "pause":
                open(pause_path, "a", encoding="utf-8").close()
                return self._send_json({"ok": True, "status": "pause_requested"})
            if action == "stop":
                open(stop_path, "a", encoding="utf-8").close()
                return self._send_json({"ok": True, "status": "stop_requested"})
            if action == "resume":
                if os.path.exists(pause_path):
                    os.remove(pause_path)
                if os.path.exists(stop_path):
                    os.remove(stop_path)
                if not _is_pid_alive(state.get("runner_pid")):
                    proc = _spawn_runner(self.args, run_id, run_dir, "", 300, resume=True)
                    return self._send_json({"ok": True, "status": "resumed", "pid": proc.pid})
                return self._send_json({"ok": True, "status": "already_running"})
        return self._send_json({"error": "bad_request"}, 400)


def _safe_run_id():
    import datetime

    return datetime.datetime.now().strftime("%Y%m%dT%H%M%S")


def main():
    args = parse_args()
    os.makedirs(args.output_root, exist_ok=True)
    Handler.args = args
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    print(f"GUI running at http://{args.host}:{args.port}")
    print(f"Output root: {args.output_root}")
    server.serve_forever()


if __name__ == "__main__":
    main()
