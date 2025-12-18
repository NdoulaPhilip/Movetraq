import 'package:flutter/material.dart';
import 'package:movetrap/Chart.dart';
import 'package:movetrap/Report.dart';
import 'package:movetrap/Track.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';
import 'package:movetrap/screen/Express/Express1.dart';
import 'package:movetrap/screen/Profiles/deliver.dart';
import 'package:movetrap/screen/navbar_screen/Hom.dart';
import 'package:movetrap/screen/orders/Orderdetails.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Delivery Orders',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: TColors.textWhite,
        fontFamily: 'Inter',
      ),
      home: const Order(),
    );
  }
}

class Order extends StatefulWidget {
  const Order({super.key});

  @override
  State<Order> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<Order> {
  int selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.textWhite,
      appBar: AppBar(
        backgroundColor: TColors.textWhite,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) {
                return const Hom();
              },
            ));
          },
        ),
        title: const Text(
          'Orders',
          style: TextStyle(
            color: TColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter Medium',
          ),
        ),
        centerTitle: true,
      ),
      body: selectedTab == 0
          ? P2PDeliveryTab(onExpressDeliveryTap: () {
              setState(() {
                selectedTab = 1;
              });
            })
          : ExpressDeliveryTab(onP2PDeliveryTap: () {
              setState(() {
                selectedTab = 0;
              });
            }),
      bottomNavigationBar: selectedTab == 0
          ? BottomNavigationBar(
            backgroundColor: Colors.white,
            iconSize: 30,
              currentIndex: 0,
              type: BottomNavigationBarType.fixed,
              selectedItemColor: Colors.black,
              unselectedItemColor: Colors.grey,
              selectedLabelStyle:
                  const TextStyle(fontSize: 12, fontFamily: 'Inter Medium'),
              unselectedLabelStyle:
                  const TextStyle(fontSize: 12, fontFamily: 'Inter Medium'),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home),
                  label: 'p2p',
                ),
                BottomNavigationBarItem(
                  icon: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) {
                            return const Report();
                          },
                        ));
                      },
                      child: const Icon(Icons.bar_chart)),
                  label: 'Report',
                ),
                BottomNavigationBarItem(
                  icon: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) {
                            return const Track();
                          },
                        ));
                      },
                      child: const Icon(Icons.local_shipping)),
                  label: 'Track',
                ),
                BottomNavigationBarItem(
                  icon: GestureDetector(
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(
                          builder: (context) {
                            return const Chart();
                          },
                        ));
                      },
                      child: const Icon(Icons.chat_bubble_outline)),
                  label: 'Chat',
                ),
              ],
            )
          : null,
    );
  }
}

class P2PDeliveryTab extends StatefulWidget {
  final VoidCallback onExpressDeliveryTap;

  const P2PDeliveryTab({super.key, required this.onExpressDeliveryTap});

  @override
  State<P2PDeliveryTab> createState() => _P2PDeliveryTabState();
}

class _P2PDeliveryTabState extends State<P2PDeliveryTab> {
  String? selectedFilter = "Send";

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Selection
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
             mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {},
                child: const Text(
                  'P2P Delivery',
                  style: TextStyle(
                    fontSize: 12, color: TColors.textPrimary,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter Bold',
                  ),
                ),
              ),
             // const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(right: 70),
                child: GestureDetector(
                  onTap: widget.onExpressDeliveryTap,
                  child: const Text(
                    'Express Delivery',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontFamily: 'Inter Regular',
                    ),
                  ),
                ),
              ),
              //const Spacer(),
              //const SizedBox( width: 20,),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: const Color(0xFFE8EDF5),
                  ),
                  child: DropdownButton<String>(
                    value: selectedFilter,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.black, size:20),
                    style: const TextStyle(
                      color: Color(0xFF0D141C),
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter Medium',
                      fontSize: 12,
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedFilter = newValue;
                      });
                    },
                    items: <String>[
                      'Send',
                      'Receive',
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Search Fields
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Column(
            children: [
              TextField(
                // readOnly: true,
                style: const TextStyle(fontFamily: 'Inter Regular'),
                decoration: InputDecoration(
                  hintText: 'Current location',
                  hintStyle:
                     const TextStyle(color: Color(0xFFA2A2A7), fontFamily: 'Inter Rgular',fontWeight: FontWeight.w400,fontSize: 12),
                  prefixIcon: const Icon(Icons.search, color: Color(0xFFA2A2A7)),
                  filled: true,
                  fillColor:const Color(0xFFE8EDF5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                       const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                // readOnly: true,
                style: const TextStyle(fontFamily: 'Inter Regular'),
                decoration: InputDecoration(
                  hintText: 'Enter location for delivery',
                  hintStyle:
                     const TextStyle(color: Color(0xFFA2A2A7), fontFamily: 'Inter Regular',fontWeight: FontWeight.w400,fontSize: 14),
                  prefixIcon:const Icon(Icons.search, color:Color(0xFFA2A2A7)),
                  filled: true,
                  fillColor:const Color(0xFFE8EDF5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 25),

        // Driver List
        Expanded(
          child: GestureDetector(
            onTap: () {},
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                DriverCard(
                  name: 'John Doe',
                  distance: '5 mins away',
                  location: 'Ikorodu',
                  destinations: 'Oshodi, Apapa, Lagos State',
                  deliveryCount: '100 Delivery',
                  rating: '99%',
                  avatarColor: Colors.blue[100]!,
                ),
                DriverCard(
                  name: 'Liam Harper',
                  distance: '15 mins away',
                  location: 'Lekki',
                  destinations: 'Oshodi, Apapa, Lagos State',
                  deliveryCount: '50 Delivery',
                  rating: '99%',
                  avatarColor: Colors.orange[100]!,
                ),
                DriverCard(
                  name: 'Ethan Carter',
                  distance: '5 mins away',
                  location: 'Ikorodu',
                  destinations: 'Oshodi, Apapa, Lagos State',
                  deliveryCount: '100 Delivery',
                  rating: '99%',
                  avatarColor: Colors.green[100]!,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DriverCard extends StatelessWidget {
  final String name;
  final String distance;
  final String location;
  final String destinations;
  final String deliveryCount;
  final String rating;
  final Color avatarColor;

  const DriverCard({
    super.key,
    required this.name,
    required this.distance,
    required this.location,
    required this.destinations,
    required this.deliveryCount,
    required this.rating,
    required this.avatarColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        pushScreen(context, screen: const Orderdetails(), withNavBar: false);
      },
      child: Container(
        color: const Color(0xFFF7FAFC),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      pushScreen(context, screen: const deliver(), withNavBar: false);
                    },
                    child: CircleAvatar(
                        radius: 22,
                        backgroundColor: avatarColor,
                        child: Image.asset('images/ord1.png')),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 12, color: Color(0xFF0D141C),
                                fontWeight: FontWeight.w500,
                                fontFamily: 'Inter Medium',
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.check_circle,
                                color: Colors.green, size: 12),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.access_time,
                                size: 10, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              distance,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF4A739C),
                                fontFamily: 'Inter Regular', fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 12),
                      const SizedBox(width: 5),
                      Text(
                        location,
                        style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF4A739C),
                            fontFamily: 'Inter Regular',fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Destinations: $destinations',
                          style: const TextStyle(
                            fontSize: 10,
                            color:TColors.textPrimary,
                            fontFamily: 'Inter Regular',fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$deliveryCount | $rating',
                    style: const TextStyle(
                      fontSize: 10,color: Color(0xFF4A739C),
                      fontWeight: FontWeight.w400,
                      fontFamily: 'Inter Regular',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ExpressDeliveryTab extends StatefulWidget {
  final VoidCallback onP2PDeliveryTap;

  const ExpressDeliveryTab({super.key, required this.onP2PDeliveryTap});

  @override
  State<ExpressDeliveryTab> createState() => _ExpressDeliveryTabState();
}

class _ExpressDeliveryTabState extends State<ExpressDeliveryTab> {
  final TextEditingController _currentLocationController =
      TextEditingController();
  final TextEditingController _deliveryLocationController =
      TextEditingController();
  final TextEditingController _productDescriptionController =
      TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _moreDetailsController = TextEditingController();
  String? selectedFilter = "Send";

  @override
  void dispose() {
    _currentLocationController.dispose();
    _deliveryLocationController.dispose();
    _productDescriptionController.dispose();
    _amountController.dispose();
    _moreDetailsController.dispose();
    super.dispose();
  }

  void _showOrderDetailsBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => OrderDetailsBottomSheet(
        currentLocation: _currentLocationController.text,
        deliveryLocation: _deliveryLocationController.text,
        amount: _amountController.text,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Selection
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: widget.onP2PDeliveryTap,
                child: const Text(
                  'P2P Delivery',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              //const SizedBox(width: 24),
              Padding(
                padding: const EdgeInsets.only(right: 70),
                child: GestureDetector(
                  onTap: () {},
                  child: const Text(
                    'Express Delivery',
                    style: TextStyle(
                      fontSize: 12, color: TColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'Inter Bold',
                    ),
                  ),
                ),
              ),
              //const Spacer(),
             // const SizedBox( width: 20, ),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.grey[100],
                  ),
                  child: DropdownButton<String>(
                    value: selectedFilter,
                    underline: const SizedBox(),
                    icon: const Icon(Icons.keyboard_arrow_down,
                        color: Colors.black, size: 20),
                    style: const TextStyle(
                      color: Color(0xFF0D141C),
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter Medium',
                      fontSize: 12,
                    ),
                    onChanged: (String? newValue) {
                      setState(() {
                        selectedFilter = newValue;
                      });
                    },
                    items: <String>[
                      'Send',
                      'Receive',
                    ].map<DropdownMenuItem<String>>((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Location Fields
                TextField(
                   //readOnly: true,
                
                  controller: _currentLocationController,
                  style: const TextStyle(fontFamily: 'Inter'),
                  decoration: InputDecoration(
                    hintText: 'Current location',
                    hintStyle:
                       const TextStyle(color: Color(0xFFA2A2A7), fontFamily: 'Inter Rgular',fontWeight: FontWeight.w400,fontSize: 14),
                    prefixIcon:const Icon(Icons.search, color: Color(0xFFA2A2A7)),
                    filled: true,
                    fillColor:const Color(0xFFE8EDF5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                       const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  // readOnly: true,
                
                  controller: _deliveryLocationController,
                  style: const TextStyle(fontFamily: 'Inter'),
                  decoration: InputDecoration(
                    hintText: 'Enter location for delivery',
                    hintStyle:
                       const TextStyle(color: Color(0xFFA2A2A7), fontFamily: 'Inter Rgular',fontWeight: FontWeight.w400,fontSize: 14),
                    prefixIcon:const Icon(Icons.search, color: Color(0xFFA2A2A7)),
                    filled: true,
                    fillColor:const Color(0xFFE8EDF5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                      const  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  
                ),

                const SizedBox(height: 24),

                // Product Description
                TextField(
                  controller: _productDescriptionController,
                  style: const TextStyle(fontFamily: 'Inter'),
                  decoration: InputDecoration(
                    hintText: 'Product Description',
                    hintStyle:
                       const TextStyle(color: Color(0xFFA2A2A7), fontFamily: 'Inter Rgular',fontWeight: FontWeight.w400,fontSize: 14),
                    filled: true,
                    fillColor: const Color(0xFFF7FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                      const  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),

                const SizedBox(height: 16),

                // Enter Amount
                TextField(
                  controller: _amountController,
                  keyboardType: TextInputType.number,
                  style: const TextStyle(fontFamily: 'Inter'),
                  decoration: InputDecoration(
                    hintText: 'Enter Amount',
                    hintStyle:
                       const TextStyle(color: Color(0xFFA2A2A7), fontFamily: 'Inter Medium',fontWeight: FontWeight.w500,fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFFF7FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                       const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),

                const SizedBox(height: 16),

                // More Details
                TextField(
                  controller: _moreDetailsController,
                  maxLines: 5,
                  style: const TextStyle(fontFamily: 'Inter'),
                  decoration: InputDecoration(
                    hintText: 'More details',
                    hintStyle:
                      const TextStyle(color: Color(0xFFA2A2A7), fontFamily: 'Inter Medium',fontWeight: FontWeight.w500,fontSize: 12),
                    filled: true,
                    fillColor: const Color(0xFFF7FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                       const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  
                ),

                const SizedBox(height: 16),

                // Image/File Upload Icons
                Row(
                  children: [
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.image_outlined,
                          color: Colors.blue[700], size: 28),
                    ),
                    const SizedBox(width: 16),
                    IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.add_circle_outline,
                          color: Colors.grey[600], size: 28),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Delivery Terms
                const Text(
                  'Delivery Terms',
                  style: TextStyle(
                    fontSize: 12,color: Color(0xFFA2A2A7),
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter Medium',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '1. Order Confirmation\nEnsure the order is verified (payment, address, item details) before dispatch.\nConfirm availability of goods before promising delivery.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF949494),
                    height: 1.5,
                    fontFamily: 'Inter Medium', fontWeight: FontWeight.w500
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '2. Delivery Address & Contact\nRequire a complete and accurate address (with landmarks if necessary).\nCollect a valid phone number of the recipient.',
                 style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF949494),
                    height: 1.5,
                    fontFamily: 'Inter Medium', fontWeight: FontWeight.w500
                  ),
                ),

                const SizedBox(height: 80),
              ],
            ),
          ),
        ),

        // Create Order Button
        Container(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _showOrderDetailsBottomSheet,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Create Order',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class OrderDetailsBottomSheet extends StatelessWidget {
  final String currentLocation;
  final String deliveryLocation;
  final String amount;

  const OrderDetailsBottomSheet({
    super.key,
    required this.currentLocation,
    required this.deliveryLocation,
    required this.amount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Order Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 20),

          // From
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 60,
                child: Text(
                  'From',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  currentLocation.isEmpty
                      ? 'Dopemu Street, Ikorodu, Lagos.'
                      : currentLocation,
                  style: const TextStyle(fontSize: 14, fontFamily: 'Inter'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // To
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 60,
                child: Text(
                  'To',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  deliveryLocation.isEmpty
                      ? 'Lekki Phase 1, Allen Ave, Ikeja.'
                      : deliveryLocation,
                  style: const TextStyle(fontSize: 14, fontFamily: 'Inter'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Amount
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(
                width: 60,
                child: Text(
                  'Amount',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  amount.isEmpty ? '₦3800' : '₦$amount',
                  style: const TextStyle(fontSize: 14, fontFamily: 'Inter'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Checkbox
          Row(
            children: [
              Checkbox(
                value: true,
                onChanged: (value) {},
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Expanded(
                child: Text(
                  "I've read the payment, terms and condition and am sure.",
                  style: TextStyle(fontSize: 13, fontFamily: 'Inter'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Create Order Button
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(
                  builder: (context) {
                    return Done();
                  },
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF007AFF),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Create Order',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }
}
