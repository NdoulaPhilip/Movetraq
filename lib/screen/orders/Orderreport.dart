import 'package:flutter/material.dart';
import 'package:movetrap/Track.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';

void main() {
  runApp(const Orderreport());
}

class Orderreport extends StatelessWidget {
  const Orderreport({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Track Order',
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.white,
      ),
      home: const TrackOrderScreen(),
    );
  }
}

class TrackOrderScreen extends StatelessWidget {
  const TrackOrderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (context) {
              return Track();
            },
          )),
        ),
        title: const Text(
          'Orders',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'Track Order',
              style: TextStyle(color: TColors.textPrimary, fontSize: 14,fontFamily: 'Inter Bold', fontWeight: FontWeight.w700),
              ),
            ),

            // Map Section
            ClipRRect(
              borderRadius: BorderRadius.circular(45),
              child: Image.asset(
                'images/maps.png',
                fit: BoxFit.cover,
                width: 500,
                height: 200,
              ),
            ),

            const SizedBox(height: 24),

            // Shipment Details
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Shipment #12345',
               style: TextStyle(color: TColors.textPrimary, fontSize: 14,fontFamily: 'Inter Bold', fontWeight: FontWeight.w700),
              ),
            ),

            const SizedBox(height: 20),

            // Timeline
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  _buildTimelineItem(
                    icon: Icons.circle_outlined,
                    title: 'Shipment Created',
                    time: 'June 15, 2024, 10:00 AM',
                    isLast: false,
                  ),
                  _buildTimelineItem(
                    icon: Icons.local_shipping_outlined,
                    title: 'In Transit',
                    time: 'June 16, 2024, 2:00 PM',
                    isLast: false,
                  ),
                  _buildTimelineItem(
                    icon: Icons.location_on_outlined,
                    title: 'Arrived at Destination',
                    time: 'June 17, 2024, 9:00 AM',
                    isLast: false,
                  ),
                  _buildTimelineItem(
                    icon: Icons.inventory_2_outlined,
                    title: 'Delivered',
                    time: 'June 17, 2024, 12:00 PM',
                    isLast: true,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Shipment Status
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Text(
                'Shipment Status',
                style: TextStyle(color: TColors.textPrimary, fontSize: 14,fontFamily: 'Inter Bold', fontWeight: FontWeight.w700),
              ),
            ),

            const SizedBox(height: 20),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoColumn(
                          label: 'Status',
                          value: 'Delivered',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoColumn(
                          label: 'Destination',
                          value: 'Lagos, NG',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoColumn(
                          label: 'Deliverer',
                          value: 'John Doe',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoColumn(
                          label: 'Delivery duration',
                          value: '30 mins',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _buildInfoColumn(
                          label: 'Order Amount',
                          value: '2000 Naira',
                        ),
                      ),
                      Expanded(
                        child: _buildInfoColumn(
                          label: 'Satisfactory',
                          value: '5 Stars',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  static Widget _buildTimelineItem({
    required IconData icon,
    required String title,
    required String time,
    required bool isLast,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Icon(icon, size: 16, color: Colors.black),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 50,
                color: Colors.grey[300],
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                 style: const TextStyle(color: TColors.textPrimary, fontSize: 12,fontFamily: 'Inter Medium', fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 2),
              Text(
                time,
                style: const TextStyle(color: Color(0xFF47739E), fontSize: 10,fontFamily: 'Inter Regular', fontWeight: FontWeight.w400),
              ),
              if (!isLast) const SizedBox(height: 16),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildInfoColumn({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF47739E), fontSize: 14,fontFamily: 'Inter Regular', fontWeight: FontWeight.w400),
        ),
        const SizedBox(height: 4),
        Text(
          value,
           style: const TextStyle(color: TColors.textPrimary, fontSize: 12,fontFamily: 'Inter Medium', fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
