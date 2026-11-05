#include <Wire.h>
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

// mpu6050_test.ino에서 확인한 raw I2C 읽기 방식 그대로 사용
// (WHO_AM_I가 0x68이 아닌 클론 칩이라 Adafruit_MPU6050 라이브러리는 사용하지 않음)

#define MPU6050_ADDR 0x68
#define PWR_MGMT_1   0x6B
#define ACCEL_XOUT_H 0x3B
#define SDA_PIN 21
#define SCL_PIN 22

#define ACCEL_SENS 16384.0
#define GYRO_SENS  131.0

// Flutter 쪽 ble_sensor_service.dart의 UUID와 반드시 동일해야 함
#define SERVICE_UUID        "12345678-1234-5678-1234-56789abcdef0"
#define CHARACTERISTIC_UUID "12345678-1234-5678-1234-56789abcdef1"

BLECharacteristic *pCharacteristic;
bool deviceConnected = false;

class ServerCallbacks : public BLEServerCallbacks {
  void onConnect(BLEServer *pServer) override {
    deviceConnected = true;
    Serial.println("폰과 연결됨");
  }
  void onDisconnect(BLEServer *pServer) override {
    deviceConnected = false;
    Serial.println("연결 끊김, 재광고 시작");
    pServer->getAdvertising()->start();
  }
};

void mpuWake() {
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(PWR_MGMT_1);
  Wire.write(0x00);
  Wire.endTransmission(true);
}

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);

  Wire.begin(SDA_PIN, SCL_PIN);
  Wire.setClock(100000);     // 400kHz보다 100kHz가 클론 칩에 더 안정적
  Wire.setTimeOut(50);       // 50ms 이상 응답 없으면 타임아웃 (무한대기 방지)
  mpuWake();

  BLEDevice::init("KickSafe-Sensor");
  BLEServer *pServer = BLEDevice::createServer();
  pServer->setCallbacks(new ServerCallbacks());

  BLEService *pService = pServer->createService(SERVICE_UUID);
  pCharacteristic = pService->createCharacteristic(
      CHARACTERISTIC_UUID,
      BLECharacteristic::PROPERTY_READ | BLECharacteristic::PROPERTY_NOTIFY);
  pCharacteristic->addDescriptor(new BLE2902());
  pService->start();

  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->addServiceUUID(SERVICE_UUID);
  pAdvertising->start();

  Serial.println("BLE 광고 시작: KickSafe-Sensor");
}

void loop() {
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(ACCEL_XOUT_H);
  uint8_t err = Wire.endTransmission(false);   // repeated start 유지

  if (err != 0) {
    Serial.printf("I2C 쓰기 실패, err=%d, 재초기화\n", err);
    Wire.begin(SDA_PIN, SCL_PIN);
    delay(10);
    return;
  }

  uint8_t n = Wire.requestFrom(MPU6050_ADDR, 14, true);
  if (n < 14) {
    Serial.printf("I2C 읽기 실패, 받은 바이트=%d, 재초기화\n", n);
    Wire.begin(SDA_PIN, SCL_PIN);
    delay(10);
    return;
  }

  int16_t rawAx = Wire.read() << 8 | Wire.read();
  int16_t rawAy = Wire.read() << 8 | Wire.read();
  int16_t rawAz = Wire.read() << 8 | Wire.read();
  int16_t rawTemp = Wire.read() << 8 | Wire.read();
  (void)rawTemp;
  int16_t rawGx = Wire.read() << 8 | Wire.read();
  int16_t rawGy = Wire.read() << 8 | Wire.read();
  int16_t rawGz = Wire.read() << 8 | Wire.read();

  float ax = rawAx / ACCEL_SENS;
  float ay = rawAy / ACCEL_SENS;
  float az = rawAz / ACCEL_SENS;
  float gx = rawGx / GYRO_SENS;
  float gy = rawGy / GYRO_SENS;
  float gz = rawGz / GYRO_SENS;

  if (deviceConnected) {
    char buf[80];
    snprintf(buf, sizeof(buf), "%.3f,%.3f,%.3f,%.2f,%.2f,%.2f", ax, ay, az, gx, gy, gz);
    pCharacteristic->setValue((uint8_t *)buf, strlen(buf));
    pCharacteristic->notify();
    Serial.printf("[%lu] 전송: %s\n", millis(), buf);   // 생존 확인용, 평소엔 지워도 됨
  }

  delay(300);
}

