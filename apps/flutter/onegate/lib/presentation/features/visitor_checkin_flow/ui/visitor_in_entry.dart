// ignore_for_file: prefer_const_constructors, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:chips_choice/chips_choice.dart';
import 'package:image_picker/image_picker.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:common_widgets/common_widgets.dart';

class VisitorsInEntry extends StatefulWidget {
  final String selectedValue;
  const VisitorsInEntry({Key? key, required this.selectedValue})
      : super(key: key);

  @override
  State<VisitorsInEntry> createState() => _VisitorsInEntryState();
}

class _VisitorsInEntryState extends State<VisitorsInEntry> {
  late TextEditingController _guestCountController;

  int _guestCount = 1;

  @override
  void initState() {
    super.initState();
    _guestCountController = TextEditingController(text: _guestCount.toString());
  }

  void _incrementGuestCount() {
    setState(() {
      _guestCount++;
      _guestCountController.text = _guestCount.toString();
    });
  }

  void _decrementGuestCount() {
    if (_guestCount > 1) {
      setState(() {
        _guestCount--;
        _guestCountController.text = _guestCount.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitle: '${widget.selectedValue} Entry',
      pageBody: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.selectedValue == 'Cabs')
              Column(
                children: [
                  CustomForm.textField(
                    "Cab Driver Name",
                    hintText: 'Enter Name',
                    textCapitalization: TextCapitalization.words,
                    suffixIcon: IconButton(
                      onPressed: () {},
                      icon: CircleAvatar(
                        backgroundColor: Color(0xffFFEBE6),
                        radius: 20,
                        child: Icon(
                          size: 22,
                          Ionicons.mic_outline,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    focusedColor: Colors.blue,
                  ),
                  CustomForm.textField(
                    focusedColor: Colors.blue,
                    "Cab Number",
                    hintText: 'MH 12 AB 1234',
                    textCapitalization: TextCapitalization.characters,
                    suffixIcon: IconButton(
                      onPressed: () {},
                      icon: CircleAvatar(
                        backgroundColor: Color(0xffFFEBE6),
                        radius: 20,
                        child: Icon(
                          size: 22,
                          Ionicons.mic_outline,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            if (widget.selectedValue == 'Delivery')
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CustomForm.textField(
                    focusedColor: Colors.blue,
                    "Delivery Person Name",
                    hintText: 'Enter Name',
                    textCapitalization: TextCapitalization.words,
                    suffixIcon: IconButton(
                      onPressed: () {},
                      icon: CircleAvatar(
                        backgroundColor: Color(0xffFFEBE6),
                        radius: 20,
                        child: Icon(
                          size: 22,
                          Ionicons.mic_outline,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Select Delivery Company',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  SelectTypeWidget(),
                ],
              ),
            if (widget.selectedValue == 'Guest')
              Column(
                children: [
                  CustomForm.textField(
                    focusedColor: Colors.blue,
                    "Guest Name",
                    hintText: 'Enter Name',
                    textCapitalization: TextCapitalization.words,
                    suffixIcon: IconButton(
                      onPressed: () {},
                      icon: CircleAvatar(
                        backgroundColor: Color(0xffFFEBE6),
                        radius: 20,
                        child: Icon(
                          size: 22,
                          Ionicons.mic_outline,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  CustomForm.textField(
                    focusedColor: Colors.blue,
                    "Coming From",
                    hintText: 'Enter Coming From',
                    textCapitalization: TextCapitalization.characters,
                    suffixIcon: IconButton(
                      onPressed: () {},
                      icon: CircleAvatar(
                        backgroundColor: Color(0xffFFEBE6),
                        radius: 20,
                        child: Icon(
                          size: 22,
                          Ionicons.mic_outline,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  CustomForm.textField("Guest Count",
                      textController: _guestCountController,
                      hintText: 'Guest Count',
                      keyboardType: TextInputType.number,
                      focusedColor: Colors.blue,
                      length: 2, onChanged: (value) {
                    setState(() {
                      _guestCount = int.tryParse(value) ?? 1;
                    });
                  },
                      suffixIcon: ButtonBar(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            onPressed: _incrementGuestCount,
                            icon: Icon(
                              Ionicons.add_circle_outline,
                              size: 32,
                              color: Colors.green,
                            ),
                          ),
                          IconButton(
                            onPressed: _decrementGuestCount,
                            icon: Icon(
                              Ionicons.remove_circle_outline,
                              color: Colors.red,
                              size: 32,
                            ),
                          ),
                        ],
                      )
                      // suffixIcon: IconButton(
                      //   onPressed: () {
                      //     _incrementGuestCount();
                      //   },
                      //   icon: Icon(
                      //     Ionicons.add_circle_outline,
                      //   ),
                      // ),
                      ),
                ],
              ),
            if (widget.selectedValue == 'Staff')
              Column(
                children: [
                  CustomForm.textField(
                    focusedColor: Colors.blue,
                    "Staff Name",
                    hintText: 'Enter Name',
                    textCapitalization: TextCapitalization.words,
                    suffixIcon: IconButton(
                      onPressed: () {},
                      icon: CircleAvatar(
                        backgroundColor: Color(0xffFFEBE6),
                        radius: 20,
                        child: Icon(
                          size: 22,
                          Ionicons.mic_outline,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Select Staff Category',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  SelectTypeWidget(),
                ],
              ),
            if (widget.selectedValue == 'Vendor')
              Column(
                children: [
                  CustomForm.textField(
                    focusedColor: Colors.blue,
                    "Vendor Name",
                    hintText: 'Enter Name',
                    textCapitalization: TextCapitalization.words,
                    suffixIcon: IconButton(
                      onPressed: () {},
                      icon: CircleAvatar(
                        backgroundColor: Color(0xffFFEBE6),
                        radius: 20,
                        child: Icon(
                          size: 22,
                          Ionicons.mic_outline,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Select Vendor Category',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  SelectTypeWidget(),
                ],
              ),
          ],
        ),
      ),
      floatingActionButton: CustomLargeBtn(
        onPressed: () {
          // _captureImageFromCamera();
        },
        text: 'NEXT',
      ),
    );
  }
}

class SelectTypeWidget extends StatefulWidget {
  const SelectTypeWidget({super.key});

  @override
  State<SelectTypeWidget> createState() => _SelectTypeWidgetState();
}

class _SelectTypeWidgetState extends State<SelectTypeWidget> {
  int selectedUserInput = -1;

  final List<String> imagePaths = [
    'assets/images/cab.png',
    'assets/images/cab.png',
    'assets/images/cab.png',
    'assets/images/cab.png',
    'assets/images/cab.png',
    'assets/images/cab.png',
  ];

  final List<String> imageValues = [
    'One',
    'Two',
    'Three',
    'Four',
    'Five',
    'Six',
  ];

  void selectImage(int index) {
    setState(() {
      selectedUserInput = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 3,
      ),
      itemCount: imagePaths.length,
      itemBuilder: (context, index) {
        return GestureDetector(
          onTap: () => selectImage(index),
          child: Container(
            margin: EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: selectedUserInput == index
                  ? Color(0xffFFEBE6)
                  : Colors.transparent,
              border: Border.all(
                color: selectedUserInput == index
                    ? Colors.red
                    : Colors.transparent,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: Image.asset(
                    height: 60,
                    imagePaths[index],
                    fit: BoxFit.cover,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    imageValues[index],
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
