class ApiConstants {
  // Base URL (override with --dart-define=API_BASE_URL=...)
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://34.87.180.232:8080',
  );
  
  // API Endpoints
  static const String statusEndpoint = '/api/status';
  static const String chatEndpoint = '/api/chat';
  static const String controlEndpoint = '/api/control';
  static const String sensorsEndpoint = '/api/sensors';
  static const String historyEndpoint = '/api/history';
  static const String ttsEndpoint = '/api/tts';
  
  // Full URLs
  static const String statusUrl = '$baseUrl$statusEndpoint';
  static const String chatUrl = '$baseUrl$chatEndpoint';
  static const String controlUrl = '$baseUrl$controlEndpoint';
  static const String sensorsUrl = '$baseUrl$sensorsEndpoint';
  static const String historyUrl = '$baseUrl$historyEndpoint';
  static const String ttsUrl = '$baseUrl$ttsEndpoint';
  
  // Request timeouts
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 10);
}

class MqttConstants {
  // MQTT Broker (override with --dart-define=MQTT_HOST / MQTT_PORT / MQTT_WS_URL / MQTT_CLIENT_ID)
  static const String brokerHost = String.fromEnvironment(
    'MQTT_HOST',
    defaultValue: 'broker.hivemq.com',
  );
  static const int brokerPort = int.fromEnvironment(
    'MQTT_PORT',
    defaultValue: 1883,
  );
  static const String clientId = String.fromEnvironment(
    'MQTT_CLIENT_ID',
    defaultValue: 'flutter-home-001',
  );
  
  // MQTT over WebSocket (for web browser)
  static const String webSocketUrl = String.fromEnvironment(
    'MQTT_WS_URL',
    defaultValue: 'ws://broker.hivemq.com:8000/mqtt',
  );
  
  // MQTT Topics
  static const String sensorTopic = 'home/sensor';
  static const String statusTopic = 'home/status';
  static const String heartbeatTopic = 'home/heartbeat';
  static const String commandTopic = 'home/command';
  
  // Connection settings
  static const Duration keepAlivePeriod = Duration(seconds: 60);
  static const Duration connectionTimeout = Duration(seconds: 10);
}

class StorageConstants {
  // SharedPreferences keys
  static const String serverUrlKey = 'server_url';
  static const String mqttHostKey = 'mqtt_host';
  static const String mqttPortKey = 'mqtt_port';
  static const String lastUpdateKey = 'last_update';
  static const String deviceStatusKey = 'device_status';
  static const String appThemeKey = 'app_theme';
  static const String notificationEnabledKey = 'notification_enabled';
  static const String controlModeKey = 'control_mode';
  static const String autoRefreshKey = 'auto_refresh';
  static const String refreshIntervalKey = 'refresh_interval';
  
  // SQLite database
  static const String databaseName = 'smart_home.db';
  static const int databaseVersion = 1;
  
  // Table names
  static const String chatMessagesTable = 'chat_messages';
  static const String sensorDataTable = 'sensor_data';
  static const String deviceLogsTable = 'device_logs';
}

class AppConstants {
  // App information
  static const String appName = 'Smart Home';
  static const String appVersion = '1.0.0';
  
  // UI constants
  static const double defaultPadding = 16.0;
  static const double smallPadding = 8.0;
  static const double largePadding = 24.0;
  static const double borderRadius = 12.0;
  static const double cardElevation = 4.0;
  
  // Chart colors
  static const List<String> chartColors = [
    '#2196F3', // Blue
    '#4CAF50', // Green
    '#FF9800', // Orange
    '#F44336', // Red
    '#9C27B0', // Purple
    '#00BCD4', // Cyan
  ];
  
  // Device limits
  static const double maxTemperature = 50.0;
  static const double minTemperature = 0.0;
  static const double maxHumidity = 100.0;
  static const double minHumidity = 0.0;
  static const int maxGasLevel = 1000;
  static const int minGasLevel = 0;
  
  // Refresh intervals (in seconds)
  static const int defaultRefreshInterval = 30;
  static const int minRefreshInterval = 5;
  static const int maxRefreshInterval = 300;
  
  // Chart data points
  static const int maxChartDataPoints = 50;
  static const int defaultChartDataPoints = 20;
}

class DeviceTypes {
  static const String light = 'light';
  static const String fan = 'fan';
  static const String airConditioner = 'air_conditioner';
  static const String waterPump = 'water_pump';
  static const String heater = 'heater';
  static const String extraDevice = 'extra_device';
  static const String temperatureSensor = 'temperature_sensor';
  static const String humiditySensor = 'humidity_sensor';
  static const String gasSensor = 'gas_sensor';
}

class MessageTypes {
  static const String command = 'command';
  static const String status = 'status';
  static const String sensor = 'sensor';
  static const String heartbeat = 'heartbeat';
  static const String error = 'error';
}

class Commands {
  static const String turnOnLight = 'LIGHT_ON';
  static const String turnOffLight = 'LIGHT_OFF';
  static const String turnOnFan = 'FAN_ON';
  static const String turnOffFan = 'FAN_OFF';
  static const String turnOnAirConditioner = 'AC_ON';
  static const String turnOffAirConditioner = 'AC_OFF';
  static const String turnOnWaterPump = 'PUMP_ON';
  static const String turnOffWaterPump = 'PUMP_OFF';
  static const String turnOnHeater = 'HEATER_ON';
  static const String turnOffHeater = 'HEATER_OFF';
  static const String turnOnExtraDevice = 'EXTRA_ON';
  static const String turnOffExtraDevice = 'EXTRA_OFF';
  static const String getStatus = 'GET_STATUS';
  static const String getSensors = 'GET_SENSORS';
  static const String reset = 'RESET';
}
