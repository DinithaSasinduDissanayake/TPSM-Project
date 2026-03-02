train_predict_classification <- function(model_name, train_df, test_df, target_col) {
  y_train <- as.factor(train_df[[target_col]])
  y_test <- test_df[[target_col]]
  n_classes <- length(levels(y_train))
  is_binary <- n_classes == 2

  train_x <- train_df[setdiff(names(train_df), target_col)]
  test_x <- test_df[setdiff(names(test_df), target_col)]

  if (model_name == "logistic_regression") {
    if (is_binary) {
      fit <- stats::glm(as.formula(paste(target_col, "~ .")), data = train_df, family = stats::binomial())
      prob <- stats::predict(fit, newdata = test_df, type = "response")
      pred <- ifelse(prob >= 0.5, levels(y_train)[2], levels(y_train)[1])
      return(list(pred = pred, prob = prob))
    } else {
      if (!requireNamespace("nnet", quietly = TRUE)) stop("Package 'nnet' required for multiclass")
      fit <- nnet::nnet(as.formula(paste(target_col, "~ .")), data = train_df, size = 5, linout = FALSE, trace = FALSE)
      prob <- stats::predict(fit, newdata = test_df)
      pred <- levels(y_train)[max.col(prob)]
      return(list(pred = pred, prob = prob))
    }
  }

  if (model_name == "decision_tree") {
    if (!requireNamespace("rpart", quietly = TRUE)) stop("Package 'rpart' required")
    fit <- rpart::rpart(as.formula(paste(target_col, "~ .")), data = train_df, method = "class")
    if (is_binary) {
      prob <- stats::predict(fit, newdata = test_df, type = "prob")[, 2]
      pred <- ifelse(prob >= 0.5, levels(y_train)[2], levels(y_train)[1])
    } else {
      prob <- stats::predict(fit, newdata = test_df, type = "prob")
      pred <- levels(y_train)[max.col(prob)]
    }
    return(list(pred = pred, prob = prob))
  }

  if (model_name == "naive_bayes") {
    if (!requireNamespace("e1071", quietly = TRUE)) stop("Package 'e1071' required")
    fit <- e1071::naiveBayes(x = train_x, y = y_train)
    prob <- stats::predict(fit, newdata = test_x, type = "raw")
    if (is_binary) {
      pred <- ifelse(prob[, 2] >= 0.5, levels(y_train)[2], levels(y_train)[1])
    } else {
      pred <- levels(y_train)[max.col(prob)]
    }
    return(list(pred = pred, prob = prob))
  }

  if (model_name == "gradient_boosting") {
    if (!requireNamespace("gbm", quietly = TRUE)) stop("Package 'gbm' required")
    train_tmp <- train_df
    if (is_binary) {
      train_tmp[[target_col]] <- as.numeric(as.factor(train_tmp[[target_col]])) - 1
      dist <- "bernoulli"
    } else {
      train_tmp[[target_col]] <- as.numeric(as.factor(train_tmp[[target_col]])) - 1
      dist <- "multinomial"
    }
    fit <- gbm::gbm(as.formula(paste(target_col, "~ .")), data = train_tmp, distribution = dist, n.trees = 100, interaction.depth = 3, shrinkage = 0.05, n.minobsinnode = 10, verbose = FALSE)
    if (is_binary) {
      prob <- stats::predict(fit, newdata = test_df, n.trees = 100, type = "response")
      pred <- ifelse(prob >= 0.5, levels(y_train)[2], levels(y_train)[1])
    } else {
      prob <- stats::predict(fit, newdata = test_df, n.trees = 100, type = "response")
      pred <- levels(y_train)[max.col(prob)]
    }
    return(list(pred = pred, prob = prob))
  }

  if (model_name == "adaboost") {
    if (!requireNamespace("ada", quietly = TRUE)) stop("Package 'ada' required")
    if (!is_binary) stop("adaboost package only supports binary classification")
    fit <- ada::ada(as.formula(paste(target_col, "~ .")), data = train_df, iter = 50, type = "real")
    prob <- as.numeric(stats::predict(fit, newdata = test_df, type = "probs")[, 2])
    pred <- ifelse(prob >= 0.5, levels(y_train)[2], levels(y_train)[1])
    return(list(pred = pred, prob = prob))
  }

  stop(sprintf("Unsupported classification model: %s", model_name))
}
