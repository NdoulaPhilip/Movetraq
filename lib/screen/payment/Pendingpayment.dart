import 'package:flutter/material.dart';
import 'package:movetrap/History.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';
import 'package:movetrap/screen/orders/Pendingorder.dart';
import 'package:movetrap/Report.dart';

void main() => runApp(const Pendingpayment());

class Pendingpayment extends StatelessWidget {
  const Pendingpayment({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Payment',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        primarySwatch: Colors.indigo,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const PaymentScreen(),
    );
  }
}

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pendingPayments = List.generate(3, (index) => 'Payment Release');
    return Scaffold(
      backgroundColor: TColors.textWhite,
      appBar: AppBar(
        backgroundColor: TColors.textWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) {
                return const Report();
              },
            ));
          },
        ),
        title: const Text(
          'Payment',
          style: TextStyle(color: TColors.textPrimary, fontSize: 16,fontFamily: 'Inter Medium', fontWeight: FontWeight.w500
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(context, MaterialPageRoute(
                builder: (context) {
                  return const History();
                },
              ));
            },
            child: const Text('History',
                style: TextStyle(color: TColors.textPrimary, fontSize: 12,fontFamily: 'Inter Regular', fontWeight: FontWeight.w400)),
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.only(left: 20, top: 20),
            child: Text(
              'Pending payment',
               style: TextStyle(color: TColors.textPrimary, fontSize: 14,fontFamily: 'Inter Medium', fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 10),
          ...pendingPayments
              .map((title) => paymentTile(context, title))
              .toList(),
        ],
      ),
    );
  }
}

// Move this function outside of the widget class, so it receives BuildContext
Widget paymentTile(BuildContext context, String title) {
  return Container(
    margin: const EdgeInsets.only(bottom: 14),
    decoration: const BoxDecoration(
      color:TColors.secondary,
      // borderRadius: BorderRadius.circular(12),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFE8EDF5),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.all(6),
            child: const Icon(Icons.access_time_rounded,
                size: 20, color: Colors.black54),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                     style:const TextStyle(color: TColors.textPrimary, fontSize: 15,fontFamily: 'Inter Medium', fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                const Text('Pending',
                   style: TextStyle(color: Color(0xFF4A739C), fontSize: 12,fontFamily: 'Inter Regular', fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const Pendingorder(),
                  ));
            },
            child: const Text('Pay',
                style: TextStyle(color: Color(0xFFFFFFFF), fontSize: 12,fontFamily: 'Inter SemiBold', fontWeight: FontWeight.w400)),
          ),
        ],
      ),
    ),
  );
}
