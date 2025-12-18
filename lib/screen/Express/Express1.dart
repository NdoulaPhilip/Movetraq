import 'package:flutter/material.dart';
import 'package:movetrap/screen/orders/Order.dart';

class Done extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text(
              "Done",
              style: TextStyle(
                fontFamily: 'Inter',
                color: Colors.black,
                fontWeight: FontWeight.w400,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: const SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.check_circle, size: 90, color: Colors.green),
              SizedBox(height: 25),
              Text(
                "Successful",
                style: TextStyle(
                  fontFamily: 'Inter',
                  color: Colors.black,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

class Express1 extends StatefulWidget {
  const Express1({super.key});
  @override
  State<Express1> createState() => _Express1State();
}

class _Express1State extends State<Express1> {
  String? menuItem = 'e1';
  final TextEditingController productController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController detailsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Orders",
            style: TextStyle(
                fontFamily: 'Inter',
                color: Colors.black,
                fontWeight: FontWeight.w500,
                fontSize: 18)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tabs
              Row(
                children: [
                  GestureDetector(
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const Order()));
                      },
                      child: _tabItem("P2P Delivery", false)),
                  const SizedBox(width: 18),
                  _tabItem("Express Delivery", true),
                  const Spacer(),
                  DropdownButtonHideUnderline(
                    child: DropdownButton(
                      value: menuItem,
                      items: const [
                        DropdownMenuItem(
                            value: 'e1',
                            child: Text(
                              'Send',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontFamily: 'Inter'),
                            )),
                        DropdownMenuItem(
                            value: 'e2',
                            child: Text(
                              'Receive',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 15,
                                  fontFamily: 'Inter'),
                            )),
                      ],
                      elevation: 0,
                      icon: const Icon(Icons.keyboard_arrow_down,
                          color: Colors.black, size: 20),
                      dropdownColor: Colors.white,
                      onChanged: (String? value) {
                        setState(() {
                          menuItem = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Entry fields
              _customTextField("Current location"),
              const SizedBox(height: 10),
              _customTextField("Enter location for delivery"),
              const SizedBox(height: 14),
              // Product input fields
              TextField(
                controller: productController,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Product Description",
                  filled: true,
                  fillColor: Color(0xFFF5F7FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                decoration: InputDecoration(
                  hintText: "Enter Amount",
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detailsController,
                minLines: 3,
                maxLines: 5,
                style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                decoration: InputDecoration(
                  hintText: "More details",
                  filled: true,
                  fillColor: Color(0xFFF5F7FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 22),
                ),
              ),
              const SizedBox(height: 16),
              // Quick Icon Buttons Row
              Row(
                children: [
                  _quickIconButton(Icons.image),
                  const SizedBox(width: 12),
                  _quickIconButton(Icons.add_circle_outline),
                ],
              ),
              const SizedBox(height: 20),
              // Delivery Terms
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Color(0xFFF5F6FA),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Delivery Terms",
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    SizedBox(height: 10),
                    Text(
                      "1. Order Confirmation\n"
                      "Ensure the order is verified (payment, address, item) before dispatch. \nConfirm availability of goods before promising delivery.\n"
                      "2. Delivery Address & Contact\n"
                      "Require a complete and accurate address (with landmarks if necessary...).\nCollect a valid phone number of the recipient.",
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          color: Colors.black54,
                          height: 1.42),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
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
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: 17,
                        color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabItem(String label, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 18),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'Inter',
          color: selected ? Colors.black : Colors.grey,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  Widget _customTextField(String hint) {
    return TextField(
      style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontFamily: 'Inter', fontSize: 13),
        filled: true,
        fillColor: Color(0xFFF5F7FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(9),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Widget _quickIconButton(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Color(0xFFE5EAF1)),
      ),
      child: Icon(icon, color: Colors.grey[700], size: 26),
    );
  }
}

// BottomSheet for order details
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
    return SafeArea(
      child: Padding(
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
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    letterSpacing: 0.1),
              ),
              const SizedBox(height: 18),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "From:   ",
                    style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(
                      "17, Odupitan Street, Ikorodu, Lagos.",
                      style: TextStyle(fontFamily: 'Inter', color: Colors.black87, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "To:      ",
                    style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: Text(
                      "20, Yusuf Street, Papa- Ajao, Mushin, Lagos State.",
                      style: TextStyle(fontFamily: 'Inter', color: Colors.black87, fontSize: 14),
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
                        fontFamily: 'Inter',
                        color: Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 5),
                  Text("5,000 Naira",
                      style: TextStyle(fontFamily: 'Inter', color: Colors.black87, fontSize: 14)),
                ],
              ),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Text(
                    "Delivery period:",
                    style: TextStyle(
                        fontFamily: 'Inter',
                        color: Colors.black54,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  SizedBox(width: 5),
                  Text("24hrs",
                      style: TextStyle(fontFamily: 'Inter', color: Colors.black87, fontSize: 14)),
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
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13),
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
                  style: TextStyle(fontFamily: 'Inter', fontSize: 13),
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
                        backgroundColor: Color(0xFFF1F3F6),
                        side: BorderSide.none,
                        padding: EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: const Text("Cancel Order",
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600)),
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
                              Navigator.pop(context);
                              Navigator.push(context,
                                  MaterialPageRoute(builder: (c) => Done()));
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
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
