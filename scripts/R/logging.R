init_run_context <- function(cfg, output_root = "outputs") {
  run_id <- format(Sys.time(), "%Y%m%dT%H%M%S")
  out_dir <- file.path(output_root, run_id)
  dir.create(out_dir, recursive = TRUE, showWarnings = FALSE)

  manifest <- list(
    run_id = run_id,
    started_at_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
    stop_on_first_fail = cfg$stop_on_first_fail,
    config = cfg
  )
  jsonlite::write_json(manifest, file.path(out_dir, "run_manifest.json"), auto_unbox = TRUE, pretty = TRUE)

  state <- new.env(parent = emptyenv())
  state$warnings <- list()

  list(run_id = run_id, out_dir = out_dir, log_file = file.path(out_dir, "run_log.txt"), state = state)
}

log_event <- function(run_ctx, level, event, payload = list()) {
  entry <- list(
    timestamp_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
    level = level,
    event = event,
    payload = payload
  )
  line <- jsonlite::toJSON(entry, auto_unbox = TRUE)
  cat(line, "\n", file = run_ctx$log_file, append = TRUE)
}

write_error_report <- function(run_ctx, msg, context = list()) {
  report <- list(
    run_id = run_ctx$run_id,
    timestamp_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
    message = msg,
    context = context
  )
  jsonlite::write_json(report, file.path(run_ctx$out_dir, "error_report.json"), auto_unbox = TRUE, pretty = TRUE)
}

log_warning <- function(run_ctx, msg, context = list()) {
  entry <- list(
    timestamp_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
    message = as.character(msg),
    context = context
  )

  run_ctx$state$warnings[[length(run_ctx$state$warnings) + 1]] <- entry
  log_event(run_ctx, "warning", "warning", c(list(message = entry$message), context))
}

write_warnings_reports <- function(run_ctx) {
  warnings_list <- run_ctx$state$warnings

  report <- list(
    run_id = run_ctx$run_id,
    generated_at_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
    total_warnings = length(warnings_list),
    warnings = warnings_list
  )
  jsonlite::write_json(report, file.path(run_ctx$out_dir, "warnings_report.json"), auto_unbox = TRUE, pretty = TRUE)

  if (length(warnings_list) == 0) {
    summary_report <- list(
      run_id = run_ctx$run_id,
      generated_at_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
      groups = list()
    )
    jsonlite::write_json(summary_report, file.path(run_ctx$out_dir, "warnings_summary.json"), auto_unbox = TRUE, pretty = TRUE)
    return(invisible(NULL))
  }

  keys <- vapply(
    warnings_list,
    function(w) {
      paste(
        w$message,
        ifelse(is.null(w$context$task), "", w$context$task),
        ifelse(is.null(w$context$dataset), "", w$context$dataset),
        ifelse(is.null(w$context$model_name), "", w$context$model_name),
        ifelse(is.null(w$context$stage), "", w$context$stage),
        sep = "||"
      )
    },
    character(1)
  )

  counts <- sort(table(keys), decreasing = TRUE)
  grouped <- lapply(names(counts), function(k) {
    idx <- which(keys == k)[1]
    first <- warnings_list[[idx]]
    list(
      count = as.integer(counts[[k]]),
      message = first$message,
      task = ifelse(is.null(first$context$task), NA_character_, first$context$task),
      dataset = ifelse(is.null(first$context$dataset), NA_character_, first$context$dataset),
      model_name = ifelse(is.null(first$context$model_name), NA_character_, first$context$model_name),
      stage = ifelse(is.null(first$context$stage), NA_character_, first$context$stage)
    )
  })

  summary_report <- list(
    run_id = run_ctx$run_id,
    generated_at_utc = format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ"),
    groups = grouped
  )
  jsonlite::write_json(summary_report, file.path(run_ctx$out_dir, "warnings_summary.json"), auto_unbox = TRUE, pretty = TRUE)
}
