import 'package:flutter/material.dart';
import 'package:movetrap/Track.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';
import 'package:movetrap/screen/Express/Express.dart';
import 'package:movetrap/screen/Location/Location.dart';
import 'package:movetrap/screen/Notifications/NotificationPage.dart';
import 'package:movetrap/screen/orders/Order.dart';
//import 'package:movetrap/screen/Notifications/NotificationPage.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent_bottom_nav_bar_v2.dart';

class Home extends StatelessWidget {
  const Home({super.key});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: screenWidth * 0.05,
            vertical: screenHeight * 0.02,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Image.asset(
                          'images/n1.png', scale: 1.5, 
                        // width: screenWidth * 0.12,
                          //height: screenWidth * 0.12,
                        ),
                        SizedBox(width: screenWidth * 0.005),
                        const Expanded(
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Current Location',
                                  style: TextStyle(
                                    color: TColors.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Inter Medium',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: 0),
                              Icon(
                                Icons.keyboard_arrow_down_outlined,
                                color: Colors.black,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.only(left: screenWidth * 0.02),
                    child: GestureDetector(
                      onTap: () {
                        pushScreen(
                          context,
                          screen: const NotificationPage(),
                          withNavBar: false,
                        );
                      },
                      child: const Icon(
                        Icons.notifications_outlined,
                        color: Colors.black,
                        size: 26,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: screenHeight * 0.025),
              // Search Bar
              Container(
                height: screenHeight * 0.055,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EDF5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TextField(
                  readOnly: true,
                  onTap: () {
                    pushScreen(context,
                        screen: const Location(), withNavBar: false);
                  },
                  style: const TextStyle(
                      fontSize: 14, fontFamily: 'Inter Regular'),
                  decoration: const InputDecoration(
                    hintText: "Where to?",
                    hintStyle: TextStyle(
                        fontSize: 14,
                        color: Color(0xFFA2A2A7),
                        fontFamily: 'Inter Regular',
                        fontWeight: FontWeight.w400),
                    prefixIcon:
                        Icon(Icons.search, size: 20, color: Color(0xFFA2A2A7)),
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ),
              SizedBox(height: screenHeight * 0.02),
              // Quick Action
              const Text(
                "Quick Action",
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: TColors.textPrimary,
                    fontSize: 18,
                    fontFamily: 'Inter Medium'),
              ),
              SizedBox(height: screenHeight * 0.015),
              Wrap(
                spacing: screenWidth * 0.04,
                runSpacing: 10,
                alignment: WrapAlignment.start,
                children: [
                  GestureDetector(
                      onTap: () {
                        pushScreen(context, screen: const Express(), withNavBar: false);
                      },
                      child: quickAction(
                          "images/Deliveryman.png", "New Order", screenWidth)),
                  GestureDetector(
                    onTap: () {
                      pushScreen(context, screen: const Track(), withNavBar: false);
                    },
                    child: quickAction("images/Track.png", "Track", screenWidth)),
                  GestureDetector(
                    onTap: () {
                       pushScreen(context, screen: const Order(), withNavBar: false);
                    },
                    child: quickAction("images/Deliver.png", "Send", screenWidth)),
                  GestureDetector(
                    onTap: () {
                       pushScreen(context, screen: const Order(), withNavBar: false);
                    },
                    child: quickAction("images/Motor.png", "Receive", screenWidth)),
                ],
              ),
              SizedBox(height: screenHeight * 0.03),
              // Suggestions Section
              const Text(
                "Suggestions",
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 18,
                    color: TColors.textPrimary,
                    fontFamily: 'Inter Medium'),
              ),
              SizedBox(height: screenHeight * 0.015),
              Wrap(
                spacing: screenWidth * 0.05,
                runSpacing: screenHeight * 0.02,
                children: [
                  suggestionCard("Send Items", "images/im3.png", screenWidth),
                  suggestionCard(
                      "Receive Items", "images/im2.png", screenWidth),
                  suggestionCard(
                      "Packages Pickup", "images/im1.png", screenWidth),
                ],
              ),
              SizedBox(height: screenHeight * 0.03),
              // More ways to deliver
              const Text(
                "More ways to deliver",
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 18,
                    color: TColors.textPrimary,
                    fontFamily: 'Inter Medium'),
              ),
              SizedBox(height: screenHeight * 0.02),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAFC),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Save yourself trips to run errands',
                        style: TextStyle(
                          color: TColors.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Inter Medium',
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.02),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                deliveryOption(
                                    Icons.directions_car, "Deliver Packages"),
                                deliveryOption(
                                    Icons.schedule, "Customer Orders"),
                                deliveryOption(
                                    Icons.store, "Marketplace Errands"),
                                deliveryOption(Icons.replay, "Forgotten Items"),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                deliveryOption(
                                    Icons.local_laundry_service, "Laundry"),
                                deliveryOption(
                                    Icons.card_giftcard, "Gifts Delivery"),
                                deliveryOption(
                                    Icons.shopping_basket, "Shopping"),
                                deliveryOption(
                                    Icons.more_horiz, "Many more ways"),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ]),
              ),
              SizedBox(height: screenHeight * 0.03),
              // Explore section
              const Text(
                "Explore",
                style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: 18,
                    color: TColors.textPrimary,
                    fontFamily: 'Inter Medium'),
              ),
              SizedBox(height: screenHeight * 0.02),
              SizedBox(
                height: screenHeight * 0.22,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: 6,
                  separatorBuilder: (context, _) =>
                      SizedBox(width: screenWidth * 0.04),
                  itemBuilder: (context, idx) {
                    final images = [
                      "images/im2.png",
                      "images/im2.png",
                      "images/im1.png",
                      "images/im2.png",
                      "images/im3.png",
                      "images/im1.png"
                    ];
                    return exploreCard(
                        images[idx % images.length], screenWidth);
                  },
                ),
              ),
              SizedBox(height: screenHeight * 0.05),
            ],
          ),
        ),
      ),
    );
  }

  // Quick Action Widget
  static Widget quickAction(String image, String label, double screenWidth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          height: screenWidth * 0.19,
          width: screenWidth * 0.19,
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFC),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(child: Image.asset(image, height: 40, width: 40)),
        ),
        const SizedBox(height: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF121417),
                fontFamily: 'Inter Regular')),
      ],
    );
  }

  // Suggestion Card
  static Widget suggestionCard(
      String title, String imagePath, double screenWidth) {
    return SizedBox(
      width: screenWidth * 0.42,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            height: screenWidth * 0.25,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              image: DecorationImage(
                image: AssetImage(imagePath),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: Color(0xFF121417),
              fontFamily: 'Inter Regular',
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Delivery Option
  static Widget deliveryOption(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.black, size: 20),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w400,
                color: Color(0xFF121417),
                fontFamily: 'Inter Medium',
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Explore Card
  static Widget exploreCard(String imagePath, double screenWidth) {
    return Container(
      width: screenWidth * 0.65,
      height: screenWidth * 0.35,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        image: DecorationImage(
          image: AssetImage(imagePath),
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
