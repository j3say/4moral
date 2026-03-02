import 'dart:async';
import 'dart:developer';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CallManager {
  Timer? _timer;
  DateTime? _startTime;
  int _minutesElapsed = 0;

  Future<String?> getFirestoreDocumentIdByUid(String uid) async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance
            .collection('Users')
            .where('uid', isEqualTo: uid)
            .limit(1)
            .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.id; // e.g. n5bCkaKctXW2Gkw2IQTr
    }
    return null; // not found
  }

  Future<String?> getFirestoreDocumentIdByPhone(String phone) async {
    QuerySnapshot snapshot =
        await FirebaseFirestore.instance
            .collection('Users')
            .where('mobileNumber', isEqualTo: phone)
            .limit(1)
            .get();

    if (snapshot.docs.isNotEmpty) {
      return snapshot.docs.first.id; // e.g. n5bCkaKctXW2Gkw2IQTr
    }
    return null; // not found
  }

  final usersRef = FirebaseFirestore.instance.collection('Users');

  Future<void> checkBalanceBeforeCall({
    required BuildContext context,
    required double perMinuteCharge,
    required String receiverUid,
    required VoidCallback onBalanceSufficient,
  }) async {
    final callerUid = await getFirestoreDocumentIdByUid(
      FirebaseAuth.instance.currentUser?.uid ?? "",
    );
    final receiverDocId = await getFirestoreDocumentIdByPhone(receiverUid);

    final callerSnapshot = await usersRef.doc(callerUid).get();
    final receiverSnapshot = await usersRef.doc(receiverDocId).get();

    final callerData = callerSnapshot.data()!;
    final callerRole =
        (callerData['accountType'] ?? 'standard').toString().toLowerCase();
    final callerBalance =
        (callerData['walletBalance'] as num?)?.toDouble() ?? 0.0;

    // ⚠️ Get receiver's data
    if (!receiverSnapshot.exists) {
      debugPrint("Receiver data not found.");
      return;
    }

    final receiverData = receiverSnapshot.data()!;
    final receiverRole =
        (receiverData['accountType'] ?? 'standard').toString().toLowerCase();

    // 🔴 Only if standard user calling mentor, check balance
    if (callerRole == 'standard' && receiverRole == 'mentor') {
      if (callerBalance < perMinuteCharge) {
        // 🚫 Low balance, do not proceed with the call
        _showLowBalanceDialog(context);
      } else {
        // ✅ Balance is sufficient, allow the call to start
        onBalanceSufficient();
      }
    } else {
      // ✅ No balance deduction needed (mentor to mentor or mentor to standard)
      onBalanceSufficient();
    }
  }

  // 🟢 Show dialog for low balance
  void _showLowBalanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Insufficient Balance"),
            content: const Text(
              "Your wallet balance is too low to start this call.\nPlease add money to continue.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Optional: Navigate to wallet top-up screen
                },
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }

  // Start wallet deduction if caller is standard & receiver is mentor
  Future<void> startWalletTimerIfNeeded(
    BuildContext context,
    double perMinuteCharge,
    String receiverUid,
  ) async {
    final callerUid = await getFirestoreDocumentIdByUid(
      FirebaseAuth.instance.currentUser?.uid ?? "",
    );
    final receiverDocId = await getFirestoreDocumentIdByPhone(receiverUid);

    final callerSnapshot = await usersRef.doc(callerUid).get();
    final receiverSnapshot = await usersRef.doc(receiverDocId).get();

    if (!callerSnapshot.exists || !receiverSnapshot.exists) {
      debugPrint(
        "❌ Caller or receiver document does not exist. No deduction logic will be applied.",
      );
      return;
    }

    // 🔧 Updated field names based on your Firestore: 'type' instead of 'accountType'
    final callerRole =
        (callerSnapshot.data()?['type'] ?? 'standard').toString().toLowerCase();
    final receiverRole =
        (receiverSnapshot.data()?['type'] ?? 'standard')
            .toString()
            .toLowerCase();

    log("Caller: $callerRole | Receiver: $receiverRole");

    debugPrint("Caller: $callerRole | Receiver: $receiverRole");

    final callerBalance =
        (callerSnapshot.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;

    // Start wallet deduction only if standard user calls mentor
    if (callerRole == 'standard' && receiverRole == 'mentor') {
      if (callerBalance < perMinuteCharge) {
        // ⚠️ Balance is low, end call and show alert
        endCall(context);
        _showBalanceAlert(context);
      } else {
        _startTime = DateTime.now();
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
          final elapsed =
              DateTime.now().difference(_startTime ?? DateTime.now()).inMinutes;

          if (elapsed > _minutesElapsed) {
            _minutesElapsed = elapsed;

            final updatedSnapshot = await usersRef.doc(callerUid).get();
            final balance =
                (updatedSnapshot.data()?['walletBalance'] as num?)
                    ?.toDouble() ??
                0.0;

            if (balance >= perMinuteCharge) {
              final newBalance = balance - perMinuteCharge;
              await usersRef.doc(callerUid).update({
                'walletBalance': newBalance,
              });
              debugPrint(
                "✅ Deducted ₹$perMinuteCharge for minute $_minutesElapsed. New balance: ₹$newBalance",
              );
            } else {
              timer.cancel();
              endCall(context);
              _showBalanceAlert(context);
            }
          }
        });
      }
    } else {
      debugPrint("✅ No wallet deduction required (free call).");
    }
  }

  void endCall(BuildContext context) {
    _timer?.cancel();
    _timer = null;
    _startTime = null;
    _minutesElapsed = 0;
    Navigator.of(context).pop();
  }

  void _showBalanceAlert(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text("Call Ended"),
            content: const Text(
              "Your wallet balance is low.\nPlease add money to continue the call.",
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Optionally navigate to wallet top-up screen
                },
                child: const Text("OK"),
              ),
            ],
          ),
    );
  }
}
