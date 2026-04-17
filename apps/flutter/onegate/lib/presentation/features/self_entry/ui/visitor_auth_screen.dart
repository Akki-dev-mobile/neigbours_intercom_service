// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter_onegate/presentation/widgets/custom_numpad.dart';
import 'package:flutter_onegate/presentation/widgets/enhanced_input_field.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';

class VisitorAuthScreen extends StatefulWidget {
  const VisitorAuthScreen({super.key});

  @override
  State<VisitorAuthScreen> createState() => _VisitorAuthScreenState();
}

class _VisitorAuthScreenState extends State<VisitorAuthScreen>
    with TickerProviderStateMixin {
  final TextEditingController _mobileCtrl = TextEditingController();
  final TextEditingController _otpCtrl = TextEditingController();

  int _step = 0; // 0: mobile, 1: otp
  // Keep _countryCode for future API integration
  String _countryCode = '+91'; // ignore: unused_field
  String selectedCountryCode = 'IN';
  int _currentAd = 0;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  // These methods are no longer needed as we're using EnhancedNumPad instead

  void _onSubmit() {
    HapticFeedback.mediumImpact();
    if (_step == 0) {
      if (_mobileCtrl.text.length == 10) {
        setState(() => _step = 1);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.tr('Please enter a 10-digit number'))),
        );
      }
    } else {
      // Trigger OTP verify callback here
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context
                .tr('Verifying OTP {otp}', params: {'otp': _otpCtrl.text}))),
      );
    }
  }

  // Ads carousel copied from Self Check-in dashboard style
  Widget _buildAdsCarousel(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    final List<Map<String, String>> ads = [
      {
        'image':
            'https://images.unsplash.com/photo-1631195092568-a1030d926fd3?auto=format&fit=crop&w=2070&q=80',
        'title': 'onegate',
      },
      {
        'image':
            'https://images.unsplash.com/photo-1496065187959-7f07b8353c55?auto=format&fit=crop&w=2070&q=80',
        'title': 'oneapp',
      },
      {
        'image':
            'https://images.unsplash.com/photo-1580041065738-e72023775cdc?auto=format&fit=crop&w=2070&q=80',
        'title': 'onesociety',
      },
    ];

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CarouselSlider(
          items: ads.map((ad) => _buildAdCard(context, ad, isTablet)).toList(),
          options: CarouselOptions(
            height: MediaQuery.of(context).size.height *
                0.25, // Slightly smaller height
            enlargeCenterPage: false,
            autoPlay: true,
            autoPlayCurve: Curves.fastOutSlowIn,
            enableInfiniteScroll: true,
            autoPlayAnimationDuration: const Duration(milliseconds: 900),
            viewportFraction: isTablet ? 0.98 : 0.98,
            onPageChanged: (index, reason) {
              setState(() {
                _currentAd = index;
              });
            },
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: ads.asMap().entries.map((entry) {
            final i = entry.key;
            final isActive = i == _currentAd;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: isActive ? 16 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF111827)
                    : const Color(0xFFD1D5DB),
                borderRadius: BorderRadius.circular(4),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildAdCard(
    BuildContext context,
    Map<String, String> ad,
    bool isTablet,
  ) {
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 16 : 12,
        vertical: isTablet ? 12 : 8,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
        image: DecorationImage(
          image: NetworkImage(ad['image'] ?? ''),
          fit: BoxFit.cover,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.05),
              Colors.black.withOpacity(0.45),
            ],
          ),
        ),
        padding: EdgeInsets.all(isTablet ? 24 : 16),
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 12 : 10,
              vertical: isTablet ? 6 : 4,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(isTablet ? 12 : 10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              (ad['title'] ?? '').toString(),
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                fontWeight: FontWeight.w700,
                color: const Color(0xff212427),
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Dismiss keyboard when tapping outside
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        extendBodyBehindAppBar: true,
        extendBody: true,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              pinned: true,
              automaticallyImplyLeading: false,
              elevation: 0,
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(
                        MediaQuery.of(context).size.width > 600 ? 8 : 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xffF44336),
                          const Color(0xffD32F2F),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(
                          MediaQuery.of(context).size.width > 600 ? 10 : 8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xffF44336).withOpacity(0.3),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.sensor_door_rounded,
                      color: Colors.white,
                      size: MediaQuery.of(context).size.width > 600 ? 20 : 16,
                    ),
                  ),
                  SizedBox(
                      width: MediaQuery.of(context).size.width > 600 ? 12 : 10),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 300),
                    style: TextStyle(
                      color: const Color(0xff212427),
                      fontSize:
                          MediaQuery.of(context).size.width > 600 ? 24 : 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                    child: Text(
                      'Visitor Check-in',
                    ),
                  ),
                ],
              ),
            ),
            // Ads carousel below header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: _buildAdsCarousel(context),
              ),
            ),
            SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: MediaQuery.of(context).size.height *
                    0.6, // Decreased height for no scrolling
                child: Column(
                  children: [
                    // Input field
                    const SizedBox(height: 16),

                    // Enhanced input field similar to self_entry_view
                    _step == 0
                        ? EnhancedInputField(
                            controller: _mobileCtrl,
                            isMobileField: true,
                            label: context.tr('Visitor Mobile Number'),
                            hint: context.tr('0123456789'),
                            maxLength: 10,
                            prefixWidget: CountryCodePicker(
                              initialSelection: 'IN',
                              favorite: ['IN'],
                              showFlagMain: true,
                              showFlagDialog: true,
                              boxDecoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                              ),
                              barrierColor: Theme.of(context)
                                  .colorScheme
                                  .surface
                                  .withOpacity(0.5),
                              closeIcon: Icon(
                                Icons.close,
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              searchDecoration: InputDecoration(
                                prefixIcon: Icon(
                                  Icons.search,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                hintText: context.tr('Search'),
                                hintStyle: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    style: BorderStyle.solid,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(15),
                                  borderSide: BorderSide(
                                    style: BorderStyle.solid,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              textStyle: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontSize: 18,
                              ),
                              dialogTextStyle: TextStyle(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                              onChanged: (CountryCode countryCode) {
                                setState(() {
                                  selectedCountryCode = countryCode.code!;
                                });
                              },
                            ),
                            onClear: () {
                              setState(() {
                                _mobileCtrl.clear();
                              });
                            },
                            isTablet: MediaQuery.of(context).size.width > 600,
                          )
                        : EnhancedInputField(
                            controller: _otpCtrl,
                            isMobileField: false,
                            label: context
                                .tr('Enter OTP Sent to Your Mobile Number'),
                            hint: context.tr('123456'),
                            maxLength: 6,
                            onClear: () {
                              setState(() {
                                _otpCtrl.clear();
                              });
                            },
                            isTablet: MediaQuery.of(context).size.width > 600,
                          ),

                    const SizedBox(height: 24),

                    // Enhanced numpad with reduced size
                    EnhancedNumPad(
                      buttonSize: MediaQuery.of(context).size.width > 600
                          ? 64
                          : 56, // Adjusted button size
                      onType: (value) {
                        if (value == '-') {
                          // Handle backspace
                          if (_step == 0 && _mobileCtrl.text.isNotEmpty) {
                            setState(() {
                              _mobileCtrl.text = _mobileCtrl.text
                                  .substring(0, _mobileCtrl.text.length - 1);
                            });
                          } else if (_step == 1 && _otpCtrl.text.isNotEmpty) {
                            setState(() {
                              _otpCtrl.text = _otpCtrl.text
                                  .substring(0, _otpCtrl.text.length - 1);
                            });
                          }
                        } else {
                          // Handle number input
                          if (_step == 0 && _mobileCtrl.text.length < 10) {
                            setState(() {
                              _mobileCtrl.text += value;
                            });
                          } else if (_step == 1 && _otpCtrl.text.length < 6) {
                            setState(() {
                              _otpCtrl.text += value;
                            });
                          }
                        }
                      },
                      numberStyle: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                      rightWidget: EnhancedSubmitButton(
                        onPressed: _onSubmit,
                      ),
                    )
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Removed the original _buildInputField method as we're using EnhancedInputField
}

// Removed StepProgressIndicator class as we're not using it anymore

// Removed CustomNumericPad class as we're using EnhancedNumPad instead
