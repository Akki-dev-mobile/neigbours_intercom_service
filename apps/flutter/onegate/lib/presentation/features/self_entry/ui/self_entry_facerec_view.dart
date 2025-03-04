import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class SelfEntryFacerecView extends StatefulWidget {
  const SelfEntryFacerecView({super.key});

  @override
  State<SelfEntryFacerecView> createState() => _SelfEntryFacerecViewState();
}

class _SelfEntryFacerecViewState extends State<SelfEntryFacerecView> {
  File? _image;
  final ImagePicker _picker = ImagePicker();
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
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
                  : "Liveness Failed")),
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

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageBody: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _image == null
                ? const Text('No image selected.')
                : Image.file(_image!),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Capture Photo'),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _uploadImage,
              child: const Text('Upload Photo'),
            ),
            ElevatedButton(
              onPressed: _showNameInputDialog,
              child: const Text('Register Photo'),
            ),
          ],
        ),
      ),
    );
  }
}
