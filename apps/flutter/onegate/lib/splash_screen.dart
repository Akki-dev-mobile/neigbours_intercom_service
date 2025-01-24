// import 'dart:developer';
//
// import 'package:flutter/material.dart';
// import 'package:provider/provider.dart';
//
//
// class SplashView extends StatefulWidget {
//   const SplashView({super.key});
//
//   @override
//   State<SplashView> createState() => _SplashViewState();
// }
//
// class _SplashViewState extends State<SplashView> {
//   @override
//   void initState() {
//     super.initState();
//     _checkLoginStatus();
//   }
//
//   Future<void> _checkLoginStatus() async {
//     await Future.delayed(const Duration(seconds: 2));
//
// bool intro=    _preferenceUtils.setIsAppIntroShown(true);
//
//     // Check if the user is authenticated
//     final isAuthenticated = await authProvider.checkLoginStatus();
//
//     // Navigate based on authentication status
//     if (intro) {
//       log('User is authenticated');
//       context.go('/home');
//     } else {
//       log('User is not authenticated');
//
//       context.go('/login');
//     }
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Column(
//         mainAxisSize: MainAxisSize.max,
//         mainAxisAlignment: MainAxisAlignment.center,
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           Padding(
//             padding: const EdgeInsets.only(
//               bottom: 50,
//             ),
//             child: Hero(
//               tag: 'splash-logo',
//               child: Image.asset('assets/images/oneapp-logo.png'),
//             ),
//           ),
//           const LinearProgressIndicator(
//             minHeight: 2,
//             color: Colors.red,
//           ),
//         ],
//       ),
//     );
//   }
// }
