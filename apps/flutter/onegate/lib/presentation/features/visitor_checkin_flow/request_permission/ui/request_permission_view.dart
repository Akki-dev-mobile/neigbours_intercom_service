// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/entities/society/member_unit.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/request_permission/bloc/request_permission_bloc.dart';
import 'package:lottie/lottie.dart';

class RequestPermissionView extends StatefulWidget {
  final List<MemberUnits>? gridData;
  final Visitor visitor;
  final PurposeCategory1 purposeCategory;
  final String? comingFrom;
  final int? guestCount;
  const RequestPermissionView(
      {super.key,
      this.gridData,
      required this.visitor,
      required this.purposeCategory,
      this.comingFrom,
      this.guestCount});

  @override
  State<RequestPermissionView> createState() =>
      _RequestPermissionViewState(gridData: gridData);
}

enum RequestType {
  rejected,
  leaveAtGate,
  approved,
  notRecheable,
  waiting,
  request,
  allowByGatekeeper
}

class _RequestPermissionViewState extends State<RequestPermissionView> {
  RequestType requestType = RequestType.notRecheable;
  final List<MemberUnits>? gridData;
  final RequestPermissionBloc requestPermissionBloc = RequestPermissionBloc(
      VisitorLogUsecase(VisitorLogRepositoryImpl( RemoteDataSource(
     ))));

  _RequestPermissionViewState({this.gridData});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<RequestPermissionBloc, RequestPermissionState>(
      bloc: requestPermissionBloc,
      listenWhen: (previous, current) =>
          current is RequestPermissionActionState,
      buildWhen: (previous, current) =>
          current is! RequestPermissionActionState,
      listener: (context, state) {
        print('${state.runtimeType}');
        switch (state.runtimeType) {
          case RPVisitorCheckedInSuccessState:
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) {
                  return const GateDashboardView();
                },
              ),
            );
            break;
          case RPErrorState:
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text((state as RPErrorState).message!),
              ),
            );
            break;
        }
      },
      builder: (context, state) {
        print('${state.runtimeType}');
        switch (state.runtimeType) {
          case RPLoadingState:
            return Center(
              child: CircularProgressIndicator(),
            );

          case RequestPermissionInitial:
            return MyScrollView(
              backButtonPressed: () {
                Navigator.pop(context);
              },
              hasBackButton: true,
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
                            widget.visitor.mobile ?? "",
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          Text(
                            widget.visitor.name ?? "",
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
                                    text: widget.purposeCategory.categoryName,
                                    style: TextStyle(
                                      color: Colors.blue[400],
                                    ),
                                  ),
                                  // TextSpan(
                                  //   text: '| Last In: 2 days ago',
                                  // ),
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
                      'Selected Flat',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
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
                      child: GridView.builder(
                        padding: EdgeInsets.only(
                          bottom: 10,
                        ),
                        shrinkWrap: true,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          childAspectRatio: 2,
                          crossAxisCount: 3,
                          crossAxisSpacing: 10.0,
                          mainAxisSpacing: 10.0,
                        ),
                        itemCount: 2,
                        itemBuilder: (BuildContext context, int index) {
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: Color(0x10C08261),
                              border: Border.all(
                                color: Color(0xffC08261),
                                width: 2,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                "1306",
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(
                                      color: Color(0xffC08261),
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ),
                          );
                        },
                      ),
                      // child: FittedBox(
                      //   fit: BoxFit.scaleDown,
                      //   child: Text(
                      //     'A-101',
                      //     style: Theme.of(context).textTheme.bodyMedium,
                      //   ),
                      // ),
                    ),
                  ),
                  GestureDetector(
                    child: Container(
                      margin: EdgeInsets.only(top: 40, bottom: 30),
                      width: double.infinity,
                      child: _getLottieAnimation(requestType),
                    ),
                    onTap: () {
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => GateDashboardView(),
                      //   ),
                      // );
                    },
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
                heroTag: 'gate_dashboard',
                text: 'Allow',
                onPressed: () {
                  requestPermissionBloc.add(
                    AllowButtonClickedEvent(
                      visitor: widget.visitor,
                      purposeCategory: widget.purposeCategory,
                      memberUnits: gridData!,
                      comingFrom: widget.comingFrom,
                      guestCount: widget.guestCount,
                    ),
                  );
                },
              ),
            );

          default:
            return Container();
        }
      },
    );
  }

  Widget _getLottieAnimation(RequestType requestType) {
    switch (requestType) {
      case RequestType.notRecheable:
        return Lottie.network(
          'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/allow_gatekeeper_a7f14dfb91.json?updated_at=2023-09-21T12:29:40.807Z',
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
          'Allow by gatekeeper',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
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
