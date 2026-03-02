import 'package:flutter/material.dart';

import '../../constants/colors.dart';
import '../../widgets/text_field_outline_border.dart';

Widget textFormFieldWidgetMobileNumber(
    size, context, controller, focusNode, hintText, validatorFunction) {
  return SizedBox(
    width: size.width * 0.9,
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextFormField(
        validator: validatorFunction,
        controller: controller,
        focusNode: focusNode,
        scrollPadding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        keyboardType: TextInputType.number,
        cursorWidth: ((0.067 * size.height) / 100),
        cursorColor: black,
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
          hintStyle: const TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
        textInputAction: TextInputAction.next,
        onEditingComplete: () {
          FocusScope.of(context).unfocus();
        },
      ),
    ),
  );
}
