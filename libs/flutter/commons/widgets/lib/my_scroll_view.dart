import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

class MyScrollView extends StatefulWidget {
  // appbar
  final String? pageTitle;
  final bool logoPageTitle;

  final bool hasBackButton;
  final Color? backBtnColor;
  final VoidCallback? backButtonPressed;
  final List<Widget>? actions;
  final Widget? leadingBtn;

  // body
  final Widget pageBody;
  final ScrollController? controller;
  final bool isScrollable;
  final double? bodyHorizaontalPadding;
  final Widget? bottomNavigationBar;

  const MyScrollView({
    super.key,
    this.pageTitle,
    this.logoPageTitle = false,
    this.hasBackButton = true,
    this.backBtnColor,
    this.backButtonPressed,
    this.actions,
    this.leadingBtn,
    required this.pageBody,
    this.controller,
    this.isScrollable = true,
    this.bodyHorizaontalPadding,
    this.bottomNavigationBar,
  });

  @override
  State<MyScrollView> createState() => _MyScrollViewState();
}

class _MyScrollViewState extends State<MyScrollView> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      resizeToAvoidBottomInset: true,
      extendBodyBehindAppBar: true,
      body: CustomScrollView(
        controller: widget.controller,
        physics: widget.isScrollable
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        slivers: [
          SliverAppBar.medium(
            centerTitle: false,
            surfaceTintColor: Theme.of(context).colorScheme.surface,
            backgroundColor: Theme.of(context).colorScheme.surface,
            automaticallyImplyLeading: false,
            flexibleSpace: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: EdgeInsets.only(
                left: (widget.hasBackButton == true) ? 60 : 30,
                bottom: 18.0,
              ),
              title: widget.pageTitle != null
                  ? Text(
                      widget.pageTitle ?? "",
                      style: Theme.of(context).textTheme.headlineMedium,
                    )
                  : widget.logoPageTitle
                      ? RichText(
                          textAlign: TextAlign.start,
                          text: TextSpan(
                            text: 'one',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                            children: <TextSpan>[
                              TextSpan(
                                text: 'app',
                                style: TextStyle(
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        )
                      : null,
              expandedTitleScale: 1.3,
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.primary,
                      Theme.of(context).colorScheme.surface,
                    ],
                  ),
                ),
                // child: CustomTextField(hintText: 'Search here',),
              ),
            ),
            actions: (widget.actions != null)
                ? [
                    Row(
                      children: widget.actions!,
                    ),
                    const SizedBox(
                      width: 20,
                    )
                  ]
                : widget.actions,

            // widget.actions
            leading: widget.hasBackButton
                ? IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.03),
                    ),
                    // color: Colors.red,
                    icon: Icon(
                      Symbols.arrow_back,
                      color: widget.backBtnColor ??
                          Theme.of(context).colorScheme.onSurface,
                    ),
                    onPressed: widget.backButtonPressed ??
                        () {
                          Navigator.pop(context);
                        })
                : widget.leadingBtn,
            pinned: true,
          ),
          SliverToBoxAdapter(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.bodyHorizaontalPadding ?? 12,
                  vertical: 0,
                ),
                child: widget.pageBody,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: widget.bottomNavigationBar,
    );
  }
}
