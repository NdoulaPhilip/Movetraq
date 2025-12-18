import 'package:flutter/material.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';
import 'package:movetrap/core/utils/constraints/image_strings.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0),
          child: Column(
            children: [
              const SizedBox(height: 60),
              
              // Logo
              // Container(
              //   width: 80,
              //   height: 80,
              //   decoration: BoxDecoration(
              //     color: const Color(0xFF2C5F7C),
              //     borderRadius: BorderRadius.circular(20),
              //   ),
              //   child: Stack(
              //     alignment: Alignment.center,
              //     children: [
              //       // Book/Box shape
              //       Positioned(
              //         bottom: 15,
              //         child: Container(
              //           width: 45,
              //           height: 35,
              //           decoration: const BoxDecoration(
              //             color: Colors.white,
              //             borderRadius: BorderRadius.only(
              //               topLeft: Radius.circular(3),
              //               topRight: Radius.circular(3),
              //             ),
              //           ),
              //         ),
              //       ),
              //       // Smile face
              //       Positioned(
              //         top: 20,
              //         child: Column(
              //           children: [
              //             Row(
              //               children: [
              //                 Container(
              //                   width: 5,
              //                   height: 5,
              //                   decoration: const BoxDecoration(
              //                     color: Colors.white,
              //                     shape: BoxShape.circle,
              //                   ),
              //                 ),
              //                 const SizedBox(width: 15),
              //                 Container(
              //                   width: 5,
              //                   height: 5,
              //                   decoration: const BoxDecoration(
              //                     color: Colors.white,
              //                     shape: BoxShape.circle,
              //                   ),
              //                 ),
              //               ],
              //             ),
              //             const SizedBox(height: 5),
              //             Container(
              //               width: 25,
              //               height: 12,
              //               decoration: const BoxDecoration(
              //                 border: Border(
              //                   bottom: BorderSide(color: Colors.white, width: 2),
              //                   left: BorderSide(color: Colors.white, width: 2),
              //                   right: BorderSide(color: Colors.white, width: 2),
              //                 ),
              //                 borderRadius: BorderRadius.only(
              //                   bottomLeft: Radius.circular(15),
              //                   bottomRight: Radius.circular(15),
              //                 ),
              //               ),
              //             ),
              //           ],
              //         ),
              //       ),
              //     ],
              //   ),
              // ),
              
               Image.asset( TImages.logo,
                  width: screenWidth * 0.3, // responsive size
                ),
              const SizedBox(height: 24),
              
              // Title
              const Text(
                'Get started with Movetraq',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              
              const SizedBox(height: 40),
              
              // Log In Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: TColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Log In',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Get Started Button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFF5F5F5),
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Get Started',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 30),
              
              // Divider with "or"
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Continue with Email Button
              _SocialButton(
                icon: Icons.email_outlined,
                label: 'Continue with email',
                onPressed: () {},
              ),
              
              const SizedBox(height: 12),
              
              // Continue with Google Button
              _SocialButton(
                iconWidget: Image.network(
                  'https://www.google.com/favicon.ico',
                  width: 20,
                  height: 20,
                ),
                label: 'Continue with Google',
                onPressed: () {},
              ),
              
              const SizedBox(height: 12),
              
              // Continue with Apple Button
              _SocialButton(
                icon: Icons.apple,
                label: 'Continue with Apple',
                onPressed: () {},
              ),
              
              const SizedBox(height: 30),
              
              // Bottom Divider with "or"
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'or',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: Colors.grey[300],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),
              
              // Continue as guest
              TextButton(
                onPressed: () {},
                child: const Text(
                  'Continue as guest',
                  style: TextStyle(
                    color: Color(0xFF1E88E5),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;
  final String label;
  final VoidCallback onPressed;

  const _SocialButton({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: const Color(0xFFF5F5F5),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            iconWidget ??
                Icon(
                  icon,
                  color: Colors.black87,
                  size: 20,
                ),
            const SizedBox(width: 12),
            Text(
              label,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}