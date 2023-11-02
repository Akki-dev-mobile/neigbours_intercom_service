// ignore_for_file: prefer_const_constructors

import 'package:chips_choice/chips_choice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/bloc/visitor_log_bloc.dart';
import 'package:flutter_onegate/utils/app_utils.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:page_transition/page_transition.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:random_avatar/random_avatar.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

import '../../gate_selection/ui/gate_selection_view.dart';

class VisitorLogView extends StatefulWidget {
  String id;
  final List<String> logList;
  final String? selectedBuilding;

  VisitorLogView({
    required this.id,
    required this.logList,
    this.selectedBuilding,
    Key? key,
  }) : super(key: key);

  @override
  State<VisitorLogView> createState() => _VisitorLogViewState();
}

class _VisitorLogViewState extends State<VisitorLogView> {
  // final List<String> items =
  //     List.generate(50, (index) => 'Name Surname $index');
  late String selectedId;
  String? selectedTime;
  String? _searchText = "";
  List<String> options = ['All', 'Today', 'This Week', 'This Month', 'Custom'];

  String? selectedBuilding;
  List<String> selectedBuildingOptions = [
    'All',
    'Building A',
    'Building B',
    'Building C',
  ];

  final VisitorLogBloc _visitorLogBloc = VisitorLogBloc(
    VisitorLogUsecase(
      VisitorLogRepositoryImpl(
        RemoteDataSource(
          DioSingleton.instance1,
          DioSingleton.instance2,
          DioSingleton.instance3,
        ),
      ),
    ),
  );

  @override
  void initState() {
    super.initState();
    selectedId = widget.id;
    switch (widget.id) {
      case "In Out Book":
        _visitorLogBloc.add(FetchVisitorLogEvent(Utils.getCurrentTime()));
        break;
      case "Visitor In":
        _visitorLogBloc.add(FetchCheckInLogEvent(Utils.getCurrentTime()));
        break;
      case "Visitor Out":
        _visitorLogBloc.add(FetchCheckOutLogEvent(Utils.getCurrentTime()));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<VisitorLogBloc, VisitorLogState>(
      bloc: _visitorLogBloc,
      listenWhen: (previous, current) => current is VisitorLogActionState,
      buildWhen: (previous, current) => current is! VisitorLogActionState,
      listener: (context, state) {
        switch (state.runtimeType) {
          case VisitorLogCheckOutSuccessState:
            final successState = state as VisitorLogCheckOutSuccessState;
            if (successState.isCheckOut!) {
              Fluttertoast.showToast(
                msg: "User Checked Out Successfully",
                toastLength: Toast.LENGTH_SHORT,
                gravity: ToastGravity.CENTER,
                timeInSecForIosWeb: 1,
                backgroundColor: Colors.red,
                textColor: Colors.white,
                fontSize: 16.0,
              );
              _visitorLogBloc.add(FetchVisitorLogEvent(DateTime.now()));
            }
            break;
          case VisitorCheckInLogSuccessState:
            _visitorLogBloc.add(FetchCheckInLogEvent(Utils.getCurrentTime()));
            break;
        }
      },
      builder: (context, state) {
        switch (state.runtimeType) {
          case VisitorLogLoadingState:
            return LoaderView();
          case VisitorLogSuccessState:
            final successState = state as VisitorLogSuccessState;
            final visitorLogs = successState.visitorLogs;
            List<VisitorLog> filteredVisitors = visitorLogs!
                .where((visitorLog) => visitorLog.visitor!.name
                    .toLowerCase()
                    .contains(_searchText!.toLowerCase()))
                .toList();
            if (filteredVisitors.isEmpty) {
              filteredVisitors = visitorLogs;
            }
            return WillPopScope(
              onWillPop: () async {
                return false;
              },
              child: MyScrollView(
                isScrollable: false,
                hasBackButton: false,
                backButtonPressed: () {},
                // pageTitle: widget.id,
                pageTitleWidget: Hero(
                  tag: 'page_title',
                  child: Text(
                    widget.id,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: IconButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GateDashboardView(),
                          ),
                        );
                      },
                      icon: Icon(
                        Icons.home,
                      ),
                    ),
                  ),
                ],
                pageBody: Column(
                  children: [
                    CustomForm.textField(
                      widget.selectedBuilding ?? 'Search',
                      titleColor: Theme.of(context).colorScheme.onBackground,
                      hintColor: Theme.of(context).colorScheme.onPrimary,
                      // "Search" ?? ,
                      hintText: 'Search Visitor',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.search,
                      onFieldSubmitted: (value) {
                        if (kDebugMode) {
                          print(value);
                        }
                      },
                      onChanged: (value) {
                        setState(() {
                          _searchText = value;
                        });
                      },
                      prefixIcon: IconButton(
                        onPressed: () {},
                        icon: Icon(
                          Ionicons.search_outline,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                      ),
                      suffixIcon: ButtonBar(
                        alignment: MainAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // IconButton(
                          //   onPressed: () {},
                          //   icon: CircleAvatar(
                          //     backgroundColor: const Color(0xffFFEBE6),
                          //     radius: 20,
                          //     child: Icon(
                          //       size: 22,
                          //       Ionicons.mic_outline,
                          //       color: Theme.of(context).colorScheme.onBackground,
                          //     ),
                          //   ),
                          // ),
                          IconButton(
                            onPressed: () {
                              _showLogBookConfigBottomSheet(context);
                            },
                            icon: Icon(
                              Ionicons.funnel_outline,
                              color: Theme.of(context).colorScheme.onBackground,
                              size: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ChipsChoice<String>.single(
                    //   padding: EdgeInsets.only(right: 20),
                    //   scrollToSelectedOnChanged: true,
                    //   spacing: 20,
                    //   choiceStyle: C2ChipStyle.outlined(
                    //     borderWidth: 1,
                    //     color: Colors.grey.shade700,
                    //     selectedStyle: C2ChipStyle.filled(
                    //       foregroundColor: Color(0xFFC08261),
                    //     ),
                    //     height: 40,
                    //   ),
                    //   choiceCheckmark: true,
                    //   value: selectedTime,
                    //   scrollPhysics: BouncingScrollPhysics(),
                    //   onChanged: (value) {
                    //     setState(() {
                    //       selectedTime = value;
                    //     });
                    //   },
                    //   choiceItems: C2Choice.listFrom<String, String>(
                    //     source: options,
                    //     value: (i, v) => v,
                    //     label: (i, v) => v,
                    //   ),
                    // ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.7,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredVisitors.length,
                        itemBuilder: (context, index) {
                          String unitList = filteredVisitors[index]
                              .visitor_building_assignment![0]
                              .unit_id
                              .map((units) => units.toString())
                              .join(', ');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Card(
                              elevation: 2,
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 2,
                                    ),
                                    leading: CircleAvatar(
                                        child: filteredVisitors[index]
                                                        .visitor!
                                                        .visitor_image !=
                                                    null &&
                                                filteredVisitors[index]
                                                    .visitor!
                                                    .visitor_image
                                                    .isNotEmpty
                                            ? Text(
                                                filteredVisitors[index]
                                                    .visitor!
                                                    .mobile
                                                    .substring(0, 1),
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .bodyMedium,
                                              )
                                            : RandomAvatar(
                                                DateTime.now()
                                                    .toIso8601String(),
                                                trBackground: false,
                                              )),
                                    // title: Text(
                                    //   filteredVisitors[index].visitor!.name,
                                    //   style:
                                    //       Theme.of(context).textTheme.bodyMedium,
                                    // ),
                                    title: RichText(
                                      text: TextSpan(
                                        children: [
                                          TextSpan(
                                            text: filteredVisitors[index]
                                                .visitor!
                                                .name,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium,
                                          ),
                                          WidgetSpan(
                                            child: visitorLogs[index]
                                                        .visitor_count
                                                        .toString() !=
                                                    '1'
                                                ? Container(
                                                    margin:
                                                        const EdgeInsets.only(
                                                            left: 8),
                                                    padding: const EdgeInsets
                                                        .symmetric(
                                                      horizontal: 7,
                                                      vertical: 2,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                          0xffFFEBE6),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                              8),
                                                      // border: Border.all(
                                                      //   color: Colors.black,
                                                      // ),
                                                    ),
                                                    child: Text(
                                                      "+ ${visitorLogs[index].visitor_count.toString()}",
                                                      style: TextStyle(
                                                        color: Colors.black,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        fontSize: 14,
                                                      ),
                                                    ))
                                                : SizedBox(),
                                          ),
                                        ],
                                      ),
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
                                            TextSpan(
                                                text: unitList,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .labelSmall),
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
                                                  // border: Border.all(
                                                  //   color: Colors.black,
                                                  // ),
                                                ),
                                                child: const Text(
                                                  'Guest',
                                                  style: TextStyle(
                                                    color: Colors.black,
                                                    fontWeight: FontWeight.w500,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    trailing: IconButton(
                                      onPressed: () {
                                        FlutterPhoneDirectCaller.callNumber(
                                            visitorLogs[index]
                                                .visitor!
                                                .mobile
                                                .toString());
                                      },
                                      icon: Icon(
                                        Ionicons.call_outline,
                                        color: Colors.green,
                                      ),
                                    ),
                                  ),
                                  Divider(
                                    indent: 16,
                                    endIndent: 16,
                                    color: Colors.grey[200],
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(
                                        bottom: 14.0, top: 8),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceEvenly,
                                      children: [
                                        RichText(
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
                                                text:
                                                    Utils.convertDateTimeFormat(
                                                        filteredVisitors[index]
                                                            .visitor_check_in),
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
                                        Container(
                                          margin:
                                              const EdgeInsets.only(left: 8),
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 2, horizontal: 10),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: const [
                                                Color.fromRGBO(
                                                  255,
                                                  236,
                                                  158,
                                                  0.8,
                                                ),
                                                Color.fromRGBO(
                                                  255,
                                                  190,
                                                  168,
                                                  0.8,
                                                ),
                                              ],
                                              begin: Alignment.topRight,
                                              end: Alignment.bottomLeft,
                                            ),
                                            // color: const Color(0xffFFEBE6),
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            border: Border.all(
                                              color: Color.fromRGBO(
                                                  255, 190, 168, 1),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              Lottie.asset(
                                                'assets/json/idcard.json',
                                                width: 30,
                                                height: 30,
                                                fit: BoxFit.cover,
                                                animate: true,
                                              ),
                                              SizedBox(
                                                width: 5,
                                              ),
                                              Text(
                                                "V-110",
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 14,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        (filteredVisitors[index]
                                                    .visitor_check_out
                                                    .toString()
                                                    .isEmpty ||
                                                filteredVisitors[index]
                                                        .visitor_check_out
                                                        .toString() ==
                                                    'null')
                                            ? ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: Colors.red,
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            8),
                                                  ),
                                                ),
                                                onPressed: () {
                                                  filteredVisitors[index]
                                                          .visitor_check_out =
                                                      Utils.getCurrentTime();
                                                  filteredVisitors[index]
                                                      .is_checked_out = true;
                                                  _visitorLogBloc.add(
                                                      CheckOutEvent(
                                                          filteredVisitors[
                                                              index],
                                                          widget.id));
                                                },
                                                child: Text(
                                                  'CheckOut',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .labelSmall!
                                                      .merge(
                                                        const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 14),
                                                      ),
                                                ),
                                              )
                                            : RichText(
                                                text: TextSpan(
                                                  children: [
                                                    const WidgetSpan(
                                                      child: Icon(
                                                        Symbols
                                                            .directions_walk_rounded,
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                    TextSpan(
                                                      text: Utils
                                                          .convertDateTimeFormat(
                                                              filteredVisitors[
                                                                      index]
                                                                  .visitor_check_out!),
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .labelMedium!
                                                          .merge(
                                                            const TextStyle(
                                                              color: Colors.red,
                                                            ),
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(
                      height: 100,
                    ),
                  ],
                ),
              ),
            );
          default:
            return Container();
        }
      },
    );
  }

  void _showLogBookConfigBottomSheet(BuildContext context) async {
    showModalBottomSheet(
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: Theme.of(context).colorScheme.background,
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Filters',
                      style: Theme.of(context).textTheme.displaySmall!.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  // ChipsChoice<String>.single(
                  //   padding: EdgeInsets.only(right: 20),
                  //   scrollToSelectedOnChanged: true,
                  //   spacing: 20,
                  //   choiceStyle: C2ChipStyle.outlined(
                  //     borderWidth: 1,
                  //     color: Colors.grey.shade700,
                  //     selectedStyle: C2ChipStyle.filled(
                  //       foregroundColor: Color(0xFFC08261),
                  //     ),
                  //     height: 40,
                  //   ),
                  //   choiceCheckmark: true,
                  //   value: selectedBuilding,
                  //   scrollPhysics: BouncingScrollPhysics(),
                  //   onChanged: (value) {
                  //     setState(() {
                  //       selectedBuilding = value;
                  //     });
                  //   },
                  //   choiceItems: C2Choice.listFrom<String, String>(
                  //     source: selectedBuildingOptions,
                  //     value: (i, v) => v,
                  //     label: (i, v) => v,
                  //   ),
                  // ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.logList.length,
                      itemBuilder: (context, index) {
                        return GateSettingListTile(
                          switchValue: selectedId == widget.logList[index],
                          onChanged: (value) {
                            setState(() {
                              selectedId = widget.logList[index];
                            });
                          },
                          title: widget.logList[index],
                          subtitle: 'Enable/Disable ${widget.logList[index]}',
                          leadingIcon: Symbols.gate,
                        );
                      },
                    ),
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  CustomLargeBtn(
                    text: 'Confirm',
                    onPressed: () {
                      setState(() {
                        widget.id = selectedId;
                      });
                      Navigator.pop(context);
                      Navigator.pushReplacement(
                        context,
                        PageTransition(
                          type: PageTransitionType.bottomToTop,
                          child: VisitorLogView(
                            id: widget.id,
                            logList: widget.logList,
                            selectedBuilding: selectedBuilding,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
