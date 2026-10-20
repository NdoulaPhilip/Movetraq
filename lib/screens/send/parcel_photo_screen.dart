import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../providers/send_flow_provider.dart';
import '../../widgets/app_page.dart';
import '../../widgets/design_ui.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';

class ParcelPhotoScreen extends StatefulWidget {
  const ParcelPhotoScreen({super.key});
  @override
  State<ParcelPhotoScreen> createState() => _ParcelPhotoScreenState();
}

class _ParcelPhotoScreenState extends State<ParcelPhotoScreen> {
  Uint8List? _photo;
  bool _busy = false;
  Future<void> _pick(ImageSource source) async {
    setState(() => _busy = true);
    try {
      final image = await ImagePicker()
          .pickImage(source: source, imageQuality: 80, maxWidth: 1600);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      if (bytes.length > 1500000) {
        throw StateError('The photo must be smaller than 1.5 MB.');
      }
      if (mounted) setState(() => _photo = bytes);
    } catch (error) {
      if (mounted) showActionError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
          title: 'Parcel photo',
          subtitle: 'Add a photo so your courier knows what to collect.',
          children: [
            if (_photo == null)
              const DesignCard(
                  child: Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Column(children: [
                  Icon(Icons.add_photo_alternate_outlined,
                      size: 44, color: AppColors.muted),
                  SizedBox(height: 16),
                  Text('Your parcel photo will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted)),
                ]),
              ))
            else
              DesignCard(
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_photo!,
                          height: 280, fit: BoxFit.contain))),
            const SizedBox(height: 18),
            RouteTile(
                title: 'Choose from gallery',
                icon: Icons.photo_library_outlined,
                onTap: _busy ? null : () => _pick(ImageSource.gallery)),
            RouteTile(
                title: 'Take a photo',
                icon: Icons.camera_alt_outlined,
                onTap: _busy ? null : () => _pick(ImageSource.camera)),
            const SizedBox(height: 20),
            PrimaryButton(
                label: 'Use this photo',
                loading: _busy,
                onPressed: _photo == null
                    ? null
                    : () {
                        final flow = context.read<SendFlowProvider>();
                        if (flow.parcelPhotos.length >= 4) {
                          showActionError(
                              context,
                              StateError(
                                  'A parcel can have at most four photos.'));
                          return;
                        }
                        flow.addParcelPhoto(_photo!);
                        Navigator.pop(context);
                      }),
          ]);
}
