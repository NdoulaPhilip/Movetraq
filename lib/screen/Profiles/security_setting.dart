import 'package:flutter/material.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';
import 'package:movetrap/screen/Profiles/Profile.dart';

void main() {
  runApp(const security_setting());
}

class security_setting extends StatelessWidget {
  const security_setting({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const SecurityScreen(),
    );
  }
}

class SecurityScreen extends StatelessWidget {
  const SecurityScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black, size: 20),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) {
                return const Profile();
              },
            ));
          },
        ),
        title: const Text(
          'Security',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            // Password Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Password',
                     style: TextStyle(color: TColors.textPrimary, fontSize: 14,fontFamily: 'Inter Bold', fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _buildInfoCard(
                    label: 'Change password',
                    subtitle: 'Last changed 3 months ago',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            // Two-Factor Authentication Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Two-Factor Authentication',
                   style: TextStyle(color: TColors.textPrimary, fontSize: 14,fontFamily: 'Inter Bold', fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  _buildInfoCard(
                    label: '2FA',
                    subtitle: 'Currently enabled',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            // Security Section
             const  Padding(
             padding: const EdgeInsets.symmetric(horizontal: 10),
             child:  Text( 'Preferences', style: TextStyle(color: TColors.textPrimary, fontSize: 14,fontFamily: 'Inter Bold', fontWeight: FontWeight.w700), ),
           ),
           const SizedBox(height: 10),
            Container(
               // padding:const EdgeInsets.symmetric(horizontal: 13.5,vertical: 13.5),
              // color:const Color(0xFFF7FAFC),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  _buildSimpleCard(
                    label: 'Recent activity',
                    onTap: () {},
                  ),
                  const SizedBox(height: 5),
                  _buildSimpleCard(
                    label: 'Linked devices',
                    onTap: () {},
                  ),
                  const SizedBox(height: 5),
                  _buildSimpleCard(
                    label: 'Privacy settings',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
         // color:const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                     style: const TextStyle(color: TColors.textPrimary, fontSize: 12,fontFamily: 'Inter Medium', fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Color(0xFF47739E), fontSize: 10,fontFamily: 'Inter Regular', fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.arrow_forward,
              size: 20,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleCard({
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          //color: const Color(0xFFF7FAFC),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: TColors.textPrimary, fontSize: 12,fontFamily: 'Inter Medium', fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(
              Icons.arrow_forward,
              size: 20,
              color: Colors.black,
            ),
          ],
        ),
      ),
    );
  }
}