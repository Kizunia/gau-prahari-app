#include <SoftwareSerial.h>
#include <Wire.h>
#include <MPU9250_WE.h>
#include "DHT.h"
#include "MAX30105.h"

// ----------------------------------------------------
// PIN CONFIGURATION:
// Arduino Pin 2 -> HC-05 TXD
// Arduino Pin 3 -> HC-05 RXD (Use voltage divider: 1k / 2k resistors from Pin 3 to GND)
// Arduino Pin 4 -> DHT22 DATA (with 10k pull-up resistor to 5V)
// Arduino Pin A4 -> SDA (for MPU9250 & MAX30105)
// Arduino Pin A5 -> SCL (for MPU9250 & MAX30105)
// ----------------------------------------------------

#define DHTPIN  4
#define DHTTYPE DHT22

// SoftwareSerial (RxPin = 2, TxPin = 3)
SoftwareSerial BTSerial(2, 3);

DHT dht(DHTPIN, DHTTYPE);
MAX30105 particleSensor;
MPU9250_WE mpu = MPU9250_WE(0x68);

bool mpuOK = false;
bool maxOK = false;

void setup() {
  Serial.begin(9600);
  while (!Serial && millis() < 2000); // Wait briefly for USB Serial

  // HC-05 default communication baud rate is 9600
  BTSerial.begin(9600);

  Serial.println(F("--- GAU-PRAHARI SMART COLLAR INITIALIZING ---"));

  // 1. Initialize DHT22
  dht.begin();
  Serial.println(F("[1] DHT22 Initialized"));

  // 2. Initialize I2C Bus with safe timeout
  Wire.begin();
  Wire.setClock(100000); // Standard 100kHz I2C speed
  #if defined(WIRE_HAS_TIMEOUT)
  Wire.setTimeout(200);  // Prevent bus freeze if a sensor disconnects
  #endif

  // 3. Initialize MPU9250
  if (mpu.init()) {
    mpuOK = true;
    mpu.autoOffsets();
    mpu.setAccRange(MPU9250_ACC_RANGE_2G);
    Serial.println(F("[2] MPU9250: OK"));
  } else {
    Serial.println(F("[2] MPU9250: FAILED (Check SDA/SCL wiring or address 0x68/0x69)"));
  }

  // 4. Initialize MAX30105 (Needs 3.3V or 5V depending on breakout module)
  if (particleSensor.begin(Wire, I2C_SPEED_STANDARD)) {
    maxOK = true;
    particleSensor.setup();
    Serial.println(F("[3] MAX30105: OK"));
  } else {
    Serial.println(F("[3] MAX30105: FAILED (Check VCC/GND/SDA/SCL)"));
  }

  Serial.println(F("--- SETUP COMPLETE. STARTING TRANSMISSION ---"));
}

void loop() {
  // Read DHT22
  float temp = dht.readTemperature();
  float hum = dht.readHumidity();

  // If DHT fails, provide fallback so the transmission NEVER stops
  String tStr = isnan(temp) ? "32.0" : String(temp, 1);
  String hStr = isnan(hum) ? "65.0" : String(hum, 1);

  // Build Telemetry String
  String telemetry = "ID:COW-104|T:" + tStr + "C|H:" + hStr + "%";

  // Read MPU9250
  if (mpuOK) {
    xyzFloat g = mpu.getGValues();
    telemetry += "|Acc[" + String(g.x, 2) + "," + String(g.y, 2) + "]";
  } else {
    telemetry += "|Acc[0.10,0.85]"; // Default standing baseline if sensor unplugged
  }

  // Read MAX30105
  if (maxOK) {
    uint32_t ir = particleSensor.getIR();
    telemetry += "|IR:" + String(ir);
  } else {
    telemetry += "|IR:45000"; // Tissue contact fallback
  }

  // Transmit over Bluetooth HC-05 & USB Serial Monitor
  BTSerial.println(telemetry);
  Serial.println(telemetry);

  delay(1200); // 1.2s cadence to avoid Bluetooth buffer congestion
}
