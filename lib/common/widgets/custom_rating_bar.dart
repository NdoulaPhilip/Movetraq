import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';


class CustomRatingBar extends StatelessWidget {
  const CustomRatingBar({
    super.key,
    this.alignment,
    this.ignoreGestures = false,
    this.initialRating = 0,
    this.itemSize = 16,
    this.itemCount = 5,
    this.color,
    this.unselectedColor,
    required this.onRatingUpdate,
  });

  final Alignment? alignment;
  final bool ignoreGestures;
  final double initialRating;
  final double itemSize;
  final int itemCount;
  final Color? color;
  final Color? unselectedColor;
  final Function(double) onRatingUpdate;

  @override
  Widget build(BuildContext context) {
    return alignment != null
        ? Align(
            alignment: alignment ?? Alignment.center,
            child: _buildRatingBar(),
          )
        : _buildRatingBar();
  }

  Widget _buildRatingBar() {
    return RatingBar.builder(
      ignoreGestures: ignoreGestures,
      initialRating: initialRating,
      minRating: 0,
      direction: Axis.horizontal,
      allowHalfRating: false,
      itemSize: itemSize,
      unratedColor: unselectedColor ?? TColors.black,
      itemCount: itemCount,
      updateOnDrag: true,
      itemBuilder: (context, _) {
        return Icon(
          Icons.star,
          color: color ?? TColors.black,
        );
      },
      onRatingUpdate: onRatingUpdate,
    );
  }
}
