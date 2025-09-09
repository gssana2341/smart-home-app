import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device_status.dart';
import '../models/sensor_data.dart';
import '../models/voice_command.dart';
import '../services/api_service.dart';
import '../services/mqtt_service.dart';
import '../services/storage_service.dart';
import '../services/voice_command_service.dart';
import '../services/tts_service.dart';
import '../widgets/device_card.dart';
import '../widgets/sensor_card.dart';
import '../widgets/control_button.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with AutomaticKeepAliveClientMixin {
  DeviceStatus? _deviceStatus;
  List<SensorData> _sensorHistory = [];
  bool _isLoading = false;
  bool _isRefreshing = false;
  String? _lastError;
  
  // Auto-refresh
  Timer? _refreshTimer;
  Timer? _deviceStatusTimer;
  Timer? _sensorDataTimer;
  bool _autoRefreshEnabled = true;
  DateTime? _lastUpdateTime;
  DateTime? _lastDeviceStatusUpdate;
  DateTime? _lastSensorDataUpdate;
  
  // Voice Command
  bool _isVoiceListening = false;
  String? _lastTranscription;
  VoiceCommand? _lastVoiceCommand;
  
  // TTS Status
  bool _isTtsAvailable = false;
  bool _isTtsSpeaking = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupListeners();
    _startAutoRefresh();
    _startRealTimeUpdates();
    _setupVoiceCommandListeners();
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    _deviceStatusTimer?.cancel();
    _sensorDataTimer?.cancel();
    super.dispose();
  }

  void _initializeData() async {
    setState(() => _isLoading = true);
    
    // Load cached data first
    await _loadCachedData();
    
    // ไม่ต้องเรียก _refreshData เพราะ real-time จะอัพเดทเอง
    // await _refreshData();
    
    setState(() => _isLoading = false);
  }

  void _startAutoRefresh() {
    if (_autoRefreshEnabled) {
      _refreshTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
        if (mounted && !_isRefreshing) {
          _refreshData();
        }
      });
    }
  }
  
  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _deviceStatusTimer?.cancel();
    _sensorDataTimer?.cancel();
    _refreshTimer = null;
    _deviceStatusTimer = null;
    _sensorDataTimer = null;
  }
  
  void _toggleAutoRefresh() {
    setState(() {
      _autoRefreshEnabled = !_autoRefreshEnabled;
    });
    
    if (_autoRefreshEnabled) {
      _startAutoRefresh();
      _startRealTimeUpdates();
    } else {
      _stopAutoRefresh();
    }
  }

  void _startRealTimeUpdates() {
    // Device status updates - ทุก 5 วินาที
    _deviceStatusTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (mounted && !_isRefreshing && _autoRefreshEnabled) {
          try {
            final apiService = Provider.of<ApiService>(context, listen: false);
            if (apiService.isConnected) {
              final status = await apiService.getDeviceStatus();
              if (status != null && mounted) {
                setState(() {
                  _deviceStatus = status;
                  _lastUpdateTime = DateTime.now();
                _lastDeviceStatusUpdate = DateTime.now();
                });
                _saveDeviceStatus(status);
              }
            }
          } catch (e) {
            // Silent fail for real-time updates
          }
        }
      });

    // Sensor data updates - ทุก 8 วินาที
    _sensorDataTimer = Timer.periodic(const Duration(seconds: 8), (timer) async {
      if (mounted && !_isRefreshing && _autoRefreshEnabled) {
          try {
            final apiService = Provider.of<ApiService>(context, listen: false);
            if (apiService.isConnected) {
              final sensors = await apiService.getSensorData(
                limit: AppConstants.defaultChartDataPoints,
              );
              if (sensors.isNotEmpty && mounted) {
              setState(() {
                _sensorHistory = sensors;
                _lastSensorDataUpdate = DateTime.now();
              });
                for (final sensor in sensors) {
                  await _saveSensorData(sensor);
                }
              }
            }
          } catch (e) {
            // Silent fail for real-time updates
          }
        }
      });
  }

  void _setupListeners() {
    try {
      // MQTT listeners
      final mqttService = Provider.of<MqttService>(context, listen: false);
      
      mqttService.deviceStatusStream.listen((status) {
        if (mounted) {
          setState(() {
            _deviceStatus = status;
            _lastUpdateTime = DateTime.now();
          });
          _saveDeviceStatus(status);
        }
      }, onError: (error) {
        print('Device status stream error: $error');
      });

      mqttService.sensorDataStream.listen((sensorData) {
        if (mounted) {
          setState(() {
            _sensorHistory.add(sensorData);
            if (_sensorHistory.length > AppConstants.maxChartDataPoints) {
              _sensorHistory.removeAt(0);
            }
            _lastUpdateTime = DateTime.now();
          });
          _saveSensorData(sensorData);
        }
      }, onError: (error) {
        print('Sensor data stream error: $error');
      });

      // Real-time updates จะถูกจัดการใน _startRealTimeUpdates()
    } catch (e) {
      print('Setup listeners error: $e');
    }
  }

  void _setupVoiceCommandListeners() {
    // ฟังสถานะการฟังจาก Provider
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final voiceCommandService = Provider.of<VoiceCommandService>(context, listen: false);
      
      // เริ่มต้น TTS Service
      try {
        final ttsService = Provider.of<TtsService>(context, listen: false);
        final initialized = await ttsService.initialize();
        if (mounted) {
          setState(() {
            _isTtsAvailable = initialized;
          });
        }
        print('TTS Service initialized: $initialized');
        
        // ฟังสถานะการพูดของ TTS ผ่าน addListener
        ttsService.addListener(() {
          if (mounted) {
            setState(() {
              _isTtsSpeaking = ttsService.isSpeaking;
            });
          }
        });
      } catch (e) {
        print('TTS service not available: $e');
      }
      
      // ฟังสถานะการฟัง
      voiceCommandService.listeningStream.listen((isListening) {
        if (mounted) {
          setState(() {
            _isVoiceListening = isListening;
          });
        }
      });

      // ฟังการแปลงเสียงเป็นข้อความ
      voiceCommandService.transcriptionStream.listen((transcription) {
        if (mounted) {
          setState(() {
            _lastTranscription = transcription;
          });
        }
      });

      // ฟังผลลัพธ์คำสั่งเสียง
      voiceCommandService.commandResultStream.listen((command) async {
        if (mounted) {
          setState(() {
            _lastVoiceCommand = command;
          });
          
          // ไม่แสดงแจ้งเตือนใน Dashboard - ย้ายไปหน้า Log แล้ว
          print('Dashboard: Voice command result: "${command.result}"');
          
          // TTS จะถูกจัดการใน VoiceCommandService แล้ว ไม่ต้องทำซ้ำ
          print('Dashboard: Voice command result received: "${command.result}"');
          print('Dashboard: TTS handled by VoiceCommandService, no need to speak again');
        }
      });

      // ฟังการอัปเดตสถานะอุปกรณ์จากคำสั่งเสียง
      voiceCommandService.deviceStatusUpdateStream.listen((status) {
        if (mounted) {
          setState(() {
            _deviceStatus = status;
            _lastUpdateTime = DateTime.now();
          });
          _saveDeviceStatus(status);
          print('Dashboard: Device status updated from voice command');
        }
      });
    });
  }

  Future<void> _loadCachedData() async {
    try {
      final storageService = StorageService.instance;
      
      // Load cached device status
      final cachedStatus = storageService.getDeviceStatus();
      if (cachedStatus != null) {
        setState(() => _deviceStatus = cachedStatus);
      }
      
      // Load cached sensor history
      final cachedSensors = await storageService.getSensorData(
        limit: AppConstants.defaultChartDataPoints,
      );
      if (cachedSensors.isNotEmpty) {
        setState(() => _sensorHistory = cachedSensors);
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(context, 'ไม่สามารถโหลดข้อมูลที่เก็บไว้ได้', isError: true);
      }
    }
  }

  Future<void> _refreshData() async {
    setState(() => _isRefreshing = true);
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      // Manual refresh - ใช้เป็น backup เมื่อ real-time ไม่ทำงาน
      print('Dashboard: Manual refresh triggered');
      
      // Fetch device status
      final status = await apiService.getDeviceStatus();
      if (status != null && mounted) {
        setState(() {
          _deviceStatus = status;
          _lastError = null;
          _lastUpdateTime = DateTime.now();
        });
        await _saveDeviceStatus(status);
        print('Dashboard: Manual refresh - Device status updated');
      }
      
      // Fetch sensor history
      final sensors = await apiService.getSensorData(
        limit: AppConstants.defaultChartDataPoints,
      );
      if (sensors.isNotEmpty && mounted) {
        setState(() => _sensorHistory = sensors);
        for (final sensor in sensors) {
          await _saveSensorData(sensor);
        }
        print('Dashboard: Manual refresh - Sensor data updated');
      }
      
      // ไม่แสดงข้อความอัพเดทสำเร็จเพื่อหลีกเลี่ยงการแจ้งเตือนซ้ำ
      if (mounted) {
        print('Dashboard: Data refresh completed successfully');
      }
      
    } catch (e) {
      if (mounted) {
        setState(() => _lastError = e.toString());
        AppHelpers.showSnackBar(context, 'ไม่สามารถรีเฟรชข้อมูลได้', isError: true);
      }
    } finally {
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _saveDeviceStatus(DeviceStatus status) async {
    try {
      await StorageService.instance.saveDeviceStatus(status);
      await StorageService.instance.setLastUpdate(DateTime.now());
    } catch (e) {
      // Silent fail for storage errors
    }
  }

  Future<void> _saveSensorData(SensorData data) async {
    try {
      await StorageService.instance.saveSensorData(data);
    } catch (e) {
      // Silent fail for storage errors
    }
  }

  // ฟังก์ชันสำหรับส่ง log ไปยังหน้า Log
  void _sendLogToLogScreen(String title, String message, Color color) {
    // ส่ง log ผ่าน VoiceCommandService เพื่อให้หน้า Log รับได้
    final voiceCommandService = Provider.of<VoiceCommandService>(context, listen: false);
    voiceCommandService.addLogMessage(title, message);
  }

  // ฟังก์ชันควบคุมไฟผ่าน API
  Future<bool> _controlLightViaApi(bool turnOn) async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final success = await apiService.controlLight(turnOn);
    if (kDebugMode) print('API Light Control: $success');
    return success;
  }

  // ฟังก์ชันควบคุมไฟผ่าน MQTT
  Future<bool> _controlLightViaMqtt(bool turnOn) async {
    final mqttService = Provider.of<MqttService>(context, listen: false);
    if (mqttService.isConnected) {
      final success = await mqttService.controlLight(turnOn);
      if (kDebugMode) print('MQTT Light Control: $success');
      return success;
    }
    return false;
  }

  // ฟังก์ชันควบคุมไฟแบบอัตโนมัติ (API แล้ว MQTT)
  Future<bool> _controlLightAuto(bool turnOn) async {
    // ลอง API ก่อน
    final apiSuccess = await _controlLightViaApi(turnOn);
    if (apiSuccess) return true;
    
    // ถ้า API ไม่สำเร็จ ใช้ MQTT
    return await _controlLightViaMqtt(turnOn);
  }

  Future<void> _controlLight() async {
    if (!mounted) return;
    
    try {
      final storage = StorageService.instance;
      final controlMode = storage.getControlMode();
      
      // สร้าง default device status ถ้ายังไม่มี
      if (_deviceStatus == null) {
        _deviceStatus = DeviceStatus(
          temperature: 0.0,
          humidity: 0.0,
          gasLevel: 0,
          relay1: false,
          relay2: false,
          relay3: false,
          relay4: false,
          relay5: false,
          relay6: false,
          online: false,
          lastSeen: DateTime.now(),
        );
      }
      
      final newState = !_deviceStatus!.relay1;
      
      // ไม่แสดงข้อความแจ้งเตือนเพื่อให้หน้า Dashboard สะอาด
      print('Dashboard: Sending light control command: ${newState ? 'ON' : 'OFF'} (Mode: $controlMode)');
      
      // ใช้ตามการตั้งค่า
      bool success = false;
      switch (controlMode) {
        case 'api':
          success = await _controlLightViaApi(newState);
          break;
        case 'mqtt':
          success = await _controlLightViaMqtt(newState);
          break;
        case 'auto':
        default:
          success = await _controlLightAuto(newState);
          break;
      }
      
      if (success && mounted) {
        // ไม่แสดงข้อความแจ้งเตือน - ข้อมูลจะแสดงในหน้า Log
        print('Dashboard: Light control success: ${newState ? 'ON' : 'OFF'}');
        
        // Update local state immediately for better UX
        setState(() {
          _deviceStatus = _deviceStatus!.copyWith(relay1: newState);
        });
        
        // Log the action
        try {
          await StorageService.instance.logDeviceAction(
            deviceType: 'light',
            action: newState ? 'turn_on' : 'turn_off',
            status: 'success',
          );
        } catch (e) {
          print('Log error: $e');
        }
        
        // ส่ง log ไปยังหน้า Log
        _sendLogToLogScreen('🎛️ ควบคุมอุปกรณ์', 'ไฟ ${newState ? 'เปิด' : 'ปิด'}', newState ? Colors.green : Colors.orange);
      } else if (mounted) {
        // ไม่แสดงข้อความแจ้งเตือน - ข้อมูลจะแสดงในหน้า Log
        print('Dashboard: Light control failed');
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(context, '❌ เกิดข้อผิดพลาด: $e', isError: true);
      }
    }
  }

  Future<void> _controlFan() async {
    if (!mounted) return;
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final mqttService = Provider.of<MqttService>(context, listen: false);
      
      // สร้าง default device status ถ้ายังไม่มี
      if (_deviceStatus == null) {
        _deviceStatus = DeviceStatus(
          temperature: 0.0,
          humidity: 0.0,
          gasLevel: 0,
          relay1: false,
          relay2: false,
          relay3: false,
          relay4: false,
          relay5: false,
          relay6: false,
          online: false,
          lastSeen: DateTime.now(),
        );
      }
      
      final newState = !_deviceStatus!.relay2;
      
      print('Dashboard: Sending fan control command: ${newState ? 'ON' : 'OFF'}');
      
      // ลองส่งผ่าน MQTT ก่อน
      bool success = false;
      if (mqttService.isConnected) {
        success = await mqttService.controlFan(newState);
        if (kDebugMode) print('MQTT Fan Control: $success');
      }
      
      // ถ้า MQTT ไม่สำเร็จ ใช้ API
      if (!success) {
        success = await apiService.controlFan(newState);
        if (kDebugMode) print('API Fan Control: $success');
      }
      
      if (success && mounted) {
        print('Dashboard: Fan control success: ${newState ? 'ON' : 'OFF'}');
        
        // Update local state immediately for better UX
        setState(() {
          _deviceStatus = _deviceStatus!.copyWith(relay2: newState);
        });
        
        // Log the action
        try {
          await StorageService.instance.logDeviceAction(
            deviceType: 'fan',
            action: newState ? 'turn_on' : 'turn_off',
            status: 'success',
          );
        } catch (e) {
          print('Log error: $e');
        }
        
        // ส่ง log ไปยังหน้า Log
        _sendLogToLogScreen('🎛️ ควบคุมอุปกรณ์', 'พัดลม ${newState ? 'เปิด' : 'ปิด'}', newState ? Colors.green : Colors.orange);
      } else if (mounted) {
        print('Dashboard: Fan control failed');
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(context, '❌ เกิดข้อผิดพลาด: $e', isError: true);
      }
    }
  }

  Future<void> _controlAirConditioner() async {
    if (!mounted) return;
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final mqttService = Provider.of<MqttService>(context, listen: false);
      
      // สร้าง default device status ถ้ายังไม่มี
      if (_deviceStatus == null) {
        _deviceStatus = DeviceStatus(
          temperature: 0.0,
          humidity: 0.0,
          gasLevel: 0,
          relay1: false,
          relay2: false,
          relay3: false,
          relay4: false,
          relay5: false,
          relay6: false,
          online: false,
          lastSeen: DateTime.now(),
        );
      }
      
      final newState = !_deviceStatus!.relay3;
      
      print('Dashboard: Sending AC control command: ${newState ? 'ON' : 'OFF'}');
      
      // ลองส่งผ่าน MQTT ก่อน
      bool success = false;
      if (mqttService.isConnected) {
        success = await mqttService.controlAirConditioner(newState);
        if (kDebugMode) print('MQTT AC Control: $success');
      }
      
      // ถ้า MQTT ไม่สำเร็จ ใช้ API
      if (!success) {
        success = await apiService.controlAirConditioner(newState);
        if (kDebugMode) print('API AC Control: $success');
      }
      
      if (success && mounted) {
        print('Dashboard: AC control success: ${newState ? 'ON' : 'OFF'}');
        
        // Update local state immediately for better UX
        setState(() {
          _deviceStatus = _deviceStatus!.copyWith(relay3: newState);
        });
        
        // Log the action
        try {
          await StorageService.instance.logDeviceAction(
            deviceType: 'air_conditioner',
            action: newState ? 'turn_on' : 'turn_off',
            status: 'success',
          );
        } catch (e) {
          print('Log error: $e');
        }
        
        // ส่ง log ไปยังหน้า Log
        _sendLogToLogScreen('🎛️ ควบคุมอุปกรณ์', 'แอร์ ${newState ? 'เปิด' : 'ปิด'}', newState ? Colors.green : Colors.orange);
      } else if (mounted) {
        print('Dashboard: AC control failed');
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(context, '❌ เกิดข้อผิดพลาด: $e', isError: true);
      }
    }
  }

  Future<void> _controlWaterPump() async {
    if (!mounted) return;
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final mqttService = Provider.of<MqttService>(context, listen: false);
      
      // สร้าง default device status ถ้ายังไม่มี
      if (_deviceStatus == null) {
        _deviceStatus = DeviceStatus(
          temperature: 0.0,
          humidity: 0.0,
          gasLevel: 0,
          relay1: false,
          relay2: false,
          relay3: false,
          relay4: false,
          relay5: false,
          relay6: false,
          online: false,
          lastSeen: DateTime.now(),
        );
      }
      
      final newState = !_deviceStatus!.relay4;
      
      print('Dashboard: Sending water pump control command: ${newState ? 'ON' : 'OFF'}');
      
      // ลองส่งผ่าน MQTT ก่อน
      bool success = false;
      if (mqttService.isConnected) {
        success = await mqttService.controlWaterPump(newState);
        if (kDebugMode) print('MQTT Water Pump Control: $success');
      }
      
      // ถ้า MQTT ไม่สำเร็จ ใช้ API
      if (!success) {
        success = await apiService.controlWaterPump(newState);
        if (kDebugMode) print('API Water Pump Control: $success');
      }
      
      if (success && mounted) {
        print('Dashboard: Water pump control success: ${newState ? 'ON' : 'OFF'}');
        
        // Update local state immediately for better UX
        setState(() {
          _deviceStatus = _deviceStatus!.copyWith(relay4: newState);
        });
        
        // Log the action
        try {
          await StorageService.instance.logDeviceAction(
            deviceType: 'water_pump',
            action: newState ? 'turn_on' : 'turn_off',
            status: 'success',
          );
        } catch (e) {
          print('Log error: $e');
        }
        
        // ส่ง log ไปยังหน้า Log
        _sendLogToLogScreen('🎛️ ควบคุมอุปกรณ์', 'ปั๊มน้ำ ${newState ? 'เปิด' : 'ปิด'}', newState ? Colors.green : Colors.orange);
      } else if (mounted) {
        print('Dashboard: Water pump control failed');
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(context, '❌ เกิดข้อผิดพลาด: $e', isError: true);
      }
    }
  }

  Future<void> _controlHeater() async {
    if (!mounted) return;
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final mqttService = Provider.of<MqttService>(context, listen: false);
      
      // สร้าง default device status ถ้ายังไม่มี
      if (_deviceStatus == null) {
        _deviceStatus = DeviceStatus(
          temperature: 0.0,
          humidity: 0.0,
          gasLevel: 0,
          relay1: false,
          relay2: false,
          relay3: false,
          relay4: false,
          relay5: false,
          relay6: false,
          online: false,
          lastSeen: DateTime.now(),
        );
      }
      
      final newState = !_deviceStatus!.relay5;
      
      print('Dashboard: Sending heater control command: ${newState ? 'ON' : 'OFF'}');
      
      // ลองส่งผ่าน MQTT ก่อน
      bool success = false;
      if (mqttService.isConnected) {
        success = await mqttService.controlHeater(newState);
        if (kDebugMode) print('MQTT Heater Control: $success');
      }
      
      // ถ้า MQTT ไม่สำเร็จ ใช้ API
      if (!success) {
        success = await apiService.controlHeater(newState);
        if (kDebugMode) print('API Heater Control: $success');
      }
      
      if (success && mounted) {
        print('Dashboard: Heater control success: ${newState ? 'ON' : 'OFF'}');
        
        // Update local state immediately for better UX
        setState(() {
          _deviceStatus = _deviceStatus!.copyWith(relay5: newState);
        });
        
        // Log the action
        try {
          await StorageService.instance.logDeviceAction(
            deviceType: 'heater',
            action: newState ? 'turn_on' : 'turn_off',
            status: 'success',
          );
        } catch (e) {
          print('Log error: $e');
        }
        
        // ส่ง log ไปยังหน้า Log
        _sendLogToLogScreen('🎛️ ควบคุมอุปกรณ์', 'ฮีทเตอร์ ${newState ? 'เปิด' : 'ปิด'}', newState ? Colors.green : Colors.orange);
      } else if (mounted) {
        print('Dashboard: Heater control failed');
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(context, '❌ เกิดข้อผิดพลาด: $e', isError: true);
      }
    }
  }

  Future<void> _controlExtraDevice() async {
    if (!mounted) return;
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final mqttService = Provider.of<MqttService>(context, listen: false);
      
      // สร้าง default device status ถ้ายังไม่มี
      if (_deviceStatus == null) {
        _deviceStatus = DeviceStatus(
          temperature: 0.0,
          humidity: 0.0,
          gasLevel: 0,
          relay1: false,
          relay2: false,
          relay3: false,
          relay4: false,
          relay5: false,
          relay6: false,
          online: false,
          lastSeen: DateTime.now(),
        );
      }
      
      final newState = !_deviceStatus!.relay6;
      
      print('Dashboard: Sending extra device control command: ${newState ? 'ON' : 'OFF'}');
      
      // ลองส่งผ่าน MQTT ก่อน
      bool success = false;
      if (mqttService.isConnected) {
        success = await mqttService.controlExtraDevice(newState);
        if (kDebugMode) print('MQTT Extra Device Control: $success');
      }
      
      // ถ้า MQTT ไม่สำเร็จ ใช้ API
      if (!success) {
        success = await apiService.controlExtraDevice(newState);
        if (kDebugMode) print('API Extra Device Control: $success');
      }
      
      if (success && mounted) {
        print('Dashboard: Extra device control success: ${newState ? 'ON' : 'OFF'}');
        
        // Update local state immediately for better UX
        setState(() {
          _deviceStatus = _deviceStatus!.copyWith(relay6: newState);
        });
        
        // Log the action
        try {
          await StorageService.instance.logDeviceAction(
            deviceType: 'extra_device',
            action: newState ? 'turn_on' : 'turn_off',
            status: 'success',
          );
        } catch (e) {
          print('Log error: $e');
        }
        
        // ส่ง log ไปยังหน้า Log
        _sendLogToLogScreen('🎛️ ควบคุมอุปกรณ์', 'อุปกรณ์เพิ่มเติม ${newState ? 'เปิด' : 'ปิด'}', newState ? Colors.green : Colors.orange);
      } else if (mounted) {
        print('Dashboard: Extra device control failed');
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(context, '❌ เกิดข้อผิดพลาด: $e', isError: true);
      }
    }
  }

  void _navigateToControl() {
    Navigator.pushNamed(context, '/control');
  }

  void _navigateToSensorDetail(String sensorType) {
    // Could navigate to detailed sensor view
    AppHelpers.showSnackBar(context, 'รายละเอียด $sensorType');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      body: _isLoading && _deviceStatus == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    _buildHeader(theme),
                    
                    const SizedBox(height: 20),
                    
                    // Connection status
                    _buildConnectionStatus(theme),
                    
                    const SizedBox(height: 20),
                    
                    // Device controls
                    _buildDeviceControls(theme),
                    
                    const SizedBox(height: 24),
                    
                    // Sensor overview
                    _buildSensorOverview(theme),
                    
                    // Bottom padding for safe area
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Smart Home',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryColor,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    'Home',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                  if (_lastUpdateTime != null) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.schedule,
                      size: 16,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'อัปเดต: ${AppHelpers.formatDateTimeShort(_lastUpdateTime!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                      ),
                    ),
                                     ],
                 ],
               ),
               
               // Voice command status
               if (_isVoiceListening) ...[
                 const SizedBox(height: 8),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                   decoration: BoxDecoration(
                     color: AppTheme.errorColor.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(16),
                     border: Border.all(color: AppTheme.errorColor.withOpacity(0.3)),
                   ),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Icon(
                         Icons.mic,
                         size: 16,
                         color: AppTheme.errorColor,
                       ),
                       const SizedBox(width: 6),
                       Text(
                         'กำลังฟัง...',
                         style: theme.textTheme.bodySmall?.copyWith(
                           color: AppTheme.errorColor,
                           fontWeight: FontWeight.w500,
                         ),
                       ),
                     ],
                   ),
                 ),
               ],
               
               // TTS Status
               if (_isTtsAvailable) ...[
                 const SizedBox(height: 8),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                   decoration: BoxDecoration(
                     color: _isTtsSpeaking 
                         ? AppTheme.warningColor.withOpacity(0.1)
                         : AppTheme.successColor.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(16),
                     border: Border.all(
                       color: _isTtsSpeaking 
                           ? AppTheme.warningColor.withOpacity(0.3)
                           : AppTheme.successColor.withOpacity(0.3),
                     ),
                   ),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Icon(
                         _isTtsSpeaking ? Icons.volume_up : Icons.volume_up,
                         size: 16,
                         color: _isTtsSpeaking 
                             ? AppTheme.warningColor 
                             : AppTheme.successColor,
                       ),
                       const SizedBox(width: 6),
                       Text(
                         _isTtsSpeaking 
                             ? 'กำลังพูด...'
                             : 'OpenAI TTS พร้อมใช้งาน',
                         style: theme.textTheme.bodySmall?.copyWith(
                           color: _isTtsSpeaking 
                               ? AppTheme.warningColor 
                               : AppTheme.successColor,
                           fontWeight: FontWeight.w500,
                         ),
                       ),
                       // แสดงจำนวน queue
                       Consumer<TtsService>(
                         builder: (context, ttsService, child) {
                           if (ttsService.queueLength > 0) {
                             return Container(
                               margin: const EdgeInsets.only(left: 4),
                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                               decoration: BoxDecoration(
                                 color: AppTheme.primaryColor,
                                 borderRadius: BorderRadius.circular(8),
                               ),
                               child: Text(
                                 '${ttsService.queueLength}',
                                 style: theme.textTheme.bodySmall?.copyWith(
                                   color: Colors.white,
                                   fontSize: 10,
                                   fontWeight: FontWeight.bold,
                                 ),
                               ),
                             );
                           }
                           return const SizedBox.shrink();
                         },
                       ),
                     ],
                   ),
                 ),
               ],
               
               if (_lastTranscription != null && !_isVoiceListening) ...[
                 const SizedBox(height: 8),
                 Container(
                   padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                   decoration: BoxDecoration(
                     color: AppTheme.primaryColor.withOpacity(0.1),
                     borderRadius: BorderRadius.circular(16),
                     border: Border.all(color: AppTheme.primaryColor.withOpacity(0.3)),
                   ),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Icon(
                         Icons.hearing,
                         size: 16,
                         color: AppTheme.primaryColor,
                       ),
                       const SizedBox(width: 6),
                       Text(
                         '"$_lastTranscription"',
                         style: theme.textTheme.bodySmall?.copyWith(
                           color: AppTheme.primaryColor,
                           fontWeight: FontWeight.w500,
                         ),
                       ),
                     ],
                   ),
                 ),
               ],
             ],
           ),
         ),
        // Voice command button
        Container(
          decoration: BoxDecoration(
            gradient: _isVoiceListening 
                ? LinearGradient(
                    colors: [
                      AppTheme.errorColor.withOpacity(0.8),
                      AppTheme.errorColor.withOpacity(0.6),
                    ],
                  )
                : AppTheme.primaryGradient,
            borderRadius: BorderRadius.circular(12),
            boxShadow: _isVoiceListening ? [
              BoxShadow(
                color: AppTheme.errorColor.withOpacity(0.5),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ] : null,
          ),
          child: IconButton(
            onPressed: _startVoiceCommand,
            icon: Icon(
              _isVoiceListening ? Icons.mic_off : Icons.mic,
              color: Colors.white,
            ),
            tooltip: _isVoiceListening ? 'หยุดฟัง' : 'สั่งคำสั่งด้วยเสียง',
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.all(12),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // TTS Test button
        if (_isTtsAvailable) ...[
          IconButton(
            onPressed: _testTts,
            icon: Icon(
              _isTtsSpeaking ? Icons.volume_up : Icons.volume_up,
              color: _isTtsSpeaking ? AppTheme.warningColor : AppTheme.primaryColor,
            ),
            tooltip: 'ทดสอบเสียง',
          ),
          const SizedBox(width: 4),
        ],
        // Auto-refresh toggle
        IconButton(
          onPressed: _toggleAutoRefresh,
          icon: Icon(
            _autoRefreshEnabled ? Icons.autorenew : Icons.sync_disabled,
            color: _autoRefreshEnabled ? AppTheme.primaryColor : Colors.grey,
          ),
          tooltip: _autoRefreshEnabled ? 'ปิด Auto-refresh' : 'เปิด Auto-refresh',
        ),
        if (_isRefreshing) ...[
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ] else ...[
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(Icons.refresh),
            tooltip: 'รีเฟรชข้อมูล',
          ),
        ],
      ],
    );
  }

  Widget _buildConnectionStatus(ThemeData theme) {
    return Consumer2<MqttService, ApiService>(
      builder: (context, mqttService, apiService, child) {
        final isDeviceOnline = _deviceStatus?.online ?? false;
        final isMqttConnected = mqttService.isConnected;
        final isApiConnected = apiService.isConnected;
        final lastSeen = _deviceStatus?.lastSeen;

        // ดูสถานะการเชื่อมต่อโดยรวม
        final overallConnected = isDeviceOnline || isMqttConnected || isApiConnected;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: overallConnected 
                ? AppTheme.successColor.withOpacity(0.1)
                : AppTheme.errorColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: overallConnected 
                  ? AppTheme.successColor.withOpacity(0.3)
                  : AppTheme.errorColor.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              // สถานะอุปกรณ์หลัก
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDeviceOnline 
                          ? AppTheme.successColor
                          : AppTheme.errorColor,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isDeviceOnline ? Icons.wifi : Icons.wifi_off,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDeviceOnline ? 'อุปกรณ์เชื่อมต่อแล้ว' : 'อุปกรณ์ไม่เชื่อมต่อ',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDeviceOnline 
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          ),
                        ),
                        if (lastSeen != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            isDeviceOnline 
                                ? 'ออนไลน์'
                                : 'ออฟไลน์ - ${AppHelpers.formatDateTimeShort(lastSeen)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // สถานะบริการ
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildServiceStatus(
                    'MQTT',
                    isMqttConnected,
                    Icons.swap_horiz,
                    theme,
                  ),
                  _buildServiceStatus(
                    'API',
                    isApiConnected,
                    Icons.cloud,
                    theme,
                  ),
                  _buildServiceStatus(
                    'AUTO',
                    _autoRefreshEnabled,
                    Icons.refresh,
                    theme,
                  ),
                ],
              ),
              
              // ข้อมูลการอัปเดต
              if (_lastDeviceStatusUpdate != null || _lastSensorDataUpdate != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      if (_lastDeviceStatusUpdate != null) ...[
                        Icon(Icons.device_hub, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Device: ${AppHelpers.formatDateTimeShort(_lastDeviceStatusUpdate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      ],
                      if (_lastDeviceStatusUpdate != null && _lastSensorDataUpdate != null) ...[
                        const SizedBox(width: 8),
                        Container(width: 1, height: 12, color: Colors.grey[400]),
                        const SizedBox(width: 8),
                      ],
                      if (_lastSensorDataUpdate != null) ...[
                        Icon(Icons.sensors, size: 12, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          'Sensor: ${AppHelpers.formatDateTimeShort(_lastSensorDataUpdate!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildServiceStatus(String label, bool isConnected, IconData icon, ThemeData theme) {
    return Column(
      children: [
        Icon(
          icon,
          color: isConnected ? AppTheme.successColor : Colors.grey,
          size: 20,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: isConnected ? AppTheme.successColor : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildDeviceControls(ThemeData theme) {
    if (_deviceStatus == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ควบคุมอุปกรณ์',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        // แถวแรก - ไฟและพัดลม
        Row(
          children: [
            Expanded(
              child: LightDeviceCard(
                deviceStatus: _deviceStatus!,
                onToggle: _controlLight,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FanDeviceCard(
                deviceStatus: _deviceStatus!,
                onToggle: _controlFan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // แถวที่สอง - แอร์และปั๊มน้ำ
        Row(
          children: [
            Expanded(
              child: AirConditionerDeviceCard(
                deviceStatus: _deviceStatus!,
                onToggle: _controlAirConditioner,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: WaterPumpDeviceCard(
                deviceStatus: _deviceStatus!,
                onToggle: _controlWaterPump,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // แถวที่สาม - ฮีทเตอร์และอุปกรณ์เพิ่มเติม
        Row(
          children: [
            Expanded(
              child: HeaterDeviceCard(
                deviceStatus: _deviceStatus!,
                onToggle: _controlHeater,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ExtraDeviceCard(
                deviceStatus: _deviceStatus!,
                onToggle: _controlExtraDevice,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSensorOverview(ThemeData theme) {
    if (_deviceStatus == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ภาพรวม Sensors',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        SensorOverviewCard(
          deviceStatus: _deviceStatus!,
          onTap: () => _navigateToSensorDetail('ภาพรวม'),
        ),
      ],
    );
  }

  Widget _buildDetailedSensors(ThemeData theme) {
    if (_deviceStatus == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'รายละเอียด Sensors',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        TemperatureSensorCard(
          deviceStatus: _deviceStatus!,
          chartData: _sensorHistory,
          showChart: true,
          onTap: () => _navigateToSensorDetail('อุณหภูมิ'),
        ),
        const SizedBox(height: 12),
        HumiditySensorCard(
          deviceStatus: _deviceStatus!,
          chartData: _sensorHistory,
          showChart: true,
          onTap: () => _navigateToSensorDetail('ความชื้น'),
        ),
        const SizedBox(height: 12),
        GasSensorCard(
          deviceStatus: _deviceStatus!,
          chartData: _sensorHistory,
          showChart: true,
          onTap: () => _navigateToSensorDetail('ก๊าซ'),
        ),
      ],
    );
  }

  void _startVoiceCommand() async {
    final voiceCommandService = Provider.of<VoiceCommandService>(context, listen: false);
    
    if (_isVoiceListening) {
      // หยุดฟัง
      await voiceCommandService.stopListening();
    } else {
      // เริ่มฟัง
      final success = await voiceCommandService.startListening();
      if (!success) {
        AppHelpers.showSnackBar(
          context, 
          '❌ ไม่สามารถเริ่มฟังคำสั่งเสียงได้ กรุณาตรวจสอบสิทธิ์ไมโครโฟน',
          isError: true,
        );
      }
    }
  }

  // ฟังก์ชันทดสอบ TTS
  void _testTts() async {
    print('Dashboard: TTS Test button pressed');
    print('Dashboard: TTS Available: $_isTtsAvailable');
    
    if (!_isTtsAvailable) {
      AppHelpers.showSnackBar(
        context, 
        '❌ TTS Service ไม่พร้อมใช้งาน',
        isError: true,
      );
      return;
    }

    try {
      final ttsService = Provider.of<TtsService>(context, listen: false);
      print('Dashboard: Calling TTS speak method...');
      
      final result = await ttsService.speak('สวัสดีครับ นี่คือการทดสอบระบบเสียง');
      print('Dashboard: TTS speak result: $result');
      
      AppHelpers.showSnackBar(
        context, 
        '🔊 กำลังทดสอบเสียง... (Result: $result)',
        isError: false,
      );
    } catch (e) {
      print('Dashboard: TTS test error: $e');
      AppHelpers.showSnackBar(
        context, 
        '❌ เกิดข้อผิดพลาดในการทดสอบเสียง: $e',
        isError: true,
      );
    }
  }
}
