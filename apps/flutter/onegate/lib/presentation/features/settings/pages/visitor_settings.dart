import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_onegate/data/datasources/gate_storage.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/pages/admin_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/pages/gatekeeper_dashboard_view.dart';
import 'package:flutter_onegate/presentation/features/gate_selection/ui/gate_selection_view.dart';
import 'package:flutter_onegate/presentation/features/settings/pages/visitor_Settings_provider.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/purpose/provider/purposeProvider.dart';
import 'package:flutter_onegate/utils/myfluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VisitorSettingsView extends StatefulWidget {
  bool? comingfrom;

  VisitorSettingsView({super.key, this.comingfrom});

  @override
  State<VisitorSettingsView> createState() => _VisitorSettingsViewState();
}

class _VisitorSettingsViewState extends State<VisitorSettingsView> {
  String? selectedGateName;
  final RemoteDataSource remoteDataSource = RemoteDataSource();
  bool _isSaving = false;

  void initState() {
    super.initState();
    getSelectedGate();
  }

  Future<void> getSelectedGate() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      selectedGateName = prefs.getString('selected_gate');
    });
  }

  // Helper method to get setting icons
  IconData _getSettingIcon(String settingType) {
    switch (settingType) {
      case 'address':
        return Icons.location_on;
      case 'approval':
        return Icons.approval;
      case 'card':
        return Icons.badge;
      case 'purpose':
        return Icons.category;
      default:
        return Icons.settings;
    }
  }

  // Helper method to get visitor type icons
  IconData _getVisitorTypeIcon(String categoryName) {
    switch (categoryName.toUpperCase()) {
      case 'DELIVERY':
        return Icons.local_shipping;
      case 'VENDOR':
        return Icons.engineering;
      case 'CABS':
        return Icons.local_taxi;
      case 'MEMBER STAFF':
        return Icons.badge;
      case 'STAFF':
        return Icons.group;
      case 'GUEST':
        return Icons.person;
      default:
        return Icons.category;
    }
  }

  /// Reorders purpose categories in the specified order: GUEST, DELIVERY, STAFF, MEMBER STAFF, VENDOR, CABS
  List<dynamic> _reorderPurposeCategories(List<dynamic> purposes) {
    final reorderedList = <dynamic>[];
    final orderPriority = [
      'GUEST',
      'DELIVERY',
      'STAFF',
      'MEMBER STAFF',
      'VENDOR',
      'CABS'
    ];

    // Add purposes in the specified order
    for (String categoryName in orderPriority) {
      final matchingPurposes = purposes
          .where((purpose) =>
              purpose.categoryName.toUpperCase() == categoryName.toUpperCase())
          .toList();
      reorderedList.addAll(matchingPurposes);
    }

    // Add any remaining purposes that weren't in the priority list
    final remainingPurposes = purposes
        .where((purpose) => !orderPriority.any((priority) =>
            priority.toUpperCase() == purpose.categoryName.toUpperCase()))
        .toList();
    reorderedList.addAll(remainingPurposes);

    return reorderedList;
  }

  // Enhanced success toast
  void _showEnhancedSuccessToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Changes Saved Successfully!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Your visitor settings have been updated',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 3000),
        elevation: 8,
      ),
    );
  }

  // Enhanced error toast
  void _showEnhancedErrorToast(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Save Failed',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Please try again or check your connection',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: const Color(0xffF44336),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(milliseconds: 3000),
        elevation: 8,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => VisitorSettingsProvider()),
        ChangeNotifierProvider(create: (_) => PurposeProvider()),
      ],
      child: Consumer2<VisitorSettingsProvider, PurposeProvider>(
        builder: (context, visitorProvider, purposeProvider, child) {
          final hasChanges = visitorProvider.hasChanges();

          return PopScope(
            canPop: widget.comingfrom == true ? false : true,
            child: MyScrollView(
              hasBackButton: widget.comingfrom == true ? false : true,
              backButtonPressed: () => Navigator.pop(context),
              pageTitle: 'Visitor Settings',
              pageBody: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 16,
                  vertical: isTablet ? 16 : 8,
                ),
                child: Column(
                children: [
                    // Enhanced Settings Section
                    _buildEnhancedSettingCard(
                      context: context,
                      isTablet: isTablet,
                      icon: _getSettingIcon('address'),
                      title: "Visitor's Address",
                      subtitle: "Set visitor's address as mandatory",
                    switchValue: visitorProvider.visitorsAddress,
                    onChanged: visitorProvider.updateVisitorsAddress,
                    ),

                    SizedBox(height: isTablet ? 16 : 12),

                    _buildEnhancedSettingCard(
                      context: context,
                      isTablet: isTablet,
                      icon: _getSettingIcon('approval'),
                      title: "Member's Approval",
                      subtitle: "Set member's approval as mandatory",
                    switchValue: visitorProvider.membersApproval,
                    onChanged: visitorProvider.updateMembersApproval,
                    ),

                    SizedBox(height: isTablet ? 16 : 12),

                    _buildEnhancedSettingCard(
                      context: context,
                      isTablet: isTablet,
                      icon: _getSettingIcon('card'),
                      title: "Visitor Card Number",
                      subtitle: "Set visitor card number as mandatory",
                    switchValue: visitorProvider.visitorCardNumber,
                    onChanged: visitorProvider.updateVisitorCardNumber,
                    ),

                    SizedBox(height: isTablet ? 16 : 12),

                    _buildEnhancedSettingCard(
                      context: context,
                      isTablet: isTablet,
                      icon: _getSettingIcon('purpose'),
                    title: "Visitor's Purpose",
                    subtitle: "Set visitor's purpose as mandatory",
                    switchValue: purposeProvider.isPurposeToggleOn,
                    onChanged: (value) async {
                      await purposeProvider.setPurposeToggleState(value);

                      if (value) {
                        await purposeProvider.fetchPurposes(remoteDataSource);
                      } else {
                        await purposeProvider.clearSavedPurposes();
                      }
                    },
                  ),

                    // Enhanced Visitor Types Grid
                    if (purposeProvider.isPurposeToggleOn) ...[
                      SizedBox(height: isTablet ? 24 : 20),
                      if (purposeProvider.isLoading)
                        _buildEnhancedLoader(context, isTablet)
                      else if (purposeProvider.purposes?.isEmpty ?? true)
                        _buildEmptyState(context, isTablet)
                      else
                        _buildEnhancedVisitorTypesGrid(
                          context: context,
                          isTablet: isTablet,
                          purposeProvider: purposeProvider,
                        ),
                    ],

                    SizedBox(height: isTablet ? 120 : 100),
                  ],
                ),
              ),
              floatingActionButton: (hasChanges || purposeProvider.hasChanges())
                  ? _buildEnhancedConfirmButton(
                      context: context,
                      isTablet: isTablet,
                      onPressed: () async {
                        // Show loading state
                        setState(() {
                          _isSaving = true;
                        });

                        try {
                        await visitorProvider.saveChanges();

                        final selectedPurposes = purposeProvider.purposes!
                            .where((p) => p.isSelected)
                            .toList();

                        await purposeProvider
                            .saveSelectedPurposes(selectedPurposes);

                          // Show enhanced success toast
                          _showEnhancedSuccessToast(context);

                          // Wait a bit to show the toast before navigation
                          await Future.delayed(
                              const Duration(milliseconds: 800));

                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => GateDashboardView(),
                          ),
                        );
                        } catch (e) {
                          // Show error toast
                          _showEnhancedErrorToast(context);
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isSaving = false;
                            });
                          }
                        }
                      },
                      )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEnhancedSettingCard({
    required BuildContext context,
    required bool isTablet,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool switchValue,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withOpacity(0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Enhanced Icon Container
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xffF44336).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: const Color(0xffF44336),
              size: 26,
            ),
          ),

          const SizedBox(width: 16),

          // Enhanced Text Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: const Color(0xff212427),
                        fontSize: isTablet ? 18 : 16,
                      ),
                ),
                SizedBox(height: isTablet ? 6 : 4),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xff57636C),
                        fontSize: isTablet ? 14 : 13,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),

          SizedBox(width: isTablet ? 16 : 12),

          // Enhanced Switch with Green Color
          Transform.scale(
            scale: isTablet ? 1.1 : 1.0,
            child: Switch(
              value: switchValue,
              onChanged: onChanged,
              activeColor: Colors.green.shade600,
              inactiveThumbColor: Colors.grey[400],
              inactiveTrackColor: Colors.grey[300],
              activeTrackColor: Colors.green.shade600.withOpacity(0.3),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedVisitorTypesGrid({
    required BuildContext context,
    required bool isTablet,
    required PurposeProvider purposeProvider,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Enhanced Section Header with Gradient
          Container(
            padding: EdgeInsets.all(isTablet ? 20 : 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xffF44336).withOpacity(0.08),
                  const Color(0xffF44336).withOpacity(0.15),
                  const Color(0xffD32F2F).withOpacity(0.08),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: const Color(0xffF44336).withOpacity(0.2),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                // Enhanced Icon Container
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xffF44336).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.category_rounded,
                    color: const Color(0xffF44336),
                    size: 26,
                  ),
                ),
                SizedBox(width: isTablet ? 16 : 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Visitor Types',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xff212427),
                              fontSize: isTablet ? 22 : 20,
                              letterSpacing: 0.3,
                            ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Select the types of visitors you want to allow',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xff212427).withOpacity(0.7),
                              fontSize: isTablet ? 14 : 12,
                              letterSpacing: 0.1,
                            ),
                      ),
                    ],
                  ),
                ),
                // Animated Selection Counter
                Consumer<PurposeProvider>(
                  builder: (context, purposeProvider, child) {
                    final selectedCount = purposeProvider.purposes
                            ?.where((p) => p.isSelected)
                            .length ??
                        0;
                    final totalCount = purposeProvider.purposes?.length ?? 0;

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 12 : 10,
                        vertical: isTablet ? 8 : 6,
                      ),
                      decoration: BoxDecoration(
                        color: selectedCount > 0
                            ? const Color(0xffF44336)
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$selectedCount/$totalCount',
                        style: TextStyle(
                          color: selectedCount > 0
                              ? Colors.white
                              : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          fontSize: isTablet ? 14 : 12,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          SizedBox(height: isTablet ? 12 : 8),

          // Enhanced Responsive Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount:
                _reorderPurposeCategories(purposeProvider.purposes!).length,
            itemBuilder: (context, index) {
              final reorderedPurposes =
                  _reorderPurposeCategories(purposeProvider.purposes!);
              final purpose = reorderedPurposes[index];
              return _buildEnhancedVisitorTypeCard(
                context: context,
                isTablet: isTablet,
                purpose: purpose,
                onTap: () async {
                  // Find the original index in the unordered list for the update
                  final originalIndex =
                      purposeProvider.purposes!.indexOf(purpose);
                  purposeProvider.updatePurposeSelection(
                    originalIndex,
                    !purpose.isSelected,
                  );
                  await purposeProvider.saveSelectedPurposes(
                    purposeProvider.purposes!,
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedVisitorTypeCard({
    required BuildContext context,
    required bool isTablet,
    required dynamic purpose,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: purpose.isSelected
                ? const Color(0xffF44336)
                : Colors.grey.withOpacity(0.2),
            width: purpose.isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Enhanced Image Container
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: purpose.image != null && purpose.image.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: purpose.image,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          decoration: BoxDecoration(
                            color: const Color(0xffF44336).withOpacity(0.1),
                          ),
                          child: const Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xffF44336),
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          decoration: BoxDecoration(
                            color: const Color(0xffF44336).withOpacity(0.1),
                          ),
                          child: Icon(
                            _getVisitorTypeIcon(purpose.categoryName),
                            color: const Color(0xffF44336),
                            size: 24,
                          ),
                        ),
                      )
                    : Container(
                        decoration: BoxDecoration(
                          color: const Color(0xffF44336).withOpacity(0.1),
                        ),
                        child: Icon(
                          _getVisitorTypeIcon(purpose.categoryName),
                          color: const Color(0xffF44336),
                          size: 24,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 8),

            // Enhanced Text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                purpose.categoryName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight:
                      purpose.isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: purpose.isSelected
                      ? const Color(0xffF44336)
                      : const Color(0xff212427),
                ),
              ),
            ),

            // Selection Indicator
            if (purpose.isSelected)
              Container(
                margin: const EdgeInsets.only(top: 4),
                child: const Icon(
                  Icons.check_circle,
                  color: Color(0xffF44336),
                  size: 16,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEnhancedLoader(BuildContext context, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 40 : 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: const Color(0xffF44336).withOpacity(0.1),
            spreadRadius: 0,
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: Column(
        children: [
          // Gate Animation
          _SettingsGateLoader(isTablet: isTablet),

          SizedBox(height: isTablet ? 20 : 16),
          Text(
            "Loading Visitor Types",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: const Color(0xff212427),
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.w600,
                ),
          ),
          SizedBox(height: isTablet ? 8 : 6),
          Text(
            "Please wait while we fetch available visitor categories",
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                  fontSize: isTablet ? 14 : 12,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isTablet) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 40 : 32),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.category_outlined,
            size: isTablet ? 64 : 48,
            color: Colors.grey[400],
          ),
          SizedBox(height: isTablet ? 16 : 12),
          Text(
            "No visitor types available",
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Colors.grey[600],
                  fontSize: isTablet ? 18 : 16,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedConfirmButton({
    required BuildContext context,
    required bool isTablet,
    required VoidCallback onPressed,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isTablet ? 200 : double.infinity,
      height: isTablet ? 56 : 52,
      margin: EdgeInsets.only(
        left: isTablet ? 0 : 16,
        right: isTablet ? 0 : 16,
        bottom: isTablet ? 16 : 12,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isSaving
              ? [
                  Colors.grey.shade400,
                  Colors.grey.shade500,
                ]
              : [
                  const Color(0xff212427),
                  const Color(0xff57636C),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isSaving ? null : onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: _isSaving
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Saving...',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  )
                : Text(
                    'Confirm',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isTablet ? 18 : 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _SettingsGateLoader extends StatefulWidget {
  final bool isTablet;
  
  const _SettingsGateLoader({required this.isTablet});

  @override
  State<_SettingsGateLoader> createState() => _SettingsGateLoaderState();
}

class _SettingsGateLoaderState extends State<_SettingsGateLoader>
    with TickerProviderStateMixin {
  late AnimationController _gateController;
  late AnimationController _iconController;
  
  late Animation<double> _gateAnimation;
  late Animation<double> _iconAnimation;

  @override
  void initState() {
    super.initState();
    
    // Gate animation controller
    _gateController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    // Icon rotation controller
    _iconController = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    );
    
    // Gate opening/closing animation
    _gateAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _gateController,
      curve: Curves.easeInOut,
    ));
    
    // Icon rotation animation
    _iconAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _iconController,
      curve: Curves.linear,
    ));
    
    // Start animations
    _gateController.repeat(reverse: true);
    _iconController.repeat();
  }

  @override
  void dispose() {
    _gateController.dispose();
    _iconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_gateAnimation, _iconAnimation]),
      builder: (context, child) {
        final gateOffset = _gateAnimation.value * (widget.isTablet ? 25 : 20);
        
        return SizedBox(
          width: widget.isTablet ? 120 : 100,
          height: widget.isTablet ? 80 : 70,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Left gate door
              Positioned(
                left: (widget.isTablet ? 20 : 15) - gateOffset,
                top: widget.isTablet ? 10 : 8,
                child: Container(
                  width: widget.isTablet ? 8 : 6,
                  height: widget.isTablet ? 60 : 50,
                  decoration: BoxDecoration(
                    color: const Color(0xffF44336),
                    borderRadius: BorderRadius.circular(widget.isTablet ? 4 : 3),
                  ),
                ),
              ),
              
              // Right gate door
              Positioned(
                right: (widget.isTablet ? 20 : 15) - gateOffset,
                top: widget.isTablet ? 10 : 8,
                child: Container(
                  width: widget.isTablet ? 8 : 6,
                  height: widget.isTablet ? 60 : 50,
                  decoration: BoxDecoration(
                    color: const Color(0xffF44336),
                    borderRadius: BorderRadius.circular(widget.isTablet ? 4 : 3),
                  ),
                ),
              ),
              
              // Center rotating gate icon
              Transform.rotate(
                angle: _iconAnimation.value * 2 * 3.14159,
                child: Container(
                  width: widget.isTablet ? 50 : 40,
                  height: widget.isTablet ? 50 : 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xffF44336),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.sensor_door,
                    color: const Color(0xffF44336),
                    size: widget.isTablet ? 24 : 20,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
