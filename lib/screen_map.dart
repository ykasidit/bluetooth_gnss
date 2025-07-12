import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatelessWidget {
  MapScreen({super.key});

  Future<void> _startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }
    Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
    ).listen((Position position) {
      androidLocation.value = LatLng(position.latitude, position.longitude);
    });

    // Simulate external GNSS device update
    Future.delayed(const Duration(seconds: 3), () {
      bluetoothLocation.value = const LatLng(13.7570, 100.5025);
    });
  }

  @override
  Widget build(BuildContext context) {
    _startLocationUpdates();
    return ValueListenableBuilder<LatLng?>(
      valueListenable: androidLocation,
      builder: (context, androidPos, _) {
        final center = androidPos ?? const LatLng(13.7563, 100.5018);

        return FlutterMap(
          options: MapOptions(
            initialCenter: center,
            initialZoom: 15,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.hybrid_gnss',
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
                        child: const Icon(Icons.phone_android, color: Colors.blue),
                      ),
                    if (btPos != null)
                      Marker(
                        point: btPos,
                        width: 40,
                        height: 40,
                        child: const Icon(Icons.gps_fixed, color: Colors.green),
                      ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

final ValueNotifier<LatLng?> androidLocation = ValueNotifier(null);
final ValueNotifier<LatLng?> bluetoothLocation = ValueNotifier(null);

