import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

typedef UploadRequest = Future<Map<String, dynamic>> Function(
    String method, String path, Map<String, dynamic>? body);

enum UploadPurpose { evidence, verification }

class UploadService {
  UploadService(
      {required this.request, required this.storageOrigin, Dio? transport})
      : _transport = transport ?? Dio();
  final UploadRequest request;
  final Uri storageOrigin;
  final Dio _transport;
  static const evidenceMaximum = 1572864;
  static const verificationMaximum = 10485760;
  static String mimeType(String name, UploadPurpose purpose) {
    final extension = name.toLowerCase().split('.').last;
    final mime = {
      'jpg': 'image/jpeg',
      'jpeg': 'image/jpeg',
      'png': 'image/png',
      'webp': 'image/webp',
      'pdf': 'application/pdf'
    }[extension];
    if (mime == null ||
        (purpose == UploadPurpose.verification && mime == 'image/webp') ||
        (purpose == UploadPurpose.evidence && mime == 'application/pdf')) {
      throw ArgumentError('Choose a supported photo or verification document.');
    }
    return mime;
  }

  static void validateBytes(
      Uint8List bytes, String mime, UploadPurpose purpose) {
    final maximum = purpose == UploadPurpose.evidence
        ? evidenceMaximum
        : verificationMaximum;
    if (bytes.isEmpty || bytes.length > maximum) {
      throw ArgumentError(
          'The selected file exceeds the upload limit or is empty.');
    }
    final valid = switch (mime) {
      'image/jpeg' => bytes.length >= 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255,
      'image/png' => bytes.length >= 8 &&
          bytes.take(8).join(',') == '137,80,78,71,13,10,26,10',
      'image/webp' => bytes.length >= 12 &&
          String.fromCharCodes(bytes.take(4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP',
      'application/pdf' =>
        bytes.length >= 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-',
      _ => false,
    };
    if (!valid) {
      throw ArgumentError('The file contents do not match its format.');
    }
  }

  Future<String> upload(XFile file,
      {required String entityId,
      required UploadPurpose purpose,
      String documentType = 'identity'}) async {
    final maximum = purpose == UploadPurpose.evidence
        ? evidenceMaximum
        : verificationMaximum;
    if (await file.length() > maximum) {
      throw ArgumentError('The selected file exceeds the upload limit.');
    }
    return uploadBytes(await file.readAsBytes(),
        mime: mimeType(file.name, purpose),
        entityId: entityId,
        purpose: purpose,
        documentType: documentType);
  }

  Future<String> uploadBytes(Uint8List bytes,
      {required String mime,
      required String entityId,
      required UploadPurpose purpose,
      String documentType = 'identity'}) async {
    if (!RegExp(
            r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
        .hasMatch(entityId)) {
      throw ArgumentError('Open uploads from a valid order or application.');
    }
    if (purpose == UploadPurpose.verification &&
        !const ['identity', 'driver_licence', 'registration', 'insurance']
            .contains(documentType)) {
      throw ArgumentError('Invalid verification document type.');
    }
    if ((purpose == UploadPurpose.evidence && mime == 'application/pdf') ||
        (purpose == UploadPurpose.verification && mime == 'image/webp')) {
      throw ArgumentError('Unsupported file format.');
    }
    validateBytes(bytes, mime, purpose);
    final verification = purpose == UploadPurpose.verification;
    final result = await request(
        'POST',
        verification
            ? '/deliverers/me/applications/$entityId/documents'
            : '/orders/$entityId/evidence/uploads',
        {'mimeType': mime, if (verification) 'documentType': documentType});
    final id = result[verification ? 'documentId' : 'uploadId'];
    final url = Uri.tryParse(result['signedUrl']?.toString() ?? '');
    if (id is! String ||
        !RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(id) ||
        url == null ||
        storageOrigin.scheme != 'https' ||
        storageOrigin.host.isEmpty ||
        url.scheme != 'https' ||
        url.userInfo.isNotEmpty ||
        url.origin != storageOrigin.origin ||
        !url.path.startsWith('/storage/v1/object/upload/sign/')) {
      throw StateError('A valid private upload reservation was not supplied.');
    }
    // A separate transport prevents API authorization headers and redirects leaking to Storage.
    final response = await _transport.putUri<dynamic>(url,
        data: bytes,
        options: Options(
            contentType: mime,
            followRedirects: false,
            sendTimeout: const Duration(seconds: 45),
            receiveTimeout: const Duration(seconds: 45),
            headers: {'Authorization': null, 'Cookie': null},
            validateStatus: (status) =>
                status != null && status >= 200 && status < 300));
    if (response.statusCode == null ||
        response.statusCode! < 200 ||
        response.statusCode! >= 300) {
      throw StateError('Upload failed. Please try again.');
    }
    await request(
        'POST',
        verification
            ? '/verification-documents/$id/confirm'
            : '/evidence/uploads/$id/confirm',
        null);
    return id;
  }

  void dispose() => _transport.close(force: true);
}
