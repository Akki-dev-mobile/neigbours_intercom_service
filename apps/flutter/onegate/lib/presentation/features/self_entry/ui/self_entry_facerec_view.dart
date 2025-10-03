import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/domain/entities/visitor/purpose/purpose.dart';
import 'package:flutter_onegate/domain/entities/visitor/visitor.dart';
import 'package:flutter_onegate/presentation/features/self_entry/self_home_view.dart';
import 'package:flutter_onegate/presentation/features/self_entry/ui/self_entry_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/units_selection/ui/unit_selection_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/visitor_in_entry/ui/visitor_in_entry.dart';
import 'package:flutter_onegate/utils/app_urls.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:flutter_onegate/utils/route_tracker.dart';

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
      GateStorage storage = GateStorage();
      await storage.init();
      await storage.saveVisitorImageBase64(_image!);
      print("Image saved successfully!");
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

  int? selectedImageIndex;

  void selectImage(int index) {
    setState(() {
      selectedImageIndex = index;
    });
  }

  List<PurposeCategory1> globalSelectedPurposes = [];

  @override
  void initState() {
    super.initState();
    _pickImage();
    _trackExpressEntryRoute();
  }

  // Track that user is in express entry flow
  Future<void> _trackExpressEntryRoute() async {
    await RouteTracker.saveCurrentRoute(
      'SelfEntryFacerecView',
      isExpressEntry: true,
    );
  }

  Future<void> loadPurposes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPurposes = prefs.getString('selected_purposes');
      if (savedPurposes != null) {
        final decoded = jsonDecode(savedPurposes) as List;
        globalSelectedPurposes =
            decoded.map((e) => PurposeCategory1.fromJson(e)).toList();
      }
      log(globalSelectedPurposes.first.categoryName);
    } catch (e) {
      debugPrint("Failed to load purposes: $e");
    }
  }

  var comingfrom;

  Future<void> selfCheckInOtp(String mobileNumber) async {
    log(mobileNumber);
    try {
      loadPurposes();
      final result =
          await _remoteDataSource.sendOtpForSelfCheckIn(mobileNumber);
      print(result.length);
      if (result['message'] == 'Visitor is already verified') {
        log(result['data'].toString());
        comingfrom = result['data']['coming_from'];

        final visitorData = result['data'];

        final visitor = Visitor(
          id: visitorData['id'],
          name: visitorData['name'] ?? '',
          mobile: visitorData['mobile'] ?? '',
          visitor_image: visitorData['visitor_image'],
        );

        // For existing visitors in Express Entry flow, ALWAYS require member approval
        // Determine default purpose (first available or fallback to Guest)
        PurposeCategory1 defaultPurpose;
        if (globalSelectedPurposes.isNotEmpty) {
          defaultPurpose = globalSelectedPurposes.first;
        } else {
          // Fallback to default Guest purpose
          defaultPurpose = PurposeCategory1(
            categoryId: 1,
            categoryName: "Guest",
            image: null,
          );
        }

        print(
            "DEBUG: Existing visitor detected in Express Entry face recognition flow, proceeding with member approval: ${defaultPurpose.categoryName}");

        // Navigate to visitor information form - approval will be required
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => VisitorsInEntry(
              selfcheckinFlow: true,
              comingfrom: comingfrom,
              searchedVisitor: visitor,
              selectedValue: defaultPurpose,
              mobile: visitorData['mobile'],
              isGatekeeperQRPasscodeEntry: false, // This is self-entry flow
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
          title: Text(AppLocalizations.of(context).enterName),
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
              child: Text(AppLocalizations.of(context).cancel),
            ),
            TextButton(
              onPressed: () {
                if (name.isNotEmpty) {
                  Navigator.of(context).pop();
                  _regImage(name); // Call registration function
                }
              },
              child: Text(AppLocalizations.of(context).submit),
            ),
          ],
        );
      },
    );
  }

  Future<void> _regImage(String name) async {
    if (_image == null) return;

    try {
      final societyid = await GateStorage().getSocietyId();

      final faceRecConfig = await GateStorage().getFaceRecConfig();

      List<String> allowed = faceRecConfig != null
          ? List<String>.from(faceRecConfig['allowed'] ?? [])
          : [];
      if (faceRecConfig != null &&
          faceRecConfig['url'] != null &&
          faceRecConfig['url'] != "" &&
          faceRecConfig['allowed'] != null &&
          societyid != null &&
          allowed.contains(societyid.toString())) {
        String url = faceRecConfig['url'] ?? '';

        final uri = Uri.parse('$url/register-face/');
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
      final societyid = await GateStorage().getSocietyId();

      final faceRecConfig = await GateStorage().getFaceRecConfig();

      List<String> allowed = faceRecConfig != null
          ? List<String>.from(faceRecConfig['allowed'] ?? [])
          : [];

      if (faceRecConfig != null &&
          faceRecConfig['url'] != null &&
          faceRecConfig['url'] != "" &&
          faceRecConfig['allowed'] != null &&
          societyid != null &&
          allowed.contains(societyid.toString())) {
        String facerecUrl = faceRecConfig['url'] ?? '';

        final uri = Uri.parse('$facerecUrl/search-face/');
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
                    ? (jsondata['match_percentage'] > 70)
                        ? jsondata['matched_user']
                        : "No User Found"
                    : "Liveness failed recapture the image")),
          );
          final numericRegex = RegExp(r'^[0-9]+$');

          if (jsondata['liveness_passed'] &&
              numericRegex.hasMatch(jsondata['matched_user'].toString()) &&
              jsondata['matched_user'].toString().length == 10 &&
              jsondata['match_percentage'] > 70) {
            selfCheckInOtp(jsondata['matched_user']);
          } else if (jsondata['liveness_passed'] &&
              jsondata['match_percentage'] < 70) {
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

  Widget _buildPurposeGrid(StateSetter setState, BuildContext context,
      {String? category}) {
    final filteredPurposes = category == null
        ? globalSelectedPurposes
        : globalSelectedPurposes
            .where((purpose) => purpose.categoryName == category)
            .toList();

    return GridView.builder(
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 3,
        crossAxisSpacing: 3,
      ),
      itemCount: filteredPurposes.length,
      itemBuilder: (context, index) {
        final purpose = filteredPurposes[index];

        return GestureDetector(
          onTap: () {
            setState(() {
              selectedImageIndex = index; // Update selection
            });
          },
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
                          imageUrl: purpose.image ?? "",
                          placeholder: (context, url) =>
                              const CircularProgressIndicator(),
                          errorWidget: (context, url, error) => const Icon(
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
                          purpose.categoryName,
                          style: TextStyle(
                            color: selectedImageIndex == index
                                ? const Color(0xffC08261)
                                : Theme.of(context).colorScheme.onSurface,
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
              if (selectedImageIndex == index)
                const Positioned(
                  right: 10,
                  top: 10,
                  child: Icon(
                    size: 20,
                    Icons.check_circle_outline,
                    color: Color(0xffC08261),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool loading = false;
  bool isProcessing = false;
  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return WillPopScope(
      // canPop: true,
      onWillPop: () {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const SelfHomeView()),
          (Route<dynamic> route) => false,
        );
        return Future.value(false);
      },
      child: MyScrollView(
        pageTitleWidget: Container(),
        floatingActionButton: _image != null
            ? Row(
                verticalDirection: VerticalDirection.down,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
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
      ),
    );
  }
}
