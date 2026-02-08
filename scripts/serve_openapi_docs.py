#!/usr/bin/env python3
"""
Serve OpenAPI documentation with Swagger UI

This script starts a simple HTTP server that serves the OpenAPI
documentation with Swagger UI for easy API exploration.
"""

import http.server
import socketserver
import json
import sys
from pathlib import Path

HTML_TEMPLATE = """
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>Florent API Documentation</title>
    <link rel="stylesheet" type="text/css" href="https://unpkg.com/swagger-ui-dist@5.10.3/swagger-ui.css">
    <style>
        body {
            margin: 0;
            padding: 0;
        }
    </style>
</head>
<body>
    <div id="swagger-ui"></div>
    <script src="https://unpkg.com/swagger-ui-dist@5.10.3/swagger-ui-bundle.js"></script>
    <script src="https://unpkg.com/swagger-ui-dist@5.10.3/swagger-ui-standalone-preset.js"></script>
    <script>
        window.onload = function() {
            window.ui = SwaggerUIBundle({
                url: '/openapi.json',
                dom_id: '#swagger-ui',
                deepLinking: true,
                presets: [
                    SwaggerUIBundle.presets.apis,
                    SwaggerUIStandalonePreset
                ],
                plugins: [
                    SwaggerUIBundle.plugins.DownloadUrl
                ],
                layout: "StandaloneLayout"
            });
        };
    </script>
</body>
</html>
"""


class OpenAPIHandler(http.server.SimpleHTTPRequestHandler):
    """Custom handler to serve OpenAPI docs"""

    def __init__(self, *args, openapi_path=None, **kwargs):
        self.openapi_path = openapi_path
        super().__init__(*args, **kwargs)

    def do_GET(self):
        if self.path == '/' or self.path == '/index.html':
            self.send_response(200)
            self.send_header('Content-type', 'text/html')
            self.end_headers()
            self.wfile.write(HTML_TEMPLATE.encode())
        elif self.path == '/openapi.json':
            try:
                with open(self.openapi_path, 'r') as f:
                    content = f.read()
                self.send_response(200)
                self.send_header('Content-type', 'application/json')
                self.end_headers()
                self.wfile.write(content.encode())
            except FileNotFoundError:
                self.send_error(404, 'OpenAPI spec not found')
        else:
            self.send_error(404, 'Not found')

    def log_message(self, format, *args):
        """Override to customize logging"""
        sys.stdout.write(f"[{self.log_date_time_string()}] {format % args}\n")


def serve_docs(port=8080, openapi_path='docs/openapi.json'):
    """
    Serve OpenAPI documentation with Swagger UI

    Args:
        port: Port to serve on (default: 8080)
        openapi_path: Path to openapi.json file
    """
    openapi_file = Path(openapi_path)

    if not openapi_file.exists():
        print(f"[ERROR] Error: OpenAPI spec not found at {openapi_file.absolute()}")
        print(f"💡 Tip: Run 'python3 scripts/generate_openapi.py' first")
        return False

    handler = lambda *args, **kwargs: OpenAPIHandler(
        *args, openapi_path=openapi_file, **kwargs
    )

    with socketserver.TCPServer(("", port), handler) as httpd:
        print(f"[SUCCESS] Serving OpenAPI documentation")
        print(f"📄 OpenAPI spec: {openapi_file.absolute()}")
        print(f"🌐 Swagger UI: http://localhost:{port}")
        print(f"🛑 Press Ctrl+C to stop")
        print()

        try:
            httpd.serve_forever()
        except KeyboardInterrupt:
            print("\n\n👋 Shutting down server...")
            return True


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(
        description="Serve OpenAPI documentation with Swagger UI"
    )
    parser.add_argument(
        "-p", "--port",
        type=int,
        default=8080,
        help="Port to serve on (default: 8080)"
    )
    parser.add_argument(
        "-f", "--file",
        default="docs/openapi.json",
        help="Path to OpenAPI JSON file (default: docs/openapi.json)"
    )

    args = parser.parse_args()

    success = serve_docs(port=args.port, openapi_path=args.file)
    sys.exit(0 if success else 1)
