import 'package:flutter/material.dart';
import 'package:movetrap/screen/orders/Order.dart';

class deliver extends StatelessWidget {
  const deliver({super.key});

  @override
  Widget build(BuildContext context) {
    const Color primaryText = Colors.black87;
    const Color subText = Colors.blueGrey;
    const Color mainBlue = Color(0xFF007AFF);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
            icon:
                const Icon(Icons.arrow_back_ios, size: 20, color: Colors.black),
            onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (context) {
                    return const Order();
                  },
                ))),
        
        centerTitle: true,
        title: const Text(
          "Driver Profile",
          style: TextStyle(
            fontFamily: "Inter", fontSize: 16,
            fontWeight: FontWeight.w600,
            color: primaryText,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            const CircleAvatar(
              radius: 40,
              backgroundImage: AssetImage("images/ord2.png"),
            ),
            const SizedBox(height: 12),
            const Text(
              "Ethan Carter",
              style: TextStyle(
                fontFamily: "Inter Bold",
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              "Driver ID: 789456",
              style: TextStyle(
                fontFamily: "Inter Medium", fontSize: 12,
                color: subText,
              ),
            ),
            const Text(
              "Status: Available",
              style: TextStyle(
                fontFamily: "Inter Medium", fontSize: 12,
                color: mainBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),

            // Stats Cards
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _StatCard(value: "4.8", label: "Rating"),
                _StatCard(value: "95%", label: "Good\nRatings"),
                _StatCard(value: "250", label: "Orders\nCompleted"),
              ],
            ),

            const SizedBox(height: 30),

            // Rating Breakdown
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Rating Breakdown",
                style: TextStyle(
                  fontFamily: "Inter",
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 18),

            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Text(
                      "4.8",
                      style: TextStyle(
                        fontFamily: "Inter",
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.amber, size: 20),
                        Icon(Icons.star, color: Colors.amber, size: 20),
                        Icon(Icons.star, color: Colors.amber, size: 20),
                        Icon(Icons.star, color: Colors.amber, size: 20),
                        Icon(Icons.star_half, color: Colors.amber, size: 20),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      "120 reviews",
                      style: TextStyle(
                        fontFamily: "Inter",
                        color: subText,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: 32),

                // Breakdown bars
                Expanded(
                  child: Column(
                    children: [
                      _RatingBar(stars: "5", percent: 0.70),
                      _RatingBar(stars: "4", percent: 0.20),
                      _RatingBar(stars: "3", percent: 0.05),
                      _RatingBar(stars: "2", percent: 0.03),
                      _RatingBar(stars: "1", percent: 0.02),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Presence
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.shade300)),
              ),
              child: const Row(
                children: [
                  Expanded(
                    child: Text(
                      "Presence",
                      style: TextStyle(
                        fontFamily: "Inter",
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(Icons.circle, color: Colors.green, size: 14),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;

  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 105,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontFamily: "Inter Medium",
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: "Inter Medium",
              fontSize: 10,
              color: Colors.blueGrey,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBar extends StatelessWidget {
  final String stars;
  final double percent;

  const _RatingBar({required this.stars, required this.percent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(stars),
        const SizedBox(width: 4),
        Expanded(
          child: LinearProgressIndicator(
            color: Colors.blue,
            value: percent,
          ),
        ),
        const SizedBox(width: 8),
        Text("${(percent * 100).toInt()}%"),
      ],
    );
  }
}
