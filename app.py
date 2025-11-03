# app.py
from flask import Flask, jsonify
from prometheus_client import Counter, generate_latest, CONTENT_TYPE_LATEST
import random

app = Flask(__name__)
req_ok = Counter("app_requests_ok_total", "Requests OK")
req_err = Counter("app_requests_error_total", "Requests with error")

@app.route("/healthz")
def healthz():
    return "ok", 200

@app.route("/do_work")
def do_work():
    if random.random() < 0.1:
        req_err.inc()
        return jsonify({"status": "error"}), 500
    req_ok.inc()
    return jsonify({"status":"ok"}), 200

@app.route("/metrics")
def metrics():
    return generate_latest(), 200, {"Content-Type": CONTENT_TYPE_LATEST}

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000)