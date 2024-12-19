// ignore_for_file: prefer_const_constructors

import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/bloc/visitor_log_bloc.dart';
import 'package:flutter_onegate/utils/app_utils.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late String selectedId;
  String? _searchText = "";
  List<String> options = ['All', 'Today', 'This Week', 'This Month', 'Custom'];
  final gateStorage = GateStorage();
  final remoteDataSource = RemoteDataSource(
      DioSingleton.instance1, DioSingleton.instance2, DioSingleton.instance3);

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
    final today = DateTime.now();
    final yesterday = today.subtract(Duration(days: 1));

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
            print("here i am $visitorLogs");
            List<VisitorLog> filteredVisitors = visitorLogs!
                .where((visitorLog) => visitorLog.visitor!.name
                    .toLowerCase()
                    .contains(_searchText!.toLowerCase()))
                .toList();
            final todayLogs = filteredVisitors.where((log) {
              return log.visitor_check_in
                  .isAfter(today.subtract(Duration(days: 1)));
            }).toList();

            final yesterdayLogs = filteredVisitors.where((log) {
              return log.visitor_check_in
                      .isAfter(yesterday.subtract(Duration(days: 1))) &&
                  log.visitor_check_in.isBefore(today);
            }).toList();

            final olderLogs = filteredVisitors.where((log) {
              return log.visitor_check_in.isBefore(yesterday);
            }).toList();
            return PopScope(
              canPop: false,
              child: MyScrollView(
                isScrollable: false,
                hasBackButton: false,
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
                  Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: IconButton(
                      onPressed: () async {
                        await _showExportDialog(context, visitorLogs);
                      },
                      icon: const Icon(
                        Icons.download,
                      ),
                    ),
                  )

// ,
                ],
                pageBody: Column(
                  children: [
                    CustomForm.textField(
                      widget.selectedBuilding ?? 'Search',
                      titleColor: Theme.of(context).colorScheme.onSurface,
                      hintColor: Theme.of(context).colorScheme.onSurface,
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
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          _showLogBookConfigBottomSheet(context);
                        },
                        icon: Icon(
                          Ionicons.funnel_outline,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 24,
                        ),
                      ),
                    ),
                    ListView(
                      shrinkWrap: true,
                      children: [
                        ExpansionTile(
                          trailing: Text(
                            todayLogs.length.toString(),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          initiallyExpanded: true,
                          title: Text('Today'),
                          children: todayLogs.map((log) {
                            return VisitorLogItem(
                              visitorLog: log,
                              onCheckOut: () {
                                log.visitor_check_out = Utils.getCurrentTime();
                                log.is_checked_out = true;
                                _visitorLogBloc
                                    .add(CheckOutEvent(log, widget.id));
                              },
                            );
                          }).toList(),
                        ),
                        ExpansionTile(
                          trailing: Text(
                            yesterdayLogs.length.toString(),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          title: Text('Yesterday'),
                          children: yesterdayLogs.map((log) {
                            return VisitorLogItem(
                              visitorLog: log,
                              onCheckOut: () {
                                log.visitor_check_out = Utils.getCurrentTime();
                                log.is_checked_out = true;
                                _visitorLogBloc
                                    .add(CheckOutEvent(log, widget.id));
                              },
                            );
                          }).toList(),
                        ),
                        ExpansionTile(
                          trailing: Text(
                            olderLogs.length.toString(),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                          title: Text('Older'),
                          children: olderLogs.take(10).map((log) {
                            return VisitorLogItem(
                              visitorLog: log,
                              onCheckOut: () {
                                log.visitor_check_out = Utils.getCurrentTime();
                                log.is_checked_out = true;
                                _visitorLogBloc
                                    .add(CheckOutEvent(log, widget.id));
                              },
                            );
                          }).toList(),
                          onExpansionChanged: (expanded) {
                            if (expanded) {
                              setState(() {
                                olderLogs.addAll(filteredVisitors.skip(10));
                              });
                            }
                          },
                        ),
                      ],
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

  Future<void> _showExportDialog(
      BuildContext context, List<VisitorLog> visitorLogs) async {
    TextEditingController emailController = TextEditingController();
    TextEditingController nameController = TextEditingController();
    DateTime? fromDate;
    DateTime? toDate;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final storedEmail = prefs.getString('email') ?? ''; // Load email if saved
    emailController.text = storedEmail;

    // Function to pick a date
    Future<DateTime?> _pickDate(BuildContext context) async {
      return await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime(2000),
        lastDate: DateTime.now(),
      );
    }

    // Show the dialog
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Export Logs'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Email Input
                    CustomForm.textField("name",
                        titleColor: Theme.of(context).colorScheme.onSurface,
                        hintColor: Theme.of(context).colorScheme.onPrimary,
                        hintText: "Enter name for export",
                        textController: nameController),

                    CustomForm.textField("Email",
                        titleColor: Theme.of(context).colorScheme.onSurface,
                        hintColor: Theme.of(context).colorScheme.onPrimary,
                        hintText: "Enter email for export",
                        textController: emailController),

                    const SizedBox(height: 10),
                    ListTile(
                      title: Text(
                        "From Date: ${fromDate != null ? DateFormat('yyyy-MM-dd').format(fromDate!) : 'Select'}",
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await _pickDate(context);
                        if (picked != null) {
                          setState(() {
                            fromDate = picked;
                          });
                        }
                      },
                    ),
                    // To Date Picker
                    ListTile(
                      title: Text(
                          "To Date: ${toDate != null ? DateFormat('yyyy-MM-dd').format(toDate!) : 'Select'}",
                          style: Theme.of(context).textTheme.headlineSmall),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await _pickDate(context);
                        if (picked != null) {
                          setState(() {
                            toDate = picked;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                CustomLargeBtn(
                    onPressed: () async {
                      // Save email in SharedPreferences
                      await prefs.setString('email', emailController.text);

                      final formattedFromDate = fromDate != null
                          ? DateFormat('yyyy-MM-dd').format(fromDate!)
                          : null;
                      final formattedToDate = toDate != null
                          ? DateFormat('yyyy-MM-dd').format(toDate!)
                          : null;

                      // Prepare export data
                      var visitorData = visitorLogs.map((visitor) {
                        return {
                          "name": nameController.text,
                          "visitor_count": visitor.visitor_count ?? 1,
                          "to_mail": emailController.text,
                          "from_date": formattedFromDate,
                          "to_date": formattedToDate,
                        };
                      }).toList();

                      print("Export Data: $visitorData");
                      print(
                          "Email: ${emailController.text}, From: $formattedFromDate, To: $formattedToDate");

                      // Call API with the updated payload
                      await remoteDataSource.exportLogs(visitorData);

                      // Close dialog
                      Navigator.of(context).pop();
                    },
                    text: "Export")
              ],
            );
          },
        );
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
                color: Theme.of(context).colorScheme.surface,
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
                            selectedBuilding: widget.selectedBuilding,
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

class VisitorLogItem extends StatelessWidget {
  final VisitorLog visitorLog;
  final Function onCheckOut;

  const VisitorLogItem({
    Key? key,
    required this.visitorLog,
    required this.onCheckOut,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    String unitList = '';
    if (visitorLog.visitor_building_assignment != null &&
        visitorLog.visitor_building_assignment!.isNotEmpty) {
      unitList = visitorLog.visitor_building_assignment![0].unit_id
          .map((units) => units.toString())
          .join(', ');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Card(
        elevation: 2,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 2,
              ),
              leading: CircleAvatar(
                backgroundImage: (visitorLog
                            .visitor!.visitor_image.isNotEmpty &&
                        Uri.tryParse(visitorLog.visitor!.visitor_image)
                                ?.hasAbsolutePath ==
                            true)
                    ? NetworkImage(visitorLog.visitor!.visitor_image)
                    : NetworkImage(
                        "https://plus.unsplash.com/premium_photo-1678706071143-232715cbb866?q=80&w=3027&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"),
                child: visitorLog.visitor!.visitor_image.isEmpty
                    ? Text(
                        visitorLog.visitor!.name.isNotEmpty
                            ? visitorLog.visitor!.name[0]
                            : 'asd',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    : null,
              ),
              title: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: visitorLog.visitor!.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    WidgetSpan(
                      child: visitorLog.visitor_count.toString() != '1'
                          ? Container(
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
                                "+ ${visitorLog.visitor_count.toString()}",
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 14,
                                ),
                              ),
                            )
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
                          style: Theme.of(context).textTheme.labelSmall),
                      WidgetSpan(
                        child: Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xffFFEBE6),
                            borderRadius: BorderRadius.circular(8),
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
                  SnackBar(
                    content: Text(
                      'Calling ${visitorLog.visitor!.mobile}',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    action: SnackBarAction(
                      label: 'Close',
                      onPressed: () {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      },
                    ),
                  );
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
              padding: const EdgeInsets.only(bottom: 14.0, top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Tooltip(
                    message: DateFormat('dd-MM-yyyy hh:mm a')
                        .format(visitorLog.visitor_check_in),
                    child: RichText(
                      text: TextSpan(
                        children: [
                          const WidgetSpan(
                            child: Icon(
                              Symbols.directions_walk_rounded,
                              color: Colors.green,
                            ),
                          ),
                          TextSpan(
                            text: Utils.convertDateTimeFormat(
                                visitorLog.visitor_check_in),
                            style:
                                Theme.of(context).textTheme.labelMedium!.merge(
                                      const TextStyle(
                                        color: Colors.green,
                                      ),
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(
                      vertical: 2,
                      horizontal: 10,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: const [
                          Color.fromRGBO(255, 236, 158, 0.8),
                          Color.fromRGBO(255, 190, 168, 0.8),
                        ],
                        begin: Alignment.topRight,
                        end: Alignment.bottomLeft,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Color.fromRGBO(255, 190, 168, 1),
                      ),
                    ),
                    child: Row(
                      children: [
                        Lottie.asset(
                          'assets/json/idcard.json',
                          width: 30,
                          height: 30,
                          fit: BoxFit.cover,
                        ),
                        SizedBox(
                          width: 5,
                        ),
                        Text(
                          'V-20',
                          style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  (visitorLog.visitor_check_out.toString().isEmpty ||
                          visitorLog.visitor_check_out.toString() == 'null')
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            onCheckOut();
                          },
                          child: Text(
                            'CheckOut',
                            style:
                                Theme.of(context).textTheme.labelSmall!.merge(
                                      const TextStyle(
                                          color: Colors.white, fontSize: 14),
                                    ),
                          ),
                        )
                      : Tooltip(
                          message: DateFormat('dd-MM-yyyy hh:mm a')
                              .format(visitorLog.visitor_check_out!),
                          child: RichText(
                            text: TextSpan(
                              children: [
                                const WidgetSpan(
                                  child: Icon(
                                    Symbols.directions_walk_rounded,
                                    color: Colors.red,
                                  ),
                                ),
                                TextSpan(
                                  text: Utils.convertDateTimeFormat(
                                      visitorLog.visitor_check_out!),
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
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
