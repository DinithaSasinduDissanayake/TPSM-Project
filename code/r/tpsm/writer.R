to_df <- function(rows) {
  if (length(rows) == 0) return(data.frame())
  dplyr::bind_rows(lapply(rows, as.data.frame))
}

write_outputs <- function(run_ctx, model_rows, pair_rows) {
  model_df <- to_df(model_rows)
  pair_df <- to_df(pair_rows)

  utils::write.csv(model_df, file.path(run_ctx$out_dir, "model_runs.csv"), row.names = FALSE)
  utils::write.csv(pair_df, file.path(run_ctx$out_dir, "pairwise_differences.csv"), row.names = FALSE)
}

write_partial_outputs <- function(run_ctx, model_rows, pair_rows) {
  model_df <- to_df(model_rows)
  pair_df <- to_df(pair_rows)
  if (nrow(model_df) > 0) {
    utils::write.csv(model_df, file.path(run_ctx$out_dir, "model_runs.partial.csv"), row.names = FALSE)
  }
  if (nrow(pair_df) > 0) {
    utils::write.csv(pair_df, file.path(run_ctx$out_dir, "pairwise_differences.partial.csv"), row.names = FALSE)
  }
}
