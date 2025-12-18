import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MaterialApp(
    home: Paymentmethod(),
    debugShowCheckedModeBanner: false,
  ));
}

class Paymentmethod extends StatefulWidget {
  const Paymentmethod({super.key});

  @override
  State<Paymentmethod> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<Paymentmethod> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark.copyWith(
        statusBarColor: Colors.white,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: const BackButton(color: Colors.black),
          centerTitle: true,
          title: const Text(
            "Payment methods",
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          ),
        ),
        backgroundColor: Colors.white,
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          children: [
            const Text(
              "Payment methods",
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
            ),
            const SizedBox(height: 10),

            // Wallet / bank / card options
            _methodTile(
              index: 0,
              icon: Icons.account_balance,
              title: "Checking",
              subtitle: "Bank of America",
              trailing: Switch(
                value: selected == 0,
                activeThumbColor: const Color(0xFF0066FF),
                onChanged: (_) => setState(() => selected = 0),
              ),
              onTap: () => setState(() => selected = 0),
              selected: selected == 0,
            ),
            _methodTile(
              index: 1,
              icon: Icons.account_balance,
              title: "Checking",
              subtitle: "Chase",
              trailing: _checkbox(selected == 1),
              onTap: () => setState(() => selected = 1),
              selected: selected == 1,
            ),
            _methodTile(
              index: 2,
              icon: Icons.credit_card,
              title: "Credit card",
              subtitle: "Visa •••• 4527",
              trailing: _checkbox(selected == 2),
              onTap: () => setState(() => selected = 2),
              selected: selected == 2,
            ),
            _methodTile(
              index: 3,
              icon: Icons.credit_card,
              title: "Debit card",
              subtitle: "Mastercard •••• 9891",
              trailing: _checkbox(selected == 3),
              onTap: () => setState(() => selected = 3),
              selected: selected == 3,
            ),

            const SizedBox(height: 18),
            const Text(
              "Add payment method",
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15, color: Colors.black),
            ),
            const SizedBox(height: 8),
            _addRow(
              icon: Icons.account_balance,
              text: "Bank account",
              onTap: () {},
            ),
            _addRow(
              icon: Icons.credit_card,
              text: "Credit or debit card",
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkbox(bool value) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFCBD2D9)),
        // No borderRadius
        color: value ? const Color(0xFF0066FF) : Colors.white,
      ),
      child: value
          ? const Icon(Icons.check, size: 16, color: Colors.white)
          : const SizedBox.shrink(),
    );
  }

  Widget _methodTile({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
    required bool selected,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              color: const Color(0xFFEFF1F7),
              child: Icon(icon, size: 22, color: const Color(0xFF344054)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black)),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      style:
                          const TextStyle(fontSize: 12, color: Colors.black54)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }

  Widget _addRow({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38,
        height: 38,
        color: const Color(0xFFEFF1F7),
        child: Icon(icon, size: 22, color: const Color(0xFF344054)),
      ),
      title: Text(
        text,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Color(0xFF99A1A9)),
      contentPadding: EdgeInsets.zero,
      horizontalTitleGap: 14,
    );
  }
}
