/*
 * =====================================================================
 * GAU-PRAHARI ARDUINO HARDWARE TELEMETRY FIRMWARE
 * =====================================================================
 * Pin Connections:
 *   - pH Sensor Analog Out      -> Arduino A0
 *   - MQ-2 Gas Sensor Analog Out-> Arduino A1
 *   - HC-SR04 Ultrasonic TRIG   -> Arduino Pin 10
 *   - HC-SR04 Ultrasonic ECHO   -> Arduino Pin 11
 *   - HC-05 Bluetooth TX        -> Arduino Pin 8 (SoftwareSerial RX)
 *   - HC-05 Bluetooth RX        -> Arduino Pin 9 (SoftwareSerial TX, via voltage divider)
 *   - VCC                       -> 5V
 *   - GND                       -> GND
 * =====================================================================
 */

#include <SoftwareSerial.h>

// -------- PIN DEFINITIONS --------
#define PH_PIN    A0
#define MQ2_PIN   A1
#define TRIG_PIN  10
#define ECHO_PIN  11
#define BT_RX_PIN 8   // Arduino D8 <- HC-05 TX
#define BT_TX_PIN 9   // Arduino D9 -> HC-05 RX (Voltage Divider recommended)

SoftwareSerial BT(BT_RX_PIN, BT_TX_PIN);

// Calibration offsets
const float PH_SLOPE = 3.5;       // Standard pH sensor scale factor
const float PH_OFFSET = 0.0;      // Adjust if baseline differs

void setup() {
  Serial.begin(9600);
  BT.begin(9600);

  pinMode(TRIG_PIN, OUTPUT);
  pinMode(ECHO_PIN, INPUT);
  pinMode(PH_PIN, INPUT);
  pinMode(MQ2_PIN, INPUT);

  Serial.println(F("============================================"));
  Serial.println(F("  Gau-Prahari Hardware Sensor Rig Online    "));
  Serial.println(F("============================================"));
  
  BT.println(F("{\"status\":\"online\",\"device\":\"Gau-Prahari-HC05\"}"));
  delay(1000);
}

// -------- SENSOR READ FUNCTIONS --------

// 1. Physical pH Sensor (Average of 10 ADC samples for noise reduction)
float readPhysicalPH() {
  long sum = 0;
  for (int i = 0; i < 10; i++) {
    sum += analogRead(PH_PIN);
    delay(10);
  }
  float avgAdc = (float)sum / 10.0;
  float voltage = (avgAdc * 5.0) / 1023.0;
  
  // Convert voltage to pH
  float calculatedPH = 7.0 + ((2.5 - voltage) * PH_SLOPE) + PH_OFFSET;
  
  // Constrain to physical bounds
  if (calculatedPH < 0.0) calculatedPH = 0.0;
  if (calculatedPH > 14.0) calculatedPH = 14.0;
  
  return calculatedPH;
}

// 2. MQ-2 Gas & Spoilage Sensor
int readPhysicalGas() {
  long sum = 0;
  for (int i = 0; i < 5; i++) {
    sum += analogRead(MQ2_PIN);
    delay(5);
  }
  return sum / 5; // Raw ADC 0 - 1023
}

// 3. HC-SR04 Ultrasonic Distance Sensor (cm)
int readPhysicalDistance() {
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  long duration = pulseIn(ECHO_PIN, HIGH, 30000); // 30ms timeout (~5m max)
  if (duration == 0) {
    return 999; // Out of range or sensor disconnected
  }
  
  int distanceCm = duration * 0.034 / 2;
  return distanceCm;
}

// -------- MAIN LOOP --------
void loop() {
  // Read actual live hardware sensors
  float livePH = readPhysicalPH();
  int liveGas = readPhysicalGas();
  int liveDist = readPhysicalDistance();

  // 1. Output human-readable debug info to Arduino IDE Serial Monitor
  Serial.print(F("[DEBUG] pH: "));
  Serial.print(livePH, 2);
  Serial.print(F(" | Gas: "));
  Serial.print(liveGas);
  Serial.print(F(" | Fill Dist: "));
  Serial.print(liveDist);
  Serial.println(F(" cm"));

  // 2. Transmit structured telemetry over Bluetooth (HC-05) to Gau-Prahari Flutter App
  BT.print(F("{\"ph\":"));
  BT.print(livePH, 2);
  BT.print(F(",\"gas\":"));
  BT.print(liveGas);
  BT.print(F(",\"distance\":"));
  BT.print(liveDist);
  BT.println(F("}"));

  // Transmit at 1 Hz (every 1000ms)
  delay(1000);
}
