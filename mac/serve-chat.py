#!/usr/bin/env python3
# Offline AI Kit - fallback chat page server for macOS (used only if perl is missing; perl is normally built in).
# Same job as serve-chat.pl: www folder, /status.json, and an /ollama/api/... proxy to the private AI server.
#   python3 serve-chat.py --bind 0.0.0.0 --port 8091 --www DIR --logs DIR --ollama-port 11435
import argparse, http.client, os, posixpath, socketserver, sys, time
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import unquote, urlsplit

ap = argparse.ArgumentParser()
for k, d in (("bind", "127.0.0.1"), ("port", "8091"), ("www", ""), ("logs", ""), ("ollama-port", "11435")):
    ap.add_argument("--" + k, default=d)
o = ap.parse_args()
ROOT = os.path.realpath(o.www)
TYPES = {".html": "text/html; charset=utf-8", ".js": "text/javascript; charset=utf-8", ".css": "text/css; charset=utf-8",
         ".json": "application/json; charset=utf-8", ".png": "image/png", ".svg": "image/svg+xml", ".ico": "image/x-icon", ".txt": "text/plain; charset=utf-8"}
ALLOWED = {"GET /api/tags", "GET /api/version", "GET /api/ps", "POST /api/chat", "POST /api/generate", "POST /api/show", "POST /api/embed", "POST /api/embeddings"}

def log(msg):
    try:
        with open(os.path.join(o.logs, "chat-server-mac.log"), "a") as f:
            f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + msg + "\n")
    except OSError:
        pass

class H(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"
    def log_message(self, *a):
        pass
    def send(self, code, ctype, body=b"", head=False):
        self.send_response(code)
        self.send_header("Content-Type", ctype); self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store"); self.send_header("X-Content-Type-Options", "nosniff"); self.end_headers()
        if body and not head:
            self.wfile.write(body)
    def proxy(self, api):
        if self.command == "OPTIONS":
            return self.send(204, "text/plain")
        if self.command + " " + api not in ALLOWED:
            return self.send(403, "text/plain", b"Not allowed through the chat page")
        n = int(self.headers.get("Content-Length") or 0)
        if n > 16 * 1024 * 1024:
            return self.send(413, "text/plain")
        body = self.rfile.read(n) if n else b""
        try:
            c = http.client.HTTPConnection("127.0.0.1", int(o.ollama_port), timeout=900)
            q = urlsplit(self.path).query
            c.request(self.command, api + ("?" + q if q else ""), body=body or None, headers={"Content-Type": "application/json"})
            r = c.getresponse()
        except OSError:
            return self.send(502, "application/json", b'{"error":"The AI server is not running"}')
        self.send_response(r.status)
        for k, v in r.getheaders():
            if k.lower() not in ("transfer-encoding", "connection", "content-length"):
                self.send_header(k, v)
        self.send_header("Connection", "close"); self.end_headers()
        while True:
            chunk = r.read1(16384) if hasattr(r, "read1") else r.read(16384)
            if not chunk:
                break
            self.wfile.write(chunk); self.wfile.flush()
        c.close()
    def route(self, head=False):
        path = unquote(urlsplit(self.path).path)
        if path.startswith("/ollama/"):
            return self.proxy(path[7:])
        if self.command not in ("GET", "HEAD"):
            return self.send(405, "text/plain")
        if path == "/status.json":
            try:
                with open(os.path.join(o.logs, "wikipedia-progress.json"), "rb") as f:
                    data = f.read() or b'{"state":"unknown"}'
            except OSError:
                data = b'{"state":"unknown"}'
            return self.send(200, "application/json; charset=utf-8", data, head)
        if path == "/":
            path = "/chat.html"
        full = os.path.realpath(os.path.join(ROOT, posixpath.normpath(path).lstrip("/")))
        if not full.startswith(ROOT + os.sep) or not os.path.isfile(full):
            return self.send(404, "text/plain", b"Not found")
        with open(full, "rb") as f:
            data = f.read()
        self.send(200, TYPES.get(os.path.splitext(full)[1].lower(), "application/octet-stream"), data, head)
    def do_GET(self): self.route()
    def do_HEAD(self): self.route(True)
    def do_POST(self): self.route()
    def do_OPTIONS(self): self.route()
    def do_DELETE(self): self.route()
    def do_PUT(self): self.route()

class S(socketserver.ThreadingMixIn, HTTPServer):
    daemon_threads = True
    allow_reuse_address = True

try:
    srv = S((o.bind, int(o.port)), H)
except OSError as e:
    log("cannot listen on %s:%s: %s" % (o.bind, o.port, e)); sys.exit(1)
log("listening on %s:%s (python)" % (o.bind, o.port))
srv.serve_forever()
