
import 'package:flutter/material.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';
import 'package:movetrap/screen/navbar_screen/Hom.dart';
import 'package:movetrap/screen/email_screen/email.dart';
import 'package:movetrap/phone.dart';
import 'package:movetrap/start.dart';

class Login extends StatefulWidget {
  const Login({super.key});

  @override
  State<Login> createState() => _LoginState();
}

class _LoginState extends State<Login> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }


  @override
  void dispose() {
    _controller.dispose();
   
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: TColors.textWhite,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: screenWidth * 0.1),
                Image.asset(
                  'images/logo.png',
                  width: screenWidth * 0.2, // responsive size
                ),
                const SizedBox(height: 20),
                const Text(
                  "Get started with Movetraq",
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: TColors.textPrimary,
                      fontFamily: 'Inter Medium'),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 30),

                // 🔹 Login button
                _customButton(
                  text: "Log in",
                  color: const Color(0xFF1A78E5),
                  textColor: Colors.white,
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => const phone()));
                  },
                ),

                const SizedBox(height: 10),

                // 🔹 Get Started button
                _customButton(
                  text: "Get Started",
                  color: const Color(0xFFF7FAFC),
                  textColor: const Color(0xFF121417),
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => const Start()));
                  },
                ),

                const SizedBox(height: 20),
                _divider(),

                const SizedBox(height: 20),

                // 🔹 Continue with email
                _customIconButton(
                  icon: const Icon(Icons.email_sharp, color: Colors.black),
                  text: "Continue with Email",
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const email()),
                    );
                  },
                ),

                const SizedBox(height: 12),

                // 🔹 Continue with Google
                _customIconButton(
                  icon: Image.asset('images/google.png', width: 22),
                  text: "Continue with Google",
                  onPressed: () {},
                ),

                const SizedBox(height: 12),

                // 🔹 Continue with Apple
                _customIconButton(
                  icon: const Icon(Icons.apple_sharp, color: Colors.black),
                  text: "Continue with Apple",
                  onPressed: () {},
                ),

                const SizedBox(height: 20),
                _divider(),

                const SizedBox(height: 12),

                // 🔹 Continue as guest
                TextButton(
                  onPressed: () {
                    Navigator.push(context,
                        MaterialPageRoute(builder: (context) => const Hom()));
                  },
                  child: const Text(
                    "Continue as guest",
                    style: TextStyle(
                        //decoration: TextDecoration.underline,
                        color: Color.fromARGB(255, 3, 140, 253),
                        fontSize: 14,
                        fontFamily: 'Inter Medium',
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 🔹 Reusable button
  Widget _customButton({
    required String text,
    required Color color,
    required Color textColor,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: color,
          foregroundColor: textColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
              fontFamily: 'Inter Medium'),
        ),
      ),
    );
  }

  // 🔹 Reusable button with icon
  Widget _customIconButton({
    required Widget icon,
    required String text,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          elevation: 0,
          side: BorderSide.none, // remove border
          padding: const EdgeInsets.symmetric(vertical: 12),
          backgroundColor: const Color(0xFFF7FAFC),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        onPressed: onPressed,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: 8),
            Text(
              text,
              style: const TextStyle(
                  color: TColors.textPrimary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                  fontFamily: 'Inter Medium'),
            ),
          ],
        ),
      ),
    );
  }

  // 🔹 Divider with "or"
  Widget _divider() {
    return const Row(
      children: [
        Expanded(
          child: Divider(
            thickness: 1,
            color: TColors.textPrimary,
          ),
        ),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            "or",
            style: TextStyle(color: TColors.textPrimary),
          ),
        ),
        Expanded(child: Divider(thickness: 1, color: TColors.textPrimary)),
      ],
    );
  }
}
