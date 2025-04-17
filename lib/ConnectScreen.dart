import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({Key? key}) : super(key: key);

  @override
  _ConnectScreenState createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  FlutterBluePlus flutterBlue = FlutterBluePlus();
  late BluetoothDevice? _connectedDevice;
  late List<BluetoothDevice> _devicesList;

  @override
  void initState() {
    super.initState();
    _devicesList = [];
    _startScan();
  }

  // Start scanning for Bluetooth devices
  void _startScan() {
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));
    FlutterBluePlus.scanResults.listen((results) {
      setState(() {
        _devicesList = results
            .where((result) => result.device.name.contains('SMP_ESP32'))
            .map((result) => result.device)
            .toList();
      });
    });
  }

  // Connect to the selected device
  Future<void> _connectToDevice(BluetoothDevice device) async {
    await device.connect();
    setState(() {
      _connectedDevice = device;
    });
    Navigator.pushReplacementNamed(context, '/dashboard');
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect to SmartPower',style: TextStyle(color: Colors.white,fontWeight: FontWeight.bold),) ,backgroundColor: Colors.amber,),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Scanning for devices...'),
            const SizedBox(height: 20),
            _devicesList.isEmpty
                ? const CircularProgressIndicator()
                : Expanded(
              child: ListView.builder(
                itemCount: _devicesList.length,
                itemBuilder: (context, index) {
                  final device = _devicesList[index];
                  return ListTile(
                    title: Text(device.name),
                    subtitle: Text(device.id.toString()),
                    onTap: () => _connectToDevice(device),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
