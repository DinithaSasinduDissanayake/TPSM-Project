load_dataset <- function(ds_cfg, run_ctx) {
  if (!file.exists(ds_cfg$path)) {
    if (!nzchar(ds_cfg$url)) {
      stop(sprintf("Dataset not found and no URL provided: %s", ds_cfg$id))
    }
    dir.create(dirname(ds_cfg$path), recursive = TRUE, showWarnings = FALSE)
    
    ext <- tools::file_ext(ds_cfg$url)
    if (ext == "zip") {
      temp_dir <- tempfile()
      dir.create(temp_dir)
      on.exit(unlink(temp_dir, recursive = TRUE))
      zip_path <- paste0(temp_dir, "/data.zip")
      utils::download.file(ds_cfg$url, zip_path, mode = "wb", quiet = TRUE)
      utils::unzip(zip_path, exdir = temp_dir)
      files <- list.files(temp_dir, recursive = TRUE, full.names = TRUE)
      csv_files <- files[grepl("\\.csv$", files, ignore.case = TRUE)]
      if (length(csv_files) > 0) {
        file.copy(csv_files[1], ds_cfg$path)
      } else {
        stop(sprintf("No CSV found in ZIP for dataset: %s", ds_cfg$id))
      }
    } else if (ext == "gz") {
      temp_file <- tempfile(fileext = ".gz")
      utils::download.file(ds_cfg$url, temp_file, mode = "wb", quiet = TRUE)
      R.utils::gunzip(temp_file, destname = ds_cfg$path, overwrite = TRUE, remove = TRUE)
    } else if (ext == "rar") {
      temp_dir <- tempfile()
      dir.create(temp_dir)
      on.exit(unlink(temp_dir, recursive = TRUE))
      rar_path <- paste0(temp_dir, "/data.rar")
      utils::download.file(ds_cfg$url, rar_path, mode = "wb", quiet = TRUE)
      system2("unrar", c("x", "-o+", rar_path, temp_dir))
      files <- list.files(temp_dir, recursive = TRUE, full.names = TRUE)
      csv_files <- files[grepl("\\.csv$", files, ignore.case = TRUE)]
      data_files <- files[grepl("\\.data$", files, ignore.case = TRUE)]
      target_file <- if (length(csv_files) > 0) csv_files[1] else data_files[1]
      if (!is.na(target_file)) {
        if (grepl("\\.data$", target_file)) {
          df <- utils::read.table(target_file, header = FALSE, stringsAsFactors = FALSE, sep = ",")
          if (!is.null(ds_cfg$header_names)) {
            colnames(df) <- ds_cfg$header_names
          } else {
            colnames(df) <- paste0("V", 1:ncol(df))
          }
          write.csv(df, ds_cfg$path, row.names = FALSE)
        } else {
          file.copy(target_file, ds_cfg$path)
        }
      } else {
        stop(sprintf("No suitable file found in RAR for dataset: %s", ds_cfg$id))
      }
    } else if (ext == "xlsx" || ext == "xls") {
      temp_file <- tempfile(fileext = paste0(".", ext))
      utils::download.file(ds_cfg$url, temp_file, mode = "wb", quiet = TRUE)
      if (!requireNamespace("readxl", quietly = TRUE)) {
        stop("Package 'readxl' required for Excel files")
      }
      df <- readxl::read_excel(temp_file)
      write.csv(df, ds_cfg$path, row.names = FALSE)
    } else if (ext == "data" || ext == "dat") {
      temp_file <- tempfile(fileext = paste0(".", ext))
      utils::download.file(ds_cfg$url, temp_file, mode = "wb", quiet = TRUE)
      df <- utils::read.table(temp_file, header = FALSE, stringsAsFactors = FALSE, sep = "")
      if (!is.null(ds_cfg$header_names)) {
        colnames(df) <- ds_cfg$header_names
      } else {
        colnames(df) <- paste0("V", 1:ncol(df))
      }
      write.csv(df, ds_cfg$path, row.names = FALSE)
    } else {
      utils::download.file(ds_cfg$url, ds_cfg$path, mode = "wb", quiet = TRUE)
    }
  }

  ext <- tools::file_ext(ds_cfg$path)
  if (ext == "csv") {
    first_line <- readLines(ds_cfg$path, n = 1)
    sep <- if (grepl(";", first_line)) ";" else ","
    df <- utils::read.csv(ds_cfg$path, stringsAsFactors = FALSE, sep = sep)
  } else if (ext == "xlsx" || ext == "xls") {
    if (!requireNamespace("readxl", quietly = TRUE)) {
      stop("Package 'readxl' required for Excel files")
    }
    df <- readxl::read_excel(ds_cfg$path)
  } else {
    df <- utils::read.csv(ds_cfg$path, stringsAsFactors = FALSE)
  }
  
  if (!ds_cfg$target %in% names(df)) {
    stop(sprintf("Target column '%s' not found for dataset '%s'", ds_cfg$target, ds_cfg$id))
  }

  log_event(run_ctx, "info", "dataset_loaded", list(dataset = ds_cfg$id, rows = nrow(df), cols = ncol(df)))
  df
}
