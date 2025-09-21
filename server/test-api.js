const axios = require("axios");

// Configuration
const BASE_URL = process.env.API_URL || "http://localhost:8080";
const API_ENDPOINTS = {
  status: `${BASE_URL}/api/status`,
  chat: `${BASE_URL}/api/chat`,
  control: `${BASE_URL}/api/control`,
  sensors: `${BASE_URL}/api/sensors`,
  history: `${BASE_URL}/api/history`,
};

// Test functions
async function testServerStatus() {
  try {
    console.log("🔍 Testing server status...");
    const response = await axios.get(API_ENDPOINTS.status);
    console.log("✅ Server Status:", response.data);
    return true;
  } catch (error) {
    console.error("❌ Server Status Error:", error.message);
    return false;
  }
}

async function testAIChat() {
  try {
    console.log("🤖 Testing AI Chat...");
    const testMessages = [
      "เปิดไฟในห้องนอน",
      "ปิดไฟ",
      "อุณหภูมิเท่าไร",
      "ความชื้นเท่าไร",
    ];

    for (const message of testMessages) {
      const response = await axios.post(API_ENDPOINTS.chat, {
        message: message,
      });
      console.log(`💬 "${message}" → ${response.data.data.reply}`);
      await new Promise((resolve) => setTimeout(resolve, 1000)); // Wait 1 second
    }
    return true;
  } catch (error) {
    console.error("❌ AI Chat Error:", error.message);
    return false;
  }
}

async function testDeviceCommands() {
  try {
    console.log("📱 Testing device commands...");
    const testCommands = [
      { device: "relay1", action: "เปิดไฟ" },
      { device: "relay2", action: "ปิดพัดลม" },
      { device: "ac", action: "ตั้งอุณหภูมิ 25" },
    ];

    for (const cmd of testCommands) {
      const response = await axios.post(API_ENDPOINTS.control, cmd);
      console.log(`📡 Command sent: ${cmd.device} - ${cmd.action}`);
      console.log(`   Response: ${response.data.message}`);
      await new Promise((resolve) => setTimeout(resolve, 500)); // Wait 0.5 second
    }
    return true;
  } catch (error) {
    console.error("❌ Device Commands Error:", error.message);
    return false;
  }
}

async function testDataRetrieval() {
  try {
    console.log("📊 Testing data retrieval...");

    // Test sensors endpoint
    const sensorsResponse = await axios.get(API_ENDPOINTS.sensors);
    console.log(
      `🌡️ Sensors: ${sensorsResponse.data.data.length} records found`
    );

    // Test history endpoint
    const historyResponse = await axios.get(API_ENDPOINTS.history);
    console.log(
      `💬 Chat History: ${historyResponse.data.data.length} messages found`
    );

    return true;
  } catch (error) {
    console.error("❌ Data Retrieval Error:", error.message);
    return false;
  }
}

async function runAllTests() {
  console.log("🚀 Starting API Tests...");
  console.log(`🌐 Base URL: ${BASE_URL}`);
  console.log("=".repeat(50));

  const results = {
    status: await testServerStatus(),
    chat: await testAIChat(),
    commands: await testDeviceCommands(),
    data: await testDataRetrieval(),
  };

  console.log("=".repeat(50));
  console.log("📊 Test Results:");
  console.log(`   Server Status: ${results.status ? "✅ PASS" : "❌ FAIL"}`);
  console.log(`   AI Chat: ${results.chat ? "✅ PASS" : "❌ FAIL"}`);
  console.log(
    `   Device Commands: ${results.commands ? "✅ PASS" : "❌ FAIL"}`
  );
  console.log(`   Data Retrieval: ${results.data ? "✅ PASS" : "❌ FAIL"}`);

  const passed = Object.values(results).filter(Boolean).length;
  const total = Object.keys(results).length;

  console.log(`\n🎯 Overall: ${passed}/${total} tests passed`);

  if (passed === total) {
    console.log("🎉 All tests passed! Server is working correctly.");
  } else {
    console.log("⚠️  Some tests failed. Check the logs above for details.");
  }
}

// Run tests if this file is executed directly
if (require.main === module) {
  runAllTests().catch(console.error);
}

module.exports = {
  testServerStatus,
  testAIChat,
  testDeviceCommands,
  testDataRetrieval,
  runAllTests,
};
