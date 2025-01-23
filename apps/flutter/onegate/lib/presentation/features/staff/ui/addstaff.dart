import 'dart:developer';
import 'dart:io';

import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/staff/ui/staff_home_view.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../dio_setup.dart';

class AddStaff extends StatefulWidget {
  const AddStaff({super.key});

  @override
  State<AddStaff> createState() => _AddStaffState();
}

class _AddStaffState extends State<AddStaff> {
  final RemoteDataSource _remoteDataSource = RemoteDataSource(
    DioSingleton.instance1,
    DioSingleton.instance2,
    DioSingleton.instance3,
  );

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  String _selectedCategory = "";
  String _selectedCategoryValue = "";
  DateTime? _selectedDate;
  XFile? _image;
  String _selectedGender = '';
  String selectedCountryCodeSE = 'IN';
  late FocusNode _mobileFocusNode;
  XFile? _idProofImage;

  String _selectedIdProof = 'Aadhar Card';

  final _formKey = GlobalKey<FormState>();

  final List<String> qualifications = [
    'High School Diploma',
    'Associate Degree',
    'Bachelor\'s Degree',
    'Master\'s Degree',
    'Doctorate',
    'Professional Certification',
  ];
  String _selectedQualification = 'Bachelor\'s Degree';

  static Map<String, String> categories = {};

  final List<String> idProofs = [
    "Aadhar Card",
    "Passport",
    "Driving License",
    "Voter ID",
    "PAN Card",
  ];

  @override
  void initState() {
    super.initState();
    _mobileFocusNode = FocusNode();
    if (!qualifications.contains(_selectedQualification)) {
      _selectedQualification = qualifications.first;
    }
    _fetchCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _mobileFocusNode.dispose();
    _idNumberController.dispose();
    addressController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await _remoteDataSource.fetchStaffCategory();
      final data = response['data'];

      setState(() {
        categories = Map<String, String>.fromIterable(
          data,
          key: (item) => item['id'].toString(),
          value: (item) => item['category'],
        );

        if (categories.isNotEmpty) {
          _selectedCategory = categories.keys.first;
        }
      });
      print('Categories fetched successfully');
    } catch (e) {
      debugPrint('Error fetching categories: $e');
    }
  }

  Future<void> _openCamera({required bool isIdProof}) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? capturedImage = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (capturedImage != null) {
        setState(() {
          if (isIdProof) {
            _idProofImage = capturedImage;
          } else {
            _image = capturedImage;
          }
        });
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
      Fluttertoast.showToast(
        msg: "Failed to capture images",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<void> _selectDateOfBirth() async {
    final DateTime currentDate = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(currentDate.year - 18),
      firstDate: DateTime(1900),
      lastDate: currentDate,
      helpText: 'Select Date of Birth',
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).colorScheme.onSurface,
              onPrimary: Theme.of(context).colorScheme.surface,
              surface: Theme.of(context).colorScheme.surface,
              onSurface: Theme.of(context).colorScheme.onSurface,
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _uploadImages() async {
    try {
      if (_image == null || _idProofImage == null) {
        throw Exception("Please select both profile and ID proof images");
      }

      final File profileFile = File(_image!.path);
      final File idProofFile = File(_idProofImage!.path);

      if (!await profileFile.exists() || !await idProofFile.exists()) {
        throw Exception("One or both image files are missing");
      }

      final profileImageResponse =
          await _remoteDataSource.uploadStaffImages(profileFile, 1);
      final idProofImageResponse =
          await _remoteDataSource.uploadStaffImages(idProofFile, 1);

      if (profileImageResponse?['statusCode'] == 200 &&
          idProofImageResponse?['statusCode'] == 200) {
        final profileImageUrl = profileImageResponse!['url'];
        final idProofImageUrl = idProofImageResponse!['url'];

        // Show confirmation dialog with image URLs
        _showConfirmationDialog(profileImageUrl, idProofImageUrl);
      } else {
        throw Exception("Image upload failed with non-200 status");
      }
    } catch (e) {
      debugPrint('Error uploading images: $e');
      Fluttertoast.showToast(
        msg: "Failed to upload images: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  void _showConfirmationDialog(String profileImageUrl, String idProofImageUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Confirm Action',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          content: const Text('Do you want to add this staff member?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close dialog
                await _submitStaffData(profileImageUrl, idProofImageUrl);
              },
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitStaffData(
      String profileImageUrl, String idProofImageUrl) async {
    try {
      final staffData = {
        "name": _nameController.text.trim(),
        "email": _emailController.text.trim(),
        "phone": _phoneController.text,
        "countryCode": selectedCountryCodeSE,
        "dateOfBirth": _selectedDate?.toIso8601String(),
        "category": _selectedCategory,
        "categoryValue": _selectedCategoryValue,
        "gender": _selectedGender,
        "qualification": _selectedQualification,
        "idProofType": _selectedIdProof,
        "idProofNumber": _idNumberController.text.trim(),
        "address": addressController.text.trim(),
        "idProofImageUrl": idProofImageUrl,
        "profileImageUrl": profileImageUrl,
      };

      log('Submitting staff data: $staffData');
      final response = await _remoteDataSource.addStaff(staffData);

      if (response != null) {
        Fluttertoast.showToast(
          msg: "Staff added successfully",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );

        // Navigate to the staff list page
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => StaffScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error adding staff: $e');
      Fluttertoast.showToast(
        msg: "Failed to add staff: $e",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitle: "Create Staff",
      pageBody: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Profile Image and Form
          // ... (same as before)
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: CustomLargeBtn(
        onPressed: () async {
          if (_image != null && _idProofImage != null) {
            await _uploadImages(); // Upload images first
          } else {
            Fluttertoast.showToast(
              msg: "Please select both images",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              backgroundColor: Colors.red,
              textColor: Colors.white,
              fontSize: 16.0,
            );
          }
        },
        text: "Add",
      ),
    );
  }
}
