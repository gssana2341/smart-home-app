import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../utils/log_manager.dart';

enum NetworkType {
  wifi,
  mobile,
  ethernet,
  none,
  unknown,
}

class NetworkService extends ChangeNotifier {
  static final NetworkService _instance = NetworkService._internal();
  factory NetworkService() => _instance;
  NetworkService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  
  NetworkType _currentNetworkType = NetworkType.unknown;
  bool _isConnected = false;
  String? _connectionInfo;
  List<ConnectivityResult> _availableConnections = [];

  // Getters
  NetworkType get currentNetworkType => _currentNetworkType;
  bool get isConnected => _isConnected;
  String? get connectionInfo => _connectionInfo;
  List<ConnectivityResult> get availableConnections => _availableConnections;
  
  bool get isWifiConnected => _availableConnections.contains(ConnectivityResult.wifi);
  bool get isMobileConnected => _availableConnections.contains(ConnectivityResult.mobile);
  bool get isEthernetConnected => _availableConnections.contains(ConnectivityResult.ethernet);

  // Initialize network monitoring
  Future<void> initialize() async {
    try {
      // Get initial connectivity status
      await _checkInitialConnectivity();
      
      // Start listening to connectivity changes
      _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
        _onConnectivityChanged,
        onError: (error) {
          logger.error('Connectivity stream error: $error', category: 'Network');
        },
      );
      
      logger.info('Network service initialized', category: 'Network');
    } catch (e) {
      logger.error('Failed to initialize network service: $e', category: 'Network');
    }
  }

  // Check initial connectivity
  Future<void> _checkInitialConnectivity() async {
    try {
      final results = await _connectivity.checkConnectivity();
      await _onConnectivityChanged(results);
    } catch (e) {
      logger.error('Failed to check initial connectivity: $e', category: 'Network');
    }
  }

  // Handle connectivity changes
  Future<void> _onConnectivityChanged(List<ConnectivityResult> results) async {
    try {
      _availableConnections = results;
      
      // Determine primary connection type
      if (results.contains(ConnectivityResult.wifi)) {
        _currentNetworkType = NetworkType.wifi;
        _connectionInfo = 'WiFi';
      } else if (results.contains(ConnectivityResult.mobile)) {
        _currentNetworkType = NetworkType.mobile;
        _connectionInfo = 'Mobile Data';
      } else if (results.contains(ConnectivityResult.ethernet)) {
        _currentNetworkType = NetworkType.ethernet;
        _connectionInfo = 'Ethernet';
      } else if (results.isEmpty || results.contains(ConnectivityResult.none)) {
        _currentNetworkType = NetworkType.none;
        _connectionInfo = 'No Connection';
      } else {
        _currentNetworkType = NetworkType.unknown;
        _connectionInfo = 'Unknown';
      }

      // Check actual internet connectivity
      await _checkInternetConnectivity();
      
      logger.info('Network changed: $_connectionInfo (${results.join(', ')})', category: 'Network');
      notifyListeners();
    } catch (e) {
      logger.error('Error handling connectivity change: $e', category: 'Network');
    }
  }

  // Check actual internet connectivity
  Future<void> _checkInternetConnectivity() async {
    try {
      // Try to reach a reliable server
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      
      _isConnected = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      
      if (_isConnected) {
        logger.info('Internet connectivity confirmed', category: 'Network');
      } else {
        logger.warning('No internet connectivity detected', category: 'Network');
      }
    } catch (e) {
      _isConnected = false;
      logger.warning('Internet connectivity check failed: $e', category: 'Network');
    }
  }

  // Get network quality information
  Future<Map<String, dynamic>> getNetworkInfo() async {
    try {
      final results = await _connectivity.checkConnectivity();
      
      return {
        'type': _currentNetworkType.toString(),
        'isConnected': _isConnected,
        'availableConnections': results.map((e) => e.toString()).toList(),
        'connectionInfo': _connectionInfo,
        'timestamp': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      logger.error('Failed to get network info: $e', category: 'Network');
      return {
        'type': 'unknown',
        'isConnected': false,
        'availableConnections': [],
        'connectionInfo': 'Error',
        'timestamp': DateTime.now().toIso8601String(),
      };
    }
  }

  // Test connection to specific host
  Future<bool> testConnection(String host, {int port = 80, Duration timeout = const Duration(seconds: 5)}) async {
    try {
      final socket = await Socket.connect(host, port, timeout: timeout);
      socket.destroy();
      return true;
    } catch (e) {
      logger.warning('Connection test to $host:$port failed: $e', category: 'Network');
      return false;
    }
  }

  // Get recommended timeout based on network type
  Duration getRecommendedTimeout() {
    switch (_currentNetworkType) {
      case NetworkType.wifi:
        return const Duration(seconds: 5);
      case NetworkType.mobile:
        return const Duration(seconds: 10);
      case NetworkType.ethernet:
        return const Duration(seconds: 3);
      case NetworkType.none:
        return const Duration(seconds: 1);
      case NetworkType.unknown:
        return const Duration(seconds: 8);
    }
  }

  // Get recommended retry count based on network type
  int getRecommendedRetryCount() {
    switch (_currentNetworkType) {
      case NetworkType.wifi:
        return 2;
      case NetworkType.mobile:
        return 4;
      case NetworkType.ethernet:
        return 1;
      case NetworkType.none:
        return 0;
      case NetworkType.unknown:
        return 3;
    }
  }

  // Check if network is suitable for real-time operations
  bool isNetworkSuitableForRealtime() {
    return _isConnected && 
           (_currentNetworkType == NetworkType.wifi || 
            _currentNetworkType == NetworkType.ethernet);
  }

  // Check if network is suitable for basic operations
  bool isNetworkSuitableForBasic() {
    return _isConnected && _currentNetworkType != NetworkType.none;
  }

  // Get network status message for UI
  String getNetworkStatusMessage() {
    if (!_isConnected) {
      return 'ไม่มีการเชื่อมต่ออินเทอร์เน็ต';
    }
    
    switch (_currentNetworkType) {
      case NetworkType.wifi:
        return 'เชื่อมต่อผ่าน WiFi';
      case NetworkType.mobile:
        return 'เชื่อมต่อผ่านเน็ตมือถือ';
      case NetworkType.ethernet:
        return 'เชื่อมต่อผ่าน Ethernet';
      case NetworkType.none:
        return 'ไม่มีการเชื่อมต่อ';
      case NetworkType.unknown:
        return 'เชื่อมต่อไม่ทราบประเภท';
    }
  }

  // Get network icon for UI
  String getNetworkIcon() {
    switch (_currentNetworkType) {
      case NetworkType.wifi:
        return '📶';
      case NetworkType.mobile:
        return '📱';
      case NetworkType.ethernet:
        return '🔌';
      case NetworkType.none:
        return '❌';
      case NetworkType.unknown:
        return '❓';
    }
  }

  // Dispose
  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    super.dispose();
  }
}
