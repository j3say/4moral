import 'package:flutter/material.dart';

import '../constants/colors.dart';
import 'text_field_outline_border.dart';

Widget textFormFieldWidget(
  labelText,
  size,
  context,
  controller,
  focusNode,
  nextFocusNode,
  hintText,
  unFocus,
  keyboardNumberType,
  validatorFunction,
  onFieldSubmitted,
) {
  return SizedBox(
    width: size.width * 0.9,
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                "$labelText",
                textAlign: TextAlign.start,
                style: TextStyle(
                  color: black,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                ),
              ),
              // if (isOptional)
              //   const Text(
              //     " (Optional)",
              //     textAlign: TextAlign.start,
              //     style: TextStyle(
              //       color: Colors.grey,
              //       fontSize: 14,
              //       fontWeight: FontWeight.w400,
              //     ),
              //   ),
            ],
          ),
          const SizedBox(height: 5),
          TextFormField(
            validator: validatorFunction,
            controller: controller,
            focusNode: focusNode,

            scrollPadding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            keyboardType:
                keyboardNumberType ? TextInputType.number : TextInputType.text,
            cursorWidth: ((0.067 * size.height) / 100),
            cursorColor: black,
            // readOnly: isOptional,
            style: TextStyle(
              fontSize: ((2.032 * size.height) / 100),
              color: black,
            ),
            decoration: InputDecoration(
              disabledBorder: buildTextFieldOutlineInputBorder(size),
              focusedBorder: buildTextFieldOutlineInputBorder(size),
              errorBorder: buildTextFieldOutlineInputBorder(size),
              focusedErrorBorder: buildTextFieldOutlineInputBorder(size),
              border: buildTextFieldOutlineInputBorder(size),
              enabledBorder: buildTextFieldOutlineInputBorder(size),
              contentPadding: EdgeInsets.only(
                left: ((1.896 * size.height) / 100),
                right: ((1.896 * size.height) / 100),
              ),
              filled: true,
              fillColor: white,
              hintText: "$hintText",
              hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            textInputAction: TextInputAction.next,
            onFieldSubmitted: onFieldSubmitted,
            onEditingComplete: () {
              if (unFocus) {
                FocusScope.of(context).unfocus();
              } else {
                FocusScope.of(context).requestFocus(nextFocusNode);
              }
            },
          ),
        ],
      ),
    ),
  );
}

Widget textFormFieldWidgetBigger(
  labelText,
  size,
  context,
  controller,
  focusNode,
  nextFocusNode,
  hintText,
  unFocus,
  keyboardNumberType,
  validatorFunction,
) {
  return SizedBox(
    width: size.width * 0.9,
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        validator: validatorFunction,
        controller: controller,
        focusNode: focusNode,
        maxLines: 4,
        scrollPadding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        keyboardType:
            keyboardNumberType ? TextInputType.number : TextInputType.text,
        cursorWidth: ((0.067 * size.height) / 100),
        cursorColor: black,
        style: TextStyle(fontSize: ((2.032 * size.height) / 100), color: black),
        decoration: InputDecoration(
          disabledBorder: buildTextFieldOutlineInputBorder(size),
          focusedBorder: buildTextFieldOutlineInputBorder(size),
          errorBorder: buildTextFieldOutlineInputBorder(size),
          focusedErrorBorder: buildTextFieldOutlineInputBorder(size),
          border: buildTextFieldOutlineInputBorder(size),
          enabledBorder: buildTextFieldOutlineInputBorder(size),
          contentPadding: EdgeInsets.only(
            left: ((1.896 * size.height) / 100),
            right: ((1.896 * size.height) / 100),
            top: ((1.896 * size.height) / 100),
          ),
          filled: true,
          fillColor: white,
          hintText: "$hintText",
          hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
        ),
        textInputAction: TextInputAction.next,
        onEditingComplete: () {
          if (unFocus) {
            FocusScope.of(context).unfocus();
          } else {
            FocusScope.of(context).requestFocus(nextFocusNode);
          }
        },
      ),
    ),
  );
}
