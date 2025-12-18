import 'package:flutter/material.dart';
// import 'package:movetrap/login.dart';
import 'package:movetrap/screen/otps/otp1.dart';

class phone extends StatefulWidget {
  const phone({super.key});

  @override
  State<phone> createState() => _phoneState();
}

class _phoneState extends State<phone> {
  TextEditingController phoneCtrl = TextEditingController();

  String selectedCountry = "Nigeria";
  String countryCode = "+234";
  String flagUrl = "images/Nigeria.png";

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: Colors.white, // Make the whole screen white
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Arrow back button at the top-left
              SizedBox(height: 20),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.arrow_back_ios_new, color: Colors.black),
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ],
              ),
              SizedBox(height: 8),
              Center(
                child: Image.asset(
                  "images/logo.png",
                  height: 55,
                  width: 55,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 28),
              const Center(
                child: Text(
                  "Welcome back",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 7),
              const Center(
                child: Text(
                  "Continue with your phone number to login",
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
              SizedBox(height: 38),
              const Row(
                children: [
                  Text(
                    "Country",
                    style: TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                  Text('*', style: TextStyle(color: Colors.red)),
                  SizedBox(width: 28),
                  Text(
                    "Phone number",
                    style: TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                  Text('*', style: TextStyle(color: Colors.red)),
                ],
              ),
              SizedBox(height: 6),
              Row(
                children: [
                  Container(
                    width: 70,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.grey[300]!,
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(7),
                    ),
                    alignment: Alignment.center,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedCountry,
                        isExpanded: false,
                        icon: Icon(Icons.arrow_drop_down, color: Colors.black45),
                        items: [
                          DropdownMenuItem(
                            value: "Nigeria",
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: Image.asset(
                                flagUrl,
                                width: 26,
                                height: 18,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ],
                        onChanged: (val) {
                          // Add logic for more countries if needed.
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: 6),
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 10.0, right: 4.0),
                            child: Text(
                              countryCode,
                              style: TextStyle(fontSize: 16, color: Colors.black),
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: phoneCtrl,
                              keyboardType: TextInputType.phone,
                              style: TextStyle(fontSize: 16),
                              decoration: InputDecoration(
                                border: InputBorder.none,
                                hintText: '09000000000',
                                hintStyle: TextStyle(color: Colors.grey[400]),
                                contentPadding: EdgeInsets.symmetric(vertical: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Spacer(),
              SizedBox(
                width: double.infinity,
                height: size.height * 0.062,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF1677FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => otp1(
                          userName: 'Opeyemi',
                          phoneNumber: phoneCtrl.text,
                        ),
                      ),
                    );
                  },
                  child: const Text(
                    "Continue",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 18),
            ],
          ),
        ),
      ),
    );
  }
}
