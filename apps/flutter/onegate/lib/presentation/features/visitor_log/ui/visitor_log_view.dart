// ignore_for_file: prefer_const_constructors

import 'dart:developer';

import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/bloc/gatekeeper_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_provider.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/bloc/visitor_log_bloc.dart';
import 'package:flutter_onegate/presentation/features/visitor_log/ui/visitor_Details.dart';
import 'package:flutter_onegate/utils/app_utils.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:intl/intl.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';

class VisitorLogView extends StatefulWidget {
  String id;
  final List<String> logList;
  final String? selectedBuilding;
  int? societyID;

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
  var selectedGateName;
  late FocusNode _searchFocusNode;

  List<String> options = ['All', 'Today', 'This Week', 'This Month', 'Custom'];
  final gateStorage = GateStorage();
  final remoteDataSource = RemoteDataSource(
      DioSingleton.instance1, DioSingleton.instance2, DioSingleton.instance3);
  var societyId;
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

      case "Cards":
        _visitorLogBloc.add(FetchCheckInLogEvent(Utils.getCurrentTime()));

        // _visitorLogBloc.add(FetchCheckInLogEvent(Utils.getCurrentTime()));
        break;
      case "Visitor Out":
        _visitorLogBloc.add(FetchCheckOutLogEvent(Utils.getCurrentTime()));
        break;
    }
    _initializeSocietyId();
    getSelectedGate();
    _searchFocusNode = FocusNode();

    // _storeTodayLogsCount(context);
  }

  @override
  void dispose() {
    _searchFocusNode.dispose();

    super.dispose();
  }

  Future<void> getSelectedGate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedGateName = prefs.getString('selected_gate');
    });
  }

  Future<void> _initializeSocietyId() async {
    societyId = await gateStorage.getSocietyId();
    log('Society ID: $societyId');
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
            Fluttertoast.showToast(
              msg: "Visitor Checked Out Successfully",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.CENTER,
              timeInSecForIosWeb: 1,
              backgroundColor: Colors.green,
              textColor: Colors.white,
              fontSize: 16.0,
            );
            break;
        }
      },
      builder: (context, state) {
        switch (state.runtimeType) {
          case VisitorLogLoadingState:
            return LoaderView();
          case VisitorLogSuccessState:
            final successState = state as VisitorLogSuccessState;
            final visitorLogs = successState.visitorLogs ?? [];
            List<VisitorLog> uniqueVisitorLogs = [];
            Set<String> checkInTimes = {};

            for (var log in visitorLogs) {
              final checkInTime = log.visitor_check_in?.toIso8601String();
              if (!checkInTimes.contains(checkInTime)) {
                checkInTimes.add(checkInTime!);
                uniqueVisitorLogs.add(log);
              }
            }

            // ----------------------------------------------------------------
            //      SEARCH LOGIC (NAME, CARD_NUMBER, UNIT_ID)
            // ----------------------------------------------------------------
            final searchLower = _searchText!.toLowerCase();

            /// Filter visitors if search text is present in:
            /// - visitor name
            /// - visitor_card_number
            /// - any assigned unit ID
            List<VisitorLog> filteredVisitors = uniqueVisitorLogs.where((vLog) {
              final vName = vLog.visitor?.name?.toLowerCase() ?? '';
              final vCardNo = vLog.visitor_card_number?.toLowerCase() ?? '';

              // Flatten all unit IDs under building_assignment
              final unitIds = vLog.visitor_building_assignment
                      ?.expand((assignment) => assignment.unit_id ?? [])
                      .map((unit) => unit.toString().toLowerCase())
                      .toList() ??
                  [];

              // If name, cardNo, or any of the unit IDs match
              final matchName = vName.contains(searchLower);
              final matchCard = vCardNo.contains(searchLower);
              final matchUnit = unitIds.any((u) => u.contains(searchLower));

              return matchName || matchCard || matchUnit;
            }).toList();
            // ----------------------------------------------------------------

            /// Create day-based groupings for filtered logs
            final today = DateTime.now();
            final startOfToday = DateTime(today.year, today.month, today.day);
            final endOfToday = startOfToday.add(const Duration(days: 1));
            final startOfYesterday =
                startOfToday.subtract(const Duration(days: 1));
            final endOfYesterday = startOfToday;

            // * For storing 'today' logs count
            List<VisitorLog> todayLogs = filteredVisitors.where((log) {
              final checkInDate = log.visitor_check_in!;
              return checkInDate.isAfter(startOfToday) &&
                  checkInDate.isBefore(endOfToday);
            }).toList();

            // * For storing 'checkout' logs count
            List<VisitorLog> todayCheckoutLogs = filteredVisitors.where((log) {
              final checkOutDate = log.visitor_check_out;
              return checkOutDate != null &&
                  checkOutDate.isAfter(startOfToday) &&
                  checkOutDate.isBefore(endOfToday);
            }).toList();

            // Store the counts in SharedPreferences for use elsewhere
            Future<void> _storeTodayLogsCount(int count, String key) async {
              final prefs = await SharedPreferences.getInstance();
              prefs.setInt(key, count);
            }

            _storeTodayLogsCount(todayLogs.length, 'todayLogsCount');
            _storeTodayLogsCount(
              todayCheckoutLogs.length,
              'todayCheckoutLogsCount',
            );

            // Yesterday logs
            List<VisitorLog> yesterdayLogs = filteredVisitors.where((log) {
              final checkInDate = log.visitor_check_in!;
              return checkInDate.isAfter(startOfYesterday) &&
                  checkInDate.isBefore(endOfYesterday);
            }).toList();

            // Older logs
            List<VisitorLog> olderLogs = filteredVisitors.where((log) {
              final checkInDate = log.visitor_check_in!;
              return checkInDate.isBefore(startOfYesterday);
            }).toList();

            bool _isPopping = false;

            void _safePop(BuildContext context) {
              if (!_isPopping) {
                _isPopping = true;
                Navigator.of(context).pop();
                Future.delayed(Duration(milliseconds: 300), () {
                  _isPopping = false;
                });
              }
            }

            return WillPopScope(
              onWillPop: () async {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => GateDashboardView()),
                  (Route<dynamic> route) => false,
                );

                return false;
              },
              child: MyScrollView(
                // isScrollable: false,
                hasBackButton: true,
                pageTitleWidget: Hero(
                  tag: 'page_title',
                  child: Text(
                    widget.id,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
                actions: [
                  if (widget.id == "In Out Book")
                    GestureDetector(
                      onTap: () {
                        _showExportBottomSheet(context, visitorLogs);
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 10.0),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.download_rounded,
                                  color: Colors.black,
                                ),
                                const Padding(
                                  padding: EdgeInsets.only(right: 8.0),
                                  child: Text(
                                    'Export',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                ],
                pageBody: Column(
                  children: [
                    CustomForm.textField(
                      widget.selectedBuilding ?? 'Search',
                      focusNode: _searchFocusNode,
                      titleColor: Theme.of(context).colorScheme.onSurface,
                      hintColor: Theme.of(context).colorScheme.onSurface,
                      hintText:
                          'Search ${widget.id != 'Cards' ? 'visitor' : 'card number'}',
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
                    if (_searchText!.isNotEmpty && filteredVisitors.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off_outlined,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No such visitors found in log',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (todayLogs.isEmpty && _searchText!.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off_outlined,
                              size: 48,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No visitors today',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'When visitors check in, they will appear here',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ListView.builder(
                      physics: BouncingScrollPhysics(),
                      shrinkWrap: true,
                      itemCount: todayLogs.length +
                          yesterdayLogs.length +
                          olderLogs.length +
                          (todayLogs.isNotEmpty ? 1 : 0) +
                          (yesterdayLogs.isNotEmpty ? 1 : 0) +
                          (olderLogs.isNotEmpty ? 1 : 0), // Add headers count
                      itemBuilder: (context, index) {
                        int currentIndex = 0;

                        // Today Section
                        if (todayLogs.isNotEmpty) {
                          if (index == currentIndex) {
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [],
                            );
                          }
                          if (index > currentIndex &&
                              index <= currentIndex + todayLogs.length) {
                            return VisitorLogItem(
                              visitorLog: todayLogs[index - currentIndex - 1],
                              onCheckOut: () {
                                setState(() {
                                  todayLogs[index - currentIndex - 1]
                                          .visitor_check_out =
                                      Utils.getCurrentTime();
                                  todayLogs[index - currentIndex - 1]
                                      .is_checked_out = true;
                                });

                                // Emit a success state with updated logs directly
                                _visitorLogBloc
                                    .emit(VisitorLogSuccessState(todayLogs));

                                // Trigger the Bloc event to process the checkout for backend synchronization
                                _visitorLogBloc.add(CheckOutEvent(
                                  todayLogs[index - currentIndex - 1],
                                  widget.id,
                                ));
                              },
                            );
                          }
                          currentIndex +=
                              todayLogs.length + 1; // Add 1 for header
                        }

                        return const SizedBox
                            .shrink(); // Fallback in case of unexpected index
                      },
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

  bool isLoading = false;

  Future<void> _showExportBottomSheet(
      BuildContext context, List<VisitorLog> visitorLogs) async {
    final TextEditingController emailController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    bool isLoading = false;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final storedEmail = prefs.getString('email') ?? '';
    emailController.text = storedEmail;

    final exportFormKey = GlobalKey<FormState>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
          return Container(
            padding: EdgeInsets.only(
              top: 16,
              left: 16,
              right: 16,
              bottom: MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.background,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Form(
              key: exportFormKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Export Logs',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),
                    CustomForm.textField(
                      "Email",
                      titleColor: Theme.of(context).colorScheme.onSurface,
                      hintColor: Theme.of(context).colorScheme.onPrimary,
                      hintText: "Enter email for export",
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value!.isEmpty) {
                          return 'Please enter email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                      textController: emailController,
                    ),
                    const SizedBox(height: 20),
                    FormField<DateTime>(
                      validator: (value) {
                        if (startDate == null) {
                          return "Please select a start date";
                        }
                        return null;
                      },
                      builder: (fieldState) {
                        return InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now(),
                              builder: (BuildContext context, Widget? child) {
                                return Theme(
                                  data: ThemeData.light().copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: Colors.black,
                                    ),
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.black,
                                      ),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() {
                                startDate = picked;
                                if (endDate != null &&
                                    startDate!.isAfter(endDate!)) {
                                  endDate = null;
                                }
                                fieldState.didChange(picked);
                              });
                            }
                          },
                          child: _buildDateField(
                            context,
                            label: 'From Date',
                            date: startDate,
                            placeholder: 'Select From Date',
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 16),
                    FormField<DateTime>(
                      validator: (value) {
                        if (endDate == null) {
                          return "Please select an end date";
                        }
                        if (startDate != null &&
                            endDate!.isBefore(startDate!)) {
                          return "End date cannot be earlier than start date";
                        }
                        return null;
                      },
                      builder: (fieldState) {
                        return InkWell(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: endDate ?? DateTime.now(),
                              firstDate: startDate ?? DateTime(2000),
                              lastDate: DateTime.now(),
                              builder: (BuildContext context, Widget? child) {
                                return Theme(
                                  data: ThemeData.light().copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: Colors.black,
                                    ),
                                    textButtonTheme: TextButtonThemeData(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.black,
                                      ),
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() {
                                endDate = picked;
                                fieldState.didChange(picked);
                              });
                            }
                          },
                          child: _buildDateField(
                            context,
                            label: 'To Date',
                            date: endDate,
                            placeholder: 'Select To Date',
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),
                    if (isLoading)
                      const CircularProgressIndicator()
                    else
                      CustomLargeBtn(
                        onPressed: () async {
                          if (startDate == null || endDate == null) {
                            Fluttertoast.showToast(
                              msg: "Please select valid dates",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.red,
                              textColor: Colors.white,
                              fontSize: 16.0,
                            );
                            return;
                          }
                          if (exportFormKey.currentState!.validate()) {
                            setState(() => isLoading = true);

                            await prefs.setString(
                                'email', emailController.text);

                            final formattedFromDate =
                                DateFormat('yyyy-MM-dd').format(startDate!);
                            final formattedToDate =
                                DateFormat('yyyy-MM-dd').format(endDate!);

                            final email = emailController.text.trim();
                            final visitorData = {
                              "company_id": societyId,
                              "name": nameController.text,
                              "to_mail": email,
                              "from_date": formattedFromDate,
                              "to_date": formattedToDate,
                              "in_gate": selectedGateName,
                            };

                            try {
                              await remoteDataSource.exportLogs(visitorData);
                              Navigator.pop(context);
                              showSuccessDialog(
                                context: context,
                                title: "Export logs",
                                message: "Visitor logs exported successfully.",
                              );
                            } catch (e) {
                              setState(() => isLoading = false);
                              Fluttertoast.showToast(
                                msg: "Failed to export logs",
                                toastLength: Toast.LENGTH_SHORT,
                                gravity: ToastGravity.BOTTOM,
                                backgroundColor: Colors.red,
                                textColor: Colors.white,
                                fontSize: 16.0,
                              );
                            } finally {
                              setState(() => isLoading = false);
                            }
                          }
                        },
                        text: "Export",
                      ),
                  ],
                ),
              ),
            ),
          );
        });
      },
    );
  }

  void _showErrorDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title, style: const TextStyle(color: Colors.red)),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), // Close dialog
              child: const Text("OK"),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDateField(BuildContext context,
      {required String label, DateTime? date, required String placeholder}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.calendar_today, size: 20),
              const SizedBox(width: 8),
              Text(
                date != null
                    ? DateFormat('MMM dd, yyyy').format(date)
                    : placeholder,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void showSuccessDialog({
    required BuildContext context,
    required String title,
    required String message,
    VoidCallback? onDismiss,
  }) {
    showGeneralDialog(
      context: context,
      pageBuilder: (_, __, ___) => Container(),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );

        return ScaleTransition(
          scale: Tween<double>(begin: 0.5, end: 1.0).animate(curvedAnimation),
          child: FadeTransition(
            opacity:
                Tween<double>(begin: 0.0, end: 1.0).animate(curvedAnimation),
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
              backgroundColor: Theme.of(context).colorScheme.surface,
              elevation: 8,
              title: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.5),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
                )),
                child: Row(
                  children: [
                    TweenAnimationBuilder<double>(
                      duration: const Duration(milliseconds: 1500),
                      tween: Tween<double>(begin: 0, end: 2 * 3.14159),
                      builder: (context, value, child) => Transform.rotate(
                        angle: value,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green.shade600,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ),
                  ],
                ),
              ),
              content: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.5),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.2, 0.8, curve: Curves.easeOutCubic),
                )),
                child: FadeTransition(
                  opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      message,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            // color: Colors.green,
                            height: 1.5,
                          ),
                    ),
                  ),
                ),
              ),
              actions: [
                SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).animate(CurvedAnimation(
                    parent: animation,
                    curve: const Interval(0.3, 0.9, curve: Curves.easeOutCubic),
                  )),
                  child: FadeTransition(
                    opacity: Tween<double>(begin: 0.0, end: 1.0).animate(
                      CurvedAnimation(
                        parent: animation,
                        curve: const Interval(0.3, 0.9, curve: Curves.easeOut),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 8.0, bottom: 8.0),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              Colors.black, // Set the background color to black
                          foregroundColor:
                              Colors.white, // Set the text color to white
                        ),
                        onPressed: () {
                          Navigator.of(context).pop();
                          onDismiss?.call();
                        },
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('OK'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 500),
      barrierDismissible: false,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
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

  // Add a method to update today's counts
  Future<void> _updateTodayLogsCount() async {
    final prefs = await SharedPreferences.getInstance();
    final currentCount = prefs.getInt('todayLogsCount') ?? 0;
    await prefs.setInt('todayLogsCount', currentCount - 1);

    final currentCheckoutCount = prefs.getInt('todayCheckoutLogsCount') ?? 0;
    await prefs.setInt('todayCheckoutLogsCount', currentCheckoutCount + 1);
  }
}

class VisitorLogItem extends StatefulWidget {
  final VisitorLog visitorLog;
  final Function onCheckOut;

  const VisitorLogItem({
    Key? key,
    required this.visitorLog,
    required this.onCheckOut,
  }) : super(key: key);

  @override
  State<VisitorLogItem> createState() => _VisitorLogItemState();
}

class _VisitorLogItemState extends State<VisitorLogItem> {
  final bool _hasCallSupport = true;
  Future<void>? _launched;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    String unitList = '';

    if (widget.visitorLog.visitor_building_assignment != null &&
        widget.visitorLog.visitor_building_assignment!.isNotEmpty) {
      unitList = widget.visitorLog.visitor_building_assignment!
          .expand((assignment) => assignment.unit_id ?? [])
          .map((unit) => unit.toString())
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
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VisitorDetailsScreen(
                      unitList: unitList,
                      visitorLog: widget.visitorLog,
                    ),
                  ),
                );
              },
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 2,
              ),
              leading: CircleAvatar(
                backgroundImage: widget
                        .visitorLog.visitor!.visitor_image!.isNotEmpty
                    ? NetworkImage(
                        widget.visitorLog.visitor!.visitor_image ?? "")
                    : NetworkImage(
                        'https://images.unsplash.com/photo-1731778572747-315c9089bc69?q=80&w=2940&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D'),
                child: widget.visitorLog.visitor!.visitor_image!.isEmpty
                    ? Text(
                        widget.visitorLog.visitor!.name!.isNotEmpty
                            ? widget.visitorLog.visitor!.name![0]
                            : 'G',
                        style: Theme.of(context).textTheme.bodyMedium,
                      )
                    : null,
              ),
              title: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: widget.visitorLog.visitor!.name,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    WidgetSpan(
                      child: widget.visitorLog.visitor_count.toString() != '1'
                          ? Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xffFFB080),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                "+ ${widget.visitorLog.visitor_count.toString()}",
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
                      // TextSpan(
                      //     text: unitList,
                      //     style: Theme.of(context).textTheme.labelSmall),
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
                          child: Text(
                            widget.visitorLog.purpose_sub_category_name != null
                                ? "${widget.visitorLog.purpose_sub_category_name}"
                                : "${widget.visitorLog.visitor_purpose_Category_name}",
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
                onPressed: _hasCallSupport
                    ? () => _launched =
                        _makePhoneCall(widget.visitorLog.visitor!.mobile ?? "")
                    : null,

                // onPressed: () {
                //               log(
                //                 'Calling ${visitorLog.visitor!.mobile}',
                //               );
                //
                //               SnackBar(
                //                 content: Text(
                //                   'Calling ${visitorLog.visitor!.mobile}',
                //                   style: Theme.of(context).textTheme.labelMedium,
                //                 ),
                //                 action: SnackBarAction(
                //                   label: 'Close',
                //                   onPressed: () {
                //                     ScaffoldMessenger.of(context).hideCurrentSnackBar();
                //                   },
                //                 ),
                //               );
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
            Container(
              padding: const EdgeInsets.only(
                  bottom: 14.0, top: 8, left: 12, right: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Tooltip(
                    message: DateFormat('dd-MM-yyyy hh:mm a')
                        .format(widget.visitorLog.visitor_check_in!),
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
                                widget.visitorLog.visitor_check_in!),
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
                  widget.visitorLog.visitor_card_number != null ||
                          widget.visitorLog.carNumber != null
                      ? Container(
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
                              widget.visitorLog.visitor_card_number != null
                                  ? Lottie.asset(
                                      'assets/json/idcard.json',
                                      width: 30,
                                      height: 30,
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      Symbols.car_tag_rounded,
                                      size: 30,
                                      // color: Colors.red, // Optional color for the icon
                                    ),
                              const SizedBox(width: 5),
                              Text(
                                widget.visitorLog.visitor_card_number != null
                                    ? widget.visitorLog.visitor_card_number!
                                    : widget.visitorLog.carNumber ?? 'N/A',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : Spacer(),
                  (widget.visitorLog.visitor_check_out.toString().isEmpty ||
                          widget.visitorLog.visitor_check_out.toString() ==
                              'null')
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: Row(
                                    children: const [
                                      Icon(Icons.warning_amber_rounded,
                                          color: Colors.red),
                                      SizedBox(width: 8),
                                      Text(
                                        'Confirm Checkout',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Are you sure you want to checkout?',
                                        style: TextStyle(fontSize: 16),
                                      ),
                                      SizedBox(height: 8),
                                      Text(
                                        'This action cannot be undone.',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.white,
                                        elevation: 0,
                                        side: BorderSide(
                                            color: Colors.grey[300]!),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                      },
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: Colors.black87,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                      ),
                                      onPressed: () {
                                        Navigator.of(context).pop();
                                        widget.onCheckOut();
                                        // context
                                        //     .read<GatekeeperDashboardBloc>()
                                        //     .add(
                                        //         GatekeeperDashboardInitialEvent());
                                      },
                                      child: Text(
                                        'Checkout',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                  actionsPadding: EdgeInsets.all(16),
                                  actionsAlignment: MainAxisAlignment.end,
                                );
                              },
                            );
                          },
                          child: Text(
                            'Checkout',
                            style:
                                Theme.of(context).textTheme.labelSmall!.merge(
                                      const TextStyle(
                                          color: Colors.white, fontSize: 14),
                                    ),
                          ),
                        )
                      : Tooltip(
                          message: DateFormat('dd-MM-yyyy hh:mm a')
                              .format(widget.visitorLog.visitor_check_out!),
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
                                      widget.visitorLog.visitor_check_out!),
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
