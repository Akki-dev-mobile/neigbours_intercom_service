import 'package:chips_choice/chips_choice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:ionicons/ionicons.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:page_transition/page_transition.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:random_avatar/random_avatar.dart';

import '../../gate_selection/ui/gate_selection_view.dart';

class VisitorLogView extends StatefulWidget {
  String id;
  final List<String> logList;

  VisitorLogView({required this.id, required this.logList, Key? key})
      : super(key: key);

  @override
  State<VisitorLogView> createState() => _VisitorLogViewState();
}

class _VisitorLogViewState extends State<VisitorLogView> {
  final List<String> items =
      List.generate(50, (index) => 'Name Surname $index');
  late String selectedId;

  @override
  void initState() {
    super.initState();
    selectedId = widget.id;
  }

  @override
  Widget build(BuildContext context) {
    return MyScrollView(
      isScrollable: false,
      pageTitle: widget.id,
      hasBackButton: true,
      pageBody: Column(
        children: [
          CustomForm.textField(
            titleColor: Theme.of(context).colorScheme.onBackground,
            hintColor: Theme.of(context).colorScheme.onPrimary,
            "Search",
            hintText: 'Search Visitor',
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.search,
            onFieldSubmitted: (value) {
              if (kDebugMode) {
                print(value);
              }
            },
            prefixIcon: IconButton(
              onPressed: () {},
              icon: Icon(
                Ionicons.search_outline,
                color: Theme.of(context).colorScheme.onBackground,
              ),
            ),
            suffixIcon: ButtonBar(
              alignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: () {},
                  icon: CircleAvatar(
                    backgroundColor: const Color(0xffFFEBE6),
                    radius: 20,
                    child: Icon(
                      size: 22,
                      Ionicons.mic_outline,
                      color: Theme.of(context).colorScheme.onBackground,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () {
                    _showLogBookConfigBottomSheet(context);
                  },
                  icon: Icon(
                    Ionicons.options_outline,
                    color: Theme.of(context).colorScheme.onBackground,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: MediaQuery.of(context).size.height * 0.7,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: items.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Card(
                    elevation: 2,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 2,
                          ),
                          leading: CircleAvatar(
                            child: RandomAvatar(
                              DateTime.now().toIso8601String(),
                              trBackground: false,
                            ),
                          ),
                          title: Text(
                            items[index],
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: RichText(
                              text: TextSpan(
                                children: [
                                  const WidgetSpan(
                                    child: Icon(
                                      Symbols.apartment,
                                      color: Color(0xffFFB080),
                                    ),
                                  ),
                                  TextSpan(
                                    text: ' A/201, +4',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall!
                                        .merge(
                                          const TextStyle(fontSize: 12),
                                        ),
                                  ),
                                  WidgetSpan(
                                    child: Container(
                                      margin: const EdgeInsets.only(left: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 7,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(0xffFFEBE6),
                                        borderRadius: BorderRadius.circular(8),
                                        // border: Border.all(
                                        //   color: Colors.black,
                                        // ),
                                      ),
                                      child: const Text(
                                        'Guest',
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          trailing: const Icon(
                            Ionicons.call,
                            color: Colors.green,
                          ),
                        ),
                        Divider(
                          indent: 16,
                          endIndent: 16,
                          color: Colors.grey[200],
                        ),
                        ListTile(
                          title: RichText(
                            text: TextSpan(
                              children: [
                                const WidgetSpan(
                                  child: Icon(
                                    Symbols.directions_walk_rounded,
                                    color: Colors.green,
                                  ),
                                ),
                                TextSpan(
                                  text: ' 04:00 AM',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall!
                                      .merge(
                                        const TextStyle(
                                          color: Colors.green,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          trailing: (index % 2 == 0)
                              ? ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onPressed: () {
                                    Fluttertoast.showToast(
                                      msg: "User Checked Out Successfully",
                                      toastLength: Toast.LENGTH_SHORT,
                                      gravity: ToastGravity.CENTER,
                                      timeInSecForIosWeb: 1,
                                      backgroundColor: Colors.red,
                                      textColor: Colors.white,
                                      fontSize: 16.0,
                                    );
                                    Navigator.pop(context);
                                  },
                                  child: Text(
                                    'CheckOut',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall!
                                        .merge(
                                          TextStyle(
                                              color: Colors.white,
                                              fontSize: 14),
                                        ),
                                  ),
                                )
                              : RichText(
                                  text: TextSpan(
                                    children: [
                                      WidgetSpan(
                                        child: Icon(
                                          Symbols.directions_walk_rounded,
                                          color: Colors.red,
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' 09:00 PM',
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall!
                                            .merge(
                                              TextStyle(
                                                color: Colors.red,
                                              ),
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(
            height: 100,
          ),
        ],
      ),
    );
  }

  void _showLogBookConfigBottomSheet(BuildContext context) async {
    showModalBottomSheet(
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setState) {
            return Container(
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                color: Theme.of(context).colorScheme.background,
              ),
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Select your gate',
                      style: Theme.of(context).textTheme.displaySmall!.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.logList.length,
                      itemBuilder: (context, index) {
                        return GateSettingListTile(
                          switchValue: selectedId == widget.logList[index],
                          onChanged: (value) {
                            setState(() {
                              selectedId = widget.logList[index];
                            });
                          },
                          title: widget.logList[index],
                          subtitle: 'Enable/Disable ${widget.logList[index]}',
                          leadingIcon: Symbols.gate,
                        );
                      },
                    ),
                  ),
                  const SizedBox(
                    height: 30,
                  ),
                  CustomLargeBtn(
                    text: 'Confirm',
                    onPressed: () {
                      setState(() {
                        widget.id = selectedId;
                      });

                      Navigator.pop(context);

                      Navigator.pushReplacement(
                        context,
                        PageTransition(
                          type: PageTransitionType.bottomToTop,
                          child: VisitorLogView(
                            id: widget.id,
                            logList: widget.logList,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
