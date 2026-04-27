archive_old_complete_runs <- function(output_root, keep_run_id) {
  if (!dir.exists(output_root)) {
    return(character(0))
  }

  root_parts <- strsplit(normalizePath(output_root, mustWork = FALSE), .Platform$file.sep, fixed = TRUE)[[1]]
  runner_name <- basename(output_root)
  parent_name <- basename(dirname(output_root))
  if (identical(parent_name, "active")) {
    archive_root <- file.path(dirname(dirname(output_root)), "archive", runner_name)
  } else {
    archive_root <- file.path(output_root, "archive")
  }
  dir.create(archive_root, recursive = TRUE, showWarnings = FALSE)

  required <- c("model_runs.csv", "pairwise_differences.csv", "run_manifest.json")
  moved <- character(0)
  children <- list.dirs(output_root, full.names = TRUE, recursive = FALSE)
  for (child in children) {
    run_id <- basename(child)
    if (run_id %in% c("active", "archive") || identical(run_id, keep_run_id)) {
      next
    }
    if (file.exists(file.path(child, "PAUSE")) || file.exists(file.path(child, "STOP"))) {
      next
    }
    if (!all(file.exists(file.path(child, required)))) {
      next
    }

    dest <- file.path(archive_root, run_id)
    if (dir.exists(dest)) {
      i <- 1
      repeat {
        candidate <- file.path(archive_root, paste0(run_id, "_", i))
        if (!dir.exists(candidate)) {
          dest <- candidate
          break
        }
        i <- i + 1
      }
    }
    file.rename(child, dest)
    moved <- c(moved, dest)
  }
  moved
}
