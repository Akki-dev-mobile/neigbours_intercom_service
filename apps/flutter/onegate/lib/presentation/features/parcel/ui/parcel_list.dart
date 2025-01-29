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
  ParcelList({super.key});

  @override
  _ParcelListState createState() => _ParcelListState();
}

class _ParcelListState extends State<ParcelList> {
  RemoteDataSource remoteDataSource = RemoteDataSource(
    DioSingleton.instance1,
    DioSingleton.instance2,
    DioSingleton.instance3,
  );

  TextEditingController searchController = TextEditingController();
  List<dynamic> filteredParcels = [];

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

  void _refreshPage() {
    context.read<ParcelBloc>().add(FetchParcels());
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ParcelBloc(remoteDataSource)..add(FetchParcels()),
      child: MyScrollView(
        isScrollable: true,
        hasBackButton: true,
        pageTitle: 'Parcels',
        pageBody: Column(
          children: [
            CustomForm.textField(
              "Search Members",
              titleColor: Colors.black,
              hintColor: Colors.grey,
              hintText: "Search Member/Units",
              textController: searchController,
              onChanged: (value) {
                if (value.isEmpty) {
                  setState(() {
                    filteredParcels.clear();
                  });
                } else {
                  final state = context.read<ParcelBloc>().state;
                  if (state is ParcelLoaded) {
                    _filterParcels(value, state.parcels);
                  }
                }
              },
            ),
            BlocBuilder<ParcelBloc, ParcelState>(
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

                  return ListView.builder(
                    padding: EdgeInsets.only(top: 10),
                    shrinkWrap: true,
                    itemCount: parcels.length,
                    itemBuilder: (context, index) {
                      final parcel = parcels[index] as Map<String, dynamic>;
                      final contactNumber = parcel['visitor_mobile'] ?? 'N/A';
                      final checkIn = parcel['visitor_check_in'];

                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Card(
                          elevation: 2,
                          margin: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                                      builder: (context) =>
                                          ParcelDetails(parcel: parcel),
                                    ),
                                  );
                                },
                                leading: CircleAvatar(
                                  backgroundImage: NetworkImage(
                                      parcel['visitor_image'] ?? ''),
                                  radius: 30,
                                ),
                                trailing: IconButton(
                                  onPressed: () {
                                    if (contactNumber != 'N/A' &&
                                        contactNumber.isNotEmpty) {
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
                                  icon: Icon(
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
                                  child: RichText(
                                    text: TextSpan(
                                      children: [
                                        const WidgetSpan(
                                          child: Icon(
                                            Symbols.apartment,
                                            color: Color(0xffFFB080),
                                          ),
                                        ),
                                        WidgetSpan(
                                          child: Container(
                                            margin:
                                                const EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xffFFEBE6),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              parcel['unit_name']?.toString() ??
                                                  'No Description',
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const WidgetSpan(
                                          child: Icon(
                                            Symbols.delivery_truck_speed,
                                            color: Color(0xffFFB080),
                                          ),
                                        ),
                                        const WidgetSpan(
                                          child: SizedBox(
                                            height: 10,
                                          ),
                                        ),
                                        WidgetSpan(
                                          child: Container(
                                            margin: EdgeInsets.only(left: 8),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xffFFEBE6),
                                              borderRadius:
                                                  BorderRadius.circular(15),
                                            ),
                                            child: Text(
                                              parcel['purpose_sub_category_name'] ??
                                                  'N/A',
                                              style: const TextStyle(
                                                color: Colors.black,
                                                fontWeight: FontWeight.w500,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        )
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Divider(
                                indent: 16,
                                endIndent: 16,
                                color: Colors.grey[200],
                              ),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Tooltip(
                                    message: checkIn != null
                                        ? DateFormat('dd MMM HH:mm').format(
                                            DateTime.tryParse(checkIn) ??
                                                DateTime.now(),
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
                                            text:
                                                parcel['log_created_at'] != null
                                                    ? DateFormat('dd MMM HH:mm')
                                                        .format(
                                                        DateTime.tryParse(parcel[
                                                                'log_created_at']) ??
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
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: () {
                                            TextEditingController
                                                otpController =
                                                TextEditingController();
                                            remoteDataSource.getParcelOtp(
                                              parcel['parcel_id'].toString(),
                                              parcel['memb_mobile_number']
                                                  .toString(),
                                            );
                                            showModalBottomSheet(
                                              context: context,
                                              isScrollControlled: true,
                                              builder: (BuildContext context) {
                                                return OtpBottomSheet(
                                                  remoteDataSource:
                                                      remoteDataSource,
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
                                      : Row(
                                          children: [
                                            Icon(
                                              Icons.verified,
                                              color: Colors.green,
                                            ),
                                            SizedBox(width: 4),
                                            Text(
                                                parcel['parcel_status'] ??
                                                    'N/A',
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyLarge),
                                          ],
                                        ),
                                ],
                              )
                            ],
                          ),
                        ),
                      );
                    },
                  );
                } else if (state is ParcelError) {
                  return Center(child: Text('Error: ${state.message}'));
                } else {
                  return const Center(child: Text('No parcels found.'));
                }
              },
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
