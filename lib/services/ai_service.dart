import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/voice_command.dart';
import '../models/device_status.dart';
import '../utils/constants.dart';
import '../config/api_keys.dart';

class AiService {
  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _model = 'gpt-3.5-turbo';
  
  // ใช้ API key ของ OpenAI (ต้องตั้งค่าเอง)
  static const String _apiKey = ApiKeys.openaiApiKey;
  
  // ใช้ local AI model แทน (ไม่ต้องใช้ API key)
  static const bool _useLocalAI = true; // เปลี่ยนเป็น true เพื่อใช้ Local AI

  /// ประมวลผลคำสั่งเสียงและแปลงเป็นคำสั่งควบคุม
  Future<VoiceCommand> processVoiceCommand(
    String voiceInput, 
    DeviceStatus? deviceStatus,
  ) async {
    try {
      if (_useLocalAI) {
        return _processWithLocalAI(voiceInput, deviceStatus);
      } else {
        return await _processWithOpenAI(voiceInput, deviceStatus);
      }
    } catch (e) {
      return VoiceCommand(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        command: voiceInput,
        result: 'เกิดข้อผิดพลาดในการประมวลผล: $e',
        timestamp: DateTime.now(),
        isSuccess: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// ใช้ Local AI Logic แทน OpenAI API
  VoiceCommand _processWithLocalAI(String voiceInput, DeviceStatus? deviceStatus) {
    final input = voiceInput.toLowerCase().trim();
    final timestamp = DateTime.now();
    final id = timestamp.millisecondsSinceEpoch.toString();

    // คำสั่งควบคุมไฟ
    if (input.contains('เปิดไฟ') || input.contains('ไฟเปิด')) {
      return VoiceCommand(
        id: id,
        command: voiceInput,
        result: 'สั่งเปิดไฟแล้ว ✅',
        timestamp: timestamp,
        isSuccess: true,
      );
    }
    
    if (input.contains('ปิดไฟ') || input.contains('ไฟปิด')) {
      return VoiceCommand(
        id: id,
        command: voiceInput,
        result: 'สั่งปิดไฟแล้ว ✅',
        timestamp: timestamp,
        isSuccess: true,
      );
    }

    // คำสั่งควบคุมพัดลม
    if (input.contains('เปิดพัดลม') || input.contains('พัดลมเปิด') || 
        input.contains('เปิดพัดลม') || input.contains('พัดลม') && input.contains('เปิด')) {
      return VoiceCommand(
        id: id,
        command: voiceInput,
        result: 'สั่งเปิดพัดลมแล้ว ✅',
        timestamp: timestamp,
        isSuccess: true,
      );
    }
    
    if (input.contains('ปิดพัดลม') || input.contains('พัดลมปิด') || 
        input.contains('ปิดพัดลม') || input.contains('พัดลม') && input.contains('ปิด')) {
      return VoiceCommand(
        id: id,
        command: voiceInput,
        result: 'สั่งปิดพัดลมแล้ว ✅',
        timestamp: timestamp,
        isSuccess: true,
      );
    }

    // คำสั่งควบคุมแอร์
    if (input.contains('เปิดแอร์') || input.contains('แอร์เปิด') || input.contains('เปิดแอร์คอนดิชั่น')) {
      return VoiceCommand(
        id: id,
        command: voiceInput,
        result: 'สั่งเปิดแอร์แล้ว ✅',
        timestamp: timestamp,
        isSuccess: true,
      );
    }
    
    if (input.contains('ปิดแอร์') || input.contains('แอร์ปิด') || input.contains('ปิดแอร์คอนดิชั่น')) {
      return VoiceCommand(
        id: id,
        command: voiceInput,
        result: 'สั่งปิดแอร์แล้ว ✅',
        timestamp: timestamp,
        isSuccess: true,
      );
    }

    // คำสั่งควบคุมปั๊มน้ำ
    if (input.contains('เปิดปั๊มน้ำ') || input.contains('ปั๊มน้ำเปิด') || input.contains('เปิดปั๊ม')) {
      return VoiceCommand(
        id: id,
        command: voiceInput,
        result: 'สั่งเปิดปั๊มน้ำแล้ว ✅',
        timestamp: timestamp,
        isSuccess: true,
      );
    }
    
    if (input.contains('ปิดปั๊มน้ำ') || input.contains('ปั๊มน้ำปิด') || input.contains('ปิดปั๊ม')) {
      return VoiceCommand(
        id: id,
        command: voiceInput,
        result: 'สั่งปิดปั๊มน้ำแล้ว ✅',
        timestamp: timestamp,
        isSuccess: true,
      );
    }

    // คำสั่งควบคุมฮีทเตอร์
    if (input.contains('เปิดฮีทเตอร์') || input.contains('ฮีทเตอร์เปิด') || input.contains('เปิดเครื่องทำความร้อน')) {
      return VoiceCommand(
        id: id,
        command: voiceInput,
        result: 'สั่งเปิดฮีทเตอร์แล้ว ✅',
        timestamp: timestamp,
        isSuccess: true,
      );
    }
    
    if (input.contains('ปิดฮีทเตอร์') || input.contains('ฮีทเตอร์ปิด') || input.contains('ปิดเครื่องทำความร้อน')) {
      return VoiceCommand(
        id: id,
        command: voiceInput,
        result: 'สั่งปิดฮีทเตอร์แล้ว ✅',
        timestamp: timestamp,
        isSuccess: true,
      );
    }

    // คำสั่งควบคุมอุปกรณ์เพิ่มเติม
    if (input.contains('เปิดอุปกรณ์เพิ่มเติม') || input.contains('อุปกรณ์เพิ่มเติมเปิด') || input.contains('เปิดอุปกรณ์พิเศษ')) {
      return VoiceCommand(
        id: id,
        command: voiceInput,
        result: 'สั่งเปิดอุปกรณ์เพิ่มเติมแล้ว ✅',
        timestamp: timestamp,
        isSuccess: true,
      );
    }
    
    if (input.contains('ปิดอุปกรณ์เพิ่มเติม') || input.contains('อุปกรณ์เพิ่มเติมปิด') || input.contains('ปิดอุปกรณ์พิเศษ')) {
      return VoiceCommand(
        id: id,
        command: voiceInput,
        result: 'สั่งปิดอุปกรณ์เพิ่มเติมแล้ว ✅',
        timestamp: timestamp,
        isSuccess: true,
      );
    }

    // คำสั่งควบคุมทั้งหมด
    if (input.contains('เปิดทั้งหมด') || input.contains('เปิดทุกอย่าง')) {
      return VoiceCommand(
        id: id,
        command: voiceInput,
        result: 'สั่งเปิดอุปกรณ์ทั้งหมดแล้ว ✅',
        timestamp: timestamp,
        isSuccess: true,
      );
    }
    
    if (input.contains('ปิดทั้งหมด') || input.contains('ปิดทุกอย่าง')) {
      return VoiceCommand(
        id: id,
        command: voiceInput,
        result: 'สั่งปิดอุปกรณ์ทั้งหมดแล้ว ✅',
        timestamp: timestamp,
        isSuccess: true,
      );
    }

    // คำสั่งสอบถามสถานะ
    if (input.contains('สถานะ') || input.contains('เป็นอย่างไร')) {
      if (deviceStatus != null) {
        final result = '''
สถานะอุปกรณ์:
• ไฟ: ${deviceStatus.relay1 ? 'เปิด' : 'ปิด'}
• พัดลม: ${deviceStatus.relay2 ? 'เปิด' : 'ปิด'}
• อุณหภูมิ: ${deviceStatus.temperature.toStringAsFixed(1)}°C
• ความชื้น: ${deviceStatus.humidity.toStringAsFixed(1)}%
• ก๊าซ: ${deviceStatus.gasLevel} ppm
• การเชื่อมต่อ: ${deviceStatus.online ? 'ออนไลน์' : 'ออฟไลน์'}
        '''.trim();
        
        return VoiceCommand(
          id: id,
          command: voiceInput,
          result: result,
          timestamp: timestamp,
          isSuccess: true,
        );
      } else {
        return VoiceCommand(
          id: id,
          command: voiceInput,
          result: 'ไม่สามารถดึงข้อมูลสถานะได้ - อุปกรณ์อาจออฟไลน์',
          timestamp: timestamp,
          isSuccess: false,
          errorMessage: 'อุปกรณ์ออฟไลน์',
        );
      }
    }

    // คำสั่งสอบถามอุณหภูมิ
    if (input.contains('อุณหภูมิ') || input.contains('ร้อน') || input.contains('เย็น')) {
      if (deviceStatus != null) {
        final temp = deviceStatus.temperature;
        String status;
        if (temp < 20) status = 'เย็น';
        else if (temp < 30) status = 'ปกติ';
        else status = 'ร้อน';
        
        return VoiceCommand(
          id: id,
          command: voiceInput,
          result: 'อุณหภูมิปัจจุบัน: ${temp.toStringAsFixed(1)}°C ($status)',
          timestamp: timestamp,
          isSuccess: true,
        );
      } else {
        return VoiceCommand(
          id: id,
          command: voiceInput,
          result: 'ไม่สามารถดึงข้อมูลอุณหภูมิได้',
          timestamp: timestamp,
          isSuccess: false,
          errorMessage: 'อุปกรณ์ออฟไลน์',
        );
      }
    }

    // คำสั่งสอบถามความชื้น
    if (input.contains('ความชื้น') || input.contains('ชื้น')) {
      if (deviceStatus != null) {
        final humidity = deviceStatus.humidity;
        String status;
        if (humidity < 30) status = 'แห้ง';
        else if (humidity < 70) status = 'ปกติ';
        else status = 'ชื้น';
        
        return VoiceCommand(
          id: id,
          command: voiceInput,
          result: 'ความชื้นปัจจุบัน: ${humidity.toStringAsFixed(1)}% ($status)',
          timestamp: timestamp,
          isSuccess: true,
        );
      } else {
        return VoiceCommand(
          id: id,
          command: voiceInput,
          result: 'ไม่สามารถดึงข้อมูลความชื้นได้',
          timestamp: timestamp,
          isSuccess: false,
          errorMessage: 'อุปกรณ์ออฟไลน์',
        );
      }
    }

    // คำสั่งช่วยเหลือ
    if (input.contains('ช่วย') || input.contains('ช่วยเหลือ') || input.contains('ทำอะไรได้')) {
      return VoiceCommand(
        id: id,
        command: voiceInput,
        result: '''
คำสั่งที่สามารถใช้ได้:
• "เปิดไฟ" หรือ "ปิดไฟ"
• "เปิดพัดลม" หรือ "ปิดพัดลม"
• "เปิดทั้งหมด" หรือ "ปิดทั้งหมด"
• "สถานะอุปกรณ์เป็นอย่างไร"
• "อุณหภูมิเท่าไหร่"
• "ความชื้นเท่าไหร่"
        '''.trim(),
        timestamp: timestamp,
        isSuccess: true,
      );
    }

    // คำสั่งที่ไม่รู้จัก
    return VoiceCommand(
      id: id,
      command: voiceInput,
      result: 'ขออภัย ไม่เข้าใจคำสั่ง "$voiceInput" ลองพูด "ช่วยเหลือ" เพื่อดูคำสั่งที่ใช้ได้',
      timestamp: timestamp,
      isSuccess: false,
      errorMessage: 'คำสั่งไม่รู้จัก',
    );
  }

  /// ใช้ OpenAI API (ต้องมี API key)
  Future<VoiceCommand> _processWithOpenAI(String voiceInput, DeviceStatus? deviceStatus) async {
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };

    final context = deviceStatus != null ? '''
สถานะปัจจุบันของระบบ:
- ไฟ: ${deviceStatus.relay1 ? 'เปิด' : 'ปิด'}
- พัดลม: ${deviceStatus.relay2 ? 'เปิด' : 'ปิด'}
- แอร์: ${deviceStatus.relay3 ? 'เปิด' : 'ปิด'}
- ปั๊มน้ำ: ${deviceStatus.relay4 ? 'เปิด' : 'ปิด'}
- ฮีทเตอร์: ${deviceStatus.relay5 ? 'เปิด' : 'ปิด'}
- อุปกรณ์เพิ่มเติม: ${deviceStatus.relay6 ? 'เปิด' : 'ปิด'}
- อุณหภูมิ: ${deviceStatus.temperature}°C
- ความชื้น: ${deviceStatus.humidity}%
- ก๊าซ: ${deviceStatus.gasLevel} ppm
- การเชื่อมต่อ: ${deviceStatus.online ? 'เชื่อมต่อ' : 'ไม่เชื่อมต่อ'}
''' : '';

    final prompt = '''
คุณเป็น AI Assistant สำหรับระบบ Smart Home ที่ควบคุมอุปกรณ์ต่างๆ

อุปกรณ์ที่สามารถควบคุมได้:
- ไฟ (relay1)
- พัดลม (relay2) 
- แอร์/แอร์คอนดิชั่น (relay3)
- ปั๊มน้ำ (relay4)
- ฮีทเตอร์/เครื่องทำความร้อน (relay5)
- อุปกรณ์เพิ่มเติม (relay6)

$context

คำสั่งของผู้ใช้: "$voiceInput"

**สำคัญ: ตอบแบบผู้ชายเสมอ ใช้ "ครับ" แทน "ค่ะ" และพูดช้าๆ ชัดๆ**

กรุณาตอบกลับเป็นภาษาไทยและระบุ:
1. การกระทำที่จะทำ (ถ้ามี)
2. สถานะปัจจุบัน (ถ้าสอบถาม)
3. คำแนะนำเพิ่มเติม (ถ้าจำเป็น)

**ตอบแบบผู้ชายเสมอ และพูดช้าๆ ชัดๆ:**
- ✅ "ครับ" ✅ "ครับครับ" ✅ "ได้ครับ"
- ❌ ไม่ใช้ "ค่ะ" ❌ ไม่ใช้ "ค่ะค่ะ" ❌ ไม่ใช้ "ได้ค่ะ"

ตัวอย่างการตอบ:
- "เปิดไฟแล้วครับ" (ไม่ใช่ "เปิดไฟแล้วค่ะ")
- "อุณหภูมิ 25 องศาเซลเซียสครับ" (ไม่ใช่ "อุณหภูมิ 25 องศาเซลเซียสค่ะ")
- "พัดลมปิดแล้วครับ" (ไม่ใช่ "พัดลมปิดแล้วค่ะ")

ตอบกลับสั้นๆ และชัดเจน:
''';

    final body = {
      'model': _model,
      'messages': [
        {
          'role': 'system',
          'content': '''คุณเป็น AI Assistant สำหรับระบบ Smart Home ที่ควบคุมไฟและพัดลม

**สำคัญ: ตอบแบบผู้ชายเสมอ ใช้ "ครับ" แทน "ค่ะ"**

คำสั่งที่รองรับ:
- เปิด/ปิดไฟ: ใช้คำสั่ง "เปิดไฟ" หรือ "ปิดไฟ"
- เปิด/ปิดพัดลม: ใช้คำสั่ง "เปิดพัดลม" หรือ "ปิดพัดลม"
- ดูสถานะ: ใช้คำสั่ง "สถานะอุปกรณ์" หรือ "อุณหภูมิเท่าไหร่"

**ตอบแบบผู้ชายเสมอ:**
- ✅ "ครับ" ✅ "ครับครับ" ✅ "ได้ครับ"
- ❌ ไม่ใช้ "ค่ะ" ❌ ไม่ใช้ "ค่ะค่ะ" ❌ ไม่ใช้ "ได้ค่ะ"

**การตอบอุณหภูมิ:**
- ต้องตอบชัดเจน เช่น "31 องศาเซลเซียส" (ไม่ใช่ "31°C" หรือ "31C")
- ต้องมีคำว่า "องศาเซลเซียส" เสมอ
- ตัวอย่าง: "อุณหภูมิปัจจุบัน 31 องศาเซลเซียสครับ"

ตัวอย่างการตอบ:
- "เปิดไฟแล้วครับ" (ไม่ใช่ "เปิดไฟแล้วค่ะ")
- "อุณหภูมิ 25 องศาเซลเซียสครับ" (ไม่ใช่ "25°C" หรือ "25C")
- "พัดลมปิดแล้วครับ" (ไม่ใช่ "พัดลมปิดแล้วค่ะ")''',
        },
        {
          'role': 'user',
          'content': prompt,
        },
      ],
      'max_tokens': 200,
      'temperature': 0.7,
    };

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: headers,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final content = data['choices'][0]['message']['content'];
      
      return VoiceCommand(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        command: voiceInput,
        result: content,
        timestamp: DateTime.now(),
        isSuccess: true,
      );
    } else {
      throw Exception('OpenAI API Error: ${response.statusCode}');
    }
  }

  /// ตรวจสอบว่าเป็นคำสั่งควบคุมหรือไม่
  bool isControlCommand(String voiceInput) {
    final input = voiceInput.toLowerCase();
    return input.contains('เปิด') || 
           input.contains('ปิด') || 
           input.contains('ควบคุม') ||
           input.contains('สั่ง') ||
           input.contains('ไฟ') ||
           input.contains('พัดลม') ||
           input.contains('แอร์') ||
           input.contains('แอร์คอนดิชั่น') ||
           input.contains('ปั๊มน้ำ') ||
           input.contains('ปั๊ม') ||
           input.contains('ฮีทเตอร์') ||
           input.contains('เครื่องทำความร้อน') ||
           input.contains('อุปกรณ์เพิ่มเติม') ||
           input.contains('อุปกรณ์พิเศษ') ||
           input.contains('ทั้งหมด') ||
           input.contains('ทุกอย่าง');
  }

  /// ตรวจสอบว่าเป็นคำสั่งสอบถามหรือไม่
  bool isQueryCommand(String voiceInput) {
    final input = voiceInput.toLowerCase();
    return input.contains('อะไร') || 
           input.contains('เท่าไหร่') || 
           input.contains('เป็นอย่างไร') ||
           input.contains('สถานะ') ||
           input.contains('อุณหภูมิ') ||
           input.contains('ความชื้น');
  }
}
