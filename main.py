import os
import sys
from wsgiref import simple_server


def app(environ, start_response):
    start_response("200 OK", [
        ("Content-type", "text/plain; charset=utf-8"),
        ("Version", sys.version.split()[0]),
    ])
    return [b"Hello"]


simple_server.ServerHandler.server_software = ""
port = int(os.environ.get("PORT", 8080))
with simple_server.make_server(host="", port=port, app=app) as httpd:
    print(f"Serving on port {port}...")
    httpd.serve_forever()
