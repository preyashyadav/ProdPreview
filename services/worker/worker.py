# worker.py

import logging
import os
import threading
import time

import requests
from flask import Flask, jsonify

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s"
)

API_URL = os.getenv("API_URL", "http://api:4000/api/hello")
POLL_INTERVAL = int(os.getenv("POLL_INTERVAL", "30"))
app = Flask(__name__)
health_state = {
    "api_reachable": False,
    "last_checked_at": None,
    "last_error": None,
}


def _update_health_state(api_reachable, last_error=None):
    health_state["api_reachable"] = api_reachable
    health_state["last_checked_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    health_state["last_error"] = last_error

@app.route("/health")
def health():
    return jsonify(
        status="ok",
        service="worker",
        timestamp=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        api_reachable=health_state["api_reachable"],
        last_checked_at=health_state["last_checked_at"],
        api_url=API_URL,
        last_error=health_state["last_error"],
    )


def fetch_api_status():
    resp = requests.get(API_URL, timeout=5)
    resp.raise_for_status()
    return resp.json()


def poll_api():
    """Continuously hit the API endpoint and log the response."""
    while True:
        try:
            data = fetch_api_status()
            _update_health_state(True)
            logging.info(f"Polled API, got: {data}")
        except Exception as e:
            _update_health_state(False, str(e))
            logging.error(f"Error polling API: {e}")
        time.sleep(POLL_INTERVAL)


if __name__ == "__main__":
    thread = threading.Thread(target=poll_api, daemon=True)
    thread.start()

    port = int(os.getenv("PORT", "8000"))
    app.run(host="0.0.0.0", port=port)
