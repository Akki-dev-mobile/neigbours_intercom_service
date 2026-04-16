import 'dart:developer';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/models/staff_model.dart';
import 'package:flutter_onegate/presentation/features/staff/ui/staff_list_widget.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';

class StaffScreen extends StatefulWidget {
  const StaffScreen({Key? key}) : super(key: key);

  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  late Future<List<StaffModel>> _staffFuture = Future.value([]);
  final RemoteDataSource remoteDataSource = RemoteDataSource();
  final GateStorage _gateStorage = GateStorage();

  List<StaffModel> _staffListFull = [];
  List<StaffModel> _filteredStaffList = [];

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeSocietyId();
    _searchController.addListener(() {
      setState(() {}); // Rebuild UI when search text changes
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _initializeSocietyId() async {
    var societyID = await _gateStorage.getSocietyId();
    log('Society ID: $societyID');

    _staffFuture = remoteDataSource.fetchStaffList(societyID.toString());
    setState(() {});
  }

  void _filterStaffList(String query) {
    if (query.isEmpty) {
      _filteredStaffList = List.from(_staffListFull);
    } else {
      _filteredStaffList = _staffListFull.where((staff) {
        final staffName = staff.name.toLowerCase();
        return staffName.contains(query.toLowerCase());
      }).toList();
    }
    setState(() {});
  }

  void _clearSearch() {
    _searchController.clear();
    _filteredStaffList = List.from(_staffListFull);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('Staff')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Fixed search field at top
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 24 : 16,
              vertical: isTablet ? 16 : 12,
            ),
            child: _buildEnhancedSearchField(context, isTablet),
          ),
          // Scrollable content
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    FutureBuilder<List<StaffModel>>(
                      future: _staffFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return _buildEnhancedLoader(context, isTablet);
                        } else if (snapshot.hasError) {
                          return _buildErrorWidget(
                              context, isTablet, snapshot.error.toString());
                        } else if (snapshot.hasData) {
                          final freshData = snapshot.data!;

                          if (_staffListFull.isEmpty) {
                            _staffListFull = freshData;
                            _filteredStaffList = List.from(_staffListFull);
                          }

                          if (_filteredStaffList.isEmpty) {
                            return _buildNoStaffWidget();
                          }

                          // Show the filtered staff list
                          return StaffListWidget(staffList: _filteredStaffList);
                        } else {
                          return _buildNoStaffWidget();
                        }
                      },
                    ),
                    SizedBox(height: isTablet ? 120 : 100),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      // floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      // floatingActionButton: ElevatedButton.icon(
      //   style: ElevatedButton.styleFrom(
      //     backgroundColor: Theme.of(context).colorScheme.onSurface,
      //   ),
      //   onPressed: () {
      //     Navigator.of(context)
      //         .push(
      //       MaterialPageRoute(
      //         builder: (context) => const AddStaff(),
      //       ),
      //     )
      //         .then((_) {
      //       // Refresh the staff list after navigation
      //       _initializeSocietyId();
      //     });
      //   },
      //   label: Text(
      //     'Add Staff',
      //     style: Theme.of(context)
      //         .textTheme
      //         .bodyLarge
      //         ?.copyWith(color: Colors.white),
      //   ),
      //   icon: Icon(
      //     Icons.add,
      //     size: Theme.of(context).iconTheme.size,
      //     color: Colors.white,
      //   ),
      // ),
    );
  }

  // Enhanced section header
  Widget _buildEnhancedSectionHeader({
    required BuildContext context,
    required bool isTablet,
    required String title,
    required IconData icon,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.red.shade300.withOpacity(0.08),
            Colors.red.shade400.withOpacity(0.15),
            Colors.red.shade300.withOpacity(0.08),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.red.shade300.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 12 : 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.red.shade300,
                  Colors.red.shade400,
                ],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isTablet ? 28 : 24,
            ),
          ),
          SizedBox(width: isTablet ? 16 : 14),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xff212427),
                    fontSize: isTablet ? 22 : 20,
                    letterSpacing: 0.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced search field
  Widget _buildEnhancedSearchField(BuildContext context, bool isTablet) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.shade300,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (query) => _filterStaffList(query),
        cursorColor: const Color(0xffF44336),
        decoration: InputDecoration(
          hintText: context.tr('Search staff by name, category, or phone...'),
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: isTablet ? 16 : 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.red.shade400,
            size: isTablet ? 22 : 20,
          ),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () => _clearSearch(),
                )
              : null,
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 20 : 16,
            vertical: isTablet ? 16 : 14,
          ),
        ),
        style: TextStyle(
          fontSize: isTablet ? 16 : 14,
          fontWeight: FontWeight.w500,
          color: const Color(0xff212427),
        ),
      ),
    );
  }

  // Enhanced loader widget
  Widget _buildEnhancedLoader(BuildContext context, bool isTablet) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: isTablet ? 120 : 100),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Enhanced loading container with gate animation
            Container(
              padding: EdgeInsets.all(isTablet ? 40 : 32),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: isTablet ? 120 : 100,
                    height: isTablet ? 120 : 100,
                    child: _GateLoadingAnimation(isTablet: isTablet),
                  ),
                  SizedBox(height: isTablet ? 32 : 24),
                  Text(
                    context.tr('loadingStaffTitle'),
                    style: TextStyle(
                      color: const Color(0xff212427),
                      fontSize: isTablet ? 24 : 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                  SizedBox(height: isTablet ? 12 : 8),
                  Text(
                    context.tr('loadingStaffSubtitle'),
                    style: TextStyle(
                      color: const Color(0xff57636C),
                      fontSize: isTablet ? 16 : 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced error widget
  Widget _buildErrorWidget(BuildContext context, bool isTablet, String error) {
    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: isTablet ? 100 : 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Enhanced error icon container
            Container(
              padding: EdgeInsets.all(isTablet ? 40 : 32),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.red.shade50,
                    Colors.red.shade100.withOpacity(0.3),
                  ],
                ),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: Colors.red.shade200.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: isTablet ? 80 : 64,
                color: Colors.red.shade400,
              ),
            ),
            SizedBox(height: isTablet ? 32 : 24),

            // Enhanced title
            Text(
              'Unable to Load Staff',
              style: TextStyle(
                color: const Color(0xff212427),
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: isTablet ? 12 : 8),

            // Enhanced subtitle
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 60 : 40),
              child: Text(
                'There was an error loading the staff list. Please check your connection and try again.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: isTablet ? 16 : 14,
                  height: 1.4,
                ),
              ),
            ),
            SizedBox(height: isTablet ? 40 : 32),

            // Enhanced retry button
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    Color(0xff212427),
                    Color(0xff57636C),
                  ],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  // Retry loading staff list
                  _initializeSocietyId();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 32 : 24,
                    vertical: isTablet ? 16 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                ),
                label: Text(
                  'Try Again',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: isTablet ? 16 : 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// **🛑 Enhanced No Staff Available Widget**
  Widget _buildNoStaffWidget() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isSearching = _searchController.text.trim().isNotEmpty;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 40 : 24,
          vertical: isTablet ? 24 : 16,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardMaxWidth = isTablet ? 560.0 : constraints.maxWidth;
            final cardMinWidth = isTablet ? 460.0 : 300.0;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: cardMaxWidth,
                minWidth: cardMinWidth.clamp(0, cardMaxWidth).toDouble(),
              ),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 44 : 32,
                    vertical: isTablet ? 40 : 30,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: isTablet ? 100 : 80,
                        height: isTablet ? 100 : 80,
                        decoration: BoxDecoration(
                          color: const Color(0xffF44336).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.groups_outlined,
                          color: const Color(0xffF44336),
                          size: isTablet ? 42 : 34,
                        ),
                      ),
                      SizedBox(height: isTablet ? 28 : 22),
                      Text(
                        isSearching ? 'No Staff Found' : 'No Staff Available',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 24 : 21,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff212427),
                        ),
                      ),
                      SizedBox(height: isTablet ? 14 : 10),
                      Text(
                        isSearching
                            ? 'No staff members match your search. Try a different keyword.'
                            : 'There are currently no staff members registered in the system.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: isTablet ? 28 : 22),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Color(0xff212427),
                              Color(0xff57636C),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: isSearching
                              ? () {
                                  _searchController.clear();
                                  _filteredStaffList =
                                      List.from(_staffListFull);
                                  setState(() {});
                                }
                              : _initializeSocietyId,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 32 : 24,
                              vertical: isTablet ? 16 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(
                            Icons.refresh_rounded,
                            color: Colors.white,
                          ),
                          label: Text(
                            isSearching ? 'Clear Search' : 'Refresh',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: isTablet ? 16 : 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// --- Insert the dashboard loader animation widget ---
class _GateLoadingAnimation extends StatefulWidget {
  final bool isTablet;
  const _GateLoadingAnimation({required this.isTablet});
  @override
  _GateLoadingAnimationState createState() => _GateLoadingAnimationState();
}

class _GateLoadingAnimationState extends State<_GateLoadingAnimation>
    with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _gateAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _gateAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _rotationAnimation = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.isTablet ? 120 : 100,
          height: widget.isTablet ? 120 : 100,
          decoration: BoxDecoration(
            color: const Color(0xffF44336).withOpacity(0.05),
            borderRadius: BorderRadius.circular(widget.isTablet ? 20 : 16),
          ),
          child: Stack(
            children: [
              // Left gate door
              Positioned(
                left: 0,
                top: widget.isTablet ? 20 : 16,
                bottom: widget.isTablet ? 20 : 16,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: (widget.isTablet ? 40 : 32) -
                      (_gateAnimation.value * (widget.isTablet ? 15 : 12)),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xffF44336),
                        Color(0xffD32F2F),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(widget.isTablet ? 8 : 6),
                      bottomLeft: Radius.circular(widget.isTablet ? 8 : 6),
                      topRight: Radius.circular(widget.isTablet ? 4 : 3),
                      bottomRight: Radius.circular(widget.isTablet ? 4 : 3),
                    ),
                  ),
                ),
              ),
              // Right gate door
              Positioned(
                right: 0,
                top: widget.isTablet ? 20 : 16,
                bottom: widget.isTablet ? 20 : 16,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  width: (widget.isTablet ? 40 : 32) -
                      (_gateAnimation.value * (widget.isTablet ? 15 : 12)),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xffF44336),
                        Color(0xffD32F2F),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(widget.isTablet ? 8 : 6),
                      bottomRight: Radius.circular(widget.isTablet ? 8 : 6),
                      topLeft: Radius.circular(widget.isTablet ? 4 : 3),
                      bottomLeft: Radius.circular(widget.isTablet ? 4 : 3),
                    ),
                  ),
                ),
              ),
              // Center gate icon
              Center(
                child: Transform.rotate(
                  angle: _rotationAnimation.value * 2 * 3.14159,
                  child: Container(
                    padding: EdgeInsets.all(widget.isTablet ? 12 : 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(widget.isTablet ? 12 : 10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: widget.isTablet ? 8 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.sensor_door_rounded,
                      color: const Color(0xffF44336),
                      size: widget.isTablet ? 32 : 24,
                    ),
                  ),
                ),
              ),
              // Loading dots indicator
              Positioned(
                bottom: widget.isTablet ? 8 : 6,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(3, (index) {
                    return AnimatedContainer(
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      margin: EdgeInsets.symmetric(
                          horizontal: widget.isTablet ? 3 : 2),
                      width: widget.isTablet ? 8 : 6,
                      height: widget.isTablet ? 8 : 6,
                      decoration: BoxDecoration(
                        color: const Color(0xffF44336).withOpacity(
                          0.3 +
                              ((_controller.value + (index * 0.3)) % 1.0) * 0.7,
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
