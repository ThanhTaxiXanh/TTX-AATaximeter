import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;

import '../domain/traffic_sign.dart';

/// Only viewport-sized aggregates enter the Flutter widget tree.
class TrafficSignLayer extends StatelessWidget {
  const TrafficSignLayer({
    super.key,
    required this.items,
    required this.onSelect,
    required this.onCluster,
  });

  final List<SignMapItem> items;
  final ValueChanged<int> onSelect;
  final ValueChanged<SignMapItem> onCluster;

  @override
  Widget build(BuildContext context) => fm.MarkerLayer(
    markers: [
      for (final item in items)
        fm.Marker(
          point: ll.LatLng(item.latitude, item.longitude),
          width: item.isCluster ? 46 : 40,
          height: item.isCluster ? 46 : 40,
          child: Semantics(
            label: item.isCluster
                ? 'Cụm ${item.count} biển báo'
                : 'Biển báo ${item.signId}, chưa xác minh',
            button: true,
            child: GestureDetector(
              key: ValueKey('sign-${item.signId}'),
              onTap: () {
                if (item.isCluster) {
                  onCluster(item);
                } else {
                  onSelect(item.signId);
                }
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: item.isCluster
                      ? const Color(0xEE092844)
                      : const Color(0xF5112537),
                  border: Border.all(
                    color: const Color(0xFF00C2FF), width: 1.6,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0x88000000), blurRadius: 5),
                  ],
                ),
                child: Center(
                  child: item.isCluster
                      ? Text('${item.count}', maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12, fontWeight: FontWeight.bold,
                          ))
                      : (item.speedKmhInferred != null
                          ? Text('${item.speedKmhInferred}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ))
                          : const Icon(Icons.signpost_outlined,
                              color: Colors.white, size: 22)),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}
