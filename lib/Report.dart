import 'package:flutter/material.dart';
import 'package:movetrap/History.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';
import 'package:movetrap/screen/Profiles/deliver.dart';
import 'package:movetrap/screen/orders/Order.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

import 'screen/payment/Pendingpayment.dart';

void main() => runApp(const Report());

class Report extends StatelessWidget {
  const Report({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delivery Report Dashboard',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
      ),
      home: const DashboardScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String? selectedFilter = "Last 7 Days";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.textWhite,
      appBar: AppBar(
        backgroundColor: TColors.textWhite,
        elevation: 0,
        title: const Center(
          child: Text(
            'Report',
            style: TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              fontFamily: 'Inter',
            ),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) {
                return const Order();
              },
            ));
          },
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 700;
          return SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: isWide ? 48 : 18, vertical: 10),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dropdown Row
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 130,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(6),
                           color:Colors.grey[100],
                        ),
                        child: DropdownButton<String>(
                          value: selectedFilter,
                          underline: const SizedBox(),
                          icon: const Icon(Icons.keyboard_arrow_down,
                              color: Colors.black, size: 20),
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Inter',
                            fontSize: 12,
                          ),
                          onChanged: (String? newValue) {
                            setState(() {
                              selectedFilter = newValue;
                            });
                          },
                          items: <String>[
                            'Last 7 Days',
                            'Last 30 Days',
                            'Last 90 Days',
                            'All Time'
                          ].map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Pending Payment Card
                    Card(
                      color: const Color(0xFFF7FAFC),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      child: Padding(
                        padding: EdgeInsets.all(isWide ? 24 : 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Pending Payment',
                                      style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                          fontFamily: 'Inter')),
                                  const SizedBox(height: 4),
                                  Text('25',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: isWide ? 22 : 16,
                                          color: Colors.indigo[800],
                                          fontFamily: 'Inter')),
                                  const SizedBox(height: 10),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      padding: EdgeInsets.symmetric(
                                          horizontal: isWide ? 26 : 16, vertical: 10),
                                    ),
                                    onPressed: () {
                                      Navigator.push(context, MaterialPageRoute(
                                        builder: (context) {
                                          return const Pendingpayment();
                                        },
                                      ));
                                    },
                                    child: Text('Pay',
                                        style: TextStyle(
                                            fontSize: isWide ? 14 : 12,
                                            color: Colors.white,
                                            fontFamily: 'Inter')),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Deliveries stats row
                    GestureDetector(
                      onTap: () {
                        pushScreen(context, screen: const History(),withNavBar: false);
                      },
                      child: Row(
                        children: [
                          Expanded(
                            child: Card(
                              color: const Color(0xFFF7FAFC),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                              child: Padding(
                                padding: EdgeInsets.all(isWide ? 16 : 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('All Deliveries',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontSize: isWide ? 15 : 12,
                                            fontFamily: 'Inter')),
                                    const SizedBox(height: 4),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text('25',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: isWide ? 20 : 16,
                                                fontFamily: 'Inter')),
                                        const SizedBox(width: 8),
                                        Text('+10%',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.w600,
                                              fontSize: isWide ? 12 : 10,
                                              fontFamily: 'Inter',
                                            )),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Card(
                              color: const Color(0xFFF7FAFC),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              elevation: 0,
                              child: Padding(
                                padding: EdgeInsets.all(isWide ? 15 : 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Active Deliveries',
                                        style: TextStyle(
                                            color: Colors.black,
                                            fontSize: isWide ? 15 : 12,
                                            fontFamily: 'Inter')),
                                    const SizedBox(height: 4),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Text('20',
                                            style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: isWide ? 20 : 16,
                                                fontFamily: 'Inter')),
                                        const SizedBox(height: 8),
                                        Text('+8%',
                                            style: TextStyle(
                                              color: Colors.green,
                                              fontWeight: FontWeight.w600,
                                              fontSize: isWide ? 12 : 10,
                                              fontFamily: 'Inter',
                                            )),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Total amount spent
                    Card(
                      color: const Color(0xFFF7FAFC),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      elevation: 0,
                      child: Padding(
                        padding: EdgeInsets.all(isWide ? 24 : 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Total Amount Spent',
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: isWide ? 20 : 13,
                                  fontFamily: 'Inter'),
                            ),
                            const SizedBox(height: 6),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '\$5,000',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: isWide ? 20 : 10,
                                      color: Colors.black,
                                      fontFamily: 'Inter'),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '-2%',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                    fontSize: isWide ? 15 : 12,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),
                    Text('Top Performers',
                        style: TextStyle(
                            fontSize: isWide ? 17 : 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            fontFamily: 'Inter')),
                    const SizedBox(height: 10),

                    Container(
                      color: const Color(0xFFF7FAFC),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Navigator.push(context, MaterialPageRoute(
                                builder: (context) {
                                  return const deliver();
                                },
                              ));
                            },
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                radius: isWide ? 24 : 20,
                                backgroundImage: const AssetImage('images/ord2.png'),
                              ),
                              title: Text('Ethan Carter',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: isWide ? 15 : 12,
                                      fontFamily: 'Inter')),
                              subtitle: Text('25 Deliveries',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w400,
                                      fontSize: isWide ? 13 : 10,
                                      color: Colors.blueAccent,
                                      fontFamily: 'Inter')),
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: isWide ? 24 : 20,
                              backgroundImage: const AssetImage('images/ord1.png'),
                            ),
                            title: Text('Olivia Bennett',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isWide ? 15 : 12,
                                    fontFamily: 'Inter')),
                            subtitle: Text('12 Deliveries',
                                style: TextStyle(
                                    fontWeight: FontWeight.w400,
                                    fontSize: isWide ? 13 : 10,
                                    color: Colors.blueAccent,
                                    fontFamily: 'Inter')),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),

                    Text('Frequent Routes',
                        style: TextStyle(
                            fontSize: isWide ? 15 : 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                            fontFamily: 'Inter')),
                    const SizedBox(height: 10),
                    Container(
                      color: const Color(0xFFF7FAFC),
                      child: Column(
                        children: [
                          ListTile(
                            leading: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 5),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    color: Colors.grey[200]),
                                child: const Icon(Icons.location_on_outlined)),
                            title: Text('Route A',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isWide ? 15 : 12,
                                    fontFamily: 'Inter')),
                            subtitle: Text('160 Shipments',
                                style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: isWide ? 12 : 10,
                                    fontFamily: 'Inter')),
                          ),
                          const SizedBox(height: 5),
                          ListTile(
                            leading: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 5),
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(5),
                                    color: Colors.grey[200]),
                                child: const Icon(Icons.location_on_outlined)),
                            title: Text('Route B',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isWide ? 15 : 12,
                                    fontFamily: 'Inter')),
                            subtitle: Text('80 Shipments',
                                style: TextStyle(
                                    color: Colors.blueAccent,
                                    fontSize: isWide ? 12 : 10,
                                    fontFamily: 'Inter')),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
