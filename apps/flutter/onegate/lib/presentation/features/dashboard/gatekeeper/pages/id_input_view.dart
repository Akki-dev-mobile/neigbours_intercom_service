// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitorMapper.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/bloc/gatekeeper_dashboard_bloc.dart';
import 'package:flutter_onegate/purposeProvider.dart';
import 'package:flutter_onegate/purpose_mapper.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:ionicons/ionicons.dart';
import 'package:onegate_client/onegate_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../visitor_checkin_flow/visitor_in_entry/ui/visitor_in_entry.dart';

class IdInputView extends StatefulWidget {
  const IdInputView({Key? key}) : super(key: key);

  @override
  State<IdInputView> createState() => _IdInputViewState();
}

late FocusNode _focusNode;
final mobileControllerFormKey = GlobalKey<FormState>();
final passcodeControllerFormKey = GlobalKey<FormState>();
TextEditingController mobileController = TextEditingController();
TextEditingController passcodeController = TextEditingController();
int _currentIndex = 0;
List<String> _labels = ['Mobile', 'Pass Code'];
String? selectedPassAlpha = 'A';
String selectedCountryCode = 'IN';
final isoCode = selectedCountryCode;
Visitor? searchedVisitor;

List<String> listPassAlpha = [
  'G',
  'S',
  'A',
];

class _IdInputViewState extends State<IdInputView> {
  bool isLoading = false;

  void startLoading() {
    setState(() {
      isLoading = true;
    });
  }

  void stopLoading() {
    setState(() {
      isLoading = false;
    });
  }

  @override
  void initState() {
    super.initState();

    _focusNode = FocusNode();

    // Request focus after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FocusScope.of(context).requestFocus(_focusNode);
      mobileController.clear(); // Clear after the build phase
    });

    loadPurposes();
  }

  final gateDashboardBloc = GatekeeperDashboardBloc(
      VisitorUsecase(
        VisitorRepoImpl(
          RemoteDataSource(DioSingleton.instance1, DioSingleton.instance2,
              DioSingleton.instance3),
        ),
      ),
      VisitorLogUsecase(
        VisitorLogRepositoryImpl(
          RemoteDataSource(DioSingleton.instance1, DioSingleton.instance2,
              DioSingleton.instance3),
        ),
      ));
  final provider = PurposeProvider();
  RemoteDataSource remoteDataSource = new RemoteDataSource(
    DioSingleton.instance1,
    DioSingleton.instance2,
    DioSingleton.instance3,
  );

  @override
  void dispose() {
    _currentIndex = 0;
    _focusNode.dispose();
    super.dispose();

    mobileController.text = '';
  }

  List<PurposeCategory> globalSelectedPurposes = [];

  Future<void> loadPurposes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPurposes = prefs.getString('selected_purposes');
      if (savedPurposes != null) {
        final decoded = jsonDecode(savedPurposes) as List;
        globalSelectedPurposes =
            decoded.map((e) => PurposeCategoryMapper.fromJson(e)).toList();
      }
    } catch (e) {
      debugPrint("Failed to load purposes: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        BlocConsumer<GatekeeperDashboardBloc, GatekeeperDashboardState>(
          bloc: gateDashboardBloc,
          listenWhen: (previous, current) =>
              current is GatekeeperDashboardActionState,
          buildWhen: (previous, current) =>
              current is! GatekeeperDashboardActionState,
          listener: (context, state) async {
            if (state is OpenPurposeDialogState) {
              if (globalSelectedPurposes.length == 1) {
                final singlePurpose = globalSelectedPurposes.first;
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VisitorsInEntry(
                      searchedVisitor: searchedVisitor,
                      selectedValue: singlePurpose,
                      mobile: mobileController.text,
                    ),
                  ),
                );
                return; // Exit early
              }
              showModalBottomSheet(
                useSafeArea: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                backgroundColor: Theme.of(context).colorScheme.surface,
                context: context,
                builder: (context) => ImageGridBottomSheet(
                  // Filter purposes to only include "GUEST"
                  purposeCategories: state.purposeCategories!
                      .where((purpose) =>
                          purpose.purpose_category_name.toUpperCase() ==
                          "GUEST")
                      .toList(),
                  gatekeeperDashboardBloc: gateDashboardBloc,
                ),
              );
            }

            switch (state.runtimeType) {
              case GatekeeperDashboardErrorState:
                final errorState = state as GatekeeperDashboardErrorState;
                Fluttertoast.showToast(
                  msg: errorState.message!,
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                  timeInSecForIosWeb: 1,
                  backgroundColor: Colors.red,
                  textColor: Colors.white,
                  fontSize: 16.0,
                );
                break;

              case SaveSearchedVisitorState:
                final saveVisitorState = state as SaveSearchedVisitorState;
                searchedVisitor = saveVisitorState.visitor;
                break;

              case InputPutViewNextClickedState:
                // Example: Set loading state here if needed
                break;

              case NavigateToVisitorDetailsState:
                final navigateToVisitorDetailsState =
                    state as NavigateToVisitorDetailsState;
                // mobileController.text = '';

                // Retrieve and decode the saved purpose
                final prefs = await SharedPreferences.getInstance();
                final jsonString = prefs.getString("dialoguePurpose");
                PurposeCategory? selectedPurpose;
                if (jsonString != null) {
                  final json = jsonDecode(jsonString);
                  selectedPurpose = PurposeCategoryMapper.fromJson(json);
                }

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VisitorsInEntry(
                      searchedVisitor: navigateToVisitorDetailsState.visitor,
                      mobile: mobileController.text,
                      selectedValue: selectedPurpose,
                    ),
                  ),
                );
                break;
            }
          },
          builder: (context, state) {
            return MyScrollView(
              pageTitle: 'Enter Mobile Number',
              backButtonPressed: () {
                Navigator.pop(context);
              },
              hasBackButton: true,
              pageBody: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ToggleSwitch(
                  //   cornerRadius: 20.0,
                  //   borderWidth: 0.5,
                  //   minWidth: MediaQuery.of(context).size.width * 0.8,
                  //   minHeight: 50.0,
                  //   fontSize: 18.0,s
                  //   changeOnTap: true,
                  //   initialLabelIndex: _currentIndex,
                  //   activeBgColor: [
                  //     Theme.of(context).colorScheme.onBackground,
                  //   ],
                  //   activeFgColor: Theme.of(context).colorScheme.background,
                  //   borderColor: [
                  //     Theme.of(context).colorScheme.onBackground,
                  //   ],
                  //   inactiveBgColor: Theme.of(context).colorScheme.background,
                  //   inactiveFgColor: Theme.of(context).colorScheme.onPrimary,
                  //   totalSwitches: 2,
                  //   labels: _labels,
                  //   onToggle: (index) {
                  //     setState(() {
                  //       _currentIndex = index!;
                  //     });
                  //     print('Switched to: $_currentIndex');
                  //   },
                  // ),
                  // SizedBox(height: 20),
                  // (_currentIndex == 0)
                  //     ?
                  Form(
                    key: mobileControllerFormKey,
                    child: CustomForm.textField(
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Mobile number is required';
                        } else if (value.length != 10) {
                          return 'Please enter a 10-digit number';
                        } else if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                          return 'No spaces or special characters allowed';
                        }
                        return null;
                      },
                      titleColor: Theme.of(context).colorScheme.onBackground,
                      hintColor: Theme.of(context).colorScheme.onPrimary,
                      focusNode: _focusNode,
                      "Visitor Mobile Number",
                      hintText: '0123456789',
                      prefixIcon: CountryCodePicker(
                        initialSelection: 'IN',
                        favorite: ['IN'],
                        showFlagMain: true,
                        showFlagDialog: true,
                        boxDecoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.background,
                        ),
                        barrierColor:
                        Theme.of(context).colorScheme.background.withOpacity(0.5),
                        closeIcon: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                        searchDecoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.search,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                          hintText: 'Search',
                          hintStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(
                              style: BorderStyle.solid,
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(
                              style: BorderStyle.solid,
                              color: Theme.of(context).colorScheme.onBackground,
                            ),
                          ),
                        ),
                        textStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 18,
                        ),
                        dialogTextStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                        onChanged: (CountryCode countryCode) {
                          setState(() {
                            selectedCountryCode = countryCode.code!;
                          });
                        },
                      ),
                      textController: mobileController,
                      keyboardType: TextInputType.number,
                      length: 10,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly, // Allow only digits
                      ],
                      onChanged: (value) {
                        if (value.length == 10) {
                          gateDashboardBloc.add(
                            GDOnMobileNumberEnteredEvent(mobileController.text),
                          );
                        }
                      },
                    ),
                  )
                  // : Column(
                  //     children: [
                  //       Form(
                  //         key: passcodeControllerFormKey,
                  //         child: CustomForm.textField(
                  //           titleColor:
                  //               Theme.of(context).colorScheme.onBackground,
                  //           hintColor:
                  //               Theme.of(context).colorScheme.onPrimary,
                  //           "Visitor Passcode",
                  //           hintText: '123456',
                  //           textController: passcodeController,
                  //           textCapitalization:
                  //               TextCapitalization.characters,
                  //           length: 6,
                  //           keyboardType: TextInputType.number,
                  //           prefixIcon: Padding(
                  //             padding: EdgeInsets.only(
                  //               left: 10,
                  //               right: 20,
                  //             ),
                  //             child: CircleAvatar(
                  //               backgroundColor: Colors.blueGrey,
                  //               child: Text(
                  //                 selectedPassAlpha ?? 'A',
                  //                 style: TextStyle(
                  //                   color: Colors.black,
                  //                   fontWeight: FontWeight.bold,
                  //                 ),
                  //               ),
                  //             ),
                  //           ),
                  //           suffixIcon: IconButton(
                  //             onPressed: () {
                  //               if (passcodeControllerFormKey.currentState!
                  //                   .validate()) {
                  //                 // showModalBottomSheet(
                  //                 //   useSafeArea: true,
                  //                 //   shape: RoundedRectangleBorder(
                  //                 //     borderRadius: BorderRadius.only(
                  //                 //       topLeft: Radius.circular(20),
                  //                 //       topRight: Radius.circular(20),
                  //                 //     ),
                  //                 //   ),
                  //                 //   backgroundColor: Theme.of(context)
                  //                 //       .colorScheme
                  //                 //       .background,
                  //                 //   context: context,
                  //                 //   builder: (context) =>
                  //                 //       ImageGridBottomSheet(),
                  //                 // );
                  //               }
                  //             },
                  //             icon: Icon(
                  //               Symbols.done_rounded,
                  //               color: Theme.of(context)
                  //                   .colorScheme
                  //                   .onBackground,
                  //             ),
                  //           ),
                  //           validator: (value) {
                  //             if (value!.isEmpty) {
                  //               return 'Passcode is required';
                  //             } else if (value.length != 6) {
                  //               return 'Please enter a 6-digit passcode';
                  //             }
                  //             return null;
                  //           },
                  //         ),
                  //       ),
                  //       ChipsChoice<String>.single(
                  //         padding: EdgeInsets.symmetric(horizontal: 20),
                  //         spacing: 20,
                  //         choiceStyle: C2ChipStyle.outlined(
                  //           borderWidth: 1,
                  //           color: Colors.grey,
                  //           selectedStyle: C2ChipStyle.outlined(
                  //             overlayColor: Color(0x90C08261),
                  //             color: Color(0xff0c08261),
                  //           ),
                  //         ),
                  //         choiceCheckmark: true,
                  //         value: selectedPassAlpha,
                  //         scrollPhysics: BouncingScrollPhysics(),
                  //         onChanged: (value) {
                  //           setState(() {
                  //             selectedPassAlpha = value;
                  //           });
                  //         },
                  //         choiceItems: C2Choice.listFrom<String, String>(
                  //           source: listPassAlpha,
                  //           value: (i, v) => v,
                  //           label: (i, v) => v,
                  //         ),
                  //       ),
                  //     ],
                  //   ),
                ],
              ),
              floatingActionButton: CustomLargeBtn(
                text: 'Next',
                onPressed: () async {
                  // var passcode = passcodeController.text;
                  //
                  // await remoteDataSource.passcodeVerify(passcode, context);

                  if (mobileControllerFormKey.currentState?.validate() ??
                      false) {
                    gateDashboardBloc.add(InputPutViewNextClickedEvent());
                  }
                },
              ),
            );
          },
        ),
        if (isLoading) const LoaderView(), // LoaderView overlay
      ],
    );
  }
}

class ImageGridBottomSheet extends StatefulWidget {
  final List<PurposeCategory> purposeCategories;
  final GatekeeperDashboardBloc gatekeeperDashboardBloc;
  VisitorMapper? searchedVisitor;

  ImageGridBottomSheet(
      {super.key,
      required this.purposeCategories,
      this.searchedVisitor,
      required this.gatekeeperDashboardBloc});

  @override
  _ImageGridBottomSheetState createState() => _ImageGridBottomSheetState();
}

class _ImageGridBottomSheetState extends State<ImageGridBottomSheet> {
  int selectedImageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSelectedPurposesToGlobal();
  }

  List<PurposeCategory> globalSelectedPurposes = [];

  Future<void> _loadSelectedPurposesToGlobal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString('selected_purposes');

      if (jsonString != null) {
        final jsonList = jsonDecode(jsonString) as List<dynamic>;
        setState(() {
          globalSelectedPurposes = jsonList
              .map((json) => PurposeCategoryMapper.fromJson(json))
              .toList()
              .where((purpose) =>
                  purpose.purpose_category_name.toUpperCase() == "GUEST")
              .toList();
        });
        print("Global selected purposes loaded: $globalSelectedPurposes");
      } else {
        print("No selected purposes found in SharedPreferences.");
      }
    } catch (e) {
      print("Failed to load selected purposes into global variable: $e");
    }
  }

  void selectImage(int index) {
    setState(() {
      selectedImageIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        color: Theme.of(context).colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ListTile(
            title: Text(
              'Select Purpose of visit',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            trailing: const Icon(
              Ionicons.close_circle_outline,
              color: Colors.red,
              size: 28,
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 10),
          Expanded(
            child: globalSelectedPurposes.isEmpty
                ? GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 3,
                      crossAxisSpacing: 3,
                    ),
                    itemCount: widget.purposeCategories.length,
                    itemBuilder: (context, index) {
                      final purpose = widget.purposeCategories[index];
                      return GestureDetector(
                        onTap: () => selectImage(index),
                        child: Stack(
                          children: [
                            Container(
                              height: 250,
                              width: 200,
                              margin: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: selectedImageIndex == index
                                    ? const Color(0x10C08261)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selectedImageIndex == index
                                      ? const Color(0xffC08261)
                                      : Colors.grey,
                                  width: selectedImageIndex == index ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: CachedNetworkImage(
                                        maxHeightDiskCache: 90,
                                        maxWidthDiskCache: 90,
                                        height: 60,
                                        width: 60,
                                        fit: BoxFit.cover,
                                        imageUrl: purpose.purpose_img,
                                        placeholder: (context, url) =>
                                            const CircularProgressIndicator(),
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                          Icons.error,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        purpose.purpose_category_name,
                                        style: TextStyle(
                                          color: selectedImageIndex == index
                                              ? const Color(0xffC08261)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                          fontWeight:
                                              selectedImageIndex == index
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selectedImageIndex == index)
                              const Positioned(
                                right: 10,
                                top: 10,
                                child: Icon(
                                  size: 20,
                                  Ionicons.checkmark_circle_outline,
                                  color: Color(0xffC08261),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 3,
                      crossAxisSpacing: 3,
                    ),
                    itemCount: globalSelectedPurposes.length,
                    itemBuilder: (context, index) {
                      final purpose = globalSelectedPurposes[index];
                      return GestureDetector(
                        onTap: () => selectImage(index),
                        child: Stack(
                          children: [
                            Container(
                              height: 250,
                              width: 200,
                              margin: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                color: selectedImageIndex == index
                                    ? const Color(0x10C08261)
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selectedImageIndex == index
                                      ? const Color(0xffC08261)
                                      : Colors.grey,
                                  width: selectedImageIndex == index ? 2 : 1,
                                ),
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 7),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(15),
                                      child: CachedNetworkImage(
                                        maxHeightDiskCache: 90,
                                        maxWidthDiskCache: 90,
                                        height: 60,
                                        width: 60,
                                        fit: BoxFit.cover,
                                        imageUrl: purpose.purpose_img,
                                        placeholder: (context, url) =>
                                            const CircularProgressIndicator(),
                                        errorWidget: (context, url, error) =>
                                            const Icon(
                                          Icons.error,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        purpose.purpose_category_name,
                                        style: TextStyle(
                                          color: selectedImageIndex == index
                                              ? const Color(0xffC08261)
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onSurface,
                                          fontWeight:
                                              selectedImageIndex == index
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selectedImageIndex == index)
                              const Positioned(
                                right: 10,
                                top: 10,
                                child: Icon(
                                  size: 20,
                                  Ionicons.checkmark_circle_outline,
                                  color: Color(0xffC08261),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            child: CustomLargeBtn(
              text: 'Next',
              onPressed: () async {
                if (selectedImageIndex != -1) {
                  final selectedValue = globalSelectedPurposes.length == 0
                      ? widget.purposeCategories[selectedImageIndex]
                      : globalSelectedPurposes[selectedImageIndex];
                  Navigator.pop(
                    context,
                    selectedValue,
                  );

                  final dialogue = await SharedPreferences.getInstance();
                  await dialogue.setString(
                    "dialoguePurpose",
                    jsonEncode(selectedValue.toJson()),
                  );

                  widget.gatekeeperDashboardBloc.add(
                    PurposeNextButtonClickedEvent(
                      selectedValue,
                      searchedVisitor,
                      mobileController.text,
                    ),
                  );
                }
              },
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
