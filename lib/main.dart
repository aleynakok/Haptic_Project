import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'ai_service.dart';
import 'package:google_fonts/google_fonts.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF010409),
      ),
      home: const WelcomePage(),
    );
  }
}

const Color kCyan   = Color(0xFF00FBFF);
const Color kBlue   = Color(0xFF007BFF);
const Color kDeepBg = Color(0xFF010409);

class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, required this.gradient, this.style});
  final String text;
  final TextStyle? style;
  final Gradient gradient;
  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) =>
          gradient.createShader(Rect.fromLTWH(0, 0, bounds.width, bounds.height)),
      child: Text(text, style: style),
    );
  }
}

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBg,
      body: Stack(
        children: [
          _techCoreVisual(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.waves_rounded, size: 80, color: kCyan),
                const SizedBox(height: 50),
                GradientText(
                  "HAPTIC\nPROJECT",
                  gradient: const LinearGradient(colors: [Colors.white, kCyan]),
                  style: GoogleFonts.orbitron(
                    fontSize: 42, fontWeight: FontWeight.w900,
                    height: 1.3, letterSpacing: 12,
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  "AI-DRIVEN SURFACE SIMULATION",
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    color: kCyan.withValues(alpha: 0.8),
                    letterSpacing: 6,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 120),
                _neonButton(context,
                  text: "BOOT SYSTEM",
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const HapticControlPage())),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class HapticControlPage extends StatefulWidget {
  const HapticControlPage({super.key});
  @override
  State<HapticControlPage> createState() => _HapticControlPageState();
}

class _HapticControlPageState extends State<HapticControlPage> {
  BluetoothDevice?         targetDevice;
  BluetoothCharacteristic? targetCharacteristic;
  bool   isConnected     = false;
  bool   isScanning      = false;
  String predictedFabric = "";
  bool   isLoading       = false;

  StreamSubscription? _scanSub;
  StreamSubscription? _isScanSub;

  final TextEditingController _urlController = TextEditingController();
  final AIService _aiService = AIService();

  final String serviceUuid = "4fafc201-1fb5-459e-8fcc-c5c9c331914b";
  final String charUuid    = "beb5483e-36e1-4688-b7f5-ea07361b26a8";

  final Map<String, String> fabricCommands = {
    "ipek": "1",  "silk": "1",
    "pamuk": "2", "cotton": "2",
    "denim": "3", "kot": "3",
    "yün": "4",   "wool": "4",
    "keten": "5", "sentetik": "6",
  };

  @override
  void dispose() {
    _scanSub?.cancel();
    _isScanSub?.cancel();
    _urlController.dispose();
    super.dispose();
  }

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
    if (isScanning) return;

    await _scanSub?.cancel();
    await _isScanSub?.cancel();
    _scanSub   = null;
    _isScanSub = null;

    setState(() { isScanning = true; });

    await FlutterBluePlus.startScan(timeout: const Duration(seconds: 10));

    _scanSub = FlutterBluePlus.scanResults.listen((results) async {
      for (final r in results) {
        final name = r.device.platformName.isNotEmpty
            ? r.device.platformName
            : r.advertisementData.advName;

        if (name == "Haptic_Fabric_ESP32") {
          await FlutterBluePlus.stopScan();
          if (mounted) setState(() { targetDevice = r.device; });
          await connectToDevice(r.device);
          break;
        }
      }
    });

    _isScanSub = FlutterBluePlus.isScanning.listen((scanning) {
      if (!scanning && mounted && !isConnected) {
        setState(() => isScanning = false);
      }
    });
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    try {
      await device.connect();

      final services = await device.discoverServices();

      for (final service in services) {
        if (service.uuid.toString().toLowerCase() == serviceUuid) {
          for (final char in service.characteristics) {
            if (char.uuid.toString().toLowerCase() == charUuid) {
              if (mounted) {
                setState(() {
                  targetCharacteristic = char;
                  isConnected = true;
                  isScanning  = false;
                });
              }
              _showSnackBar("SYSTEM SYNCHRONIZED", isError: false);
              return;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Connection Error: $e");
      if (mounted) setState(() { isScanning = false; });
      _showSnackBar("CONNECTION FAILED");
    }
  }

  void sendCommand(String label, String cmd) async {
    if (targetCharacteristic != null) {
      await targetCharacteristic!.write(cmd.codeUnits);
      setState(() { predictedFabric = label; });
    }
  }

  void _analyze() async {
    if (_urlController.text.trim().isEmpty) return;
    setState(() { isLoading = true; predictedFabric = ""; });

    try {
      final result     = await _aiService.predictFabric(_urlController.text.trim());
      final normalized = result.toLowerCase().trim();
      final cmd        = fabricCommands[normalized] ?? "1";

      if (mounted) setState(() => isLoading = false);

      if (isConnected) {
        sendCommand(normalized, cmd);
      } else {
        if (mounted) setState(() => predictedFabric = normalized);
        _showSnackBar("PLEASE CONNECT DEVICE");
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
      _showSnackBar("ANALYSIS ERROR");
    }
  }

  void _showSnackBar(String msg, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold)),
      backgroundColor: isError ? Colors.redAccent : kCyan.withValues(alpha: 0.8),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kDeepBg,
      body: Stack(
        children: [
          _techCoreVisual(),
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 70),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SYSTEM STATUS  •  ${isConnected ? "ONLINE" : "OFFLINE"}",
                  style: GoogleFonts.orbitron(
                    color: isConnected ? kCyan : Colors.white24,
                    letterSpacing: 4, fontSize: 13, fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 40),

                _glassBox(
                  padding: 20,
                  child: Row(
                    children: [
                      _pulsingDot(isConnected),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isConnected ? "LINK READY" : "HARDWARE LINK",
                              style: GoogleFonts.orbitron(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 16, letterSpacing: 1.5),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isConnected
                                  ? "ESP32 SYNCHRONIZED"
                                  : (isScanning ? "SCANNING..." : "TAP TO INITIALIZE SCAN"),
                              style: GoogleFonts.rajdhani(
                                  color: Colors.white54, fontSize: 11,
                                  fontWeight: FontWeight.bold, letterSpacing: 1.5),
                            ),
                          ],
                        ),
                      ),
                      if (isScanning)
                        const SizedBox(
                          width: 28, height: 28,
                          child: CircularProgressIndicator(strokeWidth: 2, color: kCyan),
                        )
                      else
                        IconButton(
                          onPressed: isConnected ? null : requestPermissions,
                          icon: Icon(
                            isConnected
                                ? Icons.bluetooth_connected
                                : Icons.bluetooth_searching,
                            color: isConnected ? kCyan : Colors.white54,
                            size: 32,
                          ),
                        ),
                    ],
                  ),
                ),

                const SizedBox(height: 50),

                _glassBox(
                  padding: 5,
                  child: TextField(
                    controller: _urlController,
                    style: GoogleFonts.rajdhani(
                      fontSize: 18, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 2.0,
                    ),
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(vertical: 25),
                      hintText: "PASTE SOURCE LINK...",
                      hintStyle: GoogleFonts.rajdhani(
                          color: Colors.white38,
                          fontWeight: FontWeight.bold, letterSpacing: 2),
                      prefixIcon: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Icon(Icons.link, color: kCyan, size: 30),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                _neonButton(context,
                  text: isLoading ? "PROCESSING..." : "PROCESS TEXTURE",
                  onTap: isLoading ? null : _analyze,
                ),

                const SizedBox(height: 60),

                if (predictedFabric.isNotEmpty) ...[
                  Center(
                    child: Text("HAPTIC PROFILE DETECTED",
                        style: GoogleFonts.orbitron(
                            color: kCyan, letterSpacing: 5,
                            fontSize: 14, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 30),
                  _resultDisplay(predictedFabric),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultDisplay(String fabric) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 35),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: kCyan.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(_getIcon(fabric), size: 60, color: kCyan),
          const SizedBox(height: 20),
          GradientText(
            fabric.toUpperCase(),
            gradient: const LinearGradient(colors: [Colors.white, kCyan]),
            style: GoogleFonts.orbitron(
                fontSize: 48, fontWeight: FontWeight.w900, letterSpacing: -2),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String f) {
    if (f.contains("pamuk") || f.contains("cotton")) return Icons.cloud_outlined;
    if (f.contains("ipek")  || f.contains("silk"))   return Icons.auto_awesome_outlined;
    if (f.contains("denim") || f.contains("kot"))    return Icons.grid_view_outlined;
    if (f.contains("yün")   || f.contains("wool"))   return Icons.waves_outlined;
    return Icons.texture;
  }
}

Widget _techCoreVisual() {
  return Positioned(
    top: -100, right: -100,
    child: Container(
      width: 300, height: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kBlue.withValues(alpha: 0.1),
      ),
    ),
  );
}

Widget _neonButton(BuildContext context,
    {required String text, VoidCallback? onTap}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: onTap != null
            ? const LinearGradient(colors: [Colors.white, kCyan])
            : const LinearGradient(colors: [Colors.white24, Colors.white12]),
      ),
      child: Center(
        child: Text(text,
            style: GoogleFonts.orbitron(
                fontWeight: FontWeight.w900, letterSpacing: 3,
                fontSize: 14, color: kDeepBg)),
      ),
    ),
  );
}

Widget _glassBox({required Widget child, double padding = 20}) {
  return Container(
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(25),
    ),
    child: child,
  );
}

Widget _pulsingDot(bool active) {
  return Container(
    width: 16, height: 16,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: active ? kCyan : Colors.white24,
    ),
  );
}
