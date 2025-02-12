import 'dart:async';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/parcel/bloc/parcel_bloc.dart';
import 'package:flutter_onegate/presentation/features/parcel/ui/parceldetails.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../dio_setup.dart';
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
  }

  void _startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && !_isRefreshing) {
        _refreshPage();
      }
    });
  }

  @override
  void dispose() {
    searchController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _refreshPage() async {
    if (!mounted || _isRefreshing)
      return; // Prevent calling refresh if unmounted

    setState(() {
      _isRefreshing = true;
    });

    try {
      if (mounted) {
        context.read<ParcelBloc>().add(FetchParcels());
      }
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

  void _filterParcels(String query, List<dynamic> parcels) {
    setState(() {
      filteredParcels = parcels
          .where((parcel) =>
              (parcel['member_name']?.toString() ?? '')
                  .toLowerCase()
                  .contains(query.toLowerCase()) ||
              (parcel['unit_name']?.toString() ?? '')
                  .toLowerCase()
                  .contains(query.toLowerCase()))
          .toList();
    });
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
    final contactNumber = parcel['visitor_mobile'] ?? 'N/A';
    final checkIn = parcel['visitor_check_in'];

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 2,
        // margin: const EdgeInsets.all(8.0),
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
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ParcelDetails(parcel: parcel),
                    ),
                  );
                },
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(parcel['visitor_image'] ?? ''),
                  radius: 30,
                ),
                trailing: IconButton(
                  onPressed: () {
                    if (contactNumber != 'N/A' && contactNumber.isNotEmpty) {
                      _launchCaller(contactNumber);
                    } else {
                      Fluttertoast.showToast(
                        msg: 'No contact number available',
                        toastLength: Toast.LENGTH_SHORT,
                        gravity: ToastGravity.BOTTOM,
                        backgroundColor: Colors.red,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                    }
                  },
                  icon: const Icon(
                    Ionicons.call_outline,
                    color: Colors.green,
                  ),
                ),
                title: Text(
                  parcel['member_name'] ?? 'N/A',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Symbols.apartment,
                            color: Color(0xffFFB080),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffFFEBE6),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              parcel['unit_name']?.toString() ??
                                  'No Description',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                    // fontSize: 14,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 10,
                      ),
                      Row(
                        children: [
                          const Icon(
                            Symbols.delivery_truck_speed,
                            color: Color(0xffF2D8A5),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xffF2D8A5),
                              borderRadius: BorderRadius.circular(15),
                            ),
                            child: Text(
                              parcel['purpose_sub_category_name'] ?? 'N/A',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall!
                                  .copyWith(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w500,
                                    // fontSize: 14,
                                  ),
                            ),
                          ),
                        ],
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
                          ? DateFormat('dd MMM HH:mm').format(
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
                              text: parcel['log_created_at'] != null
                                  ? DateFormat('dd MMM HH:mm').format(
                                      DateTime.tryParse(
                                              parcel['log_created_at']) ??
                                          DateTime.now(),
                                    )
                                  : 'N/A',
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
                            onPressed: () {
                              TextEditingController otpController =
                                  TextEditingController();
                              remoteDataSource.getParcelOtp(
                                parcel['parcel_id'].toString(),
                                parcel['memb_mobile_number'].toString(),
                              );
                              showModalBottomSheet(
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
                            },
                            child: const Text(
                              'Pick',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          )
                        // : ElevatedButton(
                        //     style: ElevatedButton.styleFrom(
                        //       backgroundColor: Colors.white,
                        //       shape: RoundedRectangleBorder(
                        //         borderRadius: BorderRadius.circular(8),
                        //       ),
                        //     ),
                        //     onPressed: () {},
                        //     child: Text(
                        //       parcel['parcel_status'] ?? 'N/A',
                        //       style: const TextStyle(
                        //         fontSize: 18,
                        //         color: Colors.black,
                        //         fontWeight: FontWeight.bold,
                        //       ),
                        //     ),
                        //   )
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

    return filteredParcels.isNotEmpty
        ? ListView.builder(
            padding: const EdgeInsets.only(top: 10, bottom: 300),
            shrinkWrap: true,
            itemCount: filteredParcels.length,
            itemBuilder: (context, index) {
              final parcel = filteredParcels[index] as Map<String, dynamic>;

              return parsalView(parcel);
            },
          )
        : Column(
            // mainAxisAlignment: MainAxisAlignment.center,
            // mainAxisSize: MainAxisSize.min,
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

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ParcelBloc(remoteDataSource)..add(FetchParcels()),
      child: MyScrollView(
        actions: [
          if (_isRefreshing)
            const Padding(
              padding: EdgeInsets.all(50.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _refreshPage,
              tooltip: 'Refresh',
            ),
        ],
        isScrollable: false,
        hasBackButton: true,
        pageTitle: 'Parcels',
        pageBody: RefreshIndicator(
          onRefresh: _refreshPage,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: _buildSearchField(),
              ),

              // CustomForm.textField(
              //   "Search Members",
              //   titleColor: Colors.black,
              //   hintColor: Colors.grey,
              //   hintText: "Search Member/Units",
              //   textController: searchController,
              //   onChanged: (value) {
              //     if (value.isEmpty) {
              //       setState(() {
              //         filteredParcels.clear();
              //       });
              //     } else {
              //       final state = context.read<ParcelBloc>().state;
              //       if (state is ParcelLoaded) {
              //         _filterParcels(value, state.parcels);
              //       }
              //     }
              //   },
              // ),

              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height,
                ),
                child: BlocBuilder<ParcelBloc, ParcelState>(
                  builder: (context, state) {
                    if (state is ParcelLoading) {
                      return const Center(
                        child: CircularProgressIndicator(
                          color: Colors.red,
                        ),
                      );
                    } else if (state is ParcelLoaded) {
                      final parcels = searchController.text.isEmpty
                          ? state.parcels
                          : filteredParcels;

                      if (parcels.isEmpty) {
                        return const Center(
                          child: Text('No such member parcel found.'),
                        );
                      }

                      return parsallist(parcels, _searchQuery);
                    } else if (state is ParcelError) {
                      return Center(child: Text('Error: ${state.message}'));
                    } else {
                      return const Column(
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
