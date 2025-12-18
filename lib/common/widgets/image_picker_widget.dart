import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:movetrap/core/utils/constraints/colors.dart';

class PickImageWidget extends StatelessWidget {
  const PickImageWidget({super.key, this.pickedImage, required this.function});
  final XFile? pickedImage;
  final Function function;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 74,
      width: 74,
      child: Stack(
        children: [
          pickedImage == null
              ? Container(
                  height: 74,
                  width: 74,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(50),
                    color: Colors.grey[100],
                  ),

                  // child: const Icon(Icons.cloud_upload_rounded, size: 50,),
                )
              : ClipOval(
                  child: Image.file(
                    File(pickedImage!.path),
                    height: 74,
                    width: 74,
                    fit: BoxFit.cover, // Use cover to maintain aspect ratio while filling
                  ),
                ),
          Positioned(
            right: -10,
            bottom: -15,
            child: IconButton(
              onPressed: () {
                function();
              },
              icon: const Icon(
                Icons.cloud_upload_rounded,
                size: 20,
                color: TColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
