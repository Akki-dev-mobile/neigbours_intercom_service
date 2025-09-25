import 'dart:developer';
import 'dart:io';

import 'package:common_widgets/common_widgets.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onegate/data/models/staff_model.dart';
import 'package:flutter_onegate/presentation/features/staff/ui/staff_home_view.dart';
import 'package:flutter_onegate/generated/l10n/app_localizations.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../data/datasources/remote_datasource.dart';
import '../model/staff_model.dart';

class EditStaff extends StatefulWidget {
  final String staffId;

  const EditStaff({
    Key? key,
    required this.staffId,
  }) : super(key: key);

  @override
  State<EditStaff> createState() => _EditStaffState();
}

class _EditStaffState extends State<EditStaff> {
  final RemoteDataSource _remoteDataSource = RemoteDataSource();

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
  bool _isLoading = true;
  StaffModel? _staffData;
  final String _profileImageUrl = '';
  final String _idProofImageUrl = '';

  @override
  void initState() {
    super.initState();
    _mobileFocusNode = FocusNode();
    _staffId = int.parse(widget.staffId);

    // Initialize controllers with empty values
    _nameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _idNumberController = TextEditingController();
    _addressController = TextEditingController();

    // Fetch staff data
    _fetchStaffData();
    _fetchCategories();
  }

  Future<void> _fetchStaffData() async {
    try {
      final response = await _remoteDataSource.fetchStaffById(_staffId);
      if (response != null && response['data'] != null) {
        final staffData = StaffModel.fromJson(response['data']);
        setState(() {
          _staffData = staffData;

          // Update controllers with fetched data
          _nameController.text = staffData.name;
          // _emailController.text = staffData.staff ?? '';
          _phoneController.text = staffData.staffContactNumber;
          // _idNumberController.text = staffData. ?? '';
          // _addressController.text = staffData.address ?? '';

          // Update other fields
          _dob = staffData.staffDob;
          _selectedDate = DateTime.tryParse(staffData.staffDob);
          _selectedCategory = staffData.category;
          // _selectedGender = staffData.gender ?? 'M';
          _selectedQualification = staffData.staffQualification;
          _selectedIdProof = staffData.staffBadgeNumber ?? 'Aadhar Card';
          // selectedCountryCodeSE = staffData. ?? 'IN';

          // // Store image URLs
          // _profileImageUrl = staffData.profileImageUrl ?? '';
          // _idProofImageUrl = staffData.idProofImageUrl ?? '';

          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching staff data: $e');
      setState(() {
        _isLoading = false;
      });
      myFluttertoast(
        msg: "Failed to load staff data",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  @override
  void dispose() {
    _mobileFocusNode.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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
      myFluttertoast(
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
        myFluttertoast(
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
            dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
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
          title: Text(AppLocalizations.of(context)!.confirmUpload),
          content: Text(AppLocalizations.of(context)!.doYouWantToUpload),
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
      const int companyId = 1;
      final profileImageResponse =
          await _remoteDataSource.uploadStaffImages(profileImage, companyId);
      final idProofImageResponse =
          await _remoteDataSource.uploadStaffImages(idProofImage, companyId);

      if (profileImageResponse != null && idProofImageResponse != null) {
        final profileImageUrl = profileImageResponse['url'];
        final idProofImageUrl = idProofImageResponse['url'];

        myFluttertoast(
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
      // Handle error
      debugPrint('Error uploading images: $e');
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
              Text(AppLocalizations.of(context)!.male),
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
              Text(AppLocalizations.of(context)!.female),
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
              Text(AppLocalizations.of(context)!.other),
            ],
          )
        ],
      ),
    );
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
        "profileImageUrl": profileImageUrl ?? _profileImageUrl,
        "idProofImageUrl": idProofImageUrl ?? _idProofImageUrl,
      };

      log('Updating staff data: $staffData');

      final response = await _remoteDataSource.editStaff(_staffId, staffData);

      if (mounted) {
        if (response != null) {
          Navigator.pop(context);
          if (mounted) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(
                builder: (context) =>
                    const StaffScreen(), // Replace with your list view screen widget
              ),
              (route) => false,
            );
          }
          showDialog(
            context: context,
            builder: (BuildContext context) {
              Future.delayed(const Duration(seconds: 2), () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              });
              return AlertDialog(
                title: SizedBox(
                  height: MediaQuery.of(context).size.height * 0.1,
                  width: MediaQuery.of(context).size.width * 0.2,
                  child: Image.network(
                      'https://uxwing.com/wp-content/themes/uxwing/download/editing-user-action/tick-mark-user-color-icon.png'),
                ),
                content: Text(
                    AppLocalizations.of(context)!.staffUpdatedSuccessfully),
              );
            },
          );
        }
      } else {
        log('Error response: ${response?.data}');
        myFluttertoast(
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
      }
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGender.isEmpty) {
      myFluttertoast(
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
      myFluttertoast(
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
      myFluttertoast(
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
          if (_profileImageUrl.isNotEmpty) {
            _showConfirmationDialog(
                context, File(_profileImageUrl), idProofFile);
          } else {
            // Handle case where there's no existing profile image
            _updateStaffData(null, await _uploadSingleImage(idProofFile));
          }
        } else {
          throw Exception('ID Proof image file not found');
        }
      } else if (_newProfileImage != null &&
          _newProfileImage!.path.isNotEmpty &&
          (_newIdProofImage == null || _newIdProofImage!.path.isEmpty)) {
        final profileFile = File(_newProfileImage!.path);
        if (await profileFile.exists()) {
          if (_idProofImageUrl.isNotEmpty) {
            _showConfirmationDialog(
                context, profileFile, File(_idProofImageUrl));
          } else {
            // Handle case where there's no existing ID proof image
            _updateStaffData(await _uploadSingleImage(profileFile), null);
          }
        } else {
          throw Exception('Profile image file not found');
        }
      } else {
        _updateStaffData(null, null);
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  Future<String?> _uploadSingleImage(File imageFile) async {
    try {
      const int companyId = 1;
      final response =
          await _remoteDataSource.uploadStaffImages(imageFile, companyId);
      if (response != null) {
        return response['url'];
      }
      return null;
    } catch (e) {
      debugPrint('Error uploading single image: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text("Edit Staff"),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

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
                  foregroundImage: _newProfileImage != null
                      ? FileImage(File(_newProfileImage!.path))
                      : (_profileImageUrl.isNotEmpty
                              ? NetworkImage(_profileImageUrl)
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
                  titleColor: Theme.of(context).colorScheme.onSurface,
                  hintColor: Theme.of(context).colorScheme.onPrimary,
                  prefixIcon: CountryCodePicker(
                    initialSelection: selectedCountryCodeSE,
                    favorite: const ['IN'],
                    showFlagMain: true,
                    showFlagDialog: true,
                    boxDecoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                    ),
                    barrierColor:
                        Theme.of(context).colorScheme.surface.withOpacity(0.5),
                    closeIcon: Icon(
                      Icons.close,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    searchDecoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.search,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      hintText: 'Search',
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    textStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
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
                  hintText: "Enter ID Number",
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
                        if (input.length < 10 ||
                            !RegExp(r'^[A-Za-z\d]+$').hasMatch(input)) {
                          return 'Please enter a valid Voter ID';
                        }
                        break;
                      case 'PAN Card':
                        if (!RegExp(r'^[A-Z\d]{10}$').hasMatch(input)) {
                          return 'Please enter a valid PAN Card number (10 alphanumeric characters)';
                        }
                        break;
                    }
                    return null;
                  },
                  suffixIcon: IconButton(
                    onPressed: () => _openCamera(isIdProof: true),
                    icon: const Icon(Icons.camera_alt),
                  ),
                ),

                // Address
                CustomForm.textField(
                  "Address",
                  textController: _addressController,
                  titleColor: Colors.black,
                  hintColor: Colors.grey,
                  hintText: "Enter Address",
                  lines: 3,
                  validator: (value) {
                    if (value?.isEmpty ?? true) {
                      return 'Please enter an address';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 30),

                // Submit Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      "Update Staff",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
