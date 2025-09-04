# API Configuration

## การตั้งค่า API Keys

1. **สร้างไฟล์ `api_keys.dart`** โดยคัดลอกจาก `api_keys.dart.example`
2. **ตั้งค่า API Keys** ของคุณในไฟล์ `api_keys.dart`
3. **อย่า commit** ไฟล์ `api_keys.dart` ขึ้น GitHub (มีใน .gitignore แล้ว)

## API Keys ที่ต้องตั้งค่า

### OpenAI API Key
- ไปที่ [OpenAI Platform](https://platform.openai.com/api-keys)
- สร้าง API Key ใหม่
- ใส่ใน `openaiApiKey`

### MQTT Configuration
- ตั้งค่า MQTT Broker ของคุณ
- ใส่ Username และ Password (ถ้ามี)

### API Endpoints
- ตั้งค่า API Base URL ของคุณ
- ใส่ API Token (ถ้ามี)

## ตัวอย่างการใช้งาน

```dart
import 'package:your_app/config/api_keys.dart';

// ใช้ API Key
final apiKey = ApiKeys.openaiApiKey;
final mqttBroker = ApiKeys.mqttBroker;
```

## หมายเหตุ

- ไฟล์นี้จะไม่ถูก commit ขึ้น GitHub เพื่อความปลอดภัย
- ตั้งค่า API Keys ในไฟล์ `api_keys.dart` เท่านั้น
- อย่าใส่ API Keys จริงในโค้ดหลัก
