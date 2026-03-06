#!/usr/bin/env python3
"""Comprehensive post-fix analysis: hunt for hidden issues."""
import pandas as pd, numpy as np, json, os

RUN = 'outputs/py_fixtest/20260305T154724'
mr = pd.read_csv(f'{RUN}/model_runs.csv')
pw = pd.read_csv(f'{RUN}/pairwise_differences.csv')

with open(f'{RUN}/run_log.txt') as f:
    logs = [json.loads(l) for l in f if l.strip()]

print("=" * 90)
print("POST-FIX DEEP ANALYSIS")
print("=" * 90)

# 1. Error summary
print("\n1. ERRORS AND STATUS BREAKDOWN")
for status in sorted(mr['status'].unique()):
    cnt = len(mr[mr['status']==status])
    print(f"   {status}: {cnt}")
errors = mr[mr['status']=='error']
if len(errors) > 0:
    for _, e in errors.groupby(['dataset_id','model_name']).first().reset_index().iterrows():
        print(f"   ⚠️ {e['dataset_id']:25s} {e['model_name']:25s}: {e['error_message']}")

# 2. NULL metric values
print("\n2. NULL METRIC VALUES")
nulls = mr[mr['metric_value'].isna()]
if len(nulls) > 0:
    null_summary = nulls.groupby(['task_type','dataset_id','model_name','metric_name']).size().reset_index(name='n')
    for _, r in null_summary.iterrows():
        print(f"   {r['task_type']:15s} {r['dataset_id']:25s} {r['model_name']:25s} {r['metric_name']:10s} {r['n']} NULLs")
else:
    print("   None!")

# 3. NaN/Inf in metric values
print("\n3. NaN/Inf IN METRIC VALUES")
ok_rows = mr[mr['status']=='ok']
inf_rows = ok_rows[~np.isfinite(ok_rows['metric_value'])]
if len(inf_rows) > 0:
    for _, r in inf_rows.groupby(['dataset_id','model_name','metric_name']).size().reset_index(name='n').iterrows():
        print(f"   ⚠️ {r['dataset_id']:25s} {r['model_name']:25s} {r['metric_name']:10s} {r['n']} Inf/NaN")
else:
    print("   None!")

# 4. Suspiciously high or low values
print("\n4. SUSPICIOUS VALUES")
for task in sorted(mr['task_type'].unique()):
    sub = mr[(mr['task_type']==task) & (mr['status']=='ok')]
    for metric in sorted(sub['metric_name'].unique()):
        vals = sub[sub['metric_name']==metric]['metric_value'].dropna()
        if len(vals) == 0: continue
        # Check for extremes
        if metric == 'r2' and vals.min() < -0.5:
            bad = sub[(sub['metric_name']==metric) & (sub['metric_value'] < -0.5)]
            for ds in bad['dataset_id'].unique():
                for m in bad[bad['dataset_id']==ds]['model_name'].unique():
                    v = bad[(bad['dataset_id']==ds) & (bad['model_name']==m)]['metric_value'].mean()
                    print(f"   ⚠️ {task}:{ds}:{m} R²={v:.4f} (worse than mean)")
        if metric == 'accuracy' and vals.max() == 1.0:
            perfect = sub[(sub['metric_name']==metric) & (sub['metric_value'] == 1.0)]
            for ds in perfect['dataset_id'].unique():
                cnt = len(perfect[perfect['dataset_id']==ds])
                print(f"   ⚠️ {task}:{ds} has {cnt} perfect accuracy=1.0 folds")
        if metric == 'mae' and vals.max() > 10000:
            high = sub[(sub['metric_name']==metric) & (sub['metric_value'] > 10000)]
            for ds in high['dataset_id'].unique():
                for m in high[high['dataset_id']==ds]['model_name'].unique():
                    v = high[(high['dataset_id']==ds) & (high['model_name']==m)]['metric_value'].mean()
                    print(f"   ⚠️ {task}:{ds}:{m} MAE={v:.0f} (very high)")

# 5. Check one-hot encoding worked — compare feature count
print("\n5. ONE-HOT ENCODING CHECK")
import yaml
with open('config/smoke_test.yaml') as f:
    cfg = yaml.safe_load(f)
for task_name in ['classification', 'regression']:
    task_cfg = cfg.get(task_name, {})
    for ds in task_cfg.get('datasets', []):
        path = ds['path']
        if not os.path.exists(path): continue
        raw = pd.read_csv(path, nrows=5)
        cat_cols = raw.select_dtypes(include=['object','category']).columns
        target = ds['target']
        cat_cols = [c for c in cat_cols if c != target]
        if len(cat_cols) > 0:
            # Estimate encoded column count
            raw_full = pd.read_csv(path)
            n_dummies = sum(raw_full[c].nunique() - 1 for c in cat_cols if c in raw_full.columns)
            numeric_orig = len(raw.select_dtypes(include=[np.number]).columns)
            total_features = numeric_orig + n_dummies - 1  # -1 for target
            print(f"   {ds['id']:25s} raw={len(raw.columns)} cat_cols={len(cat_cols)} → estimated {total_features} features after encoding")

# 6. Pairwise completeness
print("\n6. PAIRWISE COMPLETENESS")
expected_pairs = {}
for task_name in ['classification', 'regression', 'timeseries']:
    task_cfg = cfg.get(task_name, {})
    pairs = task_cfg.get('model_pairs', [])
    datasets = task_cfg.get('datasets', [])
    metrics = task_cfg.get('metrics', [])
    folds = task_cfg.get('folds', task_cfg.get('splits', 2))
    repeats = task_cfg.get('repeats', 1)
    n_splits = folds * repeats if task_name != 'timeseries' else folds
    for p in pairs:
        for ds in datasets:
            expected = n_splits * len(metrics)
            actual = len(pw[(pw['task_type']==task_name) & (pw['dataset_id']==ds['id']) & 
                           (pw['single_model_name'].str.contains(p['single'][:5])) &
                           (pw['ensemble_model_name'].str.contains(p['ensemble'][:5]))])
            if actual != expected:
                print(f"   ⚠️ {task_name}:{ds['id']}:{p['single']} vs {p['ensemble']}: expected {expected}, got {actual}")

# 7. Log warnings
print("\n7. WARNINGS FROM RUN LOG")
warns = [l for l in logs if l.get('level') in ('warning', 'error')]
if warns:
    for w in warns[:10]:
        d = w.get('data', {})
        print(f"   [{w['level']}] {d.get('dataset', '?')}: {d.get('error_message', d.get('warning', str(d)[:100]))}")
else:
    print("   Zero warnings/errors in log")

# 8. Check if one-hot creates too many columns (explosion)
print("\n8. FEATURE EXPLOSION CHECK")
for task_name in ['classification', 'regression']:
    task_cfg = cfg.get(task_name, {})
    for ds in task_cfg.get('datasets', []):
        path = ds['path']
        if not os.path.exists(path): continue
        raw = pd.read_csv(path)
        target = ds['target']
        X = raw.drop(columns=[target], errors='ignore')
        cat_cols = X.select_dtypes(include=['object','category']).columns
        if len(cat_cols) > 0:
            X_enc = pd.get_dummies(X, columns=cat_cols, drop_first=True, dtype=float)
            if len(X_enc.columns) > 100:
                print(f"   ⚠️ {ds['id']:25s} {len(X_enc.columns)} features after encoding (was {len(X.columns)})!")
            
# 9. Check if train/test column mismatch could happen with one-hot
print("\n9. TRAIN/TEST COLUMN MISMATCH RISK")
for task_name in ['classification']:
    task_cfg = cfg.get(task_name, {})
    for ds in task_cfg.get('datasets', []):
        path = ds['path']
        if not os.path.exists(path): continue
        raw = pd.read_csv(path)
        cat_cols = raw.select_dtypes(include=['object','category']).columns
        target = ds['target']
        cat_cols = [c for c in cat_cols if c != target]
        for c in cat_cols:
            n_unique = raw[c].nunique()
            if n_unique > 20:
                print(f"   ⚠️ {ds['id']:25s} column '{c}' has {n_unique} unique values — high cardinality!")

# 10. Check pairwise ensemble_better consistency
print("\n10. PAIRWISE ensemble_better CONSISTENCY")
for _, row in pw.head(20).iterrows():
    d = row['difference_value']
    eb = row['ensemble_better']
    if (d > 0 and not eb) or (d < 0 and eb) or (d == 0 and eb):
        print(f"   ⚠️ INCONSISTENT: diff={d:.6f} but ensemble_better={eb} ({row['metric_name']}, {row['dataset_id']})")
consistent = all((row['difference_value'] > 0) == row['ensemble_better'] for _, row in pw.iterrows() if row['difference_value'] != 0)
print(f"   All {len(pw)} pairwise rows consistent: {consistent}")
