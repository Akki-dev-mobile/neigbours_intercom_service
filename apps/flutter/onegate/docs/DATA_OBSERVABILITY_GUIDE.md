# OneGate Data Observability & Search Enhancement Guide

## Overview

This guide covers the comprehensive data handling, search, and monitoring improvements implemented in the OneGate Flutter application. The enhancements include Meilisearch integration for advanced search, ntfy.sh for push notifications, and a robust data observability system.

## Features Implemented

### 🔍 Advanced Search with Meilisearch
- **Real-time fuzzy search** for residents and visitors
- **Advanced filtering** by building, status, date ranges
- **Search suggestions** and auto-completion
- **Indexed search** for improved performance

### 📊 Data Health Monitoring
- **Periodic health checks** for data consistency
- **API endpoint monitoring**
- **Resident count validation** per building
- **Visitor data integrity checks**

### 🚨 Push Notifications via ntfy.sh
- **Real-time alerts** for data anomalies
- **API failure notifications**
- **Search service health alerts**
- **Customizable notification topics**

### 🔄 Background Data Observability
- **Automated health checks** every 30 minutes
- **Index synchronization** every 2 hours
- **Background task management** with Workmanager
- **Graceful error handling**

## Architecture

### Service Layer Structure
```
services/
├── search/
│   └── meilisearch_service.dart          # Search functionality
├── notifications/
│   └── ntfy_service.dart                 # Push notifications
├── data_health/
│   └── data_health_service.dart          # Health monitoring
└── background/
    └── data_observability_service.dart   # Background tasks
```

### UI Components
```
presentation/
├── widgets/
│   └── advanced_search_widget.dart       # Reusable search component
└── features/settings/
    └── data_observability_settings_screen.dart  # Settings UI
```

## Setup Instructions

### 1. Dependencies Installation

The following dependencies have been added to `pubspec.yaml`:

```yaml
dependencies:
  meilisearch: ^0.15.0      # Search engine
  workmanager: ^0.5.2       # Background tasks
  uuid: ^4.5.1              # Unique identifiers
```

Install dependencies:
```bash
cd apps/flutter/onegate
flutter pub get
```

### 2. Meilisearch Setup

#### Option A: Local Installation
```bash
# Install Meilisearch
curl -L https://install.meilisearch.com | sh

# Run Meilisearch
./meilisearch --master-key="your-master-key"
```

#### Option B: Docker
```bash
docker run -it --rm \
  -p 7700:7700 \
  -e MEILI_MASTER_KEY="your-master-key" \
  getmeili/meilisearch:v1.5
```

#### Configuration
Set Meilisearch configuration in the app:
```dart
final gateStorage = GateStorage();
await gateStorage.setMeilisearchHost('http://localhost:7700');
await gateStorage.setMeilisearchApiKey('your-master-key');
```

### 3. ntfy.sh Setup

#### Using Public ntfy.sh
No setup required - uses `https://ntfy.sh` by default.

#### Self-hosted ntfy.sh
```bash
# Install ntfy
sudo snap install ntfy

# Run ntfy server
ntfy serve
```

Configure in app:
```dart
final gateStorage = GateStorage();
await gateStorage.setNtfyUrl('https://your-ntfy-server.com');
```

### 4. Background Tasks Configuration

Background tasks are automatically configured but only run in debug mode for safety.

```dart
final observabilityService = DataObservabilityService();
await observabilityService.initialize();

// Start periodic health checks (30 minutes interval)
await observabilityService.startPeriodicHealthChecks();

// Start index sync (2 hours interval)
await observabilityService.startPeriodicIndexSync();
```

## Usage Guide

### Advanced Search Implementation

#### Basic Search Widget
```dart
AdvancedSearchWidget(
  hintText: 'Search residents...',
  searchType: SearchType.residents,
  onSearchResults: (results) {
    // Handle search results
    setState(() {
      searchResults = results;
    });
  },
  showFilters: true,
  showSuggestions: true,
)
```

#### Search with Filters
```dart
AdvancedSearchWidget(
  hintText: 'Search visitors...',
  searchType: SearchType.visitors,
  filters: {
    'building': 'Tower A',
    'isStaff': false,
    'dateRange': DateTimeRange(
      start: DateTime.now().subtract(Duration(days: 7)),
      end: DateTime.now(),
    ),
  },
  onSearchResults: (results) {
    // Process filtered results
  },
)
```

### Data Health Monitoring

#### Manual Health Check
```dart
final healthService = DataHealthService();
await healthService.initialize();

final result = await healthService.performHealthCheck();
print('Overall Status: ${result.overallStatus}');
print('Resident Check: ${result.residentDataCheck?.status}');
print('API Health: ${result.apiHealthCheck?.status}');
```

#### Accessing Health Check Results
```dart
final lastResult = await healthService.getLastHealthCheckResult();
if (lastResult != null) {
  print('Last check: ${lastResult.timestamp}');
  print('Status: ${lastResult.overallStatus}');
}
```

### Push Notifications

#### Sending Custom Alerts
```dart
final ntfyService = NtfyService();
await ntfyService.initialize();

// Data anomaly alert
await ntfyService.sendDataAnomalyAlert(
  title: 'Data Inconsistency Detected',
  message: 'Resident count mismatch in Tower A',
  data: {'building': 'Tower A', 'expected': 100, 'actual': 95},
  priority: AlertPriority.high,
);

// API error alert
await ntfyService.sendApiErrorAlert(
  title: 'API Endpoint Failed',
  message: 'Members API is not responding',
  data: {'endpoint': '/api/members'},
);
```

#### Subscribing to Notifications
Subscribe to ntfy.sh topics:
- `onegate/data-anomaly` - Data inconsistency alerts
- `onegate/search-error` - Search service errors
- `onegate/api-error` - API failures
- `onegate/health-check` - System health alerts

### Settings Screen Integration

Add the data observability settings to your app:

```dart
// In your settings menu
ListTile(
  title: Text('Data Observability'),
  subtitle: Text('Monitor system health and search'),
  trailing: Icon(Icons.chevron_right),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DataObservabilitySettingsScreen(),
      ),
    );
  },
)
```

## API Enhancements

### Fixed Data Handling Issues

#### Pagination Improvements
- Removed artificial limits in `getMembersList()`
- Added proper error handling for incomplete responses
- Implemented retry logic for failed requests

#### Data Validation
- Added null safety checks
- Implemented data consistency validation
- Enhanced error reporting

### Enhanced Search Capabilities

#### Resident Search
```dart
final results = await meilisearchService.searchResidents(
  query: 'john',
  building: 'Tower A',
  memberStatus: 'Active',
  approved: true,
  limit: 20,
);
```

#### Visitor Search
```dart
final results = await meilisearchService.searchVisitors(
  query: 'visitor name',
  isStaff: false,
  fromDate: DateTime.now().subtract(Duration(days: 30)),
  toDate: DateTime.now(),
);
```

## Monitoring & Alerts

### Health Check Components

1. **Resident Data Check**
   - Validates resident count per building
   - Checks for missing required fields
   - Detects duplicate entries

2. **Visitor Data Check**
   - Validates visitor logs consistency
   - Checks for missing visitor information
   - Detects anomalies in visit patterns

3. **API Health Check**
   - Tests all critical API endpoints
   - Monitors response times
   - Validates response data structure

4. **Meilisearch Health Check**
   - Verifies search service availability
   - Checks index health
   - Monitors search performance

### Alert Types

#### Data Anomaly Alerts
- Resident count mismatches
- Missing required data fields
- Duplicate entries
- Inconsistent timestamps

#### System Health Alerts
- API endpoint failures
- Search service unavailability
- Background task failures
- Database connectivity issues

## Testing

### Running Tests
```bash
cd apps/flutter/onegate
flutter test test/services/data_observability_test.dart
```

### Test Coverage
- Unit tests for all service classes
- Integration tests for end-to-end workflows
- Mock implementations for external dependencies
- Error handling validation

### Manual Testing Checklist

#### Search Functionality
- [ ] Basic text search works
- [ ] Filters apply correctly
- [ ] Suggestions appear and work
- [ ] Search results are accurate
- [ ] Performance is acceptable

#### Health Monitoring
- [ ] Manual health check completes
- [ ] Results are stored and retrievable
- [ ] Alerts are sent for issues
- [ ] Background tasks run correctly

#### Notifications
- [ ] Test notifications send successfully
- [ ] Alert priorities work correctly
- [ ] Custom data is included
- [ ] Topics are correctly formatted

## Troubleshooting

### Common Issues

#### Meilisearch Connection Failed
```
Error: Connection refused to Meilisearch server
```
**Solution:** Verify Meilisearch is running and accessible at the configured URL.

#### Background Tasks Not Running
```
Warning: Background tasks disabled in release mode
```
**Solution:** Background tasks only run in debug mode for safety. This is expected behavior.

#### ntfy.sh Notifications Not Received
```
Error: Failed to send notification
```
**Solution:** Check network connectivity and ntfy.sh server availability.

#### Search Results Empty
```
Warning: No search results returned
```
**Solution:** Ensure data has been indexed in Meilisearch and indexes are healthy.

### Debug Mode Features

The following features are only available in debug mode:
- Background health checks
- Automatic index synchronization
- Detailed logging
- Network request monitoring

### Performance Considerations

#### Search Performance
- Meilisearch provides sub-millisecond search responses
- Indexes are optimized for common search patterns
- Pagination limits prevent memory issues

#### Background Task Impact
- Health checks run every 30 minutes (configurable)
- Index sync runs every 2 hours (configurable)
- Tasks are cancelled when app is closed

## Future Enhancements

### Planned Features
1. **Advanced Analytics Dashboard**
   - Visual health status indicators
   - Historical trend analysis
   - Performance metrics

2. **Machine Learning Integration**
   - Anomaly detection algorithms
   - Predictive health monitoring
   - Smart alerting thresholds

3. **Enhanced Search Features**
   - Voice search integration
   - Image-based search
   - Semantic search capabilities

4. **Extended Monitoring**
   - Device performance metrics
   - Network quality monitoring
   - User behavior analytics

## Support

For issues or questions regarding the data observability features:

1. Check the troubleshooting section above
2. Review the test files for usage examples
3. Examine the service implementations for detailed behavior
4. Consult the Flutter and Meilisearch documentation

## Contributing

When contributing to the data observability features:

1. Follow the existing service architecture patterns
2. Add comprehensive tests for new functionality
3. Update documentation for any API changes
4. Ensure backward compatibility
5. Test in both debug and release modes

---

# OneGate User Guide - Enhanced Search & Monitoring

## For End Users

### Enhanced Search Features

#### Quick Search
1. **Access Search**: Tap the search icon in any resident or visitor list
2. **Type to Search**: Start typing a name, flat number, or mobile number
3. **View Suggestions**: Tap on suggested results for quick selection
4. **Clear Search**: Tap the 'X' button to clear and start over

#### Advanced Filters
1. **Open Filters**: Tap the filter icon next to the search bar
2. **Select Building**: Choose specific building/tower
3. **Set Date Range**: Pick start and end dates for visitor searches
4. **Apply Status Filters**: Filter by active/inactive members or staff/visitors
5. **Apply Filters**: Tap 'Apply' to see filtered results

#### Search Tips
- **Minimum Characters**: Type at least 2 characters for search
- **Partial Matching**: Search works with partial names or numbers
- **Multiple Filters**: Combine multiple filters for precise results
- **Real-time Results**: Results update as you type

### System Health Monitoring (Admin Users)

#### Accessing Health Dashboard
1. **Open Settings**: Navigate to app settings
2. **Select Data Observability**: Tap on 'Data Observability' option
3. **View Status**: See overall system health at a glance

#### Understanding Health Status
- **🟢 Healthy**: All systems operating normally
- **🟡 Warning**: Minor issues detected, system functional
- **🔴 Critical**: Serious issues requiring attention

#### Health Check Components
- **Resident Data**: Validates resident information consistency
- **Visitor Data**: Checks visitor log integrity
- **API Health**: Monitors server connectivity
- **Search Service**: Verifies search functionality

#### Manual Health Check
1. **Tap 'Run Health Check'**: Initiates immediate system scan
2. **Wait for Results**: Check completes in 30-60 seconds
3. **Review Details**: Tap on individual components for details
4. **Take Action**: Follow recommendations for any issues

### Network Logs (Debug Mode Only)

#### Viewing Network Activity
1. **Access Settings**: Go to Data Observability settings
2. **Tap Network Logs**: View all API requests and responses
3. **Filter by Date**: Select specific time periods
4. **Search Logs**: Find specific API calls or errors

#### Understanding Log Entries
- **Green Entries**: Successful API calls
- **Red Entries**: Failed requests or errors
- **Yellow Entries**: Warnings or slow responses
- **Timestamps**: When each request occurred

### Notifications

#### Receiving Alerts
- **System Health**: Automatic alerts for critical issues
- **Data Anomalies**: Notifications for data inconsistencies
- **Search Errors**: Alerts when search service fails

#### Notification Topics
Subscribe to these topics on ntfy.sh:
- `onegate/data-anomaly`
- `onegate/search-error`
- `onegate/api-error`
- `onegate/health-check`

### Troubleshooting for Users

#### Search Not Working
1. **Check Internet**: Ensure stable internet connection
2. **Try Different Terms**: Use alternative search keywords
3. **Clear Filters**: Remove all filters and try again
4. **Restart App**: Close and reopen the application

#### Slow Performance
1. **Check Network**: Verify internet speed
2. **Clear Cache**: Clear app cache in device settings
3. **Update App**: Ensure latest version is installed
4. **Restart Device**: Reboot your device

#### Missing Data
1. **Refresh Screen**: Pull down to refresh data
2. **Check Filters**: Ensure no restrictive filters are applied
3. **Verify Permissions**: Confirm you have access to the data
4. **Contact Admin**: Report persistent issues to administrator

### Best Practices

#### Efficient Searching
- Use specific terms for faster results
- Apply filters to narrow down large datasets
- Save frequently used filter combinations
- Clear search when switching between different data types

#### Data Management
- Report any inconsistencies immediately
- Verify visitor information before entry
- Keep resident data updated
- Use proper naming conventions

#### System Monitoring
- Check health status regularly (admins)
- Monitor notification channels
- Report system issues promptly
- Keep app updated to latest version
