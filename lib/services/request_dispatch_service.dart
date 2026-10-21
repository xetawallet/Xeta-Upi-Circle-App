import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pretty_qr_code/pretty_qr_code.dart';
import 'package:share_plus/share_plus.dart';
import 'package:whatsapp_direct_send/whatsapp_direct_send.dart';

import '../models/request_draft.dart';
import '../models/trusted_person.dart';

class DispatchResult {
  const DispatchResult({required this.channel, required this.launched});

  final String channel;
  final bool launched;
}

class RequestDispatchService {
  const RequestDispatchService();

  Future<DispatchResult> sendViaWhatsApp({
    required TrustedPerson helper,
    required String message,
    required RequestDraft draft,
  }) async {
    final qrFilePath = await _createQrFile(draft.qrValue);
    final normalizedPhone = _normalizePhone(helper.phoneNumber);

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      try {
        await WhatsappDirectSend.shareToChat(
          phone: normalizedPhone,
          text: message,
          filePath: qrFilePath,
        );
        return const DispatchResult(channel: 'WhatsApp', launched: true);
      } catch (_) {
        await _shareFallback(message: message, qrFilePath: qrFilePath);
        return const DispatchResult(
          channel: 'WhatsApp Share Sheet',
          launched: true,
        );
      }
    }

    await _shareFallback(message: message, qrFilePath: qrFilePath);
    return const DispatchResult(channel: 'Share Sheet', launched: true);
  }

  Future<DispatchResult> sendViaOtherSources({
    required String message,
    required RequestDraft draft,
  }) async {
    final qrFilePath = await _createQrFile(draft.qrValue);
    await _shareFallback(
      message: message,
      qrFilePath: qrFilePath,
      title: 'Share through other sources',
    );
    return const DispatchResult(channel: 'Other Sources', launched: true);
  }

  Future<String?> pickAndStoreProofImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      dialogTitle: 'Select the payment proof image from WhatsApp',
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final selectedFile = result.files.single;
    final extension = _fileExtension(selectedFile.name);
    final targetDirectory = await _ensureArchiveDirectory();
    final targetPath =
        '${targetDirectory.path}/proof_${DateTime.now().microsecondsSinceEpoch}$extension';
    final bytes = await _readSelectedFileBytes(selectedFile);

    final file = File(targetPath);
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> deleteStoredProofImages(Iterable<String?> paths) async {
    if (kIsWeb) return;
    final archiveDirectory = await _ensureArchiveDirectory();
    final safePrefix =
        '${archiveDirectory.absolute.path}${Platform.pathSeparator}';
    for (final path in paths) {
      if (path == null || path.isEmpty) continue;
      final file = File(path).absolute;
      if (!file.path.startsWith(safePrefix)) continue;
      try {
        if (await file.exists()) await file.delete();
      } on FileSystemException {
        // Keep transaction deletion complete even if an old proof is unavailable.
      }
    }
  }

  Future<void> _shareFallback({
    required String message,
    required String qrFilePath,
    String title = 'Xeta UPI Circle App request',
  }) async {
    await SharePlus.instance.share(
      ShareParams(text: message, title: title, files: [XFile(qrFilePath)]),
    );
  }

  Future<Directory> _ensureArchiveDirectory() async {
    final baseDirectory = await getApplicationDocumentsDirectory();
    final archiveDirectory = Directory(
      '${baseDirectory.path}/Xeta UPI Circle App',
    );
    if (!await archiveDirectory.exists()) {
      await archiveDirectory.create(recursive: true);
    }
    return archiveDirectory;
  }

  Future<String> _createQrFile(String data) async {
    final qrCode = QrCode.fromData(
      data: data,
      errorCorrectLevel: QrErrorCorrectLevel.M,
    );
    final qrImage = QrImage(qrCode);
    final bytes = await qrImage.toImageAsBytes(
      size: 1200,
      format: ui.ImageByteFormat.png,
      decoration: const PrettyQrDecoration(
        shape: PrettyQrSmoothSymbol(color: Color(0xFF112F2C)),
        background: Color(0xFFFFFFFF),
        quietZone: PrettyQrQuietZone.modules(2),
      ),
    );

    if (bytes == null) {
      throw StateError('Unable to generate the QR image for WhatsApp sharing.');
    }

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/xeta_upi_circle_app_qr_${DateTime.now().microsecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    return file.path;
  }

  String _fileExtension(String filename) {
    final dotIndex = filename.lastIndexOf('.');
    if (dotIndex <= 0 || dotIndex == filename.length - 1) {
      return '.png';
    }
    return filename.substring(dotIndex);
  }

  String _normalizePhone(String input) {
    final digitsOnly = input.replaceAll(RegExp(r'\D'), '');
    if (digitsOnly.length == 10) {
      return '91$digitsOnly';
    }
    return digitsOnly;
  }

  Future<List<int>> _readSelectedFileBytes(PlatformFile selectedFile) async {
    if (selectedFile.bytes != null) {
      return selectedFile.bytes!;
    }

    final path = selectedFile.path;
    if (!kIsWeb && path != null && path.isNotEmpty) {
      return File(path).readAsBytes();
    }

    throw StateError('Unable to read the selected proof image.');
  }
}
