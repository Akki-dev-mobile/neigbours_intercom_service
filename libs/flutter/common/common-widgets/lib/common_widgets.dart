// ignore_for_file: prefer_const_constructors

import 'package:flutter/material.dart';
import 'package:ionicons/ionicons.dart';
import 'package:flutter/services.dart';

class MyScrollView extends StatelessWidget {
  const MyScrollView({
    Key? key,
    required this.pageBody,
    this.pageTitle,
    this.floatingActionButton,
    this.bottomSheet,
    this.controller,
    this.hasBackButton = true,
    this.isScrollable = true,
  });

  final Widget pageBody;
  final String? pageTitle;
  final Widget? floatingActionButton;
  final Widget? bottomSheet;
  final ScrollController? controller;
  final bool hasBackButton;
  final bool isScrollable;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      extendBody: true,
      backgroundColor: Theme.of(context).colorScheme.background,
      body: CustomScrollView(
        controller: controller,
        physics: isScrollable
            ? const BouncingScrollPhysics()
            : const NeverScrollableScrollPhysics(),
        slivers: <Widget>[
          SliverAppBar(
            automaticallyImplyLeading: false,
            leading: hasBackButton
                ? IconButton(
                    icon: Icon(
                      Ionicons.arrow_back_outline,
                      color: Colors.black,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  )
                : null,
            pinned: true,
            title: Text(
              pageTitle ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            expandedHeight: 80,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Theme.of(context).colorScheme.surfaceVariant,
                      Theme.of(context).colorScheme.background,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomSheet: bottomSheet,
    );
  }
}

class CustomForm {
  static Widget textField(
    String title, {
    Color? titleColor,
    bool isNumber = false,
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
              color: titleColor ?? Colors.black87,
            ),
          ),
          SizedBox(
            height: 5,
          ),
          TextFormField(
            autovalidateMode: AutovalidateMode.onUserInteraction,
            focusNode: focusNode,
            onFieldSubmitted: onFieldSubmitted,
            textInputAction: textInputAction ?? TextInputAction.go,
            enabled: isEnabled,
            initialValue: hasInitialValue,
            maxLines: lines,
            style: TextStyle(
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
            inputFormatters: [
              LengthLimitingTextInputFormatter(length),
            ],
            obscureText: isObscureText ? true : false,
            keyboardType: isNumber ? TextInputType.number : TextInputType.text,
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  style: BorderStyle.solid,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15),
                borderSide: BorderSide(
                  style: BorderStyle.solid,
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
  });
  final void Function() onPressed;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8),
      width: MediaQuery.of(context).size.width * 1,
      height: 60,
      child: ElevatedButton(
        style: ButtonStyle(
          overlayColor: MaterialStateProperty.all<Color>(
            Color(0x80FFB080),
          ),
          backgroundColor: MaterialStateProperty.all<Color>(Colors.black),
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
              side: BorderSide(
                color: Colors.transparent,
                width: 1,
              ),
            ),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            wordSpacing: 1.2,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
