import 'package:flutter/material.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BatRayApp());
}

class BatRayApp extends StatelessWidget {
  const BatRayApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BatRay',
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFF40B4DC),
          secondary: const Color(0xFFB4C8DC),
        ),
      ),
      home: const BatRayHome(),
    );
  }
}

class BatRayHome extends StatelessWidget {
  const BatRayHome({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/icons/ic_launcher_batray.png', width: 128, height: 128),
            const SizedBox(height: 24),
            const Text('BatRay', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Hello World', style: TextStyle(fontSize: 16, color: Colors.grey[400])),
          ],
        ),
      ),
    );
  }
}
