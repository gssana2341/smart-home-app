import 'dart:async';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../models/device_status.dart';
import '../models/sensor_data.dart';
import '../models/chat_message.dart';
import '../utils/constants.dart';
import '../utils/log_manager.dart';
import 'network_service.dart';

class ApiService extends ChangeNotifier {
  late final Dio _dio;
  bool _isConnected = false;
  String? _lastError;
  final NetworkService _networkService = NetworkService();
  
  // Getters
  bool get isConnected => _isConnected;
  String? get lastError => _lastError;
  NetworkService get networkService => _networkService;

  ApiService() {
    try {
      _initializeDio();
      _initializeNetworkService();
    } catch (e) {
      logger.error('ApiService initialization error', error: e, category: 'API');
      _isConnected = false;
      _lastError = e.toString();
    }
  }

  Future<void> _initializeNetworkService() async {
    try {
      await _networkService.initialize();
      // Listen to network changes and update timeouts accordingly
      _networkService.addListener(_onNetworkChanged);
    } catch (e) {
      logger.error('Failed to initialize network service', error: e, category: 'API');
    }
  }

  void _onNetworkChanged() {
    // Update Dio timeouts based on network type
    final timeout = _networkService.getRecommendedTimeout();
    _dio.options.connectTimeout = timeout;
    _dio.options.receiveTimeout = Duration(seconds: timeout.inSeconds * 2);
    _dio.options.sendTimeout = timeout;
    
    logger.info('Updated API timeouts based on network: ${_networkService.getNetworkStatusMessage()}', category: 'API');
  }

  void _initializeDio() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      sendTimeout: ApiConstants.sendTimeout,
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'User-Agent': 'SmartHomeApp/1.0.0',
      },
      // เพิ่มการรองรับการเชื่อมต่อที่ไม่เสถียร
      followRedirects: true,
      maxRedirects: 3,
      validateStatus: (status) {
        // ยอมรับ status codes 200-299 และ 400-499
        return status != null && (status < 300 || (status >= 400 && status < 500));
      },
    ));

    // Add interceptors for logging and error handling
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        logger.debug('Request: ${options.method} ${options.path}', category: 'API');
        if (options.data != null) {
          logger.debug('Data: ${options.data}', category: 'API');
        }
        handler.next(options);
      },
      onResponse: (response, handler) {
        logger.info('Response: ${response.statusCode} ${response.requestOptions.path}', category: 'API');
        _isConnected = true;
        _lastError = null;
        notifyListeners();
        handler.next(response);
      },
      onError: (error, handler) {
        logger.error('API Error: ${error.message}', category: 'API');
        _isConnected = false;
        _lastError = error.message;
        notifyListeners();
        handler.next(error);
      },
    ));
  }

  // Get device status
  Future<DeviceStatus?> getDeviceStatus() async {
    try {
      final response = await _dio.get(ApiConstants.statusEndpoint);
      
      if (response.statusCode == 200 && response.data != null) {
        // แก้: ข้อมูลจริงอยู่ใน response.data['data']
        final deviceData = response.data['data'] ?? response.data;
        logger.debug('Device Status Data: $deviceData', category: 'API');
        return DeviceStatus.fromJson(deviceData);
      }
      return null;
    } on DioException catch (e) {
      _handleError(e);
      return null;
    } catch (e) {
      _lastError = 'Unexpected error: $e';
      notifyListeners();
      return null;
    }
  }

  // Get sensor data
  Future<List<SensorData>> getSensorData({int? limit}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) {
        queryParams['limit'] = limit;
      }

      final response = await _dio.get(
        ApiConstants.sensorsEndpoint,
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200 && response.data != null) {
        // แก้: ข้อมูลจริงอยู่ใน response.data['data']
        final List<dynamic> dataList = response.data is List 
            ? response.data 
            : response.data['data'] ?? [];
        
        if (kDebugMode) {
          print('Sensor Data List: $dataList');
        }
        
        return dataList
            .map((json) => SensorData.fromJson(json))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      _handleError(e);
      return [];
    } catch (e) {
      _lastError = 'Unexpected error: $e';
      notifyListeners();
      return [];
    }
  }

  // Control device with retry mechanism
  Future<bool> controlDevice({
    required String command,
    Map<String, dynamic>? parameters,
    int? maxRetries,
    Duration? retryDelay,
  }) async {
    // Use network-appropriate retry settings
    final retryCount = maxRetries ?? _networkService.getRecommendedRetryCount();
    final delay = retryDelay ?? const Duration(seconds: 2);
    int attempts = 0;
    Exception? lastException;
    
    while (attempts < retryCount) {
      attempts++;
      
      try {
        if (kDebugMode) {
          print('API: Attempt $attempts/$retryCount for command: $command');
        }
        
        final data = {
          'command': command,
          'timestamp': DateTime.now().toIso8601String(),
          'attempt': attempts,
          'client_id': 'flutter_app',
          ...?parameters,
        };

        final response = await _dio.post(
          ApiConstants.controlEndpoint,
          data: data,
          options: Options(
            receiveTimeout: const Duration(seconds: 10),
            sendTimeout: const Duration(seconds: 10),
          ),
        );
        
        if (response.statusCode == 200) {
          if (kDebugMode) {
            print('API: Command $command succeeded on attempt $attempts');
          }
          _isConnected = true;
          _lastError = null;
          notifyListeners();
          return true;
        }
        
        throw Exception('Server returned status: ${response.statusCode}');
        
      } on DioException catch (e) {
        lastException = e;
        if (kDebugMode) {
          print('API: Attempt $attempts failed: ${e.message}');
        }
        
        // Don't retry for certain error types
        if (e.type == DioExceptionType.badResponse && 
            e.response?.statusCode == 404) {
          _handleError(e);
          return false;
        }
        
        _handleError(e);
        
        // Wait before retrying (except on last attempt)
        if (attempts < retryCount) {
          if (kDebugMode) {
            print('API: Waiting ${delay.inSeconds}s before retry...');
          }
          await Future.delayed(delay);
        }
        
      } catch (e) {
        lastException = Exception(e.toString());
        if (kDebugMode) {
          print('API: Attempt $attempts failed with error: $e');
        }
        
        // Wait before retrying (except on last attempt)
        if (attempts < retryCount) {
          await Future.delayed(delay);
        }
      }
    }
    
    // All attempts failed
    _lastError = 'All $retryCount attempts failed. Last error: ${lastException?.toString() ?? "Unknown error"}';
    _isConnected = false;
    notifyListeners();
    
    if (kDebugMode) {
      print('API: All attempts failed for command: $command');
    }
    
    return false;
  }

  // Send chat message to AI
  Future<ChatMessage?> sendChatMessage(String message) async {
    try {
      final data = {
        'message': message,
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await _dio.post(
        ApiConstants.chatEndpoint,
        data: data,
      );
      
      if (response.statusCode == 200 && response.data != null) {
        return ChatMessage.fromJson({
          'id': response.data['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
          'message': message,
          'reply': response.data['reply'] ?? '',
          'timestamp': DateTime.now().toIso8601String(),
          'isUser': false,
        });
      }
      return null;
    } on DioException catch (e) {
      _handleError(e);
      return null;
    } catch (e) {
      _lastError = 'Unexpected error: $e';
      notifyListeners();
      return null;
    }
  }

  // Get chat history
  Future<List<ChatMessage>> getChatHistory({int? limit}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (limit != null) {
        queryParams['limit'] = limit;
      }

      final response = await _dio.get(
        ApiConstants.historyEndpoint,
        queryParameters: queryParams,
      );
      
      if (response.statusCode == 200 && response.data != null) {
        final List<dynamic> dataList = response.data is List 
            ? response.data 
            : response.data['messages'] ?? [];
        
        return dataList
            .map((json) => ChatMessage.fromJson(json))
            .toList();
      }
      return [];
    } on DioException catch (e) {
      _handleError(e);
      return [];
    } catch (e) {
      _lastError = 'Unexpected error: $e';
      notifyListeners();
      return [];
    }
  }

  // Control specific devices - ปรับให้ตรงกับ API จริง
  Future<bool> controlLight(bool turnOn) async {
    try {
      final data = {
        'device': 'relay1',
        'action': turnOn ? 'เปิดไฟ' : 'ปิดไฟ',
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (kDebugMode) {
        print('API: Sending light control: $data');
      }

      final response = await _dio.post(
        ApiConstants.controlEndpoint,
        data: data,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('API: Light control success: ${response.data}');
        }
        _isConnected = true;
        _lastError = null;
        notifyListeners();
        return true;
      }
      
      return false;
    } on DioException catch (e) {
      _handleError(e);
      return false;
    } catch (e) {
      _lastError = 'Unexpected error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> controlFan(bool turnOn) async {
    try {
      final data = {
        'device': 'relay2',
        'action': turnOn ? 'เปิดพัดลม' : 'ปิดพัดลม',
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (kDebugMode) {
        print('API: Sending fan control: $data');
      }

      final response = await _dio.post(
        ApiConstants.controlEndpoint,
        data: data,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('API: Fan control success: ${response.data}');
        }
        _isConnected = true;
        _lastError = null;
        notifyListeners();
        return true;
      }
      
      return false;
    } on DioException catch (e) {
      _handleError(e);
      return false;
    } catch (e) {
      _lastError = 'Unexpected error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> controlAirConditioner(bool turnOn) async {
    try {
      final data = {
        'device': 'relay3',
        'action': turnOn ? 'เปิดแอร์' : 'ปิดแอร์',
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (kDebugMode) {
        print('API: Sending AC control: $data');
      }

      final response = await _dio.post(
        ApiConstants.controlEndpoint,
        data: data,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('API: AC control success: ${response.data}');
        }
        _isConnected = true;
        _lastError = null;
        notifyListeners();
        return true;
      }
      
      return false;
    } on DioException catch (e) {
      _handleError(e);
      return false;
    } catch (e) {
      _lastError = 'Unexpected error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> controlWaterPump(bool turnOn) async {
    try {
      final data = {
        'device': 'relay4',
        'action': turnOn ? 'เปิดปั๊มน้ำ' : 'ปิดปั๊มน้ำ',
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (kDebugMode) {
        print('API: Sending water pump control: $data');
      }

      final response = await _dio.post(
        ApiConstants.controlEndpoint,
        data: data,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('API: Water pump control success: ${response.data}');
        }
        _isConnected = true;
        _lastError = null;
        notifyListeners();
        return true;
      }
      
      return false;
    } on DioException catch (e) {
      _handleError(e);
      return false;
    } catch (e) {
      _lastError = 'Unexpected error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> controlHeater(bool turnOn) async {
    try {
      final data = {
        'device': 'relay5',
        'action': turnOn ? 'เปิดฮีทเตอร์' : 'ปิดฮีทเตอร์',
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (kDebugMode) {
        print('API: Sending heater control: $data');
      }

      final response = await _dio.post(
        ApiConstants.controlEndpoint,
        data: data,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('API: Heater control success: ${response.data}');
        }
        _isConnected = true;
        _lastError = null;
        notifyListeners();
        return true;
      }
      
      return false;
    } on DioException catch (e) {
      _handleError(e);
      return false;
    } catch (e) {
      _lastError = 'Unexpected error: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> controlExtraDevice(bool turnOn) async {
    try {
      final data = {
        'device': 'relay6',
        'action': turnOn ? 'เปิดอุปกรณ์เพิ่มเติม' : 'ปิดอุปกรณ์เพิ่มเติม',
        'timestamp': DateTime.now().toIso8601String(),
      };

      if (kDebugMode) {
        print('API: Sending extra device control: $data');
      }

      final response = await _dio.post(
        ApiConstants.controlEndpoint,
        data: data,
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      
      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('API: Extra device control success: ${response.data}');
        }
        _isConnected = true;
        _lastError = null;
        notifyListeners();
        return true;
      }
      
      return false;
    } on DioException catch (e) {
      _handleError(e);
      return false;
    } catch (e) {
      _lastError = 'Unexpected error: $e';
      notifyListeners();
      return false;
    }
  }

  // Refresh device status
  Future<bool> refreshStatus() async {
    return await controlDevice(command: Commands.getStatus);
  }

  // Get sensor readings
  Future<bool> refreshSensors() async {
    return await controlDevice(command: Commands.getSensors);
  }

  // Reset device
  Future<bool> resetDevice() async {
    return await controlDevice(command: Commands.reset);
  }

  // Connection test
  Future<bool> testConnection() async {
    try {
      final response = await _dio.get(
        '/api/ping',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      
      _isConnected = response.statusCode == 200;
      if (_isConnected) {
        _lastError = null;
      }
      notifyListeners();
      return _isConnected;
    } on DioException catch (e) {
      _handleError(e);
      return false;
    } catch (e) {
      _lastError = 'Connection test failed: $e';
      _isConnected = false;
      notifyListeners();
      return false;
    }
  }

  // Update base URL
  void updateBaseUrl(String newBaseUrl) {
    _dio.options.baseUrl = newBaseUrl;
    _isConnected = false;
    _lastError = null;
    notifyListeners();
  }

  // Error handling
  void _handleError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        _lastError = 'Connection timeout';
        break;
      case DioExceptionType.sendTimeout:
        _lastError = 'Send timeout';
        break;
      case DioExceptionType.receiveTimeout:
        _lastError = 'Receive timeout';
        break;
      case DioExceptionType.badResponse:
        _lastError = 'Server error: ${error.response?.statusCode}';
        break;
      case DioExceptionType.cancel:
        _lastError = 'Request cancelled';
        break;
      case DioExceptionType.connectionError:
        _lastError = 'Connection error';
        break;
      case DioExceptionType.unknown:
        _lastError = 'Unknown error: ${error.message}';
        break;
      default:
        _lastError = 'Network error';
    }
    
    _isConnected = false;
    notifyListeners();
  }

  // Cleanup
  @override
  void dispose() {
    _dio.close();
    super.dispose();
  }
}
