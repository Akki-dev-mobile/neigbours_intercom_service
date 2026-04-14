// import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/bloc/admin_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/bloc/gatekeeper_dashboard_bloc.dart';
// import 'package:lottie/lottie.dart';
import 'package:shimmer/shimmer.dart';

class DashboardBlocks extends StatelessWidget {
  final int? inBook;
  final int? outBook;
  final Bloc bloc;

  const DashboardBlocks({
    super.key,
    this.inBook,
    this.outBook,
    required this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;

    // Compute a common, responsive card height based on the In-Out card's sizing rules
    final double targetWidth = screenWidth * (isTablet ? 0.22 : 0.3);
    final double cardWidth = targetWidth.clamp(120.0, 180.0);
    final double commonCardHeight = (cardWidth * 1.6).clamp(240.0, 320.0);

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 8 : 4,
        vertical: isTablet ? 16 : 12,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Enhanced In-Out Card
          _buildEnhancedInOutCard(context, isTablet, commonCardHeight),

          SizedBox(width: isTablet ? 16 : 12),

          // Enhanced Visitor Cards Row (side-by-side)
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _buildEnhancedVisitorInCard(
                      context, isTablet, commonCardHeight),
                ),
                SizedBox(width: isTablet ? 16 : 12),
                Expanded(
                  child: _buildEnhancedVisitorOutCard(
                      context, isTablet, commonCardHeight),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Enhanced In-Out Card with modern styling
  Widget _buildEnhancedInOutCard(
      BuildContext context, bool isTablet, double commonCardHeight) {
    final screenWidth = MediaQuery.of(context).size.width;
    final double targetWidth = screenWidth * (isTablet ? 0.22 : 0.3);
    final double cardWidth = targetWidth.clamp(120.0, 180.0);
    final double cardHeight = commonCardHeight;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: cardWidth,
      height: cardHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 1.0],
          colors: [
            Color(0xffFFE8C6),
            Color(0xffFFA726),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
        border: Border.all(
          color: const Color(0xffFFCC80).withOpacity(0.45),
          width: 0.30,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: isTablet ? 18 : 14,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xffFFCC80).withOpacity(0.22),
            blurRadius: isTablet ? 10 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CardTexturePainter(
                    accentColor: const Color(0xffFB8C00),
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              elevation: isTablet ? 5 : 4,
              shadowColor: Colors.black.withOpacity(0.15),
              child: InkWell(
                borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (bloc is GatekeeperDashboardBloc) {
                    bloc.add(GDInAndOutButtonPressedEvent());
                  } else if (bloc is AdminDashboardBloc) {
                    bloc.add(ADInAndOutButtonPressedEvent());
                  }
                },
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Enhanced icon container with better shadows
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          padding: EdgeInsets.all(isTablet ? 16 : 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(isTablet ? 20 : 16),
                            border: Border.all(
                              color: const Color(0xffFFCC80).withOpacity(0.45),
                              width: 0.30,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: isTablet ? 12 : 8,
                                offset: const Offset(0, 4),
                              ),
                              BoxShadow(
                                color:
                                    const Color(0xffFFCC80).withOpacity(0.25),
                                blurRadius: isTablet ? 6 : 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CachedNetworkImage(
                            height: isTablet ? 64 : 48,
                            width: isTablet ? 64 : 48,
                            fit: BoxFit.contain,
                            imageUrl:
                                'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/visitor_book_31e76df597.gif?updated_at=2023-08-23T06:26:37.400Z',
                            placeholder: (context, url) => Container(
                              height: isTablet ? 64 : 48,
                              width: isTablet ? 64 : 48,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: SizedBox(
                                  width: isTablet ? 24 : 20,
                                  height: isTablet ? 24 : 20,
                                  child: const DashboardLoaderIcon(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xffFFCC80),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Container(
                              height: isTablet ? 64 : 48,
                              width: isTablet ? 64 : 48,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.book_rounded,
                                color: const Color(0xffFFCC80),
                                size: isTablet ? 32 : 24,
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Enhanced title
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'In - Out Book',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xff212427),
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),

                      // Enhanced count
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 16 : 12,
                          vertical: isTablet ? 8 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius:
                              BorderRadius.circular(isTablet ? 16 : 12),
                          border: Border.all(
                            color: const Color(0xffFFCC80).withOpacity(0.45),
                            width: 0.10,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: isTablet ? 8 : 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          "${(outBook ?? 0) + (inBook ?? 0)}",
                          style: TextStyle(
                            color: const Color(0xff212427),
                            fontSize: isTablet ? 28 : 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced Visitor-In Card with modern styling
  Widget _buildEnhancedVisitorInCard(
      BuildContext context, bool isTablet, double commonCardHeight) {
    final double vCardHeight = commonCardHeight;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: vCardHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 1.0],
          colors: [
            Color(0xffD8F0D9),
            Color(0xff66BB6A),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(
          color: const Color(0xff81C784).withOpacity(0.45),
          width: 0.30,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: isTablet ? 18 : 14,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xff81C784).withOpacity(0.22),
            blurRadius: isTablet ? 10 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CardTexturePainter(
                    accentColor: const Color(0xff2E7D32),
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              elevation: isTablet ? 4 : 3,
              shadowColor: Colors.black.withOpacity(0.12),
              child: InkWell(
                borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                onTap: () {
                  HapticFeedback.lightImpact();
                  bloc is GatekeeperDashboardBloc
                      ? bloc.add(GDVisitorsInButtonPressedEvent())
                      : bloc.add(ADVisitorsInButtonPressedEvent());
                },
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          padding: EdgeInsets.all(isTablet ? 16 : 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(isTablet ? 16 : 12),
                            border: Border.all(
                              color: const Color(0xff81C784).withOpacity(0.45),
                              width: 0.30,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: isTablet ? 8 : 6,
                                offset: const Offset(0, 3),
                              ),
                              BoxShadow(
                                color:
                                    const Color(0xff81C784).withOpacity(0.25),
                                blurRadius: isTablet ? 4 : 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Transform(
                            transform: Matrix4.rotationY(math.pi),
                            alignment: Alignment.center,
                            child: Image(
                              image: const CachedNetworkImageProvider(
                                'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/visitor_in_01b37e79e9.gif?updated_at=2023-08-23T06:26:37.878Z',
                              ),
                              height: isTablet ? 64 : 48,
                              width: isTablet ? 64 : 48,
                              fit: BoxFit.contain,
                              gaplessPlayback: true,
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Container(
                                  height: isTablet ? 40 : 32,
                                  width: isTablet ? 40 : 32,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      width: isTablet ? 16 : 12,
                                      height: isTablet ? 16 : 12,
                                      child: const DashboardLoaderIcon(
                                        strokeWidth: 1.5,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Color(0xff81C784),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                height: isTablet ? 40 : 32,
                                width: isTablet ? 40 : 32,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Icon(
                                  Icons.person_add_rounded,
                                  color: const Color(0xff81C784),
                                  size: isTablet ? 24 : 20,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Visitor-In',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 16 : 12,
                          vertical: isTablet ? 8 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius:
                              BorderRadius.circular(isTablet ? 16 : 12),
                          border: Border.all(
                            color: const Color(0xff81C784).withOpacity(0.45),
                            width: 0.10,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: isTablet ? 8 : 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          inBook.toString(),
                          style: TextStyle(
                            color: const Color(0xff212427),
                            fontSize: isTablet ? 28 : 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Enhanced Visitor-Out Card with modern styling
  Widget _buildEnhancedVisitorOutCard(
      BuildContext context, bool isTablet, double commonCardHeight) {
    final double vCardHeight = commonCardHeight;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: vCardHeight,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0.0, 1.0],
          colors: [
            Color(0xffFFE1E4),
            Color(0xffEF9A9A),
          ],
        ),
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        border: Border.all(
          color: const Color(0xffFFAB91).withOpacity(0.45),
          width: 0.30,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: isTablet ? 18 : 14,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: const Color(0xffFFAB91).withOpacity(0.22),
            blurRadius: isTablet ? 10 : 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
        child: Stack(
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _CardTexturePainter(
                    accentColor: const Color(0xffD95D5D),
                  ),
                ),
              ),
            ),
            Material(
              color: Colors.transparent,
              elevation: isTablet ? 4 : 3,
              shadowColor: Colors.black.withOpacity(0.12),
              child: InkWell(
                borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                onTap: () {
                  HapticFeedback.lightImpact();
                  bloc is GatekeeperDashboardBloc
                      ? bloc.add(GDVisitorsOutButtonPressedEvent())
                      : bloc.add(ADVisitorsOutButtonPressedEvent());
                },
                child: Padding(
                  padding: EdgeInsets.all(isTablet ? 16 : 12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          padding: EdgeInsets.all(isTablet ? 16 : 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(isTablet ? 16 : 12),
                            border: Border.all(
                              color: const Color(0xffFFAB91).withOpacity(0.45),
                              width: 0.30,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: isTablet ? 8 : 6,
                                offset: const Offset(0, 3),
                              ),
                              BoxShadow(
                                color: const Color(0xffFFE5E0).withOpacity(0.3),
                                blurRadius: isTablet ? 4 : 3,
                                offset: const Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Image(
                            image: const CachedNetworkImageProvider(
                              'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/visitor_out_c9f84ddb97.gif?updated_at=2023-08-23T06:26:37.786Z',
                            ),
                            height: isTablet ? 64 : 48,
                            width: isTablet ? 64 : 48,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                height: isTablet ? 40 : 32,
                                width: isTablet ? 40 : 32,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade100,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Center(
                                  child: SizedBox(
                                    width: isTablet ? 16 : 12,
                                    height: isTablet ? 16 : 12,
                                    child: const DashboardLoaderIcon(
                                      strokeWidth: 1.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Color(0xffFFAB91),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                              height: isTablet ? 40 : 32,
                              width: isTablet ? 40 : 32,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.person_remove_rounded,
                                color: const Color(0xffFFAB91),
                                size: isTablet ? 24 : 20,
                              ),
                            ),
                          ),
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Visitor-Out',
                          maxLines: 1,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.black,
                            fontSize: isTablet ? 20 : 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 16 : 12,
                          vertical: isTablet ? 8 : 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius:
                              BorderRadius.circular(isTablet ? 16 : 12),
                          border: Border.all(
                            color: const Color(0xffFFAB91).withOpacity(0.45),
                            width: 0.10,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: isTablet ? 8 : 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          outBook.toString(),
                          style: TextStyle(
                            color: const Color(0xff212427),
                            fontSize: isTablet ? 28 : 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CardTexturePainter extends CustomPainter {
  final Color accentColor;

  const _CardTexturePainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final stripePaint = Paint()
      ..color = Colors.white.withOpacity(0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (double x = -size.height; x < size.width; x += 14) {
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.height, size.height), stripePaint);
    }

    final accentStripePaint = Paint()
      ..color = accentColor.withOpacity(0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;

    for (double x = -size.height + 7; x < size.width; x += 18) {
      canvas.drawLine(Offset(x, 0), Offset(x + size.height, size.height),
          accentStripePaint);
    }

    final dotPaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..style = PaintingStyle.fill;

    for (double y = 10; y < size.height; y += 24) {
      for (double x = 10; x < size.width; x += 24) {
        if (((x + y) ~/ 24) % 2 == 0) {
          canvas.drawCircle(Offset(x, y), 1.2, dotPaint);
        }
      }
    }

    // Subtle grain particles overlay for tactile card texture.
    // Deterministic distribution keeps visual stable across rebuilds.
    final baseParticles = (size.width * size.height / 95).round();
    final int particleCount = baseParticles.clamp(120, 420).toInt();
    final whiteGrainPaint = Paint()..style = PaintingStyle.fill;
    final accentGrainPaint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < particleCount; i++) {
      final double px = ((i * 37) % 1000) / 1000 * size.width;
      final double py = ((i * 91) % 1000) / 1000 * size.height;
      final bool accent = i % 9 == 0;

      if (accent) {
        accentGrainPaint.color = accentColor.withOpacity(0.075);
        canvas.drawCircle(Offset(px, py), 0.75, accentGrainPaint);
      } else {
        whiteGrainPaint.color = Colors.white.withOpacity(0.09);
        canvas.drawCircle(Offset(px, py), 0.60, whiteGrainPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CardTexturePainter oldDelegate) {
    return oldDelegate.accentColor != accentColor;
  }
}

class DashboardBlocksSkeleton extends StatelessWidget {
  const DashboardBlocksSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        margin: EdgeInsets.symmetric(
          horizontal: isTablet ? 8 : 4,
          vertical: isTablet ? 16 : 12,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Skeleton for In-Out Card
            Container(
              width: isTablet ? 160 : 120,
              height: isTablet ? 280 : 240,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
              ),
            ),
            SizedBox(width: isTablet ? 16 : 12),
            // Skeleton for Visitor Cards
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: isTablet ? 132 : 114,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
                    ),
                  ),
                  SizedBox(height: isTablet ? 16 : 12),
                  Container(
                    height: isTablet ? 132 : 114,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
