import 'dart:async';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/parcel/bloc/parcel_bloc.dart';
import 'package:flutter_onegate/presentation/features/parcel/ui/parcel_details.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../bloc/parcel_state.dart';
import 'package:common_widgets/dashboard_loader.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';

class ParcelList extends StatefulWidget {
  const ParcelList({super.key});

  @override
  _ParcelListState createState() => _ParcelListState();
}

class _ParcelListState extends State<ParcelList> {
  RemoteDataSource remoteDataSource = RemoteDataSource();

  TextEditingController searchController = TextEditingController();
  List<dynamic> filteredParcels = [];
  Timer? _refreshTimer;
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  String _searchQuery = '';
  String? selectedBuilding = "All Buildings";

  @override
  void initState() {
    super.initState();
    _startAutoRefresh();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();

    context.read<ParcelBloc>().add(FetchParcels());
    context.read<ParcelBloc>().add(FetchParcels());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    context.read<ParcelBloc>().add(FetchParcels());
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) {
        context.read<ParcelBloc>().add(FetchParcels());
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Widget _buildSearchField() {
    return Column(
      children: [
        // Search field
        CustomForm.textField(
          "",
          hintText: AppLocalizations.of(context).searchMembers,
          titleColor: Theme.of(context).colorScheme.onSurface,
          hintColor: Theme.of(context).colorScheme.onSurface,
          focusNode: _searchFocusNode,
          prefixIcon: const Icon(Ionicons.search_outline),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                )
              : null,
          textController: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),

        // Building selection dropdown
        // BlocBuilder<ParcelBloc, ParcelState>(
        //   builder: (context, state) {
        //     // Extract building names from parcels using the helper method
        //     Set<String> buildingNames = {"All Buildings"};
        //
        //     if (state is ParcelLoaded) {
        //       buildingNames = BuildingDropdown.extractBuildingNames(
        //         state.parcels,
        //         getUnitName: (dynamic parcel) {
        //           if (parcel['unit_name'] != null &&
        //               parcel['unit_name'].toString().isNotEmpty) {
        //             return parcel['unit_name'].toString();
        //           }
        //           return "";
        //         },
        //       );
        //     }
        //
        //     List<String> sortedBuildingNames = buildingNames.toList();
        //
        //     return BuildingDropdown(
        //       selectedBuilding: selectedBuilding,
        //       onBuildingSelected: (String? value) {
        //         setState(() {
        //           selectedBuilding = value;
        //         });
        //       },
        //       buildingNames: sortedBuildingNames,
        //     );
        //   },
        // ),
      ],
    );
  }

  Widget parsalView(Map<String, dynamic> parcel) {
    final checkIn = parcel['visitor_check_in'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ListTile(
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ParcelDetails(parcel: parcel),
                  ),
                );

                // Refresh if any update happened in ParcelDetails
                if (result == true) {
                  if (context.mounted) {
                    context.read<ParcelBloc>().add(FetchParcels());
                  }
                }
              },
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              leading: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.grey.shade200,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 26,
                  backgroundImage: parcel['visitor_image'] != null &&
                          parcel['visitor_image'].toString().isNotEmpty
                      ? NetworkImage(parcel['visitor_image'])
                      : const NetworkImage(
                          'https://images.unsplash.com/photo-1731778572747-315c9089bc69?q=80&w=2940&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D'),
                  child: parcel['visitor_image'] == null ||
                          parcel['visitor_image'].toString().isEmpty
                      ? Text(
                          parcel['visitor_name'] != null &&
                                  parcel['visitor_name'].toString().isNotEmpty
                              ? parcel['visitor_name']
                                  .toString()[0]
                                  .toUpperCase()
                              : 'P',
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xffF44336),
                                  ),
                        )
                      : null,
                ),
              ),
              title: Text(
                parcel['visitor_name'] ?? 'Parcel Delivery',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xff212427),
                      fontSize: 16,
                      letterSpacing: 0.1,
                    ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xffF44336).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xffF44336).withOpacity(0.2),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            _getPurposeIcon(
                                parcel['purpose_sub_category_name']),
                            color: const Color(0xffF44336),
                            size: 15,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Flexible(
                          child: Text(
                            "${_capitalizeFirstLetter(parcel['purpose_sub_category_name']?.toString() ?? "Parcel")} - ${parcel['unit_name']?.toString() ?? 'N/A'}",
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  fontSize: 14,
                                  color: const Color(0xff57636C),
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.2,
                                  height: 1.4,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        )
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Divider(
              indent: 20,
              endIndent: 20,
              height: 24,
              thickness: 1,
              color: Colors.grey.shade200,
            ),
            Container(
              padding: const EdgeInsets.only(
                  bottom: 16.0, top: 12, left: 20, right: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Tooltip(
                    message: checkIn != null
                        ? DateFormat('dd-MM-yyyy hh:mm a').format(
                            DateTime.tryParse(checkIn) ?? DateTime.now(),
                          )
                        : "No check-in time",
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.green.shade200,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Symbols.directions_walk_rounded,
                            color: Colors.green.shade600,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('hh:mm a').format(
                              DateFormat('yyyy-MM-dd hh:mm:ss a')
                                  .parse(parcel['log_created_at']),
                            ),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      letterSpacing: 0.3,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  parcel['parcel_status'] == 'pending'
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xffF44336),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onPressed: () async {
                            TextEditingController otpController =
                                TextEditingController();
                            remoteDataSource.getParcelOtp(
                              parcel['parcel_id'].toString(),
                              parcel['memb_mobile_number'].toString(),
                            );

                            final result = await showModalBottomSheet<bool>(
                              context: context,
                              isScrollControlled: true,
                              builder: (BuildContext context) {
                                return OtpBottomSheet(
                                  remoteDataSource: remoteDataSource,
                                  parcel: parcel,
                                  otpController: otpController,
                                );
                              },
                            );

                            // If result is true, refresh the parcel list
                            if (result == true) {
                              if (context.mounted) {
                                context.read<ParcelBloc>().add(FetchParcels());
                              }
                            }
                          },
                          child: Text(
                            'Pick',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  letterSpacing: 0.5,
                                ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.green.shade200,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.verified,
                                color: Colors.green.shade600,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _capitalizeFirstLetter(
                                    parcel['parcel_status'] ?? 'N/A'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                      letterSpacing: 0.3,
                                    ),
                              ),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _capitalizeFirstLetter(String text) {
    if (text.isEmpty) return "";
    return text
        .split(' ') // Split into words
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : word)
        .join(' '); // Join words back
  }

  IconData _getPurposeIcon(String? category) {
    switch (category?.toUpperCase()) {
      case "DELIVERY":
        return Symbols.inventory_2;
      case "CAB":
        return Icons.local_taxi;
      case "VISITOR":
        return Icons.person;
      default:
        return Icons.inventory_2_outlined; // Default icon if unknown category
    }
  }

  Widget parsallist(List<dynamic> parcels, final String searchQuery) {
    // If no parcels at all, show the enhanced empty state
    if (parcels.isEmpty) {
      return _buildEnhancedEmptyState(context);
    }

    final query = searchQuery.toLowerCase();
    List<dynamic> filteredParcels = parcels.where((parcel) {
      final memberName = parcel['member_name']?.toString().toLowerCase() ?? '';
      final unitName = parcel['unit_name']?.toString().toLowerCase() ?? '';
      final purposeSubCategory =
          parcel['purpose_sub_category_name']?.toString().toLowerCase() ?? '';

      return memberName.contains(query) ||
          unitName.contains(query) ||
          purposeSubCategory.contains(query);
    }).toList();

    // Filter by selected building if not "All Buildings"
    if (selectedBuilding != null && selectedBuilding != "All Buildings") {
      filteredParcels = filteredParcels.where((parcel) {
        if (parcel['unit_name'] != null &&
            parcel['unit_name'].toString().isNotEmpty) {
          String unitName = parcel['unit_name'].toString();
          if (unitName.contains("-")) {
            String buildingName = unitName.split("-")[0].trim();
            return buildingName == selectedBuilding;
          } else {
            return unitName == selectedBuilding;
          }
        }
        return false;
      }).toList();
    }

    if (filteredParcels.isEmpty) {
      return _buildEnhancedNoResultsState(context, searchQuery);
    }

    // Group parcels by date
    Map<String, List<dynamic>> groupedParcels = {};
    for (var parcel in filteredParcels) {
      String dateKey = parcel['log_created_at'] != null
          ? DateFormat('yyyy-MM-dd').format(
              DateTime.tryParse(parcel['log_created_at']) ?? DateTime.now())
          : 'Unknown Date';

      if (!groupedParcels.containsKey(dateKey)) {
        groupedParcels[dateKey] = [];
      }
      groupedParcels[dateKey]!.add(parcel);
    }

    // Sort dates in ascending order
    List<String> sortedDates = groupedParcels.keys.toList()..sort();

    return ListView(
      padding: const EdgeInsets.only(top: 0, bottom: 300),
      shrinkWrap: true,
      children: sortedDates.expand((date) {
        return [
          Chip(
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
              borderRadius:
                  BorderRadius.circular(25), // Adjust the radius as needed
              side: BorderSide.none, // No border
            ),
            label: Text(
              DateFormat('MMM dd, yyyy').format(DateTime.parse(date)),
              style: Theme.of(context).textTheme.labelSmall,
            ),
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          ),
          Builder(builder: (context) {
            // Sort parcels by building name within each date group
            List<dynamic> sortedParcels = List.from(groupedParcels[date]!);
            sortedParcels.sort((a, b) {
              String buildingA = "";
              String buildingB = "";

              if (a['unit_name'] != null &&
                  a['unit_name'].toString().isNotEmpty) {
                String unitName = a['unit_name'].toString();
                if (unitName.contains("-")) {
                  buildingA = unitName.split("-")[0].trim();
                } else {
                  buildingA = unitName;
                }
              }

              if (b['unit_name'] != null &&
                  b['unit_name'].toString().isNotEmpty) {
                String unitName = b['unit_name'].toString();
                if (unitName.contains("-")) {
                  buildingB = unitName.split("-")[0].trim();
                } else {
                  buildingB = unitName;
                }
              }

              return buildingA.compareTo(buildingB);
            });

            return Column(
                children:
                    sortedParcels.map((parcel) => parsalView(parcel)).toList());
          }),
        ];
      }).toList(),
    );
  }

  Widget _buildEnhancedNoResultsState(
      BuildContext context, String searchQuery) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: isTablet ? 80 : 60),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Enhanced icon container (staff style)
            Container(
              padding: EdgeInsets.all(isTablet ? 32 : 24),
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
                searchQuery.isEmpty
                    ? Symbols.package_2
                    : Icons.search_off_rounded,
                size: isTablet ? 64 : 48,
                color: Colors.red.shade300,
              ),
            ),
            SizedBox(height: isTablet ? 24 : 20),

            // Enhanced title (staff style)
            Text(
              searchQuery.isEmpty ? 'No Parcels Available' : 'No Parcel Found',
              style: TextStyle(
                color: const Color(0xff212427),
                fontSize: isTablet ? 20 : 18,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: isTablet ? 8 : 6),

            // Enhanced subtitle (staff style)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 50 : 32),
              child: Text(
                searchQuery.isEmpty
                    ? 'There are currently no parcels registered in the system.'
                    : 'No parcels match your search criteria. Try adjusting your search terms.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: isTablet ? 14 : 12,
                  height: 1.4,
                ),
              ),
            ),

            // Clear search button for search results (staff style)
            if (searchQuery.isNotEmpty) ...[
              SizedBox(height: isTablet ? 32 : 24),
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
                    setState(() {
                      _searchQuery = '';
                      _searchController.clear();
                    });
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
                    Icons.clear_all,
                    color: Colors.white,
                  ),
                  label: Text(
                    'Clear Search',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: isTablet ? 16 : 14,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedEmptyState(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    final screenHeight = MediaQuery.of(context).size.height;
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final availableHeight = screenHeight - keyboardHeight;

    return Container(
      height: availableHeight,
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 32 : 24,
        vertical: isTablet ? 60 : 40,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          // Enhanced animated icon
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 1500),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, -10 + (10 * value)),
                child: Container(
                  width: isTablet ? 160 : 140,
                  height: isTablet ? 160 : 140,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xffF44336).withOpacity(0.08),
                        const Color(0xffff5722).withOpacity(0.03),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(isTablet ? 80 : 70),
                  ),
                  child: Icon(
                    Symbols.package_2,
                    size: isTablet ? 64 : 56,
                    color: const Color(0xffF44336).withOpacity(0.6),
                  ),
                ),
              );
            },
          ),

          SizedBox(height: isTablet ? 40 : 32),

          // Enhanced title with animation
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            tween: Tween<double>(begin: 0, end: 1),
            builder: (context, value, child) {
              return Opacity(
                opacity: value,
                child: Text(
                  'No Parcels Today',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xff212427),
                        fontSize: isTablet ? 30 : 26,
                        letterSpacing: -0.5,
                      ),
                ),
              );
            },
          ),

          SizedBox(height: isTablet ? 20 : 16),

          // Enhanced description
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isTablet ? 40 : 20),
            child: Text(
              'No parcels found today.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: const Color(0xff57636C),
                    fontSize: isTablet ? 18 : 16,
                    height: 1.6,
                    fontWeight: FontWeight.w400,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper widget for feature items
  Widget _buildFeatureItem(IconData icon, String label, bool isTablet) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 10 : 8),
            decoration: BoxDecoration(
              color: const Color(0xffF44336).withOpacity(0.1),
              borderRadius: BorderRadius.circular(isTablet ? 10 : 8),
            ),
            child: Icon(
              icon,
              color: const Color(0xffF44336),
              size: isTablet ? 24 : 20,
            ),
          ),
          SizedBox(height: isTablet ? 10 : 8),
          Text(
            label,
            style: TextStyle(
              fontSize: isTablet ? 14 : 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedErrorState(BuildContext context, String errorMessage) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Center(
      child: Padding(
        padding: EdgeInsets.only(top: isTablet ? 100 : 80),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Enhanced icon container (staff style)
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
                Icons.error_outline,
                size: isTablet ? 80 : 64,
                color: Colors.red.shade300,
              ),
            ),
            SizedBox(height: isTablet ? 32 : 24),

            // Enhanced title (staff style)
            Text(
              AppLocalizations.of(context).somethingWentWrong,
              style: TextStyle(
                color: const Color(0xff212427),
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
            SizedBox(height: isTablet ? 12 : 8),

            // Enhanced subtitle (staff style)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isTablet ? 60 : 40),
              child: Text(
                AppLocalizations.of(context).errorLoadingParcelList,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: isTablet ? 16 : 14,
                  height: 1.4,
                ),
              ),
            ),
            SizedBox(height: isTablet ? 40 : 32),

            // Enhanced retry button (staff style)
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
                  // Retry loading parcel list
                  context.read<ParcelBloc>().add(FetchParcels());
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
                  AppLocalizations.of(context).tryAgain,
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ParcelBloc(remoteDataSource)..add(FetchParcels()),
      child: MyScrollView(
        isScrollable: false,
        hasBackButton: true,
        backButtonPressed: () {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const GateDashboardView()),
            (Route<dynamic> route) => false,
          );
        },
        pageTitle: AppLocalizations.of(context).parcels,
        pageBody: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: _buildSearchField(),
            ),
            Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height,
              ),
              child: BlocBuilder<ParcelBloc, ParcelState>(
                builder: (context, state) {
                  if (state is ParcelLoading) {
                    return const DashboardLoader(
                      title: 'Loading Parcels',
                      subtitle: 'Please wait while we fetch parcel data...',
                    );
                  } else if (state is ParcelLoaded) {
                    return Stack(
                      children: [
                        parsallist(state.parcels, _searchQuery),
                      ],
                    );
                  } else if (state is ParcelError) {
                    return _buildEnhancedErrorState(context, state.message);
                  } else {
                    return _buildEnhancedEmptyState(context);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
