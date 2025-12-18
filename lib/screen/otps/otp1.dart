import 'package:flutter/material.dart';
import 'dart:async';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: otp1(userName: "Opeyemi", phoneNumber: "090******63"),
      debugShowCheckedModeBanner: false,
    );
  }
}

// ignore: camel_case_types
class otp1 extends StatefulWidget {
  final String userName;
  final String phoneNumber;

  const otp1({required this.userName, required this.phoneNumber, Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _otp1State createState() => _otp1State();
}

// ignore: camel_case_types
class _otp1State extends State<otp1> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  int secondsRemaining = 15 * 60; // 15 minutes countdown
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    for (int i = 0; i < 4; i++) {
      _controllers[i].addListener(() {
        if (_controllers[i].text.length == 1 && i < 3) {
          _focusNodes[i + 1].requestFocus();
        }
      });
    }
  }

  void _startTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (secondsRemaining > 0) {
        setState(() {
          secondsRemaining--;
        });
      } else {
        t.cancel();
      }
    });
  }

  String get timerText {
    int min = secondsRemaining ~/ 60;
    int sec = secondsRemaining % 60;
    return "${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}";
  }

  @override
  void dispose() {
    timer?.cancel();
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isAllFilled = _controllers.every((ctrl) => ctrl.text.trim().isNotEmpty);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // Title row with arrow back and welcome text
              Row(
                children: [
                  Expanded(
                    child: Text(
                      "Welcome back, ${widget.userName}.",
                      style:const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                "Enter the 4-digit code sent to your phone number:",
                style: TextStyle(fontSize: 12, color: Colors.black87),
              ),
              const SizedBox(height: 10),
              Text(
                widget.phoneNumber,
                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15),
              ),
              const SizedBox(height: 24),
              // PIN boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: List.generate(4, (index) {
                  return Container(
                    width: 50,
                    height: 55,
                    margin: const EdgeInsets.only(right: 12),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: const TextStyle(fontSize: 26),
                      decoration: InputDecoration(
                        counterText: '',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: const BorderSide(color: Colors.grey),
                        ),
                      ),
                      onChanged: (val) {
                        if (val.length == 1 && index < 3) {
                          _focusNodes[index + 1].requestFocus();
                        }
                        if (val.isEmpty && index > 0) {
                          _focusNodes[index - 1].requestFocus();
                        }
                        setState(() {});
                      },
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              // Timer text
              Text(
                "Time Remaining: $timerText",
                style: TextStyle(color: Colors.grey[700], fontSize: 12),
              ),
              const SizedBox(height: 10),
              // Resend button
              TextButton(
                onPressed: () {
                  setState(() {
                    secondsRemaining = 2 * 60;
                    _startTimer();
                  });
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  minimumSize: const Size(30, 30),
                  foregroundColor: Colors.grey[800],
                  backgroundColor: Colors.grey[200],
                ),
                child: const Text("Resend"),
              ),
              const Spacer(),
              // navigation buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black,
                      shape: const CircleBorder(),
                      padding: const EdgeInsets.all(12),
                      elevation: 0,
                    ),
                    child: const Icon(Icons.arrow_back, size: 28),
                  ),
                  ElevatedButton(
                    onPressed: isAllFilled ? () {} : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[300],
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 12),
                      elevation: 0,
                    ),
                    child: Text(
                      "Next →",
                      style: TextStyle(
                        fontSize: 14,
                        color: isAllFilled ? Colors.black : Colors.black,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
