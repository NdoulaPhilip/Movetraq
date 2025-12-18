import 'package:flutter/material.dart';
import 'package:movetrap/History.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';
import 'package:movetrap/screen/navbar_screen/Hom.dart';
import 'package:movetrap/screen/orders/Orderreport.dart';

class Track extends StatelessWidget {
  const Track({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
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
        title: const Text(
          'Track Orders',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const History(),
                ),
              );
            },
            child: const Text(
              'History',
             style: TextStyle(color: TColors.textPrimary, fontSize: 12,fontFamily: 'Inter Bold', fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ongoing Orders',
             style: TextStyle(color: TColors.textPrimary, fontSize: 14,fontFamily: 'Inter Bold', fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                    //padding:const EdgeInsets.symmetric(horizontal: 13.5,vertical: 13.5),
              // color:const Color(0xFFF7FAFC),
                child: ListView.builder(
                  itemCount: 3,
                  itemBuilder: (context, index) {
                    return _buildOrderCard(context); // Pass context here
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(BuildContext context) { // Add context parameter
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
       // color: const Color(0xFFF5F6F8),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EDF5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.access_time,
              size: 20,
              color: Color(0xFF0D141C),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Shipment #123456',
                   style: TextStyle(color: TColors.textPrimary, fontSize: 14,fontFamily: 'Inter Medium', fontWeight: FontWeight.w500 ),
                ),
                SizedBox(height: 4),
                Text(
                  'Ongoing',
                  style: TextStyle(color: Color(0xFF47739E), fontSize: 12,fontFamily: 'Inter Regular', fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
         const SizedBox(width: 10,),
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const Orderreport(), // Changed to Orderreport
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007AFF),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 1,
                vertical: 0,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'Track',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
