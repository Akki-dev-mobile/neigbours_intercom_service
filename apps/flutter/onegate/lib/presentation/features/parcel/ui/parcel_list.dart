import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/parcel/bloc/parcel_bloc.dart';
import 'package:flutter_onegate/presentation/features/parcel/ui/parceldetails.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../dio_setup.dart';
import '../bloc/parcel_state.dart';

class ParcelList extends StatelessWidget {
  const ParcelList({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
        create: (context) => ParcelBloc(RemoteDataSource(DioSingleton.instance1,
            DioSingleton.instance2, DioSingleton.instance3))
          ..add(FetchParcels()),
        child: MyScrollView(
          isScrollable: true,
          hasBackButton: true,
          pageTitle: 'Parcels',
          pageBody: BlocBuilder<ParcelBloc, ParcelState>(
            builder: (context, state) {
              if (state is ParcelLoading) {
                return Center(
                    child: CircularProgressIndicator(
                  color: Colors.red,
                ));
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
                                parcel['memb_mobile_number'] ?? 'N/A';
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        ParcelDetails(parcel: parcel),
                                  ),
                                );
                              },
                              child: Card(
                                margin: const EdgeInsets.all(8.0),
                                child: Column(
                                  children: [
                                    ListTile(
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
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                    'No contact number available'),
                                              ),
                                            );
                                          }
                                        },
                                        icon: Icon(
                                          Icons.phone,
                                          color: Colors.green,
                                        ),
                                      ),
                                      title: Text(
                                        "Name: ${parcel['visitor_name']}",
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium,
                                      ),
                                      subtitle: Text(
                                          parcel['unit_id']?.toString() ??
                                              'No Description'),
                                    ),
                                    Divider(
                                      color: Colors.grey[200],
                                    ),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        Text(
                                          parcel['visitor_check_in'] ?? 'N/A',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(color: Colors.green),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: const Color(0xffFFEBE6),
                                            borderRadius:
                                                BorderRadius.circular(15),
                                          ),
                                          child: Text(
                                            parcel['purpose_sub_category_name'] ??
                                                'N/A',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                        ),
                                        parcel['parcel_status'] == 'pending'
                                            ? Container(
                                                child: TextButton.icon(
                                                  onPressed: () {},
                                                  label: Text(
                                                    'Pick',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .bodySmall,
                                                  ),
                                                  icon: Icon(Symbols.logout,
                                                      color: Colors.green),
                                                ),
                                              )
                                            : Text(parcel['parcel_status'] ??
                                                'N/A'),
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
        ));
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
