import 'package:flutter/material.dart';

import '../domain/traffic_sign.dart';

/// These details are informative and never modify taxi fare or speed policy.
class TrafficSignDetails extends StatelessWidget {
  const TrafficSignDetails({super.key, required this.sign});

  final TrafficSign sign;

  @override
  Widget build(BuildContext context) {
    Widget line(String title, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('$title: $value',
        style: const TextStyle(color: Colors.white, fontSize: 13)),
    );
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Thông tin biển báo', style: TextStyle(
                color: Colors.white, fontSize: 18,
                fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              line('ID', '${sign.signId}'),
              line('Mã loại biển', '${sign.signTypeCode}'),
              line('Tọa độ GPS', '${sign.latitude}, ${sign.longitude}'),
              line('Giá trị thô', '${sign.valueRaw}'),
              line('Hướng thô', '${sign.directionRaw}'),
              line('Tốc độ suy ra', sign.speedKmhInferred == null
                  ? 'Chưa có dữ liệu'
                  : '${sign.speedKmhInferred} km/h (chưa xác minh)'),
              line('Loại biển', 'Loại biển chưa được xác minh'),
              line('Tình trạng', 'Chưa xác minh'),
              line('Nguồn', sign.sourceDataset),
              const SizedBox(height: 8),
              const Text(
                'Lớp dữ liệu tham khảo. Không dùng làm giới hạn tốc độ '
                'pháp lý hoặc cảnh báo an toàn.',
                style: TextStyle(color: Colors.amberAccent, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
