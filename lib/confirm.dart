import 'package:flutter/material.dart';

class confirm extends StatefulWidget {
  const confirm({super.key});

  @override
  State<confirm> createState() => _confirmState();
}

class _confirmState extends State<confirm> {
  bool agreeTerms1 = false;
  bool agreeTerms2 = false;

  @override
  Widget build(BuildContext context) {
    const Color lightGray = Color.fromRGBO(232, 237, 245, 1);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          "Order Details",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications_none, color: Colors.black),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 🔹 Location & Stats
            const Text("Location: Ikorodu",
                style: TextStyle(fontSize: 14, color: Colors.black)),
            const SizedBox(height: 4),
            const Text("Good Rating %: 99%",
                style: TextStyle(fontSize: 13, color: Colors.black)),
            const SizedBox(height: 4),
            const Text("30-Days Order Completed %: 99%",
                style: TextStyle(fontSize: 13, color: Colors.black)),
            const SizedBox(height: 16),

            // 🔹 Input Fields
           const SizedBox(
              height: 40,
              child: TextField(
                style:  TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Enter Amount",
                  hintStyle: TextStyle(fontSize: 12, color: Colors.grey),
                  filled: true,
                  fillColor: lightGray,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                     EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 10),
           const SizedBox(
              height: 40,
              child: TextField(
                maxLines: null,
                expands: true,
                style:  TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: "Enter order details",
                  hintStyle:  TextStyle(fontSize: 12, color: Colors.grey),
                  filled: true,
                  fillColor: lightGray,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding:
                 EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 🔹 Complete Order Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Text(
                    "Complete your Order",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Image.asset("images/Approval.png", scale: 1.5),
                  const SizedBox(height: 16),

                  // ✅ Checkboxes
                  Row(
                    children: [
                      Checkbox(
                        value: agreeTerms1,
                        activeColor: Colors.blue,
                        onChanged: (v) {
                          setState(() {
                            agreeTerms1 = v ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          "You agree to the advertiser terms and conditions",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Checkbox(
                        value: agreeTerms2,
                        activeColor: Colors.blue,
                        onChanged: (v) {
                          setState(() {
                            agreeTerms2 = v ?? false;
                          });
                        },
                      ),
                      const Expanded(
                        child: Text(
                          "You agree to the delivery terms and conditions",
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // 🔹 Buttons
                  Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: const BorderSide(color: Colors.black26),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: const Text("Cancel Order",
                              style: TextStyle(color: Colors.black)),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            backgroundColor: Colors.blue,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: (agreeTerms1 && agreeTerms2)
                              ? () {
                                  // Handle order confirmation
                                }
                              : null, // Disable until checked
                          child: const Text("Confirm Order",
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
