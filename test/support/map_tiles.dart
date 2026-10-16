import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

class TestMapTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      const AssetImage('assets/images/movetraq-brand.png');
}
