import 'package:flutter/material.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/widgets/text_field_outline_border.dart';

Widget captionEditorField(
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
