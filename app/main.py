import os, time, socket
from flask import Flask, Response, jsonify, render_template_string
from prometheus_client import Counter, Histogram, generate_latest, CONTENT_TYPE_LATEST

app = Flask(__name__)

# --- Build/Deploy metadata ---
APP_NAME = os.getenv("APP_NAME", "demo-python-app")
APP_VERSION = os.getenv("APP_VERSION", "0.0.0-local")
GIT_SHA = os.getenv("GIT_SHA", "dev")
BUILD_TIME = os.getenv("BUILD_TIME", "unknown")
ENV_NAME = os.getenv("ENV_NAME", "dev")
BUILD_NUMBER = os.getenv("BUILD_NUMBER", "0")

# --- Config from ConfigMap/ENV ---
THEME_COLOR = os.getenv("THEME_COLOR", "#0ea5e9")
MESSAGE = os.getenv("MESSAGE", "Hello from GitHub Actions → OCIR → OKE!")

# --- Downward API ---
POD_NAME = os.getenv("POD_NAME", socket.gethostname())
POD_IP = os.getenv("POD_IP", "0.0.0.0")
NODE_NAME = os.getenv("NODE_NAME", "unknown")

# --- Prometheus metrics ---
REQ_COUNTER = Counter("app_http_requests_total", "Total HTTP requests", ["path", "method"])
REQ_LATENCY = Histogram("app_http_request_duration_seconds", "Request latency", ["path", "method"])

INDEX_HTML = """
<!doctype html>
<html>
<head>
  <meta charset="utf-8"/>
  <title>{{ app_name }}</title>
  <style>
    body { font-family: ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, Noto Sans, Arial, "Apple Color Emoji", "Segoe UI Emoji";
           margin: 0; padding: 2rem; background: #0b1220; color: #fff; }
    .card { background: #111827; border-radius: 16px; padding: 24px; max-width: 900px; margin: 0 auto; box-shadow: 0 10px 30px rgba(0,0,0,.35); }
    .badge { display: inline-block; padding: 4px 10px; border-radius: 999px; font-size: 12px; background: {{ theme_color }}; color: #0b1220; margin-right: 8px; }
    .grid { display: grid; gap: 12px; grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); margin-top: 12px; }
    .kv { background: #0f172a; border: 1px solid #1f2937; border-radius: 12px; padding: 12px; }
    .kv .k { color: #93c5fd; font-size: 12px; text-transform: uppercase; letter-spacing: .08em; }
    .kv .v { font-size: 14px; margin-top: 6px; word-break: break-all; }
    a { color: {{ theme_color }}; }
  </style>
</head>
<body>
  <div class="card">
    <div>
      <span class="badge">{{ env_name }}</span>
      <span class="badge">v{{ app_version }}</span>
      <span class="badge">build #{{ build_number }}</span>
    </div>
    <h1 style="margin-top:10px">{{ message }}</h1>
    <p>Refresh to check changes (version, SHA, build time, itp.).</p>

    <div class="grid">
      <div class="kv"><div class="k">APP NAME</div><div class="v">{{ app_name }}</div></div>
      <div class="kv"><div class="k">GIT SHA</div><div class="v">{{ git_sha }}</div></div>
      <div class="kv"><div class="k">BUILD TIME</div><div class="v">{{ build_time }}</div></div>
      <div class="kv"><div class="k">POD NAME</div><div class="v">{{ pod_name }}</div></div>
      <div class="kv"><div class="k">POD IP</div><div class="v">{{ pod_ip }}</div></div>
      <div class="kv"><div class="k">NODE NAME</div><div class="v">{{ node_name }}</div></div>
      <div class="kv"><div class="k">THEME COLOR</div><div class="v">{{ theme_color }}</div></div>
    </div>

    <p style="margin-top:16px">
      Endpoints: <a href="/healthz">/healthz</a> • <a href="/readyz">/readyz</a> •
      <a href="/version">/version</a> • <a href="/metrics">/metrics</a>
    </p>
  </div>
</body>
</html>
"""

def measure(func):
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        resp = func(*args, **kwargs)
        REQ_COUNTER.labels(path=request_path(), method=request_method()).inc()
        REQ_LATENCY.labels(path=request_path(), method=request_method()).observe(time.perf_counter() - start)
        return resp
    return wrapper

def request_path():
    from flask import request
    return request.path

def request_method():
    from flask import request
    return request.method

@app.route("/")
@measure
def index():
    return render_template_string(
        INDEX_HTML,
        app_name=APP_NAME,
        app_version=APP_VERSION,
        git_sha=GIT_SHA,
        build_time=BUILD_TIME,
        env_name=ENV_NAME,
        build_number=BUILD_NUMBER,
        theme_color=THEME_COLOR,
        message=MESSAGE,
        pod_name=POD_NAME,
        pod_ip=POD_IP,
        node_name=NODE_NAME,
    )

@app.route("/version")
@measure
def version():
    return jsonify(
        app=APP_NAME,
        version=APP_VERSION,
        git_sha=GIT_SHA,
        build_time=BUILD_TIME,
        env=ENV_NAME,
        build_number=BUILD_NUMBER,
        pod=POD_NAME,
        node=NODE_NAME,
        ip=POD_IP,
    )

@app.route("/metrics")
def metrics():
    return Response(generate_latest(), mimetype=CONTENT_TYPE_LATEST)

@app.route("/healthz")
def healthz():
    return "ok", 200

@app.route("/readyz")
def readyz():
    return "ready", 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.getenv("PORT", "8080")))
