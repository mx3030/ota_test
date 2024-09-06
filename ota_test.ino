#include "WiFi_Module.h"
#include "OTA_Module.h"

const char *firmwareURL = "http://192.168.178.86/ota_test.ino.bin"; 

void setup() {
    Serial.begin(115200);
    WiFi_Module::connect(DEFAULT_NETWORK_SETTINGS);
    OTA_Module::init(); 
    OTA_Module::initServer();
}

void loop() {
    OTA_Module::handleOTAClient();
    Serial.println("Test");
    delay(1000);
}

