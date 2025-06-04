#!/usr/bin/env python3
"""
OneGate Observatory Real-time Data API Server
Bridges Flutter app Observatory service with web dashboard
"""

import http.server
import socketserver
import json
import time
import threading
import sqlite3
import os
from datetime import datetime, timedelta
from pathlib import Path
import urllib.parse

# Configuration
API_PORT = 8866
WEB_PORT = 9999
HOST = 'localhost'

class ObservatoryDataStore:
    """SQLite-based data store for Observatory metrics"""
    
    def __init__(self):
        self.db_path = Path(__file__).parent / 'observatory_data.db'
        self.init_database()
    
    def init_database(self):
        """Initialize SQLite database with required tables"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Metrics table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                metric_type TEXT NOT NULL,
                metric_name TEXT NOT NULL,
                metric_value TEXT NOT NULL,
                metadata TEXT
            )
        ''')
        
        # Logs table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                level TEXT NOT NULL,
                message TEXT NOT NULL,
                source TEXT,
                metadata TEXT
            )
        ''')
        
        # System status table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS system_status (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
                service_name TEXT NOT NULL,
                status TEXT NOT NULL,
                details TEXT
            )
        ''')
        
        conn.commit()
        conn.close()
    
    def store_metric(self, metric_type, metric_name, metric_value, metadata=None):
        """Store a metric in the database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO metrics (metric_type, metric_name, metric_value, metadata)
            VALUES (?, ?, ?, ?)
        ''', (metric_type, metric_name, str(metric_value), json.dumps(metadata) if metadata else None))
        
        conn.commit()
        conn.close()
    
    def store_log(self, level, message, source=None, metadata=None):
        """Store a log entry in the database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            INSERT INTO logs (level, message, source, metadata)
            VALUES (?, ?, ?, ?)
        ''', (level, message, source, json.dumps(metadata) if metadata else None))
        
        conn.commit()
        conn.close()
    
    def update_system_status(self, service_name, status, details=None):
        """Update system status for a service"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        # Delete old status for this service
        cursor.execute('DELETE FROM system_status WHERE service_name = ?', (service_name,))
        
        # Insert new status
        cursor.execute('''
            INSERT INTO system_status (service_name, status, details)
            VALUES (?, ?, ?)
        ''', (service_name, status, details))
        
        conn.commit()
        conn.close()
    
    def get_latest_metrics(self, limit=100):
        """Get latest metrics from database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT timestamp, metric_type, metric_name, metric_value, metadata
            FROM metrics
            ORDER BY timestamp DESC
            LIMIT ?
        ''', (limit,))
        
        results = cursor.fetchall()
        conn.close()
        
        return [
            {
                'timestamp': row[0],
                'type': row[1],
                'name': row[2],
                'value': row[3],
                'metadata': json.loads(row[4]) if row[4] else None
            }
            for row in results
        ]
    
    def get_latest_logs(self, limit=50):
        """Get latest logs from database"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT timestamp, level, message, source, metadata
            FROM logs
            ORDER BY timestamp DESC
            LIMIT ?
        ''', (limit,))
        
        results = cursor.fetchall()
        conn.close()
        
        return [
            {
                'timestamp': row[0],
                'level': row[1],
                'message': row[2],
                'source': row[3],
                'metadata': json.loads(row[4]) if row[4] else None
            }
            for row in results
        ]
    
    def get_system_status(self):
        """Get current system status"""
        conn = sqlite3.connect(self.db_path)
        cursor = conn.cursor()
        
        cursor.execute('''
            SELECT service_name, status, details, timestamp
            FROM system_status
            ORDER BY timestamp DESC
        ''')
        
        results = cursor.fetchall()
        conn.close()
        
        return [
            {
                'service': row[0],
                'status': row[1],
                'details': row[2],
                'timestamp': row[3]
            }
            for row in results
        ]

class ObservatoryAPIHandler(http.server.BaseHTTPRequestHandler):
    """HTTP request handler for Observatory API"""
    
    def __init__(self, *args, data_store=None, **kwargs):
        self.data_store = data_store
        super().__init__(*args, **kwargs)
    
    def do_OPTIONS(self):
        """Handle CORS preflight requests"""
        self.send_response(200)
        self.send_cors_headers()
        self.end_headers()
    
    def send_cors_headers(self):
        """Send CORS headers"""
        self.send_header('Access-Control-Allow-Origin', '*')
        self.send_header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS')
        self.send_header('Access-Control-Allow-Headers', 'Content-Type')
    
    def do_GET(self):
        """Handle GET requests"""
        self.send_response(200)
        self.send_header('Content-type', 'application/json')
        self.send_cors_headers()
        self.end_headers()
        
        path = self.path.split('?')[0]
        
        if path == '/api/metrics':
            metrics = self.data_store.get_latest_metrics()
            response = {'metrics': metrics, 'timestamp': datetime.now().isoformat()}
            
        elif path == '/api/logs':
            logs = self.data_store.get_latest_logs()
            response = {'logs': logs, 'timestamp': datetime.now().isoformat()}
            
        elif path == '/api/status':
            status = self.data_store.get_system_status()
            response = {'status': status, 'timestamp': datetime.now().isoformat()}
            
        elif path == '/api/dashboard':
            # Aggregate dashboard data
            metrics = self.data_store.get_latest_metrics(50)
            logs = self.data_store.get_latest_logs(10)
            status = self.data_store.get_system_status()

            # Process metrics for dashboard
            dashboard_data = self.process_metrics_for_dashboard(metrics)
            detailed_metrics = self.process_detailed_metrics(metrics)

            response = {
                'dashboard': dashboard_data,
                'detailed_metrics': detailed_metrics,
                'raw_metrics': metrics,
                'logs': logs,
                'status': status,
                'timestamp': datetime.now().isoformat(),
                'metadata': {
                    'total_metrics': len(metrics),
                    'collection_interval': '5 seconds',
                    'api_version': '1.0.0'
                }
            }

        elif path == '/api/detailed':
            # Detailed metrics endpoint
            metrics = self.data_store.get_latest_metrics(100)
            detailed_metrics = self.process_detailed_metrics(metrics)

            response = {
                'detailed_metrics': detailed_metrics,
                'timestamp': datetime.now().isoformat()
            }
            
        else:
            response = {'error': 'Endpoint not found', 'path': path}
        
        self.wfile.write(json.dumps(response, indent=2).encode())
    
    def do_POST(self):
        """Handle POST requests from Flutter app"""
        content_length = int(self.headers['Content-Length'])
        post_data = self.rfile.read(content_length)
        
        try:
            data = json.loads(post_data.decode('utf-8'))
            
            # Store different types of data
            if 'metrics' in data:
                for metric in data['metrics']:
                    self.data_store.store_metric(
                        metric.get('type', 'unknown'),
                        metric.get('name', 'unknown'),
                        metric.get('value', 0),
                        metric.get('metadata')
                    )
            
            if 'logs' in data:
                for log in data['logs']:
                    self.data_store.store_log(
                        log.get('level', 'info'),
                        log.get('message', ''),
                        log.get('source', 'flutter'),
                        log.get('metadata')
                    )
            
            if 'status' in data:
                for status in data['status']:
                    self.data_store.update_system_status(
                        status.get('service', 'unknown'),
                        status.get('status', 'unknown'),
                        status.get('details')
                    )
            
            self.send_response(200)
            self.send_header('Content-type', 'application/json')
            self.send_cors_headers()
            self.end_headers()
            
            response = {'success': True, 'message': 'Data stored successfully'}
            self.wfile.write(json.dumps(response).encode())
            
        except Exception as e:
            self.send_response(400)
            self.send_header('Content-type', 'application/json')
            self.send_cors_headers()
            self.end_headers()
            
            response = {'success': False, 'error': str(e)}
            self.wfile.write(json.dumps(response).encode())
    
    def process_metrics_for_dashboard(self, metrics):
        """Process raw metrics into dashboard format"""
        dashboard_data = {
            'network_requests': 0,
            'successful_requests': 0,
            'failed_requests': 0,
            'avg_response_time': 0,
            'total_crashes': 0,
            'fatal_crashes': 0,
            'handled_exceptions': 0,
            'error_rate': 0,
            'total_events': 0,
            'active_users': 0,
            'session_duration': '0m 0s',
            'app_version': '1.0.0+1'
        }
        
        # Process metrics to extract dashboard values
        for metric in metrics:
            metric_name = metric['name']
            metric_value = metric['value']
            
            try:
                if metric_name == 'network_requests_total':
                    dashboard_data['network_requests'] = int(metric_value)
                elif metric_name == 'network_requests_successful':
                    dashboard_data['successful_requests'] = int(metric_value)
                elif metric_name == 'network_requests_failed':
                    dashboard_data['failed_requests'] = int(metric_value)
                elif metric_name == 'avg_response_time':
                    dashboard_data['avg_response_time'] = int(float(metric_value))
                elif metric_name == 'total_crashes':
                    dashboard_data['total_crashes'] = int(metric_value)
                elif metric_name == 'fatal_crashes':
                    dashboard_data['fatal_crashes'] = int(metric_value)
                elif metric_name == 'handled_exceptions':
                    dashboard_data['handled_exceptions'] = int(metric_value)
                elif metric_name == 'total_events':
                    dashboard_data['total_events'] = int(metric_value)
                elif metric_name == 'active_users':
                    dashboard_data['active_users'] = int(metric_value)
                elif metric_name == 'session_duration':
                    dashboard_data['session_duration'] = str(metric_value)
                elif metric_name == 'app_version':
                    dashboard_data['app_version'] = str(metric_value)
            except (ValueError, TypeError):
                continue
        
        # Calculate error rate
        if dashboard_data['network_requests'] > 0:
            error_rate = (dashboard_data['failed_requests'] / dashboard_data['network_requests']) * 100
            dashboard_data['error_rate'] = round(error_rate, 2)
        
        return dashboard_data
    
    def log_message(self, format, *args):
        """Custom logging format"""
        print(f"🔗 API [{self.address_string()}] {format % args}")

def create_api_handler(data_store):
    """Create API handler with data store"""
    def handler(*args, **kwargs):
        return ObservatoryAPIHandler(*args, data_store=data_store, **kwargs)
    return handler

def start_api_server():
    """Start the Observatory API server"""
    data_store = ObservatoryDataStore()
    
    print("🔗 OneGate Observatory Real-time API Server")
    print("=" * 50)
    print(f"📍 API Server starting on http://{HOST}:{API_PORT}")
    print(f"🌐 Web Dashboard: http://{HOST}:{WEB_PORT}")
    print("=" * 50)
    
    # Add some sample data for testing
    data_store.store_metric('network', 'network_requests_total', 1247)
    data_store.store_metric('network', 'network_requests_successful', 1198)
    data_store.store_metric('network', 'network_requests_failed', 49)
    data_store.store_metric('network', 'avg_response_time', 245)
    data_store.store_metric('crash', 'total_crashes', 3)
    data_store.store_metric('crash', 'fatal_crashes', 0)
    data_store.store_metric('crash', 'handled_exceptions', 12)
    data_store.store_metric('analytics', 'total_events', 8456)
    data_store.store_metric('analytics', 'active_users', 127)
    data_store.store_metric('analytics', 'session_duration', '12m 34s')
    data_store.store_metric('app', 'app_version', '1.0.0+1')
    
    data_store.store_log('info', 'Observatory API Server initialized successfully', 'api_server')
    data_store.store_log('info', 'Real-time data bridge established', 'api_server')
    data_store.store_log('info', 'Ready to receive data from OneGate Flutter app', 'api_server')
    
    data_store.update_system_status('observatory_service', 'active')
    data_store.update_system_status('data_collection', 'running')
    data_store.update_system_status('api_server', 'active')
    
    try:
        handler = create_api_handler(data_store)
        with socketserver.TCPServer((HOST, API_PORT), handler) as httpd:
            print(f"✅ API Server started successfully!")
            print(f"📊 API Endpoints:")
            print(f"   • GET  /api/metrics   - Latest metrics")
            print(f"   • GET  /api/logs      - Recent logs")
            print(f"   • GET  /api/status    - System status")
            print(f"   • GET  /api/dashboard - Dashboard data")
            print(f"   • POST /api/data      - Receive Flutter data")
            print("=" * 50)
            print("📝 API Server Logs:")
            print("-" * 20)
            print(f"⏹️  Press Ctrl+C to stop the server")
            print("-" * 20)
            
            # Start serving
            httpd.serve_forever()
            
    except KeyboardInterrupt:
        print("\n" + "=" * 50)
        print("🛑 API Server stopped by user")
        print("👋 Thank you for using OneGate Observatory API!")
        print("=" * 50)
    except OSError as e:
        if e.errno == 48:  # Address already in use
            print(f"❌ Error: Port {API_PORT} is already in use")
            print(f"💡 Try using a different port or stop the existing service")
        else:
            print(f"❌ Error starting API server: {e}")
    except Exception as e:
        print(f"❌ Unexpected error: {e}")

if __name__ == "__main__":
    start_api_server()
