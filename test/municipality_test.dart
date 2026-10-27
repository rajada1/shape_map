import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shape_map/shape_map.dart';

void main() {
  final asset = File('example/assets/maps/brazil_municipalities.smap');
  test(
    'optional municipality asset has validated IBGE regions',
    () async {
      final bytes = await asset.readAsBytes();
      final map = await ShapeMapData.decode(
        ByteData.sublistView(Uint8List.fromList(bytes)),
        id: 'brazilMunicipalities',
      );
      expect(map.regions, hasLength(5570));
      expect(map.regions.map((region) => region.id).toSet(), hasLength(5570));
      final saoPaulo = map.regionById('BR-3550308');
      expect(saoPaulo, isNotNull);
      expect(saoPaulo!.name, 'São Paulo');
      final saoPauloState = ShapeMaps.brazilStates.regionById('BR-SP');
      expect(saoPauloState, isNotNull);
      expect(
        saoPauloState!.geometry.path.contains(saoPaulo.markerAnchor),
        isTrue,
      );
    },
    skip: !asset.existsSync(),
  );
}
