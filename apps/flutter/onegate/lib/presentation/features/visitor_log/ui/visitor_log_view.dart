// ignore_for_file: prefer_const_constructors

import 'dart:developer';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorLog.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
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
import 'package:infinite_scroll_pagination/infinite_scroll_pagination.dart';

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
  static const _pageSize = 15;

  final PagingController<int, VisitorLog> _pagingController =
      PagingController(firstPageKey: 0);

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
    _pagingController.addPageRequestListener((pageKey) {
      _fetchPage(pageKey);
    });
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
        break;
      case "Visitor Out":
        _visitorLogBloc.add(FetchCheckOutLogEvent(Utils.getCurrentTime()));
        break;
    }
    _initializeSocietyId();
    getSelectedGate();
    _searchFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _pagingController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _fetchPage(int pageKey) async {
    try {
      final newItems = await _getVisitorLogsForPage(pageKey);
      final isLastPage = newItems.length < _pageSize;
      if (isLastPage) {
        _pagingController.appendLastPage(newItems);
      } else {
        final nextPageKey = pageKey + newItems.length;
        _pagingController.appendPage(newItems, nextPageKey);
      }
    } catch (error) {
      _pagingController.error = error;
    }
  }

  Future<List<VisitorLog>> _getVisitorLogsForPage(int pageKey) async {
    final state = _visitorLogBloc.state;

    if (state is VisitorLogSuccessState) {
      final allLogs = state.visitorLogs ?? [];
      final filteredLogs = _getFilteredVisitors(allLogs);

      final startIndex = pageKey;
      final endIndex = startIndex + _pageSize;

      if (startIndex >= filteredLogs.length) {
        return [];
      }

      return filteredLogs.sublist(
        startIndex,
        endIndex > filteredLogs.length ? filteredLogs.length : endIndex,
      );
    }
    return [];
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
    return MyScrollView(
      pageBody: BlocConsumer<VisitorLogBloc, VisitorLogState>(
        bloc: _visitorLogBloc,
        listenWhen: (previous, current) => current is VisitorLogActionState,
        buildWhen: (previous, current) => current is! VisitorLogActionState,
        listener: (context, state) {
          if (state is VisitorLogCheckOutSuccessState &&
              state.isCheckOut == true) {
            Fluttertoast.showToast(
              msg: "User Checked Out Successfully",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.green,
              textColor: Colors.white,
            );
          } else if (state is VisitorCheckInLogSuccessState) {
            Fluttertoast.showToast(
              msg: "Visitor Checked In Successfully",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.blue,
              textColor: Colors.white,
            );
          }
        },
        builder: (context, state) {
          if (state is VisitorLogLoadingState) {
            return LoaderView();
          } else if (state is VisitorLogSuccessState) {
            final visitorLogs = state.visitorLogs ?? [];
            final uniqueVisitorLogs = _getUniqueVisitorLogs(visitorLogs);
            final filteredVisitors = _getFilteredVisitors(uniqueVisitorLogs);

            return Container(
                padding: const EdgeInsets.only(bottom: 100),
                height: MediaQuery.of(context).size.height,
                child: Column(children: [
                  _buildSearchField(),
                  if (filteredVisitors.isEmpty)
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.person_search_rounded,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No Visitor Logs Found',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.grey[700],
                                          ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'There are no visitor logs to display',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                ]));
          }
          return Center(child: Text("Unexpected error occurred."));
        },
      ),
      actions: _buildActions(context, []),
      pageTitle: widget.id,
    );
  }

// Utility functions for filtering logs
  List<VisitorLog> _getUniqueVisitorLogs(List<VisitorLog> logs) {
    Set<String> checkInTimes = {};
    return logs.where((log) {
      final checkInTime = log.visitor_check_in?.toIso8601String();
      if (checkInTime != null && !checkInTimes.contains(checkInTime)) {
        checkInTimes.add(checkInTime);
        return true;
      }
      return false;
    }).toList();
  }

  List<VisitorLog> _getFilteredVisitors(List<VisitorLog> logs) {
    if (_searchText == null || _searchText!.isEmpty) {
      return logs; // Return all logs if no search text
    }

    final searchLower = _searchText!.toLowerCase();

    return logs.where((log) {
      final visitorName = log.visitor?.name?.toLowerCase() ?? '';
      final cardNumber = log.visitor_card_number?.toLowerCase() ?? '';
      final unitIds = log.visitor_building_assignment
              ?.expand((assignment) => assignment.unit_id ?? [])
              .map((unit) => unit.toLowerCase())
              .toList() ??
          [];

      return visitorName.contains(searchLower) ||
          cardNumber.contains(searchLower) ||
          unitIds.any((u) => u.contains(searchLower));
    }).toList();
  }

// Widgets for reusable UI components
  List<Widget> _buildActions(BuildContext context, List<VisitorLog> logs) {
    return [
      if (widget.id == "In Out Book")
        GestureDetector(
          onTap: () => _showExportBottomSheet(context, logs),
          child: Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.download_rounded, color: Colors.black),
                    SizedBox(width: 8),
                    Text(
                      'Export',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
    ];
  }

  Widget _buildSearchField() {
    return CustomForm.textField(
      widget.selectedBuilding ?? 'Search',
      focusNode: _searchFocusNode,
      titleColor: Theme.of(context).colorScheme.onSurface,
      hintColor: Theme.of(context).colorScheme.onSurface,
      hintText: 'Search ${widget.id != 'Cards' ? 'visitor' : 'card number'}',
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.search,
      onChanged: (value) {
        setState(() {
          _searchText = value;
        });
        _pagingController.refresh();
      },
      prefixIcon: Icon(Ionicons.search_outline),
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
    );
  }

  Widget _buildNoSearchResults() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.person_off_outlined, size: 48),
          SizedBox(height: 16),
          Text('No such visitors found in log'),
        ],
      ),
    );
  }

  Widget _buildNoItemsFound() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.person_off_outlined, size: 48),
          SizedBox(height: 16),
          Text('No visitors found'),
        ],
      ),
    );
  }

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
                      image: widget.visitorLog.visitor?.visitor_image,
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
                backgroundImage: CachedNetworkImageProvider(
                  widget.visitorLog.visitor?.visitor_image?.isNotEmpty == true
                      ? widget.visitorLog.visitor!.visitor_image!
                      : 'https://images.unsplash.com/photo-1731778572747-315c9089bc69?q=80&w=2940&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D',
                ),
                onBackgroundImageError: (_, __) {
                  // Handle the error and provide a fallback image
                  return;
                },
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
                                      onPressed: () async {
                                        Navigator.of(context).pop();
                                        await widget.onCheckOut();
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
