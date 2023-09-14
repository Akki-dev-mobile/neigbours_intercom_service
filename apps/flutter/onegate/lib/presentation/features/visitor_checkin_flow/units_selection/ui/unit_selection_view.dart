// ignore_for_file: prefer_const_constructors

import 'dart:async';
import 'package:chips_choice/chips_choice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:common_widgets/common_widgets.dart';

import '../../request_permission/ui/request_permission_view.dart';

class UnitSelectionView extends StatefulWidget {
  const UnitSelectionView({Key? key}) : super(key: key);

  @override
  State<UnitSelectionView> createState() => _UnitSelectionViewState();
}

class _UnitSelectionViewState extends State<UnitSelectionView> {
  List<int> selectedIndices = [];
  List<String> items = [
    'A-101',
    'A-102',
    'A-103',
    'A-104',
    'A-105',
    'A-106',
    'A-107',
    'A-108',
    'A-109',
    'A-110',
    'A-111',
    'A-112',
    'A-113',
    'A-114',
    'A-115',
    'A-116',
    'A-117',
    'A-118',
    'A-119',
    'A-120',
    'A-101',
    'A-102',
    'A-103',
    'A-104',
    'A-105',
    'A-106',
    'A-107',
    'A-108',
    'A-109',
    'A-110',
    'A-111',
    'A-112',
    'A-113',
    'A-114',
    'A-115',
    'A-116',
    'A-117',
    'A-118',
    'A-119',
    'A-120',
    'A-119',
    'A-120',
    'A-101',
    'A-102',
    'A-103',
    'A-104',
    'A-105',
    'A-106',
    'A-107',
    'A-108',
    'A-109',
    'A-110',
    'A-111',
    'A-112',
    'A-113',
    'A-114',
    'A-115',
    'A-116',
    'A-117',
    'A-118',
    'A-119',
    'A-120',
    'A-106',
    'A-107',
    'A-108',
    'A-109',
    'A-110',
    'A-111',
    'A-112',
    'A-113',
    'A-114',
    'A-115',
    'A-116',
    'A-117',
    'A-118',
    'A-119',
    'A-120',
    'A-119',
    'A-120',
    'A-101',
    'A-102',
    'A-103',
    'A-104',
    'A-105',
    'A-106',
    'A-107',
    'A-108',
    'A-109',
    'A-110',
    'A-111',
    'A-112',
    'A-113',
    'A-114',
    'A-115',
    'A-116',
    'A-117',
    'A-118',
    'A-119',
    'A-1211',
  ];

  List<String> anotherList = [];
  // late String itemCount;

  String getSelectedItemsText() {
    final itemCount = anotherList.length;

    if (itemCount == 0) {
      return 'No Members are selected';
    } else if (itemCount == 1) {
      return '1 Member is selected';
    } else {
      return '$itemCount Members are selected';
    }
  }

  List<Tab> unitTypeTabs = [
    Tab(text: 'Units'),
    Tab(text: 'Members'),
  ];

  String getCommaSeparatedValues() {
    return anotherList.join(', ');
  }

  String? selectedBuilding;
  List<String> options = [
    'Society Office',
    'Building A',
    'Building B',
    'Building C',
    'Building D',
    'Building E',
  ];

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      isScrollable: false,
      pageTitle: 'Select Units/Members',
      pageBody: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DefaultTabController(
            length: unitTypeTabs.length,
            child: Column(
              children: [
                TabBar(
                  tabs: unitTypeTabs,
                  indicatorColor: Colors.red,
                  labelColor: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.7),
                  unselectedLabelColor: Theme.of(context)
                      .colorScheme
                      .onBackground
                      .withOpacity(0.7),
                  dividerColor: Colors.transparent,
                  labelStyle: TextStyle(
                    fontSize: 18,
                  ),
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: TabBarView(
                    physics: NeverScrollableScrollPhysics(),
                    children: [
                      Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: 15,
                            ),
                            child: ChipsChoice<String>.single(
                              // scrollToSelectedOnChanged: true,
                              choiceStyle: C2ChipStyle.outlined(
                                color:
                                    Theme.of(context).colorScheme.onBackground,
                                selectedStyle: C2ChipStyle.filled(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onBackground,
                                  foregroundColor:
                                      Theme.of(context).colorScheme.background,
                                  backgroundOpacity: 1,
                                ),
                                height: 40,
                              ),
                              choiceCheckmark: true,
                              value: selectedBuilding,
                              scrollPhysics: BouncingScrollPhysics(),
                              onChanged: (value) {
                                setState(() {
                                  selectedBuilding = value;
                                });
                              },
                              choiceItems: C2Choice.listFrom<String, String>(
                                source: options,
                                value: (i, v) => v,
                                label: (i, v) => v,
                              ),
                            ),
                          ),
                          Expanded(
                            child: GridView.builder(
                              padding: EdgeInsets.only(
                                bottom: 150,
                              ),
                              shrinkWrap: true,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                childAspectRatio: 2,
                                crossAxisCount: 3,
                                crossAxisSpacing: 10.0,
                                mainAxisSpacing: 10.0,
                              ),
                              itemCount: items.length,
                              itemBuilder: (BuildContext context, int index) {
                                return GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      if (selectedIndices.contains(index)) {
                                        selectedIndices.remove(index);
                                      } else {
                                        selectedIndices.add(index);
                                      }
                                      if (kDebugMode) {
                                        print(
                                            'Selected Indices: $selectedIndices');
                                      }
                                      anotherList.clear();
                                      for (int index in selectedIndices) {
                                        if (index >= 0 &&
                                            index < items.length) {
                                          anotherList.add(items[index]);
                                        }
                                      }
                                      if (kDebugMode) {
                                        print('Another List: $anotherList');
                                      }
                                    });
                                  },
                                  child: Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      color: selectedIndices.contains(index)
                                          ? Theme.of(context)
                                              .colorScheme
                                              .onBackground
                                              .withOpacity(0.9)
                                          : Theme.of(context)
                                              .colorScheme
                                              .background,
                                      border: Border.all(
                                        color: selectedIndices.contains(index)
                                            ? Theme.of(context)
                                                .colorScheme
                                                .onBackground
                                            : Theme.of(context)
                                                .colorScheme
                                                .onBackground
                                                .withOpacity(0.5),
                                        width: 1,
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        items[index],
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 22,
                                          color: selectedIndices.contains(index)
                                              ? Theme.of(context)
                                                  .colorScheme
                                                  .background
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .onBackground,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                          SizedBox(height: 120),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          CustomForm.textField(
                            "Search",
                            titleColor:
                                Theme.of(context).colorScheme.onBackground,
                            hintColor: Theme.of(context).colorScheme.onPrimary,
                            hintText: 'Search Members/Units',
                            textCapitalization: TextCapitalization.words,
                            prefixIcon: IconButton(
                              onPressed: () {},
                              icon: Icon(
                                Ionicons.search,
                                size: 26,
                              ),
                            ),
                            suffixIcon: IconButton(
                              onPressed: () {},
                              icon: Icon(
                                Ionicons.mic_outline,
                                size: 28,
                              ),
                            ),
                          ),
                          Lottie.network(
                            'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/search_members_692a406814.json?updated_at=2023-08-23T06:28:52.176Z',
                            width: double.infinity,
                            height: 300,
                          ),
                          Text(
                            'No Members Found.\nSearch members by their name or flat',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onBackground
                                  .withOpacity(0.5),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: Container(
        width: double.infinity,
        margin: EdgeInsets.all(16),
        child: FloatingActionButton(
          elevation: 0.5,
          onPressed: () {
            (selectedIndices.length == 1)
                ? Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RequestPermissionView(),
                    ),
                  )
                : showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(20),
                        topRight: Radius.circular(20),
                      ),
                    ),
                    builder: (context) => SelectedUnitsBottomSheet(
                      selectedIndices: selectedIndices,
                    ),
                  );
          },
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Color(0xffFFEBE6),
            ),
            child: ListTile(
                contentPadding: EdgeInsets.only(left: 16),
                title: Text(
                  getSelectedItemsText(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 18,
                      color: Theme.of(context).colorScheme.onBackground),
                ),
                trailing: (selectedIndices.isEmpty)
                    ? SizedBox()
                    : Container(
                        margin: EdgeInsets.all(5),
                        height: 75,
                        width: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Theme.of(context).colorScheme.onBackground,
                        ),
                        child: Center(
                          child: Text(
                            'NEXT',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      )),
          ),
        ),
      ),
    );
  }
}

class SelectedUnitsBottomSheet extends StatefulWidget {
  List<int>? selectedIndices = [];
  SelectedUnitsBottomSheet({super.key, this.selectedIndices});

  @override
  State<SelectedUnitsBottomSheet> createState() =>
      _SelectedUnitsBottomSheetState();
}

class _SelectedUnitsBottomSheetState extends State<SelectedUnitsBottomSheet>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: (widget.selectedIndices == null || widget.selectedIndices!.isEmpty)
          ? Column(
              children: [
                ListTile(
                  title: Text(
                    'Select flats or search for members',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context)
                          .colorScheme
                          .onBackground
                          .withOpacity(0.5),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                Lottie.network(
                  'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/search_members_692a406814.json?updated_at=2023-08-23T06:28:52.176Z',
                  width: double.infinity,
                  height: 200,
                ),
                SizedBox(height: 50)
              ],
            )
          : Column(
              children: [
                SizedBox(height: 30),
                ListTile(
                  title: Text(
                    'Selected Units/Members',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  trailing: Directionality(
                    textDirection: TextDirection.rtl,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        // padding: EdgeInsets.only(bottom: 15.0),
                        elevation: 0,
                        backgroundColor: Colors.transparent,
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => RequestPermissionView(),
                          ),
                        );
                      },
                      icon: Icon(
                        Ionicons.arrow_forward_outline,
                        color: Theme.of(context).colorScheme.onBackground,
                      ),
                      label: Text(
                        'NEXT',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onBackground,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: NeverScrollableScrollPhysics(),
                  itemCount: widget.selectedIndices!.length,
                  itemBuilder: (BuildContext context, int index) {
                    final item = widget.selectedIndices!.elementAt(index);
                    return ListTile(
                      onTap: () {},
                      trailing: IconButton(
                        icon: Icon(
                          Ionicons.close_circle_outline,
                          color: Colors.red,
                        ),
                        onPressed: () {
                          setState(() {
                            widget.selectedIndices!.removeAt(index);
                          });

                          // Navigator.pop(context);
                        },
                      ),
                      title: Text('Shubham Bane'),
                      subtitle: Text('Building A | $item'),
                    );
                  },
                  separatorBuilder: (context, index) {
                    return Divider(
                      indent: 16,
                      endIndent: 16,
                    );
                  },
                ),
                SizedBox(height: 30),
              ],
            ),
    );
  }
}
