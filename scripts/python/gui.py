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

project_root = os.path.dirname(
    os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
)
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
                ds
                for ds in raw_cfg[task_name].get("datasets", [])
                if ds["id"] in dataset_ids
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
    pending = [
        d for d in datasets.values() if d["status"] in ("running", "paused", "pending")
    ]
    pending.sort(
        key=lambda x: (x["status"] != "running", x["task_name"], x["dataset_id"])
    )
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


def _spawn_runner(
    args,
    run_id: str,
    run_dir: str,
    snapshot_path: str,
    timeout: int,
    resume: bool = False,
):
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


_SHARED_CSS = """
* { box-sizing: border-box; margin: 0; padding: 0; }
:root {
  --bg: #060b14;
  --surface: #0d1526;
  --card: #111d35;
  --card2: #0e1a30;
  --border: #1e3358;
  --border2: #243d6a;
  --text: #cdd9f0;
  --text-muted: #5d7aab;
  --text-dim: #3a5080;
  --accent: #3b82f6;
  --accent2: #60a5fa;
  --accent-glow: rgba(59,130,246,0.25);
  --purple: #a78bfa;
  --green: #34d399;
  --yellow: #fbbf24;
  --red: #f87171;
  --red2: #ef4444;
  --cyan: #22d3ee;
}
html, body { height: 100%; }
body {
  font-family: 'Inter', ui-sans-serif, system-ui, -apple-system, sans-serif;
  background: var(--bg);
  color: var(--text);
  line-height: 1.55;
  font-size: 14px;
}
a { color: var(--accent2); text-decoration: none; }
a:hover { color: #93c5fd; text-decoration: underline; }
code {
  font-family: 'JetBrains Mono', 'Fira Code', ui-monospace, monospace;
  background: rgba(59,130,246,0.08);
  color: var(--cyan);
  padding: 2px 7px;
  border-radius: 5px;
  font-size: 0.8rem;
  word-break: break-all;
}

/* ── NAV ── */
.nav {
  display: flex; align-items: center; gap: 16px;
  padding: 0 24px; height: 56px;
  background: var(--surface);
  border-bottom: 1px solid var(--border);
  position: sticky; top: 0; z-index: 100;
}
.nav-logo {
  display: flex; align-items: center; gap: 10px;
  font-weight: 700; font-size: 1rem; letter-spacing: -0.02em;
  color: var(--text);
}
.nav-logo .logo-icon {
  width: 30px; height: 30px;
  background: linear-gradient(135deg, var(--accent), var(--purple));
  border-radius: 8px;
  display: flex; align-items: center; justify-content: center;
  font-size: 14px;
}
.nav-pill {
  font-size: 0.7rem; font-weight: 600; padding: 2px 8px;
  background: rgba(59,130,246,0.15); color: var(--accent2);
  border-radius: 20px; border: 1px solid rgba(59,130,246,0.3);
}
.nav-spacer { flex: 1; }
.nav-refresh {
  font-size: 0.75rem; color: var(--text-muted);
  display: flex; align-items: center; gap: 6px;
}
.pulse { width: 7px; height: 7px; border-radius: 50%; background: var(--green); animation: pulse 2s infinite; }
@keyframes pulse { 0%,100% { opacity: 1; } 50% { opacity: 0.3; } }

/* ── LAYOUT ── */
.page { max-width: 1280px; margin: 0 auto; padding: 28px 24px; }
.grid2 { display: grid; grid-template-columns: 400px 1fr; gap: 20px; align-items: start; }
@media (max-width: 900px) { .grid2 { grid-template-columns: 1fr; } }
.full-width { grid-column: 1 / -1; }

/* ── CARDS ── */
.card {
  background: var(--card);
  border: 1px solid var(--border);
  border-radius: 14px;
  padding: 20px 22px;
  box-shadow: 0 2px 20px rgba(0,0,0,0.4);
}
.card-header {
  display: flex; align-items: center; justify-content: space-between;
  margin-bottom: 18px; padding-bottom: 14px;
  border-bottom: 1px solid var(--border);
}
.card-title {
  font-size: 0.8rem; font-weight: 600; letter-spacing: 0.08em;
  text-transform: uppercase; color: var(--text-muted);
  display: flex; align-items: center; gap: 8px;
}
.card-title svg { width: 15px; height: 15px; opacity: 0.7; }

/* ── ACTIVE RUN HERO ── */
.hero-card {
  background: linear-gradient(135deg, #0c1f3d 0%, #111d35 60%, #0a1628 100%);
  border: 1px solid var(--border2);
  border-radius: 14px; padding: 24px;
  position: relative; overflow: hidden;
}
.hero-card::before {
  content: ''; position: absolute; top: -40px; right: -40px;
  width: 160px; height: 160px;
  background: radial-gradient(circle, rgba(59,130,246,0.15) 0%, transparent 70%);
  pointer-events: none;
}
.hero-status { display: flex; align-items: center; gap: 14px; margin-bottom: 18px; }
.hero-run-id { font-size: 1.1rem; font-weight: 700; color: var(--text); }
.hero-meta { font-size: 0.78rem; color: var(--text-muted); margin-top: 2px; }
.hero-progress-label {
  display: flex; justify-content: space-between; align-items: center;
  margin-bottom: 8px;
}
.hero-pct { font-size: 1.6rem; font-weight: 800; color: var(--accent2); letter-spacing: -0.03em; }
.hero-pct-label { font-size: 0.75rem; color: var(--text-muted); }
.progress-bar-wrap { position: relative; height: 10px; border-radius: 10px; background: var(--border); overflow: hidden; }
.progress-bar-fill {
  height: 100%; border-radius: 10px;
  background: linear-gradient(90deg, var(--accent) 0%, var(--purple) 100%);
  box-shadow: 0 0 12px rgba(59,130,246,0.5);
  transition: width 0.5s ease;
}
.hero-detail { margin-top: 16px; font-size: 0.8rem; color: var(--text-muted); }
.hero-detail code { font-size: 0.75rem; }

/* ── BUTTONS ── */
.btn-row { display: flex; gap: 8px; flex-wrap: wrap; margin-top: 16px; }
.btn {
  padding: 8px 16px; border-radius: 8px; font-size: 0.8rem; font-weight: 600;
  cursor: pointer; border: none; text-decoration: none; display: inline-flex;
  align-items: center; gap: 6px; transition: all 0.15s ease; white-space: nowrap;
}
.btn-primary { background: var(--accent); color: #fff; }
.btn-primary:hover { background: #2563eb; transform: translateY(-1px); box-shadow: 0 4px 12px var(--accent-glow); }
.btn-ghost { background: transparent; color: var(--text-muted); border: 1px solid var(--border2); }
.btn-ghost:hover { background: rgba(255,255,255,0.04); color: var(--text); border-color: var(--accent); }
.btn-danger { background: rgba(239,68,68,0.15); color: var(--red); border: 1px solid rgba(239,68,68,0.3); }
.btn-danger:hover { background: rgba(239,68,68,0.25); transform: translateY(-1px); }
.btn-success { background: rgba(52,211,153,0.15); color: var(--green); border: 1px solid rgba(52,211,153,0.3); }
.btn-success:hover { background: rgba(52,211,153,0.25); }
.btn-big {
  padding: 12px 28px; font-size: 0.9rem; border-radius: 10px;
  background: linear-gradient(135deg, var(--accent), #1d4ed8);
  color: #fff; border: none; cursor: pointer; font-weight: 700;
  width: 100%; margin-top: 20px; letter-spacing: 0.02em;
  transition: all 0.2s; box-shadow: 0 4px 20px var(--accent-glow);
}
.btn-big:hover { transform: translateY(-2px); box-shadow: 0 8px 30px var(--accent-glow); }
button { font-family: inherit; }

/* ── BADGES ── */
.badge {
  display: inline-flex; align-items: center; gap: 5px;
  padding: 3px 10px; border-radius: 20px;
  font-size: 0.7rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.06em;
}
.badge::before { content: ''; width: 5px; height: 5px; border-radius: 50%; flex-shrink: 0; }
.badge-running { background: rgba(59,130,246,0.15); color: #60a5fa; border: 1px solid rgba(59,130,246,0.3); }
.badge-running::before { background: #60a5fa; box-shadow: 0 0 6px #60a5fa; animation: pulse 1.5s infinite; }
.badge-completed { background: rgba(52,211,153,0.12); color: var(--green); border: 1px solid rgba(52,211,153,0.25); }
.badge-completed::before { background: var(--green); }
.badge-stopped { background: rgba(248,113,113,0.12); color: var(--red); border: 1px solid rgba(248,113,113,0.25); }
.badge-stopped::before { background: var(--red); }
.badge-paused { background: rgba(251,191,36,0.12); color: var(--yellow); border: 1px solid rgba(251,191,36,0.25); }
.badge-paused::before { background: var(--yellow); }
.badge-failed { background: rgba(239,68,68,0.15); color: var(--red); border: 1px solid rgba(239,68,68,0.3); }
.badge-failed::before { background: var(--red); }
.badge-pending { background: rgba(93,122,171,0.12); color: var(--text-muted); border: 1px solid rgba(93,122,171,0.2); }
.badge-pending::before { background: var(--text-muted); }
.badge-alive { background: rgba(52,211,153,0.12); color: var(--green); border: 1px solid rgba(52,211,153,0.25); }
.badge-alive::before { background: var(--green); box-shadow: 0 0 6px var(--green); animation: pulse 2s infinite; }
.badge-dead { background: rgba(93,122,171,0.1); color: var(--text-dim); border: 1px solid rgba(93,122,171,0.15); }
.badge-dead::before { background: var(--text-dim); }

/* ── FORM ── */
.form-group { margin-bottom: 16px; }
.form-label { display: block; font-size: 0.75rem; font-weight: 600; color: var(--text-muted); text-transform: uppercase; letter-spacing: 0.06em; margin-bottom: 6px; }
select, input[type=number], input[type=text] {
  width: 100%; padding: 10px 12px;
  background: var(--surface); border: 1px solid var(--border2);
  color: var(--text); border-radius: 8px; font-size: 0.875rem;
  font-family: inherit; transition: border-color 0.15s, box-shadow 0.15s;
  appearance: none; -webkit-appearance: none;
}
select { background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='12' height='8' viewBox='0 0 12 8'%3E%3Cpath d='M1 1l5 5 5-5' stroke='%235d7aab' stroke-width='1.5' fill='none' stroke-linecap='round'/%3E%3C/svg%3E"); background-repeat: no-repeat; background-position: right 12px center; padding-right: 36px; }
select:focus, input:focus { outline: none; border-color: var(--accent); box-shadow: 0 0 0 3px var(--accent-glow); }
.task-checks { display: flex; gap: 0; border: 1px solid var(--border2); border-radius: 10px; overflow: hidden; margin-top: 6px; }
.task-check { flex: 1; position: relative; }
.task-check input { position: absolute; opacity: 0; width: 0; height: 0; }
.task-check label {
  display: flex; flex-direction: column; align-items: center; justify-content: center;
  padding: 10px 8px; cursor: pointer; font-size: 0.75rem; font-weight: 600;
  color: var(--text-muted); background: var(--surface); transition: all 0.15s;
  border-right: 1px solid var(--border2); gap: 4px;
}
.task-check:last-child label { border-right: none; }
.task-check label .task-icon { font-size: 1.1rem; }
.task-check input:checked + label { background: rgba(59,130,246,0.15); color: var(--accent2); }
.task-check input:checked + label .task-icon { filter: drop-shadow(0 0 4px var(--accent)); }
.adv-details {
  margin-top: 14px; border: 1px solid var(--border); border-radius: 10px; overflow: hidden;
}
.adv-summary {
  padding: 11px 14px; cursor: pointer; font-size: 0.8rem; font-weight: 600;
  color: var(--text-muted); list-style: none; display: flex; align-items: center; gap: 8px;
  background: rgba(255,255,255,0.02); user-select: none;
}
.adv-summary::before { content: '▶'; font-size: 0.6rem; transition: transform 0.2s; }
details[open] .adv-summary::before { transform: rotate(90deg); }
.adv-body { padding: 14px; display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.ds-section { margin-top: 16px; }
.ds-group { margin-bottom: 14px; }
.ds-group-title { font-size: 0.7rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.08em; color: var(--text-muted); margin-bottom: 8px; padding: 0 2px; }
.ds-grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(160px, 1fr)); gap: 6px; }
.ds-item { position: relative; }
.ds-item input { position: absolute; opacity: 0; width: 0; height: 0; }
.ds-item label {
  display: flex; align-items: center; gap: 7px; padding: 6px 10px;
  background: rgba(255,255,255,0.025); border: 1px solid var(--border);
  border-radius: 6px; cursor: pointer; font-size: 0.75rem; color: var(--text-muted);
  transition: all 0.15s;
}
.ds-item label::before { content: ''; width: 8px; height: 8px; border-radius: 2px; border: 1px solid var(--border2); flex-shrink: 0; transition: all 0.15s; }
.ds-item input:checked + label { border-color: rgba(59,130,246,0.4); background: rgba(59,130,246,0.07); color: var(--text); }
.ds-item input:checked + label::before { background: var(--accent); border-color: var(--accent); box-shadow: 0 0 6px var(--accent-glow); }
.ds-item label:hover { border-color: var(--border2); background: rgba(255,255,255,0.04); }

/* ── TABLE ── */
.table-wrap { overflow-x: auto; border-radius: 10px; border: 1px solid var(--border); }
table { border-collapse: collapse; width: 100%; }
thead tr { background: rgba(255,255,255,0.025); }
th {
  padding: 11px 14px; text-align: left; font-size: 0.7rem; font-weight: 700;
  text-transform: uppercase; letter-spacing: 0.07em; color: var(--text-muted);
  border-bottom: 1px solid var(--border); white-space: nowrap;
}
td { padding: 12px 14px; font-size: 0.82rem; border-bottom: 1px solid var(--border); vertical-align: middle; }
tbody tr:last-child td { border-bottom: none; }
tbody tr:hover { background: rgba(59,130,246,0.04); }
.run-id-cell { font-family: 'JetBrains Mono', monospace; font-size: 0.75rem; }
.empty-row td { text-align: center; padding: 32px; color: var(--text-dim); font-size: 0.85rem; }

/* ── INLINE PROGRESS ── */
.tbl-progress { display: flex; align-items: center; gap: 10px; min-width: 140px; }
.tbl-progress-bar { flex: 1; height: 5px; border-radius: 5px; background: var(--border); overflow: hidden; }
.tbl-progress-fill { height: 100%; border-radius: 5px; background: linear-gradient(90deg, var(--accent), var(--purple)); }
.tbl-pct { font-size: 0.75rem; color: var(--text-muted); min-width: 36px; text-align: right; }

/* ── DISABLED CARD ── */
.card-disabled { opacity: 0.45; pointer-events: none; }
.card-disabled .card-title { color: var(--text-dim); }
"""


def render_index(output_root: str) -> str:
    runs = _list_runs(output_root)
    active_run = _find_active_run(output_root)
    history_runs = [
        run for run in runs if not active_run or run["run_id"] != active_run["run_id"]
    ]
    table_rows = []
    for run in history_runs:
        pct = run["progress"].get("pct_complete", 0.0)
        status = run["status"]
        alive_cls = "badge-alive" if run["runner_alive"] else "badge-dead"
        alive_lbl = "alive" if run["runner_alive"] else "dead"
        bar_w = f"{pct:.1f}%"
        updated = html.escape(str(run["updated_at_utc"]))
        table_rows.append(
            f"<tr>"
            f"<td class='run-id-cell'><a href='/runs/{html.escape(run['run_id'])}'>{html.escape(run['run_id'])}</a></td>"
            f"<td><span class='badge badge-{html.escape(status)}'>{html.escape(status)}</span></td>"
            f"<td><div class='tbl-progress'><div class='tbl-progress-bar'><div class='tbl-progress-fill' style='width:{bar_w}'></div></div><span class='tbl-pct'>{pct:.1f}%</span></div></td>"
            f"<td><span class='badge {alive_cls}'>{alive_lbl}</span></td>"
            f"<td style='color:var(--text-muted);font-size:0.78rem'>{updated}</td>"
            f"</tr>"
        )
    dataset_catalog = _dataset_catalog()
    dataset_sections = []
    for task_name, items in dataset_catalog.items():
        check_parts = []
        for item in items:
            iid = html.escape(item["id"])
            ilabel = html.escape(item["label"])
            check_parts.append(
                f"<div class='ds-item'>"
                f"<input type='checkbox' name='dataset' id='ds_{iid}' value='{iid}' checked>"
                f"<label for='ds_{iid}'>{ilabel}</label>"
                f"</div>"
            )
        checks = "".join(check_parts)
        dataset_sections.append(
            f"<div class='ds-group'><div class='ds-group-title'>{html.escape(task_name.title())}</div>"
            f"<div class='ds-grid'>{checks}</div></div>"
        )
    if active_run:
        pct = active_run["progress"].get("pct_complete", 0.0)
        status = active_run["status"]
        bar_w = f"{pct:.1f}%"
        alive_cls = "badge-alive" if active_run["runner_alive"] else "badge-dead"
        alive_lbl = "alive" if active_run["runner_alive"] else "dead"
        active_panel = f"""
<div class="hero-card full-width">
  <div class="hero-status">
    <div>
      <div class="hero-run-id">{html.escape(active_run["run_id"])}</div>
      <div class="hero-meta">Active Run &nbsp;&bull;&nbsp; Updated {html.escape(str(active_run["updated_at_utc"]))}</div>
    </div>
    <div style="margin-left:auto;display:flex;align-items:center;gap:10px">
      <span class='badge {alive_cls}'>{alive_lbl}</span>
      <span class='badge badge-{html.escape(status)}'>{html.escape(status)}</span>
    </div>
  </div>
  <div class="hero-progress-label">
    <div>
      <div class="hero-pct">{pct:.1f}<span style="font-size:1rem;font-weight:400;color:var(--text-muted)">%</span></div>
      <div class="hero-pct-label">Overall Progress</div>
    </div>
  </div>
  <div class="progress-bar-wrap">
    <div class="progress-bar-fill" style="width:{bar_w}"></div>
  </div>
  <div class="hero-detail">Current work: <code>{html.escape(_current_dataset_summary(active_run["run_dir"]) or "-")}</code></div>
  <div class="btn-row">
    <a class="btn btn-ghost" href="/runs/{html.escape(active_run["run_id"])}">&#128269; Open Run</a>
    <form method="post" action="/runs/{html.escape(active_run["run_id"])}/pause" style="display:inline">
      <button class="btn btn-ghost" type="submit">&#9646;&#9646; Pause</button>
    </form>
    <form method="post" action="/runs/{html.escape(active_run["run_id"])}/resume" style="display:inline">
      <button class="btn btn-success" type="submit">&#9654; Resume</button>
    </form>
    <form method="post" action="/runs/{html.escape(active_run["run_id"])}/stop" style="display:inline">
      <button class="btn btn-danger" type="submit">&#9632; Stop</button>
    </form>
  </div>
</div>
<div class="card card-disabled">
  <div class="card-header">
    <div class="card-title">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>
      New Run
    </div>
  </div>
  <p style="font-size:0.85rem;color:var(--text-muted)">A run is already active. Stop or wait for it to finish before starting another.</p>
</div>"""
        new_run_col = ""
    else:
        active_panel = ""
        new_run_col = f"""
<div class="card">
  <div class="card-header">
    <div class="card-title">
      <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polygon points="5 3 19 12 5 21 5 3"/></svg>
      New Run
    </div>
  </div>
  <form method="post" action="/runs/start">
    <div class="form-group">
      <div class="form-label">Preset</div>
      <select name="preset">
        <option value="quick">Quick Smoke Test</option>
        <option value="balanced" selected>Balanced (5 folds &times; 2 repeats)</option>
        <option value="full">Full Production</option>
      </select>
    </div>
    <div class="form-group">
      <div class="form-label">Task Types</div>
      <div class="task-checks">
        <div class="task-check">
          <input type="checkbox" name="task" id="t_cls" value="classification" checked>
          <label for="t_cls"><span class="task-icon">&#128202;</span>Classification</label>
        </div>
        <div class="task-check">
          <input type="checkbox" name="task" id="t_reg" value="regression" checked>
          <label for="t_reg"><span class="task-icon">&#128200;</span>Regression</label>
        </div>
        <div class="task-check">
          <input type="checkbox" name="task" id="t_ts" value="timeseries" checked>
          <label for="t_ts"><span class="task-icon">&#128336;</span>Timeseries</label>
        </div>
      </div>
    </div>
    <details class="adv-details">
      <summary class="adv-summary">Advanced Settings</summary>
      <div class="adv-body">
        <div class="form-group" style="margin:0">
          <div class="form-label">Folds Override</div>
          <input type="number" name="folds" min="2" max="20" placeholder="default">
        </div>
        <div class="form-group" style="margin:0">
          <div class="form-label">Repeats Override</div>
          <input type="number" name="repeats" min="1" max="10" placeholder="default">
        </div>
        <div class="form-group" style="margin:0">
          <div class="form-label">TS Splits Override</div>
          <input type="number" name="ts_splits" min="1" max="20" placeholder="default">
        </div>
        <div class="form-group" style="margin:0">
          <div class="form-label">Timeout / Dataset (s)</div>
          <input type="number" name="timeout" value="300" min="30">
        </div>
      </div>
      <div class="ds-section" style="padding:0 14px 14px">
        <div class="form-label" style="margin-bottom:10px">Datasets</div>
        {"".join(dataset_sections)}
      </div>
    </details>
    <button class="btn-big" type="submit">&#9654;&nbsp; Launch Run</button>
  </form>
</div>"""
    history_body = (
        "".join(table_rows)
        or f"<tr class='empty-row'><td colspan='5'>No runs yet &mdash; launch your first run above</td></tr>"
    )
    total_runs = len(runs)
    running_count = sum(1 for r in runs if r["status"] == "running")
    done_count = sum(1 for r in runs if r["status"] == "completed")
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta http-equiv="refresh" content="5">
  <title>TPSM Runner</title>
  <style>{_SHARED_CSS}
  .stat-strip {{ display:flex; gap:12px; margin-bottom:20px; flex-wrap:wrap; }}
  .stat-box {{ flex:1; min-width:100px; background:var(--card); border:1px solid var(--border); border-radius:10px; padding:14px 16px; }}
  .stat-val {{ font-size:1.6rem; font-weight:800; letter-spacing:-0.03em; color:var(--text); line-height:1; }}
  .stat-lbl {{ font-size:0.7rem; font-weight:600; text-transform:uppercase; letter-spacing:0.07em; color:var(--text-muted); margin-top:4px; }}
  </style>
</head>
<body>
<nav class="nav">
  <div class="nav-logo">
    <div class="logo-icon">&#9889;</div>
    TPSM Runner
  </div>
  <span class="nav-pill">Python</span>
  <div class="nav-spacer"></div>
  <div class="nav-refresh"><div class="pulse"></div>Auto-refresh 5s</div>
</nav>
<div class="page">
  <div class="stat-strip">
    <div class="stat-box"><div class="stat-val">{total_runs}</div><div class="stat-lbl">Total Runs</div></div>
    <div class="stat-box"><div class="stat-val" style="color:var(--accent2)">{running_count}</div><div class="stat-lbl">Running</div></div>
    <div class="stat-box"><div class="stat-val" style="color:var(--green)">{done_count}</div><div class="stat-lbl">Completed</div></div>
    <div class="stat-box"><div class="stat-val" style="color:var(--yellow)">{len(runs) - running_count - done_count}</div><div class="stat-lbl">Other</div></div>
  </div>
  <div class="grid2">
    {active_panel}
    {new_run_col}
    <div class="card" style="grid-column: {"2" if not active_panel else "1"} / -1">
      <div class="card-header">
        <div class="card-title">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M12 20h9"/><path d="M16.5 3.5a2.121 2.121 0 013 3L7 19l-4 1 1-4L16.5 3.5z"/></svg>
          Run History
        </div>
        <span style="font-size:0.75rem;color:var(--text-muted)">{len(history_runs)} record{"s" if len(history_runs) != 1 else ""}</span>
      </div>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Run ID</th><th>Status</th><th>Progress</th><th>Runner</th><th>Last Updated</th></tr></thead>
          <tbody>{history_body}</tbody>
        </table>
      </div>
    </div>
  </div>
</div>
</body>
</html>"""


def render_run_detail(output_root: str, run_id: str) -> str:
    run_dir = os.path.join(output_root, run_id)
    state_path = os.path.join(run_dir, "state", "run_state.json")
    if not os.path.exists(state_path):
        return "<h1>Run not found</h1>"
    state = load_json(state_path)
    logs = _tail_log(run_dir, 60)
    current = state.get("current_unit_id") or "-"
    progress = state.get("progress", {})
    pct_complete = progress.get("pct_complete", 0.0)
    bar_w = f"{pct_complete:.1f}%"
    run_status = state["status"]
    alive = _is_pid_alive(state.get("runner_pid"))
    alive_cls = "badge-alive" if alive else "badge-dead"
    alive_lbl = "alive" if alive else "dead"

    dataset_rows = []
    for ds in state.get("datasets", {}).values():
        pct = (
            (ds["completed_units"] / ds["total_units"] * 100.0)
            if ds["total_units"]
            else 0.0
        )
        ds_status = ds["status"]
        ds_bar_w = f"{pct:.1f}%"
        dataset_rows.append(
            f"<tr>"
            f"<td><span style='font-size:0.75rem;color:var(--text-muted)'>{html.escape(ds['task_name'])}</span></td>"
            f"<td style='font-family:monospace;font-size:0.78rem'>{html.escape(ds['dataset_id'])}</td>"
            f"<td><span class='badge badge-{html.escape(ds_status)}'>{html.escape(ds_status)}</span></td>"
            f"<td style='color:var(--text-muted);font-size:0.8rem'>{ds['completed_units']}/{ds['total_units']}</td>"
            f"<td><div class='tbl-progress'><div class='tbl-progress-bar'><div class='tbl-progress-fill' style='width:{ds_bar_w}'></div></div><span class='tbl-pct'>{pct:.1f}%</span></div></td>"
            f"</tr>"
        )

    log_entries = []
    for item in logs:
        ts = html.escape(item.get("timestamp_utc", ""))
        ev = html.escape(item.get("event", ""))
        lvl = item.get("level", "info")
        data_str = html.escape(json.dumps(item.get("data", {}), sort_keys=True))
        color = {
            "error": "var(--red)",
            "warning": "var(--yellow)",
            "debug": "var(--text-dim)",
        }.get(lvl, "var(--text-muted)")
        ev_color = {"error": "var(--red)", "warning": "var(--yellow)"}.get(
            lvl, "var(--cyan)"
        )
        log_entries.append(
            f"<div class='log-entry'>"
            f"<span class='log-ts'>{ts}</span>"
            f"<span class='log-ev' style='color:{ev_color}'>{ev}</span>"
            f"<span class='log-data' style='color:{color}'>{data_str}</span>"
            f"</div>"
        )
    log_html = (
        "".join(log_entries)
        or "<div class='log-entry' style='color:var(--text-dim)'>No events yet</div>"
    )

    rid = html.escape(run_id)
    return f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width,initial-scale=1">
  <meta http-equiv="refresh" content="5">
  <title>{rid} &mdash; TPSM</title>
  <style>{_SHARED_CSS}
  .kv-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; margin-top: 4px; }}
  .kv {{ background: rgba(0,0,0,0.25); border: 1px solid var(--border); border-radius: 10px; padding: 14px 16px; }}
  .kv-label {{ font-size: 0.68rem; font-weight: 700; text-transform: uppercase; letter-spacing: 0.08em; color: var(--text-muted); margin-bottom: 6px; }}
  .kv-val {{ font-size: 1.05rem; font-weight: 700; color: var(--text); }}
  .log-wrap {{ background: #06080f; border: 1px solid var(--border); border-radius: 10px; padding: 14px 16px; max-height: 480px; overflow-y: auto; font-family: 'JetBrains Mono','Fira Code',ui-monospace,monospace; }}
  .log-entry {{ display: flex; gap: 10px; padding: 5px 0; border-bottom: 1px solid rgba(255,255,255,0.03); flex-wrap: wrap; align-items: baseline; }}
  .log-entry:last-child {{ border: none; }}
  .log-ts {{ color: var(--text-dim); font-size: 0.7rem; flex-shrink: 0; min-width: 170px; }}
  .log-ev {{ font-size: 0.75rem; font-weight: 700; flex-shrink: 0; min-width: 160px; }}
  .log-data {{ font-size: 0.72rem; color: var(--text-muted); word-break: break-all; }}
  .detail-grid {{ display: grid; grid-template-columns: 380px 1fr; gap: 20px; align-items: start; }}
  @media (max-width: 900px) {{ .detail-grid {{ grid-template-columns: 1fr; }} }}
  .back-link {{ display: inline-flex; align-items: center; gap: 6px; font-size: 0.8rem; color: var(--text-muted); margin-bottom: 20px; transition: color 0.15s; }}
  .back-link:hover {{ color: var(--accent2); text-decoration: none; }}
  </style>
</head>
<body>
<nav class="nav">
  <div class="nav-logo">
    <div class="logo-icon">&#9889;</div>
    TPSM Runner
  </div>
  <span class="nav-pill">Run Detail</span>
  <div class="nav-spacer"></div>
  <div class="nav-refresh"><div class="pulse"></div>Auto-refresh 5s</div>
</nav>
<div class="page">
  <a class="back-link" href="/">&#8592; Back to Dashboard</a>

  <div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;flex-wrap:wrap;gap:12px">
    <div>
      <div style="font-size:0.75rem;color:var(--text-muted);margin-bottom:4px">Run ID</div>
      <div style="font-family:monospace;font-size:1.1rem;font-weight:700;color:var(--text)">{rid}</div>
    </div>
    <div style="display:flex;align-items:center;gap:10px">
      <span class="badge {alive_cls}">{alive_lbl}</span>
      <span class="badge badge-{html.escape(run_status)}">{html.escape(run_status)}</span>
    </div>
  </div>

  <div class="btn-row" style="margin-bottom:24px">
    <form method="post" action="/runs/{rid}/pause" style="display:inline">
      <button class="btn btn-ghost" type="submit">&#9646;&#9646; Pause After Split</button>
    </form>
    <form method="post" action="/runs/{rid}/resume" style="display:inline">
      <button class="btn btn-success" type="submit">&#9654; Resume</button>
    </form>
    <form method="post" action="/runs/{rid}/stop" style="display:inline">
      <button class="btn btn-danger" type="submit">&#9632; Stop After Split</button>
    </form>
  </div>

  <div class="kv-grid" style="margin-bottom:20px">
    <div class="kv"><div class="kv-label">Overall Progress</div>
      <div style="margin-top:8px">
        <div style="display:flex;justify-content:space-between;margin-bottom:6px">
          <span class="kv-val">{pct_complete:.1f}%</span>
          <span style="font-size:0.78rem;color:var(--text-muted)">{progress.get("completed_units", 0)} / {progress.get("total_units", 0)} units</span>
        </div>
        <div class="progress-bar-wrap"><div class="progress-bar-fill" style="width:{bar_w}"></div></div>
      </div>
    </div>
    <div class="kv"><div class="kv-label">Datasets</div><div class="kv-val">{progress.get("completed_datasets", 0)} <span style="font-size:0.8rem;font-weight:400;color:var(--text-muted)">/ {progress.get("total_datasets", 0)}</span></div></div>
    <div class="kv"><div class="kv-label">Current Unit</div><div style="margin-top:4px"><code style="font-size:0.72rem">{html.escape(current)}</code></div></div>
    <div class="kv"><div class="kv-label">Last Updated</div><div style="font-size:0.8rem;color:var(--text-muted);margin-top:4px">{html.escape(str(state.get("updated_at_utc")))}</div></div>
  </div>

  <div class="detail-grid">
    <div class="card">
      <div class="card-header">
        <div class="card-title">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M9 21V9"/></svg>
          Dataset Progress
        </div>
      </div>
      <div class="table-wrap">
        <table>
          <thead><tr><th>Task</th><th>Dataset</th><th>Status</th><th>Units</th><th>Progress</th></tr></thead>
          <tbody>{"".join(dataset_rows) or "<tr class='empty-row'><td colspan='5'>No datasets tracked yet</td></tr>"}</tbody>
        </table>
      </div>
    </div>

    <div class="card">
      <div class="card-header">
        <div class="card-title">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="22 12 18 12 15 21 9 3 6 12 2 12"/></svg>
          Recent Events
        </div>
        <span style="font-size:0.72rem;color:var(--text-dim)">last {len(logs)}</span>
      </div>
      <div class="log-wrap">{log_html}</div>
    </div>
  </div>
</div>
</body>
</html>"""


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
            return self._send_json(
                {"runs": _list_runs(self.args.output_root), "timestamp_utc": utc_now()}
            )
        if self.path.startswith("/api/runs/"):
            run_id = self.path.split("/api/runs/", 1)[1]
            run_dir = os.path.join(self.args.output_root, run_id)
            state_path = os.path.join(run_dir, "state", "run_state.json")
            if not os.path.exists(state_path):
                return self._send_json({"error": "not_found"}, 404)
            return self._send_json(
                {"state": load_json(state_path), "logs": _tail_log(run_dir, 60)}
            )
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
            _spawn_runner(
                self.args, run_id, run_dir, snapshot_path, timeout, resume=False
            )
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
            proc = _spawn_runner(
                self.args, run_id, run_dir, snapshot_path, timeout, resume=False
            )
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
                    proc = _spawn_runner(
                        self.args, run_id, run_dir, "", 300, resume=True
                    )
                    return self._send_json(
                        {"ok": True, "status": "resumed", "pid": proc.pid}
                    )
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
