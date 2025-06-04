#!/usr/bin/env python3
"""
OneGate Observatory Dashboard Web Server
Simple HTTP server to serve the Observatory dashboard web page
"""

import http.server
import socketserver
import webbrowser
import os
import sys
from pathlib import Path

# Configuration
PORT = 9999
HOST = 'localhost'

class ObservatoryHTTPRequestHandler(http.server.SimpleHTTPRequestHandler):
    """Custom HTTP request handler for Observatory dashboard"""
    
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=str(Path(__file__).parent), **kwargs)
    
    def end_headers(self):
        # Add CORS headers for development
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
        super().end_headers()
    
    def do_GET(self):
        # Redirect root to dashboard
        if self.path == '/':
            self.path = '/observatory_dashboard.html'
        return super().do_GET()
    
    def log_message(self, format, *args):
        # Custom logging format
        print(f"🌐 [{self.address_string()}] {format % args}")

def start_server():
    """Start the Observatory dashboard web server"""
    
    # Change to the web directory
    web_dir = Path(__file__).parent
    os.chdir(web_dir)
    
    print("🔭 OneGate Observatory Dashboard Web Server")
    print("=" * 50)
    print(f"📍 Server starting on http://{HOST}:{PORT}")
    print(f"📁 Serving files from: {web_dir}")
    print("=" * 50)
    
    try:
        with socketserver.TCPServer((HOST, PORT), ObservatoryHTTPRequestHandler) as httpd:
            print(f"✅ Server started successfully!")
            print(f"🌐 Dashboard URL: http://{HOST}:{PORT}")
            print(f"📊 Access your OneGate Observatory Dashboard in your browser")
            print("=" * 50)
            print("📝 Server Logs:")
            print("-" * 20)
            
            # Try to open browser automatically
            try:
                webbrowser.open(f'http://{HOST}:{PORT}')
                print(f"🚀 Opening dashboard in your default browser...")
            except Exception as e:
                print(f"⚠️  Could not auto-open browser: {e}")
                print(f"📖 Please manually open: http://{HOST}:{PORT}")
            
            print(f"⏹️  Press Ctrl+C to stop the server")
            print("-" * 20)
            
            # Start serving
            httpd.serve_forever()
            
    except KeyboardInterrupt:
        print("\n" + "=" * 50)
        print("🛑 Server stopped by user")
        print("👋 Thank you for using OneGate Observatory Dashboard!")
        print("=" * 50)
    except OSError as e:
        if e.errno == 48:  # Address already in use
            print(f"❌ Error: Port {PORT} is already in use")
            print(f"💡 Try using a different port or stop the existing service")
            print(f"🔍 You can check what's using port {PORT} with: lsof -i :{PORT}")
        else:
            print(f"❌ Error starting server: {e}")
        sys.exit(1)
    except Exception as e:
        print(f"❌ Unexpected error: {e}")
        sys.exit(1)

if __name__ == "__main__":
    start_server()
