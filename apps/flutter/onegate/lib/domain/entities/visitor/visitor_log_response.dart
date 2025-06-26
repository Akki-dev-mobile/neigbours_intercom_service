/// Response model for v2 visitor log API that includes pagination and counts
class VisitorLogResponse {
  final List<dynamic> data;
  final int total;
  final int checkedInCount;
  final int checkedOutCount;
  final int currentPage;
  final int perPage;
  final int lastPage;
  final String? nextPageUrl;
  final String? prevPageUrl;

  VisitorLogResponse({
    required this.data,
    required this.total,
    required this.checkedInCount,
    required this.checkedOutCount,
    required this.currentPage,
    required this.perPage,
    required this.lastPage,
    this.nextPageUrl,
    this.prevPageUrl,
  });

  factory VisitorLogResponse.fromJson(Map<String, dynamic> json) {
    // Handle the actual API response structure where pagination data is nested under 'data'
    final responseData =
        json['data'] ?? json; // Handle both nested and flat structures

    // Extract visitor data array
    final visitorData = responseData['data'] ?? [];

    // Calculate counts from the visitor data if not provided directly
    int checkedInCount = 0;
    int checkedOutCount = 0;

    if (visitorData is List) {
      for (final visitor in visitorData) {
        if (visitor is Map<String, dynamic>) {
          final isCheckedOut = visitor['is_checked_out'] ?? false;
          if (isCheckedOut == true || isCheckedOut == 'true') {
            checkedOutCount++;
          } else {
            checkedInCount++;
          }
        }
      }
    }

    return VisitorLogResponse(
      data: visitorData is List ? visitorData : [],
      total: responseData['total'] ??
          (visitorData is List ? visitorData.length : 0),
      checkedInCount: responseData['checked_in_count'] ?? checkedInCount,
      checkedOutCount: responseData['checked_out_count'] ?? checkedOutCount,
      currentPage: responseData['current_page'] ?? 1,
      perPage: responseData['per_page'] ?? 20,
      lastPage: responseData['last_page'] ?? 1,
      nextPageUrl: responseData['next_page_url'],
      prevPageUrl: responseData['prev_page_url'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'total': total,
      'checked_in_count': checkedInCount,
      'checked_out_count': checkedOutCount,
      'current_page': currentPage,
      'per_page': perPage,
      'last_page': lastPage,
      'next_page_url': nextPageUrl,
      'prev_page_url': prevPageUrl,
    };
  }

  /// Get visitor in-out count (total)
  int get inOutCount => total;

  /// Get visitor-in count
  int get visitorInCount => checkedInCount;

  /// Get visitor-out count
  int get visitorOutCount => checkedOutCount;

  /// Check if there are more pages
  bool get hasNextPage => nextPageUrl != null;

  /// Check if there are previous pages
  bool get hasPrevPage => prevPageUrl != null;
}
