import 'dart:convert';
import 'dart:developer';

import 'package:dio/dio.dart';
// import 'package:firebase_auth/firebase_auth.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fourmoral/utils/mock_firebase.dart';
import 'package:fourmoral/constants/colors.dart';
import 'package:fourmoral/models/user_profile_model.dart';
import 'package:intl/intl.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  late Razorpay _razorpay;
  double _walletBalance = 0.0;
  final _amountController = TextEditingController();
  User? currentUser;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    _loadWalletBalance();
  }

  @override
  void dispose() {
    _razorpay.clear();
    _amountController.dispose();
    super.dispose();
  }

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

  Future<void> _loadWalletBalance() async {
    currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("User not logged in.")));
      return;
    }
    String currentUserUid = currentUser?.uid ?? "";

    QuerySnapshot snapshot =
        await FirebaseFirestore.instance
            .collection('Users')
            .where('uid', isEqualTo: currentUserUid)
            .get();

    if (snapshot.docs.isNotEmpty) {
      DocumentSnapshot doc = snapshot.docs.first;
      double balance = (doc['walletBalance'] as num?)?.toDouble() ?? 0.0;

      setState(() {
        _walletBalance = balance;
      });
    } else {
      setState(() {
        _walletBalance = 0.0;
      });
    }
  }

  Future<void> addTransactionToFirestore({
    required double amount,
    required String paymentId,
    required String status,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final userDocId = await getFirestoreDocumentIdByUid(currentUser.uid);

    final userDocRef =
        FirebaseFirestore.instance
            .collection('Users')
            .doc(userDocId)
            .collection('Transactions')
            .doc();

    await userDocRef.set({
      'amount': amount,
      'paymentId': paymentId,
      'status': status, // 'captured' or 'failed'
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final paymentId = response.paymentId;
    double addedAmount = double.parse(_amountController.text);
    int amountInPaise = (addedAmount * 100).toInt();

    var headers = {
      'Content-Type': 'application/json',
      'Authorization':
          'Basic cnpwX3Rlc3Rfd1ByVHJQSFhXTzdYTjE6eklxd0RodkhPNEx3S20xU3BVVHU0Vzdx',
    };
    var data = json.encode({"amount": amountInPaise, "currency": "INR"});
    var dio = Dio();
    var captureResponse = await dio.request(
      'https://api.razorpay.com/v1/payments/$paymentId/capture',
      options: Options(method: 'POST', headers: headers),
      data: data,
    );

    if (captureResponse.statusCode == 200) {
      if (currentUser == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("User not logged in.")));
        return;
      }

      QuerySnapshot snapshot =
          await FirebaseFirestore.instance
              .collection('Users')
              .where('uid', isEqualTo: currentUser?.uid)
              .get();

      if (snapshot.docs.isNotEmpty) {
        DocumentSnapshot doc = snapshot.docs.first;
        double currentBalance =
            (doc['walletBalance'] as num?)?.toDouble() ?? 0.0;

        double newBalance = currentBalance + addedAmount;

        await doc.reference.update({'walletBalance': newBalance});

        // Add transaction to Firestore
        addTransactionToFirestore(
          amount: addedAmount,
          paymentId: paymentId ?? '',
          status: 'captured',
        );

        setState(() {
          _walletBalance = newBalance;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Payment Successful! ₹$addedAmount added.")),
        );

        _amountController.clear();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("User not found.")));
      }
    } else {
      print(captureResponse.statusMessage);
    }
  }

  Future<void> _handlePaymentError(PaymentFailureResponse response) async {
    addTransactionToFirestore(
      amount: double.parse(_amountController.text),
      paymentId: response.code.toString(),
      status: 'failed',
    );
    log('Payment failed: ${response.message} (Code: ${response.code})');
    _amountController.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Payment Failed. Please try again.")),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("External Wallet Selected.")));
  }

  void _startRazorpayCheckout() {
    String amount = _amountController.text.trim();
    if (amount.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Please enter an amount.")));

      return;
    }

    var options = {
      'key':
          'rzp_test_wPrTrPHXWO7XN1', // rzp_test_wPrTrPHXWO7XN1 // rzp_live_GZEjvPBJ7XlOYQ
      'amount': (double.parse(amount) * 100).toInt(),
      'name': 'FourMoral Wallet',
      'description': 'Add money to wallet',
      'currency': 'INR',
      'prefill': {
        'contact': profileDataModel?.mobileNumber,
        'email': profileDataModel?.emailAddress,
      },
      'theme': {'color': '#1976D2'},
    };

    try {
      _razorpay.open(options);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error opening Razorpay checkout.")),
      );
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Wallet', style: TextStyle(color: Colors.white)),
        backgroundColor: veryDarkBlue,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        // ignore: deprecated_member_use
        color: blue.withOpacity(0.3),
        height: double.infinity,
        child: SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: Colors.white,
                  child: ListTile(
                    leading: CircleAvatar(
                      // ignore: deprecated_member_use
                      backgroundColor: veryDarkBlue.withOpacity(0.2),
                      child: Icon(
                        Icons.account_balance_wallet,
                        color: veryDarkBlue,
                      ),
                    ),
                    title: const Text('Current Balance'),
                    subtitle: Text(
                      '₹ $_walletBalance',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'Add Money to Wallet',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixText: '₹ ',
                    hintText: 'Enter amount',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(
                      Icons.add_circle_outline,
                      color: Colors.white,
                    ),
                    onPressed: _startRazorpayCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: veryDarkBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    label: const Text(
                      'Add Money',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 30),
                const Text(
                  'Transaction History',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                FutureBuilder<String?>(
                  future: getFirestoreDocumentIdByUid(currentUser?.uid ?? ""),
                  builder: (context, docIdSnapshot) {
                    if (docIdSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return Center(
                        child: Theme(
                          data: ThemeData(platform: TargetPlatform.iOS),
                          child: const CircularProgressIndicator.adaptive(),
                        ),
                      );
                    }

                    final docId = docIdSnapshot.data;
                    if (docId == null) {
                      return Center(child: Text("User data not found."));
                    }

                    return StreamBuilder<QuerySnapshot>(
                      stream:
                          FirebaseFirestore.instance
                              .collection('Users')
                              .doc(docId)
                              .collection('Transactions')
                              .orderBy('timestamp', descending: true)
                              .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(
                            child: Theme(
                              data: ThemeData(platform: TargetPlatform.iOS),
                              child: const CircularProgressIndicator.adaptive(),
                            ),
                          );
                        }
                        final transactions = snapshot.data?.docs;
                        if (transactions == null || transactions.isEmpty) {
                          return Center(child: Text("No transactions yet."));
                        }

                        return ListView.builder(
                          shrinkWrap: true,
                          physics: NeverScrollableScrollPhysics(),
                          itemCount: transactions.length,
                          itemBuilder: (context, index) {
                            final txn = transactions[index];
                            final amount = txn['amount'];
                            final paymentId = txn['paymentId'];
                            final status = txn['status'];
                            final timestamp =
                                (txn['timestamp'] as Timestamp?)?.toDate();
                            return Card(
                              elevation: 4,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: Colors.white,
                              child: ListTile(
                                leading: Icon(
                                  status == 'captured'
                                      ? Icons.check_circle
                                      : Icons.cancel,
                                  color:
                                      status == 'captured'
                                          ? Colors.green
                                          : Colors.red,
                                ),
                                title: Text(
                                  "₹${amount.toStringAsFixed(2)}",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Payment ID: $paymentId"),
                                    if (timestamp != null)
                                      Text(
                                        "Date: ${DateFormat('yyyy-MM-dd hh:mm a').format(timestamp)}",
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
