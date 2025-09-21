import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_message.dart';
import '../models/device_status.dart';
import '../models/voice_command.dart';
import '../services/storage_service.dart';
import '../services/ai_chat_service.dart';
import '../services/tts_service.dart';
import '../services/voice_command_service.dart';
import '../services/mqtt_service.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../utils/constants.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen>
    with AutomaticKeepAliveClientMixin {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _messageController = TextEditingController();
  final List<ChatMessage> _logMessages = [];
  bool _isLoading = false;
  bool _isTyping = false;
  DeviceStatus? _deviceStatus;
  late AiChatService _aiChatService;
  late TtsService _ttsService;
  VoiceCommandService? _voiceCommandService;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _aiChatService = AiChatService();
    _ttsService = TtsService.instance;
    _initializeLog();
    _addWelcomeMessage();
    _initializeTts();
    _setupVoiceCommandListeners();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _messageController.dispose();
    _ttsService.stop();
    super.dispose();
  }

  void _initializeLog() async {
    setState(() => _isLoading = true);
    
    // Load device status for context
    _deviceStatus = StorageService.instance.getDeviceStatus();
    
    setState(() => _isLoading = false);
  }

  void _setupVoiceCommandListeners() {
    // ใช้ Provider เพื่อเข้าถึง VoiceCommandService เดียวกับที่ใช้ใน Dashboard
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final voiceCommandService = Provider.of<VoiceCommandService>(context, listen: false);
        _voiceCommandService = voiceCommandService;
        
        // ฟังผลลัพธ์คำสั่งเสียง
        voiceCommandService.commandResultStream.listen((command) {
          if (mounted) {
            _addLogMessage(
              '🎤 คำสั่งเสียง: "${command.command}"',
              command.isSuccess ? command.result : '❌ ${command.result}',
              command.isSuccess ? Colors.green : Colors.red,
            );
          }
        });

        // ฟังการอัปเดตสถานะอุปกรณ์ (ปิดการแจ้งเตือนซ้ำ)
        voiceCommandService.deviceStatusUpdateStream.listen((status) {
          if (mounted) {
            // ไม่แสดง log สำหรับการอัปเดตสถานะเพื่อหลีกเลี่ยงการแจ้งเตือนซ้ำ
            print('Device status updated: ${status.online}');
          }
        });

        // เพิ่ม log สำหรับสถานะการเชื่อมต่อปัจจุบัน
        final mqttService = Provider.of<MqttService>(context, listen: false);
        final apiService = Provider.of<ApiService>(context, listen: false);
        
        _addLogMessage(
          '📡 MQTT Status',
          mqttService.isConnected ? 'เชื่อมต่ออยู่' : 'ไม่เชื่อมต่อ',
          mqttService.isConnected ? Colors.green : Colors.red,
        );

        _addLogMessage(
          '🌐 API Status',
          apiService.isConnected ? 'เชื่อมต่ออยู่' : 'ไม่เชื่อมต่อ',
          apiService.isConnected ? Colors.green : Colors.red,
        );
      }
    });
  }

  void _addLogMessage(String title, String message, Color color) {
    final logMessage = ChatMessage(
      id: const Uuid().v4(),
      message: title,
      response: message,
      timestamp: DateTime.now(),
      isUser: false,
    );
    
    setState(() {
      _logMessages.add(logMessage);
    });
    
    _scrollToBottom();
  }

  // ฟังก์ชันสำหรับเพิ่ม log จากภายนอก
  void addDeviceControlLog(String deviceName, bool isOn) {
    _addLogMessage(
      '🎛️ ควบคุมอุปกรณ์',
      '$deviceName ${isOn ? 'เปิด' : 'ปิด'}',
      isOn ? Colors.green : Colors.orange,
    );
  }

  void addConnectionLog(String service, bool isConnected) {
    _addLogMessage(
      '🔗 การเชื่อมต่อ',
      '$service ${isConnected ? 'เชื่อมต่อสำเร็จ' : 'ขาดการเชื่อมต่อ'}',
      isConnected ? Colors.green : Colors.red,
    );
  }



  void _addWelcomeMessage() {
    final welcomeMessage = ChatMessage(
      id: const Uuid().v4(),
      message: '📋 ระบบ Log เริ่มทำงาน',
      response: 'ยินดีต้อนรับสู่ระบบ Log ของ Smart Home! 📋\n\nที่นี่คุณจะเห็น:\n• 🎤 คำสั่งเสียงที่คุณใช้\n• 🔧 การอัปเดตสถานะอุปกรณ์\n• 💬 การสนทนากับ AI\n• 📊 ข้อมูลการทำงานของระบบ\n\nระบบจะบันทึกทุกการทำงานไว้ที่นี่ครับ!',
      timestamp: DateTime.now(),
      isUser: false,
    );
    
    setState(() {
      _logMessages.add(welcomeMessage);
    });
  }

  /// ส่งข้อความไปยัง AI
  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    // เพิ่มข้อความของผู้ใช้
    final userMessage = ChatMessage(
      id: const Uuid().v4(),
      message: message,
      response: '',
      timestamp: DateTime.now(),
      isUser: true,
    );

    setState(() {
      _logMessages.add(userMessage);
      _isTyping = true;
    });

    // ล้าง input
    _messageController.clear();

    // เลื่อนไปที่ข้อความล่าสุด
    _scrollToBottom();

    try {
             // ส่งข้อความไปยัง AI
       final aiResponse = await _aiChatService.sendMessage(
         message,
         _logMessages,
         _deviceStatus,
         autoPlay: _ttsService.isInitialized, // เล่นเสียงถ้า TTS เปิดอยู่
         context: context, // ส่ง context สำหรับการควบคุมอุปกรณ์
       );

      if (mounted) {
        setState(() {
          _logMessages.add(aiResponse);
          _isTyping = false;
        });
        
        // เลื่อนไปที่ข้อความล่าสุด
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _logMessages.add(ChatMessage(
            id: const Uuid().v4(),
            message: message,
            response: 'ขออภัย เกิดข้อผิดพลาดในการประมวลผล: $e',
            timestamp: DateTime.now(),
            isUser: false,
            isError: true,
            errorMessage: e.toString(),
          ));
          _isTyping = false;
        });
        
        _scrollToBottom();
      }
    }
  }

  /// เริ่มต้น TTS Service
  Future<void> _initializeTts() async {
    try {
      final success = await _ttsService.initialize();
      if (success) {
        print('TTS initialized successfully');
        setState(() {}); // อัพเดท UI
      } else {
        print('TTS initialization failed');
      }
    } catch (e) {
      print('TTS initialization error: $e');
    }
  }

  /// เปิด/ปิด TTS
  Future<void> _toggleTts() async {
    if (_ttsService.isInitialized) {
      await _ttsService.stop();
      // ปิด TTS โดยการ dispose และสร้างใหม่
      _ttsService.dispose();
      _ttsService = TtsService.instance;
    } else {
      await _ttsService.initialize();
    }
    setState(() {}); // อัพเดท UI
  }

  /// เล่นเสียงข้อความ
  Future<void> _playMessage(String text) async {
    try {
      if (_ttsService.isSpeaking) {
        await _ttsService.stop();
      } else {
        if (!_ttsService.isInitialized) {
          final success = await _ttsService.initialize();
          if (!success) {
            AppHelpers.showSnackBar(
              context, 
              'ไม่สามารถเริ่มต้นเสียง AI ได้', 
              isError: true
            );
            return;
          }
        }
        
        final success = await _ttsService.speakAuto(text);
        if (!success) {
          AppHelpers.showSnackBar(
            context, 
            'ไม่สามารถเล่นเสียงได้', 
            isError: true
          );
        }
      }
    } catch (e) {
      print('Error playing message: $e');
      AppHelpers.showSnackBar(
        context, 
        'เกิดข้อผิดพลาดในการเล่นเสียง: $e', 
        isError: true
      );
    }
  }

  /// เลื่อนไปที่ข้อความล่าสุด
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _clearLog() async {
    final confirmed = await AppHelpers.showConfirmDialog(
      context,
      'ล้างประวัติ Log',
      'คุณต้องการลบประวัติ Log ทั้งหมดหรือไม่?',
    );

    if (confirmed == true && mounted) {
      try {
        setState(() {
          _logMessages.clear();
        });
        _addWelcomeMessage();
        AppHelpers.showSnackBar(context, 'ลบประวัติ Log แล้ว');
      } catch (e) {
        AppHelpers.showSnackBar(context, 'ไม่สามารถลบประวัติได้', isError: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
             appBar: AppBar(
         title: const Text('AI Chat System Log'),
         actions: [
           // TTS Toggle Button
           IconButton(
             onPressed: () => _toggleTts(),
             icon: Icon(
               _ttsService.isInitialized ? Icons.volume_up : Icons.volume_off,
               color: _ttsService.isInitialized ? AppTheme.successColor : Colors.grey,
             ),
             tooltip: _ttsService.isInitialized ? 'ปิดเสียง AI' : 'เปิดเสียง AI',
           ),
           // Clear Log Button
           IconButton(
             onPressed: _clearLog,
             icon: const Icon(Icons.delete_sweep),
             tooltip: 'ล้างประวัติ Log',
           ),
         ],
       ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logMessages.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: _logMessages.length + (_isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _logMessages.length && _isTyping) {
                            return _buildTypingIndicator(theme);
                          }
                          final message = _logMessages[index];
                          return _buildLogMessage(message, theme);
                        },
                      ),
          ),
          
          // Input area
          _buildInputArea(theme),
        ],
      ),
    );
  }

    Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.assignment,
              size: 64,
              color: AppTheme.primaryColor,
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            '📋 System Log',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            'ระบบ Log ของ Smart Home\nที่นี่จะแสดงประวัติการทำงานทั้งหมด',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
           
           const SizedBox(height: 16),
           
           // TTS Status
           Container(
             padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
             decoration: BoxDecoration(
               color: _ttsService.isInitialized 
                   ? AppTheme.successColor.withOpacity(0.1)
                   : Colors.grey.withOpacity(0.1),
               borderRadius: BorderRadius.circular(20),
               border: Border.all(
                 color: _ttsService.isInitialized 
                     ? AppTheme.successColor
                     : Colors.grey,
                 width: 1,
               ),
             ),
             child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 Icon(
                   _ttsService.isInitialized ? Icons.volume_up : Icons.volume_off,
                   size: 16,
                   color: _ttsService.isInitialized 
                       ? AppTheme.successColor
                       : Colors.grey,
                 ),
                 const SizedBox(width: 8),
                 Text(
                   _ttsService.isInitialized 
                       ? 'เสียง AI เปิดใช้งาน'
                       : 'เสียง AI ปิดใช้งาน',
                   style: theme.textTheme.bodySmall?.copyWith(
                     color: _ttsService.isInitialized 
                         ? AppTheme.successColor
                         : Colors.grey,
                     fontWeight: FontWeight.w500,
                   ),
                 ),
               ],
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildLogMessage(ChatMessage message, ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (message.isUser) ...[
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomLeft: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      message.message,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppHelpers.formatDateTimeShort(message.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.person,
                color: Colors.white,
                size: 16,
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.successColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark 
                    ? Colors.grey[800] 
                    : Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                                         Text(
                       message.response,
                                             style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.brightness == Brightness.dark 
                          ? Colors.white 
                          : Colors.grey[800],
                      ),
                     ),
                     const SizedBox(height: 8),
                     Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         IconButton(
                           onPressed: () => _playMessage(message.response),
                           icon: Icon(
                             _ttsService.isSpeaking ? Icons.stop : Icons.volume_up,
                             size: 16,
                             color: AppTheme.successColor,
                           ),
                           tooltip: _ttsService.isSpeaking ? 'หยุดเสียง' : 'เล่นเสียง',
                           padding: EdgeInsets.zero,
                           constraints: const BoxConstraints(
                             minWidth: 24,
                             minHeight: 24,
                           ),
                         ),
                         if (_ttsService.isSpeaking)
                           SizedBox(
                             width: 16,
                             height: 16,
                             child: CircularProgressIndicator(
                               strokeWidth: 2,
                               valueColor: AlwaysStoppedAnimation<Color>(AppTheme.successColor),
                             ),
                           ),
                       ],
                     ),
                    const SizedBox(height: 4),
                    Text(
                      AppHelpers.formatDateTimeShort(message.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.successColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.smart_toy,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark 
                ? Colors.grey[800] 
                : Colors.grey[100],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI กำลังพิมพ์',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.brightness == Brightness.dark 
                      ? Colors.grey[300] 
                      : Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.successColor),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputArea(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark 
          ? Colors.grey[900] 
          : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: 'พิมพ์ข้อความของคุณ...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: theme.brightness == Brightness.dark 
                  ? Colors.grey[800] 
                  : Colors.grey[100],
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(24),
            ),
            child: IconButton(
              onPressed: _sendMessage,
              icon: const Icon(Icons.send, color: Colors.white),
              tooltip: 'ส่งข้อความ',
            ),
          ),
        ],
      ),
    );
  }
}
