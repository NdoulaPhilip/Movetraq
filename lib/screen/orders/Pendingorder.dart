import 'package:flutter/material.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';
import 'package:movetrap/screen/otps/Otp3.dart';
import 'package:movetrap/screen/payment/Pendingpayment.dart';

void main() => runApp(const Pendingorder());

class Pendingorder extends StatelessWidget {
  const Pendingorder({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ReleasePaymentScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ReleasePaymentScreen extends StatelessWidget {
  const ReleasePaymentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.textWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) {
                return const Pendingpayment();
              },
            ));
          },
        ),
        title: const Text(
          'Release Payment',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w600,
            fontSize: 17,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Payment Release',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            const Text(
              'Please confirm your order delivery to ensure you have successfully received your order. Once confirmed, you may proceed to release the payment.',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color:const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(14),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Order Details',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 14,fontFamily: "Inter Bold")),
                  SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Amount', style: TextStyle(color:Color(0xFF000000), fontFamily: 'Inter Regular')),
                      Text('5,000 Naira',
                          style: TextStyle(fontWeight: FontWeight.w700,color:Color(0xFF000000), fontFamily: 'Inter Bold',)),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Destination',
                          style: TextStyle(color:Color(0xFF000000), fontFamily: 'Inter Regular')),
                      Text('17, Olasuwon Street, Ikeja, Lagos.',
                         style: TextStyle(fontWeight: FontWeight.w700,color:Color(0xFF000000), fontFamily: 'Inter Bold')),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Transaction ID',
                          style: TextStyle(color:Color(0xFF000000), fontFamily: 'Inter Regular')),
                      Text('12345678321',
                          style: TextStyle(fontWeight: FontWeight.w700,color:Color(0xFF000000), fontFamily: 'Inter Bold')),
                    ],
                  ),
                  SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Order Time',
                          style: TextStyle(color:Color(0xFF000000), fontFamily: 'Inter Regular')),
                      Text('29-09-2025 14:05:13',
                          style: TextStyle(fontWeight: FontWeight.w700,color:Color(0xFF000000), fontFamily: 'Inter Bold')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Payment Method',
                style: TextStyle(fontSize:16,fontWeight: FontWeight.w500 ,color:Color(0xFF000000), fontFamily: 'Inter Medium')),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                 color:const Color(0xFFF7FAFC),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.account_balance_wallet_outlined,
                        color: Colors.black87),
                    title: const Text('Checking',
                        style: TextStyle(fontSize:16,fontWeight: FontWeight.w500 ,color:Color(0xFF000000), fontFamily: 'Inter Medium')),
                    subtitle:
                        const Text('Wallet', style: TextStyle(fontSize: 13)),
                    trailing: Switch(value: true, onChanged: (v) {}),
                  ),
                  //const Divider(height: 1),
                  ListTile(
                    leading:
                        const Icon(Icons.credit_card_outlined, color: Colors.black87),
                    title: const Text('Debit card',
                        style: TextStyle(fontSize:16,fontWeight: FontWeight.w500 ,color:Color(0xFF000000), fontFamily: 'Inter Medium')),
                    subtitle: const Text('Mastercard ... 8901',
                        style: TextStyle(fontSize: 13)),
                    trailing: Checkbox(value: false, onChanged: (v) {}),
                  ),
                ],
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Release Payment',
                    style: TextStyle(fontSize: 15, color: Colors.white)),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    isScrollControlled: true,
                    builder: (_) => const ReleasePaymentConfirmationModal(),
                  );
                },
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),
      ),
    );
  }
}

class ReleasePaymentConfirmationModal extends StatefulWidget {
  const ReleasePaymentConfirmationModal({super.key});

  @override
  State<ReleasePaymentConfirmationModal> createState() =>
      _ReleasePaymentConfirmationModalState();
}

class _ReleasePaymentConfirmationModalState
    extends State<ReleasePaymentConfirmationModal> {
  bool agreeTerms1 = false;
  bool agreeTerms2 = false;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Release Payment',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
            const SizedBox(height: 10),
            const SizedBox(height: 10),
            Center(
              child: Image.asset('images/Approval.png'),
            ),
            const SizedBox(height: 14),
            CheckboxListTile(
              value: agreeTerms1,
              onChanged: (v) {
                setState(() {
                  agreeTerms1 = v ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                  'You agree to the advertiser terms and condition',
                  style: TextStyle(fontSize: 14)),
            ),
            CheckboxListTile(
              value: agreeTerms2,
              onChanged: (v) {
                setState(() {
                  agreeTerms2 = v ?? false;
                });
              },
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                  'You agree to the advertiser terms and condition',
                  style: TextStyle(fontSize: 14)),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(vertical: 15),
                    ),
                    child: const Text('Cancel', style: TextStyle(fontSize: 15)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('Release',
                    style: TextStyle(fontSize: 15, color: Colors.white)),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) {
                      return const Otp3();
                    },
                  ));
                },
              ),
            ),
            const SizedBox(height: 14),
          ],
        ),
      ),
    );
  }
}
