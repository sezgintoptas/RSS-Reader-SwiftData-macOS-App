import http.server
import socketserver
import json
import os
import shutil

PORT = 8080

class MockGitHubHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/api/releases/latest":
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            
            response = {
                "tag_name": "v1.1.0",
                "name": "Sürüm 1.1.0: Heyecan Verici Yenilikler!",
                "body": "- Hata düzeltmeleri eklendi.\n- Hız iyileştirmeleri yapıldı.\n- Kullanıcı arayüzü elden geçirildi.",
                "html_url": "https://github.com/sezgintoptas/RSS-Reader-SwiftData-macOS-App/releases/tag/v1.1.0",
                "assets": [
                    {
                        "name": "RSSReader.app.zip",
                        "browser_download_url": f"http://localhost:{PORT}/RSSReader.app.zip",
                        "size": 1234567
                    }
                ]
            }
            self.wfile.write(json.dumps(response).encode("utf-8"))
        elif self.path == "/RSSReader.app.zip":
            # Zip current app
            if not os.path.exists("RSSReader.app.zip"):
                print("Zipping RSSReader.app...")
                shutil.make_archive("RSSReader.app", "zip", ".", "RSSReader.app")
            super().do_GET()
        else:
            self.send_response(404)
            self.end_headers()

if __name__ == "__main__":
    Handler = MockGitHubHandler
    with socketserver.TCPServer(("", PORT), Handler) as httpd:
        print(f"Mock GitHub API listening on port {PORT}")
        httpd.serve_forever()
