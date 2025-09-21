/*
  Google Cloud Smart Home Server
  Node.js + Express + MQTT + OpenAI
  Deploy: Google Cloud Run
*/

const express = require("express");
const mqtt = require("mqtt");
const sqlite3 = require("sqlite3").verbose();
const OpenAI = require("openai");
const cors = require("cors");
require("dotenv").config();

const app = express();
const PORT = process.env.PORT || 8080;

// ===== CONFIGURATION =====
const config = {
  // MQTT Broker (ใช้ Public Broker สำหรับทดสอบ)
  mqtt_broker: process.env.MQTT_BROKER || "broker.hivemq.com",
  mqtt_port: process.env.MQTT_PORT || 1883,
  mqtt_topic_sensor: process.env.MQTT_TOPIC_SENSOR || "home/sensor",
  mqtt_topic_status: process.env.MQTT_TOPIC_STATUS || "home/status",
  mqtt_topic_heartbeat: process.env.MQTT_TOPIC_HEARTBEAT || "home/heartbeat",
  mqtt_topic_command: process.env.MQTT_TOPIC_COMMAND || "home/command",

  // OpenAI API
  openai_api_key: process.env.OPENAI_API_KEY || "your-openai-api-key-here",

  // Database
  db_path: process.env.DB_PATH || "./smarthome.db",

  // Server IP (สำหรับ ESP32)
  server_ip: process.env.SERVER_IP || "35.247.182.78",
  server_port: process.env.PORT || 8080,
};

// ===== INITIALIZE SERVICES =====
const openai = new OpenAI({
  apiKey: config.openai_api_key,
});

let mqttClient;
let db;

// Current device state
let deviceState = {
  temperature: 0,
  humidity: 0,
  gas_level: 0,
  relay1: false, // Light/ไฟ
  relay2: false, // Fan/พัดลม
  relay3: false, // Air Conditioner/แอร์
  relay4: false, // Water Pump/ปั๊มน้ำ
  relay5: false, // Heater/ฮีทเตอร์
  relay6: false, // Extra Device/อุปกรณ์เพิ่มเติม
  last_seen: new Date(),
  online: false,
};

// ===== EXPRESS MIDDLEWARE =====
// Configure CORS to allow only specified origins (comma-separated in env)
const allowedOrigins = (process.env.WEB_ORIGINS || process.env.CORS_ORIGINS || process.env.FRONTEND_ORIGIN || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

app.use(
  cors({
    origin: allowedOrigins.length ? allowedOrigins : true,
  })
);
app.use(express.json({ limit: "2mb" }));
app.use(express.static("public"));

// Logging middleware
app.use((req, res, next) => {
  console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
  next();
});

// ===== DATABASE SETUP =====
function initDatabase() {
  db = new sqlite3.Database(config.db_path, (err) => {
    if (err) {
      console.error("❌ Database connection error:", err);
    } else {
      console.log("✅ Connected to SQLite database");
    }
  });

  // Create tables
  db.serialize(() => {
    // Messages table
    db.run(`CREATE TABLE IF NOT EXISTS messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      message TEXT NOT NULL,
      reply TEXT,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);

    // Device status table
    db.run(`CREATE TABLE IF NOT EXISTS devices (
      id INTEGER PRIMARY KEY,
      name TEXT DEFAULT 'ESP32_Home',
      status TEXT DEFAULT 'offline',
      last_seen DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);

    // Sensor logs table
    db.run(`CREATE TABLE IF NOT EXISTS sensor_logs (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      temperature REAL,
      humidity REAL,
      gas_level INTEGER,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
    )`);

    console.log("✅ Database tables initialized");
  });
}

// ===== MQTT SETUP =====
function initMQTT() {
  console.log("📡 Connecting to MQTT Broker:", config.mqtt_broker);

  mqttClient = mqtt.connect(`mqtt://${config.mqtt_broker}:${config.mqtt_port}`);

  mqttClient.on("connect", () => {
    console.log("✅ MQTT Connected");

    // Subscribe to ESP32 topics
    mqttClient.subscribe(config.mqtt_topic_sensor);
    mqttClient.subscribe(config.mqtt_topic_status);
    mqttClient.subscribe(config.mqtt_topic_heartbeat);

    console.log("📥 Subscribed to ESP32 topics");
  });

  mqttClient.on("message", (topic, message) => {
    try {
      const messageStr = message.toString();
      console.log(`📨 MQTT Raw message [${topic}]:`, messageStr);

      // Handle heartbeat message specially
      if (topic === config.mqtt_topic_heartbeat) {
        if (messageStr === "alive") {
          console.log("💓 Heartbeat received from ESP32");
          // Update device state directly
          deviceState.last_seen = new Date();
          deviceState.online = true;

          // Update database
          db.run("UPDATE devices SET status = ?, last_seen = ? WHERE id = 1", [
            "online",
            new Date().toISOString(),
          ]);
          return;
        }
      }

      // Check if message is valid JSON
      if (
        !messageStr.trim() ||
        messageStr === "Disconnected" ||
        messageStr === "Connected"
      ) {
        console.log("ℹ️ Skipping non-JSON message:", messageStr);
        return;
      }

      let data;
      try {
        data = JSON.parse(messageStr);
      } catch (parseError) {
        console.log("⚠️ Invalid JSON message, skipping:", messageStr);
        return;
      }

      console.log(`📨 MQTT Parsed message [${topic}]:`, data);

      handleMQTTMessage(topic, data);
    } catch (error) {
      console.error("❌ MQTT Processing Error:", error);
    }
  });

  mqttClient.on("error", (error) => {
    console.error("❌ MQTT Error:", error);
  });
}

// ===== MQTT MESSAGE HANDLER =====
function handleMQTTMessage(topic, data) {
  const now = new Date();

  switch (topic) {
    case config.mqtt_topic_sensor:
      // Update sensor data
      deviceState.temperature = data.temperature;
      deviceState.humidity = data.humidity;
      deviceState.gas_level = data.gas_level;
      deviceState.last_seen = now;
      deviceState.online = true;

      // Log to database
      db.run(
        "INSERT INTO sensor_logs (temperature, humidity, gas_level) VALUES (?, ?, ?)",
        [data.temperature, data.humidity, data.gas_level]
      );
      break;

    case config.mqtt_topic_status:
      // Update device status
      deviceState.relay1 = data.relay1;
      deviceState.relay2 = data.relay2;
      deviceState.relay3 = data.relay3;
      deviceState.relay4 = data.relay4;
      deviceState.relay5 = data.relay5;
      deviceState.relay6 = data.relay6;
      deviceState.last_seen = now;
      deviceState.online = true;
      break;

    case config.mqtt_topic_heartbeat:
      // Device is alive
      deviceState.last_seen = now;
      deviceState.online = true;

      db.run("UPDATE devices SET status = ?, last_seen = ? WHERE id = 1", [
        "online",
        now.toISOString(),
      ]);
      break;
  }
}

// ===== AI PROCESSING =====
async function processAICommand(message) {
  try {
    const prompt = `
    You are a smart home assistant. Analyze this Thai command and return a JSON response.
    
    Current device status:
    - Temperature: ${deviceState.temperature}°C
    - Humidity: ${deviceState.humidity}%
    - Gas Level: ${deviceState.gas_level}
    - Relay 1 (Light/ไฟ): ${deviceState.relay1 ? "ON" : "OFF"}
    - Relay 2 (Fan/พัดลม): ${deviceState.relay2 ? "ON" : "OFF"}
    - Relay 3 (Air Conditioner/แอร์): ${deviceState.relay3 ? "ON" : "OFF"}
    - Relay 4 (Water Pump/ปั๊มน้ำ): ${deviceState.relay4 ? "ON" : "OFF"}
    - Relay 5 (Heater/ฮีทเตอร์): ${deviceState.relay5 ? "ON" : "OFF"}
    - Relay 6 (Extra Device/อุปกรณ์เพิ่มเติม): ${
      deviceState.relay6 ? "ON" : "OFF"
    }

    User command: "${message}"

    Return JSON with:
    {
      "intent": "turn_on|turn_off|toggle|status|question",
      "device": "relay1|relay2|relay3|relay4|relay5|relay6|light|fan|ac|air_conditioner|water_pump|pump|heater|extra|none",
      "response": "Thai response message",
      "action_needed": true/false
    }

    Examples:
    - "เปิดไฟ" → {"intent":"turn_on","device":"relay1","response":"เปิดไฟแล้วครับ","action_needed":true}
    - "ปิดไฟ" → {"intent":"turn_off","device":"relay1","response":"ปิดไฟแล้วครับ","action_needed":true}
    - "เปิดพัดลม" → {"intent":"turn_on","device":"relay2","response":"เปิดพัดลมแล้วครับ","action_needed":true}
    - "ปิดพัดลม" → {"intent":"turn_off","device":"relay2","response":"ปิดพัดลมแล้วครับ","action_needed":true}
    - "เปิดแอร์" → {"intent":"turn_on","device":"relay3","response":"เปิดแอร์แล้วครับ","action_needed":true}
    - "ปิดแอร์" → {"intent":"turn_off","device":"relay3","response":"ปิดแอร์แล้วครับ","action_needed":true}
    - "เปิดปั๊มน้ำ" → {"intent":"turn_on","device":"relay4","response":"เปิดปั๊มน้ำแล้วครับ","action_needed":true}
    - "ปิดปั๊มน้ำ" → {"intent":"turn_off","device":"relay4","response":"ปิดปั๊มน้ำแล้วครับ","action_needed":true}
    - "เปิดฮีทเตอร์" → {"intent":"turn_on","device":"relay5","response":"เปิดฮีทเตอร์แล้วครับ","action_needed":true}
    - "ปิดฮีทเตอร์" → {"intent":"turn_off","device":"relay5","response":"ปิดฮีทเตอร์แล้วครับ","action_needed":true}
    - "เปิดอุปกรณ์เพิ่มเติม" → {"intent":"turn_on","device":"relay6","response":"เปิดอุปกรณ์เพิ่มเติมแล้วครับ","action_needed":true}
    - "ปิดอุปกรณ์เพิ่มเติม" → {"intent":"turn_off","device":"relay6","response":"ปิดอุปกรณ์เพิ่มเติมแล้วครับ","action_needed":true}
    - "อุณหภูมิเท่าไร" → {"intent":"status","device":"none","response":"อุณหภูมิตอนนี้ ${
      deviceState.temperature
    } องศาครับ","action_needed":false}
    - "ความชื้นเท่าไร" → {"intent":"status","device":"none","response":"ความชื้นตอนนี้ ${
      deviceState.humidity
    }% ครับ","action_needed":false}
    - "สถานะอุปกรณ์" → {"intent":"status","device":"none","response":"ไฟ: ${
      deviceState.relay1 ? "เปิด" : "ปิด"
    }, พัดลม: ${deviceState.relay2 ? "เปิด" : "ปิด"}, แอร์: ${
      deviceState.relay3 ? "เปิด" : "ปิด"
    }, ปั๊มน้ำ: ${deviceState.relay4 ? "เปิด" : "ปิด"}, ฮีทเตอร์: ${
      deviceState.relay5 ? "เปิด" : "ปิด"
    }, อุปกรณ์เพิ่มเติม: ${deviceState.relay6 ? "เปิด" : "ปิด"}, อุณหภูมิ: ${
      deviceState.temperature
    }°C, ความชื้น: ${deviceState.humidity}%","action_needed":false}
    `;

    const completion = await openai.chat.completions.create({
      model: "gpt-3.5-turbo",
      messages: [{ role: "user", content: prompt }],
      max_tokens: 300,
      temperature: 0.3,
    });

    const aiResponse = completion.choices[0].message.content;
    console.log("🤖 AI Response:", aiResponse);

    return JSON.parse(aiResponse);
  } catch (error) {
    console.error("❌ AI Processing Error:", error);
    return {
      intent: "error",
      device: "none",
      response: "ขออภัย ไม่สามารถประมวลผลคำสั่งได้ในขณะนี้",
      action_needed: false,
    };
  }
}

// ===== DEVICE CONTROL =====
function sendDeviceCommand(device, action) {
  const command = {
    device: device,
    action: action,
    timestamp: new Date().toISOString(),
  };

  console.log("📤 Sending command to ESP32:", command);
  mqttClient.publish(config.mqtt_topic_command, JSON.stringify(command));

  return true;
}

// ===== REST API ENDPOINTS =====

// Health check
app.get("/", (req, res) => {
  res.json({
    status: "online",
    service: "Smart Home Server",
    version: "1.0.0",
    timestamp: new Date().toISOString(),
  });
});

// Get device status
app.get("/api/status", (req, res) => {
  res.json({
    success: true,
    data: deviceState,
    timestamp: new Date().toISOString(),
  });
});

// Get sensor history
app.get("/api/sensors", (req, res) => {
  const limit = req.query.limit || 50;

  db.all(
    "SELECT * FROM sensor_logs ORDER BY timestamp DESC LIMIT ?",
    [limit],
    (err, rows) => {
      if (err) {
        res.status(500).json({ success: false, error: err.message });
      } else {
        res.json({ success: true, data: rows });
      }
    }
  );
});

// Chat proxy to OpenAI Chat Completions
app.post("/api/chat", async (req, res) => {
  try {
    const { message } = req.body || {};

    if (!message || typeof message !== "string") {
      return res.status(400).json({ success: false, error: "'message' is required" });
    }

    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ success: false, error: "Server misconfigured: missing OPENAI_API_KEY" });
    }

    console.log("💬 Proxying chat message to OpenAI:", message);

    const response = await fetch("https://api.openai.com/v1/chat/completions", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "gpt-3.5-turbo",
        messages: [
          { role: "system", content: "You are a helpful assistant." },
          { role: "user", content: message },
        ],
        temperature: 0.7,
      }),
    });

    if (!response.ok) {
      const errText = await response.text().catch(() => "");
      console.error("❌ OpenAI chat error:", response.status, errText);
      return res.status(response.status).json({ success: false, error: "OpenAI chat failed", details: errText });
    }

    const data = await response.json();
    const reply = data?.choices?.[0]?.message?.content || "";

    // Save to database (if available)
    try {
      db.run("INSERT INTO messages (message, reply) VALUES (?, ?)", [message, reply]);
    } catch (e) {
      console.warn("⚠️ Failed to log chat to DB:", e?.message || e);
    }

    // Return top-level 'reply' for ApiService compatibility
    return res.json({ success: true, reply, raw: data });
  } catch (error) {
    console.error("❌ Chat API Error:", error);
    return res.status(500).json({ success: false, error: "Internal server error" });
  }
});

// TTS proxy to OpenAI Audio Speech API (mp3)
app.post("/api/tts", async (req, res) => {
  try {
    const { text, voice = "fable" } = req.body || {};

    if (!text || typeof text !== "string") {
      return res.status(400).json({ success: false, error: "'text' is required" });
    }

    const apiKey = process.env.OPENAI_API_KEY;
    if (!apiKey) {
      return res.status(500).json({ success: false, error: "Server misconfigured: missing OPENAI_API_KEY" });
    }

    console.log("🔊 Proxying TTS to OpenAI (voice=", voice, ")");

    const response = await fetch("https://api.openai.com/v1/audio/speech", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${apiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        model: "tts-1",
        input: text,
        voice,
        response_format: "mp3",
      }),
    });

    if (!response.ok) {
      const errText = await response.text().catch(() => "");
      console.error("❌ OpenAI TTS error:", response.status, errText);
      return res.status(response.status).json({ success: false, error: "OpenAI TTS failed", details: errText });
    }

    const arrayBuf = await response.arrayBuffer();
    const buffer = Buffer.from(arrayBuf);
    res.setHeader("Content-Type", "audio/mpeg");
    res.setHeader("Content-Length", buffer.length);
    res.setHeader("Cache-Control", "no-store");
    return res.send(buffer);
  } catch (error) {
    console.error("❌ TTS API Error:", error);
    return res.status(500).json({ success: false, error: "Internal server error" });
  }
});

// Manual device control
app.post("/api/control", (req, res) => {
  try {
    const { device, action } = req.body;

    if (!device || !action) {
      return res.status(400).json({
        success: false,
        error: "Device and action are required",
      });
    }

    const success = sendDeviceCommand(device, action);

    res.json({
      success: success,
      message: `Command sent: ${action} ${device}`,
      timestamp: new Date().toISOString(),
    });
  } catch (error) {
    console.error("❌ Control API Error:", error);
    res.status(500).json({
      success: false,
      error: "Internal server error",
    });
  }
});

// Voice to text (placeholder - ใช้ Android STT แทน)
app.post("/api/voice", (req, res) => {
  res.json({
    success: true,
    message: "Use Android STT instead",
    text: req.body.text || "",
  });
});

// Get chat history
app.get("/api/history", (req, res) => {
  const limit = req.query.limit || 20;

  db.all(
    "SELECT * FROM messages ORDER BY timestamp DESC LIMIT ?",
    [limit],
    (err, rows) => {
      if (err) {
        res.status(500).json({ success: false, error: err.message });
      } else {
        res.json({ success: true, data: rows.reverse() });
      }
    }
  );
});

// ===== DEVICE MONITORING =====
setInterval(() => {
  const now = new Date();
  const lastSeen = new Date(deviceState.last_seen);
  const timeDiff = now - lastSeen;

  // If no heartbeat for 2 minutes, mark as offline
  if (timeDiff > 120000) {
    deviceState.online = false;
    console.log("⚠️ Device appears offline");
  }
}, 30000);

// ===== ERROR HANDLING =====
app.use((err, req, res, next) => {
  console.error("❌ Server Error:", err);
  res.status(500).json({
    success: false,
    error: "Internal server error",
  });
});

// ===== SERVER STARTUP =====
async function startServer() {
  try {
    // Initialize database
    initDatabase();

    // Initialize MQTT
    initMQTT();

    // Start HTTP server
    app.listen(PORT, () => {
      console.log("🚀 Server started successfully!");
      console.log(`📡 HTTP Server: http://localhost:${PORT}`);
      console.log(`📊 API Endpoints:`);
      console.log(`   GET  /api/status    - Device status`);
      console.log(`   POST /api/chat      - AI chat`);
      console.log(`   POST /api/tts       - TTS proxy (mp3)`);
      console.log(`   POST /api/control   - Device control`);
      console.log(`   GET  /api/sensors   - Sensor history`);
      console.log(`   GET  /api/history   - Chat history`);
    });
  } catch (error) {
    console.error("❌ Server startup failed:", error);
    process.exit(1);
  }
}

// Start the server
startServer();
