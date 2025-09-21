# 🤖 Claude AI Prompt Guide - Smart Home Flutter App

## 🎯 **Copy และ Paste prompt นี้ไปยัง Claude:**

---

**ช่วยสร้าง Flutter Smart Home App ที่มี features ดังนี้:**

### 📱 **App Features:**
1. **Dashboard Screen** - แสดงสถานะอุปกรณ์และข้อมูล sensors
2. **Device Control Screen** - ควบคุมการเปิด/ปิดไฟ, พัดลม
3. **AI Chat Screen** - สนทนากับ AI Assistant
4. **Settings Screen** - ตั้งค่า app และ server

### 🔧 **Technical Requirements:**
- **Flutter Version**: 3.0+ (Dart 3.0+)
- **State Management**: Provider pattern
- **HTTP Client**: Dio หรือ http package
- **MQTT Client**: mqtt_client package
- **Local Storage**: SharedPreferences + SQLite
- **UI Framework**: Material Design 3

### 🌐 **Server Integration:**
- **Base URL**: `http://35.247.182.78:8080`
- **API Endpoints**:
  - `GET /api/status` - สถานะอุปกรณ์
  - `POST /api/chat` - AI Chat
  - `POST /api/control` - ควบคุมอุปกรณ์
  - `GET /api/sensors` - ข้อมูล sensors
  - `GET /api/history` - ประวัติการสนทนา

### 📊 **Data Models:**
```dart
// Device Status
class DeviceStatus {
  double temperature;
  double humidity;
  int gasLevel;
  bool relay1;  // ไฟ
  bool relay2;  // พัดลม
  bool online;
  DateTime lastSeen;
}

// Sensor Data
class SensorData {
  double temperature;
  double humidity;
  int gasLevel;
  DateTime timestamp;
}

// Chat Message
class ChatMessage {
  String message;
  String reply;
  DateTime timestamp;
  bool isUser;
}
```

### 🎨 **UI Design:**
- **Theme**: Material Design 3 (Material You)
- **Colors**: Primary (Blue), Secondary (Green), Accent (Orange)
- **Typography**: Google Fonts (Roboto)
- **Icons**: Material Icons + Custom SVG icons
- **Layout**: Responsive design (Mobile-first)

### 📁 **Project Structure:**
```
lib/
├── main.dart
├── models/
│   ├── device_status.dart
│   ├── sensor_data.dart
│   └── chat_message.dart
├── screens/
│   ├── dashboard_screen.dart
│   ├── control_screen.dart
│   ├── chat_screen.dart
│   └── settings_screen.dart
├── services/
│   ├── api_service.dart
│   ├── mqtt_service.dart
│   └── storage_service.dart
├── widgets/
│   ├── device_card.dart
│   ├── sensor_card.dart
│   ├── control_button.dart
│   └── chat_bubble.dart
└── utils/
    ├── constants.dart
    ├── theme.dart
    └── helpers.dart
```

### 🚀 **Required Packages (pubspec.yaml):**
```yaml
dependencies:
  flutter:
    sdk: flutter
  provider: ^6.1.1
  dio: ^5.3.2
  mqtt_client: ^4.0.0
  shared_preferences: ^2.2.2
  sqflite: ^2.3.0
  google_fonts: ^6.1.0
  flutter_svg: ^2.0.9
  fl_chart: ^0.65.0
  permission_handler: ^11.0.1
  speech_to_text: ^6.3.0
```

---

## 📝 **Prompt เพิ่มเติม (ถ้าต้องการ):**

### **สำหรับสร้าง UI Components:**
```
"ช่วยสร้าง Flutter widget สำหรับ [ชื่อ widget] ที่มี:
- Design ตาม Material Design 3
- Responsive layout
- Animation effects
- Error handling
- Loading states"
```

### **สำหรับสร้าง API Service:**
```
"ช่วยสร้าง Flutter service class สำหรับเชื่อมต่อ HTTP API ที่:
- Base URL: http://35.247.182.78:8080
- ใช้ Dio package
- มี error handling
- มี retry mechanism
- ใช้ Provider pattern"
```

### **สำหรับสร้าง MQTT Service:**
```
"ช่วยสร้าง Flutter MQTT service ที่:
- เชื่อมต่อกับ broker.hivemq.com
- Subscribe topics: home/sensor, home/status, home/heartbeat
- Publish commands ไปยัง home/command
- มี connection management
- มี error handling"
```

---

## 🎯 **ขั้นตอนการใช้งาน:**

1. **Copy prompt หลัก** ไปยัง Claude
2. **รอ AI สร้างโค้ด**
3. **Copy โค้ดไปใช้**
4. **ใช้ prompt เพิ่มเติม** ถ้าต้องการส่วนอื่น

## 💡 **Tips:**
- **ระบุ requirements ชัดเจน**
- **ขออธิบายการทำงาน**
- **ขอตัวอย่างการใช้งาน**
- **ถามเมื่อไม่เข้าใจ**

---

**🎉 Happy Coding with Claude! 🚀**
