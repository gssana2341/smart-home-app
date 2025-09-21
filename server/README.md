# 🏠 Smart Home Server - Google Cloud

Smart Home Server ที่ทำงานบน Google Cloud สำหรับรับข้อมูล MQTT จาก ESP32, ประมวลผล AI ด้วย OpenAI API, และส่งคำสั่งกลับไปยัง ESP32 พร้อม REST API สำหรับ Android App

## ✨ Features

- 📡 **MQTT Integration** - รับข้อมูลจาก ESP32 และส่งคำสั่งกลับ
- 🤖 **AI Processing** - ใช้ OpenAI API สำหรับประมวลผลคำสั่งภาษาไทย
- 🗄️ **SQLite Database** - เก็บข้อมูลอุปกรณ์, คำสั่ง, และการสนทนา AI
- 🌐 **REST API** - สำหรับ Android App และการจัดการระบบ
- 🔒 **Security** - Rate limiting, CORS, และ Helmet security
- 🐳 **Docker Ready** - พร้อม deploy บน Google Cloud Run
- 📱 **Mobile Ready** - API endpoints สำหรับ Android App

## 🚀 Quick Start

### 1. Install Dependencies

```bash
npm install
```

### 2. Environment Variables

สร้างไฟล์ `.env` จาก `env.example`:

```bash
cp env.example .env
```

แก้ไขค่าใน `.env`:

```env
OPENAI_API_KEY=your-openai-api-key-here
MQTT_BROKER=broker.hivemq.com
MQTT_PORT=1883
DB_PATH=./smarthome.db
```

### 3. Run Locally

```bash
npm run dev
```

Server จะทำงานที่ `http://localhost:8080`

## 📡 API Endpoints

### Health Check
```
GET /api/status
```

### Chat with AI
```
POST /api/chat
Content-Type: application/json

{
  "message": "เปิดไฟในห้องนอน"
}
```

### Device Management
```
GET /api/devices          # ดูสถานะอุปกรณ์
GET /api/commands         # ดูประวัติคำสั่ง
POST /api/command         # ส่งคำสั่งไปอุปกรณ์
GET /api/conversations    # ดูประวัติการสนทนา AI
```

## 🐳 Deploy to Google Cloud

### Prerequisites

1. **Google Cloud CLI** - [Install Guide](https://cloud.google.com/sdk/docs/install)
2. **Docker** - [Install Guide](https://docs.docker.com/get-docker/)
3. **Google Cloud Project** - สร้างโปรเจคใหม่ใน [Google Cloud Console](https://console.cloud.google.com/)

### Deployment Steps

#### Option 1: Using Script (Recommended)

**Linux/Mac:**
```bash
chmod +x deploy.sh
./deploy.sh YOUR_PROJECT_ID asia-southeast1
```

**Windows PowerShell:**
```powershell
.\deploy.ps1 YOUR_PROJECT_ID asia-southeast1
```

#### Option 2: Manual Deployment

```bash
# 1. Authenticate
gcloud auth login

# 2. Set project
gcloud config set project YOUR_PROJECT_ID

# 3. Enable APIs
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# 4. Configure Docker
gcloud auth configure-docker

# 5. Build and push
docker build -t gcr.io/YOUR_PROJECT_ID/smart-home-server .
docker push gcr.io/YOUR_PROJECT_ID/smart-home-server

# 6. Deploy to Cloud Run
gcloud run deploy smart-home-server \
  --image gcr.io/YOUR_PROJECT_ID/smart-home-server \
  --platform managed \
  --region asia-southeast1 \
  --allow-unauthenticated \
  --port 8080
```

### Set Environment Variables

หลังจาก deploy แล้ว ให้ตั้งค่า Environment Variables ใน Google Cloud Console:

1. ไปที่ **Cloud Run** > **smart-home-server** > **Edit & Deploy New Revision**
2. ในส่วน **Variables & Secrets** เพิ่ม:
   - `OPENAI_API_KEY` = your-api-key
   - `MQTT_BROKER` = broker.hivemq.com
   - `MQTT_PORT` = 1883

## 🔧 ESP32 Configuration

อัปเดต ESP32 code ให้ใช้ MQTT topics:

```cpp
// MQTT Topics
#define MQTT_TOPIC_IN "smart-home/esp32/input"
#define MQTT_TOPIC_OUT "smart-home/esp32/output"

// MQTT Message Format
{
  "device_id": "esp32_001",
  "command": "เปิดไฟ",
  "message": "เปิดไฟในห้องนอน"
}
```

## 📱 Android App Integration

ใช้ REST API endpoints สำหรับ Android App:

```kotlin
// Base URL
val baseUrl = "https://your-cloud-run-url.run.app"

// API Endpoints
val statusUrl = "$baseUrl/api/status"
val chatUrl = "$baseUrl/api/chat"
val devicesUrl = "$baseUrl/api/devices"
val commandsUrl = "$baseUrl/api/commands"
```

## 🧪 Testing

### Test Server Status
```bash
curl https://your-cloud-run-url.run.app/api/status
```

### Test AI Chat
```bash
curl -X POST https://your-cloud-run-url.run.app/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "เปิดไฟ"}'
```

### Test MQTT
ใช้ MQTT client เช่น MQTT Explorer หรือ Mosquitto:

**Subscribe to:** `smart-home/esp32/output`
**Publish to:** `smart-home/esp32/input`

```json
{
  "device_id": "test_device",
  "command": "เปิดไฟ",
  "message": "เปิดไฟในห้องนอน"
}
```

## 📊 Monitoring

- **Health Check**: `/api/status` endpoint
- **Logs**: ดูใน Google Cloud Console > Cloud Run > Logs
- **Metrics**: Cloud Run metrics ใน Google Cloud Console

## 🔒 Security Features

- **Rate Limiting**: 100 requests per 15 minutes per IP
- **CORS**: Cross-origin resource sharing
- **Helmet**: Security headers
- **Input Validation**: Request body validation
- **Error Handling**: Graceful error responses

## 🚨 Troubleshooting

### Common Issues

1. **MQTT Connection Failed**
   - ตรวจสอบ MQTT broker URL และ port
   - ตรวจสอบ network connectivity

2. **OpenAI API Error**
   - ตรวจสอบ API key ใน environment variables
   - ตรวจสอบ OpenAI account status

3. **Database Error**
   - ตรวจสอบ file permissions สำหรับ SQLite
   - ตรวจสอบ disk space

### Debug Mode

เพิ่ม debug logging:

```bash
export DEBUG=*
npm start
```

## 📚 Dependencies

- **Express.js** - Web framework
- **MQTT.js** - MQTT client
- **OpenAI** - AI API integration
- **SQLite3** - Database
- **Helmet** - Security middleware
- **CORS** - Cross-origin support

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Commit changes
4. Push to branch
5. Create Pull Request

## 📄 License

MIT License - see LICENSE file for details

## 📞 Support

หากมีปัญหาหรือคำถาม:
- สร้าง Issue ใน GitHub repository
- ติดต่อทีมพัฒนา

---

**Made with ❤️ for Smart Home Automation**
