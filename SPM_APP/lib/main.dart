import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:spm_app/ConnectScreen.dart';
import 'package:flutter_reactive_ble/flutter_reactive_ble.dart';
void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: SmartPowerApp(),
  ));
}

class SmartPowerApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.yellow,
      ),
      home: ConnectScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}




class PowerDashboard extends StatefulWidget {
  final String deviceId;
  final FlutterReactiveBle flutterReactiveBle;
  final Uuid serviceUuid;
  final Uuid characteristicUuid;

  const PowerDashboard({
    Key? key,
    required this.deviceId,
    required this.flutterReactiveBle,
    required this.serviceUuid,
    required this.characteristicUuid,
  }) : super(key: key);

  @override
  _PowerDashboardState createState() => _PowerDashboardState();
}

class _PowerDashboardState extends State<PowerDashboard> {
  double voltage = 4.8;
  double current = 0.65;
  double power = 0.0;
  String loadSource = "Main";
  bool relayOn = true;
  bool autoMode = false;
  String systemStatus = "Normal";
  String lastUpdated = "-";
  String appVersion = "v1.0.2";
  String integrityGrade = "Good";
  List<FlSpot> voltageHistory = [];
  List<FlSpot> currentHistory = [];
  int time = 0;
  List<String> messageLog = [];

  StreamSubscription<List<int>>? _dataSubscription;
  StreamSubscription<ConnectionStateUpdate>? _connectionSubscription;
  bool isConnected = true;

  @override
  void initState() {
    super.initState();
    _setupBleConnection();
    Timer.periodic(Duration(seconds: 1), (_) => updateData());
  }

  void _setupBleConnection() {
    // Monitor connection state
    _connectionSubscription = widget.flutterReactiveBle.connectToDevice(
      id: widget.deviceId,
    ).listen((connectionState) {
      print("Connection state: ${connectionState.connectionState}");
      setState(() {
        isConnected = connectionState.connectionState == DeviceConnectionState.connected;
      });

      if (!isConnected) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ Disconnected from ESP32")),
        );
      }
    });

    // Subscribe to notifications
    final characteristic = QualifiedCharacteristic(
      deviceId: widget.deviceId,
      serviceId: widget.serviceUuid,
      characteristicId: widget.characteristicUuid,
    );

    _dataSubscription = widget.flutterReactiveBle
        .subscribeToCharacteristic(characteristic)
        .listen((data) {
      final message = String.fromCharCodes(data);
      print("📥 Dashboard received: $message");

      // Process messages from ESP32
      processESP32Message(message);

      setState(() {
        messageLog.add(message);
        if (messageLog.length > 20) messageLog.removeAt(0);
        lastUpdated = DateTime.now().toLocal().toString().substring(0, 19);
      });
    }, onError: (error) {
      print("Subscription error: $error");
    });
  }

  void processESP32Message(String message) {
    // Process Generator status
    if (message.contains("Generator: ON")) {
      setState(() {
        relayOn = false;
        loadSource = "Generator";
      });
    } else if (message.contains("Generator: OFF")) {
      setState(() {
        relayOn = true;
        loadSource = "Main";
      });
    }

    // Process Buzzer/LED status for system status
    if (message.contains("Buzzer: ON") || message.contains("LED: ON")) {
      setState(() {
        systemStatus = "Critical";
        integrityGrade = "Poor";
      });
    }

    // Process overload messages
    if (message.contains("Overload!")) {
      setState(() {
        systemStatus = "Critical";
        integrityGrade = "Poor";
        // Simulate voltage drop during overload
        voltage = 4.2;
      });
    }
  }

  void updateData() {
    if (!mounted) return;

    setState(() {
      // Only update these values if we haven't received specific data from ESP32
      if (systemStatus != "Critical") {
        voltage = (4.5 + (0.5 * (0.5 - (DateTime.now().second % 10) / 10)));
        systemStatus = voltage < 4.3 ? "Critical" : (voltage < 4.6 ? "Warning" : "Normal");
        integrityGrade = voltage < 4.3 ? "Poor" : (voltage < 4.6 ? "Moderate" : "Good");
      }

      current = 0.6 + (0.05 * (DateTime.now().second % 5));
      power = voltage * current;

      voltageHistory.add(FlSpot(time.toDouble(), voltage));
      currentHistory.add(FlSpot(time.toDouble(), current));
      if (voltageHistory.length > 20) voltageHistory.removeAt(0);
      if (currentHistory.length > 20) currentHistory.removeAt(0);
      time++;
    });
  }

  void toggleRelay() {
    // In a real implementation, we would send a command to the ESP32
    // to toggle the relay. For now, we'll just update the UI
    setState(() {
      relayOn = !relayOn;
      loadSource = relayOn ? "Main" : "Generator";
    });

    // This is where you would send a command to ESP32
    // (would require a write characteristic, which is not in your ESP32 code)
  }

  void toggleAutoMode(bool value) {
    setState(() {
      autoMode = value;
    });
  }

  @override
  void dispose() {
    _dataSubscription?.cancel();
    _connectionSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Power Dashboard - Client',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.yellow,
        actions: [
          // Connection status indicator
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              isConnected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
              color: isConnected ? Colors.green : Colors.red,
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("System Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: systemStatus == "Normal"
                                ? Colors.green
                                : (systemStatus == "Warning" ? Colors.orange : Colors.red),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            systemStatus,
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    dataRow("Voltage", "${voltage.toStringAsFixed(2)} V"),
                    dataRow("Current", "${current.toStringAsFixed(2)} A"),
                    dataRow("Power", "${power.toStringAsFixed(2)} W"),
                    dataRow("Load Source", loadSource),
                    dataRow("Integrity Grade", integrityGrade),
                    dataRow("Last Updated", lastUpdated),
                    dataRow("App Version", appVersion),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Controls", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Relay Switch", style: TextStyle(fontSize: 16)),
                        Switch(
                          value: relayOn,
                          onChanged: (_) => toggleRelay(),
                          activeColor: Colors.yellow,
                        ),
                      ],
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Auto Mode", style: TextStyle(fontSize: 16)),
                        Switch(
                          value: autoMode,
                          onChanged: toggleAutoMode,
                          activeColor: Colors.red,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Voltage Chart", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Container(
                      height: 200,
                      child: voltageChart(),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Current Chart", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Container(
                      height: 200,
                      child: currentChart(),
                    ),
                  ],
                ),
              ),
            ),

            SizedBox(height: 20),

            // Message log from ESP32
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("ESP32 Data Log", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        Text("${messageLog.length} messages", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    SizedBox(height: 10),
                    Container(
                      height: 150,
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: ListView.builder(
                        itemCount: messageLog.length,
                        itemBuilder: (context, index) {
                          return Text(
                            messageLog[index],
                            style: TextStyle(
                              color: messageLog[index].contains("Overload")
                                  ? Colors.red
                                  : Colors.green,
                              fontFamily: 'monospace',
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget dataRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16)),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget voltageChart() {
    // Check if the data list is empty before rendering
    if (voltageHistory.isEmpty) {
      return Center(child: Text('No voltage data available'));
    }

    return LineChart(
      LineChartData(
        minX: time > 20 ? (time - 20).toDouble() : 0,
        maxX: time > 0 ? time.toDouble() : 20,
        minY: 4.0,
        maxY: 5.2,
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: voltageHistory,
            isCurved: true,
            color: Colors.greenAccent,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: Colors.greenAccent.withOpacity(0.3),
            ),
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }

  Widget currentChart() {
    // Check if the data list is empty before rendering
    if (currentHistory.isEmpty) {
      return Center(child: Text('No current data available'));
    }

    return LineChart(
      LineChartData(
        minX: time > 20 ? (time - 20).toDouble() : 0,
        maxX: time > 0 ? time.toDouble() : 20,
        minY: 0.5,
        maxY: 1.2,
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
        ),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: currentHistory,
            isCurved: true,
            color: Colors.blueAccent,
            barWidth: 3,
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blueAccent.withOpacity(0.3),
            ),
            dotData: FlDotData(show: false),
          ),
        ],
      ),
    );
  }
}