import 'dart:io';
import 'package:flutter/foundation.dart';
import '../services/api_service.dart';
import '../services/mqtt_service.dart';
import '../services/network_service.dart';
import '../utils/log_manager.dart';

class ConnectionTest {
  static Future<Map<String, dynamic>> runFullTest() async {
    final results = <String, dynamic>{};
    
    try {
      // Test network connectivity
      results['network'] = await _testNetworkConnectivity();
      
      // Test API connectivity
      results['api'] = await _testApiConnectivity();
      
      // Test MQTT connectivity (skip on web)
      if (!kIsWeb) {
        results['mqtt'] = await _testMqttConnectivity();
      } else {
        results['mqtt'] = {
          'status': 'skipped',
          'message': 'MQTT not supported on web platform',
          'success': false,
        };
      }
      
      // Overall status
      results['overall'] = _calculateOverallStatus(results);
      
    } catch (e) {
      logger.error('Connection test failed: $e', category: 'ConnectionTest');
      results['error'] = e.toString();
      results['overall'] = {
        'success': false,
        'message': 'Test failed: $e',
      };
    }
    
    return results;
  }

  static Future<Map<String, dynamic>> _testNetworkConnectivity() async {
    try {
      final networkService = NetworkService();
      await networkService.initialize();
      
      final networkInfo = await networkService.getNetworkInfo();
      
      return {
        'status': 'completed',
        'success': networkService.isConnected,
        'message': networkService.getNetworkStatusMessage(),
        'details': networkInfo,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      return {
        'status': 'failed',
        'success': false,
        'message': 'Network test failed: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  static Future<Map<String, dynamic>> _testApiConnectivity() async {
    try {
      final apiService = ApiService();
      
      // Test basic connection
      final connectionTest = await apiService.testConnection();
      
      if (connectionTest) {
        // Test device status endpoint
        final deviceStatus = await apiService.getDeviceStatus();
        
        return {
          'status': 'completed',
          'success': true,
          'message': 'API connection successful',
          'deviceStatus': deviceStatus != null,
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        return {
          'status': 'failed',
          'success': false,
          'message': 'API connection failed',
          'error': apiService.lastError,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      return {
        'status': 'failed',
        'success': false,
        'message': 'API test failed: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  static Future<Map<String, dynamic>> _testMqttConnectivity() async {
    try {
      final mqttService = MqttService();
      
      // Try to connect
      final connected = await mqttService.connect();
      
      if (connected) {
        // Test publishing a simple message
        final published = await mqttService.publishCommand('TEST_CONNECTION');
        
        return {
          'status': 'completed',
          'success': true,
          'message': 'MQTT connection successful',
          'published': published,
          'timestamp': DateTime.now().toIso8601String(),
        };
      } else {
        return {
          'status': 'failed',
          'success': false,
          'message': 'MQTT connection failed',
          'error': mqttService.lastError,
          'timestamp': DateTime.now().toIso8601String(),
        };
      }
    } catch (e) {
      return {
        'status': 'failed',
        'success': false,
        'message': 'MQTT test failed: $e',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  static Map<String, dynamic> _calculateOverallStatus(Map<String, dynamic> results) {
    final networkSuccess = results['network']?['success'] ?? false;
    final apiSuccess = results['api']?['success'] ?? false;
    final mqttSuccess = results['mqtt']?['success'] ?? false;
    final mqttSkipped = results['mqtt']?['status'] == 'skipped';
    
    // Calculate overall success
    bool overallSuccess;
    String message;
    
    if (networkSuccess && apiSuccess) {
      if (mqttSkipped || mqttSuccess) {
        overallSuccess = true;
        message = 'การเชื่อมต่อสำเร็จ';
      } else {
        overallSuccess = false;
        message = 'API ทำงานได้ แต่ MQTT ไม่สามารถเชื่อมต่อได้';
      }
    } else if (networkSuccess) {
      overallSuccess = false;
      message = 'เครือข่ายเชื่อมต่อได้ แต่ API ไม่สามารถเข้าถึงได้';
    } else {
      overallSuccess = false;
      message = 'ไม่สามารถเชื่อมต่อเครือข่ายได้';
    }
    
    return {
      'success': overallSuccess,
      'message': message,
      'network': networkSuccess,
      'api': apiSuccess,
      'mqtt': mqttSuccess || mqttSkipped,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  // Quick connection test for UI
  static Future<bool> quickTest() async {
    try {
      // Test basic internet connectivity
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Test specific server connectivity
  static Future<bool> testServerConnectivity(String host, {int port = 80}) async {
    try {
      final socket = await Socket.connect(host, port, timeout: const Duration(seconds: 5));
      socket.destroy();
      return true;
    } catch (e) {
      return false;
    }
  }
}
