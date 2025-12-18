import 'package:flutter/material.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';
import 'package:movetrap/screen/Profiles/Profile.dart';

void main() {
  runApp(const user_profile());
}

// ignore: camel_case_types
class user_profile extends StatelessWidget {
  const user_profile({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const ProfileDetailsScreen(),
    );
  }
}

class ProfileDetailsScreen extends StatefulWidget {
  const ProfileDetailsScreen({Key? key}) : super(key: key);

  @override
  State<ProfileDetailsScreen> createState() => _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends State<ProfileDetailsScreen> {
  bool notificationsEnabled = false;

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
          'Profile',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
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
            const  Padding(
             padding:  EdgeInsets.symmetric(horizontal: 10),
             child:  Text(
                        'Account',
                       style: TextStyle(color: TColors.textPrimary, fontSize: 14,fontFamily: 'Inter Bold', fontWeight: FontWeight.w700),
                      ),
           ),
           const SizedBox(height: 12),
            // Account Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(
                    label: 'Name',
                    value: 'Liam Carter',
                    onTap: () {},
                  ),
                  const SizedBox(height: 5),
                  _buildInfoCard(
                    label: 'Phone',
                    value: '+1 (555) 123-4567',
                    onTap: () {},
                  ),
                  const SizedBox(height: 5),
                  _buildInfoCard(
                    label: 'Email',
                    value: 'liam.carter@example.com',
                    onTap: () {},
                  ),
                  const SizedBox(height: 5),
                  _buildInfoCard(
                    label: 'Address',
                    value: '123 Main St, Anytown, USA',
                    onTap: () {},
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
          const  Padding(
             padding: const EdgeInsets.symmetric(horizontal: 10),
             child:  Text( 'Preferences',style: TextStyle(color: TColors.textPrimary, fontSize: 14,fontFamily: 'Inter Bold', fontWeight: FontWeight.w700), ),
           ),
           const SizedBox(height: 8),
            // Preferences Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(
                    label: 'Language',
                    value: 'English',
                    onTap: () {},
                  ),
                  const SizedBox(height: 5),
                  _buildInfoCard(
                    label: 'Theme',
                    value: 'System',
                    onTap: () {},
                  ),
                  //const SizedBox(height: 2),
                  _buildToggleCard(
                    label: 'Notifications',
                    value: notificationsEnabled,
                    onChanged: (val) {
                      setState(() {
                        notificationsEnabled = val;
                      });
                    },
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
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
         // color: const Color(0xFFF5F5F5),
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
                    value,
                    style: const TextStyle(color: Color(0xFF47739E), fontSize: 10,fontFamily: 'Inter Regular', fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.only(right: 20),
              child: Icon(
                Icons.arrow_forward,
                size: 20,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleCard({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 16),
      decoration: BoxDecoration(
       // color: const Color(0xFFF5F5F5),
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
          Padding(
            padding: const EdgeInsets.only(left: 40),
            child: Transform.scale(
              scale: 0.70,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.white,
                activeTrackColor: const Color(0xFF34C759),
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: const Color(0xFFE5E5EA),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
