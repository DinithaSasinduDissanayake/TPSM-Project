#!/usr/bin/env Rscript

library(dplyr)
library(ggplot2)
library(tidyr)

args <- commandArgs(trailingOnly = TRUE)
OUTPUT_DIR <- if (length(args) >= 1) args[1] else "outputs/analysis"
DATA_PATH <- if (length(args) >= 2) args[2] else "outputs/combined_pairwise_differences.csv"

if (!dir.exists(OUTPUT_DIR)) dir.create(OUTPUT_DIR, recursive = TRUE)
if (!dir.exists(file.path(OUTPUT_DIR, "plots"))) dir.create(file.path(OUTPUT_DIR, "plots"), recursive = TRUE)

df <- read.csv(DATA_PATH)

cat("=== DESCRIPTIVE ANALYSIS FOR TPSM PROJECT ===\n\n")

# ============================================================================
# 1. OVERALL SUMMARY
# ============================================================================
cat("1. OVERALL SUMMARY\n")
cat(rep("=", 50), "\n")

overall <- df %>%
  summarise(
    total_comparisons = n(),
    mean_diff = mean(difference_value, na.rm = TRUE),
    median_diff = median(difference_value, na.rm = TRUE),
    sd_diff = sd(difference_value, na.rm = TRUE),
    min_diff = min(difference_value, na.rm = TRUE),
    max_diff = max(difference_value, na.rm = TRUE),
    ensemble_win_pct = mean(ensemble_better, na.rm = TRUE) * 100
  )
print(overall)

cat("\n>>> INTERPRETATION: Overall, ensembles win", round(overall$ensemble_win_pct, 1), 
    "% of the time with mean difference of", round(overall$mean_diff, 4), "\n\n")

# ============================================================================
# 2. BY METRIC
# ============================================================================
cat("2. BY METRIC\n")
cat(rep("=", 50), "\n")

by_metric <- df %>%
  group_by(metric_name) %>%
  summarise(
    n = n(),
    mean_diff = mean(difference_value, na.rm = TRUE),
    median_diff = median(difference_value, na.rm = TRUE),
    sd_diff = sd(difference_value, na.rm = TRUE),
    ensemble_win_pct = mean(ensemble_better, na.rm = TRUE) * 100,
    .groups = "drop"
  ) %>%
  arrange(desc(mean_diff))

print(by_metric)

cat("\n>>> KEY INSIGHT: Metrics where ensembles consistently win:\n")
winners <- by_metric %>% filter(mean_diff > 0 & ensemble_win_pct > 50)
if (nrow(winners) > 0) {
  for (i in seq_len(nrow(winners))) {
    cat("   -", winners$metric_name[i], ":", round(winners$ensemble_win_pct[i], 1), 
        "% win rate, avg +", round(winners$mean_diff[i], 4), " gain\n")
  }
}

# ============================================================================
# 3. BY DATASET
# ============================================================================
cat("\n3. BY DATASET\n")
cat(rep("=", 50), "\n")

by_dataset <- df %>%
  group_by(dataset_id, metric_name) %>%
  summarise(
    n = n(),
    mean_diff = mean(difference_value, na.rm = TRUE),
    ensemble_win_pct = mean(ensemble_better, na.rm = TRUE) * 100,
    .groups = "drop"
  )

print(by_dataset)

cat("\n>>> KEY INSIGHT: Which dataset favors ensembles more?\n")
ds_summary <- df %>%
  group_by(dataset_id) %>%
  summarise(
    ensemble_win_pct = mean(ensemble_better, na.rm = TRUE) * 100,
    mean_diff = mean(difference_value, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(ensemble_win_pct))
print(ds_summary)

# ============================================================================
# 4. BY MODEL PAIR
# ============================================================================
cat("\n4. BY MODEL PAIR\n")
cat(rep("=", 50), "\n")

by_pair <- df %>%
  group_by(single_model_name, ensemble_model_name, metric_name) %>%
  summarise(
    n = n(),
    mean_diff = mean(difference_value, na.rm = TRUE),
    ensemble_win_pct = mean(ensemble_better, na.rm = TRUE) * 100,
    .groups = "drop"
  )

print(by_pair)

cat("\n>>> BEST MODEL PAIRING:\n")
best_pair <- df %>%
  group_by(single_model_name, ensemble_model_name) %>%
  summarise(
    ensemble_win_pct = mean(ensemble_better, na.rm = TRUE) * 100,
    mean_diff = mean(difference_value, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  arrange(desc(ensemble_win_pct))
print(best_pair)

# ============================================================================
# 5. SAVE SUMMARY CSV
# ============================================================================
write.csv(by_metric, file.path(OUTPUT_DIR, "by_metric.csv"), row.names = FALSE)
write.csv(by_dataset, file.path(OUTPUT_DIR, "by_dataset.csv"), row.names = FALSE)
write.csv(by_pair, file.path(OUTPUT_DIR, "by_model_pair.csv"), row.names = FALSE)
write.csv(overall, file.path(OUTPUT_DIR, "overall_summary.csv"), row.names = FALSE)

# ============================================================================
# 6. VISUALIZATIONS
# ============================================================================

# Plot 1: Boxplot by Metric
p1 <- ggplot(df, aes(x = metric_name, y = difference_value, fill = metric_name)) +
  geom_boxplot(alpha = 0.7) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "red", linewidth = 1) +
  labs(
    title = "Ensemble vs Single Model: Difference by Metric",
    subtitle = "Positive = Ensemble Better | Red line = No difference",
    x = "Metric",
    y = "Difference Value (Ensemble - Single)"
  ) +
  theme_minimal() +
  theme(legend.position = "none", axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(file.path(OUTPUT_DIR, "plots", "boxplot_by_metric.png"), p1, width = 10, height = 6)

# Plot 2: Win Rate by Dataset and Metric
p2 <- by_dataset %>%
  ggplot(aes(x = metric_name, y = ensemble_win_pct, fill = dataset_id)) +
  geom_bar(stat = "identity", position = "dodge", alpha = 0.8) +
  geom_hline(yintercept = 50, linetype = "dashed", color = "red") +
  labs(
    title = "Ensemble Win Rate by Dataset and Metric",
    subtitle = "Red line = 50% (random chance)",
    x = "Metric",
    y = "Ensemble Win Rate (%)",
    fill = "Dataset"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(file.path(OUTPUT_DIR, "plots", "winrate_by_dataset_metric.png"), p2, width = 10, height = 6)

# Plot 3: Heatmap - Mean Difference by Dataset x Model Pair
p3_data <- df %>%
  group_by(dataset_id, single_model_name, ensemble_model_name) %>%
  summarise(mean_diff = mean(difference_value, na.rm = TRUE), .groups = "drop")

p3 <- ggplot(p3_data, aes(x = dataset_id, 
                          y = paste(single_model_name, "→", ensemble_model_name), 
                          fill = mean_diff)) +
  geom_tile(color = "white", linewidth = 0.5) +
  scale_fill_gradient2(low = "#d73027", mid = "#ffffbf", high = "#1a9850", 
                       name = "Mean Difference") +
  labs(
    title = "Which Model Pairs Work Best?",
    subtitle = "Green = Ensemble Wins | Red = Single Wins",
    x = "Dataset",
    y = "Model Pair"
  ) +
  theme_minimal() +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
ggsave(file.path(OUTPUT_DIR, "plots", "heatmap_model_pair.png"), p3, width = 10, height = 6)

# Plot 4: Histogram of all differences
p4 <- ggplot(df, aes(x = difference_value, fill = ensemble_better)) +
  geom_histogram(bins = 50, alpha = 0.7, color = "white") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "red", linewidth = 1) +
  labs(
    title = "Distribution of All Differences",
    subtitle = "Blue = Ensemble Wins | Orange = Single Wins",
    x = "Difference Value",
    y = "Frequency"
  ) +
  scale_fill_manual(values = c("FALSE" = "#fdae61", "TRUE" = "#4575b4"), 
                   name = "Ensemble Won?") +
  theme_minimal()
ggsave(file.path(OUTPUT_DIR, "plots", "histogram_differences.png"), p4, width = 10, height = 6)

# Plot 5: Win Rate Pie Charts by Model Pair
p5_data <- df %>%
  group_by(single_model_name, ensemble_model_name) %>%
  summarise(
    total = n(),
    ensemble_wins = sum(ensemble_better),
    single_wins = total - ensemble_wins,
    .groups = "drop"
  )

p5 <- ggplot(p5_data) +
  geom_bar(aes(x = "", y = total, fill = ensemble_wins), stat = "identity", width = 1) +
  coord_polar("y") +
  facet_wrap(~ paste(single_model_name, "→", ensemble_model_name)) +
  scale_fill_gradient(low = "#fdae61", high = "#4575b4", name = "Ensemble Wins") +
  labs(
    title = "Win Rate by Model Pair",
    x = "",
    y = ""
  ) +
  theme_minimal() +
  theme(axis.text = element_blank())
ggsave(file.path(OUTPUT_DIR, "plots", "winrate_pie.png"), p5, width = 12, height = 6)

cat("\n=== FILES SAVED TO", OUTPUT_DIR, "===\n")
cat("- by_metric.csv\n")
cat("- by_dataset.csv\n")
cat("- by_model_pair.csv\n")
cat("- overall_summary.csv\n")
cat("- plots/boxplot_by_metric.png\n")
cat("- plots/winrate_by_dataset_metric.png\n")
cat("- plots/heatmap_model_pair.png\n")
cat("- plots/histogram_differences.png\n")
cat("- plots/winrate_pie.png\n")
cat("\n=== ANALYSIS COMPLETE ===\n")
