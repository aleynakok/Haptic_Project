import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

// MyApp ismini burada güncelledik
void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF0F1214),
        primaryColor: const Color(0xFF2962FF),
      ),
      home: const WelcomePage(),
    );
  }
}

// --- SHARED UI CONSTANTS ---
const Color kBackgroundColor = Color(0xFF0F1214);
const Color kCardColor = Color(0xFF1C2025);
const Color kAccentColor = Color(0xFF2962FF);

// --- 1. WELCOME PAGE ---
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: kCardColor,
                shape: BoxShape.circle,
                border: Border.all(
                  // withOpacity uyarısını gidermek için withValues kullanıldı
                  color: kAccentColor.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: const Icon(Icons.waves_rounded, size: 60, color: kAccentColor),
            ),
            const SizedBox(height: 30),
            const Text(
                "HAPTIC PROJECT",
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 3)
            ),
            const SizedBox(height: 10),
            const Text(
                "Welcome to the Digital Fabric Experience",
                style: TextStyle(fontSize: 14, color: Colors.white38)
            ),
            const SizedBox(height: 80),
            SizedBox(
              width: 200,
              height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: kAccentColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HapticControlPage())
                ),
                child: const Text(
                    "START",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 2. MAIN CONTROL PAGE ---
class HapticControlPage extends StatefulWidget {
  const HapticControlPage({super.key});

  @override
  State<HapticControlPage> createState() => _HapticControlPageState();
}

class _HapticControlPageState extends State<HapticControlPage> {
  BluetoothDevice? targetDevice;
  BluetoothCharacteristic? targetCharacteristic;
  bool isConnected = false;
  bool isScanning = false;
  String selectedFabric = "";

  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String charUuid = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  // --- CROSS PLATFORM PERMISSION CHECK ---
  Future<void> requestPermissions() async {
    if (Platform.isAndroid) {
      await [
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        Permission.location,
      ].request();
    }
    startScanAndConnect();
  }

  void startScanAndConnect() async {
    setState(() { isScanning = true; });

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    FlutterBluePlus.scanResults.listen((results) async {
      for (ScanResult r in results) {
        // localName uyarısını gidermek için advName kullanıldı
        String name = r.device.platformName.isEmpty
            ? r.advertisementData.advName
            : r.device.platformName;

        if (name == "Haptic_Fabric_ESP32") {
          FlutterBluePlus.stopScan();
          setState(() { targetDevice = r.device; });
          await connectToDevice(r.device);
          break;
        }
      }
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();
      List<BluetoothService> services = await device.discoverServices();
      for (var service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid) {
          for (var char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() == charUuid) {
              setState(() {
                targetCharacteristic = char;
                isConnected = true;
                isScanning = false;
              });
            }
          }
        }
      }
    } catch (e) {
      setState(() { isScanning = false; });
      debugPrint("Connection Error: $e");
    }
  }

  void sendCommand(String label, String cmd) async {
    if (targetCharacteristic != null) {
      await targetCharacteristic!.write(cmd.codeUnits);
      setState(() { selectedFabric = label; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("CONTROL PANEL", style: TextStyle(letterSpacing: 2, fontSize: 16)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 25),
        child: Column(
          children: [
            _buildConnectionPanel(),
            const SizedBox(height: 40),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text("Fabric Selection", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 18,
                mainAxisSpacing: 18,
                children: [
                  _fabricCard("SILK", "1", Icons.auto_awesome_outlined),
                  _fabricCard("COTTON", "2", Icons.blur_on_rounded),
                  _fabricCard("DENIM", "3", Icons.grid_view_rounded),
                  _fabricCard("WOOL", "4", Icons.grain_rounded),
                ],
              ),
            ),
            if (selectedFabric.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 30),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 25),
                decoration: BoxDecoration(
                    color: kAccentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30)
                ),
                child: Text(
                    "Active Texture: $selectedFabric",
                    style: const TextStyle(color: kAccentColor, fontWeight: FontWeight.bold)
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionPanel() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: kCardColor, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Icon(
              isConnected ? Icons.check_circle : Icons.error_outline,
              color: isConnected ? Colors.greenAccent : Colors.orangeAccent
          ),
          const SizedBox(width: 15),
          Expanded(
              child: Text(
                  isConnected ? "Connected" : (isScanning ? "Searching..." : "Waiting"),
                  style: const TextStyle(fontSize: 15)
              )
          ),
          if (!isConnected)
            isScanning
                ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: kAccentColor)
            )
                : TextButton(
                onPressed: requestPermissions,
                child: const Text("CONNECT", style: TextStyle(color: kAccentColor, fontWeight: FontWeight.bold))
            ),
        ],
      ),
    );
  }

  Widget _fabricCard(String label, String cmd, IconData icon) {
    bool isCurrent = selectedFabric == label;
    return GestureDetector(
      onTap: isConnected ? () => sendCommand(label, cmd) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: isCurrent ? kAccentColor : kCardColor,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
              color: isCurrent ? kAccentColor : Colors.white.withValues(alpha: 0.05)
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 45, color: isCurrent ? Colors.white : Colors.white38),
            const SizedBox(height: 12),
            Text(
                label,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCurrent ? Colors.white : Colors.white70
                )
            ),
          ],
        ),
      ),
    );
  }
}