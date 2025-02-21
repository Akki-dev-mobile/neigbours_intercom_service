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
import 'package:url_launcher/url_launcher.dart';
import '../bloc/parcel_state.dart';

class ParcelList extends StatefulWidget {
  const ParcelList({super.key});

  @override
  _ParcelListState createState() => _ParcelListState();
}

class _ParcelListState extends State<ParcelList> {
  RemoteDataSource remoteDataSource = RemoteDataSource();

  TextEditingController searchController = TextEditingController();
  List<dynamic> filteredParcels = [];
  Timer? _refreshTimer; // Add this
  bool _isRefreshing = false; // Add this
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;
  String _searchQuery = '';

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

  Future<void> _refreshPage() async {
    if (!mounted || _isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    try {
      context.read<ParcelBloc>().add(FetchParcels());
    } catch (e) {
      debugPrint("Error refreshing ParcelBloc: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isRefreshing = false;
        });
      }
    }
  }

  Widget _buildSearchField() {
    return CustomForm.textField(
      "Search",
      hintText: "Search Members",
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
    );
  }

  Widget parsalView(Map<String, dynamic> parcel) {
    final checkIn = parcel['visitor_check_in'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.only(
            bottom: 8.0,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
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
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(parcel['visitor_image'] ?? ''),
                  radius: 30,
                ),
                title: Text(
                  parcel['member_name'] ?? 'N/A',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Text.rich(
                  TextSpan(
                    children: [
                      WidgetSpan(
                        alignment: PlaceholderAlignment
                            .middle, // Aligns icon with text
                        child: Icon(
                          _getPurposeIcon(parcel['purpose_sub_category_name']),
                          size: 16, // Same size as text
                          color: Colors.grey[600], // Greyish color
                        ),
                      ),
                      const WidgetSpan(
                          child: SizedBox(
                              width: 6)), // Space between icon and text
                      TextSpan(
                        text:
                            "${parcel['unit_name']?.toString() ?? 'No Description'} - ${parcel['purpose_sub_category_name'] ?? 'N/A'}",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              fontSize:
                                  14, // Ensures text and icon size are the same
                              color: Colors.grey[600], // Greyish color
                            ),
                      ),
                    ],
                  ),
                ),
              ),
              Divider(
                indent: 16,
                endIndent: 16,
                color: Colors.grey[200],
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12.0, right: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Tooltip(
                      message: checkIn != null
                          ? DateFormat('HH:mm').format(
                              DateTime.tryParse(checkIn) ?? DateTime.now(),
                            )
                          : 'N/A',
                      child: RichText(
                        textAlign: TextAlign.start,
                        text: TextSpan(
                          children: [
                            const WidgetSpan(
                              child: Icon(
                                Symbols.directions_walk_rounded,
                                color: Colors.green,
                              ),
                            ),
                            TextSpan(
                              text: DateFormat('hh:mm a').format(
                                DateFormat('yyyy-MM-dd hh:mm:ss a')
                                    .parse(parcel['log_created_at']),
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium!
                                  .merge(
                                    const TextStyle(
                                      color: Colors.green,
                                    ),
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    parcel['parcel_status'] == 'pending'
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
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
                                  context
                                      .read<ParcelBloc>()
                                      .add(FetchParcels());
                                }
                              }
                            },
                            child: Text(
                              'Pick',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium!
                                  .copyWith(
                                    color: Colors.white,
                                  ),
                            ),
                          )
                        : Container(
                            decoration: BoxDecoration(
                                border: Border.all(color: Colors.green),
                                borderRadius: BorderRadius.circular(10)),
                            child: Padding(
                              padding: const EdgeInsets.all(4.0),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.verified,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(parcel['parcel_status'] ?? 'N/A',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium!
                                          .copyWith(color: Colors.green)),
                                ],
                              ),
                            ),
                          ),
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
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
    final query = searchQuery.toLowerCase();
    final filteredParcels = parcels.where((parcel) {
      final memberName = parcel['member_name']?.toString().toLowerCase() ?? '';
      final unitName = parcel['unit_name']?.toString().toLowerCase() ?? '';
      final purposeSubCategory =
          parcel['purpose_sub_category_name']?.toString().toLowerCase() ?? '';

      return memberName.contains(query) ||
          unitName.contains(query) ||
          purposeSubCategory.contains(query);
    }).toList();

    if (filteredParcels.isEmpty) {
      return Column(
        children: [
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.2,
          ),
          const Center(
            child: Icon(
              Symbols.package_2,
              size: 90,
            ),
          ),
          const Center(child: Text('No parcels found.')),
        ],
      );
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
          ...groupedParcels[date]!.map((parcel) => parsalView(parcel)).toList(),
        ];
      }).toList(),
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
          Navigator.push(context,
              MaterialPageRoute(builder: (context) => GateDashboardView()));
        },
        pageTitle: 'Parcels',
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
                    return const Center(
                      child: CircularProgressIndicator(
                        color: Colors.black,
                      ),
                    );
                  } else if (state is ParcelLoaded) {
                    return Stack(
                      children: [
                        parsallist(state.parcels, _searchQuery),
                      ],
                    );
                  } else if (state is ParcelError) {
                    return Center(child: Text('Error: ${state.message}'));
                  } else {
                    return Column(
                      children: [
                        Icon(Symbols.package_2),
                        Center(child: Text('No parcels found.')),
                      ],
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _launchCaller(String number) async {
    final url = 'tel:$number';
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      throw 'Could not launch $url';
    }
  }
}
