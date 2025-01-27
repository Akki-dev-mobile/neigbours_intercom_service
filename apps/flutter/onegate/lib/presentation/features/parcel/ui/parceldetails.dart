import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';

import '../../../../dio_setup.dart';

class ParcelDetails extends StatelessWidget {
  final Map<String, dynamic> parcel;

  ParcelDetails({Key? key, required this.parcel}) : super(key: key);
  RemoteDataSource remoteDataSource = RemoteDataSource(
      DioSingleton.instance1, DioSingleton.instance2, DioSingleton.instance3);

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
        pageTitle: 'Parcel Details',
        pageBody: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: CircleAvatar(
                  radius: 60,
                  backgroundColor: Colors.grey[200],
                  foregroundImage: parcel['visitor_image'] != null
                      ? NetworkImage(parcel['visitor_image'])
                      : null,
                  child: parcel['visitor_image'] == null
                      ? const Icon(
                          Icons.person,
                          size: 50,
                          color: Colors.grey,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              Center(
                child: Text(
                  parcel['visitor_name'] ?? 'No Name',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                ),
              ),
              const SizedBox(height: 16),

              // Divider
              const Divider(thickness: 2, color: Colors.grey),

              _buildDetailRow(
                context,
                'Flat No',
                parcel['unit_name']?.toString() ?? 'No Description',
              ),
              _buildDetailRow(
                context,
                'Deliver To',
                parcel['member_name'] ?? 'No Name',
              ),
              _buildDetailRow(
                context,
                'Check-In',
                parcel['visitor_check_in'] ?? 'N/A',
              ),
              _buildDetailRow(
                context,
                'Coming From',
                parcel['purpose_sub_category_name'] ?? 'N/A',
              ),
              _buildDetailRow(
                context,
                'Status',
                parcel['parcel_status'] ?? 'N/A',
              ),

              const SizedBox(height: 16),

              if (parcel['parcel_image'] != null)
                Container(
                  margin: EdgeInsets.symmetric(vertical: 16.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.network(
                      parcel['parcel_image'],
                      fit: BoxFit.cover,
                      height: 200,
                      width: double.infinity,
                    ),
                  ),
                ),

              const SizedBox(height: 50),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: CustomLargeBtn(
          onPressed: () {
            TextEditingController otpController = TextEditingController();
            remoteDataSource.getParcelOtp(
              parcel['parcel_id'].toString(),
              parcel['memb_mobile_number'].toString(),
            );
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: Text('Enter OTP'),
                  content: TextField(
                    controller: otpController,
                    decoration: InputDecoration(
                      hintText: 'Enter OTP',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  actions: <Widget>[
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Cancel',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: () async {
                        String otp = otpController.text;
                        try {
                          final result = await remoteDataSource.verifyParcelOtp(
                            parcel['parcel_id'].toString(),
                            otp,
                          );
                          log("OTP verified: $result");
                        } catch (e) {
                          log("OTP verification failed: $e");
                        }
                        Navigator.of(context).pop();
                      },
                      child: Text(
                        'Submit',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                );
              },
            );
          },
          text: 'Mark as Delivered',
        ));
  }
}

// Detail Row Widget
Widget _buildDetailRow(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12.0),
    child: Row(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
        ),
        const Spacer(),
        Text(
          value,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black87,
              ),
        ),
      ],
    ),
  );
}
