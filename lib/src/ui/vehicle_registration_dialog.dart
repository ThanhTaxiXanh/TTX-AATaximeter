import 'package:flutter/material.dart';
import '../domain/vehicle_registration.dart';

/// Vehicle registration from the first reference video.
/// Does not infer the driver's license plate from the APK or screenshots.
class VehicleRegistrationDialog extends StatefulWidget {
  const VehicleRegistrationDialog({super.key, this.initial});

  final VehicleRegistration? initial;

  @override
  State<VehicleRegistrationDialog> createState() =>
      _VehicleRegistrationDialogState();
}

class _VehicleRegistrationDialogState
    extends State<VehicleRegistrationDialog> {
  late VehicleCategory _category =
      widget.initial?.category ?? VehicleCategory.fourSeats;
  late final TextEditingController _plate = TextEditingController(
    text: widget.initial?.plate ?? '');
  String? _error;

  @override
  void dispose() {
    _plate.dispose();
    super.dispose();
  }

  void _submit() {
    try {
      final registration = VehicleRegistration(
        category: _category,
        plate: _plate.text,
      );
      Navigator.of(context).pop(registration);
    } catch (_) {
      setState(() => _error =
          'Nhập biển số gồm 5–16 ký tự (chữ, số, dấu . hoặc -).');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF111829),
      title: const Text('ĐĂNG KÝ THÔNG TIN XE',
        style: TextStyle(color: Color(0xFFFFB800),
            fontWeight: FontWeight.w800)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn loại xe đang sử dụng:'),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final category in VehicleCategory.values)
                ChoiceChip(
                  label: Text(category.label),
                  selected: _category == category,
                  onSelected: (_) => setState(() => _category = category),
                ),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _plate,
              textCapitalization: TextCapitalization.characters,
              maxLength: 16,
              onChanged: (_) => setState(() => _error = null),
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Biển số xe (bắt buộc)',
                hintText: 'Ví dụ: 98G-001.07',
                prefixIcon: Icon(Icons.directions_car),
              ),
            ),
            if (_error != null) Text(_error!,
              style: const TextStyle(color: Colors.redAccent)),
            const Text('Thông tin xe chỉ lưu trên điện thoại. '
              'Việc chọn loại xe không tự động xác nhận biểu giá tính cước.',
              style: TextStyle(fontSize: 11, color: Colors.white60)),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context),
          child: const Text('Để sau')),
        FilledButton.icon(
          onPressed: _submit,
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('XÁC NHẬN'),
        ),
      ],
    );
  }
}
