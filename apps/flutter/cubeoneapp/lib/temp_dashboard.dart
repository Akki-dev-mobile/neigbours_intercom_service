import 'package:flutter/material.dart';
import 'package:flutter_commons_widgets/my_scroll_view.dart';

class TempDashboard extends StatefulWidget {
  const TempDashboard({super.key});

  @override
  State<TempDashboard> createState() => _TempDashboardState();
}

class _TempDashboardState extends State<TempDashboard> {
  late CarouselController _carouselViewController;

  @override
  void initState() {
    super.initState();
    _carouselViewController = CarouselController();
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      hasBackButton: false,
      logoPageTitle: true,
      pageBody: Column(
        children: [
          SizedBox(
            height: 200,
            child: CarouselView(
              controller: _carouselViewController,
              // padding: const EdgeInsets.symmetric(horizontal: 20),
              shrinkExtent: 200,
              itemExtent: 330,
              children: List<Widget>.generate(4, (int index) {
                final int actualIndex = index % 4; // Assuming 4 items
                return Container(
                  color: actualIndex.isEven ? Colors.red : Colors.green,
                  child: Center(
                    child: Text('Item $actualIndex'),
                  ),
                );
              }),
            ),
          ),
          Container(
            height: 200,
            color: Colors.green,
          ),
          Container(
            height: 200,
            color: Colors.red,
          ),
          Container(
            height: 200,
            color: Colors.green,
          ),
          Container(
            height: 200,
            color: Colors.red,
          ),
          Container(
            height: 200,
            color: Colors.green,
          ),
        ],
      ),
    );
  }
}
