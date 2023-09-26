// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:cached_network_image/cached_network_image.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:chips_choice/chips_choice.dart';
import 'package:page_transition/page_transition.dart';

import 'package:toggle_switch/toggle_switch.dart';
import 'package:common_widgets/common_widgets.dart';

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

List<String> listPassAlpha = [
  'G',
  'S',
  'A',
];

class _IdInputViewState extends State<IdInputView> {
  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    Future.delayed(Duration(milliseconds: 200), () {
      FocusScope.of(context).requestFocus(_focusNode);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      hasBackButton: true,
      pageBody: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ToggleSwitch(
            cornerRadius: 20.0,
            borderWidth: 0.5,
            minWidth: MediaQuery.of(context).size.width * 0.8,
            minHeight: 50.0,
            fontSize: 18.0,
            changeOnTap: true,
            initialLabelIndex: _currentIndex,
            activeBgColor: [
              Theme.of(context).colorScheme.onBackground,
            ],
            activeFgColor: Theme.of(context).colorScheme.background,
            borderColor: [
              Theme.of(context).colorScheme.onBackground,
            ],
            inactiveBgColor: Theme.of(context).colorScheme.background,
            inactiveFgColor: Theme.of(context).colorScheme.onPrimary,
            totalSwitches: 2,
            labels: _labels,
            onToggle: (index) {
              setState(() {
                _currentIndex = index!;
              });
              print('Switched to: $_currentIndex');
            },
          ),
          SizedBox(height: 20),
          (_currentIndex == 0)
              ? Form(
                  key: mobileControllerFormKey,
                  child: CustomForm.textField(
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
                      barrierColor: Theme.of(context)
                          .colorScheme
                          .background
                          .withOpacity(0.5),
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
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Mobile number is required';
                      } else if (value.length != 10) {
                        return 'Please enter a 10-digit number';
                      }
                      return null;
                    },
                  ),
                )
              : Column(
                  children: [
                    Form(
                      key: passcodeControllerFormKey,
                      child: CustomForm.textField(
                        titleColor: Theme.of(context).colorScheme.onBackground,
                        hintColor: Theme.of(context).colorScheme.onPrimary,
                        "Visitor Passcode",
                        hintText: '123456',
                        textController: passcodeController,
                        textCapitalization: TextCapitalization.characters,
                        length: 6,
                        keyboardType: TextInputType.number,
                        prefixIcon: Padding(
                          padding: EdgeInsets.only(
                            left: 10,
                            right: 20,
                          ),
                          child: CircleAvatar(
                            backgroundColor: Color(0xffFFEBE6),
                            child: Text(
                              selectedPassAlpha ?? 'A',
                              style: TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        suffixIcon: IconButton(
                          onPressed: () {
                            if (passcodeControllerFormKey.currentState!
                                .validate()) {
                              showModalBottomSheet(
                                useSafeArea: true,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    topRight: Radius.circular(20),
                                  ),
                                ),
                                backgroundColor:
                                    Theme.of(context).colorScheme.background,
                                context: context,
                                builder: (context) => ImageGridBottomSheet(),
                              );
                            }
                          },
                          icon: Icon(
                            Symbols.done_rounded,
                            color: Theme.of(context).colorScheme.onBackground,
                          ),
                        ),
                        validator: (value) {
                          if (value!.isEmpty) {
                            return 'Passcode is required';
                          } else if (value.length != 6) {
                            return 'Please enter a 6-digit passcode';
                          }
                          return null;
                        },
                      ),
                    ),
                    ChipsChoice<String>.single(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      spacing: 20,
                      choiceStyle: C2ChipStyle.outlined(
                        borderWidth: 1,
                        color: Colors.grey,
                        selectedStyle: C2ChipStyle.outlined(
                          overlayColor: Color(0x90C08261),
                          color: Color(0xFF0C08261),
                        ),
                      ),
                      choiceCheckmark: true,
                      value: selectedPassAlpha,
                      scrollPhysics: BouncingScrollPhysics(),
                      onChanged: (value) {
                        setState(() {
                          selectedPassAlpha = value;
                        });
                      },
                      choiceItems: C2Choice.listFrom<String, String>(
                        source: listPassAlpha,
                        value: (i, v) => v,
                        label: (i, v) => v,
                      ),
                    ),
                  ],
                ),
        ],
      ),
      floatingActionButton: CustomLargeBtn(
        text: 'Next',
        onPressed: () {
          if (mobileControllerFormKey.currentState!.validate()) {
            showModalBottomSheet(
              useSafeArea: true,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              backgroundColor: Theme.of(context).colorScheme.background,
              context: context,
              builder: (context) => ImageGridBottomSheet(),
            );
          }
        },
      ),
    );
  }
}

class ImageGridBottomSheet extends StatefulWidget {
  @override
  _ImageGridBottomSheetState createState() => _ImageGridBottomSheetState();
}

class _ImageGridBottomSheetState extends State<ImageGridBottomSheet> {
  int selectedImageIndex = 0;
  final List<String> imagePaths = [
    'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/guest_dbd7ea2cb9.png?updated_at=2023-09-08T12:42:09.850Z',
    'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/cab_8ed111c563.png?updated_at=2023-09-08T12:42:09.898Z',
    'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/delivery_boy_4bba1833cc.png?updated_at=2023-09-08T12:42:09.875Z',
    'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/staff_ae83c36d56.png?updated_at=2023-09-08T12:42:09.891Z',
    'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/vendor_f5d3fe1fa3.png?updated_at=2023-09-08T12:42:09.822Z',
  ];

  final List<String> imageValues = [
    'Guest',
    'Cabs',
    'Delivery',
    'Staff',
    'Vendor',
  ];

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
        color: Theme.of(context).colorScheme.background,
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
              itemCount: imagePaths.length,
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
                                  imageUrl: imagePaths[index],
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
                                  imageValues[index],
                                  style: TextStyle(
                                    color: selectedImageIndex == index
                                        ? Color(0xffC08261)
                                        : Theme.of(context)
                                            .colorScheme
                                            .onBackground,
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
                if (selectedImageIndex != -1) {
                  String selectedValue = imageValues[selectedImageIndex];
                  Navigator.pop(context, selectedValue);
                  Navigator.push(
                    context,
                    PageTransition(
                      type: PageTransitionType.rightToLeft,
                      child: VisitorsInEntry(selectedValue: selectedValue),
                    ),
                  );
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
