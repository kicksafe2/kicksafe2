#include <Wire.h>

// Adafruit_MPU6050 라이브러리의 begin()이 WHO_AM_I 값을 엄격하게 검사하다가
// 클론 칩 등에서 실패하는 경우가 있어, 라이브러리 없이 레지스터를 직접 읽습니다.

#define MPU6050_ADDR 0x68
#define PWR_MGMT_1   0x6B
#define WHO_AM_I     0x75
#define ACCEL_XOUT_H 0x3B
#define SDA_PIN 21
#define SCL_PIN 22

void setup() {
  Serial.begin(115200);
  while (!Serial) delay(10);

  Wire.begin(SDA_PIN, SCL_PIN);

  // WHO_AM_I 레지스터 확인 (정상 MPU6050은 보통 0x68)
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(WHO_AM_I);
  Wire.endTransmission(false);
  Wire.requestFrom(MPU6050_ADDR, 1, true);
  byte whoami = Wire.read();
  Serial.print("WHO_AM_I: 0x");
  Serial.println(whoami, HEX);

  // 슬립 모드 해제
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(PWR_MGMT_1);
  Wire.write(0x00);
  Wire.endTransmission(true);

  Serial.println("MPU6050 초기화 완료 (raw I2C)");
}

// 레지스터 설정을 안 건드렸으므로 기본 감도값 사용
// 가속도: ±2g 범위 -> 16384 LSB/g
// 자이로: ±250deg/s 범위 -> 131 LSB/(deg/s)
#define ACCEL_SENS 16384.0
#define GYRO_SENS  131.0

void loop() {
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(ACCEL_XOUT_H);
  Wire.endTransmission(false);
  Wire.requestFrom(MPU6050_ADDR, 14, true);

  int16_t rawAx = Wire.read() << 8 | Wire.read();
  int16_t rawAy = Wire.read() << 8 | Wire.read();
  int16_t rawAz = Wire.read() << 8 | Wire.read();
  int16_t rawTemp = Wire.read() << 8 | Wire.read();
  int16_t rawGx = Wire.read() << 8 | Wire.read();
  int16_t rawGy = Wire.read() << 8 | Wire.read();
  int16_t rawGz = Wire.read() << 8 | Wire.read();

  float ax = rawAx / ACCEL_SENS;
  float ay = rawAy / ACCEL_SENS;
  float az = rawAz / ACCEL_SENS;

  float gx = rawGx / GYRO_SENS;
  float gy = rawGy / GYRO_SENS;
  float gz = rawGz / GYRO_SENS;

  float tempC = rawTemp / 340.0 + 36.53;

  Serial.print("Accel(g) X:"); Serial.print(ax, 3);
  Serial.print(" Y:"); Serial.print(ay, 3);
  Serial.print(" Z:"); Serial.print(az, 3);

  Serial.print(" | Gyro(deg/s) X:"); Serial.print(gx, 2);
  Serial.print(" Y:"); Serial.print(gy, 2);
  Serial.print(" Z:"); Serial.print(gz, 2);

  Serial.print(" | Temp:"); Serial.print(tempC, 2);
  Serial.println(" C");

  delay(500);
}
