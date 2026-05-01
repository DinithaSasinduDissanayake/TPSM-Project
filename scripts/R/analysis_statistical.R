`%>%` <- dplyr::`%>%`

perform_statistical_tests <- function(df) {
  required_cols <- c("difference_value", "ensemble_better", "metric_name",
                     "dataset_id", "single_model_name", "ensemble_model_name",
                     "task_type")
  missing <- setdiff(required_cols, names(df))
  if (length(missing) > 0) {
    stop("Missing columns in combined output: ", paste(missing, collapse = ", "))
  }

  normalize_bool <- function(x) {
    if (is.logical(x)) return(x)
    tolower(as.character(x)) %in% c("true", "t", "1", "yes")
  }

  if ("valid_pair" %in% names(df)) {
    df$valid_pair <- normalize_bool(df$valid_pair)
  } else {
    df$valid_pair <- TRUE
  }
  df$ensemble_better <- normalize_bool(df$ensemble_better)
  
  df_filtered <- df[df$valid_pair == TRUE, ]
  if (nrow(df_filtered) == 0) {
    warning("No valid pairs found for statistical testing")
    return(data.frame())
  }
  
  stat_results <- df_filtered %>%
    dplyr::group_by(task_type, metric_name, single_model_name, ensemble_model_name) %>%
    dplyr::summarise(
      n = dplyr::n(),
      mean_diff = mean(difference_value, na.rm = TRUE),
      sd_diff = sd(difference_value, na.rm = TRUE),
      median_diff = median(difference_value, na.rm = TRUE),
      ensemble_better_rate = mean(ensemble_better, na.rm = TRUE),
      t_stat = tryCatch(
        stats::t.test(difference_value, mu = 0)$statistic,
        error = function(e) NA_real_
      ),
      t_pvalue = tryCatch(
        stats::t.test(difference_value, mu = 0)$p.value,
        error = function(e) NA_real_
      ),
      wilcox_stat = tryCatch(
        stats::wilcox.test(difference_value, mu = 0)$statistic,
        error = function(e) NA_real_
      ),
      wilcox_pvalue = tryCatch(
        stats::wilcox.test(difference_value, mu = 0)$p.value,
        error = function(e) NA_real_
      ),
      .groups = "drop"
    ) %>%
    dplyr::mutate(
      se = sd_diff / sqrt(n),
      ci_lower = mean_diff - 1.96 * se,
      ci_upper = mean_diff + 1.96 * se,
      cohens_d = mean_diff / sd_diff,
      significant_t = t_pvalue < 0.05,
      significant_wilcox = wilcox_pvalue < 0.05
    )
  
  stat_results$p_adjusted_bh <- p.adjust(stat_results$t_pvalue, method = "BH")
  stat_results$p_adjusted_bonf <- p.adjust(stat_results$t_pvalue, method = "bonferroni")
  
  stat_results <- stat_results %>%
    dplyr::mutate(
      label = paste0(single_model_name, " -> ", ensemble_model_name)
    )
  
  stat_results
}

create_forest_plot <- function(df, output_dir, task_type = NULL, metric = NULL) {
  df_filtered <- df[df$valid_pair == TRUE, ]
  
  if (is.null(task_type)) {
    task_type <- df_filtered$task_type[1]
  }
  if (is.null(metric)) {
    metric <- df_filtered$metric_name[1]
  }
  
  df_plot <- df_filtered %>%
    dplyr::filter(task_type == !!task_type, metric_name == !!metric)
  
  ci_data <- df_plot %>%
    dplyr::group_by(single_model_name, ensemble_model_name) %>%
    dplyr::summarise(
      mean = mean(difference_value, na.rm = TRUE),
      se = sd(difference_value, na.rm = TRUE) / sqrt(dplyr::n()),
      lower = mean - 1.96 * se,
      upper = mean + 1.96 * se,
      .groups = "drop"
    ) %>%
    dplyr::mutate(label = paste0(single_model_name, " -> ", ensemble_model_name))
  
  p_forest <- ggplot2::ggplot(ci_data, ggplot2::aes(x = mean, y = label,
                                                xmin = lower, xmax = upper)) +
    ggplot2::geom_pointrange() +
    ggplot2::geom_vline(xintercept = 0, linetype = "dashed", color = "red") +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = paste0("Effect Sizes with 95% CI: ", task_type, "-", metric),
      x = "Mean Difference (positive = ensemble better)",
      y = NULL
    ) +
    ggplot2::theme_minimal(base_size = 14)
  
  output_file <- file.path(output_dir, paste0("forest_plot_", task_type, "_", metric, ".png"))
  ggplot2::ggsave(output_file, p_forest, width = 10, height = 6, dpi = 300)
  
  output_file
}

create_violin_plot <- function(df, output_dir, task_type = NULL, metric = NULL) {
  df_filtered <- df[df$valid_pair == TRUE, ]
  
  if (is.null(task_type)) {
    task_type <- df_filtered$task_type[1]
  }
  if (is.null(metric)) {
    metric <- df_filtered$metric_name[1]
  }
  
  df_plot <- df_filtered %>%
    dplyr::filter(task_type == !!task_type, metric_name == !!metric)
  
  p_violin <- ggplot2::ggplot(df_plot, ggplot2::aes(x = metric_name, y = difference_value, fill = metric_name)) +
    ggplot2::geom_violin(alpha = 0.5, trim = FALSE) +
    ggplot2::geom_boxplot(width = 0.15, alpha = 0.8, outlier.shape = NA) +
    ggplot2::geom_jitter(width = 0.1, alpha = 0.1, size = 0.5) +
    ggplot2::geom_hline(yintercept = 0, linetype = "dashed", color = "red", linewidth = 1) +
    ggplot2::coord_flip() +
    ggplot2::labs(
      title = paste0("Distribution of Ensemble - Single Differences: ", task_type, "-", metric),
      x = NULL,
      y = "Difference (positive = ensemble better)"
    ) +
    ggplot2::theme_minimal(base_size = 14) +
    ggplot2::theme(legend.position = "none")
  
  output_file <- file.path(output_dir, paste0("violin_plot_", task_type, "_", metric, ".png"))
  ggplot2::ggsave(output_file, p_violin, width = 10, height = 6, dpi = 300)
  
  output_file
}
