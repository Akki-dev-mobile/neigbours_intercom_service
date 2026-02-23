import 'package:flutter/material.dart';

/// Placeholder screen kept for backwards compatibility with the extracted UI.
///
/// Host apps should route to their own "Neighbour/Neighbors" home.
class NeighbourScreen extends StatelessWidget {
  const NeighbourScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('NeighbourScreen is not implemented in intercom_module.'),
      ),
    );
  }
}

