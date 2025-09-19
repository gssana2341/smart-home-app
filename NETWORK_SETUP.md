# การตั้งค่าเครือข่ายสำหรับ Smart Home App

## ฟีเจอร์ที่เพิ่มใหม่

### 🌐 รองรับทั้ง WiFi และเน็ตมือถือ
- แอปสามารถใช้งานได้ทั้ง WiFi และเน็ตมือถือ
- ตรวจจับประเภทเครือข่ายอัตโนมัติ
- ปรับ timeout และ retry ตามประเภทเครือข่าย

### 🔧 การตั้งค่าที่เพิ่มใน Android

#### 1. Network Permissions
```xml
<!-- Network permissions for both WiFi and Mobile Data -->
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
<uses-permission android:name="android.permission.CHANGE_WIFI_STATE" />
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- Mobile data permissions -->
<uses-permission android:name="android.permission.READ_PHONE_STATE" />
<uses-permission android:name="android.permission.ACCESS_SUPERUSER" />
```

#### 2. Network Security Configuration
- อนุญาต HTTP traffic (cleartext)
- รองรับการเชื่อมต่อไปยัง server ที่ใช้ HTTP
- ไฟล์: `android/app/src/main/res/xml/network_security_config.xml`

#### 3. Application Settings
```xml
<application
    android:usesCleartextTraffic="true"
    android:networkSecurityConfig="@xml/network_security_config">
```

## 🚀 วิธีการ Build APK

### วิธีที่ 1: ใช้ Script
```bash
# Windows
build_apk.bat

# Linux/Mac
chmod +x build_apk.sh
./build_apk.sh
```

### วิธีที่ 2: ใช้ Flutter Command
```bash
# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build APK
flutter build apk --release --target-platform android-arm,android-arm64,android-x64
```

## 📱 การติดตั้งและใช้งาน

### 1. ติดตั้ง APK
- Copy ไฟล์ `build/app/outputs/flutter-apk/app-release.apk` ไปยังมือถือ
- เปิดไฟล์ APK และติดตั้ง
- อนุญาตการติดตั้งจากแหล่งที่ไม่รู้จัก (ถ้าจำเป็น)

### 2. อนุญาต Permissions
เมื่อเปิดแอปครั้งแรก ระบบจะขออนุญาต:
- **Network Access**: สำหรับการเชื่อมต่ออินเทอร์เน็ต
- **Location**: สำหรับการตรวจจับเครือข่าย
- **Phone State**: สำหรับการตรวจสอบสถานะเครือข่าย

### 3. การใช้งาน
- แอปจะตรวจจับประเภทเครือข่ายอัตโนมัติ
- แสดงสถานะเครือข่ายที่มุมบนขวา
- ทำงานได้ทั้ง WiFi และเน็ตมือถือ
- ปรับการเชื่อมต่อตามประเภทเครือข่าย

## 🔍 การแก้ไขปัญหา

### ปัญหา: ไม่สามารถเชื่อมต่อได้
**วิธีแก้:**
1. ตรวจสอบการเชื่อมต่ออินเทอร์เน็ต
2. ตรวจสอบว่า server ทำงานอยู่
3. ลองปิด/เปิด WiFi หรือเน็ตมือถือ
4. รีสตาร์ทแอป

### ปัญหา: เชื่อมต่อช้า
**วิธีแก้:**
1. ตรวจสอบสัญญาณเครือข่าย
2. ลองเปลี่ยนจาก WiFi เป็นเน็ตมือถือ หรือในทางกลับกัน
3. รีสตาร์ทแอป

### ปัญหา: APK ติดตั้งไม่ได้
**วิธีแก้:**
1. เปิด "ติดตั้งแอปจากแหล่งที่ไม่รู้จัก" ใน Settings
2. ตรวจสอบว่ามีพื้นที่ว่างเพียงพอ
3. ลองดาวน์โหลด APK ใหม่

## 🌐 การทำงานบนเว็บ

### รองรับการทำงานบนเว็บเบราว์เซอร์
- ใช้ API เท่านั้น (ไม่ใช้ MQTT)
- รองรับการเชื่อมต่อผ่าน Chrome, Firefox, Safari
- ทำงานได้ทั้ง WiFi และเน็ตมือถือ

### การรันบนเว็บ
```bash
flutter run -d chrome
```

## 📊 Network Status Indicators

| สัญลักษณ์ | ความหมาย |
|-----------|-----------|
| 📶 | เชื่อมต่อผ่าน WiFi |
| 📱 | เชื่อมต่อผ่านเน็ตมือถือ |
| 🔌 | เชื่อมต่อผ่าน Ethernet |
| ❌ | ไม่มีการเชื่อมต่อ |
| ❓ | ไม่ทราบประเภทเครือข่าย |

## 🔧 การปรับแต่ง

### เปลี่ยน Server URL
แก้ไขในไฟล์ `lib/utils/constants.dart`:
```dart
static const String baseUrl = 'http://YOUR_SERVER_IP:PORT';
```

### เปลี่ยน MQTT Broker
แก้ไขในไฟล์ `lib/utils/constants.dart`:
```dart
static const String brokerHost = 'YOUR_MQTT_BROKER';
static const int brokerPort = 1883;
```

## 📞 การสนับสนุน

หากพบปัญหาหรือต้องการความช่วยเหลือ:
1. ตรวจสอบ logs ในแอป
2. ดูสถานะเครือข่ายในแอป
3. ทดสอบการเชื่อมต่อด้วย Connection Test
4. รีสตาร์ทแอปและลองใหม่
