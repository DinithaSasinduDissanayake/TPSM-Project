load_dataset <- function(ds_cfg, run_ctx) {
  if (!file.exists(ds_cfg$path)) {
    if (!nzchar(ds_cfg$url)) {
      stop(sprintf("Dataset not found and no URL provided: %s", ds_cfg$id))
    }
    dir.create(dirname(ds_cfg$path), recursive = TRUE, showWarnings = FALSE)
    utils::download.file(ds_cfg$url, ds_cfg$path, mode = "wb", quiet = TRUE)
  }

  df <- utils::read.csv(ds_cfg$path, stringsAsFactors = FALSE)
  if (!ds_cfg$target %in% names(df)) {
    stop(sprintf("Target column '%s' not found for dataset '%s'", ds_cfg$target, ds_cfg$id))
  }

  log_event(run_ctx, "info", "dataset_loaded", list(dataset = ds_cfg$id, rows = nrow(df), cols = ncol(df)))
  df
}
