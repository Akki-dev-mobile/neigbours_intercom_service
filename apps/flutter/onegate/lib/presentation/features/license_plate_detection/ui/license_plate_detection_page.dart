import 'dart:io';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/repositories/license_plate_repository.dart';
import 'package:flutter_onegate/presentation/features/license_plate_detection/bloc/license_plate_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';

class LicensePlateDetectionPage extends StatelessWidget {
  const LicensePlateDetectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => LicensePlateBloc(LicensePlateRepository()),
      child: Scaffold(
        appBar: AppBar(title: Text(context.tr('License Plate Detection'))),
        body: const LicensePlateBody(),
      ),
    );
  }
}

class LicensePlateBody extends StatefulWidget {
  const LicensePlateBody({super.key});

  @override
  _LicensePlateBodyState createState() => _LicensePlateBodyState();
}

class _LicensePlateBodyState extends State<LicensePlateBody> {
  File? _selectedImage;

  final picker = ImagePicker();

  Future<void> _pickImage(BuildContext context) async {
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });

      context.read<LicensePlateBloc>().add(UploadImageEvent(_selectedImage!));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedImage != null)
              Image.file(_selectedImage!, height: 250),
            const SizedBox(height: 20),
            BlocBuilder<LicensePlateBloc, LicensePlateState>(
              builder: (context, state) {
                if (state is LicensePlateLoading) {
                  return const DashboardLoaderIcon();
                } else if (state is LicensePlateSuccess) {
                  return Text(
                    context.tr('Detected Plate: {plate}',
                        params: {'plate': state.plateText}),
                    style: const TextStyle(fontSize: 18, color: Colors.green),
                  );
                } else if (state is LicensePlateFailure) {
                  return Text(
                    context
                        .tr('Error: {error}', params: {'error': state.error}),
                    style: const TextStyle(fontSize: 16, color: Colors.red),
                  );
                }
                return Text(context.tr('Please select an image to detect.'));
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _pickImage(context),
              child: Text(context.tr('Pick Image from Gallery')),
            ),
          ],
        ),
      ),
    );
  }
}
