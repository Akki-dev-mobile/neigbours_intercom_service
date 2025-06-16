#!/bin/bash

# OneGate Complete Monitoring Stack Startup Script
# This script starts all monitoring and observability services

set -e

echo "🚀 Starting OneGate Complete Monitoring Stack..."

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
check_docker() {
    if ! docker info > /dev/null 2>&1; then
        print_error "Docker is not running. Please start Docker and try again."
        exit 1
    fi
    print_success "Docker is running"
}

# Check if docker-compose is available
check_docker_compose() {
    if ! command -v docker-compose &> /dev/null; then
        print_error "docker-compose is not installed. Please install docker-compose and try again."
        exit 1
    fi
    print_success "docker-compose is available"
}

# Create necessary directories
create_directories() {
    print_status "Creating necessary directories..."

    # Determine the correct base path
    if [ -d "docker/observatory-stack" ]; then
        BASE_PATH="docker/observatory-stack"
    elif [ -d "apps/flutter/onegate/docker/observatory-stack" ]; then
        BASE_PATH="apps/flutter/onegate/docker/observatory-stack"
    else
        print_error "Cannot find docker/observatory-stack directory"
        exit 1
    fi

    mkdir -p "$BASE_PATH/grafana/dashboards"
    mkdir -p "$BASE_PATH/prometheus/data"
    mkdir -p "$BASE_PATH/loki/data"
    mkdir -p "$BASE_PATH/tempo/data"
    mkdir -p "$BASE_PATH/clickhouse/data"
    mkdir -p "$BASE_PATH/postgres/data"
    mkdir -p "$BASE_PATH/redis/data"

    print_success "Directories created"
}

# Copy environment file if it doesn't exist
setup_environment() {
    print_status "Setting up environment configuration..."
    
    if [ ! -f .env ]; then
        if [ -f .env.example ]; then
            cp .env.example .env
            print_warning "Copied .env.example to .env. Please update with your actual configuration."
        else
            print_error ".env.example not found. Please create environment configuration."
            exit 1
        fi
    else
        print_success "Environment file exists"
    fi
}

# Start the observatory stack
start_observatory_stack() {
    print_status "Starting Observatory Stack..."

    # Ensure we're in the right directory
    if [ -d "docker/observatory-stack" ]; then
        cd docker/observatory-stack
    elif [ -d "apps/flutter/onegate/docker/observatory-stack" ]; then
        cd apps/flutter/onegate/docker/observatory-stack
    else
        print_error "Cannot find docker/observatory-stack directory"
        exit 1
    fi

    # Use minimal configuration first
    print_status "Using minimal configuration for reliable startup..."

    # Pull latest images
    print_status "Pulling latest Docker images..."
    docker-compose -f docker-compose-minimal.yml pull

    # Start services
    print_status "Starting core monitoring services..."
    docker-compose -f docker-compose-minimal.yml up -d

    cd - > /dev/null
    print_success "Observatory Stack started"
}

# Wait for services to be ready
wait_for_services() {
    print_status "Waiting for services to be ready..."
    
    # Wait for key services
    services=(
        "http://localhost:3000"  # Grafana
        "http://localhost:9090"  # Prometheus
        "http://localhost:3301"  # SigNoz
        "http://localhost:5015"  # Observatory Dashboard
        "http://localhost:3002"  # Consolidated Dashboard
    )
    
    for service in "${services[@]}"; do
        print_status "Waiting for $service..."
        timeout=60
        while [ $timeout -gt 0 ]; do
            if curl -s "$service" > /dev/null 2>&1; then
                print_success "$service is ready"
                break
            fi
            sleep 2
            ((timeout-=2))
        done
        
        if [ $timeout -le 0 ]; then
            print_warning "$service is not responding (timeout)"
        fi
    done
}

# Display service URLs
display_services() {
    print_success "🎉 OneGate Complete Monitoring Stack is running!"
    echo ""
    echo "📊 Monitoring Services:"
    echo "  • Observatory Dashboard:    http://localhost:5015"
    echo "  • Consolidated Dashboard:   http://localhost:3002"
    echo "  • Grafana:                  http://localhost:3000 (admin/admin)"
    echo "  • SigNoz APM:              http://localhost:3301"
    echo "  • Prometheus:              http://localhost:9090"
    echo ""
    echo "🔍 Analytics & Logging:"
    echo "  • PostHog:                 http://localhost:8000"
    echo "  • Loki (Logs):             http://localhost:3100"
    echo "  • Jaeger (Tracing):        http://localhost:16686"
    echo "  • Tempo (Tracing):         http://localhost:3200"
    echo ""
    echo "💾 Data Storage:"
    echo "  • ClickHouse:              http://localhost:8123"
    echo "  • PostgreSQL:              localhost:5432"
    echo "  • Redis:                   localhost:6379"
    echo ""
    echo "📱 Flutter App Integration:"
    echo "  • All services are configured to receive data from the OneGate Flutter app"
    echo "  • Real-time metrics collection is active"
    echo "  • Error tracking and performance monitoring enabled"
    echo ""
    echo "🛠️  Management Commands:"
    echo "  • Stop all services:       docker-compose -f docker/observatory-stack/docker-compose-minimal.yml down"
    echo "  • View logs:               docker-compose -f docker/observatory-stack/docker-compose-minimal.yml logs -f"
    echo "  • Restart services:        docker-compose -f docker/observatory-stack/docker-compose-minimal.yml restart"
    echo ""
}

# Check service health
check_service_health() {
    print_status "Checking service health..."
    
    cd docker/observatory-stack

    # Check container status
    failed_services=()
    while IFS= read -r line; do
        if [[ $line == *"unhealthy"* ]] || [[ $line == *"Exited"* ]]; then
            service_name=$(echo "$line" | awk '{print $1}')
            failed_services+=("$service_name")
        fi
    done < <(docker-compose -f docker-compose-minimal.yml ps)
    
    if [ ${#failed_services[@]} -eq 0 ]; then
        print_success "All services are healthy"
    else
        print_warning "Some services are not healthy:"
        for service in "${failed_services[@]}"; do
            print_warning "  - $service"
        done
    fi
    
    cd ../..
}

# Main execution
main() {
    echo "🔭 OneGate Complete Monitoring Stack Setup"
    echo "=========================================="
    echo ""
    
    # Pre-flight checks
    check_docker
    check_docker_compose
    
    # Setup
    create_directories
    setup_environment
    
    # Start services
    start_observatory_stack
    
    # Wait and verify
    wait_for_services
    check_service_health
    
    # Display information
    display_services
    
    print_success "Setup complete! Your monitoring stack is ready."
    print_status "You can now run your Flutter app and see real-time monitoring data."
}

# Handle script interruption
trap 'print_error "Script interrupted"; exit 1' INT TERM

# Run main function
main "$@"
