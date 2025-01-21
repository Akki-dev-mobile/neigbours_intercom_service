// edit_staff.dart

import 'dart:developer';
import 'dart:io';

import 'package:common_widgets/common_widgets.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
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

  // Date & Images
  DateTime? _selectedDate;
  XFile? _newProfileImage;
  XFile? _newIdProofImage;

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

  @override
  void initState() {
    super.initState();

    _nameController = TextEditingController(text: widget.staff.name);
    _emailController = TextEditingController(text: widget.staff.email);
    _phoneController = TextEditingController(text: widget.staff.phone);
    _idNumberController =
        TextEditingController(text: widget.staff.idProofNumber);
    _addressController = TextEditingController(text: widget.staff.address);

    _mobileFocusNode = FocusNode();

    _selectedGender = widget.staff.gender;
    _selectedDate = widget.staff.dateOfBirth;
    _selectedCategory = widget.staff.category;
    _selectedCategoryValue = widget.staff.categoryValue;
    _selectedQualification = widget.staff.qualification;
    _selectedIdProof = widget.staff.idProofType;
    selectedCountryCodeSE = widget.staff.countryCode;

    if (!idProofs.contains(_selectedIdProof)) {
      if (idProofs.isNotEmpty) _selectedIdProof = idProofs.first;
    }

    if (!qualifications.contains(_selectedQualification)) {
      if (qualifications.isNotEmpty) {
        _selectedQualification = qualifications.first;
      }
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
    _addressController.dispose();
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

        // Ensure the selectedCategory is valid or fallback to the first
        if (categories.isNotEmpty) {
          // If the existing _selectedCategory isn't in the new map, set a default
          if (!categories.containsKey(_selectedCategory)) {
            _selectedCategory = categories.keys.first;
            _selectedCategoryValue = categories.values.first;
          } else {
            // We assume the staff.category is the ID, so let's update the text value
            _selectedCategoryValue = categories[_selectedCategory] ?? '';
          }
        }
      });
      log('Categories fetched successfully');
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load categories.')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to capture image')),
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
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Confirm'),
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Images uploaded successfully')),
        );
        _updateStaffData(profileImageUrl, idProofImageUrl);
      } else {
        throw Exception('Failed to upload images');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  Future<void> _updateStaffData(
    String? profileImageUrl,
    String? idProofImageUrl,
  ) async {
    try {
      // Build the map of updated staff data
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
        "address": _addressController.text.trim(),
        // Use the newly uploaded images if present; otherwise, keep existing
        "profileImageUrl": profileImageUrl ?? widget.staff.profileImageUrl,
        "idProofImageUrl": idProofImageUrl ?? widget.staff.idProofImageUrl,
      };

      log('Updating staff data: $staffData');

      // Call your editStaff method in _remoteDataSource
      final response =
          await _remoteDataSource.editStaff(widget.staff.id, staffData);

      if (mounted) {
        if (response != null) {
          // Successfully updated
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Staff updated successfully')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating staff: $e');

      if (mounted) {
        String errorMessage = e.toString();

        // Example: if the server responds with "Phone number is required"
        if (errorMessage.contains("Phone number is required")) {
          errorMessage = "Please enter a valid phone number";
        }
        // Or if it's a 400 status
        else if (errorMessage.contains('400')) {
          errorMessage = 'Please check all required fields and try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $errorMessage')),
        );
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a gender')),
      );
      return;
    }

    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select date of birth')),
      );
      return;
    }

    if (_selectedCategory.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a category')),
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
          await _uploadImages(
            File(widget.staff.profileImageUrl),
            idProofFile,
          );
        } else {
          throw Exception('ID Proof image file not found');
        }
      } else if (_newProfileImage != null &&
          _newProfileImage!.path.isNotEmpty &&
          (_newIdProofImage == null || _newIdProofImage!.path.isEmpty)) {
        final profileFile = File(_newProfileImage!.path);
        if (await profileFile.exists()) {
          await _uploadImages(
            profileFile,
            File(widget.staff.idProofImageUrl),
          );
        } else {
          throw Exception('Profile image file not found');
        }
      } else {
        _updateStaffData(null, null);
      }
    } catch (e) {
      debugPrint('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
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
                  backgroundColor: Colors.grey,
                  backgroundImage: _newProfileImage != null
                      ? FileImage(File(_newProfileImage!.path))
                      : (widget.staff.profileImageUrl.isNotEmpty
                          ? NetworkImage(widget.staff.profileImageUrl)
                          : const NetworkImage(
                              "https://static.vecteezy.com/system/resources/previews/045/994/896/non_2x/a-man-is-holding-a-camera-and-taking-a-picture-png.png",
                            )) as ImageProvider,
                ),
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

          // Form
          Form(
            key: _formKey,
            child: Column(
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
                  textController: _phoneController,
                  titleColor: Theme.of(context).colorScheme.onBackground,
                  hintColor: Theme.of(context).colorScheme.onPrimary,
                  focusNode: _mobileFocusNode,
                  "Mobile Number",
                  hintText: '0123456789',
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
                    onChanged: (countryCode) {
                      setState(() {
                        selectedCountryCodeSE = countryCode.code!;
                      });
                    },
                  ),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        FocusScope.of(context).requestFocus();
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
                    if (value?.isEmpty ?? true) {
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
                  hintText: 'Enter Date of Birth',
                  textController: TextEditingController(
                    text: _selectedDate != null
                        ? "${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}"
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

                // Qualification
                CustomDropdown(
                  title: "Qualification",
                  hintText: "Select Qualification",
                  items: qualifications,
                  selectedItem: _selectedQualification,
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedQualification = newValue;
                      });
                    }
                  },
                ),

                const Divider(
                  color: Colors.grey,
                  thickness: 1,
                ),

                // ID Proof
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
                ),

                // ID Proof Number + camera icon
                CustomForm.textField(
                  _selectedIdProof,
                  titleColor: Colors.black,
                  hintColor: Colors.black,
                  hintText: "Enter ID Proof Number",
                  textController: _idNumberController,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter an ID proof number';
                    }
                    return null;
                  },
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.camera_alt),
                    onPressed: () => _openCamera(isIdProof: true),
                  ),
                  counterText: "Upload ID Proof",
                ),

                // Address
                CustomForm.textField(
                  "Enter Address",
                  textController: _addressController,
                  lines: 5,
                  titleColor: Colors.black,
                  hintColor: Colors.grey,
                  hintText: "Enter Address",
                ),

                // Update Button
                CustomLargeBtn(
                  onPressed: _submitForm,
                  text: "Update Staff",
                ),
                const SizedBox(height: 120),
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
