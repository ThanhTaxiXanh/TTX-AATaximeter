import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:latlong2/latlong.dart' as ll;

import '../domain/traffic_sign.dart';
import '../domain/traffic_sign_catalog.dart';
import 'traffic_sign_icon_pack.dart';

/// Only viewport-sized aggregates enter the Flutter widget tree.
/// User-supplied icons are used solely for explicitly matched type codes.
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

  Widget _iconOrFallback(SignMapItem item) {
    final bytes = item.isCluster
        ? null : TrafficSignIconPack.pngForCode(item.signTypeCode);
    if (bytes != null) {
      // The icon is a compact representation of the actual owner-supplied
      // PNG, not a label guessed from unknown SQLite codes.
      return Image.memory(
        bytes,
        width: 40,
        height: 40,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        gaplessPlayback: true,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: item.isCluster
            ? const Color(0xEE092844) : const Color(0xF5112537),
        border: Border.all(
          color: !item.isCluster &&
              TrafficSignCatalog.postedSpeedNumber(
                  item.signTypeCode ?? -1, item.valueRaw ?? 0) != null
              ? const Color(0xFFEA4040)
              : const Color(0xFF00C2FF),
          width: 1.6,
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
                  fontSize: 12, fontWeight: FontWeight.bold))
            : Text(
                TrafficSignCatalog.markerLabel(
                  item.signTypeCode, item.valueRaw,
                  legacyInferredSpeed: item.speedKmhInferred),
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10, fontWeight: FontWeight.w900)),
      ),
    );
  }

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
                : 'Biển báo ${item.signId}, '
                    '${item.signTypeCode == null ? 'chưa rõ loại' : TrafficSignCatalog.description(item.signTypeCode!)}, '
                    'chưa xác minh hiệu lực',
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
              child: _iconOrFallback(item),
            ),
          ),
        ),
    ],
  );
}
