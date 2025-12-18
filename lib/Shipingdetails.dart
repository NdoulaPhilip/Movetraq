import 'package:flutter/material.dart';
import 'package:movetrap/Activity.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';

void main() {
  runApp(const Shipingdetails());
}

class Shipingdetails extends StatelessWidget {
  const Shipingdetails({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Shipment Details',
      theme: ThemeData(
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: Colors.black),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            fontFamily: 'Inter',
          ),
        ),
      ),
      home: const ShipmentDetailsScreen(),
    );
  }
}

class ShipmentDetailsScreen extends StatelessWidget {
  const ShipmentDetailsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.push(context, MaterialPageRoute(
            builder: (context) {
              return const Activity();
            },
          )),
        ),
        title: const Text('Shipment Details'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Shipment #123456',
              style: TextStyle(color: TColors.textPrimary, fontSize: 14,fontFamily: 'Inter Bold', fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 32),
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
            const SizedBox(height: 40),
            const Text(
              'Shipment Status',
              style: TextStyle(color: TColors.textPrimary, fontSize: 14,fontFamily: 'Inter Bold', fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 32),
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
            const SizedBox(height: 32),
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
    );
  }

  Widget _buildTimelineItem({
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
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
              ),
              child: Icon(icon, size: 20, color: Colors.black),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: Colors.grey[300],
                margin: const EdgeInsets.symmetric(vertical: 4),
              ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: TColors.textPrimary, fontSize: 12,fontFamily: 'Inter Medium', fontWeight: FontWeight.w400),
              ),
              const SizedBox(height: 4),
              Text(
                time,
                 style: const TextStyle(color: Color(0xFF47739E), fontSize: 10,fontFamily: 'Inter Regular', fontWeight: FontWeight.w300),
              ),
              if (!isLast) const SizedBox(height: 24),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoColumn({
    required String label,
    required String value,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: Color(0xFF47739E), fontSize: 12,fontFamily: 'Inter Regular', fontWeight: FontWeight.w300),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(color: TColors.textPrimary, fontSize: 10,fontFamily: 'Inter Medium', fontWeight: FontWeight.w400),
        ),
      ],
    );
  }
}
