import 'package:flutter/material.dart';

class AppText extends StatelessWidget {
    const AppText(this.text, {super.key, this.fontSize, this.fontWeight, this.color, this.textAlign, this.maxLines, this.overflow, this.letterSpacing, this.height});
  final String text;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;
  final double? letterSpacing;
  final double? height;



  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: textAlign ?? TextAlign.start,
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: fontSize ?? 14,
        fontWeight: fontWeight ?? FontWeight.normal,
        color: color ?? Colors.black,
        letterSpacing: letterSpacing,
        height: height,
      ),
    );
  }
}
