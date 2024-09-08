#include "WiFi_Module.h"
#include "Server_Module.h"
#include "OTA_Module.h"

// /github?url=https://raw.githubusercontent.com/mx3030/ota_test/master/build/ota_test.ino.bin

void setup() {
    Serial.begin(115200);
    WiFi_Module::connect(DEFAULT_NETWORK_SETTINGS);
    Server_Module::start();
    OTA_Module::init(Server_Module::server); 
}

void loop() {
    Serial.println("Test");
    delay(1000);
}
