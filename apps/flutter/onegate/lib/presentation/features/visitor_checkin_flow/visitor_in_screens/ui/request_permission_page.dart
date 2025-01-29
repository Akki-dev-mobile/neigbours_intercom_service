import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/request_permission/ui/request_permission_view.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';

class RequestPermissionPage extends StatefulWidget {
  final Visitor visitor;

  const RequestPermissionPage({
    super.key,
    required this.visitor,
  });

  @override
  State<RequestPermissionPage> createState() => _RequestPermissionView1State();
}

class _RequestPermissionView1State extends State<RequestPermissionPage> {
  @override
  Widget build(BuildContext context) {
    Color colortoshow = Color(0xffFFB080);
    RequestType requestType = RequestType.leaveAtGate;

    Size screensize = MediaQuery.of(context).size;
    return MyScrollView(
      pageTitleWidget: Container(
          width: screensize.width * 0.15,
          decoration: BoxDecoration(
            color: colortoshow.withOpacity(0.2),
            borderRadius: BorderRadius.circular(5),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: InkWell(
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => GateDashboardView()));
                },
                child: Icon(
                  Icons.home_outlined,
                  color: colortoshow,
                )),
          )),
      hasBackButton: EditableText.debugDeterministicCursor,
      floatingActionButton: _getbutton(requestType),
      pageBody: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(25),
              child: Image.network(
                  width: screensize.width * 0.5,
                  height: screensize.height * 0.2,
                  fit: BoxFit.fill,
                  "https://t4.ftcdn.net/jpg/03/64/21/11/360_F_364211147_1qgLVxv1Tcq0Ohz3FawUfrtONzz8nq3e.jpg"),
            ),
          ),
          SizedBox(height: 20),
          Text(
            widget.visitor.name ?? "",
            style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          Container(
            decoration: BoxDecoration(
              color: colortoshow.withOpacity(0.4),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text("GUEST"),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.all(16),
                  leading: Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(Ionicons.call_outline, color: Colors.green),
                  ),
                  title: Text(
                    'Phone Number',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),

                    //  TextStyle(
                    //   color: Colors.grey[600],
                    //   fontSize: 14,
                    // ),
                  ),
                  subtitle: Text(
                    widget.visitor.mobile ?? "",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    softWrap: true,
                    overflow: TextOverflow.visible,
                  ),

                  // trailing: ElevatedButton.icon(
                  //   icon: Icon(Icons.call, size: 18, color:Colors.black),
                  //   label: Text('Call',style: Theme.of(context).textTheme.bodySmall),
                  //   onPressed: () => {},
                  //   // _makePhoneCall(widget.visitorLog.visitor!.mobile ?? ""),
                  //   style: ElevatedButton.styleFrom(
                  //     backgroundColor: colortoshow,
                  //     foregroundColor: Colors.white,
                  //     padding:
                  //         EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  //     shape: RoundedRectangleBorder(
                  //       borderRadius: BorderRadius.circular(8),
                  //     ),
                  //   ),
                  // ),
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 18.0, bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: colortoshow.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Symbols.apartment,
                          color: colortoshow,
                        ),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Visiting Unit',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.6,
                            ),
                            child: Text(
                              "Society Office",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                              softWrap: true,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: GestureDetector(
              child: Container(
                margin: EdgeInsets.only(top: 10, bottom: 20),
                width: double.infinity,
                child: _getLottieAnimation(requestType),
              ),
              onTap: () {},
            ),
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
    );
  }

  Widget _getLottieAnimation(RequestType requestType) {
    switch (requestType) {
      case RequestType.notRecheable:
        return Lottie.network(
          'https://fstech-cms-db.s3.ap-south-1.amazonaws.com/Animation_1738144371860_6ed19f54ff.json',
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
          'Not Recheable',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color:
                    Theme.of(context).colorScheme.onBackground.withOpacity(0.5),
              ),
        );
      case RequestType.approved:
        return Text(
          'Approved',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        );
      case RequestType.leaveAtGate:
        return Text(
          'Leave At Gate',
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
          'Rejected',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium,
        );
      case RequestType.waiting:
        return Text(
          'Initializing Request',
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

  Widget _getbutton(RequestType requestType) {
    switch (requestType) {
      case RequestType.notRecheable:
        return Container(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CustomLargeBtn(
                  width: MediaQuery.of(context).size.width * 0.4,
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => RequestPermissionView(
                                  visitor: Visitor(),
                                  purposeCategory: PurposeCategory1(
                                      categoryId: 123,
                                      categoryName: "categoryName"),
                                )));
                  },
                  text: "allow by gatekeeper".toUpperCase()),
              CustomLargeBtn(
                  width: MediaQuery.of(context).size.width * 0.4,
                  onPressed: () {
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => RequestPermissionView(
                                  visitor: Visitor(),
                                  purposeCategory: PurposeCategory1(
                                      categoryId: 123,
                                      categoryName: "categoryName"),
                                )));
                  },
                  text: "Homepage".toUpperCase()),
            ],
          ),
        );
      case RequestType.approved:
        return CustomLargeBtn(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => RequestPermissionView(
                            visitor: Visitor(),
                            purposeCategory: PurposeCategory1(
                                categoryId: 123, categoryName: "categoryName"),
                          )));
            },
            text: "Finish".toUpperCase());
      case RequestType.leaveAtGate:
        return CustomLargeBtn(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => RequestPermissionView(
                            visitor: Visitor(),
                            purposeCategory: PurposeCategory1(
                                categoryId: 123, categoryName: "categoryName"),
                          )));
            },
            text: "Capture Photo".toUpperCase());
      case RequestType.request:
        return CustomLargeBtn(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => RequestPermissionView(
                            visitor: Visitor(),
                            purposeCategory: PurposeCategory1(
                                categoryId: 123, categoryName: "categoryName"),
                          )));
            },
            text: "Request permission".toUpperCase());
      case RequestType.rejected:
        return CustomLargeBtn(
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => RequestPermissionView(
                            visitor: Visitor(),
                            purposeCategory: PurposeCategory1(
                                categoryId: 123, categoryName: "categoryName"),
                          )));
            },
            text: "go to homespage".toUpperCase());
      case RequestType.waiting:
        return Container();
      default:
        {
          return CustomLargeBtn(
              onPressed: () {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => RequestPermissionView(
                              visitor: Visitor(),
                              purposeCategory: PurposeCategory1(
                                  categoryId: 123,
                                  categoryName: "categoryName"),
                            )));
              },
              text: "go to homespage".toUpperCase());
        }
    }
  }
}
