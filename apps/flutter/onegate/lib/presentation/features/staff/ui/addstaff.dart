import 'dart:developer';
import 'dart:io';

import 'package:common_widgets/common_widgets.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

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
      // ScaffoldMessenger.of(context).showSnackBar(
      //   const SnackBar(content: Text('Failed to load categories.')),
      // );
    }
  }

  Future<dynamic> _openCamera({required bool isIdProof}) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? capturedImage = (await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 80,
      ));

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
      if (mounted) {
        Fluttertoast.showToast(
          msg: "Failed to capture images",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 1,
          backgroundColor: Colors.red,
          textColor: Colors.white,
          fontSize: 16.0,
        );
// ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text('Failed to capture image')),
        // );
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

  void showCategoryDropdown(BuildContext context) {
    log('Showing category dropdown');
    if (categories.isEmpty) {
      log('No categories to show');
      return;
    }

    categories.isEmpty
        ? CircularProgressIndicator()
        : DropdownButton<String>(
            value: _selectedCategory,
            isExpanded: true,
            underline: SizedBox(),
            items: categories.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Text(entry.key),
              );
            }).toList(),
            onChanged: (String? newValue) {
              if (newValue != null) {
                setState(() {
                  _selectedCategory = newValue;
                });
              }
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
        _submitStaffData(profileImageUrl, idProofImageUrl);
      } else {
        throw Exception('Failed to upload images');
      }
    } catch (e) {
      debugPrint('Error uploading images: $e');
      Fluttertoast.showToast(
        msg: "Failed to upload images",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );

      // ScaffoldMessenger.of(context).showSnackBar(
      //   SnackBar(content: Text('Error: $e')),
      // );
    }
  }

  void _showConfirmationDialog(
      BuildContext context, File profileImage, File idProofImage) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Upload'),
          content: Text('Do you want to upload the selected images?'),
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
      };

      log('Submitting staff data: $staffData');

      final response = await _remoteDataSource.addStaff(staffData);

      if (mounted) {
        if (response != null) {
          Navigator.pop(context);
          Fluttertoast.showToast(
            msg: "Staff updated successfully",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }
      }
    } catch (e) {
      debugPrint('Error adding staff: $e');
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains("Phone number is required")) {
          errorMessage = "Please enter a valid phone number";
        } else if (errorMessage.contains('400')) {
          errorMessage = 'Please check all required fields and try again.';
        }
        debugPrint('Error: $errorMessage');
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Error: $errorMessage')),
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
      if (_idProofImage != null &&
          _idProofImage!.path.isNotEmpty &&
          _image != null &&
          _image!.path.isNotEmpty) {
        final idProofFile = File(_idProofImage!.path);
        final profileFile = File(_image!.path);

        if (await idProofFile.exists() && await profileFile.exists()) {
          _showConfirmationDialog(context, profileFile, idProofFile);
        } else {
          throw Exception('One or both image files not found');
        }
      } else {
        throw Exception(
            'One or both images are not selected or paths are invalid');
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
                value: 'F',
                fillColor: WidgetStateProperty.all(Colors.red),
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
      pageTitle: "Create Staff",
      pageBody: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: double.infinity,
            height: MediaQuery.of(context).size.height * 0.3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircleAvatar(
                    radius: 80,
                    backgroundColor: Colors.grey,
                    backgroundImage: _image != null
                        ? FileImage(File(_image!.path))
                        : const NetworkImage(
                            "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_960_720.png")),
                Positioned(
                  bottom: 50,
                  right: 90,
                  child: InkWell(
                    onTap: () => _openCamera(isIdProof: false),
                    child: const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blue,
                      child: Icon(
                        Icons.camera_alt,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Personal Details',
                    style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 20),
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
                _buildGenderSelection(),
                CustomForm.textField(
                  textController: _phoneController,
                  titleColor: Theme.of(context).colorScheme.onBackground,
                  hintColor: Theme.of(context).colorScheme.onPrimary,
                  focusNode: _mobileFocusNode,
                  "Visitor Mobile Number",
                  hintText: '0123456789',
                  prefixIcon: CountryCodePicker(
                    initialSelection: 'IN',
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
                        selectedCountryCodeSE = countryCode.code!;
                      });
                    },
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        FocusScope.of(context).unfocus();
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
                CustomForm.textField(
                  "Email",
                  textController: _emailController,
                  hintText: "Enter Email",
                  titleColor: Colors.black,
                  hintColor: Colors.grey,
                  keyboardType: TextInputType.emailAddress,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter an email';
                    }

                    return null;
                  },
                ),
                CustomForm.textField(
                  "Date of Birth",
                  titleColor: Colors.black,
                  hintColor: Colors.grey,
                  hintText: 'Enter Date of Birth',
                  textController: TextEditingController(
                      text: _selectedDate != null
                          ? "${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}"
                          : ""),
                  isReadOnly: true,
                  validator: (value) {
                    if (_selectedDate == null) {
                      return 'Please select date of birth';
                    }
                    return null;
                  },
                  suffixIcon: IconButton(
                    onPressed: _selectDateOfBirth,
                    icon: const Icon(
                      Icons.calendar_today,
                    ),
                  ),
                ),

                CustomDropdown(
                  title: "Category",
                  hintText: "Select Category",
                  items: categories.values.toSet().toList(),
                  selectedItem: _selectedCategoryValue.isNotEmpty
                      ? _selectedCategoryValue
                      : null,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategoryValue = newValue;
                        _selectedCategory = categories.entries
                            .firstWhere((entry) => entry.value == newValue)
                            .key;
                      });
                    }
                  },
                ),

                // CustomForm.textField(
                //   "Qualification",
                //   isReadOnly: true,
                //   titleColor: Colors.black,
                //   hintColor: Colors.black,
                //   textController:
                //       TextEditingController(text: _selectedQualification),
                //   hintText: "Enter Qualification",
                //   suffixIcon: DropdownButton<String>(
                //     underline: SizedBox(),
                //     icon: Icon(Icons.arrow_drop_down),
                //     items: qualifications.map((qualification) {
                //       return DropdownMenuItem<String>(
                //         value: qualification,
                //         child: Text(qualification),
                //       );
                //     }).toList(),
                //     onChanged: (String? newValue) {
                //       if (newValue != null) {
                //         setState(() {
                //           _selectedQualification = newValue;
                //         });
                //       }
                //     },
                //   ),
                // ),

                CustomDropdown(
                  title: "Qualification",
                  hintText: "Select Qualification",
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

                // CustomForm.textField(
                //   "Enter ID Proof",
                //   isReadOnly: true,
                //   titleColor: Colors.black,
                //   hintColor: Colors.black,
                //   hintText: "Select ID Proof",
                //   hasInitialValue: _selectedIdProof,
                //   suffixIcon: DropdownButton<String>(
                //     underline: SizedBox(),
                //     icon: Icon(Icons.arrow_drop_down),
                //     items: idProofs.map((idProof) {
                //       return DropdownMenuItem<String>(
                //         value: idProof,
                //         child: Text(idProof),
                //       );
                //     }).toList(),
                //     onChanged: (String? newValue) {
                //       if (newValue != null) {
                //         setState(() {
                //           _selectedIdProof = newValue;
                //         });
                //       }
                //     },
                //   ),c
                // ),

                CustomDropdown(
                  title: "ID Proof",
                  hintText: "Select ID Proof",
                  items: idProofs,
                  selectedItem: _selectedIdProof,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedIdProof = newValue;
                      });
                    }
                  },
                  titleColor: null,
                ),

                CustomForm.textField(
                  _selectedIdProof,
                  titleColor: Colors.black,
                  hintColor: Colors.black,
                  hintText: "Enter ID ${_selectedIdProof}",
                  textController: _idNumberController,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter an ID proof number';
                    }
                    final input = value!.trim();

                    switch (_selectedIdProof) {
                      case 'Aadhar Card':
                        // Aadhaar should be exactly 12 digits
                        if (!RegExp(r'^\d{12}$').hasMatch(input)) {
                          return 'Please enter a valid 12-digit Aadhaar number';
                        }
                        break;
                      case 'Passport':
                        // Passport: typically 8-9 alphanumeric characters (generic validation)
                        if (input.length < 8 ||
                            input.length > 9 ||
                            !RegExp(r'^[A-Za-z0-9]+$').hasMatch(input)) {
                          return 'Please enter a valid Passport number (8-9 alphanumeric characters)';
                        }
                        break;
                      case 'Driving License':
                        // Driving License: Check for a reasonable length (can vary by region)
                        if (input.length < 5) {
                          return 'Please enter a valid Driving License number';
                        }
                        break;
                      case 'Voter ID':
                        // Voter ID (Indian format example: 3 letters followed by 7 digits)
                        if (!RegExp(r'^[A-Za-z]{3}\d{7}$').hasMatch(input)) {
                          return 'Please enter a valid Voter ID (e.g., ABC1234567)';
                        }
                        break;
                      case 'PAN Card':
                        // PAN Card: Indian PAN format: 5 letters, 4 digits, 1 letter
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

                if (_image != null || _idProofImage != null) ...[
                  Text(
                    "Preview images",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  SizedBox(height: 5),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        //   // Profile Image Container
                        //   Container(
                        //     height: 120,
                        //     padding: const EdgeInsets.only(top: 8.0),
                        //     child: Stack(
                        //       alignment: Alignment.topRight,
                        //       children: [
                        //       _image != null
                        //           ? Image.file(
                        //               File(_image!.path),
                        //               width: 100,
                        //               height: 100,
                        //               fit: BoxFit.cover,
                        //             )
                        //           : Container(
                        //               width: 100,
                        //               height: 100,
                        //               color: Colors.grey.shade300,
                        //               child: const Icon(
                        //                 Icons.camera_alt,
                        //                 color: Colors.white70,
                        //                 size: 40,
                        //               ),
                        //             ),
                        //       if (_image != null)
                        //         Positioned(
                        //           right: 0,
                        //           top: 0,
                        //           child: GestureDetector(
                        //             onTap: () {
                        //               setState(() {
                        //                 _image = null;
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
                        //     ],
                        //   ),
                        // ),

                        // ID Proof Image Container
                        Container(
                          height: 120,
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Stack(
                            alignment: Alignment.topRight,
                            children: [
                              _idProofImage != null
                                  ? Image.file(
                                      File(_idProofImage!.path),
                                      width: 100,
                                      height: 100,
                                      fit: BoxFit.cover,
                                    )
                                  : Container(
                                      width: 100,
                                      height: 100,
                                      color: Colors.grey.shade300,
                                      child: const Icon(
                                        Icons.camera_alt,
                                        color: Colors.white70,
                                        size: 40,
                                      ),
                                    ),
                              if (_idProofImage != null)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _idProofImage = null;
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
                    ),
                  ),
                  SizedBox(height: 10),
                ],
                CustomForm.textField("Enter Address",
                    textController: addressController,
                    lines: 5,
                    titleColor: Colors.black,
                    hintColor: Colors.grey,
                    hintText: "Enter Address"),
                // CustomLargeBtn(
                //     onPressed: () {
                //       _submitForm();
                //     },
                //     text: "PostData"),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: CustomLargeBtn(
        onPressed: () async {
          if (_image != null && _idProofImage != null) {
            _submitStaffData(_image!.path, _idProofImage!.path);
            await _submitForm();
          } else {
            Fluttertoast.showToast(
              msg: "Please select both images",
              toastLength: Toast.LENGTH_SHORT,
              gravity: ToastGravity.BOTTOM,
              timeInSecForIosWeb: 1,
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
