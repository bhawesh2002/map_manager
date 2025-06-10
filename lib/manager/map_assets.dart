import 'package:map_manager_mapbox/utils/utils.dart';

class MapAssets {
  static late final selectedLoc;
  static Future<void> init() async {
    selectedLoc = await fetchImageFromNetworkImage(
        "https://github.com/bhawesh2002/map_manager_mapbox/raw/refs/heads/main/assets/selected-loc.png");
  }
}
