import 'package:flutter/material.dart';
import '../domain/vehicle_registration.dart';

class VehicleRegistrationDialog extends StatefulWidget {
  const VehicleRegistrationDialog({super.key, this.initial});
  final VehicleRegistration? initial;

  @override
  State<VehicleRegistrationDialog> createState() =>
      _VehicleRegistrationDialogState();
}

class _VehicleRegistrationDialogState extends State<VehicleRegistrationDialog> {
  late VehicleCategory _category =
      widget.initial?.category.isSelectable == true
          ? widget.initial!.category : VehicleCategory.fiveSeats;
  late final TextEditingController _brand = TextEditingController(
    text: widget.initial?.brand ?? '');
  late final TextEditingController _plate = TextEditingController(
    text: widget.initial?.plate ?? '');
  String? _error;

  @override
  void dispose() {
    _brand.dispose();
    _plate.dispose();
    super.dispose();
  }

  void _submit() {
    if (_brand.text.trim().isEmpty) {
      setState(() => _error = 'Vui lòng nhập hãng xe.');
      return;
    }
    try {
      final value = VehicleRegistration(
        category: _category, brand: _brand.text, plate: _plate.text);
      Navigator.of(context).pop(value);
    } catch (_) {
      setState(() => _error =
          'Hãng xe tối đa 60 ký tự; biển số 5–16 ký tự (chữ, số, . hoặc -).');
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: const Color(0xFF111829),
    title: const Text('ĐĂNG KÝ THÔNG TIN XE', style: TextStyle(
      color: Color(0xFFFFB800), fontWeight: FontWeight.w800)),
    content: SingleChildScrollView(child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Chọn loại xe đang sử dụng:'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final category in VehicleCategory.selectable)
            ChoiceChip(
              label: Text(category.label),
              selected: _category == category,
              onSelected: (_) => setState(() => _category = category),
            ),
        ]),
        const SizedBox(height: 14),
        TextField(
          key: const Key('vehicle-brand-field'),
          controller: _brand,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Hãng xe (bắt buộc)',
            hintText: 'Ví dụ: VinFast, Toyota, Hyundai',
            prefixIcon: Icon(Icons.directions_car_outlined),
          ),
        ),
        const SizedBox(height: 5),
        TextField(
          key: const Key('vehicle-plate-field'),
          controller: _plate,
          maxLength: 16,
          textCapitalization: TextCapitalization.characters,
          onChanged: (_) => setState(() => _error = null),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Biển số xe (bắt buộc)',
            hintText: 'Ví dụ: 98G-001.07',
            prefixIcon: Icon(Icons.confirmation_number_outlined),
          ),
        ),
        if (_error != null)
          Text(_error!, style: const TextStyle(color: Colors.redAccent)),
        const Text('Thông tin xe chỉ lưu trên điện thoại. '
          'Loại xe không tự động xác nhận biểu giá tính cước.',
          style: TextStyle(fontSize: 11, color: Colors.white60)),
      ],
    )),
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
