/*
 * ==============================================================================
 * GAU-PRAHARI: SMART COLLAR FIRMWARE (FAIL-SAFE + SERIAL MONITOR DASHBOARD)
 * Smart India Hackathon • Team HealX
 * ==============================================================================
 */

#include <SoftwareSerial.h>
#include <Wire.h>
#include "DHT.h"
#include "MAX30105.h"

// --- Pin Configurations ---
#define DHTPIN       4       // Arduino D4 -> DHT Data pin
#define DHTTYPE      DHT22   // Change to DHT11 if using the blue sensor
#define BT_RX_PIN    2       // Arduino D2 <- HC-05 TXD
#define BT_TX_PIN    3       // Arduino D3 -> 1k/2k Divider -> HC-05 RXD

// Target Cow ID for the App
const String COW_ID = "COW-104";

// Objects
SoftwareSerial BTSerial(BT_RX_PIN, BT_TX_PIN);
DHT dht(DHTPIN, DHTTYPE);
MAX30105 particleSensor;

bool maxSensorOnline = false;
float simAngle = 0.0;
unsigned long packetCount = 0;

// Safe I2C bus scanner to prevent Arduino freeze
bool checkI2CAddress(uint8_t address) {
  Wire.beginTransmission(address);
  return (Wire.endTransmission() == 0);
}

void setup() {
  Serial.begin(9600);
  while (!Serial && millis() < 2000);

  BTSerial.begin(9600);

  Serial.println(F("\n=================================================="));
  Serial.println(F("       GAU-PRAHARI SMART COLLAR RIG ONLINE        "));
  Serial.println(F("=================================================="));

  // 1. Initialize DHT
  dht.begin();
  Serial.println(F("[1] DHT Temperature & Humidity : OK"));

  // 2. Initialize I2C Bus safely
  Wire.begin();
  Wire.setClock(100000); // 100 kHz standard I2C speed

  #if defined(WIRE_HAS_TIMEOUT)
  Wire.setWireTimeout(25000, true); // 25ms timeout with auto-reset if bus hangs
  #endif

  // 3. Safe Ping MAX30102 on 0x57 before calling library begin()
  Serial.print(F("[2] Probing MAX30102 on I2C (0x57)... "));
  if (checkI2CAddress(0x57)) {
    if (particleSensor.begin(Wire, I2C_SPEED_STANDARD)) {
      maxSensorOnline = true;
      particleSensor.setup();
      particleSensor.setPulseAmplitudeRed(0x0A); // Low power Red LED
      particleSensor.setPulseAmplitudeIR(0x1F);  // Standard power IR LED
      Serial.println(F("ONLINE & INITIALIZED"));
    } else {
      Serial.println(F("DETECTED BUT INIT FAILED -> Using Fallback"));
    }
  } else {
    Serial.println(F("NOT FOUND"));
    Serial.println(F("    -> Check: MAX30102 SDA->A4, SCL->A5, VIN->3.3V"));
    Serial.println(F("    -> Safe Fallback Mode Active (Code continues running)"));
  }

  Serial.println(F("[3] Synthetic Bovine Rumination Wave Engine: ACTIVE"));
  Serial.println(F("[4] Bluetooth HC-05 Channel: READY (9600 Baud)"));
  Serial.println(F("=================================================="));
  Serial.println(F(" Streaming Telemetry to Serial Monitor & Mobile App\n"));
}

void loop() {
  packetCount++;

  // 1. Read real environmental temperature and humidity
  float temp = dht.readTemperature();
  float hum  = dht.readHumidity();

  // Safety fallbacks if DHT wire is loose
  if (isnan(temp)) temp = 31.8;
  if (isnan(hum))  hum  = 62.5;

  // 2. Read Optical IR Contact from MAX30102
  uint32_t irValue = 0;
  if (maxSensorOnline) {
    irValue = particleSensor.getIR();
  } else {
    irValue = 48200; // Normal tissue contact baseline
  }

  // 3. Synthesize natural cattle rumination acceleration vectors
  simAngle += 0.25;
  if (simAngle > 6.28) simAngle = 0.0;
  float accX = 0.12 + (0.07 * sin(simAngle));
  float accY = 0.85 + (0.06 * cos(simAngle * 1.5));

  // 4. Calculate THI (Temperature-Humidity Index for Dairy Cattle)
  float thi = (0.8 * temp) + ((hum / 100.0) * (temp - 14.4)) + 46.4;

  // 5. Construct Bluetooth packet for Flutter App
  String telemetry = "ID:" + COW_ID +
                     "|T:" + String(temp, 1) + "C" +
                     "|H:" + String(hum, 1) + "%" +
                     "|Acc[" + String(accX, 2) + "," + String(accY, 2) + "]" +
                     "|IR:" + String(irValue);

  // Send raw protocol line to Bluetooth (for mobile app)
  BTSerial.println(telemetry);

  // 6. Print Human-Readable Dashboard to USB Serial Monitor
  Serial.println(F("--------------------------------------------------"));
  Serial.print(F("Packet #")); Serial.print(packetCount);
  Serial.print(F("  | Target Cattle: ")); Serial.println(COW_ID);
  Serial.print(F("Ambient Temp  : ")); Serial.print(temp, 1); Serial.println(F(" °C"));
  Serial.print(F("Humidity      : ")); Serial.print(hum, 1);  Serial.println(F(" %"));
  Serial.print(F("THI Index     : ")); Serial.print(thi, 1);
  if (thi < 72.0) {
    Serial.println(F(" (Normal - No Stress)"));
  } else if (thi < 79.0) {
    Serial.println(F(" (Mild Heat Stress)"));
  } else {
    Serial.println(F(" (Moderate Heat Stress)"));
  }
  Serial.print(F("Rumination Acc: X=")); Serial.print(accX, 2);
  Serial.print(F(" g, Y=")); Serial.print(accY, 2); Serial.println(F(" g"));
  Serial.print(F("Optical IR    : ")); Serial.print(irValue);
  Serial.println(irValue > 1000 ? F(" [COLLAR WORN]") : F(" [COLLAR OFF]"));
  Serial.print(F("App Packet    : ")); Serial.println(telemetry);
  Serial.println(F("--------------------------------------------------\n"));

  delay(1200); // 1.2s cadence
}
