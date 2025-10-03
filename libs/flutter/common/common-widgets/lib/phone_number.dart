// ignore_for_file: prefer_const_constructors

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
// import 'package:libphonenumber/libphonenumber.dart';
import 'package:email_validator/email_validator.dart';

class CombinedInputField extends StatefulWidget {
  const CombinedInputField({super.key});

  @override
  _CombinedInputFieldState createState() => _CombinedInputFieldState();
}

class _CombinedInputFieldState extends State<CombinedInputField> {
  String selectedCountryCode = 'US';
  TextEditingController inputController = TextEditingController();
  bool isMobile = false;
  bool isValid = false;

  @override
  void initState() {
    super.initState();
    inputController.addListener(() {
      final firstChar = inputController.text.trim().isEmpty
          ? null
          : inputController.text.trim()[0];
      setState(() {
        isMobile = firstChar != null && int.tryParse(firstChar) != null;
      });
    });
  }

  void validateInput() async {
    final input = inputController.text.trim();
    if (isMobile) {
      final isoCode = selectedCountryCode;
      try {
        log(
          'Validating mobile number: $input, ISO Code: $isoCode',
          name: 'CombinedInputField',
        );
        // final isValidNumber = await PhoneNumberUtil.isValidPhoneNumber(
        //   phoneNumber: input,
        //   isoCode: isoCode,
        // );
        // setState(() {
        //   isValid = isValidNumber!;
        // });
        // if (isValidNumber!) {
        //   print('Valid Mobile Number: $input');
        // } else {
        //   print('Invalid Mobile Number: $input');
        // }
      } catch (e) {
        print('Error validating mobile number: $e');
      }
    } else {
      final isEmailValid = EmailValidator.validate(input);
      setState(() {
        isValid = isEmailValid;
      });
      if (isEmailValid) {
        print('Valid Email Address: $input');
      } else {
        print('Invalid Email Address: $input');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Row(
            children: [
              if (isMobile)
                Container(
                  height: 50,
                  width: MediaQuery.of(context).size.width * 0.3,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: CountryCodePicker(
                    onChanged: (CountryCode countryCode) {
                      setState(() {
                        selectedCountryCode = countryCode.code!;
                      });
                    },
                    initialSelection: 'IN',
                    favorite: const ['IN'],
                  ),
                ),
              Container(
                padding: EdgeInsets.only(
                  left: isMobile ? 8.0 : 0.0,
                ),
                width: isMobile
                    ? MediaQuery.of(context).size.width * 0.5
                    : MediaQuery.of(context).size.width * 0.8,
                child: TextFormField(
                  controller: inputController,
                  maxLines: 1,
                  keyboardType:
                      isMobile ? TextInputType.phone : TextInputType.text,
                  style: TextStyle(
                    fontSize: 18,
                  ),
                  decoration: InputDecoration(
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 15,
                    ),
                    errorStyle: TextStyle(
                      fontSize: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        style: BorderStyle.solid,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        style: BorderStyle.solid,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(
                        style: BorderStyle.solid,
                        color: const Color(0xffF44336),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.0),
          ElevatedButton(
            onPressed: () {
              validateInput();
            },
            child: Text('Validate Input'),
          ),
          SizedBox(height: 16.0),
          isValid
              ? Text(
                  isMobile
                      ? 'Mobile number is valid'
                      : 'Email address is valid',
                  style: TextStyle(color: Colors.green),
                )
              : Text(
                  isMobile
                      ? 'Mobile number is invalid'
                      : 'Email address is invalid',
                  style: TextStyle(color: Colors.red),
                ),
        ],
      ),
    );
  }
}
