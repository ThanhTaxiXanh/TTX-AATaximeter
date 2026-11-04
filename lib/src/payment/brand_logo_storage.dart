import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';

/// The brand images are local-only; no logo bytes are sent to VietQR.
class BrandLogoStorage {
  static const allowed = ['png','jpg','jpeg','webp','gif','bmp','svg'];
  static Future<String?> importLogo({required String slot}) async {
    final picked = await FilePicker.platform.pickFile(
      type: FileType.custom,
      allowedExtensions: allowed,
    );
    if (picked == null) return null;
    final ext = picked.extension?.toLowerCase() ?? '';
    if (!allowed.contains(ext)) {
      throw const FormatException('Hỗ trợ PNG/JPEG/WebP/GIF/BMP/SVG');
    }
    final data = await picked.readAsBytes();
    if (data.isEmpty || data.length > 8 * 1024 * 1024) {
      throw const FormatException('Logo phải nhỏ hơn 8 MB');
    }
    final dir = Directory(
      (await getApplicationSupportDirectory()).path + '/ttx_qr_logos');
    await dir.create(recursive: true);
    final path = dir.path + '/' + slot + '.' + ext;
    await File(path).writeAsBytes(data, flush: true);
    return path;
  }
}

class BrandLogoView extends StatelessWidget {
  const BrandLogoView({super.key, required this.path,
    this.fit = BoxFit.contain});
  final String path;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    if (path.isEmpty || !File(path).existsSync()) {
      return const SizedBox.shrink();
    }
    if (path.toLowerCase().endsWith('.svg')) {
      return SvgPicture.file(File(path), fit: fit);
    }
    return Image.file(File(path), fit: fit, gaplessPlayback: true,
      errorBuilder: (ctx, error, stack) =>
        const Icon(Icons.broken_image_outlined));
  }
}
