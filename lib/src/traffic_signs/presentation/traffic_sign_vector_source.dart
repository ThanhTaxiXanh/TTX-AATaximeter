import '../domain/traffic_sign.dart';
import '../domain/traffic_sign_catalog.dart';
import 'traffic_sign_icon_pack.dart';

/// Pure conversion: only bounded RTree viewport aggregates go to MapLibre.
/// These Point features NEVER declare legal speed limits or territorial lines.
abstract final class TrafficSignVectorSource {
  static const sourceId = 'ttx-traffic-sign-points';
  static const circlesId = 'ttx-traffic-sign-circles';
  static const labelsId = 'ttx-traffic-sign-labels';
  static const iconsId = 'ttx-traffic-sign-icons';

  static String featureId(SignMapItem item) =>
      '${item.isCluster ? 'cluster' : 'sign'}_${item.signId}';

  static String label(SignMapItem item) {
    if (item.isCluster) {
      if (item.count > 9999) return '${item.count ~/ 1000}k+';
      return '${item.count}';
    }
    // User-confirmed code/value get their own visual identities.
    // An inferred fallback remains marked ~ and is never a road limit.
    return TrafficSignCatalog.markerLabel(
      item.signTypeCode, item.valueRaw,
      legacyInferredSpeed: item.speedKmhInferred);
  }

  static Map<String, dynamic> features(List<SignMapItem> items) => {
    'type': 'FeatureCollection',
    'features': [
      for (final item in items)
        {
          'type': 'Feature',
          'id': featureId(item),
          'properties': {
            'sign_id': item.signId,
            'count': item.count,
            'display': label(item),
            'is_cluster': item.isCluster,
            'verification_status': 'unverified',
            'inferred_speed': item.speedKmhInferred,
            'sign_type_code': item.isCluster ? null : item.signTypeCode,
            'raw_value': item.isCluster ? null : item.valueRaw,
            'owner_type_label': item.isCluster || item.signTypeCode == null
                ? null : TrafficSignCatalog.description(item.signTypeCode!),
            if (!item.isCluster &&
                TrafficSignIconPack.mapLibreImageId(item.signTypeCode) != null)
              'icon_key': TrafficSignIconPack.mapLibreImageId(item.signTypeCode),
          },
          'geometry': {
            'type': 'Point',
            'coordinates': [item.longitude, item.latitude],
          },
        },
    ],
  };

  static SignMapItem? tapped(
      String id, Map<String, SignMapItem> visibleById) {
    // Do not trust a provider feature or stale native callback.
    if (!id.startsWith('sign_') && !id.startsWith('cluster_')) return null;
    return visibleById[id];
  }
}
