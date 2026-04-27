train_predict_regression <- function(model_name, train_df, test_df, target_col) {
  y_train <- train_df[[target_col]]
  train_x <- train_df[setdiff(names(train_df), target_col)]
  test_x <- test_df[setdiff(names(test_df), target_col)]

  if (model_name == "linear_regression") {
    fit <- stats::lm(as.formula(paste(target_col, "~ .")), data = train_df)
    pred <- stats::predict(fit, newdata = test_df)
    return(pred)
  }

  if (model_name == "decision_tree_regressor") {
    if (!requireNamespace("rpart", quietly = TRUE)) stop("Package 'rpart' required")
    fit <- rpart::rpart(as.formula(paste(target_col, "~ .")), data = train_df, method = "anova")
    pred <- stats::predict(fit, newdata = test_df)
    return(pred)
  }

  if (model_name == "svr") {
    if (!requireNamespace("e1071", quietly = TRUE)) stop("Package 'e1071' required")
    fit <- e1071::svm(x = train_x, y = y_train, type = "eps-regression")
    pred <- stats::predict(fit, newdata = test_x)
    return(pred)
  }

  if (model_name == "gradient_boosting_regressor") {
    if (!requireNamespace("gbm", quietly = TRUE)) stop("Package 'gbm' required")
    fit <- gbm::gbm(as.formula(paste(target_col, "~ .")), data = train_df, distribution = "gaussian", n.trees = 100, interaction.depth = 3, shrinkage = 0.05, n.minobsinnode = 10, verbose = FALSE)
    pred <- stats::predict(fit, newdata = test_df, n.trees = 100)
    return(pred)
  }

  stop(sprintf("Unsupported regression model: %s", model_name))
}
