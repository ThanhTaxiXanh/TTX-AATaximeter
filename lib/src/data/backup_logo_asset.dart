import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as path;

import '../payment/bank_book.dart';

/// Bytes of one locally imported VietQR brand logo, detached from its
/// device-specific absolute path. Never write these bytes into a live app.
class BackupLogoAsset {
  BackupLogoAsset({
    required this.slot,
    required this.extension,
    required Uint8List bytes,
  }) : bytes = Uint8List.fromList(bytes) {
    _validate();
  }

  static const maxBytes = 8 * 1024 * 1024;
  static const allowedExtensions = <String>{
    'png', 'jpg', 'jpeg', 'webp', 'gif', 'bmp', 'svg',
  };
  static const supportedSlots = <String>{'center', 'footer'};

  final String slot;
  final String extension;
  final Uint8List bytes;

  void _validate() {
    if (!supportedSlots.contains(slot) ||
        !allowedExtensions.contains(extension) ||
        bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Tên, định dạng hoặc dung lượng logo sai');
    }
    bool starts(List<int> signature) =>
        bytes.length >= signature.length &&
        List.generate(signature.length, (i) => bytes[i] == signature[i])
            .every((v) => v);
    switch (extension) {
      case 'png':
        if (!starts(const [137, 80, 78, 71, 13, 10, 26, 10])) {
          throw const FormatException('Logo PNG sai chữ ký');
        }
      case 'jpg' || 'jpeg':
        if (!starts(const [255, 216, 255])) {
          throw const FormatException('Logo JPEG sai chữ ký');
        }
      case 'gif':
        if (!starts(ascii.encode('GIF87a')) &&
            !starts(ascii.encode('GIF89a'))) {
          throw const FormatException('Logo GIF sai chữ ký');
        }
      case 'bmp':
        if (!starts(ascii.encode('BM'))) {
          throw const FormatException('Logo BMP sai chữ ký');
        }
      case 'webp':
        if (!starts(ascii.encode('RIFF')) ||
            bytes.length < 12 ||
            !List.generate(4, (i) => bytes[8 + i] ==
                ascii.encode('WEBP')[i]).every((v) => v)) {
          throw const FormatException('Logo WebP sai chữ ký');
        }
      case 'svg':
        String xml;
        try {
          xml = utf8.decode(bytes, allowMalformed: false);
        } on FormatException {
          throw const FormatException('Logo SVG không phải UTF-8');
        }
        if (!RegExp(r'<svg\b', caseSensitive: false).hasMatch(xml) ||
            RegExp(r'<\s*script\b|<!DOCTYPE|<!ENTITY|<\s*foreignObject\b|'
              r'(?:xlink:)?href\s*=',
              caseSensitive: false).hasMatch(xml)) {
          throw const FormatException('Logo SVG không được hỗ trợ an toàn');
        }
    }
  }
}

/// Capture only app-owned logo files from the documented import directory.
/// Refuse missing files and external paths rather than silently exporting
/// an incomplete backup or reading an arbitrary user-supplied path.
class BackupLogoCapture {
  static Future<List<BackupLogoAsset>> fromBankBook({
    required BankBook bankBook,
    required Directory appSupportDirectory,
  }) async {
    final configured = <String, String?>{
      'center': bankBook.centerLogoPath,
      'footer': bankBook.footerLogoPath,
    };
    if (configured.values.every((v) => v == null || v.isEmpty)) {
      return const [];
    }
    final logoDir = Directory(
      path.join(appSupportDirectory.path, 'ttx_qr_logos'));
    if (!await logoDir.exists()) {
      throw const FormatException('Thư mục logo VietQR không tồn tại');
    }
    final actualDir = await logoDir.resolveSymbolicLinks();
    final found = <BackupLogoAsset>[];
    for (final item in configured.entries) {
      final raw = item.value;
      if (raw == null || raw.isEmpty) continue;
      final file = File(raw);
      if (!await file.exists()) {
        throw FormatException('Thiếu logo đã lưu: ${item.key}');
      }
      final resolved = await file.resolveSymbolicLinks();
      final ext = path.extension(raw).replaceFirst('.', '').toLowerCase();
      if (path.dirname(resolved) != actualDir ||
          !BackupLogoAsset.allowedExtensions.contains(ext) ||
          !(path.basename(resolved) == '${item.key}.$ext' ||
            RegExp('^${item.key}_restored_[a-f0-9]{24}\\.$ext' + r'
        throw FormatException(
          'Đường dẫn logo ${item.key} không thuộc thư mục ứng dụng');
      }
      final size = await file.length();
      if (size <= 0 || size > BackupLogoAsset.maxBytes) {
        throw FormatException('Logo ${item.key} vượt giới hạn 8 MiB');
      }
      found.add(BackupLogoAsset(
        slot: item.key, extension: ext,
        bytes: await file.readAsBytes()));
    }
    return List<BackupLogoAsset>.unmodifiable(found);
  }
}
)
                .hasMatch(path.basename(resolved)))) {
        throw FormatException(
          'Đường dẫn logo ${item.key} không thuộc thư mục ứng dụng');
      }
      final size = await file.length();
      if (size <= 0 || size > BackupLogoAsset.maxBytes) {
        throw FormatException('Logo ${item.key} vượt giới hạn 8 MiB');
      }
      found.add(BackupLogoAsset(
        slot: item.key, extension: ext,
        bytes: await file.readAsBytes()));
    }
    return List<BackupLogoAsset>.unmodifiable(found);
  }
}
