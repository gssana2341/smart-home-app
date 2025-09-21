# Smart Home Web App — Slide Deck

---

## 1) Project Overview
- **Purpose**: Smart Home monitoring and control via Web (Flutter Web) with AI voice/Chat assistance.
- **Key Capabilities**:
  - **Real-time dashboard**: device status, sensor charts.
  - **Control**: light/fan/AC/pump/heater/extra via API/MQTT.
  - **Voice commands**: speech-to-text + AI intent parsing.
  - **TTS**: AI replies with speech via backend proxy.
  - **Automation**: rule-based triggers and logs.

---

## 2) Architecture (High Level)
- **Frontend**: Flutter Web served on `:8088`
- **Backend API**: Custom server on `:8080` (status/chat/control/sensors/history/tts)
- **MQTT**: Optional realtime control/status (HiveMQ public for web)
- **External AI**: OpenAI (Chat + TTS) via backend-only calls

```mermaid
flowchart LR
  subgraph Browser (iPad/PC)
    UI[Flutter Web UI]
  end
  UI -- HTTP --> API[(Backend :8080)]
  UI -- WebSocket --> MQTT[(MQTT Broker)]
  API -- HTTPS --> OpenAI[(OpenAI APIs)]
```

---

## 3) Main Modules (Frontend)
- `lib/screens/dashboard_screen.dart`
  - **Live device status**, sensor charts, quick controls
  - Auto-refresh timers + MQTT listeners
- `lib/screens/chat_screen.dart`
  - **System Log**, AI chat, TTS toggle, play response
- `lib/services/api_service.dart`
  - Calls: `status`, `chat`, `control`, `sensors`, `history`
- `lib/services/voice_command_service.dart`
  - **Speech-to-Text** + **AI processing** + **TTS playback**
- `lib/services/ai_service.dart`
  - Intent detection via OpenAI (`_processWithOpenAI`) or **Local AI** fallback
- `lib/services/tts_service.dart`
  - Web TTS via backend proxy `POST /api/tts` -> returns `audio/mpeg`
- `lib/services/storage_service.dart`
  - App settings (server URL, modes) + local cache
- `lib/utils/constants.dart`
  - API base URL, endpoints, MQTT defaults, app constants

---

## 4) Backend Endpoints (Expected)
- `GET /api/status` — system heartbeat
- `POST /api/chat` — AI chat (server-side key)
- `POST /api/control` — device control payload
- `GET /api/sensors?limit=20` — recent sensor data
- `GET /api/history` — actions/history
- `POST /api/tts` — TTS proxy to OpenAI, returns `audio/mpeg`

Notes:
- Backend must run on `0.0.0.0:8080` and enable **CORS** for the web origin.
- For TTS: accept `{ text, voice }`, call OpenAI TTS, return MP3 bytes.

---

## 5) Network Configuration (Multi‑device)
- **Frontend (Web)** served at: `http://<PC_IP>:8088`
- **Backend (API)** served at: `http://<PC_IP>:8080`
- On iPad, do NOT use `localhost` or `127.0.0.1`.
- Set the app’s server URL in Settings to `http://<PC_IP>:8080`.
- Windows Firewall (Private): allow inbound **8088** and **8080**.
- CORS Origin example: `http://<PC_IP>:8088`.

---

## 6) AI/TTS Data Flow
1. User asks or uses voice
2. Frontend sends chat/control to `API :8080`
3. Backend calls OpenAI (with server-side key)
4. Response returned to web
5. If TTS enabled, web calls `POST /api/tts` with `{ text, voice }`
6. Backend returns `audio/mpeg`, browser plays via HTML5 Audio

---

## 7) Voice Command Pipeline
- **STT**: `speech_to_text` package (mobile/web) -> Thai locale `th_TH`
- **AI Parsing**: `AiService._processWithOpenAI()` or `_processWithLocalAI()`
- **Action**: control via API/MQTT then update local state and logs
- **TTS Reply**: `TtsService.speakImmediate()` (web path uses backend `/api/tts`)

---

## 8) Build & Run (Local)
- Build Flutter Web:
```bash
flutter build web --release
```
- Serve frontend:
```powershell
python -m http.server 8088 --directory D:\Appiot\build\web --bind <PC_IP>
```
- Run backend on `0.0.0.0:8080` and enable CORS to origin `http://<PC_IP>:8088`.
- On iPad, open: `http://<PC_IP>:8088` then set server URL to `http://<PC_IP>:8080` in Settings.

---

## 9) Configuration
- `lib/utils/constants.dart`
  - `ApiConstants.baseUrl` default is `http://localhost:8080` (override via Settings)
  - `ApiConstants.ttsUrl = baseUrl + '/api/tts'`
- `lib/services/storage_service.dart`
  - `StorageConstants.serverUrlKey` persisted in SharedPreferences
- MQTT: `MqttConstants.webSocketUrl = ws://broker.hivemq.com:8000/mqtt`

---

## 10) Troubleshooting
- **iPad sees dashboard but no data**:
  - Set server URL to `http://<PC_IP>:8080`
  - Backend must listen on `0.0.0.0:8080`
  - Allow firewall ports `8080`,`8088`
  - CORS allow origin `http://<PC_IP>:8088`
- **TTS no sound (web/iOS)**:
  - Ensure `/api/tts` exists and returns `audio/mpeg`
  - First user gesture required on iOS to unmute autoplay
  - Check console logs: response status and playback errors
- **Service Worker cache**:
  - Try Private Mode or add `?v=<ts>` to bust cache

---

## 11) Demo Script (5–7 mins)
- Open dashboard (real-time tiles, charts)
- Toggle a device (light/fan) via UI
- Show automation log entry
- Open Log (chat) tab
- Ask a question -> AI replies; press speaker icon to play TTS
- Speak a command ("เปิดไฟ") -> hear TTS confirmation -> device toggles

---

## 12) Roadmap
- Native mobile builds (Android/iOS) with background MQTT
- Secure backend (auth, HTTPS, roles)
- Custom TTS voices and local model option for offline
- Rule editor UI and export/import automation rules
- Telemetry dashboards and alerts

---

## 13) Credits / Tech Stack
- **Frontend**: Flutter Web, Provider, shared_preferences
- **Backend**: (Example) Node/Express or FastAPI
- **AI**: OpenAI Chat + TTS (server-side key)
- **MQTT**: HiveMQ public (websocket), device broker (optional)

---

## 14) Contact
- Project: Smart Home App
- Version: 1.0.0
- Maintainer: You

---

# ภาคผนวก (เนื้อหาบรรยายโครงงาน)

## A) ที่มาและความสำคัญของโครงงาน
- ปัญหาในบ้าน/ฟาร์ม/ออฟฟิศขนาดเล็กมักขาดระบบติดตามสถานะและควบคุมอุปกรณ์แบบรวมศูนย์ ทำให้เสียเวลา ตรวจสอบยาก และขาดข้อมูลเชิงลึก
- อุปกรณ์ IoT มีมากขึ้นแต่กระจัดกระจาย แอปเฉพาะรายอุปกรณ์ทำให้ผู้ใช้สับสนและไม่สะดวก
- โครงงานนี้รวบระบบ “แสดงผล-ควบคุม-สั่งงานด้วยเสียง-อัตโนมัติ” ไว้ในเว็บเดียว ใช้งานได้ข้ามอุปกรณ์ (PC/iPad/มือถือ) และรองรับการขยายในอนาคต
- ใช้ AI ช่วยตีความภาษามนุษย์ ลดความซับซ้อนของ UI และเปิดทางสู่ระบบผู้ช่วยบ้านอัจฉริยะ

## B) การนำไปใช้ประโยชน์
- บ้านอัจฉริยะ: ควบคุมไฟ พัดลม แอร์ ปั๊มน้ำ ฮีทเตอร์ ดูค่าความร้อน/ความชื้น/แก๊ส แบบเรียลไทม์
- ฟาร์ม/เรือนเพาะ: รดน้ำ/พ่นหมอกแบบอัตโนมัติ แจ้งเตือนค่าเซนเซอร์ผิดปกติ พร้อมบันทึกประวัติ
- ห้องเซิร์ฟเวอร์/คลังสินค้า: แจ้งเตือนอุณหภูมิ/ความชื้น เก็บประวัติสำหรับตรวจสอบย้อนหลัง
- สถานศึกษา/สาธิตวิชา: ตัวอย่างครบวงจรของระบบ IoT + AI สำหรับสอนและต่อยอดงานวิจัย

## C) ขอบเขตของโครงงาน
- ส่วนที่มีให้ในเวอร์ชันนี้
  - Frontend Flutter Web แสดงผลแบบแดชบอร์ดและหน้าบันทึกเหตุการณ์ (Log/Chat)
  - ควบคุมอุปกรณ์ผ่าน API และ/หรือ MQTT (เลือกโหมดได้)
  - ระบบคำสั่งเสียง (Speech-to-Text) + วิเคราะห์เจตนาโดย AI + ตอบกลับด้วยเสียง (TTS ผ่าน proxy)
  - เก็บค่าตั้งค่าและแคชข้อมูลในเครื่องผู้ใช้ (`StorageService`)
  - ออโต้รีเฟรช/อัปเดตเรียลไทม์ และระบบ Automation พื้นฐาน
- นอกขอบเขต (ทำได้ในอนาคต)
  - ระบบยืนยันตัวตน/สิทธิ์ผู้ใช้ (Auth, RBAC)
  - ระบบแจ้งเตือนนอกเครือข่าย (Push/Email/SMS)
  - Mobile app แบบ native, OTA updates, และ edge computing ในอุปกรณ์ปลายทาง

## D) การออกแบบระบบเบื้องต้น
- สถาปัตยกรรมแยก Frontend (Web :8088) ออกจาก Backend (API :8080) เพื่อความปลอดภัยและยืดหยุ่น
- Backend เป็นตัวกลางเรียก OpenAI (ซ่อน API key ไว้ฝั่งเซิร์ฟเวอร์) และจัดการ CORS/นโยบายความปลอดภัย
- MQTT ใช้สำหรับอัปเดตสถานะเรียลไทม์และควบคุมอุปกรณ์แบบ latency ต่ำ

```mermaid
flowchart LR
  subgraph Client (PC/iPad/Mobile Browser)
    UI[Flutter Web] -- REST --> API[(Backend :8080)]
    UI -- WebSocket --> MQTT[(MQTT Broker)]
  end
  API -- HTTPS --> OpenAI[(OpenAI Chat / TTS)]
  API -- DB/Storage --> Logs[(History/Rules/Cache)]
```

- โค้ดหลักที่เกี่ยวข้อง
  - `lib/screens/dashboard_screen.dart` หน้าควบคุมและแสดงผลรวม
  - `lib/screens/chat_screen.dart` หน้าบันทึกเหตุการณ์/แชทกับ AI และปุ่มเล่นเสียง
  - `lib/services/voice_command_service.dart` ท่อคำสั่งเสียงครบวงจร (ฟัง-ตีความ-พูดตอบ-สั่งอุปกรณ์)
  - `lib/services/ai_service.dart` วิเคราะห์คำสั่งด้วย OpenAI หรือ Local AI
  - `lib/services/tts_service.dart` เล่นเสียงตอบกลับผ่าน `/api/tts`
  - `lib/utils/constants.dart` กำหนด endpoints และค่าคงที่ของระบบ

## E) คลาวด์และเว็บเซอร์วิสที่ใช้
- **OpenAI**: ใช้สำหรับ Chat/Intent และ TTS (เรียกจาก Backend เท่านั้น)
- **MQTT Broker**: ตัวอย่างค่าเริ่มต้น HiveMQ public (websocket) สำหรับเดโมบนเว็บ
- **ทางเลือกโฮสต์/คลาวด์** (อนาคต)
  - โฮสต์ Backend บน VPS/Cloud (e.g., Azure, AWS, GCP) พร้อม HTTPS และโดเมนจริง
  - ใช้ Cloud tunneling (ngrok/cloudflared) สำหรับทดสอบ HTTPS ชั่วคราว
  - เก็บประวัติ/กฎอัตโนมัติในฐานข้อมูลคลาวด์ (PostgreSQL/Firestore)

## F) การควบคุมและแสดงผล
- **แสดงผล**
  - แดชบอร์ดอัปเดตสถานะอุปกรณ์สดๆ กราฟเซนเซอร์แบบ time-series และ Log เหตุการณ์
  - โหมดออโต้รีเฟรช + การฟัง MQTT เพื่อความหน่วงต่ำ
- **ควบคุม**
  - ผ่าน API: `POST /api/control` และ endpoints จำเพาะ (เช่น `/api/status`, `/api/sensors`)
  - ผ่าน MQTT: ส่งคำสั่งไปยัง topic ที่กำหนด เช่น `home/command`
  - โหมดเลือกอัตโนมัติ: พยายาม API ก่อน ถ้าไม่สำเร็จสลับไป MQTT
- **TTS/Voice UX**
  - คำตอบของ AI สามารถเล่นเสียงผ่านปุ่มลำโพงบนหน้า Log (รองรับ iOS ที่ต้องการ user gesture)
  - เสียง TTS ถูกส่งมาจาก Backend ที่เรียก OpenAI แล้วส่งกลับเป็น `audio/mpeg`
