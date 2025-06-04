# OneGate Observatory & Monitoring Stack Integration Guide

## Overview

This guide covers the complete integration of the OneApp Observatory & Monitoring Stack into the OneGate Flutter application. The integration enhances OneGate's existing monitoring infrastructure with enterprise-grade observability platforms.

## 🏗️ Architecture Overview

### Existing OneGate Infrastructure
- ✅ **Network Logging**: Dio interceptors with Hive storage
- ✅ **Crash Reporting**: Comprehensive error tracking
- ✅ **Analytics Service**: Event tracking and performance monitoring
- ✅ **Data Health Monitoring**: API health checks and data consistency
- ✅ **Custom Notifications**: Self-hosted notification system
- ✅ **Meilisearch Integration**: Advanced search with health monitoring

### New Observatory Stack Components
- 🆕 **Observatory Dashboard Service**: Centralized monitoring hub
- 🆕 **SigNoz APM**: Application Performance Monitoring
- 🆕 **Grafana Dashboards**: Visual monitoring interface
- 🆕 **PostHog Analytics**: Advanced user analytics
- 🆕 **HyperDX Logs**: Log aggregation and session replay
- 🆕 **SkyWalking Tracing**: Distributed tracing
- 🆕 **Highlight Session**: Session replay and monitoring
- 🆕 **Sentry Integration**: Error tracking and performance
- 🆕 **Prometheus Metrics**: Time-series metrics collection
- 🆕 **Loki Logs**: Log aggregation
- 🆕 **Tempo Tracing**: Distributed tracing backend

## 🚀 Quick Start

### 1. Start the Observatory Stack

```bash
cd apps/flutter/onegate/docker/observatory-stack
chmod +x start-observatory.sh
./start-observatory.sh
```

### 2. Install Flutter Dependencies

```bash
cd apps/flutter/onegate
flutter pub get
```

### 3. Initialize Observatory in OneGate

The Observatory Dashboard Service is automatically initialized when you access the Data Observability settings:

1. Open OneGate app
2. Go to Settings → Data Observability
3. Tap "Start" on the Observatory Dashboard card
4. Tap "Open Dashboard" to access the monitoring interface

## 📊 Monitoring Platforms

### SigNoz APM (localhost:3301)
- **Purpose**: Application Performance Monitoring
- **Features**: 
  - Request tracing
  - Performance metrics
  - Error tracking
  - Service maps
- **Integration**: Automatic via OTLP protocol

### Grafana (localhost:3000)
- **Purpose**: Visual dashboards and alerting
- **Credentials**: admin/admin
- **Features**:
  - Custom dashboards
  - Real-time metrics
  - Alerting rules
  - Data source integration
- **Integration**: Prometheus, Loki, and Tempo data sources

### PostHog Analytics (localhost:8000)
- **Purpose**: Product analytics and user behavior
- **Features**:
  - Event tracking
  - User journeys
  - Feature flags
  - A/B testing
- **Integration**: REST API and event streaming

### HyperDX Logs (localhost:8080)
- **Purpose**: Log aggregation and session replay
- **Features**:
  - Structured logging
  - Session replay
  - Error correlation
  - Performance insights
- **Integration**: HTTP log ingestion

### SkyWalking (localhost:8080)
- **Purpose**: Distributed tracing and service mesh monitoring
- **Features**:
  - Service topology
  - Trace analysis
  - Performance metrics
  - Service dependencies
- **Integration**: OpenTracing protocol

### Highlight Session (localhost:4318)
- **Purpose**: Session replay and user experience monitoring
- **Features**:
  - Session recordings
  - User interactions
  - Performance monitoring
  - Error tracking
- **Integration**: JavaScript SDK and API

## 🔧 Configuration

### Observatory Service Configuration

The Observatory Dashboard Service can be configured through the OneGate app or by updating the configuration directly:

```dart
await observatoryService.updateConfiguration({
  'dashboardUrl': 'http://localhost:5015',
  'signozUrl': 'http://localhost:3301',
  'grafanaUrl': 'http://localhost:3000',
  'postHogUrl': 'http://localhost:8000',
  'hyperDxUrl': 'http://localhost:8080',
  'skyWalkingUrl': 'http://localhost:8080',
  'highlightUrl': 'http://localhost:4318',
  'enableRealTimeMetrics': true,
  'metricsCollectionInterval': 30, // seconds
});
```

### Environment-Specific URLs

For production deployments, update the URLs to point to your hosted monitoring infrastructure:

```dart
// Production configuration example
final productionConfig = {
  'dashboardUrl': 'https://observatory.yourdomain.com',
  'signozUrl': 'https://signoz.yourdomain.com',
  'grafanaUrl': 'https://grafana.yourdomain.com',
  // ... other URLs
};
```

## 📱 Flutter Integration

### Automatic Metrics Collection

The Observatory service automatically collects and sends metrics from:

1. **Network Requests**: Via existing Dio interceptors
2. **Crash Reports**: From CrashReporterService
3. **Analytics Events**: From AnalyticsService
4. **Health Checks**: From DataHealthService
5. **Performance Metrics**: Flutter-specific performance data

### Manual Event Tracking

You can manually track custom events:

```dart
final observatoryService = ObservatoryDashboardService();

// Track custom events
await observatoryService.trackCustomEvent('user_action', {
  'action': 'button_click',
  'screen': 'visitor_details',
  'timestamp': DateTime.now().toIso8601String(),
});

// Track performance metrics
await observatoryService.trackPerformanceMetric('screen_load_time', {
  'screen': 'dashboard',
  'load_time_ms': 1250,
  'user_id': 'user123',
});
```

### Real-time Monitoring

The service supports real-time monitoring via WebSocket connections:

```dart
// Real-time metrics are automatically streamed to connected dashboards
// Access real-time data in your UI:
final realtimeMetrics = observatoryService.getRealTimeMetrics();
```

## 🎯 Dashboard Access

### Observatory Dashboard (localhost:5015)
- **Main Hub**: Centralized view of all monitoring data
- **Features**: 
  - Real-time metrics
  - Service health status
  - Alert management
  - Configuration interface

### Consolidated Dashboard (localhost:3002)
- **Enhanced View**: Advanced analytics and reporting
- **Features**:
  - Historical trends
  - Performance analysis
  - Custom reports
  - Data export

### Mobile App Integration
- **Settings Path**: Settings → Data Observability → Observatory Dashboard
- **Features**:
  - Real-time metrics view
  - Platform status monitoring
  - Configuration management
  - Quick access to web dashboards

## 🔍 Monitoring Capabilities

### Application Performance
- **Response Times**: API call latency tracking
- **Error Rates**: Request failure monitoring
- **Throughput**: Request volume metrics
- **Resource Usage**: Memory and CPU monitoring

### User Experience
- **Session Tracking**: User journey analysis
- **Crash Monitoring**: Real-time crash detection
- **Performance Issues**: Slow operation identification
- **Feature Usage**: User interaction analytics

### Infrastructure Health
- **Service Availability**: Uptime monitoring
- **Database Performance**: Query performance tracking
- **Network Health**: Connectivity monitoring
- **Resource Utilization**: System resource tracking

## 🚨 Alerting

### Automatic Alerts
- **Crash Detection**: Immediate crash notifications
- **Performance Degradation**: Slow response alerts
- **Service Failures**: Downtime notifications
- **Error Spikes**: Unusual error rate alerts

### Custom Alerts
Configure custom alerting rules in Grafana:

1. Access Grafana at localhost:3000
2. Navigate to Alerting → Alert Rules
3. Create custom rules based on your metrics
4. Configure notification channels

## 🧪 Testing

### Running Tests

```bash
cd apps/flutter/onegate
flutter test test/services/observatory/
```

### Integration Testing

```bash
# Test Observatory service integration
flutter test test/integration/observatory_integration_test.dart

# Test monitoring platform connectivity
flutter test test/integration/monitoring_platforms_test.dart
```

### Manual Testing Checklist

- [ ] Observatory service initializes successfully
- [ ] Metrics are collected and sent to platforms
- [ ] Real-time data updates in dashboards
- [ ] WebSocket connections are stable
- [ ] Error handling works correctly
- [ ] Configuration updates are applied
- [ ] All monitoring platforms are accessible

## 🔒 Security Considerations

### API Keys and Secrets
- Store sensitive configuration in secure storage
- Use environment variables for production deployments
- Implement proper authentication for monitoring endpoints

### Data Privacy
- Ensure user data is anonymized in analytics
- Implement data retention policies
- Comply with privacy regulations (GDPR, CCPA)

### Network Security
- Use HTTPS for all monitoring endpoints
- Implement proper firewall rules
- Monitor for suspicious activity

## 🚀 Production Deployment

### Docker Deployment

```bash
# Build and deploy the monitoring stack
docker-compose -f docker-compose.prod.yml up -d

# Scale services as needed
docker-compose scale signoz-otel-collector=3
docker-compose scale grafana=2
```

### Kubernetes Deployment

```yaml
# Example Kubernetes deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: observatory-dashboard
spec:
  replicas: 3
  selector:
    matchLabels:
      app: observatory-dashboard
  template:
    metadata:
      labels:
        app: observatory-dashboard
    spec:
      containers:
      - name: dashboard
        image: onegate/observatory-dashboard:latest
        ports:
        - containerPort: 5015
```

### Cloud Deployment
- **AWS**: Use ECS/EKS for container orchestration
- **GCP**: Deploy on Google Kubernetes Engine
- **Azure**: Use Azure Container Instances or AKS

## 📈 Performance Optimization

### Metrics Collection
- Batch metrics to reduce network overhead
- Implement sampling for high-volume events
- Use compression for data transmission

### Storage Optimization
- Configure appropriate retention policies
- Implement data archiving strategies
- Monitor storage usage and costs

### Network Optimization
- Use CDN for dashboard assets
- Implement caching strategies
- Optimize WebSocket connections

## 🛠️ Troubleshooting

### Common Issues

1. **Service Not Starting**
   ```bash
   # Check Docker logs
   docker-compose logs [service-name]
   
   # Verify port availability
   netstat -tulpn | grep [port]
   ```

2. **Metrics Not Appearing**
   - Verify Observatory service initialization
   - Check network connectivity to monitoring platforms
   - Validate configuration URLs

3. **WebSocket Connection Issues**
   - Check firewall settings
   - Verify WebSocket endpoint URLs
   - Monitor connection stability

### Debug Mode
Enable debug logging in the Observatory service:

```dart
await observatoryService.updateConfiguration({
  'debugMode': true,
  'logLevel': 'debug',
});
```

## 📚 Additional Resources

- [SigNoz Documentation](https://signoz.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [PostHog Documentation](https://posthog.com/docs)
- [OpenTelemetry Documentation](https://opentelemetry.io/docs/)
- [Flutter Performance Best Practices](https://flutter.dev/docs/perf)

## 🤝 Contributing

To contribute to the Observatory integration:

1. Fork the repository
2. Create a feature branch
3. Implement your changes
4. Add comprehensive tests
5. Update documentation
6. Submit a pull request

## 📄 License

This integration follows the same license as the OneGate project.

---

**Happy Monitoring! 🚀**

For support and questions, please refer to the project documentation or create an issue in the repository.
