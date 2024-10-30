// ignore_for_file: prefer_const_constructors

import 'package:chips_choice/chips_choice.dart';
import 'package:common_widgets/common_widgets.dart';
import 'package:common_widgets/loading_view.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/data/datasources/remote_datasource.dart';
import 'package:flutter_onegate/data/repositories/society_repo_impl.dart';
import 'package:flutter_onegate/dio_setup.dart';
import 'package:flutter_onegate/domain/entities/society/building.dart';
import 'package:flutter_onegate/domain/entities/society/member_unit.dart';
import 'package:flutter_onegate/domain/use_cases/society_usecase.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/request_permission/ui/request_permission_view.dart';
import 'package:flutter_onegate/presentation/features/visitor_checkin_flow/units_selection/bloc/units_selection_bloc.dart';
import 'package:ionicons/ionicons.dart';
import 'package:lottie/lottie.dart';
import 'package:onegate_client/onegate_client.dart';

class UnitSelectionView extends StatefulWidget {
  final Visitor visitor;
  final PurposeCategory purposeCategory;
  final String? comingFrom;
  final int? guestCount;
  const UnitSelectionView(
      {Key? key,
      required this.visitor,
      required this.purposeCategory,
      this.comingFrom,
      this.guestCount})
      : super(key: key);

  @override
  State<UnitSelectionView> createState() => _UnitSelectionViewState();
}

class _UnitSelectionViewState extends State<UnitSelectionView> {
  List<MemberUnits> selectedUnits = [];
  late Building selectedBuilding;

  List<MemberUnits> anotherList = [];

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

  final UnitsSelectionBloc unitsSelectionBloc = UnitsSelectionBloc(
      SocietyUseCase(SocietyRepositoryImpl(RemoteDataSource(
          DioSingleton.instance1,
          DioSingleton.instance2,
          DioSingleton.instance3))));

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    unitsSelectionBloc.add(UnitSelectionInitialEvent());
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<UnitsSelectionBloc, UnitsSelectionState>(
      bloc: unitsSelectionBloc,
      listenWhen: (previous, current) => current is UnitsSelectionActionState,
      buildWhen: (previous, current) => current is! UnitsSelectionActionState,
      listener: (context, state) {
        switch (state.runtimeType) {
          case MemberFetchedState:
            final memberState = state as MemberFetchedState;
            for (MemberUnits index in selectedUnits) {
              if (index.id == memberState.members![0].fkUnitId) {
                index.members = memberState.members;
              }
            }
            break;
          case NavigateToRequestPermissionState:
            Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RequestPermissionView(
                    gridData: (state as NavigateToRequestPermissionState).unit,
                    visitor: widget.visitor,
                    purposeCategory: widget.purposeCategory,
                    comingFrom: widget.comingFrom,
                    guestCount: widget.guestCount,
                  ),
                ));

            break;
        }
      },
      builder: (context, state) {
        switch (state.runtimeType) {
          case UnitsSelectionLoadingState:
            return LoaderView();
          case UnitSelectionSuccessState:
            List<MemberUnits>? unit;
            print(" here i am $unit");
            final successState = state as UnitSelectionSuccessState;
            selectedBuilding = successState.selectedBuilding!;
            unit = successState.units;

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
                          indicatorColor: Color(0xffC08261),
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
                            fontWeight: FontWeight.bold,
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
                                      padding:
                                          EdgeInsets.symmetric(horizontal: 20),
                                      scrollToSelectedOnChanged: true,
                                      spacing: 20,
                                      choiceStyle: C2ChipStyle.outlined(
                                        borderWidth: 1,
                                        color: Colors.grey.shade700,
                                        selectedStyle: C2ChipStyle.filled(
                                          foregroundColor: Color(0xFFC08261),
                                        ),
                                        height: 40,
                                      ),
                                      choiceCheckmark: true,
                                      value: selectedBuilding.socBuildingName,
                                      scrollPhysics: BouncingScrollPhysics(),
                                      onChanged: (value) {
                                        for (Building building
                                            in successState.buildings!) {
                                          if (building.socBuildingName ==
                                              value) {
                                            selectedBuilding = building;
                                          }
                                        }
                                        unitsSelectionBloc.add(
                                            BuildingChipClickedEvent(
                                                selectedBuilding,
                                                successState.buildings!));
                                      },
                                      choiceItems: C2Choice.listFrom(
                                          source: successState.buildings!,
                                          value: (index, item) => successState
                                              .buildings![index]
                                              .socBuildingName,
                                          label: (index, item) =>
                                              item.socBuildingName),
                                    ),
                                  ),
                                  Expanded(
                                    child: SingleChildScrollView(
                                      padding: EdgeInsets.only(bottom: 150),
                                      child: Wrap(
                                        spacing:
                                            10.0, // Horizontal spacing between items
                                        runSpacing:
                                            10.0, // Vertical spacing between rows
                                        children: List.generate(
                                          unit?.length ?? 1,
                                          (index) {
                                            return GestureDetector(
                                              onTap: () {
                                                setState(() {
                                                  if (selectedUnits
                                                      .contains(unit![index])) {
                                                    selectedUnits
                                                        .remove(unit[index]);
                                                  } else {
                                                    selectedUnits
                                                        .add(unit[index]);
                                                    unitsSelectionBloc.add(
                                                        UnitSelectedEvent(
                                                            unit[index]));
                                                  }
                                                  if (kDebugMode) {
                                                    print(
                                                        'Selected Indices: $selectedUnits');
                                                  }
                                                  anotherList.clear();
                                                  for (MemberUnits index
                                                      in selectedUnits) {
                                                    anotherList.add(index);
                                                  }
                                                  if (kDebugMode) {
                                                    print(
                                                        'Another List: $anotherList');
                                                  }
                                                });
                                              },
                                              child: Container(
                                                width: MediaQuery.of(context)
                                                            .size
                                                            .width /
                                                        3 -
                                                    15, // Approximate width for three columns
                                                height:
                                                    100, // Set height based on the aspect ratio you want
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  color: selectedUnits.contains(
                                                          unit?[index] ?? [])
                                                      ? Color(0x10C08261)
                                                      : Colors.transparent,
                                                  border: Border.all(
                                                    color: selectedUnits
                                                            .contains(
                                                                unit?[index])
                                                        ? Color(0xffC08261)
                                                        : Colors.grey.shade400,
                                                    width:
                                                        selectedUnits.contains(
                                                                unit?[index])
                                                            ? 2
                                                            : 1,
                                                  ),
                                                ),
                                                child: FittedBox(
                                                  fit: BoxFit.scaleDown,
                                                  child: Text(
                                                    unit?[index]
                                                            .unitFlatNumber ??
                                                        '',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 22,
                                                      color: selectedUnits
                                                              .contains(
                                                                  unit?[index])
                                                          ? Color(0xffC08261)
                                                          : Colors
                                                              .grey.shade700,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
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
                                    titleColor: Theme.of(context)
                                        .colorScheme
                                        .onBackground,
                                    hintColor:
                                        Theme.of(context).colorScheme.onPrimary,
                                    hintText: 'Search Members/Units',
                                    textCapitalization:
                                        TextCapitalization.words,
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
                    (selectedUnits.length == 1)
                        ? showModalBottomSheet(
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
                              selectedIndices: selectedUnits,
                              unitsSelectionBloc: unitsSelectionBloc,
                            ),
                          )
                        : unitsSelectionBloc
                            .add(NextButtonClickedEvent(unit: selectedUnits));
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
                              color:
                                  Theme.of(context).colorScheme.onBackground),
                        ),
                        trailing: (selectedUnits.isEmpty)
                            ? SizedBox()
                            : Container(
                                margin: EdgeInsets.all(5),
                                height: 75,
                                width: 70,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onBackground,
                                ),
                                child: Center(
                                  child: Text(
                                    selectedUnits.length == 1 ? 'Next' : 'View',
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
          default:
            return Container();
        }
      },
    );
  }
}

class SelectedUnitsBottomSheet extends StatefulWidget {
  List<MemberUnits>? selectedIndices = [];
  final UnitsSelectionBloc unitsSelectionBloc;
  SelectedUnitsBottomSheet(
      {super.key, this.selectedIndices, required this.unitsSelectionBloc});

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
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
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
                SizedBox(height: 10),
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
                        backgroundColor:
                            Theme.of(context).colorScheme.onBackground,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.unitsSelectionBloc.add(NextButtonClickedEvent(
                            unit: widget.selectedIndices!));
                      },
                      icon: Icon(
                        Ionicons.arrow_forward_outline,
                        color: Theme.of(context).colorScheme.background,
                      ),
                      label: Text(
                        'Next',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.background,
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
                      title: Text(item.members![0].memberName),
                      subtitle: Text(item.unitFlatNumber),
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
