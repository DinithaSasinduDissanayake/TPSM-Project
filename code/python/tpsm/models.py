"""TPSM Pipeline - Model training and prediction."""

import warnings
import numpy as np
import pandas as pd


def _prepare_features(df, target, ds_cfg, task_name):
    """Prepare feature matrix X and target vector y from a dataframe.

    Matches R pipeline behaviour:
    - One-hot encodes categorical (object/string) columns
      (equivalent to R's model.matrix / formula interface)
    - Fills remaining NaN with column median
    """
    y = df[target].values
    drop_cols = [target]
    if task_name == "timeseries":
        time_col = ds_cfg.get("time_col")
        if time_col and time_col in df.columns:
            drop_cols.append(time_col)
    X = df.drop(columns=drop_cols, errors="ignore")

    # One-hot encode categorical (object / string) columns — mirrors R model.matrix()
    cat_cols = X.select_dtypes(include=["object", "category", "string"]).columns
    if len(cat_cols) > 0:
        X = pd.get_dummies(X, columns=cat_cols, drop_first=True, dtype=float)

    # Ensure all columns are numeric after encoding
    X = X.select_dtypes(include=[np.number])
    # Handle NaN — fill with column median
    X = X.fillna(X.median())
    return X, y


# =============================================================================
# Classification Models
# =============================================================================


def train_logistic_regression(X_train, y_train, **kwargs):
    from sklearn.linear_model import LogisticRegression
    from sklearn.pipeline import make_pipeline
    from sklearn.preprocessing import StandardScaler

    # Scale features before LBFGS to avoid slow/unstable convergence on mixed-scale inputs.
    m = make_pipeline(
        StandardScaler(),
        LogisticRegression(max_iter=1000, solver="lbfgs", random_state=42),
    )
    m.fit(X_train, y_train)
    return m


def train_decision_tree_clf(X_train, y_train, **kwargs):
    from sklearn.tree import DecisionTreeClassifier

    m = DecisionTreeClassifier(random_state=42)
    m.fit(X_train, y_train)
    return m


def train_naive_bayes(X_train, y_train, **kwargs):
    from sklearn.naive_bayes import GaussianNB

    m = GaussianNB()
    m.fit(X_train, y_train)
    return m


def train_gradient_boosting_clf(X_train, y_train, **kwargs):
    from sklearn.ensemble import HistGradientBoostingClassifier

    m = HistGradientBoostingClassifier(
        max_iter=100, max_depth=3, learning_rate=0.05, random_state=42
    )
    m.fit(X_train, y_train)
    return m


def train_random_forest_clf(X_train, y_train, **kwargs):
    from sklearn.ensemble import RandomForestClassifier

    m = RandomForestClassifier(
        n_estimators=200,
        max_depth=None,
        min_samples_leaf=1,
        n_jobs=1,
        random_state=42,
    )
    m.fit(X_train, y_train)
    return m


def train_adaboost(X_train, y_train, **kwargs):
    from sklearn.ensemble import AdaBoostClassifier

    m = AdaBoostClassifier(n_estimators=50, random_state=42)
    m.fit(X_train, y_train)
    return m


def train_svm_clf(X_train, y_train, **kwargs):
    from sklearn.svm import SVC

    m = SVC(probability=True, random_state=42, class_weight="balanced")
    m.fit(X_train, y_train)
    return m


# =============================================================================
# Regression Models
# =============================================================================


def train_linear_regression(X_train, y_train, **kwargs):
    from sklearn.linear_model import LinearRegression

    m = LinearRegression()
    m.fit(X_train, y_train)
    return m


def train_decision_tree_reg(X_train, y_train, **kwargs):
    from sklearn.tree import DecisionTreeRegressor

    m = DecisionTreeRegressor(random_state=42)
    m.fit(X_train, y_train)
    return m


def train_svr(X_train, y_train, **kwargs):
    from sklearn.svm import SVR
    from sklearn.preprocessing import StandardScaler
    from sklearn.pipeline import make_pipeline

    # SVR is O(n²) — cap training data for feasibility
    MAX_SVR_ROWS = 5000
    if len(y_train) > MAX_SVR_ROWS:
        idx = np.random.RandomState(42).choice(
            len(y_train), MAX_SVR_ROWS, replace=False
        )
        X_train = X_train[idx]
        y_train = y_train[idx]
    m = make_pipeline(StandardScaler(), SVR())
    m.fit(X_train, y_train)
    return m


def train_gradient_boosting_reg(X_train, y_train, **kwargs):
    from sklearn.ensemble import HistGradientBoostingRegressor

    m = HistGradientBoostingRegressor(
        max_iter=400,
        max_depth=None,
        learning_rate=0.05,
        min_samples_leaf=20,
        l2_regularization=0.0,
        random_state=42,
    )
    m.fit(X_train, y_train)
    return m


# =============================================================================
# Timeseries Models
# =============================================================================


def train_arima(y_train, exog_train=None, **kwargs):
    """Fit ARIMA using auto_arima (equivalent to R's auto.arima)."""
    import pmdarima as pm

    max_order = kwargs.get("arima_max_order")
    if max_order is None:
        max_order = 5
    stepwise = kwargs.get("arima_stepwise")
    if stepwise is None:
        stepwise = True
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        try:
            model = pm.auto_arima(
                y_train,
                exogenous=exog_train,
                stepwise=stepwise,
                suppress_warnings=True,
                error_action="ignore",
                max_order=max_order,
                seasonal=False,
            )
            return model
        except Exception:
            from statsmodels.tsa.arima.model import ARIMA

            model = ARIMA(y_train, order=(1, 0, 0), exog=exog_train)
            return model.fit()


def predict_arima(model, n_steps, exog_test=None):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        model_module = type(model).__module__
        if "pmdarima" in model_module:
            return model.predict(n_periods=n_steps, exogenous=exog_test)
        return model.forecast(steps=n_steps, exog=exog_test)


def train_exp_smoothing(y_train, **kwargs):
    """Simple exponential smoothing — matches R's HoltWinters(beta=FALSE, gamma=FALSE)."""
    from statsmodels.tsa.holtwinters import ExponentialSmoothing

    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        model = ExponentialSmoothing(y_train, trend=None, seasonal=None)
        return model.fit(optimized=True)


def predict_exp_smoothing(model, n_steps):
    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        return model.forecast(n_steps)


def train_gbm_lag(y_train, exog_train=None, n_lags=12, exog_max_lag=6, **kwargs):
    """Train a GBM on lagged features.

    Matches R: make_lag_matrix(y, max_lag=12, exog, exog_max_lag=6)
    """
    from sklearn.ensemble import GradientBoostingRegressor

    n = len(y_train)
    if n <= n_lags + 1:
        raise ValueError(f"Not enough data for GBM lag: {n} rows, {n_lags} lags")

    # Build lag matrix — mirrors R's make_lag_matrix()
    data = []
    targets = []
    start = max(n_lags, exog_max_lag if exog_train is not None else 0)
    for i in range(start, n):
        # Target lags (lag_1 .. lag_n_lags)
        row = [y_train[i - j] for j in range(1, n_lags + 1)]
        # Exogenous lags (col_lag_1 .. col_lag_exog_max_lag for each exog column)
        if exog_train is not None:
            ex_row = (
                exog_train[i] if hasattr(exog_train[i], "__len__") else [exog_train[i]]
            )
            n_exog = len(ex_row)
            for c in range(n_exog):
                for lag in range(1, exog_max_lag + 1):
                    row.append(
                        exog_train[i - lag][c]
                        if hasattr(exog_train[i - lag], "__getitem__")
                        else exog_train[i - lag]
                    )
        data.append(row)
        targets.append(y_train[i])

    X = np.array(data)
    y = np.array(targets)
    m = GradientBoostingRegressor(
        n_estimators=100, max_depth=3, learning_rate=0.05, random_state=42
    )
    m.fit(X, y)
    return m, n_lags, (exog_max_lag if exog_train is not None else 0)


def predict_gbm_lag(model_tuple, y_history, n_steps, exog_test=None):
    """Recursive forecasting with GBM on lagged features.

    Mirrors R's recursive one-step-ahead approach with lagged exog.
    """
    model, n_lags, exog_max_lag = model_tuple
    preds = []
    history = list(y_history[-n_lags:])

    # Build exog history from the tail of training exog if available
    # For prediction we need the last exog_max_lag rows from history
    # plus the test exog for building lags
    exog_history = []
    if exog_test is not None and exog_max_lag > 0:
        # We don't have train exog here, so use zeros for initial lags
        # then fill from exog_test as we step forward
        n_exog = len(exog_test[0]) if hasattr(exog_test[0], "__len__") else 1
        exog_history = [[0.0] * n_exog] * exog_max_lag

    for i in range(n_steps):
        row = [history[-(j + 1)] for j in range(n_lags)]
        if exog_test is not None and exog_max_lag > 0 and i < len(exog_test):
            # Add current exog to history
            ex = exog_test[i]
            ex_list = (
                ex.tolist()
                if hasattr(ex, "tolist")
                else ([ex] if not hasattr(ex, "__len__") else list(ex))
            )
            exog_history.append(ex_list)
            # Add lagged exog features
            n_exog = len(ex_list)
            for c in range(n_exog):
                for lag in range(1, exog_max_lag + 1):
                    idx = len(exog_history) - 1 - lag
                    row.append(exog_history[idx][c] if idx >= 0 else 0.0)
        pred = model.predict([row])[0]
        preds.append(pred)
        history.append(pred)

    return np.array(preds)


# =============================================================================
# Model Registry
# =============================================================================

MODEL_ALIASES = {
    "gradient_boosting": "gradient_boosting",
    "gbm": "gradient_boosting",
    "random_forest": "random_forest",
    "rf": "random_forest",
    "adaboost": "adaboost",
    "ada": "adaboost",
    "gradient_boosting_regressor": "gradient_boosting_regressor",
    "gbm_regressor": "gradient_boosting_regressor",
    "gbm_lag": "gbm_lag",
}


CLASSIFICATION_MODELS = {
    "logistic_regression": train_logistic_regression,
    "decision_tree": train_decision_tree_clf,
    "naive_bayes": train_naive_bayes,
    "gradient_boosting": train_gradient_boosting_clf,
    "random_forest": train_random_forest_clf,
    "adaboost": train_adaboost,
    "svm": train_svm_clf,
}

REGRESSION_MODELS = {
    "linear_regression": train_linear_regression,
    "decision_tree_regressor": train_decision_tree_reg,
    "svr": train_svr,
    "gradient_boosting_regressor": train_gradient_boosting_reg,
}

TIMESERIES_MODELS = {"arima", "exp_smoothing", "gbm_lag"}


def run_model(task_name, model_name, train_df, test_df, target, ds_cfg):
    """
    Train a model and return predictions.
    Returns dict with: y_pred, y_prob (classification only), y_true
    """
    resolved_name = MODEL_ALIASES.get(model_name, model_name)

    if task_name == "timeseries":
        return _run_timeseries_model(resolved_name, train_df, test_df, target, ds_cfg)
    else:
        return _run_tabular_model(
            task_name, resolved_name, train_df, test_df, target, ds_cfg
        )


def _run_tabular_model(task_name, model_name, train_df, test_df, target, ds_cfg):
    """Run a classification or regression model."""
    X_train, y_train = _prepare_features(train_df, target, ds_cfg, task_name)
    X_test, y_true = _prepare_features(test_df, target, ds_cfg, task_name)

    # Align columns
    common = X_train.columns.intersection(X_test.columns)
    X_train = X_train[common]
    X_test = X_test[common]

    if task_name == "classification":
        if model_name not in CLASSIFICATION_MODELS:
            raise ValueError(f"Unknown classification model: {model_name}")
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            model = CLASSIFICATION_MODELS[model_name](X_train.values, y_train)
            y_pred = model.predict(X_test.values)
            y_prob = None
            if hasattr(model, "predict_proba"):
                proba = model.predict_proba(X_test.values)
                y_prob = proba[:, 1] if proba.shape[1] == 2 else proba
        return {"y_pred": y_pred, "y_prob": y_prob, "y_true": y_true}
    else:
        if model_name not in REGRESSION_MODELS:
            raise ValueError(f"Unknown regression model: {model_name}")
        with warnings.catch_warnings():
            warnings.simplefilter("ignore")
            model = REGRESSION_MODELS[model_name](X_train.values, y_train)
            y_pred = model.predict(X_test.values)
        return {"y_pred": y_pred, "y_prob": None, "y_true": y_true}


def _run_timeseries_model(model_name, train_df, test_df, target, ds_cfg):
    """Run a timeseries model."""
    y_train_full = train_df[target].values.astype(float)
    y_true = test_df[target].values.astype(float)
    n_steps = len(y_true)

    # Handle NaN in training
    y_train_full = pd.Series(y_train_full).interpolate().bfill().ffill().values

    # Cap training data for parametric models (ARIMA/ExpSmoothing).
    # Distant history is often irrelevant for time series forecasting,
    # and ARIMA fitting cost grows superlinearly with data size.
    MAX_TS_ROWS = ds_cfg.get("max_ts_train_rows")
    if MAX_TS_ROWS is None:
        MAX_TS_ROWS = 10000
    if model_name in ("arima", "exp_smoothing") and len(y_train_full) > MAX_TS_ROWS:
        y_train = y_train_full[-MAX_TS_ROWS:]
    else:
        y_train = y_train_full

    # Exogenous variables
    exog_cols = ds_cfg.get("exog_cols") or []
    exog_train = None
    exog_test = None
    if exog_cols:
        ecols = [c for c in exog_cols if c in train_df.columns]
        if ecols:
            exog_train = train_df[ecols].fillna(0).values.astype(float)
            if (
                model_name in ("arima", "exp_smoothing")
                and len(exog_train) > MAX_TS_ROWS
            ):
                exog_train = exog_train[-MAX_TS_ROWS:]
            exog_test = test_df[ecols].fillna(0).values.astype(float)

    with warnings.catch_warnings():
        warnings.simplefilter("ignore")
        if model_name == "arima":
            model = train_arima(
                y_train,
                exog_train,
                arima_max_order=ds_cfg.get("arima_max_order"),
                arima_stepwise=ds_cfg.get("arima_stepwise"),
            )
            y_pred = predict_arima(model, n_steps, exog_test)
        elif model_name == "exp_smoothing":
            model = train_exp_smoothing(y_train)
            y_pred = predict_exp_smoothing(model, n_steps)
        elif model_name == "gbm_lag":
            model_tuple = train_gbm_lag(y_train, exog_train)
            y_pred = predict_gbm_lag(model_tuple, y_train, n_steps, exog_test)
        else:
            raise ValueError(f"Unknown timeseries model: {model_name}")

    return {"y_pred": np.array(y_pred), "y_prob": None, "y_true": y_true}
