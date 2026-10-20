import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../services/feature_gateway.dart';
import '../../services/local_data_service.dart';
import '../../widgets/app_page.dart';
import '../../widgets/primary_button.dart';
import '../../core/config/environment.dart';
import '../../core/networking/uploads.dart';

class PrivateUploadScreen extends StatefulWidget {
  const PrivateUploadScreen(
      {super.key,
      required this.entityId,
      this.verification = false,
      this.documentType = 'identity'});
  final String entityId;
  final bool verification;
  final String documentType;
  @override
  State<PrivateUploadScreen> createState() => _PrivateUploadScreenState();
}

class _PrivateUploadScreenState extends State<PrivateUploadScreen> {
  Uint8List? _bytes;
  String _mime = 'image/jpeg';
  String _type = 'identity';
  bool _busy = false;
  String? _confirmedId;
  @override
  void initState() {
    super.initState();
    _type = widget.documentType;
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final image = await ImagePicker()
          .pickImage(source: source, imageQuality: 80, maxWidth: 1600);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final name = image.name.toLowerCase();
      final mime = name.endsWith('.png')
          ? 'image/png'
          : name.endsWith('.webp')
              ? 'image/webp'
              : name.endsWith('.jpg') || name.endsWith('.jpeg')
                  ? 'image/jpeg'
                  : null;
      final maximum = widget.verification ? 10485760 : 1572864;
      if (mime == null ||
          (widget.verification && mime == 'image/webp') ||
          bytes.isEmpty ||
          bytes.length > maximum) {
        throw StateError(widget.verification
            ? 'Choose JPG or PNG, at most 10 MB.'
            : 'Choose JPG, PNG or WebP, at most 1.5 MB.');
      }
      if (mounted) {
        setState(() {
          _bytes = bytes;
          _mime = mime;
          _confirmedId = null;
        });
      }
    } catch (error) {
      if (mounted) showActionError(context, error);
    }
  }

  Future<void> _upload() async {
    if (_busy || _bytes == null) return;
    if (widget.entityId.isEmpty) {
      showActionError(
          context, 'Open this page from an order or submitted application.');
      return;
    }
    setState(() => _busy = true);
    UploadService? service;
    try {
      final gateway = FeatureGateway(context.read<LocalDataService>());
      if (!FeatureGateway.enabled && !widget.verification) {
        throw const FeatureUnavailable('Private uploads');
      }
      final approval = widget.verification
          ? await context.read<LocalDataService>().delivererAccess()
          : null;
      service = UploadService(
          storageOrigin: widget.verification
              ? Uri.parse(approval!['storageOrigin'] as String)
              : Environment.values.storageOrigin,
          request: (method, path, body) =>
              gateway.request('Private uploads', method, path, body: body));
      final id = await service.uploadBytes(_bytes!,
          mime: _mime,
          entityId: widget.entityId,
          purpose: widget.verification
              ? UploadPurpose.verification
              : UploadPurpose.evidence,
          documentType: _type);
      if (mounted) setState(() => _confirmedId = id);
    } catch (error) {
      if (mounted) showActionError(context, error);
    } finally {
      service?.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AppPage(
          title: widget.verification
              ? 'Verification documents'
              : 'Delivery evidence',
          children: [
            InfoBand(
                title: 'Private & protected',
                body: widget.verification
                    ? 'JPG or PNG, at most 10 MB. Required documents depend on transport and verification policy.'
                    : 'JPG, PNG or WebP, at most 1.5 MB. Delivery is confirmed only after server verification.',
                icon: Icons.lock_outline),
            if (widget.verification) ...[
              DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Document type'),
                  items: const [
                    DropdownMenuItem(
                        value: 'identity', child: Text('Identity document')),
                    DropdownMenuItem(
                        value: 'driver_licence',
                        child: Text("Driver's licence")),
                    DropdownMenuItem(
                        value: 'registration',
                        child: Text('Vehicle registration')),
                    DropdownMenuItem(
                        value: 'insurance', child: Text('Insurance'))
                  ],
                  onChanged: _busy
                      ? null
                      : (value) => setState(() {
                            _type = value!;
                            _confirmedId = null;
                          })),
              const SizedBox(height: 18)
            ],
            if (_bytes != null)
              Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.memory(_bytes!,
                          height: 240,
                          width: double.infinity,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stack) =>
                              const InfoBand(
                                  title: 'Image preview unavailable')))),
            Row(children: [
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed: _busy ? null : () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Camera'))),
              const SizedBox(width: 12),
              Expanded(
                  child: OutlinedButton.icon(
                      onPressed:
                          _busy ? null : () => _pick(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Gallery')))
            ]),
            const SizedBox(height: 24),
            if (_confirmedId != null) ...[
              InfoBand(title: 'Upload verified', body: _confirmedId),
              PrimaryButton(
                  label: 'Continue',
                  onPressed: () => Navigator.pop(context, _confirmedId))
            ] else
              PrimaryButton(
                  label: 'Upload securely',
                  loading: _busy,
                  onPressed: _bytes == null ? null : _upload),
          ]);
}
