import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  runApp(const SimpleSmartHomeApp());
}

class SimpleSmartHomeApp extends StatelessWidget {
  const SimpleSmartHomeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Home',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SmartHomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SmartHomeScreen extends StatefulWidget {
  const SmartHomeScreen({super.key});

  @override
  State<SmartHomeScreen> createState() => _SmartHomeScreenState();
}

class _SmartHomeScreenState extends State<SmartHomeScreen> {
  // State variables
  bool lightOn = false;
  bool fanOn = false;
  double temperature = 25.0;
  double humidity = 60.0;
  int gasLevel = 50;
  bool isOnline = false;
  bool isLoading = false;
  String? errorMessage;

  final String baseUrl = 'http://35.247.182.78:8080';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  // Load data from API
  Future<void> _loadData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          lightOn = data['relay1'] ?? false;
          fanOn = data['relay2'] ?? false;
          temperature = (data['temperature'] ?? 25.0).toDouble();
          humidity = (data['humidity'] ?? 60.0).toDouble();
          gasLevel = data['gasLevel'] ?? 50;
          isOnline = data['online'] ?? false;
          isLoading = false;
        });
      } else {
        throw Exception('Server error: ${response.statusCode}');
      }
    } catch (e) {
      setState(() {
        errorMessage = 'ไม่สามารถเชื่อมต่อได้: $e';
        isLoading = false;
        isOnline = false;
      });
    }
  }

  // Control light
  Future<void> _controlLight() async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/control'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'command': lightOn ? 'LIGHT_OFF' : 'LIGHT_ON',
          'device': 'relay1',
          'state': !lightOn,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          lightOn = !lightOn;
          isLoading = false;
        });
        _showMessage(lightOn ? 'เปิดไฟแล้ว' : 'ปิดไฟแล้ว');
      } else {
        throw Exception('Control failed');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showMessage('ไม่สามารถควบคุมไฟได้', isError: true);
    }
  }

  // Control fan
  Future<void> _controlFan() async {
    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/control'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'command': fanOn ? 'FAN_OFF' : 'FAN_ON',
          'device': 'relay2',
          'state': !fanOn,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        setState(() {
          fanOn = !fanOn;
          isLoading = false;
        });
        _showMessage(fanOn ? 'เปิดพัดลมแล้ว' : 'ปิดพัดลมแล้ว');
      } else {
        throw Exception('Control failed');
      }
    } catch (e) {
      setState(() => isLoading = false);
      _showMessage('ไม่สามารถควบคุมพัดลมได้', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Home'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            onPressed: _loadData,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Connection Status
              Card(
                child: ListTile(
                  leading: Icon(
                    isOnline ? Icons.wifi : Icons.wifi_off,
                    color: isOnline ? Colors.green : Colors.red,
                  ),
                  title: Text(isOnline ? 'เชื่อมต่อแล้ว' : 'ไม่เชื่อมต่อ'),
                  subtitle: errorMessage != null 
                      ? Text(errorMessage!, style: const TextStyle(color: Colors.red))
                      : null,
                ),
              ),

              const SizedBox(height: 16),

              // Device Controls
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ควบคุมอุปกรณ์',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      // Light Control
                      ListTile(
                        leading: Icon(
                          Icons.lightbulb,
                          color: lightOn ? Colors.amber : Colors.grey,
                        ),
                        title: const Text('ไฟห้อง'),
                        subtitle: Text(lightOn ? 'เปิด' : 'ปิด'),
                        trailing: isLoading 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Switch(
                                value: lightOn,
                                onChanged: isOnline ? (_) => _controlLight() : null,
                              ),
                      ),
                      
                      const Divider(),
                      
                      // Fan Control
                      ListTile(
                        leading: Icon(
                          Icons.air,
                          color: fanOn ? Colors.blue : Colors.grey,
                        ),
                        title: const Text('พัดลม'),
                        subtitle: Text(fanOn ? 'เปิด' : 'ปิด'),
                        trailing: isLoading 
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Switch(
                                value: fanOn,
                                onChanged: isOnline ? (_) => _controlFan() : null,
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Sensor Data
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ข้อมูล Sensors',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        children: [
                          Expanded(
                            child: _buildSensorCard(
                              Icons.thermostat,
                              'อุณหภูมิ',
                              '${temperature.toStringAsFixed(1)}°C',
                              Colors.red,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSensorCard(
                              Icons.water_drop,
                              'ความชื้น',
                              '${humidity.toStringAsFixed(1)}%',
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildSensorCard(
                              Icons.sensors,
                              'ก๊าซ',
                              '$gasLevel ppm',
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 100), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorCard(IconData icon, String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
