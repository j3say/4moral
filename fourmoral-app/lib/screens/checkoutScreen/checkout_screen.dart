import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class AmazonLikeCheckoutPage extends StatefulWidget {
  const AmazonLikeCheckoutPage({super.key});

  @override
  State<AmazonLikeCheckoutPage> createState() => _AmazonLikeCheckoutPageState();
}

class _AmazonLikeCheckoutPageState extends State<AmazonLikeCheckoutPage> {
  late Razorpay _razorpay;
  bool _isLoading = false;

  final String backendBaseUrl =
      "https://api.razorpay.com/v1"; // Replace with your backend API URL

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _startCheckout() async {
    setState(() => _isLoading = true);

    try {
      var headers = {
        'Content-Type': 'application/json',
        'Authorization':
            'Basic cnpwX3Rlc3Rfd1ByVHJQSFhXTzdYTjE6eklxd0RodkhPNEx3S20xU3BVVHU0Vzdx',
      };
      var data = json.encode({
        "amount": 50000,
        "currency": "INR",
        "receipt": "Receipt no. 1",
        "notes": {
          "notes_key_1": "Tea, Earl Grey, Hot",
          "notes_key_2": "Tea, Earl Grey… decaf.",
        },
      });
      var dio = Dio();
      var response = await dio.request(
        'https://api.razorpay.com/v1/orders',
        options: Options(method: 'POST', headers: headers),
        data: data,
      );

      if (response.statusCode != 200) {
        throw Exception("Failed to create order");
      }

      var options = {
        'key': 'rzp_test_wPrTrPHXWO7XN1', // rzp_live_GZEjvPBJ7XlOYQ
        'amount': response.data['amount'],
        'currency': response.data['currency'],
        'name': 'Moral 1',
        'description': 'Payment for your order',
        'order_id': response.data['id'], // Order ID from your backend
        'prefill': {'contact': '9876543210', 'email': 'user@example.com'},
        'theme': {'color': '#3399cc'},
      };

      _razorpay.open(options);
    } catch (e) {
      print("Error: $e");
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    print("Payment Success: ${response.paymentId}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("✅ Payment Successful: ${response.paymentId}")),
    );
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    print("Payment Error: ${response.code} | ${response.message}");
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("❌ Payment Failed: ${response.message}")),
    );
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    print("External Wallet: ${response.walletName}");
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text("Wallet: ${response.walletName}")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Checkout")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child:
            _isLoading
                ? Center(child: CircularProgressIndicator())
                : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Your Order",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListTile(
                        leading: Icon(Icons.shopping_bag, size: 40),
                        title: Text("Awesome Product"),
                        subtitle: Text("₹500"),
                        trailing: Icon(Icons.arrow_forward_ios),
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      "Shipping Address",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "John Doe\n123, Main Street\nMumbai, India",
                      style: TextStyle(fontSize: 16),
                    ),
                    Spacer(),
                    ElevatedButton(
                      onPressed: _startCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange.shade600,
                        minimumSize: Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: Text(
                        "Proceed to Pay ₹500",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}
