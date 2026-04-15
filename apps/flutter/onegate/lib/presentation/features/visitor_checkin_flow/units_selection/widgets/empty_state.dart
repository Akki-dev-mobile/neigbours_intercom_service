import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  const EmptyState();

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width > 600;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 40 : 24,
          vertical: isTablet ? 24 : 16,
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final cardMaxWidth = isTablet ? 560.0 : constraints.maxWidth;
            final cardMinWidth = isTablet ? 460.0 : 300.0;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: cardMaxWidth,
                minWidth: cardMinWidth.clamp(0, cardMaxWidth).toDouble(),
              ),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 44 : 32,
                    vertical: isTablet ? 40 : 30,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: isTablet ? 100 : 80,
                        height: isTablet ? 100 : 80,
                        decoration: BoxDecoration(
                          color: const Color(0xffF44336).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.search_off_rounded,
                          color: const Color(0xffF44336),
                          size: isTablet ? 42 : 34,
                        ),
                      ),
                      SizedBox(height: isTablet ? 28 : 22),
                      Text(
                        'No Members Found',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 24 : 21,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xff212427),
                        ),
                      ),
                      SizedBox(height: isTablet ? 14 : 10),
                      Text(
                        'No members match your search. Try a different keyword.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 14,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
