import 'dart:async';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/parcel/bloc/parcel_bloc.dart';
import 'package:flutter_onegate/presentation/features/parcel/ui/parcel_details.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';
import '../bloc/parcel_state.dart';
import 'package:common_widgets/dashboard_loader.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';

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
    final isTablet = MediaQuery.of(context).size.width > 600;
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
        focusNode: _searchFocusNode,
        onChanged: (value) {
          setState(() {
            _searchQuery = value;
          });
        },
        cursorColor: const Color(0xffF44336),
        decoration: InputDecoration(
          hintText: context.tr('parcelSearchHint'),
          hintStyle: TextStyle(
            color: Colors.grey.shade500,
            fontSize: isTablet ? 16 : 14,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            color: Colors.red.shade400,
            size: isTablet ? 22 : 20,
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(
                    Icons.clear_rounded,
                    color: Colors.grey.shade600,
                  ),
                  onPressed: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
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

  Widget parsalView(Map<String, dynamic> parcel) {
    final checkIn = parcel['visitor_check_in'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        elevation: 5,
        shadowColor: Colors.black.withOpacity(0.24),
        surfaceTintColor: Colors.white,
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
                parcel['visitor_name'] ?? context.tr('Parcel Delivery'),
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
                        : context.tr('No check-in time'),
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
                            context.tr('Pick'),
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
                                (parcel['parcel_status']
                                            ?.toString()
                                            .toLowerCase() ==
                                        'picked')
                                    ? context.tr('Picked')
                                    : _capitalizeFirstLetter(
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
    final normalized = text.trim().toLowerCase();
    if (normalized == 'one app' || normalized == 'oneapp') {
      return 'one app';
    }
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
                          Icons.search_off_rounded,
                          color: const Color(0xffF44336),
                          size: isTablet ? 42 : 34,
                        ),
                      ),
                      SizedBox(height: isTablet ? 28 : 22),
                      Text(
                        context.tr('No Parcel Found'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 24 : 21,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff212427),
                        ),
                      ),
                      SizedBox(height: isTablet ? 14 : 10),
                      Text(
                        searchQuery.trim().isNotEmpty
                            ? context.tr(
                                'parcelNoResultsWithQuery',
                                params: {'query': searchQuery},
                              )
                            : context.tr(
                                'No parcels match the selected filters.',
                              ),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                      if (searchQuery.trim().isNotEmpty) ...[
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
                              context.tr('Clear Search'),
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
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEnhancedEmptyState(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
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
                          Symbols.package_2,
                          color: const Color(0xffF44336),
                          size: isTablet ? 42 : 34,
                        ),
                      ),
                      SizedBox(height: isTablet ? 28 : 22),
                      Text(
                        context.tr('No Parcels Today'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 24 : 21,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff212427),
                        ),
                      ),
                      SizedBox(height: isTablet ? 14 : 10),
                      Text(
                        context.tr('parcelNoItemsToday'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: Colors.grey[600],
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
                    return DashboardLoader(
                      title: context.tr('Loading Parcels'),
                      subtitle: context.tr('parcelLoaderFetchDataSubtitle'),
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
