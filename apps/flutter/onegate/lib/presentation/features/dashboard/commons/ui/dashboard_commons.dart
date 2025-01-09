// import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_onegate/presentation/features/dashboard/admin/bloc/admin_dashboard_bloc.dart';
import 'package:flutter_onegate/presentation/features/dashboard/gatekeeper/bloc/gatekeeper_dashboard_bloc.dart';

class DashboardBlocks extends StatelessWidget {
  final int? inBook;
  final int? outBook;
  final Bloc bloc;

  DashboardBlocks({
    super.key,
    this.inBook,
    this.outBook,
    required this.bloc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      height: MediaQuery.of(context).size.height * 0.300,
      width: MediaQuery.of(context).size.width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.32,
            child: Material(
              color: const Color(0xffF2D8A5),
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                splashColor: Color.fromARGB(255, 255, 226, 172),
                autofocus: true,
                onTap: () {
                  bloc is GatekeeperDashboardBloc
                      ? bloc.add(GDInAndOutButtonPressedEvent())
                      : bloc.add(ADInAndOutButtonPressedEvent());
                  bloc.add(GDInAndOutButtonPressedEvent());
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2),
                      margin: const EdgeInsets.only(top: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: CachedNetworkImage(
                        maxHeightDiskCache: 10,
                        height: 55,
                        width: 55,
                        fit: BoxFit.contain,
                        imageUrl:
                            'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/visitor_book_31e76df597.gif?updated_at=2023-08-23T06:26:37.400Z',
                        placeholder: (context, url) =>
                            const CircularProgressIndicator(),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.error,
                          color: Colors.red,
                        ),
                        fadeOutDuration: const Duration(seconds: 1),
                        fadeInDuration: const Duration(seconds: 3),
                      ),
                    ),
                    Text(
                      'In-Out',
                      style: Theme.of(context).textTheme.displayMedium,
                    ),
                    Text(
                      "${(outBook ?? 0) + (inBook ?? 0)}", // Handle null values with default 0
                      textAlign: TextAlign.center,
                      style:
                      Theme.of(context).textTheme.displayMedium,
                    ),
                    // Text(
                    //   'Book',
                    //   textAlign: TextAlign.center,
                    //   style: Theme.of(context).textTheme.labelMedium,
                    // ),
                  ],
                ),
              ),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.50,
                height: MediaQuery.of(context).size.height * 0.14,
                child: Material(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xffCAF1D1),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    splashColor: const Color.fromARGB(255, 98, 255, 127),
                    autofocus: true,
                    onTap: () {
                      bloc is GatekeeperDashboardBloc
                          ? bloc.add(GDVisitorsInButtonPressedEvent())
                          : bloc.add(ADVisitorsInButtonPressedEvent());
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.height * 0.02,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                inBook.toString(),
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.displayMedium,
                              ),
                              Text(
                                'Visitor-In',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Transform(
                              transform: Matrix4.rotationY(math.pi),
                              alignment: Alignment.center,
                              child: CachedNetworkImage(
                                maxHeightDiskCache: 10,
                                height: 55,
                                width: 55,
                                fit: BoxFit.contain,
                                imageUrl:
                                    'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/visitor_in_01b37e79e9.gif?updated_at=2023-08-23T06:26:37.878Z',
                                placeholder: (context, url) =>
                                    const CircularProgressIndicator(),
                                errorWidget: (context, url, error) =>
                                    const Icon(
                                  Icons.error,
                                  color: Colors.red,
                                ),
                                fadeOutDuration: const Duration(seconds: 1),
                                fadeInDuration: const Duration(seconds: 3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: MediaQuery.of(context).size.width * 0.50,
                height: MediaQuery.of(context).size.height * 0.14,
                child: Material(
                  borderRadius: BorderRadius.circular(20),
                  color: const Color(0xffFFE5E0),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    splashColor: const Color.fromARGB(255, 237, 131, 109),
                    autofocus: true,
                    onTap: () {
                      bloc is GatekeeperDashboardBloc
                          ? bloc.add(GDVisitorsOutButtonPressedEvent())
                          : bloc.add(ADVisitorsOutButtonPressedEvent());
                    },
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: MediaQuery.of(context).size.height * 0.02,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                outBook.toString(),
                                textAlign: TextAlign.center,
                                style:
                                    Theme.of(context).textTheme.displayMedium,
                              ),
                              Text(
                                'Visitor-Out',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.labelMedium,
                              ),
                            ],
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: CachedNetworkImage(
                              maxHeightDiskCache: 10,
                              height: 55,
                              width: 55,
                              fit: BoxFit.contain,
                              imageUrl:
                                  'https://fsadvt-bucket.s3.ap-south-1.amazonaws.com/visitor_out_c9f84ddb97.gif?updated_at=2023-08-23T06:26:37.786Z',
                              placeholder: (context, url) =>
                                  const CircularProgressIndicator(),
                              errorWidget: (context, url, error) => const Icon(
                                Icons.error,
                                color: Colors.red,
                              ),
                              fadeOutDuration: const Duration(seconds: 1),
                              fadeInDuration: const Duration(seconds: 3),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
