// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:chips_choice/chips_choice.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';

class RequestPermissionView extends StatefulWidget {
  const RequestPermissionView({super.key});

  @override
  State<RequestPermissionView> createState() => _RequestPermissionViewState();
}

enum RequestType {
  rejected,
  leaveAtGate,
  approved,
  notRecheable,
  waiting,
  request
}

class _RequestPermissionViewState extends State<RequestPermissionView> {
  RequestType requestType = RequestType.notRecheable;
  List<String> gridData = [
    'A-101',
    'A-102',
    'A-103',
    'A-104',
    'A-105',
    'A-106',
  ];

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitle: 'Permission',
      pageBody: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 45,
                backgroundImage: NetworkImage(
                  'https://images.unsplash.com/photo-1687161590608-6d948d357bad?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=653&q=80',
                ),
              ),
              SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '+9199*****101',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  Text(
                    'Shubham Bane',
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                  SizedBox(height: 2),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: RichText(
                      text: TextSpan(
                        style: Theme.of(context).textTheme.labelMedium,
                        children: <TextSpan>[
                          TextSpan(
                            text: 'Guest ',
                            style: TextStyle(
                              color: Colors.blue[400],
                            ),
                          ),
                          TextSpan(
                            text: '| Last In: 2 days ago',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),
          Divider(
            height: 15,
            indent: 20,
            endIndent: 20,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Flat Numbers',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          GestureDetector(
            onTap: () {
              // Navigator.push(
              //   context,
              //   MaterialPageRoute(
              //     builder: (context) => MultiRequestPermissionView(),
              //   ),
              // );
            },
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 15,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: Theme.of(context).colorScheme.surfaceVariant,
                border: Border.all(
                  color: Colors.red.withOpacity(
                    0.5,
                  ),
                  width: 1,
                ),
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'A-101',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),
          ),
          Container(
            margin: EdgeInsets.only(top: 40, bottom: 30),
            width: double.infinity,
            child: _getLottieAnimation(requestType),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: _getIconLabel(requestType),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: CustomLargeBtn(
        onPressed: () {
          switch (requestType) {
            case RequestType.notRecheable:
              setState(() {
                requestType = RequestType.approved;
              });
              return;
            case RequestType.approved:
              setState(() {
                requestType = RequestType.leaveAtGate;
              });
              return;
            case RequestType.leaveAtGate:
              setState(() {
                requestType = RequestType.rejected;
              });
              return;
            case RequestType.request:
              setState(() {
                requestType = RequestType.notRecheable;
              });

              return;
            case RequestType.rejected:
              setState(() {
                requestType = RequestType.request;
              });
              return;
            default:
              setState(() {
                requestType = RequestType.notRecheable;
              });
              return;
          }
        },
        text: 'REQUEST PERMISSION',
      ),
    );
  }

  Widget _getLottieAnimation(RequestType requestType) {
    switch (requestType) {
      case RequestType.notRecheable:
        return Lottie.network(
          'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/not_reachable_6f7a889bde.json?updated_at=2023-08-23T06:28:51.658Z',
          height: 200,
        );
      case RequestType.approved:
        return Lottie.network(
          'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/accepted_ef4c4982b2.json?updated_at=2023-08-23T06:28:49.810Z',
          height: 200,
        );
      case RequestType.leaveAtGate:
        return Lottie.network(
          'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/leave_at_gate_048fedfdb6.json?updated_at=2023-08-23T06:28:51.200Z',
          height: 200,
        );
      case RequestType.request:
        return Lottie.network(
          'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/request_permission_b6ef131475.json?updated_at=2023-08-23T06:28:52.175Z',
          height: 200,
        );
      case RequestType.rejected:
        return Lottie.network(
          'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/rejected_4bcdedc751.json?updated_at=2023-08-23T06:28:51.894Z',
          height: 200,
        );
      case RequestType.waiting:
        return Lottie.network(
          'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/waiting_for_approval_07eb42d1d5.json?updated_at=2023-08-23T06:28:52.591Z',
          height: 200,
        );
      default:
        {
          return Lottie.network(
            'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/walk_e471a69550.json?updated_at=2023-08-23T06:28:52.519Z',
            height: 200,
          );
        }
    }
  }

  Widget _getIconLabel(RequestType requestType) {
    switch (requestType) {
      case RequestType.notRecheable:
        return Text(
          'Request permission from member',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        );
      case RequestType.approved:
        return Text(
          'Request permission from member',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        );
      case RequestType.leaveAtGate:
        return Text(
          'Request permission from member',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        );
      case RequestType.request:
        return Text(
          'Request permission from member',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        );
      case RequestType.rejected:
        return Text(
          'Request permission from member',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        );
      case RequestType.waiting:
        return Text(
          'Request permission from member',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        );
      default:
        {
          return Text(
            'Request permission from member',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          );
        }
    }
  }
}
