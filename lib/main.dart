import 'dart:async';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

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
      title: 'Smart Power Dashboard',
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.green,
      ),
      home: PowerDashboard(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class PowerDashboard extends StatefulWidget {
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

  @override
  void initState() {
    super.initState();
    Timer.periodic(Duration(milliseconds: 1000), (_) => updateData());
  }

  void updateData() {
    setState(() {
      voltage = (4.5 + (0.5 * (0.5 - (DateTime.now().second % 10) / 10)));
      current = 0.6 + (0.05 * (DateTime.now().second % 5));
      power = voltage * current;
      voltageHistory.add(FlSpot(time.toDouble(), voltage));
      currentHistory.add(FlSpot(time.toDouble(), current));
      if (voltageHistory.length > 20) voltageHistory.removeAt(0);
      if (currentHistory.length > 20) currentHistory.removeAt(0);
      time++;

      lastUpdated = DateTime.now().toLocal().toString().substring(0, 19);
      systemStatus = voltage < 4.3 ? "Critical" : (voltage < 4.6 ? "Warning" : "Normal");
      integrityGrade = voltage < 4.3 ? "Poor" : (voltage < 4.6 ? "Moderate" : "Good");

      if (autoMode && voltage < 4.4) {
        relayOn = false;
        loadSource = "Generator";
      } else if (autoMode) {
        relayOn = true;
        loadSource = "Main";
      }
    });
  }

  void toggleRelay() {
    setState(() {
      relayOn = !relayOn;
      loadSource = relayOn ? "Main" : "Generator";
    });
  }

  void toggleAutoMode(bool value) {
    setState(() {
      autoMode = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Smart Power Dashboard - Client'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [

            dataRow("Voltage", "${voltage.toStringAsFixed(2)} V"),
            dataRow("Current", "${current.toStringAsFixed(2)} A"),
            dataRow("Power", "${power.toStringAsFixed(2)} W"),
            dataRow("Load Source", loadSource),
            dataRow("System Status", systemStatus),
            dataRow("Integrity Grade", integrityGrade),
            dataRow("Last Updated", lastUpdated),
            dataRow("App Version", appVersion),
            SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Relay Switch", style: TextStyle(fontSize: 18)),
                Switch(
                  value: relayOn,
                  onChanged: (_) => toggleRelay(),
                  activeColor: Colors.greenAccent,
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Auto Mode", style: TextStyle(fontSize: 18)),
                Switch(
                  value: autoMode,
                  onChanged: toggleAutoMode,
                  activeColor: Colors.orangeAccent,
                ),
              ],
            ),
            SizedBox(height: 20),
            Text("Voltage Chart"),
            Expanded(child: voltageChart()),
            SizedBox(height: 10),
            Text("Current Chart"),
            Expanded(child: currentChart()),
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
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 20,
        minY: 4.0,
        maxY: 5.2,
        titlesData: FlTitlesData(show: true),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: voltageHistory,
            isCurved: true,
            color: Colors.greenAccent,
            barWidth: 3,
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }

  Widget currentChart() {
    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 20,
        minY: 0.5,
        maxY: 1.2,
        titlesData: FlTitlesData(show: true),
        borderData: FlBorderData(show: true),
        lineBarsData: [
          LineChartBarData(
            spots: currentHistory,
            isCurved: true,
            color: Colors.blueAccent,
            barWidth: 3,
            belowBarData: BarAreaData(show: false),
          ),
        ],
      ),
    );
  }
}