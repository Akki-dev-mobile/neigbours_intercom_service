import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/utils/localization_helper.dart';

class AssignCardPopup extends StatefulWidget {
  final int visitorId;
  final String visitorName;
  final Function(String) onCardAssigned;

  const AssignCardPopup({
    Key? key,
    required this.visitorId,
    required this.visitorName,
    required this.onCardAssigned,
  }) : super(key: key);

  @override
  State<AssignCardPopup> createState() => _AssignCardPopupState();
}

class _AssignCardPopupState extends State<AssignCardPopup> {
  final TextEditingController _cardNumberController = TextEditingController();
  final RemoteDataSource _remoteDataSource = RemoteDataSource();
  bool _isLoading = false;

  @override
  void dispose() {
    _cardNumberController.dispose();
    super.dispose();
  }

  /// Helper method to format card number with "V " prefix
  String _formatCardNumber(String cardNumber) {
    // Remove any existing "V " prefix and whitespace
    String cleanNumber = cardNumber.trim();
    if (cleanNumber.startsWith('V ')) {
      cleanNumber = cleanNumber.substring(2);
    } else if (cleanNumber.startsWith('V')) {
      cleanNumber = cleanNumber.substring(1);
    }

    // Add "V " prefix to the clean number
    return 'V $cleanNumber';
  }

  Future<void> _saveCardNumber() async {
    if (_cardNumberController.text.trim().isEmpty) {
      _showErrorToast(context.tr('Please enter a card number'));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final rawCardNumber = _cardNumberController.text.trim();
      final success = await _remoteDataSource.updateVisitorCardNumber(
        widget.visitorId,
        rawCardNumber,
      );

      if (success) {
        // Format the card number with "V " prefix for display
        final formattedCardNumber = _formatCardNumber(rawCardNumber);

        // Call the callback with the formatted card number
        widget.onCardAssigned(formattedCardNumber);

        // Close the popup
        Navigator.of(context).pop();

        // Show enhanced green success toast
        _showEnhancedSuccessToast();
      } else {
        _showErrorToast(
          context.tr('Failed to assign card number. Please try again.'),
        );
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      _showErrorToast(
        context.tr('Error: {error}', params: {'error': e.toString()}),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorToast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD32F2F), // OneGate red color
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showEnhancedSuccessToast() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      context.tr('Card Assigned Successfully'),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.tr(
                        'Card number {cardNumber} has been assigned to {visitorName}',
                        params: {
                          'cardNumber': _cardNumberController.text.trim(),
                          'visitorName': widget.visitorName,
                        },
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xFF4CAF50), // Green color
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );

    // Add haptic feedback for success
    HapticFeedback.lightImpact();
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 768;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: isTablet ? 500 : double.infinity,
        constraints: BoxConstraints(
          maxWidth: isTablet ? 500 : MediaQuery.of(context).size.width * 0.9,
        ),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.white, Color(0xFFF8F9FA)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 30,
              offset: const Offset(0, 15),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Icon with OneGate theme
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF44336), // OneGate red color
                      Color(0xFFD32F2F),
                    ],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF44336).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.credit_card,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),

              // Title with OneGate typography
              Text(
                context.tr('Assign Card'),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xff212427), // OneGate primary text color
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),

              // Subtitle
              Text(
                context.tr(
                  'Assign a card number to {visitorName}',
                  params: {'visitorName': widget.visitorName},
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xff57636C), // OneGate muted text color
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Card Number Input with OneGate styling
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _cardNumberController,
                  enabled: !_isLoading,
                  keyboardType: TextInputType.number, // Numeric keyboard only
                  cursorColor: Colors.black, // Black blinking cursor
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly, // Only allow digits
                  ],
                  decoration: InputDecoration(
                    hintText: context.tr('Enter card number'),
                    hintStyle: const TextStyle(
                      color: Color(0xff57636C),
                      fontSize: 16,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF44336).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.credit_card,
                        color: Color(0xFFF44336),
                        size: 20,
                      ),
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xff212427),
                  ),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _saveCardNumber(),
                ),
              ),
              const SizedBox(height: 32),

              // Action Buttons with OneGate styling
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE0E0E0),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          context.tr('Cancel'),
                          style: TextStyle(
                            color: const Color(0xff57636C),
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Color(0xff212427), // Black color
                            Color(0xff57636C), // Grey color
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xff212427).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _saveCardNumber,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: DashboardLoaderIcon(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white),
                                ),
                              )
                            : Text(
                                context.tr('Save'),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  letterSpacing: 0.5,
                                ),
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
