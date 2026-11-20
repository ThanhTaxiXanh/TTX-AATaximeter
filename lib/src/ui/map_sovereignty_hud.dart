import 'package:flutter/material.dart';

import 'vietnam_map_sovereignty.dart';

/// Persistent product labels, not geographic markers or a vehicle position.
///
/// This HUD is intentionally independent of camera, GPS, style and network.
/// Geo-referenced labels remain in the underlying map renderers.
class MapSovereigntyHud extends StatelessWidget {
  const MapSovereigntyHud({super.key});

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: Semantics(
      container: true,
      label: 'Địa danh biển đảo trên bản đồ',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xEE091F33),
          border: Border.all(color: const Color(0x9900C2FF), width: 0.6),
          borderRadius: BorderRadius.circular(9),
        ),
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Wrap(
            spacing: 9,
            runSpacing: 2,
            children: [
              Text(
                VietnamMapSovereignty.hoangSa,
                key: Key('ttx-hud-hoang-sa'),
                softWrap: true,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                VietnamMapSovereignty.truongSa,
                key: Key('ttx-hud-truong-sa'),
                softWrap: true,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
