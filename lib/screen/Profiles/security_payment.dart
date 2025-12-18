import 'package:flutter/material.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';
import 'package:movetrap/screen/Profiles/Profile.dart';

void main() => runApp(const security_payment());

class security_payment extends StatelessWidget {
  const security_payment({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter', // Make sure Inter font is added to pubspec.yaml
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const PaymentScreen(),
    );
  }
}

class PaymentScreen extends StatelessWidget {
  const PaymentScreen({Key? key}) : super(key: key);

  Color get cardBg => const Color(0xFFF6F9FB);
  Color get accentBlue => const Color(0xFFE5F0FF);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) {
                return const Profile();
              },
            ));
          },
        ),
        title: const Text(
          'Payment',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 24),
          const Text(
            'Payment methods',
            style: TextStyle(color: TColors.textPrimary, fontSize: 14,fontFamily: 'Inter Bold', fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          // Payment methods cards
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
             // color:const Color(0xFFF7FAFC),
              borderRadius: BorderRadius.circular(1),
            ),
            child: Column(
              children: [
                buildPaymentItem(
                  icon: Icons.account_balance,
                  title: 'Checking',
                  subtitle: 'Bank of America',
                  trailing: Switch(value: false, onChanged: (val) {}),
                ),
                const SizedBox(height: 10),
                buildPaymentItem(
                  icon: Icons.account_balance,
                  title: 'Checking',
                  subtitle: 'Chase',
                  trailing: checkbox(),
                ),
                const SizedBox(height: 10),
                buildPaymentItem(
                  icon: Icons.credit_card,
                  title: 'Credit card',
                  subtitle: 'Visa ... 4567',
                  trailing: checkbox(),
                ),
                const SizedBox(height: 10),
                buildPaymentItem(
                  icon: Icons.credit_card,
                  title: 'Debit card',
                  subtitle: 'Mastercard ... 8901',
                  trailing: checkbox(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Add payment method',
            style: TextStyle(color: TColors.textPrimary, fontSize: 14,fontFamily: 'Inter Bold', fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              //color: cardBg,
              borderRadius: BorderRadius.circular(1),
            ),
            child: Column(
              children: [
                buildActionItem(
                  icon: Icons.account_balance,
                  title: 'Bank account',
                  onTap: () {},
                ),
                divider(),
                buildActionItem(
                  icon: Icons.credit_card,
                  title: 'Credit or debit ca...',
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildPaymentItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color:const Color(0xFFE8EDF5),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color:const Color(0xFF0D141C), size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                 style: const TextStyle(color: TColors.textPrimary, fontSize: 12,fontFamily: 'Inter Medium', fontWeight: FontWeight.w500)),
              Text(subtitle,
                  style: const TextStyle(color: Color(0xFF47739E), fontSize: 10,fontFamily: 'Inter Regular', fontWeight: FontWeight.w400)),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Widget buildActionItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Row(
          children: [
            Icon(icon, color:const Color(0xFF0D141C), size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Text(title,
                 style: const TextStyle(color: TColors.textPrimary, fontSize: 12,fontFamily: 'Inter Medium', fontWeight: FontWeight.w500 )),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 20),
              child: Icon(Icons.arrow_forward, size: 20, color: Colors.black),
            ),
          ],
        ),
      ),
    );
  }

  Widget divider() {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFF0F2F6));
  }

  Widget checkbox() {
    return Checkbox(
      value: false,
      onChanged: (val) {},
      activeColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      side: const BorderSide(color: Colors.black),
    );
  }
}
