import 'dart:developer';
import 'dart:io';

import 'package:common_widgets/common_widgets.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/staff/ui/staff_home_view.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../../utils/myfluttertoast.dart';

class AddStaff extends StatefulWidget {
  const AddStaff({super.key});

  @override
  State<AddStaff> createState() => _AddStaffState();
}

class _AddStaffState extends State<AddStaff> {
  final RemoteDataSource _remoteDataSource = RemoteDataSource();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController addressController = TextEditingController();

  String _selectedCategory = "";
  String _selectedCategoryValue = "";
  DateTime? _selectedDate;
  XFile? _image;
  String? _profileImageUrl;
  String? _idProofImageUrl;
  String _selectedGender = '';
  String selectedCountryCodeSE = 'IN';
  late FocusNode _mobileFocusNode;
  XFile? _idProofImage;
  bool _isStaff = true; // Default to staff, toggle to member
  
  // Member selection
  List<dynamic> _membersList = [];
  dynamic _selectedMember;
  bool _isMemberLoading = false;

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
    _fetchMembers();
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

  List<TextInputFormatter> _getInputFormatters(String idProofType) {
    switch (idProofType) {
      case 'Aadhar Card':
        return [
          LengthLimitingTextInputFormatter(12),
          FilteringTextInputFormatter.digitsOnly,
        ];
      case 'Passport':
        return [
          LengthLimitingTextInputFormatter(9),
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        ];
      case 'Driving License':
        return [
          LengthLimitingTextInputFormatter(16),
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
        ];
      case 'Voter ID':
        return [
          LengthLimitingTextInputFormatter(10),
          FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z\d]')),
        ];
      case 'PAN Card':
        return [
          LengthLimitingTextInputFormatter(10),
          FilteringTextInputFormatter.allow(RegExp(r'[A-Z\d]')),
          UpperCaseTextFormatter(),
        ];
      default:
        return [];
    }
  }

  Future<void> _fetchMembers() async {
    setState(() {
      _isMemberLoading = true;
    });
    try {
      final members = await _remoteDataSource.getMembersList();
      setState(() {
      
        _membersList = members;
        _isMemberLoading = false;
        print('Members fetched successfully $members');
      });
    } catch (e) {
      setState(() {
        _isMemberLoading = false;
      });
      if (mounted) {
        myFluttertoast(
          msg: "Failed to load members",
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
          _selectedCategoryValue = categories.values.first;
        }
      });
      print('Categories fetched successfully');
    } catch (e) {
      debugPrint('Error fetching categories: $e');
      if (mounted) {
        myFluttertoast(
          msg: "Failed to load categories",
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
        myFluttertoast(
          msg: "Failed to capture images",
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

  Future<dynamic> _openGallery({required bool isIdProof}) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? selectedImage = (await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      ));

      if (selectedImage != null) {
        setState(() {
          if (isIdProof) {
            _idProofImage = selectedImage;
          } else {
            _image = selectedImage;
          }
        });
      }
    } catch (e) {
      debugPrint('Error selecting image: $e');
      if (mounted) {
        myFluttertoast(
          msg: "Failed to select image",
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

  void _showImageSourceDialog({required bool isIdProof}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Select Image Source'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Camera'),
                onTap: () {
                  Navigator.pop(context);
                  _openCamera(isIdProof: isIdProof);
                },
              ),
              ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _openGallery(isIdProof: isIdProof);
                },
              ),
            ],
          ),
        );
      },
    );
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

  Future<void> _uploadImages(File profileImage, File idProofImage) async {
    try {
      final int companyId = 1;
      final profileImageResponse =
      await _remoteDataSource.uploadStaffImages(profileImage, companyId);
      final idProofImageResponse =
      await _remoteDataSource.uploadStaffImages(idProofImage, companyId);

      if (profileImageResponse != null && idProofImageResponse != null) {
        final profileImageUrl = profileImageResponse['data']?.first;
        final idProofImageUrl = idProofImageResponse['data']?.first;

        if (profileImageUrl != null && idProofImageUrl != null) {
          setState(() {
            _profileImageUrl = profileImageUrl;
            _idProofImageUrl = idProofImageUrl;
          });

          myFluttertoast(
            msg: "Images uploaded successfully",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.green,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        } else {
          throw Exception('Image URLs are null');
        }
      } else {
        throw Exception('Failed to upload images');
      }
    } catch (e) {
      debugPrint('Error uploading images: $e');
      myFluttertoast(
        msg: "Failed to upload images",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    }
  }

  void _showConfirmationDialog(
      BuildContext context, String profileImageUrl, String idProofImageUrl) {
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
                Navigator.of(context).pop(); // Close dialog
                await _submitStaffData(profileImageUrl, idProofImageUrl);
              },
            ),
          ],
        );
      },
    );
  }

  // Future<void> _submitStaffData(
  //     String profileImageUrl, String idProofImageUrl) async {
  //   try {
  //     final data = {
  //       "name": _nameController.text.trim(),
  //       "email": _emailController.text.trim(),
  //       "phone": _phoneController.text,
  //       "countryCode": selectedCountryCodeSE,
  //       "dateOfBirth": _selectedDate?.toIso8601String(),
  //       "category": _selectedCategory,
  //       "categoryValue": _selectedCategoryValue,
  //       "gender": _selectedGender,
  //       "qualification": _selectedQualification,
  //       "idProofType": _selectedIdProof,
  //       "idProofNumber": _idNumberController.text.trim(),
  //       "address": addressController.text.trim(),
  //       "idProofImageUrl": idProofImageUrl,
  //       "profileImageUrl": profileImageUrl,
  //       "isMember": !_isStaff, // Add member/staff field
  //     };

  //     log('Submitting data: $data');

  //     final response = await _remoteDataSource.addStaff(data);

  //     if (mounted && response != null) {
  //       Navigator.pop(context);
  //       if (mounted) {
  //         Navigator.of(context).pushAndRemoveUntil(
  //           MaterialPageRoute(
  //             builder: (context) => StaffScreen(),
  //           ),
  //               (route) => false,
  //         );
  //       }

  //       showDialog(
  //         context: context,
  //         builder: (BuildContext context) {
  //           Future.delayed(const Duration(seconds: 2), () {
  //             if (Navigator.of(context).canPop()) {
  //               Navigator.of(context).pop();
  //             }
  //           });
  //           return AlertDialog(
  //             title: Container(
  //               height: MediaQuery.of(context).size.height * 0.1,
  //               width: MediaQuery.of(context).size.width * 0.2,
  //               child: Image.network(
  //                   'https://uxwing.com/wp-content/themes/uxwing/download/editing-user-action/tick-mark-user-color-icon.png'),
  //             ),
  //             content: Text(
  //               '${_isStaff ? "Staff" : "Member"} added successfully',
  //               style: Theme.of(context).textTheme.bodyMedium,
  //             ),
  //           );
  //         },
  //       );
  //     }
  //   } catch (e) {
  //     debugPrint('Error adding ${_isStaff ? "staff" : "member"}: $e');
  //     if (mounted) {
  //       String errorMessage = e.toString();
  //       if (errorMessage.contains("Phone number is required")) {
  //         errorMessage = "Please enter a valid phone number";
  //       } else if (errorMessage.contains('400')) {
  //         errorMessage = 'Please check all required fields and try again.';
  //       }

  //       myFluttertoast(
  //         msg: "Error: $errorMessage",
  //         toastLength: Toast.LENGTH_SHORT,
  //         gravity: ToastGravity.BOTTOM,
  //         timeInSecForIosWeb: 1,
  //         backgroundColor: Colors.red,
  //         textColor: Colors.white,
  //         fontSize: 16.0,
  //       );
  //     }
  //   }
  // }
  List<dynamic> _selectedMembers = []; // Changed to list for multiple selection

bool _isLoading = false;

  // Modify the _submitForm method
  
   Future<void> _submitForm() async {
    // First validate the form
    if (!_formKey.currentState!.validate()) return;

    // Check for gender selection
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

    // Check for DOB selection
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

    // Check for category selection
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

    // Check for member selection when adding staff
    if (!_isStaff && _selectedMembers.isEmpty) {
      myFluttertoast(
        msg: "Please select at least one member",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    // Check for profile and ID proof images
    // Rest of the method remains the same

    // Check for profile and ID proof images
    if (_image == null) {
      myFluttertoast(
        msg: "Please select a profile image",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    if (_idProofImage == null) {
      myFluttertoast(
        msg: "Please select an ID proof image",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return;
    }

    // Set loading state to true
    setState(() {
      _isLoading = true;
    });

    try {
      if (_idProofImage != null &&
          _idProofImage!.path.isNotEmpty &&
          _image != null &&
          _image!.path.isNotEmpty) {
        final idProofFile = File(_idProofImage!.path);
        final profileFile = File(_image!.path);

        if (await idProofFile.exists() && await profileFile.exists()) {
          await _uploadImages(profileFile, idProofFile);
          if (_profileImageUrl != null && _idProofImageUrl != null) {
            // Directly submit data instead of showing confirmation dialog
            await _submitStaffData(_profileImageUrl!, _idProofImageUrl!);
          } else {
            throw Exception('Image URLs are null');
          }
        } else {
          throw Exception('One or both image files not found');
        }
      } else {
        throw Exception(
            'One or both images are not selected or paths are invalid');
      }
    } catch (e) {
      debugPrint('Error: $e');
      myFluttertoast(
        msg: "Error: ${e.toString().substring(0, min(e.toString().length, 100))}",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
    } finally {
      // Set loading state back to false
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Modify the _submitStaffData method to use toast instead of dialog
  Future<void> _submitStaffData(
      String profileImageUrl, String idProofImageUrl) async {
    try {
            final memberIds = _selectedMembers
          .map((member) => member['id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .join(',');
      final data = {
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
        "isMember": !_isStaff,
        "memberId": memberIds, // Add member ID
      };

      log('Submitting data: $data');

      final response = await _remoteDataSource.addStaff(data);

      if (mounted && response != null) {
        // Show success toast message
        myFluttertoast(
          msg: "${_isStaff ? 'Staff' : 'Member'} added successfully",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
          timeInSecForIosWeb: 2,
          backgroundColor: Colors.green,
          textColor: Colors.white,
          fontSize: 16.0,
        );
        
        // Navigate back to staff screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => StaffScreen(),
          ),
          (route) => false,
        );
      }
    } catch (e) {
      debugPrint('Error adding ${_isStaff ? "staff" : "member"}: $e');
      if (mounted) {
        String errorMessage = e.toString();
        if (errorMessage.contains("Phone number is required")) {
          errorMessage = "Please enter a valid phone number";
        } else if (errorMessage.contains('400')) {
          errorMessage = 'Please check all required fields and try again.';
        }

        myFluttertoast(
          msg: "Error: $errorMessage",
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
Widget _buildMemberSelection() {
  return Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Members',
          style: TextStyle(
            fontSize: 16,
            color: Colors.black,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              // Selected members chips
              if (_selectedMembers.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _selectedMembers.map((member) {
                      final memberName = "${member['member_first_name'] ?? ''} ${member['member_last_name'] ?? ''}";
                      final memberType = member['member_type_name'] ?? '';
                      
                      return Chip(
                        backgroundColor: Colors.red.shade100,
                        label: Text("$memberName ($memberType)"),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () {
                          setState(() {
                            _selectedMembers.remove(member);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ),
              
              // Member selection button
              InkWell(
                onTap: () {
                  _showMemberSelectionDialog();
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _selectedMembers.isEmpty 
                              ? 'Select members' 
                              : '${_selectedMembers.length} members selected',
                          style: TextStyle(
                            color: _selectedMembers.isEmpty ? Colors.grey : Colors.black,
                          ),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_selectedMembers.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 12),
            child: Text(
              'Please select at least one member',
              style: TextStyle(
                color: Colors.red.shade700,
                fontSize: 12,
              ),
            ),
          ),
      ],
    ),
  );
}
void _showMemberSelectionDialog() {
  TextEditingController searchController = TextEditingController();
  List<dynamic> filteredMembers = List.from(_membersList);
  
  // Prepare individual members from member_details
  Map<String, List<dynamic>> membersByUnit = {};
  
  void buildMembersByUnit(List<dynamic> sourceList) {
    membersByUnit.clear();
    for (var memberGroup in sourceList) {
      final unitNumber = memberGroup['unit_flat_number']?.toString() ?? 'Unknown Unit';
      final buildingName = memberGroup['soc_building_name']?.toString() ?? '';
      final unitKey = "$buildingName - $unitNumber";
      
      if (!membersByUnit.containsKey(unitKey)) {
        membersByUnit[unitKey] = [];
      }
      
      // Extract individual members from member_details
      List<dynamic> memberDetails = memberGroup['member_details'] ?? [];
      if (memberDetails.isNotEmpty) {
        for (var member in memberDetails) {
          // Add unit information to each member for reference
          member['unit_flat_number'] = memberGroup['unit_flat_number'];
          member['soc_building_name'] = memberGroup['soc_building_name'];
          membersByUnit[unitKey]!.add(member);
        }
      } else {
        // Fallback if member_details is empty
        membersByUnit[unitKey]!.add(memberGroup);
      }
    }
  }
  
  // Initial build of membersByUnit
  buildMembersByUnit(_membersList);
  List<String> sortedUnitKeys = membersByUnit.keys.toList()..sort();
  
  showDialog(
    context: context,
    builder: (BuildContext context) {
      return StatefulBuilder(
        builder: (context, setState) {
          void filterMembers(String query) {
            setState(() {
              if (query.isEmpty) {
                // Reset to original list
                buildMembersByUnit(_membersList);
              } else {
                // Create a new filtered list of individual members
                List<dynamic> tempFilteredMembers = [];
                
                for (var memberGroup in _membersList) {
                  List<dynamic> memberDetails = memberGroup['member_details'] ?? [];
                  
                  if (memberDetails.isNotEmpty) {
                    for (var member in memberDetails) {
                      final memberName = member['member_first_name']?.toString().toLowerCase() ?? '';
                      final memberLastName = member['member_last_name']?.toString().toLowerCase() ?? '';
                      final memberType = member['member_type_name']?.toString().toLowerCase() ?? '';
                      final memberId = member['member_id']?.toString().toLowerCase() ?? '';
                      final unitNumber = memberGroup['unit_flat_number']?.toString().toLowerCase() ?? '';
                      final buildingName = memberGroup['soc_building_name']?.toString().toLowerCase() ?? '';
                      
                      if (memberName.contains(query.toLowerCase()) ||
                          memberLastName.contains(query.toLowerCase()) ||
                          memberType.contains(query.toLowerCase()) ||
                          memberId.contains(query.toLowerCase()) ||
                          unitNumber.contains(query.toLowerCase()) ||
                          buildingName.contains(query.toLowerCase())) {
                        
                        // Create a copy of the member with unit information
                        Map<String, dynamic> memberWithUnit = Map.from(member);
                        memberWithUnit['unit_flat_number'] = memberGroup['unit_flat_number'];
                        memberWithUnit['soc_building_name'] = memberGroup['soc_building_name'];
                        tempFilteredMembers.add(memberWithUnit);
                      }
                    }
                  } else {
                    // Handle the case where member_details is empty
                    final memberName = memberGroup['member_first_name']?.toString().toLowerCase() ?? '';
                    final unitNumber = memberGroup['unit_flat_number']?.toString().toLowerCase() ?? '';
                    final buildingName = memberGroup['soc_building_name']?.toString().toLowerCase() ?? '';
                    
                    if (memberName.contains(query.toLowerCase()) ||
                        unitNumber.contains(query.toLowerCase()) ||
                        buildingName.contains(query.toLowerCase())) {
                      tempFilteredMembers.add(memberGroup);
                    }
                  }
                }
                
                // Rebuild the groups with filtered members
                membersByUnit.clear();
                for (var member in tempFilteredMembers) {
                  final unitNumber = member['unit_flat_number']?.toString() ?? 'Unknown Unit';
                  final buildingName = member['soc_building_name']?.toString() ?? '';
                  final unitKey = "$buildingName - $unitNumber";
                  
                  if (!membersByUnit.containsKey(unitKey)) {
                    membersByUnit[unitKey] = [];
                  }
                  membersByUnit[unitKey]!.add(member);
                }
              }
              
              // Update the sorted keys
              sortedUnitKeys = membersByUnit.keys.toList()..sort();
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            backgroundColor: Colors.transparent,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.85,
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black26,
                            blurRadius: 10.0,
                            offset: const Offset(0.0, 10.0),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Select Members',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red.shade700,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Search Bar
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              controller: searchController,
                              decoration: InputDecoration(
                                hintText: 'Search members or units...',
                                border: InputBorder.none,
                                icon: Icon(Icons.search, color: Colors.red.shade300),
                                suffixIcon: searchController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear),
                                        onPressed: () {
                                          searchController.clear();
                                          filterMembers('');
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: filterMembers,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Selected Count
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              '${_selectedMembers.length} members selected',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),

                          // Members list
                          Container(
                            constraints: BoxConstraints(
                              maxHeight: MediaQuery.of(context).size.height * 0.5,
                            ),
                            child: membersByUnit.isEmpty
                                ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(16.0),
                                      child: Text(
                                        'No members found',
                                        style: TextStyle(color: Colors.grey.shade600),
                                      ),
                                    ),
                                  )
                                : ListView.builder(
                                    shrinkWrap: true,
                                    itemCount: sortedUnitKeys.length,
                                    itemBuilder: (context, unitIndex) {
                                      final unitKey = sortedUnitKeys[unitIndex];
                                      final unitMembers = membersByUnit[unitKey] ?? [];

                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Unit Header
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 8, horizontal: 12),
                                            margin: const EdgeInsets.only(top: 8),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(Icons.apartment,
                                                    size: 18, color: Colors.red.shade700),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Text(
                                                    unitKey,
                                                    style: const TextStyle(
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                Text(
                                                  '${unitMembers.length} members',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),

                                          // Member List
                                           // Member List
                                    ...unitMembers.map((member) {
  final memberName = member['member_first_name'] ?? 'Unknown Member';
  final memberLastName = member['member_last_name'] ?? '';
  final memberType = member['member_type_name'] ?? '';
  final memberId = member['member_id']?.toString() ?? '';
  
  // Check if this specific member is selected
  final isSelected = _selectedMembers.any((selectedMember) => 
    selectedMember['member_id']?.toString() == memberId);

  return Card(
    elevation: 0,
    color: isSelected ? Colors.red.shade50 : Colors.transparent,
    margin: const EdgeInsets.symmetric(vertical: 4),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(
        color: isSelected ? Colors.red.shade200 : Colors.transparent,
        width: 1,
      ),
    ),
    child: CheckboxListTile(
      title: Text(
        "$memberName $memberLastName",
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      subtitle: Text('Type: $memberType'),
      value: isSelected,
      activeColor: Colors.red,
      checkColor: Colors.white,
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: (bool? value) {
        setState(() {
          if (value == true) {
            _selectedMembers.add(member);
          } else {
            _selectedMembers.removeWhere((selectedMember) => 
              selectedMember['member_id']?.toString() == memberId);
          }
        });
      },
    ),
  );
}).toList(),
                                        ],
                                      );
                                    },
                                  ),
                          ),

                          // Action Buttons
                          Padding(
                            padding: const EdgeInsets.only(top: 16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.grey.shade700,
                                  ),
                                  child: const Text('Cancel'),
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red.shade600,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 16, vertical: 12),
                                  ),
                                  child: const Text('Done'),
                                  onPressed: () {
                                    this.setState(() {}); // Update the parent state
                                    Navigator.of(context).pop();
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    },
  );
}

// Add this in your form widget where appropriate
  // if (!_isStaff) _buildMemberSelection(),
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

  Widget _buildStaffMemberToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Role Type',
            style: TextStyle(
              fontSize: 16,
              color: Colors.black,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Switch(
                value: _isStaff,
                activeColor: Colors.red,
                onChanged: (bool value) {
                  setState(() {
                    _isStaff = value;
                  });
                },
              ),
              Text(_isStaff ? 'Staff' : 'Member'),
            ],
          ),
        ],
      ),
    );
  }

  String? _validateAadharCard(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter Aadhar Card number';
    }

    if (value.length != 12) {
      return 'Aadhar Card must be exactly 12 digits';
    }

    // Luhn algorithm check for Aadhar (simplified version)
    int sum = 0;
    for (int i = 0; i < value.length; i++) {
      int digit = int.parse(value[i]);
      if (i % 2 == 0) {
        digit *= 2;
        if (digit > 9) digit -= 9;
      }
      sum += digit;
    }

    if (sum % 10 != 0) {
      return 'Invalid Aadhar Card number';
    }

    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an email address';
    }

    final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegExp.hasMatch(value)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  String? _validateIdProof(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter an ID proof number';
    }

    final input = value.trim();

    switch (_selectedIdProof) {
      case 'Aadhar Card':
        return _validateAadharCard(input);
      case 'Passport':
        if (input.length < 8 || input.length > 9 || !RegExp(r'^[A-Za-z0-9]+$').hasMatch(input)) {
          return 'Please enter a valid Passport number (8-9 alphanumeric characters)';
        }
        break;
      case 'Driving License':
        if (input.length < 5 || !RegExp(r'^[A-Za-z0-9]+$').hasMatch(input)) {
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
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
        pageTitle: _isStaff ? "Create Staff" : "Add Member",
        pageBody: SingleChildScrollView(
          child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
          // Staff/Member Toggle at the top
          _buildStaffMemberToggle(),
          
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
              "https://cdn.pixabay.com/photo/2015/10/05/22/37/blank-profile-picture-973460_960_720.png"),
              ),
              Positioned(
              bottom: 50,
              right: 90,
              child: InkWell(
              onTap: () => _showImageSourceDialog(isIdProof: false),
              child: CircleAvatar(
              radius: 20,
              child: Icon(
              Icons.camera_alt,
              color: Colors.grey.withOpacity(0.8),
              ),
              ),
              ),
              ),
              ],
              ),
              ),
              const SizedBox(height: 20),
              Padding(
                  padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                child: Form(
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
                if (value!.length < 3) {
                return 'Name must be at least 3 characters';
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
                "Mobile Number",
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
                if (value == null || value.isEmpty) {
                return 'Mobile number is required';
                }
                          
                if (value.length != 10) {
                return 'Please enter a 10-digit number';
                }
                          
                if (!RegExp(r'^[0-9]+$').hasMatch(value)) {
                return 'Mobile number should contain only digits';
                }
                          
                // Basic validation for Indian mobile numbers
                if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value)) {
                return 'Please enter a valid Indian mobile number';
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
                validator: _validateEmail,
                ),
                 CustomForm.textField(
                  "Date of Birth",
                  titleColor: Colors.black,
                  hintColor: Colors.grey,
                  hintText: 'Enter Date of Birth',
                  textController: TextEditingController(
                          text: _selectedDate != null
                            ? "${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}"
                            : ""
                  ),
                  isReadOnly: true,
                  // onTap: () => _selectDateOfBirth(),
                  suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: () => _selectDateOfBirth(),
                  ),
                ),
                
                // Address field
                CustomForm.textField(
                  "Address",
                  textController: addressController,
                  titleColor: Colors.black,
                  hintColor: Colors.grey,
                  hintText: "Enter Address",
                  lines: 3,
                  // maxLines: 3,
                  validator: (value) {
                          if (value?.isEmpty ?? true) {
                            return 'Please enter an address';
                          }
                          return null;
                  },
                ),
                
                const SizedBox(height: 20),
                Text('Professional Details',
                          style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 20),
                            if (!_isStaff)_buildMemberSelection(),
                if (!_isStaff) const SizedBox(height: 16),
                
                 // Category dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                          const Text(
                            'Category',
                            style: TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: categories.isEmpty ? null : _selectedCategory.isEmpty ? null : _selectedCategory,
                  hint: const Text('Select Category'),
                  items: categories.entries.map((entry) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedCategory = newValue;
                        _selectedCategoryValue = categories[newValue] ?? '';
                      });
                    }
                  },
                ),
                            ),
                          ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Qualification dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                          const Text(
                            'Qualification',
                            style: TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedQualification,
                  hint: const Text('Select Qualification'),
                  items: qualifications.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedQualification = newValue;
                      });
                    }
                  },
                ),
                            ),
                          ),
                  ],
                ),
                
                const SizedBox(height: 20),
                Text('ID Proof Details',
                          style: Theme.of(context).textTheme.displaySmall),
                const SizedBox(height: 20),
                
                // ID Proof Type dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                          const Text(
                            'ID Proof Type',
                            style: TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  value: _selectedIdProof,
                  hint: const Text('Select ID Proof Type'),
                  items: idProofs.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _selectedIdProof = newValue;
                        _idNumberController.clear(); // Clear ID number when type changes
                      });
                    }
                  },
                ),
                            ),
                          ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // ID Proof Number field
                CustomForm.textField(
                  "ID Proof Number",
                  textController: _idNumberController,
                  titleColor: Colors.black,
                  hintColor: Colors.grey,
                  hintText: "Enter ID Proof Number",
                  inputFormatters: _getInputFormatters(_selectedIdProof),
                  validator: _validateIdProof,
                ),
                
                const SizedBox(height: 16),
                
                // ID Proof Image
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                          const Text(
                            'ID Proof Image',
                            style: TextStyle(
                fontSize: 16,
                color: Colors.black,
                fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _showImageSourceDialog(isIdProof: true),
                            child: Container(
                height: 150,
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _idProofImage != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_idProofImage!.path),
                          fit: BoxFit.cover,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                          SizedBox(height: 8),
                          Text('Upload ID Proof Image'),
                        ],
                      ),
                            ),
                          ),
                  ],
                ),
                
                const SizedBox(height: 30),
                
                // Submit Button
                            SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    'Submit',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  ),
                ),  
                const SizedBox(height: 30),
                ],
                ),
                ),
              ),
              ],
              ),
        ),
    );
  }
}

// Helper class for uppercase text formatting
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}

int min(int a, int b) {
  return a < b ? a : b;
}