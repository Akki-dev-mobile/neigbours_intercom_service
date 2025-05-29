import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/services/search/meilisearch_service.dart';
import 'package:ionicons/ionicons.dart';

/// Advanced search widget with Meilisearch integration
class AdvancedSearchWidget extends StatefulWidget {
  final String hintText;
  final SearchType searchType;
  final Function(List<Map<String, dynamic>>) onSearchResults;
  final Function(String)? onQueryChanged;
  final Map<String, dynamic>? filters;
  final bool showFilters;
  final bool showSuggestions;
  
  const AdvancedSearchWidget({
    Key? key,
    required this.hintText,
    required this.searchType,
    required this.onSearchResults,
    this.onQueryChanged,
    this.filters,
    this.showFilters = true,
    this.showSuggestions = true,
  }) : super(key: key);

  @override
  State<AdvancedSearchWidget> createState() => _AdvancedSearchWidgetState();
}

class _AdvancedSearchWidgetState extends State<AdvancedSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final MeilisearchService _meilisearchService = MeilisearchService();
  
  Timer? _debounceTimer;
  List<String> _suggestions = [];
  bool _isSearching = false;
  bool _showSuggestions = false;
  
  // Filter controllers
  String? _selectedBuilding;
  String? _selectedMemberStatus;
  bool? _approvedFilter;
  bool? _isStaffFilter;
  DateTimeRange? _dateRange;
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _searchFocusNode.addListener(_onFocusChanged);
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }
  
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    widget.onQueryChanged?.call(query);
    
    if (query.isEmpty) {
      setState(() {
        _suggestions.clear();
        _showSuggestions = false;
      });
      widget.onSearchResults([]);
      return;
    }
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
      if (widget.showSuggestions) {
        _getSuggestions(query);
      }
    });
  }
  
  void _onFocusChanged() {
    if (_searchFocusNode.hasFocus && _searchController.text.isNotEmpty && widget.showSuggestions) {
      setState(() => _showSuggestions = true);
    } else {
      setState(() => _showSuggestions = false);
    }
  }
  
  Future<void> _performSearch(String query) async {
    if (query.length < 2) return;
    
    setState(() => _isSearching = true);
    
    try {
      List<Map<String, dynamic>> results = [];
      
      switch (widget.searchType) {
        case SearchType.residents:
          results = await _meilisearchService.searchResidents(
            query: query,
            building: _selectedBuilding,
            memberStatus: _selectedMemberStatus,
            approved: _approvedFilter,
          );
          break;
        case SearchType.visitors:
          results = await _meilisearchService.searchVisitors(
            query: query,
            isStaff: _isStaffFilter,
            fromDate: _dateRange?.start,
            toDate: _dateRange?.end,
          );
          break;
      }
      
      widget.onSearchResults(results);
    } catch (e) {
      debugPrint('Search error: $e');
      widget.onSearchResults([]);
    } finally {
      setState(() => _isSearching = false);
    }
  }
  
  Future<void> _getSuggestions(String query) async {
    if (query.length < 2) return;
    
    try {
      final suggestions = await _meilisearchService.getSearchSuggestions(
        query,
        index: widget.searchType == SearchType.residents ? 'residents' : 'visitors',
      );
      
      setState(() {
        _suggestions = suggestions.take(5).toList();
        _showSuggestions = _searchFocusNode.hasFocus && suggestions.isNotEmpty;
      });
    } catch (e) {
      debugPrint('Suggestions error: $e');
    }
  }
  
  void _selectSuggestion(String suggestion) {
    _searchController.text = suggestion;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: suggestion.length),
    );
    setState(() => _showSuggestions = false);
    _performSearch(suggestion);
  }
  
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _suggestions.clear();
      _showSuggestions = false;
    });
    widget.onSearchResults([]);
  }
  
  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildFilterDialog(),
    );
  }
  
  Widget _buildFilterDialog() {
    return AlertDialog(
      title: const Text('Search Filters'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.searchType == SearchType.residents) ...[
              _buildBuildingFilter(),
              const SizedBox(height: 16),
              _buildMemberStatusFilter(),
              const SizedBox(height: 16),
              _buildApprovedFilter(),
            ] else ...[
              _buildStaffFilter(),
              const SizedBox(height: 16),
              _buildDateRangeFilter(),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            _clearFilters();
            Navigator.of(context).pop();
          },
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            _performSearch(_searchController.text);
          },
          child: const Text('Apply'),
        ),
      ],
    );
  }
  
  Widget _buildBuildingFilter() {
    return DropdownButtonFormField<String>(
      value: _selectedBuilding,
      decoration: const InputDecoration(
        labelText: 'Building',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Buildings')),
        // Add actual building options here
        const DropdownMenuItem(value: 'Tower A', child: Text('Tower A')),
        const DropdownMenuItem(value: 'Tower B', child: Text('Tower B')),
      ],
      onChanged: (value) => setState(() => _selectedBuilding = value),
    );
  }
  
  Widget _buildMemberStatusFilter() {
    return DropdownButtonFormField<String>(
      value: _selectedMemberStatus,
      decoration: const InputDecoration(
        labelText: 'Member Status',
        border: OutlineInputBorder(),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('All Statuses')),
        const DropdownMenuItem(value: 'Active', child: Text('Active')),
        const DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
      ],
      onChanged: (value) => setState(() => _selectedMemberStatus = value),
    );
  }
  
  Widget _buildApprovedFilter() {
    return CheckboxListTile(
      title: const Text('Approved Members Only'),
      value: _approvedFilter ?? false,
      tristate: true,
      onChanged: (value) => setState(() => _approvedFilter = value),
    );
  }
  
  Widget _buildStaffFilter() {
    return CheckboxListTile(
      title: const Text('Staff Only'),
      value: _isStaffFilter ?? false,
      tristate: true,
      onChanged: (value) => setState(() => _isStaffFilter = value),
    );
  }
  
  Widget _buildDateRangeFilter() {
    return ListTile(
      title: const Text('Date Range'),
      subtitle: _dateRange != null
          ? Text('${_dateRange!.start.toString().split(' ')[0]} - ${_dateRange!.end.toString().split(' ')[0]}')
          : const Text('All dates'),
      trailing: const Icon(Icons.date_range),
      onTap: () async {
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now(),
          initialDateRange: _dateRange,
        );
        if (range != null) {
          setState(() => _dateRange = range);
        }
      },
    );
  }
  
  void _clearFilters() {
    setState(() {
      _selectedBuilding = null;
      _selectedMemberStatus = null;
      _approvedFilter = null;
      _isStaffFilter = null;
      _dateRange = null;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    prefixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : const Icon(Ionicons.search_outline),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: _clearSearch,
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              if (widget.showFilters)
                IconButton(
                  icon: Icon(
                    Ionicons.options_outline,
                    color: _hasActiveFilters()
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  onPressed: _showFilterDialog,
                ),
            ],
          ),
        ),
        if (_showSuggestions && _suggestions.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
              ),
            ),
            child: Column(
              children: _suggestions.map((suggestion) {
                return ListTile(
                  dense: true,
                  leading: const Icon(Ionicons.search_outline, size: 16),
                  title: Text(suggestion),
                  onTap: () => _selectSuggestion(suggestion),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
  
  bool _hasActiveFilters() {
    return _selectedBuilding != null ||
           _selectedMemberStatus != null ||
           _approvedFilter != null ||
           _isStaffFilter != null ||
           _dateRange != null;
  }
}

enum SearchType {
  residents,
  visitors,
}
