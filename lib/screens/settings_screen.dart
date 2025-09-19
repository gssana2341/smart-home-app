import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/mqtt_service.dart';
import '../services/storage_service_simple.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _serverUrlController = TextEditingController();
  final _mqttHostController = TextEditingController();
  final _mqttPortController = TextEditingController();
  
  bool _notificationEnabled = true;
  bool _autoRefresh = true;
  String _selectedTheme = 'system';
  String _controlMode = 'api';
  bool _isLoading = false;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _serverUrlController.dispose();
    _mqttHostController.dispose();
    _mqttPortController.dispose();
    super.dispose();
  }

  void _loadSettings() async {
    setState(() => _isLoading = true);
    
    try {
      final storage = StorageService.instance;
      
      _serverUrlController.text = storage.getServerUrl();
      _mqttHostController.text = storage.getMqttHost();
      _mqttPortController.text = storage.getMqttPort().toString();
      _notificationEnabled = storage.getNotificationEnabled();
      _autoRefresh = storage.getAutoRefresh();
      _selectedTheme = storage.getAppTheme();
      _controlMode = storage.getControlMode();
      
      setState(() {});
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(context, 'ไม่สามารถโหลดการตั้งค่าได้', isError: true);
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveAppSettings() async {
    try {
      final storage = StorageService.instance;
      
      await storage.setNotificationEnabled(_notificationEnabled);
      await storage.setAutoRefresh(_autoRefresh);
      await storage.setAppTheme(_selectedTheme);
      await storage.setControlMode(_controlMode);
      
      if (mounted) {
        AppHelpers.showSnackBar(context, 'บันทึกการตั้งค่าแล้ว');
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(context, 'ไม่สามารถบันทึกการตั้งค่าได้', isError: true);
      }
    }
  }

  Future<void> _saveServerSettings() async {
    final serverUrl = _serverUrlController.text.trim();
    
    if (serverUrl.isEmpty) {
      AppHelpers.showSnackBar(context, 'กรุณาใส่ URL ของเซิร์ฟเวอร์', isError: true);
      return;
    }
    
    if (!AppHelpers.isValidUrl(serverUrl)) {
      AppHelpers.showSnackBar(context, 'URL ไม่ถูกต้อง', isError: true);
      return;
    }
    
    try {
      final storage = StorageService.instance;
      await storage.setServerUrl(serverUrl);
      
      // Update API service
      final apiService = Provider.of<ApiService>(context, listen: false);
      apiService.updateBaseUrl(serverUrl);
      
      if (mounted) {
        AppHelpers.showSnackBar(context, 'บันทึกการตั้งค่าเซิร์ฟเวอร์แล้ว');
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(context, 'ไม่สามารถบันทึกการตั้งค่าได้', isError: true);
      }
    }
  }

  Future<void> _saveMqttSettings() async {
    final mqttHost = _mqttHostController.text.trim();
    final mqttPortText = _mqttPortController.text.trim();
    
    if (mqttHost.isEmpty) {
      AppHelpers.showSnackBar(context, 'กรุณาใส่ host ของ MQTT broker', isError: true);
      return;
    }
    
    int mqttPort;
    try {
      mqttPort = int.parse(mqttPortText);
    } catch (e) {
      AppHelpers.showSnackBar(context, 'Port ต้องเป็นตัวเลข', isError: true);
      return;
    }
    
    if (!AppHelpers.isValidPort(mqttPort)) {
      AppHelpers.showSnackBar(context, 'Port ไม่ถูกต้อง (1-65535)', isError: true);
      return;
    }
    
    try {
      final storage = StorageService.instance;
      await storage.setMqttHost(mqttHost);
      await storage.setMqttPort(mqttPort);
      
      // Update MQTT service
      final mqttService = Provider.of<MqttService>(context, listen: false);
      mqttService.updateConnectionSettings(
        host: mqttHost,
        port: mqttPort,
      );
      
      if (mounted) {
        AppHelpers.showSnackBar(context, 'บันทึกการตั้งค่า MQTT แล้ว');
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(context, 'ไม่สามารถบันทึกการตั้งค่าได้', isError: true);
      }
    }
  }


  Future<void> _testConnection() async {
    AppHelpers.showLoadingOverlay(context);
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final mqttService = Provider.of<MqttService>(context, listen: false);
      
      // Test API connection with timeout
      bool apiConnected = false;
      try {
        apiConnected = await apiService.testConnection().timeout(
          const Duration(seconds: 5),
          onTimeout: () => false,
        );
      } catch (e) {
        apiConnected = false;
      }
      
      // Test MQTT connection with timeout
      bool mqttConnected = false;
      try {
        mqttConnected = await mqttService.connect().timeout(
          const Duration(seconds: 5),
          onTimeout: () => false,
        );
      } catch (e) {
        mqttConnected = false;
      }
      
      // รอสักครู่เพื่อให้การเชื่อมต่อเสร็จสมบูรณ์
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (mounted) {
        AppHelpers.hideLoadingOverlay(context);
        
        String message = 'ผลการทดสอบการเชื่อมต่อ:\n\n';
        message += '🌐 API Server: ${apiConnected ? '✅ เชื่อมต่อได้' : '❌ เชื่อมต่อไม่ได้'}\n';
        message += '📡 MQTT Broker: ${mqttConnected ? '✅ เชื่อมต่อได้' : '❌ เชื่อมต่อไม่ได้'}\n\n';
        
        if (apiConnected && mqttConnected) {
          message += '🎉 ระบบพร้อมใช้งาน!';
        } else if (apiConnected || mqttConnected) {
          message += '⚠️ ระบบใช้งานได้บางส่วน';
        } else {
          message += '❌ ระบบไม่สามารถเชื่อมต่อได้';
        }
        
        AppHelpers.showErrorDialog(
          context,
          'ผลการทดสอบ',
          message,
        );
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.hideLoadingOverlay(context);
        AppHelpers.showSnackBar(context, 'เกิดข้อผิดพลาดในการทดสอบ: $e', isError: true);
      }
    }
  }

  Future<void> _resetSettings() async {
    final confirmed = await AppHelpers.showConfirmDialog(
      context,
      'รีเซ็ตการตั้งค่า',
      'คุณต้องการรีเซ็ตการตั้งค่าทั้งหมดเป็นค่าเริ่มต้นหรือไม่?',
    );
    
    if (confirmed == true && mounted) {
      try {
        final storage = StorageService.instance;
        
        // Reset to default values
        await storage.setServerUrl(ApiConstants.baseUrl);
        await storage.setMqttHost(MqttConstants.brokerHost);
        await storage.setMqttPort(MqttConstants.brokerPort);
        await storage.setNotificationEnabled(true);
        await storage.setAutoRefresh(true);
        await storage.setRefreshInterval(AppConstants.defaultRefreshInterval);
        await storage.setAppTheme('system');
        
        // Reload settings
        _loadSettings();
        
        AppHelpers.showSnackBar(context, 'รีเซ็ตการตั้งค่าแล้ว');
      } catch (e) {
        AppHelpers.showSnackBar(context, 'ไม่สามารถรีเซ็ตการตั้งค่าได้', isError: true);
      }
    }
  }

  Future<void> _clearAllData() async {
    final confirmed = await AppHelpers.showConfirmDialog(
      context,
      'ล้างข้อมูลทั้งหมด',
      'คุณต้องการลบข้อมูลทั้งหมด รวมทั้งประวัติแชท และข้อมูล sensors หรือไม่?\n\nการกระทำนี้ไม่สามารถยกเลิกได้',
    );
    
    if (confirmed == true && mounted) {
      try {
        await StorageService.instance.clearAllData();
        AppHelpers.showSnackBar(context, 'ลบข้อมูลทั้งหมดแล้ว');
      } catch (e) {
        AppHelpers.showSnackBar(context, 'ไม่สามารถลบข้อมูลได้', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งค่า'),
        actions: [
          IconButton(
            onPressed: _testConnection,
            icon: const Icon(Icons.wifi_find),
            tooltip: 'ทดสอบการเชื่อมต่อ',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Server Settings
                _buildSection(
                  title: 'การตั้งค่าเซิร์ฟเวอร์',
                  icon: Icons.dns,
                  children: [
                    TextField(
                      controller: _serverUrlController,
                      decoration: const InputDecoration(
                        labelText: 'URL ของเซิร์ฟเวอร์',
                        hintText: 'http://35.247.182.78:8080',
                        prefixIcon: Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saveServerSettings,
                      child: const Text('บันทึกการตั้งค่าเซิร์ฟเวอร์'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // MQTT Settings
                _buildSection(
                  title: 'การตั้งค่า MQTT',
                  icon: Icons.router,
                  children: [
                    TextField(
                      controller: _mqttHostController,
                      decoration: const InputDecoration(
                        labelText: 'MQTT Broker Host',
                        hintText: 'broker.hivemq.com',
                        prefixIcon: Icon(Icons.computer),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _mqttPortController,
                      decoration: const InputDecoration(
                        labelText: 'MQTT Broker Port',
                        hintText: '1883',
                        prefixIcon: Icon(Icons.settings_input_component),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _saveMqttSettings,
                      child: const Text('บันทึกการตั้งค่า MQTT'),
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // App Settings
                _buildSection(
                  title: 'การตั้งค่าแอป',
                  icon: Icons.settings,
                  children: [
                    SwitchListTile(
                      title: const Text('การแจ้งเตือน'),
                      subtitle: const Text('เปิด/ปิดการแจ้งเตือน'),
                      value: _notificationEnabled,
                      onChanged: (value) {
                        setState(() => _notificationEnabled = value);
                        _saveAppSettings();
                      },
                    ),
                    SwitchListTile(
                      title: const Text('รีเฟรชอัตโนมัติ'),
                      subtitle: const Text('อัปเดตข้อมูลอัตโนมัติ'),
                      value: _autoRefresh,
                      onChanged: (value) {
                        setState(() => _autoRefresh = value);
                        _saveAppSettings();
                      },
                    ),
                    ListTile(
                      title: const Text('ธีม'),
                      subtitle: Text(_getThemeDisplayName(_selectedTheme)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showThemeDialog,
                    ),
                    ListTile(
                      title: const Text('โหมดการควบคุม'),
                      subtitle: Text(_getControlModeDisplayName(_controlMode)),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showControlModeDialog,
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // Connection Status
                _buildSection(
                  title: 'สถานะการเชื่อมต่อ',
                  icon: Icons.wifi,
                  children: [
                    Consumer<ApiService>(
                      builder: (context, apiService, child) {
                        return _buildConnectionTile(
                          'API Server',
                          apiService.isConnected,
                          apiService.lastError,
                        );
                      },
                    ),
                    Consumer<MqttService>(
                      builder: (context, mqttService, child) {
                        return _buildConnectionTile(
                          'MQTT Broker',
                          mqttService.isConnected,
                          mqttService.lastError,
                        );
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // System Actions
                _buildSection(
                  title: 'การจัดการระบบ',
                  icon: Icons.admin_panel_settings,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.refresh),
                      title: const Text('ทดสอบการเชื่อมต่อ'),
                      subtitle: const Text('ทดสอบการเชื่อมต่อกับเซิร์ฟเวอร์'),
                      onTap: _testConnection,
                    ),
                    ListTile(
                      leading: const Icon(Icons.restore),
                      title: const Text('รีเซ็ตการตั้งค่า'),
                      subtitle: const Text('รีเซ็ตการตั้งค่าเป็นค่าเริ่มต้น'),
                      onTap: _resetSettings,
                    ),
                    ListTile(
                      leading: Icon(Icons.delete_forever, color: AppTheme.errorColor),
                      title: Text(
                        'ล้างข้อมูลทั้งหมด',
                        style: TextStyle(color: AppTheme.errorColor),
                      ),
                      subtitle: const Text('ลบข้อมูลทั้งหมดและรีเซ็ตแอป'),
                      onTap: _clearAllData,
                    ),
                  ],
                ),
                
                const SizedBox(height: 24),
                
                // App Info
                _buildSection(
                  title: 'เกี่ยวกับแอป',
                  icon: Icons.info,
                  children: [
                    ListTile(
                      leading: const Icon(Icons.apps),
                      title: const Text('ชื่อแอป'),
                      subtitle: Text(AppConstants.appName),
                    ),
                    ListTile(
                      leading: const Icon(Icons.label),
                      title: const Text('เวอร์ชัน'),
                      subtitle: Text(AppConstants.appVersion),
                    ),
                    ListTile(
                      leading: const Icon(Icons.developer_mode),
                      title: const Text('ผู้พัฒนา'),
                      subtitle: const Text('Smart Home IoT Team'),
                    ),
                  ],
                ),
                
                // Bottom padding
                const SizedBox(height: 100),
              ],
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionTile(String title, bool isConnected, String? error) {
    return ListTile(
      leading: Icon(
        isConnected ? Icons.check_circle : Icons.error,
        color: isConnected ? AppTheme.successColor : AppTheme.errorColor,
      ),
      title: Text(title),
      subtitle: Text(
        isConnected 
            ? 'เชื่อมต่อแล้ว'
            : error ?? 'ไม่เชื่อมต่อ',
      ),
      trailing: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: isConnected ? AppTheme.successColor : AppTheme.errorColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  String _getThemeDisplayName(String theme) {
    switch (theme) {
      case 'light':
        return 'สว่าง';
      case 'dark':
        return 'มืด';
      case 'system':
      default:
        return 'ตามระบบ';
    }
  }

  String _getControlModeDisplayName(String mode) {
    switch (mode) {
      case 'api':
        return 'API Server (แนะนำ)';
      case 'mqtt':
        return 'MQTT Broker';
      case 'auto':
        return 'อัตโนมัติ (API แล้ว MQTT)';
      default:
        return 'API Server';
    }
  }


  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('เลือกธีม'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('ตามระบบ'),
                value: 'system',
                groupValue: _selectedTheme,
                onChanged: (value) {
                  setState(() => _selectedTheme = value!);
                  Navigator.pop(context);
                  _saveAppSettings();
                },
              ),
              RadioListTile<String>(
                title: const Text('สว่าง'),
                value: 'light',
                groupValue: _selectedTheme,
                onChanged: (value) {
                  setState(() => _selectedTheme = value!);
                  Navigator.pop(context);
                  _saveAppSettings();
                },
              ),
              RadioListTile<String>(
                title: const Text('มืด'),
                value: 'dark',
                groupValue: _selectedTheme,
                onChanged: (value) {
                  setState(() => _selectedTheme = value!);
                  Navigator.pop(context);
                  _saveAppSettings();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showControlModeDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('เลือกโหมดการควบคุม'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: const Text('API Server'),
                subtitle: const Text('ใช้ HTTP API (แนะนำ)'),
                value: 'api',
                groupValue: _controlMode,
                onChanged: (value) {
                  setState(() => _controlMode = value!);
                  Navigator.pop(context);
                  _saveAppSettings();
                },
              ),
              RadioListTile<String>(
                title: const Text('MQTT Broker'),
                subtitle: const Text('ใช้ MQTT Protocol'),
                value: 'mqtt',
                groupValue: _controlMode,
                onChanged: (value) {
                  setState(() => _controlMode = value!);
                  Navigator.pop(context);
                  _saveAppSettings();
                },
              ),
              RadioListTile<String>(
                title: const Text('อัตโนมัติ'),
                subtitle: const Text('API แล้ว MQTT (สำรอง)'),
                value: 'auto',
                groupValue: _controlMode,
                onChanged: (value) {
                  setState(() => _controlMode = value!);
                  Navigator.pop(context);
                  _saveAppSettings();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
