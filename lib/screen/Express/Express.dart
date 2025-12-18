import 'package:flutter/material.dart';
import 'package:movetrap/Done.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';
import 'package:movetrap/screen/navbar_screen/Hom.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Express(),
  ));
}

class Express extends StatefulWidget {
  const Express({super.key});

  @override
  State<Express> createState() => _ExpressState();
}

class _ExpressState extends State<Express> {
  TextEditingController locationCtrl = TextEditingController();
  TextEditingController descCtrl = TextEditingController();
  TextEditingController amountCtrl = TextEditingController();
  TextEditingController detailCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.textWhite,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Express Delivery",
          style: TextStyle(
            color: Colors.black, fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
         leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) {
                return const Hom();
              },
            ));
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _roundedField(
                hint: "Enter location for delivery",
                controller: locationCtrl,
                prefix: Icons.search,
              ),
              const SizedBox(height: 14),
              _roundedField(hint: "Product Description", controller: descCtrl),
              const SizedBox(height: 14),
              _roundedField(hint: "Enter Amount", controller: amountCtrl),
              const SizedBox(height: 14),
              _roundedField(
                hint: "More details",
                controller: detailCtrl,
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _quickIconButton(Icons.image),
                  const SizedBox(width: 12),
                  _quickIconButton(Icons.add_circle_outline),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Delivery Terms",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "1. Order Confirmation\n"
                      "Ensure the order is verified (payment, address, item) before dispatch. \nConfirm availability of goods before promising delivery.\n"
                      "2. Delivery Address & Contact\n"
                      "Require a complete and accurate address (with landmarks if necessary...).\nCollect a valid phone number of the recipient.",
                      style: TextStyle(
                          fontSize: 12, color: Colors.black54, height: 2.42),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 50),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) {
                        return MediaQuery.removeViewInsets(
                          removeBottom: true,
                          context: context,
                          child: SafeArea(
                            top: true,
                            bottom: false,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(18),
                                ),
                              ),
                              child: const OrderDetailsBottomSheet(),
                            ),
                          ),
                        );
                      },
                    );
                  },
                  child: const Text(
                    "Create Order",
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _roundedField({
    required String hint,
    required TextEditingController controller,
    IconData? prefix,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: prefix != null ? Icon(prefix, color: Colors.grey) : null,
        contentPadding:
            const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
        filled: true,
        fillColor: const Color(0xFFF3F4F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
        hintStyle: const TextStyle(color: Colors.black38, fontSize: 12),
      ),
    );
  }

  Widget _quickIconButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: const Color(0xFFE5EAF1)),
      ),
      child: Icon(icon, color: Colors.grey[700], size: 26),
    );
  }
}

class OrderDetailsBottomSheet extends StatefulWidget {
  const OrderDetailsBottomSheet({super.key});

  @override
  State<OrderDetailsBottomSheet> createState() =>
      _OrderDetailsBottomSheetState();
}

class _OrderDetailsBottomSheetState extends State<OrderDetailsBottomSheet> {
  bool agree1 = false;
  bool agree2 = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        left: 16,
        right: 16,
        top: 18,
        bottom: 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 35,
              height: 4,
              margin: const EdgeInsets.only(bottom: 15),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(5),
              ),
            ),
            const Text(
              "Order Details",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.1),
            ),
            const SizedBox(height: 18),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "From:   ",
                  style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Text(
                    "17, Odupitan Street, Ikorodu, Lagos.",
                    style: TextStyle(color: Colors.black87, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "To:      ",
                  style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: Text(
                    "20, Yusuf Street, Papa- Ajao, Mushin, Lagos State.",
                    style: TextStyle(color: Colors.black87, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Text(
                  "Amount:",
                  style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 5),
                Text("5,000 Naira",
                    style: TextStyle(color: Colors.black87, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            const Row(
              children: [
                Text(
                  "Delivery period:",
                  style: TextStyle(
                      color: Colors.black54,
                      fontSize: 12,
                      fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 5),
                Text("24hrs",
                    style: TextStyle(color: Colors.black87, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 18),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: agree1,
              onChanged: (val) => setState(() => agree1 = val ?? false),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                "You agree to the advertiser terms and condition",
                style: TextStyle(fontSize: 12),
              ),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: agree2,
              onChanged: (val) => setState(() => agree2 = val ?? false),
              dense: true,
              controlAffinity: ListTileControlAffinity.leading,
              title: const Text(
                "You agree to the advertiser terms and condition",
                style: TextStyle(fontSize: 12),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      backgroundColor: const Color(0xFFF1F3F6),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text("Cancel Order",
                        style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: (agree1 && agree2)
                        ? () {
                            Navigator.push(context, MaterialPageRoute(
                              builder: (context) {
                                return const Done();
                              },
                            ));
                          }
                        : null,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        disabledBackgroundColor: Colors.blue[200],
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(7),
                        )),
                    child: const Text(
                      "Confirm Order",
                      style: TextStyle(
                          fontWeight: FontWeight.w600, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
