import 'package:flutter/material.dart';

import '../constants/colors.dart';

void showDialogBoxWithOneButton(context, text, description) {
  showDialog(
      context: context,
      builder: (_) {
        return AlertDialog(
          title: Text(text),
          content: SingleChildScrollView(child: Text(description)),
          actions: [
            TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text(
                  "OK",
                  style: TextStyle(color: black),
                ))
          ],
        );
      });
}

void confirmDialogue(context, text, description, onYes, onNo) {
  showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return AlertDialog(
          title: Text(text),
          content: SingleChildScrollView(child: Text(description)),
          actions: [
            TextButton(
                onPressed: onNo,
                child: Text(
                  "NO",
                  style: TextStyle(color: black),
                )),
            TextButton(
                onPressed: onYes,
                child: Text(
                  "YES",
                  style: TextStyle(color: black),
                )),
          ],
        );
      });
}
