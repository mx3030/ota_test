#include "WiFi_Module.h"
#include "Server_Module.h"
#include "OTA_Module.h"

void setup() {
    Serial.begin(115200);
    WiFi_Module::connect(DEFAULT_NETWORK_SETTINGS);
    Server_Module::start();
    OTA_Module::init(Server_Module::server); 
}

void loop() {
    Serial.println("Test208");
    delay(1000);
}
