#!/usr/bin/env python3
"""
checkin-listener.py: a stand-in "check-in" server for the beaconing scenario
(MITRE T1071.001).

Run on kali-attacker:   python3 scripts/kali/checkin-listener.py   (listens on 8080)
Then start scripts/target/beacon.sh on linux-endpoint.

This is deliberately inert. It answers every check-in with the literal text
"noop", it has no way to send a command, and it never runs anything. The only
job it does is print who checked in and when, so you can watch the beacon
arrive on a fixed interval. All the learning happens on the defender side:
spotting the regular, repeating connection pattern in the sensor logs. The
traffic is what matters here, not the server.
"""
from datetime import datetime
from http.server import BaseHTTPRequestHandler, HTTPServer
from urllib.parse import urlparse, parse_qs

PORT = 8080


class CheckinHandler(BaseHTTPRequestHandler):
    server_version = "Apache"  # a real implant often fakes a common banner; mimic that
    sys_version = ""

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/updates/check":
            q = parse_qs(url.query)
            host = q.get("id", ["?"])[0]
            n = q.get("n", ["?"])[0]
            print(f"{datetime.now():%H:%M:%S}  check-in #{n} from {self.client_address[0]} ({host})", flush=True)
            body, code = b"noop", 200
        else:
            body, code = b"not found", 404
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):  # keep the console to just the check-in lines
        pass


if __name__ == "__main__":
    print(f"[*] Check-in listener on 0.0.0.0:{PORT}. Replies 'noop' to every request. Ctrl+C to stop.")
    try:
        HTTPServer(("0.0.0.0", PORT), CheckinHandler).serve_forever()
    except KeyboardInterrupt:
        print("\n[+] Stopped.")
