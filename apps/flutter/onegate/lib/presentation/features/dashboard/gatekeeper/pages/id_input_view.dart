// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:cached_network_image/cached_network_image.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/visitor_log_repo_impl.dart';
import 'package:flutter_onegate/data/repositories/visitor_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_log_usecae.dart';
import 'package:flutter_onegate/domain/use_cases/visitor_usecase.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/bloc/gatekeeper_dashboard_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:ionicons/ionicons.dart';
import 'package:onegate_client/onegate_client.dart';

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
int _currentIndex = 1;
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
    Future.delayed(Duration(milliseconds: 200), () {
      FocusScope.of(context).requestFocus(_focusNode);
    });
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

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
    mobileController.text = '';
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
          listener: (context, state) {
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
              case OpenPurposeDialogState:
                final dialogState = state as OpenPurposeDialogState;
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
                      purposeCategories: dialogState.purposeCategories!,
                      gatekeeperDashboardBloc: gateDashboardBloc),
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
                mobileController.text = '';
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VisitorsInEntry(
                      selectedValue: navigateToVisitorDetailsState.purpose,
                      searchedVisitor: navigateToVisitorDetailsState.visitor,
                      mobile: navigateToVisitorDetailsState.mobile,
                    ),
                  ),
                );
                break;
            }
          },
          builder: (context, state) {
            return MyScrollView(
              backButtonPressed: () {
                Navigator.pop(context);
              },
              hasBackButton: true,
              pageBody: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 20),
                  Form(
                    key: mobileControllerFormKey,
                    child: CustomForm.textField(
                      titleColor: Theme.of(context).colorScheme.onSurface,
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
                          color: Theme.of(context).colorScheme.surface,
                        ),
                        barrierColor: Theme.of(context)
                            .colorScheme
                            .surface
                            .withOpacity(0.5),
                        closeIcon: Icon(
                          Icons.close,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                        searchDecoration: InputDecoration(
                          prefixIcon: Icon(
                            Icons.search,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          hintText: 'Search',
                          hintStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(
                              style: BorderStyle.solid,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(
                              style: BorderStyle.solid,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        textStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 18,
                        ),
                        dialogTextStyle: TextStyle(
                          color: Theme.of(context).colorScheme.onSurface,
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
                      onChanged: (value) {
                        if (value.length == 10) {
                          gateDashboardBloc.add(GDOnMobileNumberEnteredEvent(
                              mobileController.text));
                        }
                      },
                    ),
                  ),
                ],
              ),
              floatingActionButton: CustomLargeBtn(
                text: 'Next',
                onPressed: () {
                  if (mobileControllerFormKey.currentState!.validate()) {
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
  Visitor? searchedVisitor;
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

  void selectImage(int index) {
    setState(() {
      selectedImageIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.only(
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
            trailing: Icon(
              Ionicons.close_circle_outline,
              color: Colors.red,
              size: 28,
            ),
            onTap: () {
              Navigator.pop(context);
            },
          ),
          SizedBox(height: 10),
          Expanded(
            child: GridView.builder(
              shrinkWrap: true,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 3,
                crossAxisSpacing: 3,
              ),
              itemCount: widget.purposeCategories.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => selectImage(index),
                  child: Stack(
                    children: [
                      Container(
                        height: 250,
                        width: 200,
                        /*padding:
                            EdgeInsets.symmetric(vertical: 7, horizontal: 10),*/
                        margin: EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: selectedImageIndex == index
                              ? Color(0x10C08261)
                              : Colors.transparent,
                          border: Border.all(
                            color: selectedImageIndex == index
                                ? Color(0xffC08261)
                                : Colors.grey,
                            width: selectedImageIndex == index ? 2 : 1,
                          ),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                                  imageUrl: widget
                                      .purposeCategories[index].purpose_img,
                                  placeholder: (context, url) =>
                                      const CircularProgressIndicator(),
                                  errorWidget: (context, url, error) =>
                                      const Icon(
                                    Icons.error,
                                    color: Colors.red,
                                  ),
                                  fadeOutDuration:
                                      const Duration(milliseconds: 300),
                                  fadeInDuration:
                                      const Duration(milliseconds: 300),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  widget.purposeCategories[index]
                                      .purpose_category_name,
                                  style: TextStyle(
                                    color: selectedImageIndex == index
                                        ? Color(0xffC08261)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurface,
                                    fontWeight: selectedImageIndex == index
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      selectedImageIndex == index
                          ? Positioned(
                              right: 10,
                              top: 10,
                              child: Icon(
                                size: 20,
                                Ionicons.checkmark_circle_outline,
                                color: Color(0xffC08261),
                              ),
                            )
                          : SizedBox()
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            margin: EdgeInsets.symmetric(horizontal: 20),
            child: CustomLargeBtn(
              text: 'Next',
              onPressed: () {
                if (searchedVisitor != null) {}
                if (selectedImageIndex != -1) {
                  PurposeCategory selectedValue =
                      widget.purposeCategories[selectedImageIndex];
                  Navigator.pop(
                    context,
                    selectedValue,
                  );
                  widget.gatekeeperDashboardBloc.add(
                      PurposeNextButtonClickedEvent(selectedValue,
                          searchedVisitor, mobileController.text));
                }
              },
            ),
          ),
          SizedBox(height: 10)
        ],
      ),
    );
  }
}
