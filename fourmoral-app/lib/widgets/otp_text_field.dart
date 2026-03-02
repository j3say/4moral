// ignore_for_file: use_key_in_widget_constructors

import 'package:flutter/material.dart';

import '../constants/colors.dart';
import 'text_field_outline_border.dart';

class OtpTextField extends StatefulWidget {
  final String? lastPin;
  final int fields;
  final Function? onSubmit;
  final double fieldWidth;
  final double fontSize;
  final bool isTextObscure;
  final bool showFieldAsBox;

  const OtpTextField({
    this.lastPin,
    this.fields = 4,
    this.onSubmit,
    this.fieldWidth = 40.0,
    this.fontSize = 16.0,
    this.isTextObscure = false,
    this.showFieldAsBox = false,
  }) : assert(fields > 0);

  @override
  State createState() {
    return OtpTextFieldState();
  }
}

class OtpTextFieldState extends State<OtpTextField> {
  final List<String> _pin = [];
  final List<FocusNode> _focusNodes = [];
  final List<TextEditingController> _textControllers = [];

  Widget textfields = Container();

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.fields; i++) {
      _pin.add('');
      _focusNodes.add(FocusNode());
      _textControllers.add(TextEditingController());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        if (widget.lastPin != null) {
          for (var i = 0; i < widget.lastPin!.length; i++) {
            _pin[i] = widget.lastPin![i];
          }
        }
        textfields = generateTextFields(context);
      });
    });
  }

  @override
  void dispose() {
    for (var t in _textControllers) {
      t.dispose();
    }
    super.dispose();
  }

  Widget generateTextFields(BuildContext context) {
    List<Widget> textFields = List.generate(widget.fields, (int i) {
      return buildTextField(i, context);
    });

    FocusScope.of(context).requestFocus(_focusNodes[0]);

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      verticalDirection: VerticalDirection.down,
      children: textFields,
    );
  }

  void clearTextFields() {
    for (var tEditController in _textControllers) {
      tEditController.clear();
    }
    _pin.clear();
  }

  Widget buildTextField(int i, BuildContext context) {
    Size size = MediaQuery.of(context).size;

    _focusNodes[i].addListener(() {
      if (_focusNodes[i].hasFocus) {}
    });

    final String lastDigit = _textControllers[i].text ?? "";

    return Container(
      width: 35,
      height: 35,
      margin: const EdgeInsets.only(right: 10.0),
      child: TextField(
        controller: _textControllers[i],
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        autofocus: true,
        maxLength: 1,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: black,
          fontSize: widget.fontSize,
        ),
        focusNode: _focusNodes[i],
        obscureText: widget.isTextObscure,
        decoration: InputDecoration(
          counterText: "",
          contentPadding: EdgeInsets.only(
            bottom: ((1.896 * size.height) / 100),
          ),
          filled: true,
          fillColor: white,
          border: buildTextFieldOutlineInputBorder(size),
          enabledBorder: buildTextFieldOutlineInputBorder(size),
          errorBorder: buildTextFieldOutlineInputBorder(size),
          disabledBorder: buildTextFieldOutlineInputBorder(size),
          focusedBorder: buildTextFieldOutlineInputBorder(size),
          focusedErrorBorder: buildTextFieldOutlineInputBorder(size),
        ),
        cursorColor: Colors.grey,
        cursorWidth: ((0.067 * size.height) / 100),
        onChanged: (String str) {
          setState(() {
            _pin[i] = str;
          });
          if (i + 1 != widget.fields) {
            _focusNodes[i].unfocus();
            if (_pin[i] == '') {
              FocusScope.of(context).requestFocus(_focusNodes[i - 1]);
            } else {
              FocusScope.of(context).requestFocus(_focusNodes[i + 1]);
            }
          } else {
            _focusNodes[i].unfocus();
            if (_pin[i] == '') {
              FocusScope.of(context).requestFocus(_focusNodes[i - 1]);
            }
          }
          if (_pin.every((String digit) => digit != '')) {
            widget.onSubmit!(_pin.join());
          }
        },
        onSubmitted: (String str) {
          if (_pin.every((String digit) => digit != '')) {
            widget.onSubmit!(_pin.join());
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return textfields;
  }
}
