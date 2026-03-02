make_splits <- function(task_name, df, split_cfg, target_col = NULL) {
  set.seed(42)
  if (split_cfg$method == "repeated_kfold") {
    use_stratify <- task_name == "classification" && !is.null(target_col) && target_col %in% names(df)
    return(make_repeated_kfold_splits(df, target_col, split_cfg$folds, split_cfg$repeats, use_stratify))
  }
  if (split_cfg$method == "rolling_origin") {
    return(make_rolling_splits(nrow(df), split_cfg$splits))
  }
  stop(sprintf("Unsupported split method: %s", split_cfg$method))
}

make_repeated_kfold_splits <- function(df, target_col, k, repeats, use_stratify = FALSE) {
  splits <- list()
  idx <- 1
  n <- nrow(df)
  y <- NULL
  if (use_stratify && !is.null(target_col) && target_col %in% names(df)) {
    y <- df[[target_col]]
    if (length(unique(y)) > 20) {
      y <- NULL
    }
  }
  for (r in seq_len(repeats)) {
    if (is.null(y)) {
      fold_ids <- sample(rep(seq_len(k), length.out = n))
    } else {
      fold_ids <- integer(n)
      classes <- unique(y)
      for (cls in classes) {
        idxs <- which(y == cls)
        fold_ids[idxs] <- sample(rep(seq_len(k), length.out = length(idxs)))
      }
    }
    for (f in seq_len(k)) {
      test_idx <- which(fold_ids == f)
      train_idx <- setdiff(seq_len(n), test_idx)
      splits[[idx]] <- list(train_idx = train_idx, test_idx = test_idx, fold = f, repeat_id = r, n_folds = k, split_method = "repeated_kfold")
      idx <- idx + 1
    }
  }
  splits
}

make_rolling_splits <- function(n, n_splits) {
  initial <- max(30, floor(n * 0.6))
  horizon <- max(1, floor((n - initial) / n_splits))
  if (initial + horizon > n) stop("Not enough rows for rolling splits")

  splits <- list()
  for (i in seq_len(n_splits)) {
    train_end <- initial + (i - 1) * horizon
    test_start <- train_end + 1
    test_end <- min(n, test_start + horizon - 1)
    if (test_start > n) break
    splits[[length(splits) + 1]] <- list(
      train_idx = seq_len(train_end),
      test_idx = seq(test_start, test_end),
      fold = i,
      repeat_id = 1,
      n_folds = n_splits,
      split_method = "rolling_origin"
    )
  }
  splits
}
