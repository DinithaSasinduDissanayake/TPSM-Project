export const finalNumbers = {
  rows: "13,950",
  datasets: "19",
  taskTypes: "2",
  metrics: "10",
  modelPairs: "6",
  ensembleWins: 11910,
  singleWins: 1779,
  ties: 261,
  allRowWinRate: "85.38%",
  nonTieWinRate: "87.00%",
  headlineWinRate: "87.50%",
  confidenceInterval: "86.91% to 88.08%",
  pValue: "< 0.001",
  decision: "Reject H0",
}

export const datasetProfile = [
  { label: "Paired rows", value: 13950 },
  { label: "Datasets", value: 19 },
  { label: "Metrics", value: 10 },
  { label: "Model pairs", value: 6 },
]

export const descriptiveCounts = [
  { name: "Ensemble wins", value: finalNumbers.ensembleWins },
  { name: "Single wins", value: finalNumbers.singleWins },
  { name: "Ties", value: finalNumbers.ties },
]

export const taskWinRates = [
  { name: "Classification", value: 87.54 },
  { name: "Regression", value: 86.19 },
]

export const headlineComparison = [
  { name: "50% null", value: 50 },
  { name: "Observed", value: 87.5 },
]

export const modelPairExamples = [
  "Decision Tree vs Random Forest",
  "Logistic Regression vs Gradient Boosting",
  "Linear Regression vs Gradient Boosting Regressor",
]

export const modelPairRates = [
  { name: "Decision Tree / Random Forest", value: 92.82 },
  { name: "Naive Bayes / Gradient Boosting", value: 89.59 },
  { name: "SVR / GB Regressor", value: 88.89 },
  { name: "Linear Regression / GB Regressor", value: 86.83 },
  { name: "Decision Tree Regressor / GB Regressor", value: 82.83 },
  { name: "Logistic Regression / Gradient Boosting", value: 79.96 },
]

export const metricWinRates = [
  { name: "logloss", value: 93.61 },
  { name: "roc_auc", value: 92.18 },
  { name: "accuracy", value: 90.48 },
  { name: "r2", value: 88.15 },
  { name: "rmse", value: 88.15 },
  { name: "mae", value: 86.0 },
  { name: "f1", value: 85.08 },
  { name: "precision", value: 80.72 },
  { name: "mape", value: 82.44 },
  { name: "recall", value: 78.33 },
]

export const datasetVariation = [
  { group: "High", value: 100 },
  { group: "Median pattern", value: 87 },
  { group: "Low", value: 67 },
]

export const readinessRows = [
  ["No time-series rows", "Confirmed"],
  ["All rows valid paired rows", "Confirmed"],
  ["Required analysis columns", "Present"],
  ["Numeric metric columns", "Usable"],
  ["Tie rule", "difference_value == 0"],
]

export const methodRows = [
  ["Statistical inference", "Use sample comparison rows to support broader project statement"],
  ["Hypothesis testing", "H0: ensemble win proportion = 0.50; H1: > 0.50"],
  ["Population proportion", "Non-tied row becomes success/failure outcome"],
  ["Paired comparison", "Single and ensemble models compared under same context"],
]

export const plotPaths = {
  task: "/analysis-plots/01_win_rate_by_task_type.png",
  dataset: "/analysis-plots/02_win_rate_by_dataset.png",
  metric: "/analysis-plots/03_win_rate_by_metric.png",
  modelPair: "/analysis-plots/04_win_rate_by_model_pair.png",
  winLossTie: "/analysis-plots/09_win_loss_tie_by_metric.png",
}
