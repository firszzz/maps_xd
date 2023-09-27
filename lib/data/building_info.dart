import 'package:syncfusion_flutter_maps/maps.dart';

///    v1.0                   v2.0
///    PolygonModel       ==    PolygonData
///    LayerMap           ==    FloorData
///    FloorMap           ==    BuildingData
///    ListMainLayer      ==    MainPolygonsList
///    AllMapBuilding     ==    AllBuildingsData
///    BuildingBoundInfo  ==    BoundBuildingInfo

class PolygonData {
  List<MapLatLng> points;
  String polygonName;

  PolygonData({ required this.points, required this.polygonName });
}

class FloorData {
  List<PolygonData> polygons;
  int floorNum;

  FloorData({ required this.polygons, required this.floorNum });
}

class BuildingData {
  List<FloorData> floorData;
  PolygonData mainPolygon;

  BuildingData({ required this.floorData, required this.mainPolygon });

  static BuildingData sortMap(
      { required List<FloorData> floorData, required PolygonData mainPolygon }) {
    floorData.sort((a, b) => b.floorNum.compareTo(a.floorNum));

    return BuildingData(floorData: floorData, mainPolygon: mainPolygon);
  }
}

class MainPolygonsList {
  List<PolygonData> mainPolygonsList;

  MainPolygonsList({ required this.mainPolygonsList });
}

class AllBuildingsData {
  List<BuildingData> buildingsData;

  AllBuildingsData({ required this.buildingsData });
}

class BoundBuildingInfo {
  double boundPercent;
  BuildingData boundBuilding;

  BoundBuildingInfo({ required this.boundPercent, required this.boundBuilding });
}

PolygonData normalizeData(List<List<double>> initData, String name) {
  List<MapLatLng> coordinates = [];

  for (int i = 0; i < initData.length; i++) {
    coordinates.add(MapLatLng(initData[i].last, initData[i].first));
  }

  PolygonData expectedData = PolygonData(points: coordinates, polygonName: name);

  return expectedData;
}
