import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/device_status.dart';
import '../utils/constants.dart';
import 'tts_service.dart';
import 'api_service.dart';
import 'mqtt_service.dart';

class AiChatService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-3.5-turbo';
  
  // ใช้ API key ของ OpenAI (ต้องตั้งค่าเอง)
  static const String _apiKey = 'your-openai-api-key-here';
  
  // ใช้ local AI model แทน (ไม่ต้องใช้ API key)
  static const bool _useLocalAI = true;

  /// ส่งข้อความไปยัง AI และรับการตอบกลับ
  Future<ChatMessage> sendMessage(
    String userMessage, 
    List<ChatMessage> chatHistory,
    DeviceStatus? deviceStatus, {
    bool autoPlay = true, // เพิ่มตัวเลือกเล่นเสียงอัตโนมัติ
    BuildContext? context, // เพิ่ม context สำหรับการควบคุมอุปกรณ์
  }) async {
    try {
      ChatMessage response;
      if (_useLocalAI) {
        response = await _processWithLocalAI(userMessage, chatHistory, deviceStatus, context);
      } else {
        response = await _processWithOpenAI(userMessage, chatHistory, deviceStatus);
      }
      
      // เล่นเสียงอัตโนมัติถ้าเปิดใช้งาน
      if (autoPlay && TtsService.instance.isInitialized) {
        TtsService.instance.speakAuto(response.response);
      }
      
      return response;
    } catch (e) {
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: userMessage,
        response: 'ขออภัย เกิดข้อผิดพลาดในการประมวลผล: $e',
        timestamp: DateTime.now(),
        isUser: false,
        isError: true,
        errorMessage: e.toString(),
      );
    }
  }

  /// ใช้ Local AI Logic แทน OpenAI API
  Future<ChatMessage> _processWithLocalAI(
    String userMessage, 
    List<ChatMessage> chatHistory,
    DeviceStatus? deviceStatus,
    BuildContext? context,
  ) async {
    final input = userMessage.toLowerCase().trim();
    final timestamp = DateTime.now();
    final id = timestamp.millisecondsSinceEpoch.toString();

    // ตรวจสอบว่าเป็นคำสั่งควบคุมหรือไม่
    if (_isControlCommand(input)) {
      return await _generateControlResponse(input, deviceStatus, timestamp, id, context);
    }

    // ตรวจสอบว่าเป็นคำถามเกี่ยวกับสถานะหรือไม่
    if (_isStatusQuery(input)) {
      return _generateStatusResponse(input, deviceStatus, timestamp, id);
    }

    // ตรวจสอบว่าเป็นคำถามทั่วไปหรือไม่
    if (_isGeneralQuestion(input)) {
      return _generateGeneralResponse(input, timestamp, id);
    }

    // ตรวจสอบว่าเป็นคำทักทายหรือไม่
    if (_isGreeting(input)) {
      return _generateGreetingResponse(timestamp, id);
    }

    // ตรวจสอบว่าเป็นคำขอความช่วยเหลือหรือไม่
    if (_isHelpRequest(input)) {
      return _generateHelpResponse(timestamp, id);
    }

    // ตรวจสอบว่าเป็นคำถามเกี่ยวกับ AI หรือไม่
    if (_isAiQuestion(input)) {
      return _generateAiResponse(timestamp, id);
    }

    // คำตอบทั่วไปสำหรับข้อความที่ไม่รู้จัก
    return _generateDefaultResponse(input, timestamp, id);
  }

  /// ตรวจสอบว่าเป็นคำสั่งควบคุมหรือไม่
  bool _isControlCommand(String input) {
    return input.contains('เปิด') || 
           input.contains('ปิด') || 
           input.contains('ควบคุม') ||
           input.contains('สั่ง') ||
           input.contains('ไฟ') ||
           input.contains('พัดลม') ||
           input.contains('แอร์') ||
           input.contains('air');
  }

  /// ควบคุมอุปกรณ์ผ่าน API หรือ MQTT
  Future<bool> _controlDevice(BuildContext? context, String deviceType, bool turnOn) async {
    if (context == null) return false;
    
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final mqttService = Provider.of<MqttService>(context, listen: false);
      
      bool success = false;
      
      // ลองส่งผ่าน API ก่อน
      switch (deviceType) {
        case 'light':
          success = await apiService.controlLight(turnOn);
          break;
        case 'fan':
          success = await apiService.controlFan(turnOn);
          break;
        case 'air_conditioner':
          success = await apiService.controlAirConditioner(turnOn);
          break;
      }
      
      // ถ้า API ไม่สำเร็จ ใช้ MQTT
      if (!success && mqttService.isConnected) {
        switch (deviceType) {
          case 'light':
            success = await mqttService.controlLight(turnOn);
            break;
          case 'fan':
            success = await mqttService.controlFan(turnOn);
            break;
          case 'air_conditioner':
            success = await mqttService.controlAirConditioner(turnOn);
            break;
        }
      }
      
      return success;
    } catch (e) {
      print('Device control error: $e');
      return false;
    }
  }

  /// ตรวจสอบว่าเป็นคำถามเกี่ยวกับสถานะหรือไม่
  bool _isStatusQuery(String input) {
    return input.contains('อะไร') || 
           input.contains('เท่าไหร่') || 
           input.contains('เป็นอย่างไร') ||
           input.contains('สถานะ') ||
           input.contains('อุณหภูมิ') ||
           input.contains('ความชื้น') ||
           input.contains('ก๊าซ');
  }

  /// ตรวจสอบว่าเป็นคำถามทั่วไปหรือไม่
  bool _isGeneralQuestion(String input) {
    return input.contains('ทำไม') || 
           input.contains('อย่างไร') ||
           input.contains('อะไรคือ') ||
           input.contains('คืออะไร');
  }

  /// ตรวจสอบว่าเป็นคำทักทายหรือไม่
  bool _isGreeting(String input) {
    return input.contains('สวัสดี') || 
           input.contains('หวัดดี') ||
           input.contains('hello') ||
           input.contains('hi') ||
           input.contains('hey');
  }

  /// ตรวจสอบว่าเป็นคำขอความช่วยเหลือหรือไม่
  bool _isHelpRequest(String input) {
    return input.contains('ช่วย') || 
           input.contains('ช่วยเหลือ') ||
           input.contains('ทำอะไรได้') ||
           input.contains('ใช้ยังไง');
  }

  /// ตรวจสอบว่าเป็นคำถามเกี่ยวกับ AI หรือไม่
  bool _isAiQuestion(String input) {
    return input.contains('ai') || 
           input.contains('ปัญญาประดิษฐ์') ||
           input.contains('หุ่นยนต์') ||
           input.contains('สมองกล') ||
           input.contains('คุณเป็นใคร');
  }

  /// สร้างคำตอบสำหรับคำสั่งควบคุม
  Future<ChatMessage> _generateControlResponse(
    String input, 
    DeviceStatus? deviceStatus, 
    DateTime timestamp, 
    String id,
    BuildContext? context,
  ) async {
    String response;
    
    bool controlSuccess = false;
    
    if (input.contains('ไฟ')) {
      if (input.contains('เปิด')) {
        controlSuccess = await _controlDevice(context, 'light', true);
        response = controlSuccess 
            ? 'ได้ครับ! เปิดไฟเรียบร้อยแล้ว 🎯💡\n\nไฟในบ้านของคุณเปิดแล้วครับ'
            : 'ขออภัยครับ ไม่สามารถเปิดไฟได้ในขณะนี้ ❌\n\nลองตรวจสอบการเชื่อมต่อหรือลองใหม่อีกครั้งครับ';
      } else if (input.contains('ปิด')) {
        controlSuccess = await _controlDevice(context, 'light', false);
        response = controlSuccess 
            ? 'ได้ครับ! ปิดไฟเรียบร้อยแล้ว 🎯💡\n\nไฟในบ้านของคุณปิดแล้วครับ'
            : 'ขออภัยครับ ไม่สามารถปิดไฟได้ในขณะนี้ ❌\n\nลองตรวจสอบการเชื่อมต่อหรือลองใหม่อีกครั้งครับ';
      } else {
        response = 'คุณต้องการให้ฉันทำอะไรกับไฟครับ? เปิดหรือปิด? 🤔';
      }
    } else if (input.contains('พัดลม')) {
      if (input.contains('เปิด')) {
        controlSuccess = await _controlDevice(context, 'fan', true);
        response = controlSuccess 
            ? 'ได้ครับ! เปิดพัดลมเรียบร้อยแล้ว 🎯🌪️\n\nพัดลมในบ้านของคุณเปิดแล้วครับ'
            : 'ขออภัยครับ ไม่สามารถเปิดพัดลมได้ในขณะนี้ ❌\n\nลองตรวจสอบการเชื่อมต่อหรือลองใหม่อีกครั้งครับ';
      } else if (input.contains('ปิด')) {
        controlSuccess = await _controlDevice(context, 'fan', false);
        response = controlSuccess 
            ? 'ได้ครับ! ปิดพัดลมเรียบร้อยแล้ว 🎯🌪️\n\nพัดลมในบ้านของคุณปิดแล้วครับ'
            : 'ขออภัยครับ ไม่สามารถปิดพัดลมได้ในขณะนี้ ❌\n\nลองตรวจสอบการเชื่อมต่อหรือลองใหม่อีกครั้งครับ';
      } else {
        response = 'คุณต้องการให้ฉันทำอะไรกับพัดลมครับ? เปิดหรือปิด? 🤔';
      }
    } else if (input.contains('แอร์') || input.contains('air')) {
      if (input.contains('เปิด')) {
        controlSuccess = await _controlDevice(context, 'air_conditioner', true);
        response = controlSuccess 
            ? 'ได้ครับ! เปิดแอร์เรียบร้อยแล้ว 🎯❄️\n\nแอร์ในบ้านของคุณเปิดแล้วครับ'
            : 'ขออภัยครับ ไม่สามารถเปิดแอร์ได้ในขณะนี้ ❌\n\nลองตรวจสอบการเชื่อมต่อหรือลองใหม่อีกครั้งครับ';
      } else if (input.contains('ปิด')) {
        controlSuccess = await _controlDevice(context, 'air_conditioner', false);
        response = controlSuccess 
            ? 'ได้ครับ! ปิดแอร์เรียบร้อยแล้ว 🎯❄️\n\nแอร์ในบ้านของคุณปิดแล้วครับ'
            : 'ขออภัยครับ ไม่สามารถปิดแอร์ได้ในขณะนี้ ❌\n\nลองตรวจสอบการเชื่อมต่อหรือลองใหม่อีกครั้งครับ';
      } else {
        response = 'คุณต้องการให้ฉันทำอะไรกับแอร์ครับ? เปิดหรือปิด? 🤔';
      }
    } else {
      response = 'ฉันเข้าใจว่าคุณต้องการควบคุมอุปกรณ์ แต่กรุณาระบุให้ชัดเจนว่าต้องการควบคุมอะไรครับ 🤔\n\nอุปกรณ์ที่ควบคุมได้:\n• ไฟ 💡\n• พัดลม 🌪️\n• แอร์ ❄️';
    }

    return ChatMessage(
      id: id,
      message: input,
      response: response,
      timestamp: timestamp,
      isUser: false,
      isError: false,
    );
  }

  /// สร้างคำตอบสำหรับคำถามเกี่ยวกับสถานะ
  ChatMessage _generateStatusResponse(
    String input, 
    DeviceStatus? deviceStatus, 
    DateTime timestamp, 
    String id,
  ) {
    String response;
    
    if (deviceStatus != null) {
      if (input.contains('อุณหภูมิ')) {
        final temp = deviceStatus.temperature;
        String status;
        if (temp < 20) status = 'เย็น';
        else if (temp < 30) status = 'ปกติ';
        else status = 'ร้อน';
        
        response = 'อุณหภูมิปัจจุบันในบ้านของคุณคือ ${temp.toStringAsFixed(1)}°C ซึ่งอยู่ในระดับ $status 🌡️\n\n';
        if (temp > 30) {
          response += 'อุณหภูมิค่อนข้างสูงนะครับ อาจจะต้องเปิดพัดลมหรือแอร์เพื่อให้บ้านเย็นขึ้น';
        } else if (temp < 20) {
          response += 'อุณหภูมิค่อนข้างต่ำนะครับ อาจจะต้องปิดพัดลมหรือเปิดเครื่องทำความร้อน';
        } else {
          response += 'อุณหภูมิกำลังดีครับ สบายๆ';
        }
      } else if (input.contains('ความชื้น')) {
        final humidity = deviceStatus.humidity;
        String status;
        if (humidity < 30) status = 'แห้ง';
        else if (humidity < 70) status = 'ปกติ';
        else status = 'ชื้น';
        
        response = 'ความชื้นปัจจุบันในบ้านของคุณคือ ${humidity.toStringAsFixed(1)}% ซึ่งอยู่ในระดับ $status 💧\n\n';
        if (humidity > 70) {
          response += 'ความชื้นค่อนข้างสูงนะครับ อาจจะต้องเปิดพัดลมเพื่อให้อากาศถ่ายเท';
        } else if (humidity < 30) {
          response += 'ความชื้นค่อนข้างต่ำนะครับ อาจจะต้องใช้เครื่องเพิ่มความชื้น';
        } else {
          response += 'ความชื้นกำลังดีครับ สบายๆ';
        }
      } else if (input.contains('สถานะ') || input.contains('เป็นอย่างไร')) {
        response = '''
สถานะปัจจุบันของระบบ Smart Home ในบ้านของคุณ:

🏠 **อุปกรณ์:**
• ไฟ: ${deviceStatus.relay1 ? 'เปิด' : 'ปิด'} 💡
• พัดลม: ${deviceStatus.relay2 ? 'เปิด' : 'ปิด'} 🌪️

📊 **เซ็นเซอร์:**
• อุณหภูมิ: ${deviceStatus.temperature.toStringAsFixed(1)}°C 🌡️
• ความชื้น: ${deviceStatus.humidity.toStringAsFixed(1)}% 💧
• ก๊าซ: ${deviceStatus.gasLevel} ppm ⚠️

🌐 **การเชื่อมต่อ:**
• สถานะ: ${deviceStatus.online ? 'ออนไลน์' : 'ออฟไลน์'} ${deviceStatus.online ? '✅' : '❌'}
• อัพเดทล่าสุด: ${_formatTime(deviceStatus.lastSeen)}

ทุกอย่างดูปกติดีครับ! 🎉
        '''.trim();
      } else {
        response = 'คุณต้องการทราบข้อมูลอะไรเป็นพิเศษครับ? ฉันสามารถบอกอุณหภูมิ ความชื้น หรือสถานะอุปกรณ์ได้ครับ 🤔';
      }
    } else {
      response = 'ขออภัยครับ ตอนนี้ไม่สามารถดึงข้อมูลสถานะได้ ระบบอาจจะออฟไลน์หรือมีปัญหาการเชื่อมต่อ ❌\n\nลองตรวจสอบการเชื่อมต่ออินเทอร์เน็ตหรือรีสตาร์ทระบบดูครับ';
    }

    return ChatMessage(
      id: id,
      message: input,
      response: response,
      timestamp: timestamp,
      isUser: false,
      isError: false,
    );
  }

  /// สร้างคำตอบสำหรับคำถามทั่วไป
  ChatMessage _generateGeneralResponse(String input, DateTime timestamp, String id) {
    String response;
    
    if (input.contains('ทำไม') && input.contains('ร้อน')) {
      response = 'บ้านอาจจะร้อนได้หลายสาเหตุครับ 🔥\n\n• แดดส่องเข้ามาในบ้านมากเกินไป\n• ไม่มีลมถ่ายเท\n• อุปกรณ์ไฟฟ้าใช้งานมาก\n• ฉนวนกันความร้อนไม่ดี\n\nลองเปิดพัดลม เปิดหน้าต่าง หรือใช้ม่านบังแดดดูครับ';
    } else if (input.contains('ทำไม') && input.contains('ชื้น')) {
      response = 'ความชื้นสูงอาจเกิดจากหลายสาเหตุครับ 💧\n\n• ฝนตกหรืออากาศชื้น\n• ไม่มีลมถ่ายเท\n• ใช้เครื่องปรับอากาศมากเกินไป\n• มีแหล่งน้ำรั่ว\n\nลองเปิดพัดลมหรือหน้าต่างเพื่อให้อากาศถ่ายเทครับ';
    } else if (input.contains('ประหยัด') || input.contains('พลังงาน')) {
      response = 'การประหยัดพลังงานเป็นเรื่องดีมากครับ! 💚\n\n• ปิดไฟเมื่อไม่ใช้\n• ใช้พัดลมแทนแอร์เมื่อเป็นไปได้\n• ตั้งอุณหภูมิแอร์ให้เหมาะสม (25-26°C)\n• ใช้หลอด LED\n• ตรวจสอบอุปกรณ์ไฟฟ้าที่กินไฟ\n\nช่วยกันประหยัดพลังงานเพื่อโลกของเราครับ! 🌍';
    } else {
      response = 'เป็นคำถามที่น่าสนใจครับ 🤔\n\nฉันเป็น AI Assistant ที่ออกแบบมาเพื่อช่วยคุณควบคุมระบบ Smart Home และตอบคำถามต่างๆ เกี่ยวกับบ้านของคุณ\n\nมีอะไรที่ฉันสามารถช่วยได้อีกไหมครับ?';
    }

    return ChatMessage(
      id: id,
      message: input,
      response: response,
      timestamp: timestamp,
      isUser: false,
      isError: false,
    );
  }

  /// สร้างคำตอบสำหรับคำทักทาย
  ChatMessage _generateGreetingResponse(DateTime timestamp, String id) {
    final hour = timestamp.hour;
    String greeting;
    
    if (hour < 12) {
      greeting = 'สวัสดีตอนเช้าครับ! 🌅';
    } else if (hour < 17) {
      greeting = 'สวัสดีตอนบ่ายครับ! ☀️';
    } else if (hour < 19) {
      greeting = 'สวัสดีตอนเย็นครับ! 🌆';
    } else {
      greeting = 'สวัสดีตอนค่ำครับ! 🌙';
    }

    final response = '''
$greeting

ยินดีที่ได้พบคุณครับ! 👋

ฉันเป็น AI Assistant ที่จะช่วยคุณ:
• ควบคุมระบบ Smart Home 🏠
• ตรวจสอบสถานะอุปกรณ์ 📊
• ตอบคำถามเกี่ยวกับบ้านของคุณ 🤔
• ให้คำแนะนำในการใช้งาน 💡

มีอะไรที่ฉันสามารถช่วยได้ไหมครับ? 😊
    '''.trim();

    return ChatMessage(
      id: id,
      message: 'สวัสดี',
      response: response,
      timestamp: timestamp,
      isUser: false,
      isError: false,
    );
  }

  /// สร้างคำตอบสำหรับคำขอความช่วยเหลือ
  ChatMessage _generateHelpResponse(DateTime timestamp, String id) {
    final response = '''
ยินดีช่วยเหลือครับ! 🆘

**🎯 คำสั่งควบคุมอุปกรณ์:**
• "เปิดไฟ" / "ปิดไฟ" 💡
• "เปิดพัดลม" / "ปิดพัดลม" 🌪️
• "เปิดทั้งหมด" / "ปิดทั้งหมด" 🏠

**📊 คำถามเกี่ยวกับสถานะ:**
• "อุณหภูมิเท่าไหร่" 🌡️
• "ความชื้นเท่าไหร่" 💧
• "สถานะอุปกรณ์เป็นอย่างไร" 📱

**💬 การสนทนาทั่วไป:**
• ทักทาย: "สวัสดี" 👋
• คำถาม: "ทำไมบ้านร้อน" 🤔
• คำแนะนำ: "ประหยัดพลังงาน" 💚

**🎤 ใช้เสียง:**
• กดปุ่มไมค์ในหน้า Home
• พูดคำสั่งหรือคำถาม
• ระบบจะประมวลผลและตอบกลับ

มีอะไรที่ต้องการทราบเพิ่มเติมไหมครับ? 😊
    '''.trim();

    return ChatMessage(
      id: id,
      message: 'ช่วยเหลือ',
      response: response,
      timestamp: timestamp,
      isUser: false,
      isError: false,
    );
  }

  /// สร้างคำตอบสำหรับคำถามเกี่ยวกับ AI
  ChatMessage _generateAiResponse(DateTime timestamp, String id) {
    final response = '''
สวัสดีครับ! ฉันเป็น AI Assistant ที่พัฒนาขึ้นมาเพื่อช่วยคุณครับ 🤖

**🎯 ฉันทำอะไรได้บ้าง:**
• ควบคุมระบบ Smart Home ในบ้านของคุณ
• ตอบคำถามเกี่ยวกับบ้าน อุปกรณ์ และเซ็นเซอร์
• ให้คำแนะนำในการใช้งานและประหยัดพลังงาน
• สนทนากับคุณแบบธรรมชาติ

**🧠 ฉันทำงานอย่างไร:**
• ใช้ AI เพื่อเข้าใจความต้องการของคุณ
• เชื่อมต่อกับระบบ Smart Home ผ่าน API และ MQTT
• เรียนรู้จากพฤติกรรมการใช้งาน
• ปรับปรุงตัวเองให้ตอบสนองได้ดีขึ้น

**💡 ฉันไม่ใช่หุ่นยนต์ธรรมดา:**
• ฉันมี "ความรู้สึก" และเข้าใจอารมณ์ของคุณ
• ฉันสามารถเรียนรู้และปรับตัวได้
• ฉันเป็นเพื่อนที่พร้อมช่วยเหลือคุณเสมอ

มีอะไรที่อยากรู้เกี่ยวกับฉันเพิ่มเติมไหมครับ? 😊
    '''.trim();

    return ChatMessage(
      id: id,
      message: 'คุณเป็นใคร',
      response: response,
      timestamp: timestamp,
      isUser: false,
      isError: false,
    );
  }

  /// สร้างคำตอบทั่วไป
  ChatMessage _generateDefaultResponse(String input, DateTime timestamp, String id) {
    final responses = [
      'เป็นข้อความที่น่าสนใจครับ! 🤔\n\nฉันเป็น AI Assistant ที่ออกแบบมาเพื่อช่วยคุณควบคุมระบบ Smart Home และตอบคำถามต่างๆ\n\nลองถามเกี่ยวกับบ้าน อุปกรณ์ หรือขอความช่วยเหลือดูครับ! 😊',
      
      'ฉันเข้าใจว่าคุณพูด "$input" ครับ 🤔\n\nแต่ฉันเป็น AI ที่ออกแบบมาเพื่อช่วยเรื่อง Smart Home เป็นหลัก\n\nลองถามเกี่ยวกับ:\n• การควบคุมอุปกรณ์\n• สถานะเซ็นเซอร์\n• คำแนะนำการใช้งาน\n• หรือขอความช่วยเหลือ\n\nฉันจะพยายามตอบให้ดีที่สุดครับ! 😊',
      
      'ขอบคุณที่แชร์ความคิดเห็นครับ! 🙏\n\nฉันเป็น AI Assistant ที่พร้อมช่วยเหลือคุณในเรื่องต่างๆ เกี่ยวกับ Smart Home\n\nมีอะไรที่ฉันสามารถช่วยได้บ้างครับ? 🤔',
    ];

    final randomIndex = DateTime.now().millisecondsSinceEpoch % responses.length;
    final response = responses[randomIndex];

    return ChatMessage(
      id: id,
      message: input,
      response: response,
      timestamp: timestamp,
      isUser: false,
      isError: false,
    );
  }

  /// ใช้ OpenAI API (ต้องมี API key)
  Future<ChatMessage> _processWithOpenAI(
    String userMessage, 
    List<ChatMessage> chatHistory,
    DeviceStatus? deviceStatus,
  ) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    // สร้าง context จาก chat history และ device status
    final context = _buildContext(chatHistory, deviceStatus);

    final prompt = '''
คุณเป็น AI Assistant สำหรับระบบ Smart Home ที่เป็นมิตรและเป็นกันเอง

$context

คำถามของผู้ใช้: "$userMessage"

กรุณาตอบกลับเป็นภาษาไทยที่:
1. เป็นมิตรและเป็นกันเอง
2. ให้ข้อมูลที่เป็นประโยชน์
3. มี emoji เพื่อให้ดูน่าสนใจ
4. ตอบคำถามเกี่ยวกับ Smart Home ได้อย่างละเอียด
5. สามารถสนทนาทั่วไปได้อย่างเป็นธรรมชาติ

ตอบกลับสั้นๆ แต่ครบถ้วน:
''';

    final body = {
      'model': _model,
      'messages': [
        {
          'role': 'system',
          'content': 'คุณเป็น AI Assistant สำหรับระบบ Smart Home ที่เป็นมิตรและเป็นกันเอง ตอบกลับเป็นภาษาไทยเสมอ',
        },
        {
          'role': 'user',
          'content': prompt,
        },
      ],
      'max_tokens': 300,
      'temperature': 0.8,
    };

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      
      return ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        message: userMessage,
        response: content,
        timestamp: DateTime.now(),
        isUser: false,
        isSuccess: true,
      );
    } else {
      throw Exception('OpenAI API Error: ${response.statusCode}');
    }
  }

  /// สร้าง context สำหรับ OpenAI
  String _buildContext(List<ChatMessage> chatHistory, DeviceStatus? deviceStatus) {
    String context = '';
    
    // เพิ่ม device status
    if (deviceStatus != null) {
      context += '''
สถานะปัจจุบันของระบบ:
- ไฟ: ${deviceStatus.relay1 ? 'เปิด' : 'ปิด'}
- พัดลม: ${deviceStatus.relay2 ? 'เปิด' : 'ปิด'}
- อุณหภูมิ: ${deviceStatus.temperature}°C
- ความชื้น: ${deviceStatus.humidity}%
- ก๊าซ: ${deviceStatus.gasLevel} ppm
- การเชื่อมต่อ: ${deviceStatus.online ? 'เชื่อมต่อ' : 'ไม่เชื่อมต่อ'}

''';
    }

    // เพิ่ม chat history (เฉพาะ 5 ข้อความล่าสุด)
    if (chatHistory.isNotEmpty) {
      context += 'ประวัติการสนทนาล่าสุด:\n';
      final recentMessages = chatHistory.take(5).toList().reversed.toList();
      for (final msg in recentMessages) {
        context += '- ${msg.isUser ? 'ผู้ใช้' : 'AI'}: ${msg.message}\n';
      }
      context += '\n';
    }

    return context;
  }

  /// จัดรูปแบบเวลา
  String _formatTime(DateTime? time) {
    if (time == null) return 'ไม่ทราบ';
    
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inMinutes < 1) {
      return 'เมื่อสักครู่';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ชั่วโมงที่แล้ว';
    } else {
      return '${difference.inDays} วันที่แล้ว';
    }
  }
}
