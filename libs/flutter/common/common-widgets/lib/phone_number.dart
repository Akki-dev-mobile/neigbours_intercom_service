import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:libphonenumber/libphonenumber.dart';
import 'package:email_validator/email_validator.dart';

class CombinedInputField extends StatefulWidget {
  @override
  _CombinedInputFieldState createState() => _CombinedInputFieldState();
}

class _CombinedInputFieldState extends State<CombinedInputField> {
  String selectedCountryCode = 'US'; // Default country code
  TextEditingController inputController = TextEditingController();
  bool isMobile = false;
  bool isValid = false;

  @override
  void initState() {
    super.initState();
    inputController.addListener(() {
      // Check the first character of input to determine if it's a mobile number or an email
      final firstChar = inputController.text.trim().isEmpty
          ? null
          : inputController.text.trim()[0];
      setState(() {
        isMobile = firstChar != null && int.tryParse(firstChar) != null;
      });
    });
  }

  void validateInput() async{
    final input = inputController.text.trim();
    if (isMobile) {
      // Validate mobile number
      final isoCode = selectedCountryCode;
      try {
        final isValidNumber = await PhoneNumberUtil.isValidPhoneNumber(
          phoneNumber: input,
          isoCode: isoCode,
        );
        setState(() {
          isValid = isValidNumber!;
        });
        if (isValidNumber!) {
          // The phone number is valid
          print('Valid Mobile Number: $input');
        } else {
          // The phone number is invalid
          print('Invalid Mobile Number: $input');
        }
      } catch (e) {
        print('Error validating mobile number: $e');
      }
    } else {
      // Validate email using regex
      final isEmailValid = EmailValidator.validate(input);
      setState(() {
        isValid = isEmailValid;
      });
      if (isEmailValid) {
        // The email is valid
        print('Valid Email Address: $input');
      } else {
        // The email is invalid
        print('Invalid Email Address: $input');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            if (isMobile)
              CountryCodePicker(
                onChanged: (CountryCode countryCode) {
                  setState(() {
                    selectedCountryCode = countryCode.code!;
                  });
                },
                initialSelection: 'IN', // Initial selection
                favorite: ['IN'], // Your favorite countries here
              ),
            Expanded(
              child: TextField(
                controller: inputController,
                keyboardType: isMobile
                    ? TextInputType.phone
                    : TextInputType.text, // Use TextInputType.text here
                decoration: InputDecoration(
                  labelText: isMobile ? 'Mobile Number' : 'Email Address',
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
                isMobile ? 'Mobile number is valid' : 'Email address is valid',
                style: TextStyle(color: Colors.green),
              )
            : Text(
                isMobile ? 'Mobile number is invalid' : 'Email address is invalid',
                style: TextStyle(color: Colors.red),
              ),
      ],
    );
  }
}


