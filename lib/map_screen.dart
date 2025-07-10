// lib/screens/map_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  LatLng? androidLocation;
  LatLng? bluetoothLocation;

  @override
  void initState() {
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
      setState(() {
        androidLocation = LatLng(position.latitude, position.longitude);
      });
    });

    // Simulated GNSS external device update
    Future.delayed(const Duration(seconds: 2), () {
      updateBluetoothLocation(const LatLng(13.7570, 100.5025));
    });
  }

  void updateBluetoothLocation(LatLng loc) {
    setState(() {
      bluetoothLocation = loc;
    });
  }

  @override
  Widget build(BuildContext context) {
    final center = androidLocation ?? const LatLng(13.7563, 100.5018);

    return FlutterMap(
      options: MapOptions(
        initialCenter: center,
        initialZoom: 15,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        ),
        MarkerLayer(
          markers: [
            if (androidLocation != null)
              Marker(
                point: androidLocation!,
                width: 40,
                height: 40,
                child: const Icon(Icons.location_pin, color: Colors.green),
              ),
            if (bluetoothLocation != null)
              Marker(
                point: bluetoothLocation!,
                width: 40,
                height: 40,
                child: const Icon(Icons.bluetooth, color: Colors.blue),
              ),
          ],
        ),
      ],
    );
  }
}
