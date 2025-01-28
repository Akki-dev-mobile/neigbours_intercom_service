import 'dart:developer';

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
import 'package:pinput/pinput.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../dio_setup.dart';
import '../bloc/parcel_state.dart';

class ParcelList extends StatelessWidget {
  ParcelList({super.key});

  RemoteDataSource remoteDataSource = RemoteDataSource(
    DioSingleton.instance1,
    DioSingleton.instance2,
    DioSingleton.instance3,
  );

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ParcelBloc(
        RemoteDataSource(
          DioSingleton.instance1,
          DioSingleton.instance2,
          DioSingleton.instance3,
        ),
      )..add(FetchParcels()),
      child: MyScrollView(
        isScrollable: true,
        hasBackButton: true,
        pageTitle: 'Parcels',
        pageBody: BlocBuilder<ParcelBloc, ParcelState>(
          builder: (context, state) {
            if (state is ParcelLoading) {
              return const Center(
                child: CircularProgressIndicator(
                  color: Colors.red,
                ),
              );
            } else if (state is ParcelLoaded) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: CustomForm.textField(
                      "Search Members",
                      titleColor: Colors.black,
                      hintColor: Colors.grey,
                      hintText: "Search Member/Units",
                    ),
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height,
                    child: Expanded(
                      child: ListView.builder(
                        itemCount: state.parcels.length,
                        itemBuilder: (context, index) {
                          final parcel =
                              state.parcels[index] as Map<String, dynamic>;
                          final contactNumber =
                              parcel['visitor_mobile'] ?? 'N/A';
                          final checkIn = parcel['visitor_check_in'];

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              elevation: 2,
                              margin: const EdgeInsets.all(8.0),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
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
                                      parcel['visitor_name'] ?? 'N/A',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium,
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
                                                margin: const EdgeInsets.only(
                                                    left: 8),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xffFFEBE6),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                child: Text(
                                                  parcel['unit_name']
                                                          ?.toString() ??
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
                                                margin:
                                                    EdgeInsets.only(left: 8),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 7,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xffFFEBE6),
                                                  borderRadius:
                                                      BorderRadius.circular(15),
                                                ),
                                                child: Text(
                                                  parcel['purpose_sub_category_name']
                                                          ?.toString() ??
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
                                        MainAxisAlignment.spaceEvenly,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      Tooltip(
                                        message: checkIn != null
                                            ? DateFormat('dd-MM-yyyy hh:mm a')
                                                .format(
                                                DateTime.tryParse(checkIn) ??
                                                    DateTime.now(),
                                              )
                                            : 'N/A',
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              const WidgetSpan(
                                                child: Icon(
                                                  Symbols
                                                      .directions_walk_rounded,
                                                  color: Colors.green,
                                                ),
                                              ),
                                              TextSpan(
                                                text: parcel[
                                                        'visitor_check_in'] ??
                                                    'N/A',
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
                                                  parcel['parcel_id']
                                                      .toString(),
                                                  parcel['memb_mobile_number']
                                                      .toString(),
                                                );
                                                showModalBottomSheet(
                                                  context: context,
                                                  isScrollControlled: true,
                                                  builder:
                                                      (BuildContext context) {
                                                    return Padding(
                                                      padding: EdgeInsets.only(
                                                        bottom: MediaQuery.of(
                                                                context)
                                                            .viewInsets
                                                            .bottom,
                                                      ),
                                                      child: Container(
                                                        padding: EdgeInsets.all(
                                                            16.0),
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Text(
                                                              'Enter OTP',
                                                              style: Theme.of(
                                                                      context)
                                                                  .textTheme
                                                                  .headlineMedium,
                                                            ),
                                                            SizedBox(
                                                                height: 16),
                                                            Container(
                                                              height: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .height *
                                                                  0.07,
                                                              width: MediaQuery.of(
                                                                          context)
                                                                      .size
                                                                      .width *
                                                                  0.8,
                                                              child: Pinput(
                                                                length: 6,
                                                                onCompleted:
                                                                    (String
                                                                        pin) {
                                                                  print(
                                                                      "Completed: $pin");
                                                                },
                                                                focusNode:
                                                                    FocusNode(),
                                                                controller:
                                                                    otpController,
                                                                submittedPinTheme:
                                                                    PinTheme(
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    border: Border.all(
                                                                        color: Colors
                                                                            .green),
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(5),
                                                                  ),
                                                                ),
                                                                focusedPinTheme:
                                                                    PinTheme(
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    border: Border.all(
                                                                        color: Colors
                                                                            .blue),
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(5),
                                                                  ),
                                                                ),
                                                                followingPinTheme:
                                                                    PinTheme(
                                                                  decoration:
                                                                      BoxDecoration(
                                                                    border: Border.all(
                                                                        color: Colors
                                                                            .grey),
                                                                    borderRadius:
                                                                        BorderRadius
                                                                            .circular(5),
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            SizedBox(
                                                                height: 16),
                                                            Row(
                                                              mainAxisAlignment:
                                                                  MainAxisAlignment
                                                                      .end,
                                                              children: [
                                                                TextButton(
                                                                  onPressed:
                                                                      () {
                                                                    remoteDataSource
                                                                        .getParcelOtp(
                                                                      parcel['parcel_id']
                                                                          .toString(),
                                                                      parcel['memb_mobile_number']
                                                                          .toString(),
                                                                    );
                                                                  },
                                                                  child: Text(
                                                                    'Resend',
                                                                    style: Theme.of(
                                                                            context)
                                                                        .textTheme
                                                                        .bodyMedium,
                                                                  ),
                                                                ),
                                                                Container(
                                                                  width: MediaQuery.of(
                                                                              context)
                                                                          .size
                                                                          .width *
                                                                      0.35,
                                                                  child:
                                                                      ElevatedButton
                                                                          .icon(
                                                                    style: ElevatedButton
                                                                        .styleFrom(
                                                                      backgroundColor:
                                                                          Colors
                                                                              .grey[200],
                                                                      shape:
                                                                          RoundedRectangleBorder(
                                                                        borderRadius:
                                                                            BorderRadius.circular(8),
                                                                      ),
                                                                    ),
                                                                    onPressed:
                                                                        () async {
                                                                      String
                                                                          otp =
                                                                          otpController
                                                                              .text;
                                                                      try {
                                                                        final result =
                                                                            await remoteDataSource.verifyParcelOtp(
                                                                          parcel['parcel_id']
                                                                              .toString(),
                                                                          otp,
                                                                        );
                                                                        Fluttertoast
                                                                            .showToast(
                                                                          toastLength:
                                                                              Toast.LENGTH_SHORT,
                                                                          gravity:
                                                                              ToastGravity.BOTTOM,
                                                                          backgroundColor:
                                                                              Colors.green,
                                                                          textColor:
                                                                              Colors.white,
                                                                          fontSize:
                                                                              16.0,
                                                                          msg: result[
                                                                              'message'],
                                                                        );
                                                                        log("OTP verified: $result");
                                                                      } catch (e) {
                                                                        log("OTP verification failed: $e");
                                                                        Fluttertoast
                                                                            .showToast(
                                                                          msg:
                                                                              'Invalid OTP',
                                                                          toastLength:
                                                                              Toast.LENGTH_SHORT,
                                                                          gravity:
                                                                              ToastGravity.BOTTOM,
                                                                          backgroundColor:
                                                                              Colors.red,
                                                                          textColor:
                                                                              Colors.white,
                                                                          fontSize:
                                                                              16.0,
                                                                        );
                                                                      }
                                                                      Navigator.of(
                                                                              context)
                                                                          .pop();
                                                                    },
                                                                    label: Text(
                                                                      'Submit',
                                                                      style: Theme.of(
                                                                              context)
                                                                          .textTheme
                                                                          .bodySmall,
                                                                    ),
                                                                    icon: Icon(
                                                                      Icons
                                                                          .check,
                                                                      color: Colors
                                                                          .black,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                            SizedBox(
                                                              height: 20,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
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
                                                  color: Colors.blue,
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
                      ),
                    ),
                  ),
                ],
              );
            } else if (state is ParcelError) {
              return Center(child: Text('Error: ${state.message}'));
            } else {
              return const Center(child: Text('No parcels found.'));
            }
          },
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
