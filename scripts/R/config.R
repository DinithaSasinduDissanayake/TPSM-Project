parse_args <- function(args) {
  out <- list(output_dir = "outputs", task_filter = NULL)
  if (length(args) == 0) return(out)

  i <- 1
  while (i <= length(args)) {
    key <- args[[i]]
    val <- if (i < length(args)) args[[i + 1]] else NULL
    if (key == "--output-dir") {
      out$output_dir <- val
      i <- i + 2
    } else if (key == "--task") {
      out$task_filter <- val
      i <- i + 2
    } else {
      i <- i + 1
    }
  }
  out
}

get_config <- function() {
  list(
    stop_on_first_fail = TRUE,
    tasks = list(
      list(
        name = "classification",
        split = list(method = "repeated_kfold", folds = 10, repeats = 5),
        metrics = c("accuracy", "precision", "recall", "f1", "roc_auc", "logloss"),
        datasets = list(
          list(id = "heart_disease", source = "uci", path = "data/classification/heart_disease.csv", url = "https://archive.ics.uci.edu/static/public/45/data.csv", target = "num"),
          list(id = "breast_cancer", source = "uci", path = "data/classification/breast_cancer.csv", url = "https://archive.ics.uci.edu/static/public/17/data.csv", target = "Diagnosis"),
          list(id = "bank_marketing", source = "uci", path = "data/classification/bank_marketing.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00222/bank.zip", target = "y", exclude_cols = c("duration")),
          list(id = "adult_census", source = "uci", path = "data/classification/adult_census.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/adult/adult.data", target = "income", header_names = c("age", "workclass", "fnlwg", "education", "education_num", "marital_status", "occupation", "relationship", "race", "sex", "capital_gain", "capital_loss", "hours_per_week", "native_country", "income")),
          list(id = "magic_gamma", source = "uci", path = "data/classification/magic_gamma.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/magic/magic04.data", target = "class", header_names = c("fLength", "fWidth", "fSize", "fConc", "fConc1", "fAsym", "fM3Long", "fM3Trans", "fAlpha", "fDist")),
          list(id = "letter_recognition", source = "uci", path = "data/classification/letter_recognition.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/letter-recognition/letter-recognition.data", target = "lettr", header_names = c("lettr", "x_box", "y_box", "width", "high", "onpix", "x_bar", "y_bar", "x2bar", "y2bar", "xybar", "x2ybr", "xy2br", "x_ege", "xegvy", "y_ege", "yegvx")),
          list(id = "german_credit", source = "uci", path = "data/classification/german_credit.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/statlog/german/german.data", target = "Risk", header_names = c("Status", "Duration", "CreditHistory", "Purpose", "CreditAmount", "Savings", "Employment", "InstallmentRate", "Residence", "Housing", "ExistingCredits", "Job", "Dependents", "Telephone", "Foreign", "Risk")),
          list(id = "online_shoppers", source = "uci", path = "data/classification/online_shoppers.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00468/online_shoppers_intention.csv", target = "Revenue"),
          list(id = "dry_bean", source = "uci", path = "data/classification/dry_bean.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00602/Dry_Bean_Dataset.xlsx", target = "Class"),
          list(id = "avila", source = "uci", path = "data/classification/avila.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00459/Avila.zip", target = "F10")
        ),
        model_pairs = list(
          list(single = "logistic_regression", ensemble = "gradient_boosting"),
          list(single = "decision_tree", ensemble = "adaboost"),
          list(single = "naive_bayes", ensemble = "gradient_boosting")
        )
      ),
      list(
        name = "regression",
        split = list(method = "repeated_kfold", folds = 10, repeats = 5),
        metrics = c("rmse", "mae", "r2", "mape"),
        datasets = list(
          list(id = "insurance", source = "kaggle", path = "data/regression/insurance.csv", url = "https://raw.githubusercontent.com/stedy/Machine-Learning-with-R-datasets/master/insurance.csv", target = "charges"),
          list(id = "housing_prices", source = "kaggle", path = "data/regression/housing_prices.csv", url = "https://raw.githubusercontent.com/datasets/house-prices-uk/main/data/data.csv", target = "Price..All."),
          list(id = "wine_quality", source = "uci", path = "data/regression/wine_quality.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/wine-quality/winequality-red.csv", target = "quality"),
          list(id = "abalone", source = "uci", path = "data/regression/abalone.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/abalone/abalone.data", target = "Rings", header_names = c("Sex", "Length", "Diameter", "Height", "Whole_weight", "Shucked_weight", "Viscera_weight", "Shell_weight", "Rings")),
          list(id = "concrete_strength", source = "uci", path = "data/regression/concrete_strength.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/concrete/compressive/Concrete_Compressive_Strength.xls", target = "Strength"),
          list(id = "ccpp", source = "uci", path = "data/regression/ccpp.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00294/CCPP.zip", target = "PE"),
          list(id = "bike_sharing", source = "uci", path = "data/regression/bike_sharing.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00275/Bike-Sharing-Dataset.zip", target = "cnt", exclude_cols = c("casual", "registered")),
          list(id = "energy_efficiency", source = "uci", path = "data/regression/energy_efficiency.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00242/ENB2012_data.xlsx", target = "Y1"),
          list(id = "airfoil", source = "uci", path = "data/regression/airfoil.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00291/airfoil_self_noise.dat", target = "ScaledSoundPressureLevel", header_names = c("Frequency", "AngleOfAttack", "ChordLength", "FreeStreamVelocity", "SuctionSideDisplacement", "ScaledSoundPressureLevel"))
        ),
        model_pairs = list(
          list(single = "linear_regression", ensemble = "gradient_boosting_regressor"),
          list(single = "decision_tree_regressor", ensemble = "gradient_boosting_regressor"),
          list(single = "svr", ensemble = "gradient_boosting_regressor")
        )
      ),
      list(
        name = "timeseries",
        split = list(method = "rolling_origin", splits = 10),
        metrics = c("rmse", "mae", "mape", "smape"),
        datasets = list(
          list(id = "melbourne_temp", source = "other", path = "data/timeseries/melbourne_temp.csv", url = "https://raw.githubusercontent.com/jbrownlee/Datasets/master/daily-min-temperatures.csv", target = "Temp", time_col = "Date"),
          list(id = "electric_production", source = "other", path = "data/timeseries/electric_production.csv", url = "https://raw.githubusercontent.com/Rudra-23/Electric-Production-Forecast/main/Electric_Production.csv", target = "Value", time_col = "DATE"),
          list(id = "air_quality", source = "uci", path = "data/timeseries/air_quality.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00360/AirQualityUCI.zip", target = "CO2", time_col = "Date", exog_cols = c("NO2", "Temperature")),
          list(id = "beijing_pm25", source = "uci", path = "data/timeseries/beijing_pm25.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00381/PRSA_data_2010.1.1-2014.12.31.csv", target = "pm2.5", time_col = "date", exog_cols = c("TEMP", "PRES")),
          list(id = "metro_traffic", source = "uci", path = "data/timeseries/metro_traffic.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00492/Metro_Interstate_Traffic_Volume.csv.gz", target = "traffic_volume", time_col = "date_time", exog_cols = c("holiday", "temp")),
          list(id = "household_power", source = "uci", path = "data/timeseries/household_power.csv", url = "https://archive.ics.uci.edu/ml/machine-learning-databases/00235/household_power_consumption.zip", target = "Global_active_power", time_col = "Date", exog_cols = c("Global_reactive_power", "Voltage"))
        ),
        model_pairs = list(
          list(single = "arima", ensemble = "gbm_lag"),
          list(single = "exp_smoothing", ensemble = "gbm_lag")
        )
      )
    )
  )
}
