/*
  ESP32 Smart Home Controller - GME12864-71 (7-pin SPI) with U8g2 - 6 RELAYS VERSION
  Board: ESP32 WROOM-32
  Display: GME12864-71 (128x64 7-pin SPI OLED)
  Features: Temperature, Gas Sensor, 6 Relay Control, MQTT, OLED Display
*/
#include <WiFi.h>       // สำหรับเชื่อมต่อ WiFi
#include <WiFiClient.h> // สำหรับสร้าง client MQTT/HTTP
#include <PubSubClient.h>
#include <ArduinoJson.h>
#include <DHT.h>
#include <SPI.h>
#include <U8g2lib.h>    // U8g2 library สำหรับ GME12864-71

// ===== PIN CONFIGURATION =====
#define DHT_PIN 4
#define GAS_SENSOR_PIN 34
#define LED_STATUS_PIN 2
#define BUTTON_PIN 0

// ----- 6 RELAY PINS -----
#define RELAY1_PIN 26    // Light/ไฟ
#define RELAY2_PIN 27    // Fan/พัดลม

#define RELAY3_PIN 25    // Air Conditioner/แอร์
#define RELAY4_PIN 33    // Water Pump/ปั๊มน้ำ
#define RELAY5_PIN 32    // Heater/ฮีทเตอร์
#define RELAY6_PIN 14    // Extra Device/อุปกรณ์เพิ่มเติม

// ----- GME12864-71 7-PIN SPI CONFIGURATION -----
#define OLED_MOSI  23   // SDA (Data)
#define OLED_CLK   18   // SCL (Clock)  
#define OLED_DC    19   // Data/Command
#define OLED_CS    5    // Chip Select
#define OLED_RES 21   // Reset
// VCC -> 3.3V
// GND -> GND

// ===== SENSOR SETUP =====
#define DHT_TYPE DHT22
DHT dht(DHT_PIN, DHT_TYPE);

// ===== GME12864-71 U8G2 DISPLAY SETUP =====
// Constructor สำหรับ SH1106 128x64 7-pin SPI (GME12864-71 มักใช้ SH1106)
U8G2_SH1106_128X64_NONAME_F_4W_HW_SPI u8g2(U8G2_R0, OLED_CS, OLED_DC, OLED_RES);

// ถ้าใช้ SSD1306 ให้ใช้บรรทัดนี้แทน:
// U8G2_SSD1306_128X64_NONAME_F_4W_HW_SPI u8g2(U8G2_R0, OLED_CS, OLED_DC, OLED_RES);

// ===== NETWORK CONFIG =====
const char* ssid = "Manaji";
const char* password = "32011111";

// ===== MQTT CONFIG =====
const char* mqtt_server = "broker.hivemq.com";
const int mqtt_port = 1883;
const char* device_id = "esp32_home_001";
const char* topic_command = "home/command";
const char* topic_status = "home/status";
const char* topic_sensor = "home/sensor";
const char* topic_heartbeat = "home/heartbeat";

// ===== OBJECTS =====
WiFiClient espClient;
PubSubClient mqtt(espClient);

// ===== VARIABLES =====
unsigned long lastSensorRead = 0;
unsigned long lastHeartbeat = 0;
unsigned long lastDisplayScroll = 0;
const long sensorInterval = 5000;
const long heartbeatInterval = 30000;
const long displayScrollInterval = 3000; // เลื่อนหน้าจอทุก 3 วินาที

// Device States - เพิ่มเป็น 6 relay
bool relay1State = false;  // Light/ไฟ
bool relay2State = false;  // Fan/พัดลม
bool relay3State = false;  // Air Conditioner/แอร์
bool relay4State = false;  // Water Pump/ปั๊มน้ำ
bool relay5State = false;  // Heater/ฮีทเตอร์
bool relay6State = false;  // Extra Device/อุปกรณ์เพิ่มเติม

float temperature = 0;
float humidity = 0;
int gasLevel = 0;
bool displayAvailable = false;
int displayPage = 0; // หน้าจอแสดงผล (0=sensor, 1=relays 1-3, 2=relays 4-6)

// Relay Names for display
const char* relayNames[6] = {"Light", "Fan", "AC", "Pump", "Heat", "Extra"};

// Function Prototypes
void updateDisplay();
void testDisplay();

// ===== SETUP =====
void setup() {
  Serial.begin(115200);
  delay(2000);
  Serial.println("\n🔥 ESP32 Smart Home Starting (6 RELAYS VERSION)...");
  
  // Initialize pins - เพิ่ม relay 3-6
  pinMode(RELAY1_PIN, OUTPUT);
  pinMode(RELAY2_PIN, OUTPUT);
  pinMode(RELAY3_PIN, OUTPUT);
  pinMode(RELAY4_PIN, OUTPUT);
  pinMode(RELAY5_PIN, OUTPUT);
  pinMode(RELAY6_PIN, OUTPUT);
  pinMode(LED_STATUS_PIN, OUTPUT);
  pinMode(BUTTON_PIN, INPUT_PULLUP);
  
  // Set initial relay states - ปิดทั้ง 6 relay
  digitalWrite(RELAY1_PIN, LOW);
  digitalWrite(RELAY2_PIN, LOW);
  digitalWrite(RELAY3_PIN, LOW);
  digitalWrite(RELAY4_PIN, LOW);
  digitalWrite(RELAY5_PIN, LOW);
  digitalWrite(RELAY6_PIN, LOW);
  
  // Initialize sensors
  dht.begin();
  
  // Initialize GME12864-71 Display with U8g2
  Serial.println("🖥️ Initializing GME12864-71 OLED Display (7-pin SPI)...");
  
  // SPI pins setup (hardware SPI)
  SPI.begin(OLED_CLK, -1, OLED_MOSI, -1); // CLK, MISO(ไม่ใช้), MOSI, SS(ไม่ใช้)
  
  // Initialize U8g2 display
  u8g2.begin();
  
  // Test if display is working
  u8g2.clearBuffer();
  u8g2.setFont(u8g2_font_6x10_tf);
  u8g2.drawStr(0, 15, "Testing Display...");
  u8g2.sendBuffer();
  delay(1000);
  
  // Check if display responds
  displayAvailable = true; // U8g2 ไม่มี function check แบบ Adafruit
  Serial.println("✅ GME12864-71 Display initialized with U8g2!");
  
  // Test display
  testDisplay();
  delay(2000);

  // Connect to WiFi
  setupWiFi();
  
  // Setup MQTT
  mqtt.setServer(mqtt_server, mqtt_port);
  mqtt.setCallback(mqttCallback);
  
  Serial.println("✅ Setup completed! (6 Relays Ready)");
  digitalWrite(LED_STATUS_PIN, HIGH);

  // Initial display update
  updateDisplay();
}

// ===== GME12864-71 DISPLAY TEST FUNCTION =====
void testDisplay() {
  if (!displayAvailable) return;
  
  Serial.println("🧪 Testing GME12864-71 7-pin SPI OLED...");
  
  // Test 1: Clear screen
  u8g2.clearBuffer();
  u8g2.sendBuffer();
  delay(500);
  
  // Test 2: Draw pixel
  u8g2.clearBuffer();
  u8g2.drawPixel(64, 32); // จุดกลางจอ
  u8g2.sendBuffer();
  delay(500);
  
  // Test 3: Draw rectangle
  u8g2.clearBuffer();
  u8g2.drawFrame(10, 10, 108, 44);
  u8g2.sendBuffer();
  delay(500);
  
  // Test 4: Text display with different fonts
  u8g2.clearBuffer();
  
  // Header
  u8g2.setFont(u8g2_font_6x10_tf);
  u8g2.drawStr(0, 10, "GME12864-71 Test");
  u8g2.drawHLine(0, 12, 128);
  
  // Info text
  u8g2.drawStr(0, 25, "ESP32 Smart Home");
  u8g2.drawStr(0, 35, "6 RELAYS VERSION");
  u8g2.drawStr(0, 45, "U8g2 Library");
  
  // Success message
  u8g2.setFont(u8g2_font_10x20_tf);
  u8g2.drawStr(20, 63, "SUCCESS!");
  
  u8g2.sendBuffer();
  
  Serial.println("✅ GME12864-71 Display test completed");
  Serial.println("If you see 'SUCCESS!' on display, it's working!");
}

void updateDisplay() {
  if (!displayAvailable) return;

  u8g2.clearBuffer();
  u8g2.setFont(u8g2_font_5x8_tf);

  int y = 10;

  // ==== Network ====
  String net = "WiFi: " + String(WiFi.status() == WL_CONNECTED ? "OK" : "NO");
  net += "   MQTT: " + String(mqtt.connected() ? "OK" : "NO");
  u8g2.drawStr(0, y, net.c_str());
  y += 8;

  // เส้นคั่น
  u8g2.drawHLine(0, y, 128);
  y += 10;

  // ==== Sensors + Relays (2 ต่อบรรทัด) ====
  u8g2.drawStr(0, y, ("Temp: " + String(temperature, 1) + " C").c_str());
  u8g2.drawStr(70, y, (String("1:") + (relay1State ? "ON" : "OFF") + " 2:" + (relay2State ? "ON" : "OFF")).c_str());
  y += 10;

  u8g2.drawStr(0, y, ("Humi: " + String(humidity, 1) + "%").c_str());
  u8g2.drawStr(70, y, (String("3:") + (relay3State ? "ON" : "OFF") + " 4:" + (relay4State ? "ON" : "OFF")).c_str());
  y += 10;

  u8g2.drawStr(0, y, ("Gas: " + String(gasLevel)).c_str());
  u8g2.drawStr(70, y, (String("5:") + (relay5State ? "ON" : "OFF") + " 6:" + (relay6State ? "ON" : "OFF")).c_str());
  y += 10;

  // เส้นคั่นล่าง
  u8g2.drawHLine(0, y, 128);

  u8g2.sendBuffer();
}



// ฟังก์ชันวาด Relay แต่ละตัว
void drawRelayState(int relayNum, bool state, int x, int y) {
  u8g2.drawStr(x, y, state ? "ON" : "OFF");
  if (state) u8g2.drawCircle(x + 30, y - 3, 2);  // จุด ● เมื่อ ON
}

// หน้าแสดง Sensor Data
void displaySensorPage() {
  u8g2.drawStr(35, 25, "SENSORS");
  u8g2.drawHLine(30, 27, 68);

  String tempStr;
  if(temperature > -100) {
    tempStr = "Temp: " + String(temperature, 1) + "C";
  } else {
    tempStr = "Temp: Error";
  }
  u8g2.drawStr(0, 38, tempStr.c_str());

  String humiStr;
  if(humidity > -100) {
    humiStr = "Humi: " + String(humidity, 1) + "%";
  } else {
    humiStr = "Humi: Error";
  }
  u8g2.drawStr(0, 48, humiStr.c_str());

  String gasStr = "Gas: " + String(gasLevel);
  u8g2.drawStr(0, 58, gasStr.c_str());
}

// หน้าแสดง Relays 1-3
void displayRelayPage1() {
  u8g2.drawStr(30, 25, "RELAYS 1-3");
  u8g2.drawHLine(25, 27, 78);

  // Relay 1
  String relay1Str = "1." + String(relayNames[0]) + ": ";
  relay1Str += relay1State ? "ON" : "OFF";
  u8g2.drawStr(0, 38, relay1Str.c_str());
  if(relay1State) u8g2.drawCircle(120, 35, 2);

  // Relay 2
  String relay2Str = "2." + String(relayNames[1]) + ": ";
  relay2Str += relay2State ? "ON" : "OFF";
  u8g2.drawStr(0, 48, relay2Str.c_str());
  if(relay2State) u8g2.drawCircle(120, 45, 2);

  // Relay 3
  String relay3Str = "3." + String(relayNames[2]) + ": ";
  relay3Str += relay3State ? "ON" : "OFF";
  u8g2.drawStr(0, 58, relay3Str.c_str());
  if(relay3State) u8g2.drawCircle(120, 55, 2);
}

// หน้าแสดง Relays 4-6
void displayRelayPage2() {
  u8g2.drawStr(30, 25, "RELAYS 4-6");
  u8g2.drawHLine(25, 27, 78);

  // Relay 4
  String relay4Str = "4." + String(relayNames[3]) + ": ";
  relay4Str += relay4State ? "ON" : "OFF";
  u8g2.drawStr(0, 38, relay4Str.c_str());
  if(relay4State) u8g2.drawCircle(120, 35, 2);

  // Relay 5
  String relay5Str = "5." + String(relayNames[4]) + ": ";
  relay5Str += relay5State ? "ON" : "OFF";
  u8g2.drawStr(0, 48, relay5Str.c_str());
  if(relay5State) u8g2.drawCircle(120, 45, 2);

  // Relay 6
  String relay6Str = "6." + String(relayNames[5]) + ": ";
  relay6Str += relay6State ? "ON" : "OFF";
  u8g2.drawStr(0, 58, relay6Str.c_str());
  if(relay6State) u8g2.drawCircle(120, 55, 2);
}

// ===== MAIN LOOP =====
void loop() {
  // Keep MQTT connected
  if (!mqtt.connected()) {
    reconnectMQTT();
  }
  mqtt.loop();
  
  // Read sensors periodically
  unsigned long now = millis();
  if (now - lastSensorRead > sensorInterval) {
    lastSensorRead = now;
    readSensors();
    publishSensorData();
  }
  
  // Auto scroll display pages
  if (now - lastDisplayScroll > displayScrollInterval) {
    lastDisplayScroll = now;
    displayPage = (displayPage + 1) % 3; // หมุนเวียน 3 หน้า
    updateDisplay();
  }
  
  // Send heartbeat
  if (now - lastHeartbeat > heartbeatInterval) {
    lastHeartbeat = now;
    publishHeartbeat();
  }
  
  // Check manual button - toggle relay 1
  if (digitalRead(BUTTON_PIN) == LOW) {
    delay(50);
    if (digitalRead(BUTTON_PIN) == LOW) {
      toggleRelay1();
      while(digitalRead(BUTTON_PIN) == LOW);
    }
  }
}

// ===== WIFI SETUP =====
void setupWiFi() {
  Serial.print("🌐 Connecting to WiFi: ");
  Serial.println(ssid);
  
  WiFi.begin(ssid, password);
  
  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
    
    // อัพเดทจอระหว่างรอ WiFi
    if (displayAvailable) {
      u8g2.clearBuffer();
      u8g2.setFont(u8g2_font_6x10_tf);
      u8g2.drawStr(0, 10, "Connecting WiFi...");
      
      String attemptStr = "Attempt: " + String(attempts) + "/20";
      u8g2.drawStr(0, 25, attemptStr.c_str());
      
      // Progress bar
      int progress = map(attempts, 0, 20, 0, 120);
      u8g2.drawFrame(0, 35, 120, 10);
      u8g2.drawBox(2, 37, progress, 6);
      
      u8g2.sendBuffer();
    }
  }
  
  if (WiFi.status() == WL_CONNECTED) {
    Serial.println();
    Serial.println("✅ WiFi Connected!");
    Serial.print("📶 IP Address: ");
    Serial.println(WiFi.localIP());
    Serial.print("📶 Signal Strength: ");
    Serial.println(WiFi.RSSI());
    
    // แสดงสถานะบนจอ
    if (displayAvailable) {
      u8g2.clearBuffer();
      u8g2.setFont(u8g2_font_6x10_tf);
      u8g2.drawStr(0, 10, "WiFi Connected!");
      
      String ipStr = "IP: " + WiFi.localIP().toString();
      u8g2.drawStr(0, 25, ipStr.c_str());
      
      String signalStr = "Signal: " + String(WiFi.RSSI()) + " dBm";
      u8g2.drawStr(0, 40, signalStr.c_str());
      
      u8g2.sendBuffer();
      delay(2000);
    }
  } else {
    Serial.println();
    Serial.println("❌ WiFi Connection Failed!");
    
    if (displayAvailable) {
      u8g2.clearBuffer();
      u8g2.setFont(u8g2_font_6x10_tf);
      u8g2.drawStr(0, 10, "WiFi Failed!");
      u8g2.drawStr(0, 25, "Check SSID/Pass");
      u8g2.drawStr(0, 40, "Restarting...");
      u8g2.sendBuffer();
      delay(3000);
    }
    
    ESP.restart();
  }
}

// ===== MQTT CONNECTION =====
void reconnectMQTT() {
  while (!mqtt.connected()) {
    Serial.print("📡 Connecting to MQTT...");
    if (mqtt.connect(device_id)) {
      Serial.println(" ✅ Connected!");
      mqtt.subscribe(topic_command);
      Serial.println("📥 Subscribed to: " + String(topic_command));
      publishDeviceStatus();
    } else {
      Serial.print(" ❌ Failed, rc=");
      Serial.print(mqtt.state());
      Serial.println(" Retry in 5 seconds...");
      delay(5000);
    }
  }
}

// ===== MQTT MESSAGE HANDLER - เพิ่มรองรับ 6 relay =====
void mqttCallback(char* topic, byte* payload, unsigned int length) {
  Serial.print("📨 Message from [" + String(topic) + "]: ");
  String message;
  for (int i = 0; i < length; i++) {
    message += (char)payload[i];
  }
  Serial.println(message);
  
  StaticJsonDocument<200> doc;
  DeserializationError error = deserializeJson(doc, message);
  
  if (error) {
    Serial.println("❌ JSON Parse Error");
    return;
  }
  
  String action = doc["action"];
  String device = doc["device"];
  
  // Relay 1 - Light/ไฟ
  if (device == "relay1" || device == "light") {
    if (action == "เปิดไฟ" || action == "on") { setRelay1(true); } 
    else if (action == "ปิดไฟ" || action == "off") { setRelay1(false); } 
    else if (action == "toggle") { toggleRelay1(); }
  } 
  // Relay 2 - Fan/พัดลม
  else if (device == "relay2" || device == "fan") {
    if (action == "เปิดพัดลม" || action == "on") { setRelay2(true); } 
    else if (action == "ปิดพัดลม" || action == "off") { setRelay2(false); } 
    else if (action == "toggle") { toggleRelay2(); }
  } 
  // Relay 3 - Air Conditioner/แอร์
  else if (device == "relay3" || device == "ac" || device == "aircon") {
    if (action == "เปิดแอร์" || action == "on") { setRelay3(true); } 
    else if (action == "ปิดแอร์" || action == "off") { setRelay3(false); } 
    else if (action == "toggle") { toggleRelay3(); }
  } 
  // Relay 4 - Water Pump/ปั๊มน้ำ
  else if (device == "relay4" || device == "pump" || device == "water") {
    if (action == "เปิดปั๊ม" || action == "เปิดปั๊มน้ำ" || action == "on") { setRelay4(true); } 
    else if (action == "ปิดปั๊ม" || action == "ปิดปั๊มน้ำ" || action == "off") { setRelay4(false); } 
    else if (action == "toggle") { toggleRelay4(); }
  } 
  // Relay 5 - Heater/ฮีทเตอร์
  else if (device == "relay5" || device == "heater" || device == "heat") {
    if (action == "เปิดฮีท" || action == "เปิดฮีทเตอร์" || action == "on") { setRelay5(true); } 
    else if (action == "ปิดฮีท" || action == "ปิดฮีทเตอร์" || action == "off") { setRelay5(false); } 
    else if (action == "toggle") { toggleRelay5(); }
  } 
  // Relay 6 - Extra Device/อุปกรณ์เพิ่มเติม
  else if (device == "relay6" || device == "extra") {
    if (action == "เปิดอุปกรณ์เพิ่มเติม" || action == "on") { setRelay6(true); } 
    else if (action == "ปิดอุปกรณ์เพิ่มเติม" || action == "off") { setRelay6(false); } 
    else if (action == "toggle") { toggleRelay6(); }
  } 
  // System commands
  else if (action == "status") {
    publishDeviceStatus();
  } else if (action == "restart") {
    Serial.println("🔄 Restarting ESP32...");
    ESP.restart();
  }
}

// ===== SENSOR READING =====
void readSensors() {
  temperature = dht.readTemperature();
  humidity = dht.readHumidity();
  gasLevel = analogRead(GAS_SENSOR_PIN);
  
  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("❌ DHT Sensor Error!");
    temperature = -999;
    humidity = -999;
  }
  
  Serial.println("🌡️ Temp: " + String(temperature) + "°C, Humidity: " + String(humidity) + "%");
  Serial.println("🔥 Gas Level: " + String(gasLevel) + "/4095");
}

// ===== RELAY CONTROLS - เพิ่มเป็น 6 relay =====
void setRelay1(bool state) {
  relay1State = state;
  digitalWrite(RELAY1_PIN, state ? HIGH : LOW);
  Serial.println("💡 Relay 1 (Light): " + String(state ? "ON" : "OFF"));
  publishDeviceStatus();
  updateDisplay(); // อัพเดทจอทันที
}

void setRelay2(bool state) {
  relay2State = state;
  digitalWrite(RELAY2_PIN, state ? HIGH : LOW);
  Serial.println("🌀 Relay 2 (Fan): " + String(state ? "ON" : "OFF"));
  publishDeviceStatus();
  updateDisplay(); // อัพเดทจอทันที
}

void setRelay3(bool state) {
  relay3State = state;
  digitalWrite(RELAY3_PIN, state ? HIGH : LOW);
  Serial.println("❄️ Relay 3 (AC): " + String(state ? "ON" : "OFF"));
  publishDeviceStatus();
  updateDisplay(); // อัพเดทจอทันที
}

void setRelay4(bool state) {
  relay4State = state;
  digitalWrite(RELAY4_PIN, state ? HIGH : LOW);
  Serial.println("💧 Relay 4 (Pump): " + String(state ? "ON" : "OFF"));
  publishDeviceStatus();
  updateDisplay(); // อัพเดทจอทันที
}

void setRelay5(bool state) {
  relay5State = state;
  digitalWrite(RELAY5_PIN, state ? HIGH : LOW);
  Serial.println("🔥 Relay 5 (Heater): " + String(state ? "ON" : "OFF"));
  publishDeviceStatus();
  updateDisplay(); // อัพเดทจอทันที
}

void setRelay6(bool state) {
  relay6State = state;
  digitalWrite(RELAY6_PIN, state ? HIGH : LOW);
  Serial.println("⚡ Relay 6 (Extra): " + String(state ? "ON" : "OFF"));
  publishDeviceStatus();
  updateDisplay(); // อัพเดทจอทันที
}

// Toggle functions
void toggleRelay1() { setRelay1(!relay1State); }
void toggleRelay2() { setRelay2(!relay2State); }
void toggleRelay3() { setRelay3(!relay3State); }
void toggleRelay4() { setRelay4(!relay4State); }
void toggleRelay5() { setRelay5(!relay5State); }
void toggleRelay6() { setRelay6(!relay6State); }

// ===== MQTT PUBLISH FUNCTIONS - อัพเดทสำหรับ 6 relay =====
void publishSensorData() {
  StaticJsonDocument<200> doc;
  doc["temperature"] = temperature;
  doc["humidity"] = humidity;
  doc["gas_level"] = gasLevel;
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  if (mqtt.publish(topic_sensor, jsonString.c_str())) {
    Serial.println("📤 Sensor data sent to home/sensor");
  } else {
    Serial.println("❌ Failed to send sensor data");
  }
}

void publishDeviceStatus() {
  StaticJsonDocument<300> doc;
  doc["relay1"] = relay1State;  // Light
  doc["relay2"] = relay2State;  // Fan
  doc["relay3"] = relay3State;  // AC
  doc["relay4"] = relay4State;  // Pump
  doc["relay5"] = relay5State;  // Heater
  doc["relay6"] = relay6State;  // Extra
  
  String jsonString;
  serializeJson(doc, jsonString);
  
  if (mqtt.publish(topic_status, jsonString.c_str())) {
    Serial.println("📤 Device status sent to home/status (6 relays)");
  } else {
    Serial.println("❌ Failed to send status");
  }
}

void publishHeartbeat() {
  if (mqtt.publish(topic_heartbeat, "alive_6relays")) {
    Serial.println("💓 Heartbeat sent to home/heartbeat");
  } else {
    Serial.println("❌ Failed to send heartbeat");
  }
}