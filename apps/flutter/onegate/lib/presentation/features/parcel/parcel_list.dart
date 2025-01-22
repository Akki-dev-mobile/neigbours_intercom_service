import 'package:common_widgets/common_widgets.dart';
import 'package:flutter/material.dart';

class ParcelList extends StatefulWidget {
  const ParcelList({super.key});

  @override
  State<ParcelList> createState() => _ParcelListState();
}

class _ParcelListState extends State<ParcelList> {
  TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController;
  }

  // void _clearSearch() {
  //   _searchController.clear();
  //   setState(() {});
  // }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      pageTitle: 'Parcels',
      pageBody: Column(
        children: [
          CustomForm.textField(
            "Search Members",
            titleColor: Colors.black,
            hintColor: Colors.grey,
            hintText: "Search Member/Units",
            //   suffixIcon: _searchController.text.isNotEmpty
            //       ? IconButton(
            //           icon: const Icon(Icons.clear, color: Colors.black),
            //           onPressed: () => _clearSearch(),
            //         )
            //       : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}
