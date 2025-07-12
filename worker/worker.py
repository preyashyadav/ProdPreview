# worker.py

import os
import time
import threading
import logging
import requests
from flask import Flask, jsonify

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

API_URL = os.getenv("API_URL", "http://api-service:4000/api/hello")
POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "30"))


app = Flask(__name__)

@app.route("/health")
def health():
    return jsonify(status="ok")

def poll_api():
    """Continuously hit the API endpoint and log the response."""
    while True:
        try:
            resp = requests.get(API_URL, timeout=5)
            resp.raise_for_status()
            data = resp.json()
            logging.info(f"Polled API, got: {data}")
        except Exception as e:
            logging.error(f"Error polling API: {e}")
        time.sleep(POLL_INTERVAL)

if __name__ == "__main__":
    thread = threading.Thread(target=poll_api, daemon=True)
    thread.start()

    port = int(os.getenv("PORT", "8000"))
    app.run(host="0.0.0.0", port=port)
