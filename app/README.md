# Smart Home App

แอปพลิเคชันควบคุมบ้านอัจฉริยะด้วย AI Chat และเสียง

## ฟีเจอร์หลัก

- 🏠 **Dashboard**: ควบคุมอุปกรณ์ในบ้าน (ไฟ, พัดลม, แอร์)
- 💬 **AI Chat**: สนทนากับ AI เพื่อควบคุมอุปกรณ์ด้วยเสียง
- 🎤 **Voice Control**: ควบคุมอุปกรณ์ด้วยคำสั่งเสียง
- 🔊 **Text-to-Speech**: AI พูดตอบกลับด้วยเสียงธรรมชาติ
- 📱 **Responsive Design**: รองรับทั้งมือถือและเว็บ

## เทคโนโลยีที่ใช้

- **Flutter**: Cross-platform mobile development
- **Dart**: Programming language
- **Provider**: State management
- **HTTP**: API communication
- **MQTT**: IoT device communication
- **OpenAI TTS**: Text-to-speech service

## การติดตั้ง

1. ติดตั้ง Flutter SDK
2. Clone repository:
   ```bash
   git clone https://github.com/yourusername/smart-home-app.git
   cd smart-home-app
   ```
3. ติดตั้ง dependencies:
   ```bash
   flutter pub get
   ```
4. รันแอป:
   ```bash
   flutter run
   ```

## การใช้งาน

1. เปิดแอปจะเริ่มที่หน้า Splash Screen
2. ปัดขึ้นเพื่อเข้าสู่ระบบ
3. ใช้ Dashboard เพื่อควบคุมอุปกรณ์
4. ใช้ Chat เพื่อสนทนากับ AI และควบคุมอุปกรณ์ด้วยเสียง

## การควบคุมอุปกรณ์

### ผ่าน Dashboard
- แตะปุ่มเพื่อเปิด/ปิดอุปกรณ์
- ดูสถานะอุปกรณ์แบบ real-time

### ผ่าน AI Chat
- พิมพ์คำสั่ง: "เปิดไฟ", "ปิดพัดลม", "เปิดแอร์"
- AI จะตอบกลับและควบคุมอุปกรณ์ให้

## การตั้งค่า

### API Keys
สร้างไฟล์ `lib/config/api_keys.dart`:
```dart
class ApiKeys {
  static const String openaiApiKey = 'your-openai-api-key';
  static const String mqttBroker = 'your-mqtt-broker';
  static const String mqttPort = '1883';
}
```

### MQTT Configuration
ตั้งค่า MQTT broker ใน `lib/services/mqtt_service.dart`

## การสร้าง APK

```bash
flutter build apk --release
```

## ระบบที่รองรับ

- ✅ Android
- ✅ iOS
- ✅ Web
- ✅ Windows
- ✅ macOS
- ✅ Linux

## การมีส่วนร่วม

1. Fork repository
2. สร้าง feature branch
3. Commit การเปลี่ยนแปลง
4. Push ไปยัง branch
5. สร้าง Pull Request

## License

MIT License

## ผู้พัฒนา

สร้างด้วย ❤️ โดย Flutter Developer

## การสนับสนุน

หากพบปัญหาหรือต้องการความช่วยเหลือ กรุณาสร้าง Issue ใน GitHub repository