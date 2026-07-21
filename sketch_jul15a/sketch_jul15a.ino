#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>
#include <Wire.h>
#include <MPU6050.h>

#define SERVICE_UUID        "12345678-1234-1234-1234-123456789abc"
#define CHARACTERISTIC_UUID "abcdefab-1234-1234-1234-abcdefabcdef"
#define HEADER 0xAA
#define SAMPLE_RATE_MS 20

MPU6050 mpu;
BLECharacteristic* pCharacteristic;
bool deviceConnected = false;
uint8_t seqNum = 0;

class MyServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer* pServer) {
    deviceConnected = true;
    Serial.println("연결됨!");
  }
  void onDisconnect(BLEServer* pServer) {
    deviceConnected = false;
    Serial.println("연결 끊김");
    pServer->startAdvertising();
  }
};

void sendImuPacket(float ax, float ay, float az,
                   float gx, float gy, float gz) {
  uint8_t packet[28];
  uint8_t idx = 0;

  packet[idx++] = HEADER;
  packet[idx++] = seqNum++;

  memcpy(&packet[idx], &ax, 4); idx += 4;
  memcpy(&packet[idx], &ay, 4); idx += 4;
  memcpy(&packet[idx], &az, 4); idx += 4;
  memcpy(&packet[idx], &gx, 4); idx += 4;
  memcpy(&packet[idx], &gy, 4); idx += 4;
  memcpy(&packet[idx], &gz, 4); idx += 4;

  uint8_t checksum = 0;
  for (int i = 1; i < 27; i++) checksum ^= packet[i];
  packet[idx++] = checksum;

  pCharacteristic->setValue(packet, 28);
  pCharacteristic->notify();
}

void setup() {
  Serial.begin(115200);
  Wire.begin(21,22);

  mpu.initialize();
  if (!mpu.testConnection()) {
    Serial.println("MPU6050 연결 실패!");
    while (1);
  }
  Serial.println("MPU6050 연결 성공!");

  BLEDevice::init("KickSafe_ESP32");
  BLEServer* pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  BLEService* pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
    CHARACTERISTIC_UUID,
    BLECharacteristic::PROPERTY_NOTIFY
  );
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();

  BLEDevice::getAdvertising()->addServiceUUID(SERVICE_UUID);
  BLEDevice::getAdvertising()->start();
  Serial.println("BLE 광고 시작!");
}

void loop() {
  int16_t ax, ay, az, gx, gy, gz;
  mpu.getMotion6(&ax, &ay, &az, &gx, &gy, &gz);

  float fax = ax / 16384.0 * 9.81;
  float fay = ay / 16384.0 * 9.81;
  float faz = az / 16384.0 * 9.81;
  float fgx = gx / 131.0;
  float fgy = gy / 131.0;
  float fgz = gz / 131.0;

  if (deviceConnected) {
    sendImuPacket(fax, fay, faz, fgx, fgy, fgz);
  }

  Serial.printf("AX:%.2f AY:%.2f AZ:%.2f | GX:%.2f GY:%.2f GZ:%.2f\n",
                fax, fay, faz, fgx, fgy, fgz);

  delay(SAMPLE_RATE_MS);
}
