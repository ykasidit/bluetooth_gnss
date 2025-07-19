import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatelessWidget {
  MapScreen({super.key});
  final mapController = MapController();

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
      var pos = LatLng(position.latitude, position.longitude);
      mapController.move(pos, 12);
      androidLocation.value = LatLng(position.latitude, position.longitude);
      bluetoothLocation.value = LatLng(position.latitude, position.longitude);
    });
  }

  @override
  Widget build(BuildContext context) {
    _startLocationUpdates();

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
        MarkerLayer(
          markers: [
            if (androidLocation.value != null)
              Marker(
                point: androidLocation.value!,
                width: 40,
                height: 40,
                child: const Icon(Icons.phone_android, color: Colors.green),
              ),
            if (bluetoothLocation.value != null)
              Marker(
                point: bluetoothLocation.value!,
                width: 40,
                height: 40,
                child: const Icon(Icons.bluetooth, color: Colors.blue),
              ),
          ],
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

final ValueNotifier<LatLng?> androidLocation = ValueNotifier(null);
final ValueNotifier<LatLng?> bluetoothLocation = ValueNotifier(null);
