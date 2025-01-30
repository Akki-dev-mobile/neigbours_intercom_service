// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart';

class MyScrollView extends StatelessWidget {
  const MyScrollView({
    super.key,
    required this.pageBody,
    this.pageTitle,
    this.pageTitleWidget,
    this.floatingActionButton,
    this.bottomSheet,
    this.controller,
    this.hasBackButton = true,
    this.backButtonPressed,
    this.isScrollable = true,
    this.actions,
    this.bottomNavigationBar,
    this.floatingActionButtonLocation
  });

  final Widget pageBody;
  final String? pageTitle;
  final Widget? pageTitleWidget;
  final Widget? floatingActionButton;
  final Widget? bottomSheet;
  final ScrollController? controller;
  final bool hasBackButton;
  final bool isScrollable;
  final List<Widget>? actions;
  final VoidCallback? backButtonPressed;
  final Widget? bottomNavigationBar;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBody: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        controller: controller,
        physics: isScrollable
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverAppBar(
            backgroundColor: Theme.of(context).colorScheme.surface,
            elevation: 1,
            automaticallyImplyLeading: false,
            leading: hasBackButton
                ? IconButton(
              icon: Icon(
                Ionicons.arrow_back_outline,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: backButtonPressed ??
                      () {
                    Navigator.pop(context);
                  },
            )
                : null,
            pinned: true,
            title: pageTitle != null
                ? Text(
              pageTitle ?? '',
              style: Theme.of(context).textTheme.bodyLarge,
            )
                : pageTitleWidget,
            actions: actions,
            // expandedHeight: 50,
            flexibleSpace: FlexibleSpaceBar(
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
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                ),
                child: pageBody,
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      floatingActionButtonLocation:floatingActionButtonLocation ?? FloatingActionButtonLocation.centerFloat ,
      bottomSheet: bottomSheet,
    );
  }
}

class CustomForm {
  static Widget textField(
      String title, {
        required Color titleColor,
        required Color hintColor,
        TextInputType? keyboardType,
        bool isObscureText = false,
        required String hintText,
        int? length,
        String? hasInitialValue,
        TextEditingController? textController,
        int lines = 1,
        String? counterText,
        bool isEnabled = true,
        Widget? suffixIcon,
        Widget? prefixIcon,
        TextCapitalization textCapitalization = TextCapitalization.none,
        FocusNode? focusNode,
        FormFieldValidator<String>? validator,
        TextInputAction? textInputAction,
        ValueChanged<String>? onChanged,
        ValueChanged<String>? onFieldSubmitted,
        String? errorText,
        List<TextInputFormatter>? inputFormatters,
        bool? isReadOnly,
      }) {
    return Container(
      margin: EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            height: 10,
          ),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: titleColor,
            ),
          ),
          SizedBox(
            height: 5,
          ),
          TextFormField(
            readOnly: isReadOnly ?? false,
            cursorColor: Colors.blue,
            // autovalidateMode: AutovalidateMode.onUserInteraction,
            focusNode: focusNode,
            onFieldSubmitted: onFieldSubmitted,
            textInputAction: textInputAction ?? TextInputAction.go,
            enabled: isEnabled,
            initialValue: hasInitialValue,
            maxLines: lines,
            style: TextStyle(
              color: titleColor,
              fontSize: 18,
            ),
            textCapitalization: textCapitalization,
            controller: textController,
            maxLength: length ?? 499,
            validator: validator ??
                    (value) {
                  if (value!.isEmpty) {
                    return '$title is required';
                  }
                  return null;
                },
            inputFormatters: inputFormatters,
            // [
            //    LengthLimitingTextInputFormatter(length),
            // ],
            obscureText: isObscureText ? true : false,
            keyboardType: keyboardType ?? TextInputType.text,
            onChanged: onChanged ?? (value) {},
            decoration: InputDecoration(
              counterText: counterText ?? '',
              contentPadding: EdgeInsets.symmetric(
                vertical: 20,
                horizontal: 15,
              ),
              errorStyle: TextStyle(
                fontSize: 14,
              ),
              errorText: errorText,
              hintText: hintText,
              hintStyle: TextStyle(
                color: hintColor,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  style: BorderStyle.solid,
                  color: titleColor,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color: titleColor,
                  style: BorderStyle.solid,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  style: BorderStyle.solid,
                  width: 2,
                  color: Colors.blue,
                ),
              ),
              prefixIcon: prefixIcon,
              suffixIcon: suffixIcon,
            ),
          ),
          SizedBox(
            height: 8,
          ),
        ],
      ),
    );
  }
}

class CustomLargeBtn extends StatelessWidget {
  const CustomLargeBtn({
    super.key,
    required this.onPressed,
    required this.text,
    this.isText = true,this.width ,
    this.widgetChild,
    this.heroTag,
    this.disabled = false,
  });

  final Function()? onPressed; // Made nullable for the disabled state
  final String text;
  final String? heroTag;
  final bool isText;
  final Widget? widgetChild; final double? width;
  final bool disabled; // New field to handle button's disabled state

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      width: width??MediaQuery.of(context).size.width * 0.85,
      height: 60,
      child: ElevatedButton(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.all<Color>(
            Color(0xFF7D7C7C),
          ),
          backgroundColor: MaterialStateProperty.all<Color>(
            disabled
                ? Colors.grey // Set a different color for the disabled state
                : Theme.of(context).colorScheme.onSurface,
          ),
          elevation: MaterialStateProperty.resolveWith<double>(
                (Set<MaterialState> states) {
              if (states.contains(MaterialState.pressed)) {
                return 8;
              }
              return 0;
            },
          ),
          shape: MaterialStateProperty.all<RoundedRectangleBorder>(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
          ),
        ),
        onPressed: disabled ? null : onPressed, // Disable button if `disabled` is true
        child: Hero(
          tag: heroTag ?? 'btn',
          child: isText
              ? Text(
            text,
            style: TextStyle(
              color: Theme.of(context).colorScheme.surface,
              fontSize: width!=null?15:22,
              wordSpacing: 1.2,
              fontWeight: FontWeight.w500,
            ),
          )
              : widgetChild ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class CustomDropdown extends StatelessWidget {
  final String title;
  final String hintText;
  final List<String> items;
  final String? selectedItem;
  final String? initialValue;
  final ValueChanged<String?> onChanged;
  final Color? titleColor;
  final Color? hintColor;
  final bool isEnabled;

  const CustomDropdown({
    Key? key,
    required this.title,
    required this.hintText,
    required this.items,
    this.selectedItem,
    required this.onChanged,
    this.titleColor,
    this.initialValue,
    this.hintColor,
    this.isEnabled = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(
            height: 10,
          ),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
              color: titleColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(
            height: 5,
          ),
          DropdownButtonFormField<String>(
            value: selectedItem ?? initialValue,
            isExpanded: true,
            style: TextStyle(
              color: titleColor ?? Theme.of(context).colorScheme.onSurface,
              fontSize: 18,
            ),
            decoration: InputDecoration(
              contentPadding: const EdgeInsets.symmetric(
                vertical: 20,
                horizontal: 15,
              ),
              hintText: hintText,
              hintStyle: TextStyle(
                color: hintColor ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  style: BorderStyle.solid,
                  color: titleColor ?? Theme.of(context).colorScheme.onSurface,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color: titleColor ?? Theme.of(context).colorScheme.onSurface,
                  style: BorderStyle.solid,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: const BorderSide(
                  style: BorderStyle.solid,
                  width: 2,
                  color: Colors.blue,
                ),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  color: hintColor ?? Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                  style: BorderStyle.solid,
                ),
              ),
            ),
            dropdownColor: Colors.white,
            items: items.map((String value) {
              return DropdownMenuItem<String>(
                value: value,
                child: Text(value),
              );
            }).toList(),
            onChanged: isEnabled ? onChanged : null,
          ),
          const SizedBox(
            height: 8,
          ),
        ],
      ),
    );
  }
}