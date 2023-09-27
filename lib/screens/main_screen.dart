import 'dart:math';

import 'package:flutter/material.dart';
import 'package:map_feature/data/building_info.dart';
import 'package:map_feature/data/test_data.dart';
import 'package:syncfusion_flutter_maps/maps.dart';
import 'package:location/location.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late MapTileLayer mapTileLayer;
  late MapZoomPanBehavior zoomPanBehavior;
  late MapTileLayerController controller;
  late AllBuildingsData allBuildingsData;
  late List<MapLatLng> screenBounds;
  late MainPolygonsList mainPolygonsList;
  late BuildingData? drawnBuilding;
  late Location location;
  late MapMarker? geoMarker;

  int floorNum = 0;
  bool needDraw = false;
  late List<MapMarker> markerList;

  @override
  void initState() {
    controller = MapTileLayerController();
    location = Location();

    markerList = [];

    zoomPanBehavior = MapZoomPanBehavior(
      focalLatLng: const MapLatLng(43.102592547117155, 131.9172953240419),
      zoomLevel: 15,
      minZoomLevel: 12,
      maxZoomLevel: 19.5,
      enableDoubleTapZooming: true,
    );

    mapTileLayer = MapTileLayer(
      key: UniqueKey(),
      controller: controller,
      zoomPanBehavior: zoomPanBehavior,
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      initialMarkersCount: 0,
      markerBuilder: (context, index) {
        return markerList[index];
      },
      sublayers: [
        const MapPolygonLayer(
          polygons: {}
        ),
      ],
      onWillZoom: (MapZoomDetails details) {
        if (details.previousZoomLevel! > 17.75 && (mapTileLayer.sublayers?.length == 0 || mapTileLayer.sublayers?.length == 1)) {
          onZoomDrawPolygons();
        }

        if (details.previousZoomLevel! < 17.75 && mapTileLayer.sublayers?.length != 1) {
          clearPolygons();

          if (screenBounds.isNotEmpty) {
            screenBounds.clear();
          }
        }

        return true;
      },
      onWillPan: (MapPanDetails details) {
        if (details.zoomLevel! > 17.75) {
          onPanDrawPolygon();
        }

        return true;
      },
    );

    allBuildingsData = allTestBuildingsData;
    mainPolygonsList = mainTestPolygonsList;

    screenBounds = [];

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Scaffold(
        body: SfMaps(
          layers: [
            mapTileLayer,
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        floatingActionButton: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (needDraw && drawnBuilding != null) SizedBox(
              height: 200,
              width: 70,
              child: ListView.builder(
                itemCount: drawnBuilding!.floorData.length,
                itemBuilder: (BuildContext context, int index) {
                  return ElevatedButton(
                    onPressed: () {
                      setState(() {
                        floorNum = index;
                        clearPolygons();
                        onZoomDrawPolygons();
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: floorNum == index ? Colors.black54 : Colors.blueGrey,
                    ),
                    child: Text(
                      drawnBuilding!.floorData[index].floorNum.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0, right: 10.0),
              child: SizedBox(
                height: 60,
                width: 60,
                child: TextButton(
                  onPressed: () async {

                    /// Получение геолокации

                    geoMarker = await getLocation();

                    if (geoMarker != null) {
                      if (markerList.isEmpty) {
                        markerList.add(geoMarker!);
                        controller.insertMarker(controller.markersCount);
                      }
                      else if (markerList.length == 1) {
                        markerList[0] = geoMarker!;
                        controller.updateMarkers([0]);
                      }

                      zoomPanBehavior.focalLatLng = MapLatLng(
                        geoMarker!.latitude,
                        geoMarker!.longitude,
                      );

                      zoomPanBehavior.zoomLevel = 18.5;
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                  ),
                  child: Transform.rotate(
                    angle: 45 * pi / 180,
                    child: const Icon(
                      Icons.navigation,
                      color: Colors.white,
                    ),
                  )
                )
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<MapMarker?> getLocation() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;
    LocationData locationData;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return null;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return null;
      }
    }

    locationData = await location.getLocation();

    return MapMarker(
      latitude: locationData.latitude!,
      longitude: locationData.longitude!,
      child: const Icon(
        Icons.my_location_outlined,
        color: Colors.red,
      ),
    );
  }

  void onPanDrawPolygon() {
    MapLatLngBounds? _screenBounds = zoomPanBehavior.latLngBounds;

    if (_screenBounds != null) {
      if ((_screenBounds.southwest.latitude - screenBounds.first.latitude).abs() < 1.0) {
        setState(() {
          screenBounds.clear();
          screenBounds.addAll(
              [
                // LOWEST COORDINATES
                MapLatLng(
                  _screenBounds.southwest.latitude,
                  _screenBounds.southwest.longitude,
                ),
                // HIGHEST COORDINATES
                MapLatLng(
                  _screenBounds.northeast.latitude,
                  _screenBounds.northeast.longitude,
                ),
              ]
          );
        });
      }

      BuildingData? checkBuilding = getBoundsBuilding(screenBounds[0], screenBounds[1], allBuildingsData);

      if (checkBuilding == null) {
        clearPolygons();

        return;
      }

      if (drawnBuilding != checkBuilding) {
        clearPolygons();

        setState(() {
          drawnBuilding = checkBuilding;
          floorNum = 0;

          mapTileLayer.sublayers!.add(
            MapPolygonLayer(
              key: UniqueKey(),
              polygons: List<MapPolygon>.generate(
                1,
                (int index) {
                  return MapPolygon(
                    points: drawnBuilding!.mainPolygon.points,
                    color: const Color.fromRGBO(255, 255, 255, 1),
                  );
                }
              ).toSet(),
              tooltipBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                    drawnBuilding!.mainPolygon.polygonName,
                    style: const TextStyle(
                        color: Colors.white
                    ),
                  ),
                );
              },
            ),
          );

          for (var polygon in drawnBuilding!.floorData[floorNum].polygons) {
            mapTileLayer.sublayers!.add(
                MapPolygonLayer(
                  key: UniqueKey(),
                  strokeColor: Colors.black54,
                  strokeWidth: 2,
                  polygons: List<MapPolygon>.generate(
                      1,
                      (int index) {
                        return MapPolygon(
                            points: polygon.points,
                            color: Colors.primaries[Random().nextInt(
                                Colors.primaries.length)],
                            onTap: () {}
                        );
                      }
                  ).toSet(),
                  tooltipBuilder: (BuildContext context, int index) {
                    return Padding(
                      key: UniqueKey(),
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        polygon.polygonName,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  },
                )
            );
          }

          needDraw = true;
        });
      }
    }

    /// TODO: Пофиксить этот способ оповещения карты (поискать в контроллере и тд)
    MapLatLng? zPBActual = mapTileLayer.zoomPanBehavior?.focalLatLng;
    if (zPBActual != null) {
      mapTileLayer.zoomPanBehavior?.focalLatLng = MapLatLng(
        zPBActual.latitude + 0.00000001,
        zPBActual.longitude + 0.00000001,
      );
    }
    /// TODO: Пофиксить этот способ оповещения карты (поискать в контроллере и тд)
  }

  void onZoomDrawPolygons() {
    MapLatLngBounds? _screenBounds = zoomPanBehavior.latLngBounds;

    if (_screenBounds != null) {
      screenBounds.addAll(
          [
            // LOWEST COORDINATES
            MapLatLng(
              _screenBounds.southwest.latitude,
              _screenBounds.southwest.longitude,
            ),
            // HIGHEST COORDINATES
            MapLatLng(
              _screenBounds.northeast.latitude,
              _screenBounds.northeast.longitude,
            ),
          ]
      );

      drawnBuilding = getBoundsBuilding(screenBounds[0], screenBounds[1], allBuildingsData);

      if (drawnBuilding != null) {
        setState(() {
          mapTileLayer.sublayers!.add(
            MapPolygonLayer(
              key: UniqueKey(),
              polygons: List<MapPolygon>.generate(
                  1,
                      (int index) {
                    return MapPolygon(
                      points: drawnBuilding!.mainPolygon.points,
                      color: const Color.fromRGBO(255, 255, 255, 1),
                    );
                  }
              ).toSet(),
              tooltipBuilder: (BuildContext context, int index) {
                return Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Text(
                    drawnBuilding!.mainPolygon.polygonName,
                    style: const TextStyle(
                        color: Colors.white
                    ),
                  ),
                );
              },
            ),
          );

          for (var polygon in drawnBuilding!.floorData[floorNum].polygons) {
            mapTileLayer.sublayers!.add(
                MapPolygonLayer(
                  key: UniqueKey(),
                  strokeColor: Colors.black54,
                  strokeWidth: 2,
                  polygons: List<MapPolygon>.generate(
                      1,
                          (int index) {
                        return MapPolygon(
                            points: polygon.points,
                            color: Colors.primaries[Random().nextInt(Colors.primaries.length)],
                            onTap: () {}
                        );
                      }
                  ).toSet(),
                  tooltipBuilder: (BuildContext context, int index) {
                    return Padding(
                      key: UniqueKey(),
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        polygon.polygonName,
                        style: const TextStyle(color: Colors.white),
                      ),
                    );
                  },
                )
            );
          }

          needDraw = true;
        });
      }
      else {
        clearPolygons();
      }
    }


    /// TODO: Пофиксить этот способ оповещения карты (поискать в контроллере и тд)
    MapLatLng? zPBActual = mapTileLayer.zoomPanBehavior?.focalLatLng;
    if (zPBActual != null) {
      mapTileLayer.zoomPanBehavior?.focalLatLng = MapLatLng(
        zPBActual.latitude + 0.00000001,
        zPBActual.longitude + 0.00000001,
      );
    }
    /// TODO: Пофиксить этот способ оповещения карты (поискать в контроллере и тд)
  }

  void clearPolygons() {
    setState(() {
      needDraw = false;
      drawnBuilding = null;
      mapTileLayer.sublayers!.clear();
    });


    /// TODO: Пофиксить этот способ оповещения карты (поискать в контроллере и тд)
    MapLatLng? zPBActual = mapTileLayer.zoomPanBehavior?.focalLatLng;
    if (zPBActual != null) {
      mapTileLayer.zoomPanBehavior?.focalLatLng = MapLatLng(
        zPBActual.latitude + 0.00000001,
        zPBActual.longitude + 0.00000001,
      );
    }
    /// TODO: Пофиксить этот способ оповещения карты (поискать в контроллере и тд)
  }

  BuildingData? getBoundsBuilding(MapLatLng lowest, MapLatLng highest, AllBuildingsData buildings) {
    List<BoundBuildingInfo> listBuildingInfo = [];

    for (var building in buildings.buildingsData) {
      int count = 0;
      late double percentage;

      for (var mainLayer in building.mainPolygon.points) {
        if ((lowest.latitude < mainLayer.latitude && mainLayer.latitude < highest.latitude)
            && (lowest.longitude < mainLayer.longitude && mainLayer.longitude < highest.longitude)) {
          count++;
        }
      }

      percentage = double.parse((count / building.mainPolygon.points.length).toStringAsFixed(2)) * 100;

      listBuildingInfo.add(
        BoundBuildingInfo(
          boundPercent: percentage,
          boundBuilding: building
        ),
      );
    }

    listBuildingInfo.sort((a, b) => b.boundPercent.compareTo(a.boundPercent));

    if (listBuildingInfo.first.boundPercent == 0.0) {
      return null;
    }

    return listBuildingInfo.first.boundBuilding;
  }
}


