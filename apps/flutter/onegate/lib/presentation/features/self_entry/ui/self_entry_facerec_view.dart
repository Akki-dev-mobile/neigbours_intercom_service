import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/presentation/features/self_entry/ui/self_entry_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/units_selection/ui/unit_selection_view.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';

class SelfEntryFacerecView extends StatefulWidget {
  const SelfEntryFacerecView({super.key});

  @override
  State<SelfEntryFacerecView> createState() => _SelfEntryFacerecViewState();
}

class _SelfEntryFacerecViewState extends State<SelfEntryFacerecView> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  final RemoteDataSource _remoteDataSource = RemoteDataSource();

  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
    }
  }

  PurposeCategory1 getPurposeCategory1(String? categoryStr) {
    if (categoryStr != null && categoryStr.isNotEmpty) {
      try {
        final Map<String, dynamic> jsonData = json.decode(categoryStr);
        return PurposeCategory1.fromJson(jsonData);
      } catch (e) {
        int catId = int.tryParse(categoryStr) ?? 1;
        return PurposeCategory1(
            categoryId: catId, categoryName: "Category $catId");
      }
    }
    return PurposeCategory1(categoryId: 1, categoryName: "Default Category");
  }

  @override
  void initState() {
    super.initState();
    _pickImage();
  }

  Future<void> selfCheckInOtp(String mobileNumber) async {
    log(mobileNumber);
    try {
      final result =
          await _remoteDataSource.sendOtpForSelfCheckIn(mobileNumber);
      print(result.length);
      if (result['message'] == 'Visitor is already verified') {
        final visitorData = result['data'];
        final visitor = Visitor(
          id: visitorData['id'],
          name: visitorData['name'] ?? '',
          mobile: visitorData['mobile'] ?? '',
          visitor_image: visitorData['visitor_image'],
        );
        // myFluttertoast(
        //     msg: "Visitor is already verified!", backgroundColor: Colors.red);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => UnitSelectionView(
              null,
              visitor: visitor,
              guestname: visitor.name ?? '',
              mobileNumber: visitor.mobile ?? '',
              purposeCategory: getPurposeCategory1(null),
              comingFrom: visitorData['coming_from'] ?? '',
              carNumber: null,
              guestCount: 1,
              isVerified: true,
            ),
          ),
        );
        return;
      }
    } catch (e) {
      print(e.toString());

      myFluttertoast(
          msg: "Error sending OTP. Please try again.${e.toString()}",
          backgroundColor: Colors.red);
    }
  }

  Future<void> _showNameInputDialog() async {
    String name = "";
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Enter Name"),
          content: TextField(
            autofocus: true,
            onChanged: (value) {
              name = value;
            },
            decoration: const InputDecoration(hintText: "Enter your name"),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (name.isNotEmpty) {
                  Navigator.of(context).pop();
                  _regImage(name); // Call registration function
                }
              },
              child: const Text("Submit"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _regImage(String name) async {
    if (_image == null) return;

    try {
      final uri = Uri.parse('http://192.168.1.9:8000/api/register-face/');
      final request = http.MultipartRequest('POST', uri)
        ..fields['name'] = name
        ..files.add(await http.MultipartFile.fromPath('files', _image!.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      print(response.body);

      if (response.statusCode == 200) {
        var jsondata = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jsondata["message"])),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload image: ${response.body}')),
        );
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _uploadImage() async {
    setState(() {
      loading = true;
    });
    if (_image == null) return;

    try {
      final uri = Uri.parse('http://192.168.1.9:8000/api/search-face/');
      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', _image!.path));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      print(response.body);
      if (response.statusCode == 200) {
        var jsondata = json.decode(response.body);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(jsondata['liveness_passed']
                  ? (jsondata['match_percentage'] > 20)
                      ? jsondata['matched_user']
                      : "No User Found"
                  : "Liveness failed recapture the image")),
        );
        final numericRegex = RegExp(r'^[0-9]+$');

        if (jsondata['liveness_passed'] &&
            numericRegex.hasMatch(jsondata['matched_user'].toString()) &&
            jsondata['matched_user'].toString().length == 10 &&
            jsondata['match_percentage'] > 20) {
          selfCheckInOtp(jsondata['matched_user']);
        } else if (jsondata['liveness_passed'] &&
            jsondata['match_percentage'] < 20) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const SelfEntryView()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: ${response.body}')),
        );
      }
    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    setState(() {
      loading = false;
    });
  }

  bool loading = false;
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return MyScrollView(
      floatingActionButton: _image != null
          ? Row(
              verticalDirection: VerticalDirection.down,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _uploadImage,
                  child: loading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.black,
                          ),
                        )
                      : const Icon(
                          Icons.check,
                          color: Colors.black,
                        ),
                ),
                ElevatedButton(
                  onPressed: _pickImage,
                  style:
                      ElevatedButton.styleFrom(backgroundColor: Colors.black),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.refresh,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Container(),
      pageBody: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _image == null
                ? SizedBox(
                    width: size.width,
                    height: size.height * 0.8,
                    child: const Center(child: Text('No image selected.')))
                : ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.file(
                      fit: BoxFit.cover,
                      _image!,
                      height: size.height * 0.7,
                    ),
                  ),
            // const SizedBox(height: 20),
            // ElevatedButton(
            //   onPressed: _pickImage,
            //   child: const Text('Capture Photo'),
            // ),
            // const SizedBox(height: 20),
            // ElevatedButton(
            //   onPressed: _uploadImage,
            //   child: const Text('Upload Photo'),
            // ),
            // ElevatedButton(
            //   onPressed: _showNameInputDialog,
            //   child: const Text('Register Photo'),
            // ),
          ],
        ),
      ),
    );
  }
}
