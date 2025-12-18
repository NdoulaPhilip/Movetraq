import 'package:flutter/material.dart';
import 'package:movetrap/History.dart';

void main() {
  runApp(const Paymenthistory());
}

class Paymenthistory extends StatelessWidget {
  const Paymenthistory({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Payment Details',
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const PaymentDetailsScreen(),
    );
  }
}

class PaymentDetailsScreen extends StatelessWidget {
  const PaymentDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (context) {
              return const History();
            },
          )),
        ),
        title: const Text(
          'Payment Details',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Information',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Colors.black,
                fontFamily: 'Inter Medium',
              ),
            ),
            const SizedBox(height: 20),

            // Deliverer Section
            Container(
              padding:const EdgeInsets.symmetric(horizontal: 13.5,vertical: 13.5),
               color:const Color(0xFFF7FAFC),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: const AssetImage('images/ord1.png'),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Deliverer: Alex Johnson',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                      fontFamily: 'Inter Medium',
                      
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Payment Details
            _buildDetailRow('Amount', '\$150.00'),
            _buildDivider(),
            _buildDetailRow('Date', 'July 26, 2025'),
            _buildDivider(),
            _buildDetailRow('Transaction ID', 'H6724232472'),
            _buildDivider(),
            _buildDetailRow('Time', '10:30 AM'),
            _buildDivider(),
            _buildDetailRow('Status', 'Completed'),

            const Spacer(),

            // Download Button
            SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton(
                onPressed: () {
                  // Handle download receipt
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007AFF),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Download Receipt',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter Bold',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style:const TextStyle(
              fontSize: 12,
              color: Color(0xFF47739E),
              fontFamily: 'Inter Regular',
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              color: Color(0xFF000000),
              fontFamily: 'Inter Regular',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[200],
    );
  }
}
