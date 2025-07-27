import 'dart:developer' as developer;

import 'package:bluetooth_gnss/main.dart';
import 'package:bluetooth_gnss/utils_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

import 'channels.dart';
import 'connect.dart';
import 'const.dart';

final ValueNotifier<LatLng?> mapInternalDevPos = ValueNotifier(null);
final ValueNotifier<LatLng?> mapExternalDevPos = ValueNotifier(null);
final ValueNotifier<LatLng?> mapExternalDevPosOri = ValueNotifier(null);


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final mapController = MapController();
  LatLng? lastMovedPos;
  bool follow = true;
  LatLng? tappedPosition;
  ValueNotifier<String> currentOffsetSum = ValueNotifier("");

  @override
  void dispose() {
    developer.log("mapscreen dispose");
    super.dispose();
  }

  @override
  void initState()
  {
    super.initState();
    _startLocationUpdates();
  }

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    ).listen((Position position) {
      developer.log("Geolocator new pos: $position mocked: ${position.isMocked}");
      var pos = LatLng(position.latitude, position.longitude);
      if (lastMovedPos == null || follow) {
        developer.log("moving map to pos: $pos");
        mapController.move(pos, mapController.camera.zoom);
        lastMovedPos = pos;
      }
      mapInternalDevPos.value = LatLng(position.latitude, position.longitude);
    });
  }


  @override
  Widget build(BuildContext context) {
    MapOptions mapOptions = MapOptions(
      keepAlive: true,
      cameraConstraint: const CameraConstraint.containLatitude(),
      onLongPress: (tapPosition, latlng) async {
        tappedPosition = latlng;
        try {
          LatLng? lastOriPos = mapExternalDevPosOri.value;
          if (lastOriPos != null) {
            double lat_offset_m = (tappedPosition!.latitude -
                lastOriPos.latitude) * latlonDegtoMetersMultiplier;
            double lon_offset_m = (tappedPosition!.longitude -
                lastOriPos.longitude) * latlonDegtoMetersMultiplier;
            prefService.set("mock_lat_offset_meters", lat_offset_m.toString());
            prefService.set("mock_lon_offset_meters", lon_offset_m.toString());
            currentOffsetSum.value =
            "Offset: Lat: ${lat_offset_m.toStringAsFixed(2)}m Lon: ${lon_offset_m
                .toStringAsFixed(2)}m";
            await setLiveArgs();
            await toast(currentOffsetSum.value);
          }
        } catch (e, tr) {
          developer.log("set new lat/lon offset exception: $e $tr");
        }

      },
      onPositionChanged: (position, hasGesture) {
        if (hasGesture) {
          follow = false;
        }
      },
    );

    return Stack(
      children: [
        FlutterMap(
          mapController: mapController,
          options: mapOptions,
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.clearevo.bluetooth_gnss',
            ),
            ValueListenableBuilder<LatLng?>(
              valueListenable: mapExternalDevPos,
              builder: (context, externalPos, _) {
                developer.log("building new MarkerLayer for externalPos: $externalPos");
                return MarkerLayer(
                  markers: [
                    if (externalPos != null)
                      Marker(
                        point: externalPos,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.location_on, color: Colors.blue),
                      ),
                  ],
                );
              },
            ),
            ValueListenableBuilder<LatLng?>(
              valueListenable: mapExternalDevPosOri,
              builder: (context, externalPos, _) {
                developer.log("building new MarkerLayer for mapExternalDevPosOri: $mapExternalDevPosOri");
                return MarkerLayer(
                  markers: [
                    if (externalPos != null)
                      Marker(
                        point: externalPos,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.bluetooth_connected_rounded, color: Colors.blue),
                      ),
                  ],
                );
              },
            ),
          ],
        ),

        // 🧭 Top-right: Controls
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            children: [
              FloatingActionButton(
                mini: true,
                heroTag: 'followBtn',
                tooltip: 'Toggle Follow',
                onPressed: () {
                  setState(() {
                    follow = !follow;
                  });
                },
                child: Icon(follow ? Icons.gps_fixed : Icons.gps_not_fixed),
              ),
              const SizedBox(height: 10),
              FloatingActionButton(
                mini: true,
                heroTag: 'northBtn',
                tooltip: 'Reset Rotation',
                onPressed: () {
                  mapController.rotate(0);
                },
                child: const Icon(Icons.explore),
              ),
            ],
          ),
        ),

        // 🧾 Bottom-right: OSM Attribution
        Positioned(
          bottom: 4,
          right: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            color: Colors.white70,
            child: const Text(
              '© OpenStreetMap contributors',
              style: TextStyle(fontSize: 10),
            ),
          ),
        ),

        // ℹ️ Bottom-left: Long tap info + tapped position
        Positioned(
          bottom: 4,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            color: Colors.white70,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '📍 Long tap to correct offsets in settings',
                  style: TextStyle(fontSize: 11),
                ),
                reactiveText(currentOffsetSum, style: const TextStyle(fontSize: 11))
              ],
            ),
          ),
        ),
      ],
    );
  }

}

