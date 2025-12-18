import 'package:flutter/material.dart';
import 'package:movetrap/Chart.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: Orderdetails(),
  ));
}

class Orderdetails extends StatefulWidget {
  const Orderdetails({Key? key}) : super(key: key);

  @override
  State<Orderdetails> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<Orderdetails> {
  bool agree1 = false;
  bool agree2 = false;
  final TextEditingController productController = TextEditingController();
  final TextEditingController amountController = TextEditingController();
  final TextEditingController detailsController = TextEditingController();

  void showCompleteOrderPopup() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom,
              top: 22,
              left: 20,
              right: 20),
          child: StatefulBuilder(
            builder: (popupContext, setModalState) => SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Complete your Order',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 24),
                  const Icon(Icons.verified,
                      size: 80, color: Colors.lightGreen),
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      Checkbox(
                          value: agree1,
                          onChanged: (v) {
                            setModalState(() {
                              agree1 = v!;
                            });
                          }),
                      const SizedBox(width: 5),
                      const Expanded(
                        child: Text(
                          "You agree to the advertiser terms and condition",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                          value: agree2,
                          onChanged: (v) {
                            setModalState(() {
                              agree2 = v!;
                            });
                          }),
                      const SizedBox(width: 5),
                      const Expanded(
                        child: Text(
                          "You agree to the advertiser terms and condition",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5F5F5),
                        foregroundColor: Colors.black,
                        side: BorderSide.none,
                        minimumSize: const Size.fromHeight(44),
                      ),
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel Order'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed:
                          (agree1 && agree2) ? () => Navigator.pop(ctx) : null,
                      child: const Text('Confirm Order'),
                    ),
                  ),
                  SizedBox(height: MediaQuery.of(ctx).padding.bottom),
                ],
              ),
            ),
          ),
        );
      },
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

  Widget delivererTermsCard() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Deliverer Terms",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
          SizedBox(height: 10),
          Text(
            "1. Order Confirmation\n"
            "Ensure the order is verified (payment, address, item details) before dispatch.\n"
            "Confirm availability of goods before promising delivery.\n\n"
            "2. Delivery Address & Contact\n"
            "Require a complete and accurate address (with landmarks if necessary).\n"
            "Collect a valid phone number of the recipient.",
            style: TextStyle(fontSize: 10, color: Colors.black54, height: 2.45),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.textWhite,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: const BackButton(color: Colors.black),
        title: const Text(
          "Order Details",
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.message_outlined, color: Colors.black),
            onPressed: () {
              pushScreen(context, screen: const Chart(), withNavBar: false);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Text("Location :",
                      style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontFamily: 'Inter Medium')),
                  SizedBox(width: 5),
                  Text('ikorodu',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontFamily: 'Inter Medium')),
                ],
              ),
              const SizedBox(height: 6),
              const Row(
                children: [
                  Text("Good Rating %: ",
                      style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontFamily: 'Inter Medium')),
                  SizedBox(width: 5),
                  Text('99%',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontFamily: 'Inter Medium')),
                ],
              ),
              const SizedBox(height: 15),
              const Row(
                children: [
                  Text("30-Days Order Completed %:",
                      style: TextStyle(
                          color: Colors.blue,
                          fontSize: 12,
                          fontFamily: 'Inter Medium')),
                  SizedBox(width: 5),
                  Text('99% Completion Rate',
                      style: TextStyle(
                          color: Colors.black,
                          fontSize: 12,
                          fontFamily: 'Inter Medium')),
                ],
              ),
              const SizedBox(height: 20),
              TextField(
                controller: productController,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: "Product Description",
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: amountController,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: "Enter Amount",
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: detailsController,
                minLines: 3,
                maxLines: 5,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(
                  hintText: "More details",
                  filled: true,
                  fillColor: const Color(0xFFF5F7FA),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 22),
                ),
              ),
              const SizedBox(height: 30),
              Row(
                children: [
                  _quickIconButton(Icons.image),
                  const SizedBox(width: 12),
                  _quickIconButton(Icons.add_circle_outline),
                ],
              ),
              delivererTermsCard(),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: showCompleteOrderPopup,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF219BFF),
                    minimumSize: const Size.fromHeight(48),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(7),
                    ),
                  ),
                  child: const Text(
                    "Create Order",
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom),
            ],
          ),
        ),
      ),
    );
  }
}
