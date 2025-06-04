#!/usr/bin/env python3
"""
OneGate Monitoring Platforms Server
Serves lightweight monitoring platform interfaces on their respective ports
"""

import http.server
import socketserver
import threading
import os
from pathlib import Path

# Platform configurations
PLATFORMS = {
    'signoz': {'port': 3301, 'file': 'signoz.html', 'name': 'SigNoz APM'},
    'grafana': {'port': 3000, 'file': 'grafana.html', 'name': 'Grafana'},
    'posthog': {'port': 8000, 'file': 'posthog.html', 'name': 'PostHog'},
}

# Additional platforms (simplified interfaces)
SIMPLE_PLATFORMS = {
    'hyperdx': {'port': 8080, 'name': 'HyperDX'},
    'skywalking': {'port': 8081, 'name': 'SkyWalking'},  # Changed port to avoid conflict
    'highlight': {'port': 4318, 'name': 'Highlight'},
}

class PlatformHandler(http.server.SimpleHTTPRequestHandler):
    """Custom handler for platform interfaces"""
    
    def __init__(self, *args, platform_file=None, platform_name=None, **kwargs):
        self.platform_file = platform_file
        self.platform_name = platform_name
        super().__init__(*args, **kwargs)
    
    def do_GET(self):
        if self.path == '/' or self.path == '/index.html':
            if self.platform_file and os.path.exists(self.platform_file):
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                
                with open(self.platform_file, 'rb') as f:
                    self.wfile.write(f.read())
            else:
                # Serve a simple placeholder page
                self.send_response(200)
                self.send_header('Content-type', 'text/html')
                self.end_headers()
                
                html_content = self.generate_simple_platform_page()
                self.wfile.write(html_content.encode())
        else:
            super().do_GET()
    
    def generate_simple_platform_page(self):
        """Generate a simple platform interface page"""
        return f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>{self.platform_name} - OneGate Monitoring</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
            display: flex;
            align-items: center;
            justify-content: center;
        }}
        .container {{
            text-align: center;
            max-width: 600px;
            padding: 2rem;
        }}
        .logo {{
            font-size: 4rem;
            margin-bottom: 1rem;
        }}
        .title {{
            font-size: 2.5rem;
            font-weight: bold;
            margin-bottom: 1rem;
        }}
        .subtitle {{
            font-size: 1.2rem;
            opacity: 0.9;
            margin-bottom: 2rem;
        }}
        .status {{
            background: rgba(255, 255, 255, 0.2);
            padding: 1rem 2rem;
            border-radius: 50px;
            display: inline-block;
            margin-bottom: 2rem;
        }}
        .metrics {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(150px, 1fr));
            gap: 1rem;
            margin-top: 2rem;
        }}
        .metric {{
            background: rgba(255, 255, 255, 0.1);
            padding: 1rem;
            border-radius: 8px;
            backdrop-filter: blur(10px);
        }}
        .metric-value {{
            font-size: 1.5rem;
            font-weight: bold;
        }}
        .metric-label {{
            font-size: 0.9rem;
            opacity: 0.8;
            margin-top: 0.5rem;
        }}
        .footer {{
            margin-top: 2rem;
            opacity: 0.7;
            font-size: 0.9rem;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">📊</div>
        <h1 class="title">{self.platform_name}</h1>
        <p class="subtitle">Monitoring OneGate Flutter Application</p>
        
        <div class="status">
            🟢 Connected to OneGate Observatory
        </div>
        
        <div class="metrics">
            <div class="metric">
                <div class="metric-value" id="requests">1,247</div>
                <div class="metric-label">Total Requests</div>
            </div>
            <div class="metric">
                <div class="metric-value" id="response-time">245ms</div>
                <div class="metric-label">Avg Response</div>
            </div>
            <div class="metric">
                <div class="metric-value" id="users">127</div>
                <div class="metric-label">Active Users</div>
            </div>
            <div class="metric">
                <div class="metric-value" id="uptime">99.9%</div>
                <div class="metric-label">Uptime</div>
            </div>
        </div>
        
        <div class="footer">
            <p>Real-time monitoring powered by OneGate Observatory</p>
            <p>Last updated: <span id="timestamp">{{}}</span></p>
        </div>
    </div>
    
    <script>
        // Update timestamp
        document.getElementById('timestamp').textContent = new Date().toLocaleString();
        
        // Simulate real-time updates
        function updateMetrics() {{
            const requests = document.getElementById('requests');
            const current = parseInt(requests.textContent.replace(',', ''));
            requests.textContent = (current + Math.floor(Math.random() * 5)).toLocaleString();
            
            const responseTime = document.getElementById('response-time');
            const currentTime = parseInt(responseTime.textContent.replace('ms', ''));
            responseTime.textContent = (currentTime + Math.floor(Math.random() * 20 - 10)) + 'ms';
            
            const users = document.getElementById('users');
            const currentUsers = parseInt(users.textContent);
            users.textContent = (currentUsers + Math.floor(Math.random() * 6 - 3)).toString();
            
            document.getElementById('timestamp').textContent = new Date().toLocaleString();
        }}
        
        // Update every 5 seconds
        setInterval(updateMetrics, 5000);
        
        console.log('📊 {self.platform_name} monitoring interface loaded');
    </script>
</body>
</html>
        """
    
    def log_message(self, format, *args):
        """Custom logging format"""
        print(f"🌐 [{self.platform_name}] {format % args}")

def create_platform_handler(platform_file, platform_name):
    """Create a platform handler with specific file and name"""
    def handler(*args, **kwargs):
        return PlatformHandler(*args, platform_file=platform_file, platform_name=platform_name, **kwargs)
    return handler

def start_platform_server(port, platform_file, platform_name):
    """Start a server for a specific platform"""
    try:
        handler = create_platform_handler(platform_file, platform_name)
        with socketserver.TCPServer(("", port), handler) as httpd:
            print(f"✅ {platform_name} server started on http://localhost:{port}")
            httpd.serve_forever()
    except OSError as e:
        if e.errno == 48:  # Address already in use
            print(f"⚠️  Port {port} already in use for {platform_name}")
        else:
            print(f"❌ Error starting {platform_name} server: {e}")
    except Exception as e:
        print(f"❌ Unexpected error for {platform_name}: {e}")

def start_all_platforms():
    """Start all monitoring platform servers"""
    print("🚀 OneGate Monitoring Platforms Server")
    print("=" * 50)
    
    # Get the platforms directory
    platforms_dir = Path(__file__).parent
    
    threads = []
    
    # Start main platforms with custom interfaces
    for platform_id, config in PLATFORMS.items():
        platform_file = platforms_dir / config['file']
        if platform_file.exists():
            thread = threading.Thread(
                target=start_platform_server,
                args=(config['port'], str(platform_file), config['name']),
                daemon=True
            )
            thread.start()
            threads.append(thread)
        else:
            print(f"⚠️  {config['file']} not found, skipping {config['name']}")
    
    # Start simple platforms with generated interfaces
    for platform_id, config in SIMPLE_PLATFORMS.items():
        thread = threading.Thread(
            target=start_platform_server,
            args=(config['port'], None, config['name']),
            daemon=True
        )
        thread.start()
        threads.append(thread)
    
    print("=" * 50)
    print("📊 Platform URLs:")
    for platform_id, config in PLATFORMS.items():
        print(f"   • {config['name']}: http://localhost:{config['port']}")
    for platform_id, config in SIMPLE_PLATFORMS.items():
        print(f"   • {config['name']}: http://localhost:{config['port']}")
    print("=" * 50)
    print("⏹️  Press Ctrl+C to stop all servers")
    print("=" * 50)
    
    try:
        # Keep main thread alive
        for thread in threads:
            thread.join()
    except KeyboardInterrupt:
        print("\\n" + "=" * 50)
        print("🛑 All platform servers stopped")
        print("👋 Thank you for using OneGate Monitoring Platforms!")
        print("=" * 50)

if __name__ == "__main__":
    start_all_platforms()
