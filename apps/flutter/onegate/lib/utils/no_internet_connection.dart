import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_onegate/common/internet_check_provider.dart';

class ErrorNoInternetPage extends StatefulWidget {
  const ErrorNoInternetPage({Key? key}) : super(key: key);

  @override
  _ErrorNoInternetPageState createState() => _ErrorNoInternetPageState();
}

class _ErrorNoInternetPageState extends State<ErrorNoInternetPage>
    with SingleTickerProviderStateMixin {
  bool _isRetrying = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _retryConnection() async {
    if (_isRetrying) return;

    setState(() {
      _isRetrying = true;
    });

    final provider = Provider.of<InternetCheckProvider>(context, listen: false);
    await provider.checkInternetAccess();

    // Add a small delay to show the loading state
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() {
        _isRetrying = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return WillPopScope(
      onWillPop: () async => false, // Prevent back navigation
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Enhanced header with gradient background
              Container(
                width: double.infinity,
                margin: EdgeInsets.symmetric(
                  horizontal: isTablet ? 48.0 : 24.0,
                  vertical: isTablet ? 32.0 : 24.0,
                ),
                padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      const Color(0xffF44336).withOpacity(0.08),
                      const Color(0xffff5722).withOpacity(0.03),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.08),
                      spreadRadius: 1,
                      blurRadius: 15,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Icon with gradient background and pulsing animation
                    ScaleTransition(
                      scale: _pulseAnimation,
                      child: Container(
                        padding: EdgeInsets.all(isTablet ? 16 : 12),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xffF44336),
                              Color(0xffD32F2F),
                            ],
                          ),
                          borderRadius:
                              BorderRadius.circular(isTablet ? 16 : 12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xffF44336).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.wifi_off_rounded,
                          color: Colors.white,
                          size: isTablet ? 32 : 24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'No Internet Connection',
                      style: TextStyle(
                        fontSize: isTablet ? 28.0 : 24.0,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff212427),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Please check your internet connection and try again.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isTablet ? 18.0 : 16.0,
                        color: const Color(0xff57636C),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              // Large No Internet Icon
              Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: isTablet ? 48.0 : 24.0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.08),
                        spreadRadius: 1,
                        blurRadius: 15,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.all(isTablet ? 40 : 32),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFF000000),
                            const Color(0xFF424242),
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: isTablet ? 80 : 64,
                      ),
                    ),
                  ),
                ),
              ),
              // Enhanced retry button
              Container(
                margin: EdgeInsets.all(isTablet ? 48.0 : 24.0),
                width: double.infinity,
                height: isTablet ? 56 : 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      const Color(0xFF000000), // Pure black
                      const Color(0xFF424242), // Dark grey
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF000000).withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _isRetrying ? null : _retryConnection,
                    borderRadius: BorderRadius.circular(12),
                    child: Center(
                      child: _isRetrying
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.refresh_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Try Again',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: isTablet ? 16.0 : 14.0,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
