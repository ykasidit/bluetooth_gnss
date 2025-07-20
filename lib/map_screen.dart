import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

final ValueNotifier<LatLng?> mapInternalDevPos = ValueNotifier(null);
final ValueNotifier<LatLng?> mapExternalDevPos = ValueNotifier(null);


class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  MapScreenState createState() => MapScreenState();
}

class MapScreenState extends State<MapScreen> {
  final mapController = MapController();
  LatLng? lastMovedPos;
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
      if (lastMovedPos == null) {
        developer.log("moving map to pos: $pos");
        mapController.move(pos, 12);
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
    );
    return FlutterMap(
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
                    child: const Icon(Icons.bluetooth, color: Colors.blue),
                  ),
              ],
            );
          },
        )
      ],
    );
    /*ValueListenableBuilder<LatLng?>(
      valueListenable: androidLocation,
      builder: (context, androidPos, _) {
        final center = androidPos ?? const LatLng(0, 0);

        return FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.clearevo.bluetooth_gnss',
            ),
            ValueListenableBuilder<LatLng?>(
              valueListenable: bluetoothLocation,
              builder: (context, btPos, _) {
                return MarkerLayer(
                  markers: [
                    if (androidPos != null)
                      Marker(
                        point: androidPos,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.phone_android, color: Colors.green),
                      ),
                    if (btPos != null)
                      Marker(
                        point: btPos,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.bluetooth, color: Colors.blue),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );*/
  }
}

