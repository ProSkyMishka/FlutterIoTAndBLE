#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

BLECharacteristic *pCharacteristic;
float temperature = 25.3;

void setup() {
  BLEDevice::init("ESP32-TEMP");
  BLEServer *pServer = BLEDevice::createServer();
  BLEService *pService = pServer->createService("12345678-1234-5678-1234-56789abcdef0");

  pCharacteristic = pService->createCharacteristic(
    "87654321-4321-6789-4321-fedcba987654",
    BLECharacteristic::PROPERTY_READ
  );

  pCharacteristic->setValue("25.3°C");
  pService->start();
  BLEAdvertising *pAdvertising = BLEDevice::getAdvertising();
  pAdvertising->start();
}

void loop() {
  delay(10000);
  temperature += 0.1;
  char tempStr[10];
  sprintf(tempStr, "%.1f°C", temperature);
  pCharacteristic->setValue(tempStr);
}
