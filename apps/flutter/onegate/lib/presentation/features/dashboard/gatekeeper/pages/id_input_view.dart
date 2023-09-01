// ignore_for_file: prefer_const_constructors, prefer_const_literals_to_create_immutables

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:chips_choice/chips_choice.dart';
import 'package:page_transition/page_transition.dart';

import 'package:toggle_switch/toggle_switch.dart';
import 'package:common_widgets/common_widgets.dart';

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
String? selectedPassAlpha;

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
            activeBgColor: [Colors.black],
            activeFgColor: Colors.white,
            borderColor: [
              Colors.black,
            ],
            inactiveBgColor: Color.fromARGB(255, 247, 247, 247),
            inactiveFgColor: Colors.black,
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
                    focusNode: _focusNode,
                    "Visitor Mobile Number",
                    hintText: '0123456789',
                    textController: mobileController,
                    isNumber: true,
                    length: 10,
                    suffixIcon: IconButton(
                      onPressed: () {
                        if (mobileControllerFormKey.currentState!.validate()) {
                          showModalBottomSheet(
                            backgroundColor:
                                Theme.of(context).colorScheme.background,
                            context: context,
                            builder: (context) => ImageGridBottomSheet(),
                          );
                        }
                      },
                      icon: Icon(
                        Symbols.done_rounded,
                        color: Colors.black,
                      ),
                    ),
                    validator: (value) {
                      if (value!.isEmpty) {
                        return 'Mobile number is required';
                      } else if (value.length != 10) {
                        return 'Please enter a 10-digit number';
                      }
                      return null;
                    },
                    focusedColor: Colors.blue,
                  ),
                )
              : Column(
                  children: [
                    Form(
                      key: passcodeControllerFormKey,
                      child: CustomForm.textField(
                        "Visitor Passcode",
                        hintText: '123456',
                        textController: passcodeController,
                        textCapitalization: TextCapitalization.characters,
                        length: 6,
                        isNumber: true,
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
                                backgroundColor:
                                    Theme.of(context).colorScheme.background,
                                context: context,
                                builder: (context) => ImageGridBottomSheet(),
                              );
                            }
                          },
                          icon: Icon(
                            Symbols.done_rounded,
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
                        focusedColor: Colors.blue,
                      ),
                    ),
                    ChipsChoice<String>.single(
                      spacing: 20,
                      choiceStyle: C2ChipStyle.filled(
                        color: Color(0xffFFEBE6),
                        foregroundColor: Colors.black,
                        selectedStyle: C2ChipStyle.outlined(
                          color: Colors.red,
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
    );
  }
}

class ImageGridBottomSheet extends StatefulWidget {
  @override
  _ImageGridBottomSheetState createState() => _ImageGridBottomSheetState();
}

class _ImageGridBottomSheetState extends State<ImageGridBottomSheet> {
  int selectedImageIndex = -1;
  final List<String> imagePaths = [
    'assets/images/guest.png',
    'assets/images/cab.png',
    'assets/images/delivery.png',
    'assets/images/staff.png',
    'assets/images/vendor.png',
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
      height: MediaQuery.of(context).size.height * 0.52,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ListTile(
            title: Text(
              'Select Purpose of visit',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
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
                        height: 300,
                        width: 200,
                        /*padding:
                            EdgeInsets.symmetric(vertical: 7, horizontal: 10),*/
                        margin: EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: selectedImageIndex == index
                              ? Color(0xffFFEBE6)
                              : Colors.transparent,
                          border: Border.all(
                            color: selectedImageIndex == index
                                ? Colors.red
                                : Colors.transparent,
                            width: 1,
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
                                child: Image.asset(
                                  height: 60,
                                  imagePaths[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  imageValues[index],
                                  // style: TextStyle(
                                  //   fontWeight: FontWeight.bold,
                                  // ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      selectedImageIndex == index
                          ? Positioned(
                              child: Icon(
                                Ionicons.checkmark_circle_outline,
                                color: Colors.red,
                              ),
                              right: 10,
                              top: 10,
                            )
                          : SizedBox()
                    ],
                  ),
                );
              },
            ),
          ),
          CustomLargeBtn(
            text: 'NEXT',
            onPressed: () {
              if (selectedImageIndex != -1) {
                String selectedValue = imageValues[selectedImageIndex];
                Navigator.pop(context, selectedValue);
              }
            },
          ),
          SizedBox(height: 10)
        ],
      ),
    );
  }
}
