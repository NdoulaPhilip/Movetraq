import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:movetrap/Shipingdetails.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';

class Activity extends StatefulWidget {
  const Activity({super.key});

  @override
  State<Activity> createState() => _ActivityState();
}

class _ActivityState extends State<Activity> {
  String? selectedFilter = "Last 7 Days";

  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: TColors.textWhite,
      appBar: AppBar(
         automaticallyImplyLeading: false,
        backgroundColor: TColors.textWhite,
        //elevation: 0,
        centerTitle: true,
        title: const Text(
          "Activity",
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: TColors.textPrimary,
            fontSize: 16,
            fontFamily: 'Inter Medium',
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: screenSize.width * 0.04,
          vertical: screenSize.height * 0.02,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Filter Dropdown
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenSize.width * 0.02,
                  vertical: screenSize.height * 0.000,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                 color:const Color(0xFFE8EDF5),
                ),
                child: DropdownButton<String>(
                  value: selectedFilter,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: Colors.black, size: 20),
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
            SizedBox(height: screenSize.height * 0.020),
            // Top Summary Boxes
            Row(
              children: [
                Expanded(
                  child: _buildSummaryBox(
                    value: "125",
                    color: const Color(0xFF0D141C),
                    title: "Active Orders",
                  ),
                ),
                SizedBox(width: screenSize.width * 0.03),
                Expanded(
                  child: _buildSummaryBox(
                    value: "30",
                    color: Colors.black,
                    title: "Pending Orders",
                  ),
                ),
              ],
            ),
            SizedBox(height: screenSize.height * 0.012),
            // Completed Orders (Full Width)
            _buildSummaryBox(
              value: "20",
              color: const Color(0xFF0D141C),
              title: "Completed Orders",
            ),
            SizedBox(height: screenSize.height * 0.032),
            // Shipment Delivery
            const Text(
              "Shipment Delivery",
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: TColors.textPrimary,
                  fontFamily: 'Inter Bold'),
            ),
            SizedBox(height: screenSize.height * 0.005),
            const Text(
              "Shipment Volume",
              style: TextStyle(
                  color: Color(0xFF0D141C),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter Medium'),
            ),
            SizedBox(height: screenSize.height * 0.005),
            const Text(
              "+15%",
              style: TextStyle(
                  color:  Color(0xFF0D141C),
                  fontWeight: FontWeight.w700,fontSize: 16,
                  fontFamily: 'Inter Bold'),
            ),
            SizedBox(height: screenSize.height * 0.005),
            const Row(
              children: [
                Text(
                  "This Month",
                  style: TextStyle(
                      color: Color(0xFF4A739C),
                      fontWeight: FontWeight.w400, fontSize: 12,
                      fontFamily: 'Inter Regular'),
                ),
                SizedBox(width: 4),
                Text(
                  "+15%",
                  style: TextStyle(
                      color: Color(0xFF088738),
                      fontWeight: FontWeight.w500,fontSize: 12,
                      fontFamily: 'Inter Medium'),
                ),
              ],
            ),
            SizedBox(height: screenSize.height * 0.017),
            SizedBox(
              height: screenSize.height * 0.20,
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          interval: 1.0, 
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            switch (value.toInt()) {
                              case 0:
                                return const Text('Jan',
                                    style: TextStyle(
                                        fontSize: 12, fontFamily: 'Inter ',fontWeight: FontWeight.w700,color: Color(0xFF4A739C)));
                              case 1:
                                return const Text('Feb',
                                    style: TextStyle(
                                        fontSize: 12, fontFamily: 'Inter ',fontWeight: FontWeight.w700,color: Color(0xFF4A739C)));
                              case 2:
                                return const Text('Mar',
                                    style: TextStyle(
                                        fontSize: 12, fontFamily: 'Inter ',fontWeight: FontWeight.w700,color: Color(0xFF4A739C)));
                              case 3:
                                return const Text('Apr',
                                    style: TextStyle(
                                        fontSize: 12, fontFamily: 'Inter ',fontWeight: FontWeight.w700,color: Color(0xFF4A739C)));
                              case 4:
                                return const Text('May',
                                    style: TextStyle(
                                        fontSize: 12, fontFamily: 'Inter ',fontWeight: FontWeight.w700,color: Color(0xFF4A739C)));
                              case 5:
                                return const Text('Jun',
                                    style: TextStyle(
                                        fontSize: 12,  fontFamily: 'Inter', fontWeight: FontWeight.w700, color: Color(0xFF4A739C)));
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        isCurved: true,
                        color:const Color(0xFF4A739C),
                        barWidth: 2,
                        belowBarData: BarAreaData(show: false),
                        dotData: const FlDotData(show: false),
                        spots: const [
                          FlSpot(0, 1.5),
                          FlSpot(1, 1.8),
                          FlSpot(2, 1.2),
                          FlSpot(3, 2.0),
                          FlSpot(4, 1.6),
                          FlSpot(5, 2.2),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: screenSize.height * 0.05),
            // Recent Activity Section
            const Text(
              "Recent Activity",
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: Color(0xFF0D141C),
                  fontFamily: 'Inter Bold'),
            ),
            SizedBox(height: screenSize.height * 0.016),
            GestureDetector(
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(
                    builder: (context) {
                      return const Shipingdetails();
                    },
                  ));
                },
                child:
                    _buildRecentItem("Shipment #12345", "Ongoing", "2h ago")),
            _buildRecentItem("Shipment #67890", "Canceled Order", "4h ago"),
            _buildRecentItem("Shipment #11223", "Order Completed", "6h ago"),
          ],
        ),
      ),
    );
  }

  // Summary Boxes (responsive)
  static Widget _buildSummaryBox({
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 20),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFC),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color:  Color(0xFF0D141C),
              fontWeight: FontWeight.w500,
              fontSize: 12,
              fontFamily: 'Inter Medium',
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w500,
              fontSize: 14,
              fontFamily: 'Inter Medium',
            ),
          ),
        ],
      ),
    );
  }

  // Recent Item (responsive)
  static Widget _buildRecentItem(String title, String status, String date) {
    return Container(
      color:const Color(0xFFF7FAFC),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  height: 30,
                  width: 30,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EDF5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.local_shipping_outlined,
                      color: Colors.black, size: 25),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.w400,
                            fontSize: 14, color: Color(0xFF0D141C),
                            fontFamily: 'Inter Medium')),
                    Text(status,
                        style: const TextStyle(
                            color: Color(0xFF4A739C),
                            fontSize: 12, 
                            fontFamily: 'Inter Regular', fontWeight: FontWeight.w400)),
                  ],
                ),
              ],
            ),
            Text(date,
                style: const TextStyle(
                    color: Color(0xFF4A739C),
                    fontWeight: FontWeight.w400,
                    fontSize: 12,
                    fontFamily: 'Inter Regular')),
          ],
        ),
      ),
    );
  }
}
