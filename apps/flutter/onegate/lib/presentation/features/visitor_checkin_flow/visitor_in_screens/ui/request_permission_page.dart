import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/parcel/ui/widgets/info_list_tile_widget.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/request_permission/ui/request_permission_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/units_selection/ui/unit_selection_view.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shimmer/shimmer.dart';

class RequestPermissionPage extends StatefulWidget {
  final Visitor visitor;
  final Future<void> Function() handleMemberSelectionfun;
  final Set<String> selectedMembers;
  final List<String> selectedBuildingUnits;

  const RequestPermissionPage(
      {super.key,
      required this.visitor,
      required this.handleMemberSelectionfun,
      required this.selectedMembers,
      required this.selectedBuildingUnits});

  @override
  State<RequestPermissionPage> createState() => _RequestPermissionView1State();
}

class _RequestPermissionView1State extends State<RequestPermissionPage> {
  double lottieAnimationSize = 250;
  RequestType requestType = RequestType.request;

  @override
  Widget build(BuildContext context) {
    List<RequestType> requestTypes = [
      RequestType.approved,
      RequestType.rejected,
      RequestType.leaveAtGate,
      RequestType.notRecheable,
      RequestType.request,
      RequestType.waiting,
      RequestType.allowByGatekeeper
    ];

    Color colortoshow = const Color(0xffFFB080);

    Size screensize = MediaQuery.of(context).size;
    return MyScrollView(
      pageTitleWidget: Column(
        children: [
          SizedBox(
            height: screensize.height * 0.02,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                  // width: screensize.width * 0.15,
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
                                  builder: (context) =>
                                      const GateDashboardView()));
                        },
                        child: Icon(
                          Icons.home_outlined,
                          color: colortoshow,
                        )),
                  )),
              DropdownButton<RequestType>(
                value: requestType,
                hint: const Text("Select Request Type"),
                items: requestTypes.map((RequestType type) {
                  return DropdownMenuItem<RequestType>(
                    value: type,
                    child: Text(
                        type.toString().split('.').last), // Extracts enum name
                  );
                }).toList(),
                onChanged: (RequestType? newValue) {
                  setState(() {
                    requestType = newValue!;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      hasBackButton: EditableText.debugDeterministicCursor,
      floatingActionButton: _getbutton(requestType),
      pageBody: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        // mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(
            height: screensize.height * 0.01,
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(50),
                        child: Image.network(
                            width: screensize.height * 0.1,
                            height: screensize.height * 0.1,
                            fit: BoxFit.cover,
                            widget.visitor.visitor_image ?? ""),
                      ),
                      SizedBox(width: screensize.width * 0.1),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: screensize.width * 0.4,
                            child: Text(
                              widget.visitor.name ?? "",
                              style: const TextStyle(
                                  fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: colortoshow.withOpacity(0.4),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text("GUEST",
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall!
                                      .copyWith(fontSize: 10)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Divider(
                    thickness: 0.2,
                  ),
                  InfoLileWidget(
                    icon: Symbols.call,
                    iconColor: Colors.green,
                    title: widget.visitor.mobile!,
                  ),
                  InfoLileWidget(
                    icon: Symbols.apartment,
                    iconColor: colortoshow,
                    title: widget.selectedBuildingUnits.toString(),
                  ),
                ],
              ),
            ),
          ),
          Center(
            child: GestureDetector(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 20),
                width: double.maxFinite,
                child: _getLottieAnimation(requestType),
              ),
              onTap: () {},
            ),
          ),
          FittedBox(
            alignment: Alignment.topRight,
            // fit: BoxFit.fill,
            child: _getIconLabel(requestType),
          ),
        ],
      ),
    );
  }

  Widget _getLottieAnimation(RequestType requestType) {
    switch (requestType) {
      case RequestType.allowByGatekeeper:
        return Lottie.network(
            'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/allow_gatekeeper_a7f14dfb91.json?updated_at=2023-09-21T12:29:40.807Z',
            height: lottieAnimationSize,
            fit: BoxFit.contain);
      case RequestType.notRecheable:
        return Lottie.network(
            'https://fstech-cms-db.s3.ap-south-1.amazonaws.com/Animation_1738144371860_6ed19f54ff.json',
            height: lottieAnimationSize,
            fit: BoxFit.contain);
      case RequestType.approved:
        return Lottie.network(
            'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/accepted_ef4c4982b2.json?updated_at=2023-08-23T06:28:49.810Z',
            height: lottieAnimationSize,
            fit: BoxFit.contain);
      case RequestType.leaveAtGate:
        return Lottie.network(
          'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/leave_at_gate_048fedfdb6.json?updated_at=2023-08-23T06:28:51.200Z',
          height: lottieAnimationSize,
        );
      case RequestType.request:
        return Lottie.network(
            'https://fstech-cms-db.s3.ap-south-1.amazonaws.com/request_permission_5d72ff6325.json',
            height: lottieAnimationSize,
            fit: BoxFit.contain);
      case RequestType.rejected:
        return Lottie.network(
            'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/rejected_4bcdedc751.json?updated_at=2023-08-23T06:28:51.894Z',
            height: lottieAnimationSize * 0.8,
            fit: BoxFit.contain);
      case RequestType.waiting:
        return Lottie.network(
            'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/waiting_for_approval_07eb42d1d5.json?updated_at=2023-08-23T06:28:52.591Z',
            height: lottieAnimationSize,
            fit: BoxFit.contain);
      default:
        {
          return Lottie.network(
              'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/walk_e471a69550.json?updated_at=2023-08-23T06:28:52.519Z',
              height: lottieAnimationSize,
              fit: BoxFit.contain);
        }
    }
  }

  Widget _getIconLabel(RequestType requestType) {
    switch (requestType) {
      case RequestType.notRecheable:
        return Shimmer.fromColors(
            baseColor: const Color(0xffffc720),
            highlightColor: const Color.fromARGB(51, 255, 199, 32),
            child: Text(
              'Member not reachable !!',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: const Color(0xffffc720),
                    // fontWeight: FontWeight.bold,
                    fontSize: 25,
                  ),
            ));

      case RequestType.allowByGatekeeper:
        return Shimmer.fromColors(
            baseColor: const Color(0xffFFB080),
            highlightColor: const Color.fromARGB(51, 255, 177, 128),
            child: Text(
              'Allowed by gatekeeper',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: const Color(0xffFFB080),
                    // fontWeight: FontWeight.bold,
                    fontSize: 25,
                  ),
            ));
      case RequestType.approved:
        return Shimmer.fromColors(
            baseColor: const Color(0xff02af46),
            highlightColor: const Color.fromARGB(51, 2, 175, 71),
            child: Text(
              'Visitor approved',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    fontSize: 25,
                    color: const Color(0xff02af46),
                    // fontWeight: FontWeight.bold
                  ),
            ));

      case RequestType.leaveAtGate:
        return Shimmer.fromColors(
            baseColor: const Color.fromARGB(255, 169, 116, 96),
            highlightColor: const Color.fromARGB(51, 169, 116, 96),
            child: Text(
              'Leave at gate',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: const Color.fromARGB(255, 169, 116, 96),
                    // fontWeight: FontWeight.bold,
                    fontSize: 25,
                  ),
            ));

      case RequestType.request:
        return Shimmer.fromColors(
            baseColor: const Color(0xfffeb080),
            highlightColor: const Color.fromARGB(51, 254, 176, 128),
            child: SizedBox(
              width: 250,
              child: Text(
                'Request permission from member',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: const Color(0xfffeb080),
                      // fontWeight: FontWeight.bold,
                      fontSize: 25,
                    ),
              ),
            ));

      case RequestType.rejected:
        return Shimmer.fromColors(
            baseColor: Colors.red,
            highlightColor: const Color.fromARGB(51, 244, 67, 54),
            child: SizedBox(
                width: 250,
                child: Text(
                  'Visitor rejected',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: Colors.red,
                        // fontWeight: FontWeight.bold,
                        fontSize: 25,
                      ),
                )));

      case RequestType.waiting:
        return Shimmer.fromColors(
            baseColor: Colors.black,
            highlightColor: const Color.fromARGB(51, 0, 0, 0),
            child: SizedBox(
                width: 250,
                child: Text(
                  'Initializing request...',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: Colors.black,
                        // fontWeight: FontWeight.bold,
                        fontSize: 25,
                      ),
                )));
      default:
        {
          return Shimmer.fromColors(
              baseColor: Colors.black,
              highlightColor: const Color.fromARGB(51, 0, 0, 0),
              child: SizedBox(
                  width: 250,
                  child: Text(
                    'Initializing request...',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                          color: Colors.black,
                          // fontWeight: FontWeight.bold,
                          fontSize: 25,
                        ),
                  )));
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
              ElevatedButton(
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.all<Color>(
                      const Color(0xFF7D7C7C),
                    ),
                    backgroundColor:
                        WidgetStateProperty.all<Color>(Colors.white),
                    elevation: WidgetStateProperty.resolveWith<double>(
                      (Set<WidgetState> states) {
                        if (states.contains(WidgetState.pressed)) {
                          return 8;
                        }
                        return 0;
                      },
                    ),
                    shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                      RoundedRectangleBorder(
                        side: const BorderSide(color: Colors.black, width: 1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                  onPressed: () {},
                  child: SizedBox(
                      width: MediaQuery.of(context).size.width * 0.3,
                      height: 60,
                      child: const Center(
                          child: Text(
                        "Allow",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 15,
                          wordSpacing: 1.2,
                          // fontWeight: FontWeight.w500,
                        ),
                      )))),
              // CustomLargeBtn(
              //     width: MediaQuery.of(context).size.width * 0.45,
              //     onPressed: () {
              //       Navigator.push(
              //           context,
              //           MaterialPageRoute(
              //               builder: (context) => RequestPermissionView(
              //                     visitor: Visitor(),
              //                     purposeCategory: PurposeCategory1(
              //                         categoryId: 123,
              //                         categoryName: "categoryName"),
              //                   )));
              //     },
              //     text: "Allow"),

              CustomLargeBtn(
                  width: MediaQuery.of(context).size.width * 0.45,
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
                  text: "Try Again"),
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
            text: "Finish");
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
            text: "Capture photo");
      case RequestType.request:
        return CustomLargeBtn(
            onPressed: () {
              widget.handleMemberSelectionfun();

              // Navigator.push(
              //     context,
              //     MaterialPageRoute(
              //         builder: (context) => RequestPermissionView(
              //               visitor: Visitor(),
              //               purposeCategory: PurposeCategory1(
              //                   categoryId: 123, categoryName: "categoryName"),
              //             )));
            },
            text: "Request permission");
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
            text: "Finish");
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
              text: "Finish");
        }
    }
  }
}
