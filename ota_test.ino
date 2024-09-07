#include "WiFi_Module.h"
#include "OTA_Module.h"

void setup() {
    Serial.begin(115200);
    //WiFi_Module::connect(DEFAULT_NETWORK_SETTINGS);
    WiFi_Module::connect(WLAN_7270_SETTINGS);
    OTA_Module::init(); 
    OTA_Module::initServer();
}

void loop() {
    OTA_Module::otaServer->handleClient();
    Serial.println("Test");
    delay(1000);
}

