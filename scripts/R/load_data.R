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
      
      if (file.info(zip_path)$size < 100) {
        stop(sprintf("Downloaded file too small - likely an error page: %s", ds_cfg$id))
      }
      
      utils::unzip(zip_path, exdir = temp_dir)
      files <- list.files(temp_dir, recursive = TRUE, full.names = TRUE)
      
      target_file <- NULL
      if (!is.null(ds_cfg$zip_file)) {
        target_file <- files[basename(files) == ds_cfg$zip_file][1]
      }
      
      if (is.null(target_file)) {
        csv_files <- files[grepl("\\.csv$", files, ignore.case = TRUE)]
        if (length(csv_files) > 0) {
          target_file <- csv_files[1]
        } else {
          txt_files <- files[grepl("\\.txt$", files, ignore.case = TRUE)]
          if (length(txt_files) > 0) {
            target_file <- txt_files[1]
          } else {
            xlsx_files <- files[grepl("\\.xlsx?$", files, ignore.case = TRUE)]
            if (length(xlsx_files) > 0) {
              target_file <- xlsx_files[1]
            }
          }
        }
      }
      
      if (!is.null(target_file)) {
        if (grepl("\\.txt$", target_file, ignore.case = TRUE)) {
          first_lines <- readLines(target_file, n = 3)
          sep <- if (any(grepl("\t", first_lines))) "\t" else ","
          df <- utils::read.table(target_file, header = FALSE, stringsAsFactors = FALSE, sep = sep)
          if (!is.null(ds_cfg$header_names)) {
            colnames(df) <- ds_cfg$header_names
          }
          write.csv(df, ds_cfg$path, row.names = FALSE)
        } else if (grepl("\\.xlsx?$", target_file, ignore.case = TRUE)) {
          if (!requireNamespace("readxl", quietly = TRUE)) {
            stop("Package 'readxl' required for Excel files")
          }
          df <- readxl::read_excel(target_file)
          write.csv(df, ds_cfg$path, row.names = FALSE)
        } else {
          file.copy(target_file, ds_cfg$path)
        }
      } else {
        stop(sprintf("No suitable file found in ZIP for dataset: %s", ds_cfg$id))
      }
    } else if (ext == "gz") {
      temp_file <- tempfile(fileext = ".gz")
      utils::download.file(ds_cfg$url, temp_file, mode = "wb", quiet = TRUE)
      if (file.info(temp_file)$size < 100) {
        stop(sprintf("Downloaded file too small - likely an error page: %s", ds_cfg$id))
      }
      R.utils::gunzip(temp_file, destname = ds_cfg$path, overwrite = TRUE, remove = TRUE)
    } else if (ext == "rar") {
      temp_dir <- tempfile()
      dir.create(temp_dir)
      on.exit(unlink(temp_dir, recursive = TRUE))
      rar_path <- paste0(temp_dir, "/data.rar")
      utils::download.file(ds_cfg$url, rar_path, mode = "wb", quiet = TRUE)
      if (file.info(rar_path)$size < 100) {
        stop(sprintf("Downloaded file too small - likely an error page: %s", ds_cfg$id))
      }
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
      if (file.info(temp_file)$size < 100) {
        stop(sprintf("Downloaded file too small - likely an error page: %s", ds_cfg$id))
      }
      if (!requireNamespace("readxl", quietly = TRUE)) {
        stop("Package 'readxl' required for Excel files")
      }
      df <- readxl::read_excel(temp_file)
      write.csv(df, ds_cfg$path, row.names = FALSE)
    } else if (ext == "data" || ext == "dat") {
      temp_file <- tempfile(fileext = paste0(".", ext))
      utils::download.file(ds_cfg$url, temp_file, mode = "wb", quiet = TRUE)
      if (file.info(temp_file)$size < 100) {
        stop(sprintf("Downloaded file too small - likely an error page: %s", ds_cfg$id))
      }
      sep <- if (!is.null(ds_cfg$separator)) ds_cfg$separator else ""
      df <- utils::read.table(temp_file, header = FALSE, stringsAsFactors = FALSE, sep = sep, strip.white = TRUE)
      if (!is.null(ds_cfg$header_names)) {
        colnames(df) <- ds_cfg$header_names
      } else {
        colnames(df) <- paste0("V", 1:ncol(df))
      }
      write.csv(df, ds_cfg$path, row.names = FALSE)
    } else {
      utils::download.file(ds_cfg$url, ds_cfg$path, mode = "wb", quiet = TRUE)
      if (file.info(ds_cfg$path)$size < 100) {
        stop(sprintf("Downloaded file too small - likely an error page: %s", ds_cfg$id))
      }
    }
  }
  
  ext <- tools::file_ext(ds_cfg$path)
  if (ext == "csv") {
    first_line <- readLines(ds_cfg$path, n = 1)
    sep <- if (!is.null(ds_cfg$separator)) ds_cfg$separator else if (grepl(";", first_line)) ";" else ","
    dec <- if (!is.null(ds_cfg$decimal)) ds_cfg$decimal else "."
    na_strings <- if (!is.null(ds_cfg$na_strings)) ds_cfg$na_strings else "NA"
    df <- utils::read.csv(ds_cfg$path, stringsAsFactors = FALSE, sep = sep, dec = dec, na.strings = na_strings)
    if (!is.null(ds_cfg$max_rows) && nrow(df) > ds_cfg$max_rows) {
      df <- tail(df, ds_cfg$max_rows)
    }
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
