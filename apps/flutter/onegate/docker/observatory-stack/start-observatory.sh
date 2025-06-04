#!/bin/bash

# OneGate Observatory & Monitoring Stack Startup Script
# This script starts the complete monitoring infrastructure for OneGate Flutter app

set -e

echo "🚀 Starting OneGate Observatory & Monitoring Stack..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Docker is running
if ! docker info > /dev/null 2>&1; then
    print_error "Docker is not running. Please start Docker and try again."
    exit 1
fi

# Check if Docker Compose is available
if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose is not installed. Please install Docker Compose and try again."
    exit 1
fi

# Create necessary directories
print_status "Creating necessary directories..."
mkdir -p config
mkdir -p dashboard
mkdir -p consolidated
mkdir -p grafana/dashboards
mkdir -p grafana/provisioning/dashboards
mkdir -p grafana/provisioning/datasources
mkdir -p prometheus
mkdir -p loki
mkdir -p tempo
mkdir -p clickhouse
mkdir -p signoz
mkdir -p nginx
mkdir -p postgres
mkdir -p measure
mkdir -p logs

# Set permissions
chmod +x start-observatory.sh
chmod -R 755 config/

print_success "Directories created successfully"

# Create basic configuration files if they don't exist
print_status "Setting up configuration files..."

# Create Grafana dashboard provisioning config
cat > grafana/provisioning/dashboards/dashboards.yml << EOF
apiVersion: 1

providers:
  - name: 'default'
    orgId: 1
    folder: ''
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards
EOF

# Create Tempo configuration
cat > tempo/tempo.yaml << EOF
server:
  http_listen_port: 3200

distributor:
  receivers:
    jaeger:
      protocols:
        thrift_http:
          endpoint: 0.0.0.0:14268
        grpc:
          endpoint: 0.0.0.0:14250
    zipkin:
      endpoint: 0.0.0.0:9411
    otlp:
      protocols:
        http:
          endpoint: 0.0.0.0:4318
        grpc:
          endpoint: 0.0.0.0:4317

ingester:
  trace_idle_period: 10s
  max_block_bytes: 1_000_000
  max_block_duration: 5m

compactor:
  compaction:
    compaction_window: 1h
    max_compaction_objects: 1000000
    block_retention: 1h
    compacted_block_retention: 10m

storage:
  trace:
    backend: local
    local:
      path: /tmp/tempo/traces
    wal:
      path: /tmp/tempo/wal
    pool:
      max_workers: 100
      queue_depth: 10000
EOF

# Create ClickHouse configuration
cat > clickhouse/clickhouse-config.xml << EOF
<?xml version="1.0"?>
<yandex>
    <logger>
        <level>warning</level>
        <console>true</console>
    </logger>
    <http_port>8123</http_port>
    <tcp_port>9000</tcp_port>
    <openSSL>
        <server>
            <certificateFile>/etc/clickhouse-server/server.crt</certificateFile>
            <privateKeyFile>/etc/clickhouse-server/server.key</privateKeyFile>
            <dhParamsFile>/etc/clickhouse-server/dhparam.pem</dhParamsFile>
            <verificationMode>none</verificationMode>
            <loadDefaultCAFile>true</loadDefaultCAFile>
            <cacheSessions>true</cacheSessions>
            <disableProtocols>sslv2,sslv3</disableProtocols>
            <preferServerCiphers>true</preferServerCiphers>
        </server>
        <client>
            <loadDefaultCAFile>true</loadDefaultCAFile>
            <cacheSessions>true</cacheSessions>
            <disableProtocols>sslv2,sslv3</disableProtocols>
            <preferServerCiphers>true</preferServerCiphers>
            <verificationMode>none</verificationMode>
            <invalidCertificateHandler>
                <name>AcceptCertificateHandler</name>
            </invalidCertificateHandler>
        </client>
    </openSSL>
    <listen_host>::</listen_host>
    <listen_host>0.0.0.0</listen_host>
    <max_connections>4096</max_connections>
    <keep_alive_timeout>3</keep_alive_timeout>
    <max_concurrent_queries>100</max_concurrent_queries>
    <uncompressed_cache_size>8589934592</uncompressed_cache_size>
    <mark_cache_size>5368709120</mark_cache_size>
    <path>/var/lib/clickhouse/</path>
    <tmp_path>/var/lib/clickhouse/tmp/</tmp_path>
    <user_files_path>/var/lib/clickhouse/user_files/</user_files_path>
    <users_config>users.xml</users_config>
    <default_profile>default</default_profile>
    <default_database>default</default_database>
    <timezone>UTC</timezone>
    <mlock_executable>false</mlock_executable>
    <remote_servers>
        <test_shard_localhost>
            <shard>
                <replica>
                    <host>localhost</host>
                    <port>9000</port>
                </replica>
            </shard>
        </test_shard_localhost>
    </remote_servers>
    <zookeeper incl="zookeeper-servers" optional="true" />
    <macros incl="macros" optional="true" />
    <builtin_dictionaries_reload_interval>3600</builtin_dictionaries_reload_interval>
    <max_session_timeout>3600</max_session_timeout>
    <default_session_timeout>60</default_session_timeout>
    <query_log>
        <database>system</database>
        <table>query_log</table>
        <flush_interval_milliseconds>7500</flush_interval_milliseconds>
    </query_log>
    <dictionaries_config>*_dictionary.xml</dictionaries_config>
    <compression incl="clickhouse_compression">
    </compression>
    <distributed_ddl>
        <path>/clickhouse/task_queue/ddl</path>
    </distributed_ddl>
    <format_schema_path>/var/lib/clickhouse/format_schemas/</format_schema_path>
</yandex>
EOF

# Create ClickHouse users configuration
cat > clickhouse/clickhouse-users.xml << EOF
<?xml version="1.0"?>
<yandex>
    <profiles>
        <default>
            <max_memory_usage>10000000000</max_memory_usage>
            <use_uncompressed_cache>0</use_uncompressed_cache>
            <load_balancing>random</load_balancing>
        </default>
        <readonly>
            <readonly>1</readonly>
        </readonly>
    </profiles>
    <users>
        <default>
            <password></password>
            <networks incl="networks" replace="replace">
                <ip>::/0</ip>
            </networks>
            <profile>default</profile>
            <quota>default</quota>
        </default>
    </users>
    <quotas>
        <default>
            <interval>
                <duration>3600</duration>
                <queries>0</queries>
                <errors>0</errors>
                <result_rows>0</result_rows>
                <read_rows>0</read_rows>
                <execution_time>0</execution_time>
            </interval>
        </default>
    </quotas>
</yandex>
EOF

# Create SigNoz OTEL Collector configuration
cat > signoz/otel-collector-config.yaml << EOF
receivers:
  otlp:
    protocols:
      grpc:
        endpoint: 0.0.0.0:4317
      http:
        endpoint: 0.0.0.0:4318
  jaeger:
    protocols:
      grpc:
        endpoint: 0.0.0.0:14250
      thrift_http:
        endpoint: 0.0.0.0:14268
  zipkin:
    endpoint: 0.0.0.0:9411

processors:
  batch:
    timeout: 1s
    send_batch_size: 1024
  memory_limiter:
    limit_mib: 512

exporters:
  clickhouse:
    endpoint: tcp://clickhouse:9000?dial_timeout=10s&compress=lz4
    database: signoz_traces
    logs_table_name: otel_logs
    traces_table_name: otel_traces
    metrics_table_name: otel_metrics
    timeout: 5s
    retry_on_failure:
      enabled: true
      initial_interval: 5s
      max_interval: 30s
      max_elapsed_time: 300s

service:
  pipelines:
    traces:
      receivers: [otlp, jaeger, zipkin]
      processors: [memory_limiter, batch]
      exporters: [clickhouse]
    metrics:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [clickhouse]
    logs:
      receivers: [otlp]
      processors: [memory_limiter, batch]
      exporters: [clickhouse]
EOF

# Create PostgreSQL init script for multiple databases
cat > postgres/init-multiple-databases.sh << EOF
#!/bin/bash
set -e

function create_user_and_database() {
    local database=\$1
    echo "Creating user and database '\$database'"
    psql -v ON_ERROR_STOP=1 --username "\$POSTGRES_USER" <<-EOSQL
        CREATE DATABASE \$database;
EOSQL
}

if [ -n "\$POSTGRES_MULTIPLE_DATABASES" ]; then
    echo "Multiple database creation requested: \$POSTGRES_MULTIPLE_DATABASES"
    for db in \$(echo \$POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
        create_user_and_database \$db
    done
    echo "Multiple databases created"
fi
EOF

chmod +x postgres/init-multiple-databases.sh

# Create Nginx configuration
cat > nginx/nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    upstream observatory_dashboard {
        server observatory-dashboard:5015;
    }

    upstream consolidated_dashboard {
        server consolidated-dashboard:3002;
    }

    upstream grafana {
        server grafana:3000;
    }

    upstream signoz {
        server signoz-frontend:3301;
    }

    server {
        listen 80;
        server_name localhost;

        location / {
            proxy_pass http://observatory_dashboard;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /consolidated/ {
            proxy_pass http://consolidated_dashboard/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /grafana/ {
            proxy_pass http://grafana/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }

        location /signoz/ {
            proxy_pass http://signoz/;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF

print_success "Configuration files created successfully"

# Pull Docker images
print_status "Pulling Docker images..."
docker-compose pull

# Start the services
print_status "Starting Observatory & Monitoring Stack..."
docker-compose up -d

# Wait for services to be ready
print_status "Waiting for services to be ready..."
sleep 30

# Check service health
print_status "Checking service health..."

services=(
    "onegate-postgres:5432"
    "onegate-redis:6379"
    "onegate-clickhouse:8123"
    "onegate-grafana:3000"
    "onegate-prometheus:9090"
    "onegate-loki:3100"
    "onegate-tempo:3200"
)

for service in "${services[@]}"; do
    IFS=':' read -r container port <<< "$service"
    if docker exec "$container" nc -z localhost "$port" 2>/dev/null; then
        print_success "$container is ready on port $port"
    else
        print_warning "$container might not be ready yet on port $port"
    fi
done

# Display access URLs
echo ""
print_success "🎉 OneGate Observatory & Monitoring Stack is running!"
echo ""
echo "📊 Access URLs:"
echo "  • Observatory Dashboard:     http://localhost:5015"
echo "  • Consolidated Dashboard:    http://localhost:3002"
echo "  • Grafana:                   http://localhost:3000 (admin/admin)"
echo "  • SigNoz APM:               http://localhost:3301"
echo "  • Prometheus:               http://localhost:9090"
echo "  • PostHog Analytics:        http://localhost:8000"
echo "  • HyperDX Logs:             http://localhost:8080"
echo "  • SkyWalking UI:            http://localhost:8080"
echo "  • Highlight Session:        http://localhost:4318"
echo "  • Sentry Error Tracking:    http://localhost:9000"
echo ""
echo "🔧 Infrastructure:"
echo "  • PostgreSQL:               localhost:5432"
echo "  • Redis:                    localhost:6379"
echo "  • ClickHouse:               localhost:8123"
echo "  • Elasticsearch:            localhost:9200"
echo "  • Loki:                     localhost:3100"
echo "  • Tempo:                    localhost:3200"
echo ""
echo "📱 Flutter App Integration:"
echo "  • Update your OneGate app configuration to point to these endpoints"
echo "  • The Observatory Dashboard Service will automatically connect"
echo "  • Check the Data Observability settings in your app"
echo ""
print_status "To stop the stack: docker-compose down"
print_status "To view logs: docker-compose logs -f [service-name]"
print_status "To restart: docker-compose restart [service-name]"
echo ""
print_success "Happy monitoring! 🚀"
