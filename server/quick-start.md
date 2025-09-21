# 🚀 Quick Start Guide - Smart Home Server

## ⚡ เริ่มต้นใน 5 นาที

### 1. 📦 Install Dependencies
```bash
npm install
```

### 2. 🔑 Setup Environment
```bash
# Copy environment template
cp env.example .env

# Edit .env file with your OpenAI API key
OPENAI_API_KEY=sk-your-actual-api-key-here
```

### 3. 🚀 Run Server
```bash
npm run dev
```

Server จะทำงานที่ `http://localhost:8080` 🎉

---

## 🧪 ทดสอบ Server

### Test Local Server
```bash
npm run test:local
```

### Test API Endpoints
```bash
# Health Check
curl http://localhost:8080/api/status

# AI Chat
curl -X POST http://localhost:8080/api/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "เปิดไฟ"}'
```

---

## ☁️ Deploy to Google Cloud

### 1. Install Tools
- [Google Cloud CLI](https://cloud.google.com/sdk/docs/install)
- [Docker](https://docs.docker.com/get-docker/)

### 2. Deploy
```bash
# Linux/Mac
./deploy.sh YOUR_PROJECT_ID

# Windows
.\deploy.ps1 YOUR_PROJECT_ID
```

### 3. Set Environment Variables
ใน Google Cloud Console:
- `OPENAI_API_KEY` = your-api-key
- `MQTT_BROKER` = broker.hivemq.com
- `MQTT_PORT` = 1883

---

## 📱 ESP32 Integration

### MQTT Topics
- **Input**: `smart-home/esp32/input`
- **Output**: `smart-home/esp32/output`

### Message Format
```json
{
  "device_id": "esp32_001",
  "command": "เปิดไฟ",
  "message": "เปิดไฟในห้องนอน"
}
```

---

## 🔗 API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/status` | Server health check |
| POST | `/api/chat` | Chat with AI |
| GET | `/api/devices` | List devices |
| GET | `/api/commands` | Command history |
| POST | `/api/command` | Send command to device |
| GET | `/api/conversations` | AI conversation history |

---

## 🎯 Next Steps

1. ✅ **Server Running** - Server ทำงานแล้ว
2. 🔧 **Test API** - ทดสอบ endpoints
3. ☁️ **Deploy Cloud** - Deploy บน Google Cloud
4. 📱 **Update ESP32** - เปลี่ยน MQTT server
5. 📱 **Create Android App** - สร้างแอปมือถือ

---

## 🆘 Need Help?

- 📖 **Full Documentation**: [README.md](README.md)
- 🐛 **Issues**: สร้าง GitHub issue
- 💬 **Support**: ติดต่อทีมพัฒนา

---

**Happy Coding! 🎉**
