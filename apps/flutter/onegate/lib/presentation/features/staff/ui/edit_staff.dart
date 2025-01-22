// edit_staff.dart

import 'dart:developer';
import 'dart:io';

import 'package:common_widgets/common_widgets.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onegate/presentation/features/staff/ui/staff_list_widget.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../data/datasources/remote_datasource.dart';
import '../../../../dio_setup.dart';
import '../model/staff_model.dart';

class EditStaff extends StatefulWidget {
  final Staff staff;

  const EditStaff({
    Key? key,
    required this.staff,
  }) : super(key: key);

  @override
  State<EditStaff> createState() => _EditStaffState();
}

class _EditStaffState extends State<EditStaff> {
  final RemoteDataSource _remoteDataSource = RemoteDataSource(
    DioSingleton.instance1,
    DioSingleton.instance2,
    DioSingleton.instance3,
  );

  // TextEditingControllers
  late TextEditingController _nameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;
  late TextEditingController _idNumberController;
  late TextEditingController _addressController;

  // FocusNode
  late FocusNode _mobileFocusNode;

  // Dropdown values
  String _selectedCategory = "";
  String _selectedCategoryValue = "";
  String _selectedGender = '';
  String _selectedQualification = 'Bachelor\'s Degree';
  String _selectedIdProof = 'Aadhar Card';
  String _dob = '';

  // Date & Images
  DateTime? _selectedDate;
  XFile? _newProfileImage;
  XFile? _newIdProofImage;
  XFile? _image;

  // Predefined lists/maps
  static Map<String, String> categories = {};
  final List<String> qualifications = [
    'High School Diploma',
    'Associate Degree',
    'Bachelor\'s Degree',
    'Master\'s Degree',
    'Doctorate',
    'Professional Certification',
  ];
  final List<String> idProofs = [
    "Aadhar Card",
    "Passport",
    "Driving License",
    "Voter ID",
    "PAN Card",
  ];

  final _formKey = GlobalKey<FormState>();
  String selectedCountryCodeSE = 'IN';
  late int _staffId = 0;

  @override
  void initState() {
    super.initState();
    print("mydataaaaaaaa ${widget.staff}");

    _nameController = TextEditingController(text: widget.staff.name);
    _emailController = TextEditingController(text: widget.staff.email);
    _phoneController = TextEditingController(text: widget.staff.phone);
    _idNumberController =
        TextEditingController(text: widget.staff.idProofNumber);

    print("Staff ID: ${widget.staff.category}");
    _addressController = TextEditingController(text: widget.staff.address);
    _dob = widget.staff.dateOfBirth.toString();

    _selectedDate = widget.staff.dateOfBirth; // Initialize DOB

    _selectedCategory = widget.staff.category;
    _selectedCategoryValue = widget.staff.categoryValue;

    log("mydataaaaaaaa $_selectedCategory");
    log("mydataaaaaaaa value $_selectedCategoryValue");

    _mobileFocusNode = FocusNode();

    // Set qualification
    _selectedQualification = qualifications.contains(widget.staff.qualification)
        ? widget.staff.qualification
        : qualifications.first;

    _selectedIdProof = widget.staff.idProofType;
    selectedCountryCodeSE = widget.staff.countryCode;

    // Set gender
    _selectedGender = widget.staff.gender;

    _fetchCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _mobileFocusNode.dispose();
    _idNumberController.dispose();
    _addressController.dispose();

    super.dispose();
  }

  List<TextInputFormatter> _getInputFormatters(String idProofType) {
    switch (idProofType) {
      case 'Aadhar Card':
        return [
          LengthLimitingTextInputFormatter(12), // Limit input to 12 digits
          FilteringTextInputFormatter.digitsOnly, // Allow only digits
        ];
      case 'Passport':
        return [
          LengthLimitingTextInputFormatter(9),
          // Limit input to 9 characters
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          // Allow alphanumeric
        ];
      case 'Driving License':
        return [
          LengthLimitingTextInputFormatter(16),
          // Adjust as per requirement
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
          // Allow alphanumeric
        ];
      case 'Voter ID':
        return [
          LengthLimitingTextInputFormatter(10),
          // Limit to 10 characters
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z\d]')),
          // Allow alphanumeric
        ];
      case 'PAN Card':
        return [
          LengthLimitingTextInputFormatter(10),
          // Limit to 10 characters
          FilteringTextInputFormatter.allow(RegExp(r'[A-Z\d]')),
          // Allow uppercase letters and digits
        ];
      default:
        return [];
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await _remoteDataSource.fetchStaffCategory();
      final data = response['data'];

      setState(() {
        categories = {
          for (var item in data) item['id'].toString(): item['category']
        };

        print("mydataaaaaaaa $categories ");

        if (categories.isNotEmpty) {
          print("mycategories if1 $_selectedCategoryValue ");
          if (categories.containsKey(_selectedCategory)) {
            _selectedCategoryValue = categories[_selectedCategory]!;
            print("mycategories if2 $_selectedCategoryValue ");
          } else {
            // Set to the first available category if the prefilled one is not found
            _selectedCategory = categories.keys.first;
            _selectedCategoryValue = categories[_selectedCategory]!;

            print(
                "categories else1 $_selectedCategoryValue : $_selectedCategory");
          }
        } else {
          _selectedCategory = '';
          _selectedCategoryValue = '';
          print(
              "categories else2 $_selectedCategoryValue : $_selectedCategory");
        }
      });
      log('Categories fetched successfully');
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      Fluttertoast.showToast(
        msg: "Failed to load categories",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  Future<dynamic> _openCamera({required bool isIdProof}) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? capturedImage = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      );

      if (capturedImage != null) {
        setState(() {
          if (isIdProof) {
            _newIdProofImage = capturedImage;
          } else {
            _newProfileImage = capturedImage;
          }
        });
      }
    } catch (e) {
      debugPrint('Error capturing image: $e');
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Failed to capture image",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
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

  Future<void> _showConfirmationDialog(
      BuildContext context, File profileImage, File idProofImage) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Confirm Upload'),
          content: const Text('Do you want to upload the selected images?'),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(
                'Confirm',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              onPressed: () async {
                Navigator.of(context).pop();
                await _uploadImages(profileImage, idProofImage);
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _uploadImages(File profileImage, File idProofImage) async {
    try {
      final int companyId = 1;
      final profileImageResponse =
          await _remoteDataSource.uploadStaffImages(profileImage, companyId);
      final idProofImageResponse =
          await _remoteDataSource.uploadStaffImages(idProofImage, companyId);

      if (profileImageResponse != null && idProofImageResponse != null) {
        final profileImageUrl = profileImageResponse['url'];
        final idProofImageUrl = idProofImageResponse['url'];

        Fluttertoast.showToast(
          msg: "Images uploaded successfully",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        _updateStaffData(profileImageUrl, idProofImageUrl);
      } else {
        throw Exception('Failed to upload images');
      }
    } catch (e) {
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
    }
  }

  Future<void> _updateStaffData(
    String? profileImageUrl,
    String? idProofImageUrl,
  ) async {
    try {
      final staffData = {
        "id": _staffId,
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
        "address": _addressController.text.trim(),
        "profileImageUrl": profileImageUrl ?? widget.staff.profileImageUrl,
        "idProofImageUrl": idProofImageUrl ?? widget.staff.idProofImageUrl,
      };

      log('Updating staff data: $staffData');

      final response =
          await _remoteDataSource.editStaff(widget.staff.id, staffData);

      if (mounted &&
          response != null &&
          response is Response &&
          response.statusCode == 200) {
        // Navigate to StaffListWidget after successful update
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
              builder: (context) => const StaffListWidget(staffList: [])),
          (Route<dynamic> route) => false,
        );

        Fluttertoast.showToast(
          msg: "Staff updated successfully",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      } else {
        log('Error response: ${response?.data}');
        Fluttertoast.showToast(
          msg: "Failed to update staff: ${response?.data}",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
      }
    } catch (e) {
      debugPrint('Error updating staff: $e');

      if (mounted) {
        String errorMessage = e.toString();

        if (errorMessage.contains("Phone number is required")) {
          errorMessage = "Please enter a valid phone number";
        }

        debugPrint('Error : $errorMessage');

        // Fluttertoast.showToast(
        //   msg: "Error: $errorMessage",
        //   toastLength: Toast.LENGTH_SHORT,
        //   gravity: ToastGravity.BOTTOM,
        //   backgroundColor: Colors.red,
        //   textColor: Colors.white,
        //   fontSize: 16.0,
        // );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please select a gender",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    if (_selectedDate == null) {
      Fluttertoast.showToast(
        msg: "Please select date of birth",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    if (_selectedCategory.isEmpty) {
      Fluttertoast.showToast(
        msg: "Please select a category",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    try {
      if (_newIdProofImage != null &&
          _newIdProofImage!.path.isNotEmpty &&
          _newProfileImage != null &&
          _newProfileImage!.path.isNotEmpty) {
        final idProofFile = File(_newIdProofImage!.path);
        final profileFile = File(_newProfileImage!.path);

        if (await idProofFile.exists() && await profileFile.exists()) {
          _showConfirmationDialog(context, profileFile, idProofFile);
        } else {
          throw Exception('One or both image files not found');
        }
      } else if (_newIdProofImage != null &&
          _newIdProofImage!.path.isNotEmpty &&
          (_newProfileImage == null || _newProfileImage!.path.isEmpty)) {
        final idProofFile = File(_newIdProofImage!.path);
        if (await idProofFile.exists()) {
          _showConfirmationDialog(
              context, File(widget.staff.profileImageUrl), idProofFile);
        } else {
          throw Exception('ID Proof image file not found');
        }
      } else if (_newProfileImage != null &&
          _newProfileImage!.path.isNotEmpty &&
          (_newIdProofImage == null || _newIdProofImage!.path.isEmpty)) {
        final profileFile = File(_newProfileImage!.path);
        if (await profileFile.exists()) {
          _showConfirmationDialog(
              context, profileFile, File(widget.staff.idProofImageUrl));
        } else {
          throw Exception('Profile image file not found');
        }
      } else {
        _updateStaffData(null, null);
      }
    } catch (e) {
      debugPrint('Error: $e');
      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
    }
  }

  Widget _buildGenderSelection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Gender',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Radio<String>(
                fillColor: WidgetStateProperty.all(Colors.red),
                value: 'M',
                groupValue: _selectedGender,
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _selectedGender = value;
                    });
                  }
                },
              ),
              const Text('Male'),
              const SizedBox(width: 20),
              Radio<String>(
                fillColor: WidgetStateProperty.all(Colors.red),
                value: 'F',
                groupValue: _selectedGender,
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _selectedGender = value;
                    });
                  }
                },
              ),
              const Text('Female'),
              const SizedBox(width: 20),
              Radio<String>(
                fillColor: WidgetStateProperty.all(Colors.red),
                value: 'O',
                groupValue: _selectedGender,
                onChanged: (String? value) {
                  if (value != null) {
                    setState(() {
                      _selectedGender = value;
                    });
                  }
                },
              ),
              const Text('Other'),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitle: "Edit Staff",
      pageBody: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Profile Image
          SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                  radius: 80,
                  backgroundColor: Theme.of(context).colorScheme.onSurface,
                  backgroundImage: _newProfileImage != null
                      ? FileImage(File(_newProfileImage!.path))
                      : (widget.staff.profileImageUrl.isNotEmpty
                              ? NetworkImage(widget.staff.profileImageUrl)
                              : const NetworkImage(
                                  "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_960_720.png"))
                          as ImageProvider,
                ),
                Positioned(
                  bottom: 50,
                  right: 90,
                  child: InkWell(
                    onTap: () => _openCamera(isIdProof: false),
                    child: CircleAvatar(
                      radius: 20,
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Form
          Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Details',
                  style: Theme.of(context).textTheme.displaySmall,
                ),
                const SizedBox(height: 20),

                // Name
                CustomForm.textField(
                  "Name",
                  textController: _nameController,
                  titleColor: Colors.black,
                  hintColor: Colors.grey,
                  hintText: "Enter Name",
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter a name';
                    }
                    return null;
                  },
                ),

                // Gender
                _buildGenderSelection(),

                // Mobile Number
                CustomForm.textField(
                  "Mobile Number",
                  focusNode: _mobileFocusNode,
                  textController: _phoneController,
                  hintText: "0123456789",
                  titleColor: Theme.of(context).colorScheme.onBackground,
                  hintColor: Theme.of(context).colorScheme.onPrimary,
                  prefixIcon: CountryCodePicker(
                    initialSelection: selectedCountryCodeSE,
                    favorite: const ['IN'],
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
                    ),
                    textStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onBackground,
                      fontSize: 18,
                    ),
                    onChanged: (countryCode) {
                      setState(() {
                        selectedCountryCodeSE = countryCode.code!;
                      });
                    },
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        _mobileFocusNode.unfocus();
                      });
                    },
                    icon: const CircleAvatar(
                      radius: 20,
                      child: Icon(
                        size: 22,
                        Symbols.done,
                        color: Colors.black,
                      ),
                    ),
                  ),
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

                // Email
                CustomForm.textField(
                  "Email",
                  textController: _emailController,
                  hintText: "Enter Email",
                  titleColor: Colors.black,
                  hintColor: Colors.grey,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value!.isEmpty) {
                      return 'Please enter an email';
                    }
                    return null;
                  },
                ),

                // DOB
                CustomForm.textField(
                  "Date of Birth",
                  titleColor: Colors.black,
                  hintColor: Colors.grey,
                  hintText: _dob,
                  textController: TextEditingController(
                    text: _selectedDate != null
                        ? "${_selectedDate!.day.toString().padLeft(2, '0')}/"
                            "${_selectedDate!.month.toString().padLeft(2, '0')}/"
                            "${_selectedDate!.year}"
                        : "",
                  ),
                  isReadOnly: true,
                  validator: (value) {
                    if (_selectedDate == null) {
                      return 'Please select date of birth';
                    }
                    return null;
                  },
                  suffixIcon: IconButton(
                    onPressed: _selectDateOfBirth,
                    icon: const Icon(Icons.calendar_today),
                  ),
                ),

                // Category
                CustomDropdown(
                  title: "Category",
                  hintText: "Select Category",
                  items: categories.values.toSet().toList(),
                  selectedItem: _selectedCategoryValue,
                  // Use prefilled value

                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = categories.entries
                            .firstWhere((entry) => entry.value == newValue)
                            .key;
                        _selectedCategoryValue = newValue;
                      });
                    }
                  },
                ),

                // Qualification
                CustomDropdown(
                  title: "Qualification",
                  hintText: "Select Qualification",
                  initialValue: _selectedQualification,
                  items: qualifications,
                  selectedItem: qualifications.contains(_selectedQualification)
                      ? _selectedQualification
                      : null,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedQualification = newValue;
                      });
                    }
                  },
                ),

                // ID Proof
                CustomDropdown(
                  title: "ID Proof",
                  hintText: "Select ID Proof",
                  items: idProofs,
                  initialValue: idProofs.contains(_selectedIdProof)
                      ? _selectedIdProof
                      : idProofs.first,
                  // Ensure valid initial value
                  selectedItem: idProofs.contains(_selectedIdProof)
                      ? _selectedIdProof
                      : null,
                  // Validate selected value
                  onChanged: (String? newValue) {
                    if (newValue != null && newValue.isNotEmpty) {
                      setState(() {
                        _selectedIdProof = newValue;
                      });
                    }
                  },
                  titleColor: null,
                ),

                // ID Proof Number + camera icon
                CustomForm.textField(
                  _selectedIdProof,
                  titleColor: Colors.black,
                  hintColor: Colors.grey,
                  hintText: "Enter ID ${_selectedIdProof}",
                  textController: _idNumberController,
                  inputFormatters: _getInputFormatters(_selectedIdProof),
                  // Apply input formatters
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter an ID proof number';
                    }
                    final input = value!.trim();

                    switch (_selectedIdProof) {
                      case 'Aadhar Card':
                        if (!RegExp(r'^\d{12}$').hasMatch(input)) {
                          return 'Please enter a valid 12-digit Aadhaar number';
                        }
                        break;
                      case 'Passport':
                        if (input.length < 8 ||
                            input.length > 9 ||
                            !RegExp(r'^[A-Za-z0-9]+$').hasMatch(input)) {
                          return 'Please enter a valid Passport number (8-9 alphanumeric characters)';
                        }
                        break;
                      case 'Driving License':
                        if (input.length < 5) {
                          return 'Please enter a valid Driving License number';
                        }
                        break;
                      case 'Voter ID':
                        if (!RegExp(r'^[A-Za-z]{3}\d{7}$').hasMatch(input)) {
                          return 'Please enter a valid Voter ID (e.g., ABC1234567)';
                        }
                        break;
                      case 'PAN Card':
                        if (!RegExp(r'^[A-Z]{5}\d{4}[A-Z]$').hasMatch(input)) {
                          return 'Please enter a valid PAN card number (e.g., ABCDE1234F)';
                        }
                        break;
                      default:
                        break;
                    }
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: () => _openCamera(isIdProof: true),
                  ),
                  counterText: "Upload ID Proof",
                ),

                SizedBox(
                  height: 10,
                ),
                if ((_newIdProofImage != null &&
                    _newIdProofImage!.path.isNotEmpty)) ...[
                  Text(
                    "Preview Images",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 5),
                  Container(
                    // decoration: BoxDecoration(
                    //   border: Border.all(
                    //     color: Theme.of(context).colorScheme.onSurface,
                    //   ),
                    //   borderRadius: BorderRadius.circular(15),
                    // ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        // Profile Image Container
                        // if (_newProfileImage != null &&
                        //     _newProfileImage!.path.isNotEmpty) ...[
                        //   Container(
                        //     height: 120,
                        //     padding: const EdgeInsets.only(top: 8.0),
                        //     child: Stack(
                        //       alignment: Alignment.topRight,
                        //       children: [
                        //         Image.file(
                        //           File(_newProfileImage!.path),
                        //           width: 100,
                        //           height: 100,
                        //           fit: BoxFit.cover,
                        //         ),
                        //         Positioned(
                        //           right: 0,
                        //           top: 0,
                        //           child: GestureDetector(
                        //             onTap: () {
                        //               setState(() {
                        //                 _newProfileImage = null;
                        //               });
                        //             },
                        //             child: Container(
                        //               decoration: BoxDecoration(
                        //                 shape: BoxShape.circle,
                        //                 color: Colors.redAccent,
                        //               ),
                        //               child: const Icon(
                        //                 Icons.close,
                        //                 color: Colors.white,
                        //                 size: 20,
                        //               ),
                        //             ),
                        //           ),
                        //         ),
                        //       ],
                        //     ),
                        //   ),
                        // ],

                        // ID Proof Image Container
                        if (_newIdProofImage != null &&
                            _newIdProofImage!.path.isNotEmpty) ...[
                          Container(
                            height: 120,
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Stack(
                              alignment: Alignment.topRight,
                              children: [
                                Image.file(
                                  File(_newIdProofImage!.path),
                                  width: 100,
                                  height: 100,
                                  fit: BoxFit.cover,
                                ),
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _newIdProofImage = null;
                                      });
                                    },
                                    child: Container(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.redAccent,
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 10),
                ],

// Address
                CustomForm.textField(
                  "Enter Address",
                  textController: _addressController,
                  lines: 5,
                  titleColor: Colors.black,
                  hintColor: Colors.grey,
                  hintText: "Enter Address",
                ),
                SizedBox(
                  height: 100,
                ),
                // CustomLargeBtn(
                //   onPressed: _submitForm,
                //   text: "Update Staff",
                // ),
                // const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: CustomLargeBtn(
        onPressed: _submitForm,
        text: "Update",
      ),
    );
  }
}
