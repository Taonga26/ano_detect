import numpy as np
import pandas as pd
import joblib
from tensorflow.keras.models import load_model
import warnings
warnings.filterwarnings('ignore')
import json

# ------------------------------
# Load ML Models
# ------------------------------

try:
    var_model = joblib.load('models/var_model.pkl')
    var_scaler = joblib.load('scalers/var_scaler.pkl')
    lstm_scaler = joblib.load('scalers/lstm_scaler.pkl')
    lstm_model = load_model('models/lstm_model.keras')
    iso_forest = joblib.load('models/isolation_forest_model.pkl')

    print("Python: Models loaded successfully (Chaquopy).")

except Exception as e:
    print("Python: Error loading models:", str(e))


# ------------------------------
# Helper functions
# ------------------------------

def create_sequences(X, seq_len=10):
    Xs, ys = [], []
    for i in range(len(X) - seq_len):
        Xs.append(X.iloc[i:i+seq_len].values)
        ys.append(X.iloc[i+seq_len].values)
    return np.array(Xs), np.array(ys)


# ------------------------------
# Main anomaly detection pipeline
# ------------------------------

def detect_anomalies(df):

    # Fix date
    if 'Date' in df.columns:
        if df['Date'].dtype == 'object':
            df['Date'] = pd.to_datetime(df['Date'], format='mixed')

        df.set_index('Date', inplace=True)

    # Scale with VAR scaler
    scaled_data = pd.DataFrame(
        var_scaler.transform(df),
        columns=df.columns,
        index=df.index
    )

    # VAR forecast
    k = var_model.k_ar
    steps = len(scaled_data)
    forecast_values = var_model.forecast(scaled_data.values[-k:], steps=steps)

    forecast_df = pd.DataFrame(
        forecast_values,
        index=scaled_data.index,
        columns=scaled_data.columns
    )

    # Compute residuals
    residuals = scaled_data - forecast_df
    residuals = residuals.dropna()

    # Scale residuals for LSTM
    residuals_scaled = pd.DataFrame(
        lstm_scaler.transform(residuals),
        columns=residuals.columns,
        index=residuals.index
    )

    # Prepare LSTM sequences
    X_sequences, y_true = create_sequences(residuals_scaled, seq_len=10)

    if len(X_sequences) == 0:
        return [], [], [], {
            'total_points': 0,
            'anomalies': 0,
            'percentages': {
                'anomalies': 0,
                'normal': 0
            }
        }

    # LSTM prediction
    y_pred = lstm_model.predict(X_sequences)

    # Compute MSE
    mse = np.mean(np.power(y_true - y_pred, 2), axis=1)

    # Isolation Forest
    labels = iso_forest.predict(mse.reshape(-1, 1))
    anomalies = np.where(labels == -1, 1, 0)

    # Create output DataFrame
    results_index = residuals_scaled.iloc[-len(mse):].index
    results = pd.DataFrame({
        "Reconstruction_Error": mse,
        "Anomaly": anomalies
    }, index=results_index)

    # Extract anomalous points
    anom_idx = results.index[results['Anomaly'] == 1]
    anomalous_points = df.loc[df.index.intersection(anom_idx)]

    # Format JSON outputs
    eda_payload = df.reset_index().to_dict(orient='records')

    if not anomalous_points.empty:
        recent_payload = anomalous_points.reset_index()[['Date', 'Close']].to_dict(orient='records')
    else:
        recent_payload = []

    total = len(df) if len(df) > 0 else 1

    pie_payload = {
        'total_points': len(df),
        'anomalies': int(results['Anomaly'].sum()),
        'percentages': {
            'anomalies': round((results['Anomaly'].sum() / total) * 100, 2),
            'normal': round(((total - results['Anomaly'].sum()) / total) * 100, 2)
        }
    }

    anomalies_json = anomalous_points.reset_index().to_dict(orient='records') if not anomalous_points.empty else []

    return anomalies_json, eda_payload, recent_payload, pie_payload


# ------------------------------
# Chaquopy entry function
# ------------------------------

def run_detection(csv_string: str) -> str:
    """
    Called from Flutter using MethodChannel.
    Receives CSV text and returns JSON string.
    """
    from io import StringIO

    try:
        df = pd.read_csv(StringIO(csv_string), parse_dates=['Date'])

        # Enforce required columns
        required = ['Date', 'Close', 'High', 'Low', 'Open', 'Volume']
        df = df[[col for col in df.columns if col in required]]

        # Validate
        missing = [c for c in required if c not in df.columns]
        if missing:
            return json.dumps({
                "error": "Missing required columns",
                "missing": missing
            })

        anomalies, eda, recent, pie = detect_anomalies(df)

        return json.dumps({
            "status": "success",
            "anomalies": anomalies,
            "eda": eda,
            "recent": recent,
            "pie": pie,
            "anomalies_count": len(anomalies)
        })

    except Exception as e:
        return json.dumps({
            "status": "error",
            "message": str(e)
        })
