#!/usr/bin/env Rscript

# Phase 2A Step 3: Simple descriptive plots.
# This script does not run hypothesis tests or calculate p-values.

if (!requireNamespace("ggplot2", quietly = TRUE)) {
  stop("Package 'ggplot2' is required for plotting.")
}

if (!requireNamespace("dplyr", quietly = TRUE)) {
  stop("Package 'dplyr' is required for simple data preparation.")
}

args <- commandArgs(trailingOnly = TRUE)

STEP2_DIR <- if (length(args) >= 1) {
  args[1]
} else {
  "outputs/final_project_analysis/02_descriptive_summaries"
}

DATA_PATH <- if (length(args) >= 2) {
  args[2]
} else {
  "outputs/archive/legacy/py_full_no_timeseries_probe/20260421T231947/analysis_ready_pairwise.csv"
}

OUTPUT_DIR <- if (length(args) >= 3) {
  args[3]
} else {
  "outputs/final_project_analysis/03_descriptive_plots"
}

if (!dir.exists(STEP2_DIR)) {
  stop(paste("Step 2 summary folder not found:", STEP2_DIR))
}

if (!file.exists(DATA_PATH)) {
  stop(paste("Input CSV not found:", DATA_PATH))
}

if (!dir.exists(OUTPUT_DIR)) {
  dir.create(OUTPUT_DIR, recursive = TRUE)
}

normalize_bool <- function(x) {
  if (is.logical(x)) {
    return(x)
  }
  y <- tolower(trimws(as.character(x)))
  out <- rep(NA, length(y))
  out[y %in% c("true", "t", "1")] <- TRUE
  out[y %in% c("false", "f", "0")] <- FALSE
  out
}

read_step2 <- function(filename) {
  path <- file.path(STEP2_DIR, filename)
  if (!file.exists(path)) {
    stop(paste("Required Step 2 file not found:", path))
  }
  read.csv(path, stringsAsFactors = FALSE)
}

format_percent <- function(x) {
  paste0(round(x * 100, 1), "%")
}

plot_win_rate <- function(data, label_col, title, output_file, flag_mape = FALSE) {
  data <- data[order(data$ensemble_win_rate), ]
  data[[label_col]] <- factor(data[[label_col]], levels = data[[label_col]])
  data$bar_group <- "normal"
  if (flag_mape && "metric_name" %in% names(data)) {
    data$bar_group[data$metric_name == "mape"] <- "mape_caution"
  }

  p <- ggplot2::ggplot(
    data,
    ggplot2::aes(x = .data[[label_col]], y = ensemble_win_rate, fill = bar_group)
  ) +
    ggplot2::geom_col(width = 0.7) +
    ggplot2::geom_hline(yintercept = 0.5, linetype = "dashed", linewidth = 0.6) +
    ggplot2::coord_flip() +
    ggplot2::scale_y_continuous(
      labels = function(x) paste0(round(x * 100), "%"),
      limits = c(0, 1)
    ) +
    ggplot2::scale_fill_manual(
      values = c(normal = "#262626", mape_caution = "#737373"),
      guide = "none"
    ) +
    ggplot2::labs(
      title = title,
      subtitle = "Dashed line = 50% reference. Ties are not counted as ensemble wins.",
      x = NULL,
      y = "Ensemble win rate"
    ) +
    ggplot2::theme_minimal(base_size = 12) +
    ggplot2::theme(
      plot.title = ggplot2::element_text(face = "bold"),
      panel.grid.major.y = ggplot2::element_blank()
    )

  ggplot2::ggsave(
    file.path(OUTPUT_DIR, output_file),
    plot = p,
    width = 10,
    height = 6,
    dpi = 300
  )
}

cat("=== TPSM Phase 2A Step 3: Descriptive Plots ===\n")
cat("Step 2 summaries:", STEP2_DIR, "\n")
cat("Input CSV:", DATA_PATH, "\n")
cat("Output:", OUTPUT_DIR, "\n\n")

summary_by_task <- read_step2("summary_by_task_type.csv")
summary_by_dataset <- read_step2("summary_by_dataset.csv")
summary_by_metric <- read_step2("summary_by_metric.csv")
summary_by_model_pair <- read_step2("summary_by_model_pair.csv")

df <- read.csv(DATA_PATH, stringsAsFactors = FALSE)
if ("valid_pair" %in% names(df)) {
  df$valid_pair <- normalize_bool(df$valid_pair)
}
if ("ensemble_better" %in% names(df)) {
  df$ensemble_better <- normalize_bool(df$ensemble_better)
}
df <- df[df$valid_pair == TRUE & !is.na(df$valid_pair), ]
df$win_status <- ifelse(
  df$difference_value > 0,
  "ensemble_win",
  ifelse(df$difference_value < 0, "single_win", "tie")
)
df$mape_caution <- ifelse(df$metric_name == "mape", "mape caution", "other metrics")

plot_win_rate(
  summary_by_task,
  "task_type",
  "Ensemble win rate by task type",
  "01_win_rate_by_task_type.png"
)

plot_win_rate(
  summary_by_dataset,
  "dataset_id",
  "Ensemble win rate by dataset",
  "02_win_rate_by_dataset.png"
)

plot_win_rate(
  summary_by_metric,
  "metric_name",
  "Ensemble win rate by metric",
  "03_win_rate_by_metric.png",
  flag_mape = TRUE
)

plot_win_rate(
  summary_by_model_pair,
  "model_pair",
  "Ensemble win rate by model pair",
  "04_win_rate_by_model_pair.png"
)

common_range <- as.numeric(stats::quantile(
  df$difference_value,
  probs = c(0.01, 0.99),
  na.rm = TRUE
))

hist_common_plot <- ggplot2::ggplot(df, ggplot2::aes(x = difference_value)) +
  ggplot2::geom_histogram(bins = 60, fill = "#262626", color = "white") +
  ggplot2::geom_vline(xintercept = 0, linetype = "dashed", linewidth = 0.6) +
  ggplot2::coord_cartesian(xlim = common_range) +
  ggplot2::labs(
    title = "Raw difference_value distribution, zoomed",
    subtitle = "Internal check only: mixed metric scales still make this hard to use for presentation.",
    x = "difference_value",
    y = "Comparison count"
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(plot.title = ggplot2::element_text(face = "bold"))

ggplot2::ggsave(
  file.path(OUTPUT_DIR, "05_histogram_difference_value.png"),
  plot = hist_common_plot,
  width = 10,
  height = 6,
  dpi = 300
)

faceted_hist_plot <- ggplot2::ggplot(df, ggplot2::aes(x = difference_value)) +
  ggplot2::geom_histogram(bins = 40, fill = "#262626", color = "white") +
  ggplot2::geom_vline(xintercept = 0, linetype = "dashed", linewidth = 0.5) +
  ggplot2::facet_wrap(~ metric_name, scales = "free_x", ncol = 2) +
  ggplot2::labs(
    title = "difference_value distributions by metric",
    subtitle = "Each metric has its own x-axis scale, so mixed metric units do not hide the shape.",
    x = "difference_value",
    y = "Comparison count"
  ) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(plot.title = ggplot2::element_text(face = "bold"))

ggplot2::ggsave(
  file.path(OUTPUT_DIR, "07_faceted_histogram_difference_by_metric.png"),
  plot = faceted_hist_plot,
  width = 11,
  height = 9,
  dpi = 300
)

task_hist_plot <- ggplot2::ggplot(df, ggplot2::aes(x = difference_value)) +
  ggplot2::geom_histogram(bins = 50, fill = "#262626", color = "white") +
  ggplot2::geom_vline(xintercept = 0, linetype = "dashed", linewidth = 0.5) +
  ggplot2::facet_wrap(~ task_type, scales = "free_x", ncol = 1) +
  ggplot2::labs(
    title = "difference_value distributions by task type",
    subtitle = "Classification and regression are separated because their metric scales are different.",
    x = "difference_value",
    y = "Comparison count"
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(plot.title = ggplot2::element_text(face = "bold"))

ggplot2::ggsave(
  file.path(OUTPUT_DIR, "08_histogram_difference_by_task_type.png"),
  plot = task_hist_plot,
  width = 10,
  height = 7,
  dpi = 300
)

boxplot_data <- df
boxplot_data$metric_name <- factor(
  boxplot_data$metric_name,
  levels = summary_by_metric$metric_name[order(summary_by_metric$ensemble_win_rate)]
)

boxplot_data <- dplyr::group_by(boxplot_data, metric_name)
boxplot_data <- dplyr::mutate(
  boxplot_data,
  metric_low = stats::quantile(difference_value, 0.05, na.rm = TRUE),
  metric_high = stats::quantile(difference_value, 0.95, na.rm = TRUE),
  difference_value_limited = pmax(pmin(difference_value, metric_high), metric_low)
)
boxplot_data <- dplyr::ungroup(boxplot_data)

box_plot <- ggplot2::ggplot(
  boxplot_data,
  ggplot2::aes(x = metric_name, y = difference_value_limited, fill = mape_caution)
) +
  ggplot2::geom_boxplot(outlier.shape = NA) +
  ggplot2::geom_hline(yintercept = 0, linetype = "dashed", linewidth = 0.6) +
  ggplot2::coord_flip() +
  ggplot2::scale_fill_manual(
    values = c("other metrics" = "#262626", "mape caution" = "#737373"),
    name = NULL
  ) +
  ggplot2::labs(
    title = "difference_value by metric, limited view",
    subtitle = "Values are clipped within each metric's 5th to 95th percentile for readability.",
    x = NULL,
    y = "difference_value, clipped within each metric"
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(plot.title = ggplot2::element_text(face = "bold"))

ggplot2::ggsave(
  file.path(OUTPUT_DIR, "06_boxplot_difference_by_metric.png"),
  plot = box_plot,
  width = 10,
  height = 6,
  dpi = 300
)

win_loss_counts <- stats::aggregate(
  comparison_id ~ metric_name + win_status,
  data = df,
  FUN = length
)
names(win_loss_counts)[names(win_loss_counts) == "comparison_id"] <- "comparison_count"
win_loss_counts$win_status <- factor(
  win_loss_counts$win_status,
  levels = c("single_win", "tie", "ensemble_win"),
  labels = c("Single model better", "Tie", "Ensemble better")
)
win_loss_counts$metric_name <- factor(
  win_loss_counts$metric_name,
  levels = summary_by_metric$metric_name[order(summary_by_metric$ensemble_win_rate)]
)

win_loss_plot <- ggplot2::ggplot(
  win_loss_counts,
  ggplot2::aes(x = metric_name, y = comparison_count, fill = win_status)
) +
  ggplot2::geom_col(width = 0.7) +
  ggplot2::coord_flip() +
  ggplot2::scale_fill_manual(
    values = c(
      "Single model better" = "#8c8c8c",
      "Tie" = "#d9d9d9",
      "Ensemble better" = "#262626"
    ),
    name = NULL
  ) +
  ggplot2::labs(
    title = "Win, loss, and tie counts by metric",
    subtitle = "Positive difference_value means the ensemble model performed better.",
    x = NULL,
    y = "Comparison count"
  ) +
  ggplot2::theme_minimal(base_size = 12) +
  ggplot2::theme(
    plot.title = ggplot2::element_text(face = "bold"),
    panel.grid.major.y = ggplot2::element_blank(),
    legend.position = "bottom"
  )

ggplot2::ggsave(
  file.path(OUTPUT_DIR, "09_win_loss_tie_by_metric.png"),
  plot = win_loss_plot,
  width = 10,
  height = 6,
  dpi = 300
)

notes_path <- file.path(OUTPUT_DIR, "descriptive_plot_notes.md")

task_top <- summary_by_task[order(summary_by_task$ensemble_win_rate, decreasing = TRUE), ][1, ]
dataset_top <- summary_by_dataset[order(summary_by_dataset$ensemble_win_rate, decreasing = TRUE), ][1:5, ]
dataset_bottom <- summary_by_dataset[order(summary_by_dataset$ensemble_win_rate), ][1:5, ]
metric_top <- summary_by_metric[order(summary_by_metric$ensemble_win_rate, decreasing = TRUE), ][1:3, ]
metric_bottom <- summary_by_metric[order(summary_by_metric$ensemble_win_rate), ][1:3, ]
pair_top <- summary_by_model_pair[order(summary_by_model_pair$ensemble_win_rate, decreasing = TRUE), ][1, ]
pair_bottom <- summary_by_model_pair[order(summary_by_model_pair$ensemble_win_rate), ][1, ]

notes <- c(
  "# Phase 2A Step 3: Descriptive Plot Notes",
  "",
  paste("Step 2 summary folder:", STEP2_DIR),
  paste("Main input CSV:", DATA_PATH),
  "",
  "## Plots Created",
  "",
  "- `01_win_rate_by_task_type.png`: compares ensemble win rate for classification and regression.",
  "- `02_win_rate_by_dataset.png`: compares ensemble win rate across datasets.",
  "- `03_win_rate_by_metric.png`: compares ensemble win rate across metrics; MAPE is shown in a caution color.",
  "- `04_win_rate_by_model_pair.png`: compares ensemble win rate across model pairs.",
  "- `05_histogram_difference_value.png`: zoomed raw histogram. Keep for internal checking only; not recommended for presentation.",
  "- `06_boxplot_difference_by_metric.png`: limited boxplot by metric. Values are clipped within each metric's 5th to 95th percentile for readability.",
  "- `07_faceted_histogram_difference_by_metric.png`: shows separate metric-wise distributions with free x-axis scales.",
  "- `08_histogram_difference_by_task_type.png`: separates classification and regression distributions.",
  "- `09_win_loss_tie_by_metric.png`: counts how often the ensemble wins, loses, or ties for each metric.",
  "",
  "## Why Raw difference_value Is Hard To Plot",
  "",
  paste0(
    "The raw `difference_value` column mixes metrics with very different scales. ",
    "Classification metrics such as accuracy, F1, precision, recall, and ROC AUC are bounded and usually move in small decimals. ",
    "Regression error metrics such as MAE and RMSE can move by hundreds or thousands because they use the original target units. ",
    "When all metrics are placed on one raw x-axis, the large regression values compress the small classification values near zero."
  ),
  "",
  "## Plain-Language Observations",
  "",
  paste0(
    "- The task-type plot shows the strongest task type is `", task_top$task_type,
    "` with a win rate of ", format_percent(task_top$ensemble_win_rate), "."
  ),
  paste0(
    "- Several datasets have very high ensemble win rates, including ",
    paste(dataset_top$dataset_id, collapse = ", "), "."
  ),
  paste0(
    "- The lowest dataset win rates are seen in ",
    paste(dataset_bottom$dataset_id, collapse = ", "), "."
  ),
  paste0(
    "- The highest metric win rates are ",
    paste(metric_top$metric_name, collapse = ", "), "."
  ),
  paste0(
    "- The lowest metric win rates are ",
    paste(metric_bottom$metric_name, collapse = ", "), "."
  ),
  paste0(
    "- The strongest model-pair win-rate plot is `", pair_top$model_pair,
    "` at ", format_percent(pair_top$ensemble_win_rate), "."
  ),
  paste0(
  "- The weakest model-pair win-rate plot is `", pair_bottom$model_pair,
  "` at ", format_percent(pair_bottom$ensemble_win_rate), "."
  ),
  "- The faceted histogram is the clearest plot for explaining `difference_value` shape by metric.",
  "- The task-type histogram shows why classification and regression should not be forced onto one raw x-axis.",
  "- The win/loss/tie chart is the simplest presentation plot for showing how often ensembles perform better.",
  "",
  "## Cautions",
  "",
  "- These plots are descriptive only. They do not test statistical significance.",
  "- The 50% reference line is visual guidance only, not a hypothesis test.",
  "- Ties are not counted as ensemble wins.",
  "- MAPE is included but visually flagged because the generator warnings identified low-target MAPE risk.",
  "- `05_histogram_difference_value.png` is not recommended for presentation because it still mixes metric scales.",
  "- `06_boxplot_difference_by_metric.png` clips values within each metric for readability, so it should not be used to discuss extreme values.",
  "- Raw `difference_value` is still scale-sensitive, especially across regression and classification metrics.",
  "",
  "## Best Plots For Report Or Presentation",
  "",
  "- Use `01_win_rate_by_task_type.png` for the high-level task comparison.",
  "- Use `02_win_rate_by_dataset.png` to show variation across datasets.",
  "- Use `03_win_rate_by_metric.png` to explain metric-level differences and flag MAPE.",
  "- Use `07_faceted_histogram_difference_by_metric.png` to explain `difference_value` without mixed-scale distortion.",
  "- Use `08_histogram_difference_by_task_type.png` if the presentation needs a simple classification-versus-regression comparison.",
  "- Use `09_win_loss_tie_by_metric.png` as the clearest beginner-friendly count view.",
  "",
  "## Internal-Understanding Plots",
  "",
  "- `05_histogram_difference_value.png` is useful only as a quick diagnostic view of the combined raw distribution.",
  "- `06_boxplot_difference_by_metric.png` is useful for checking the middle spread by metric, but remember that extreme values are clipped.",
  "",
  "## Next Step",
  "",
  "After the descriptive plots are accepted, the next step can be planned separately. No hypothesis testing is done in this script."
)

writeLines(notes, notes_path)

cat("Plots and notes written to:", OUTPUT_DIR, "\n")
cat("- 01_win_rate_by_task_type.png\n")
cat("- 02_win_rate_by_dataset.png\n")
cat("- 03_win_rate_by_metric.png\n")
cat("- 04_win_rate_by_model_pair.png\n")
cat("- 05_histogram_difference_value.png\n")
cat("- 06_boxplot_difference_by_metric.png\n")
cat("- 07_faceted_histogram_difference_by_metric.png\n")
cat("- 08_histogram_difference_by_task_type.png\n")
cat("- 09_win_loss_tie_by_metric.png\n")
cat("- descriptive_plot_notes.md\n")
