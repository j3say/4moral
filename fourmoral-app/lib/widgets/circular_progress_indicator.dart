import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

import '../constants/colors.dart';

Widget buildCPI(context) {
  showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope(
            onWillPop: () async => false,
            child: Container(
                decoration: BoxDecoration(color: black.withOpacity(0.4)),
                child: Center(
                    child: SizedBox(
                        height: 250,
                        width: 250,
                        child: Lottie.asset('assets/loading.json')))),
          ));
  return Container();
}

Widget buildCPIWidget(height, width) {
  return SizedBox(
      height: height * 0.8,
      width: width,
      child: Center(
          child: SizedBox(
              height: 50,
              width: 50,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(blue),
              ))));
}

Widget buildCPIWhiteWidget(height, width) {
  return SizedBox(
      height: height * 0.8,
      width: width,
      child: Center(
          child: SizedBox(
              height: 50,
              width: 50,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(white),
              ))));
}
