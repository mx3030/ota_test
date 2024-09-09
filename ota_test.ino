#include "WiFi_Module.h"
//#inlcude "MQTT_Module.h"
#include "Server_Module.h"
#include "WS_Module.h"
#include "OTA_Module.h"
#include <Arduino_JSON.h>

#define BAUDRATE 115200

void handleOTAMessage(JSONVar message) {
    if (strcmp((const char*)message["topic"], "ota") == 0) {
        const char* url = (const char*)message["data"];
        OTA_Module::handleAppDownloadFromURL(url);  
    }
}

// /github?url=https://raw.githubusercontent.com/mx3030/ota_test/master/build/ota_test.ino.bin

void setup() {
    Serial.begin(BAUDRATE);
    // activate wlan
    WiFi_Module::connect(DEFAULT_NETWORK_SETTINGS);
    // start server
    Server_Module::start();
    // start ws
    WS_Module::start(Server_Module::server);
    WS_Module::addDataHandler(handleOTAMessage);
    // activate ota
    OTA_Module::init(Server_Module::server); 
}

void loop() {
    Serial.println("Test");
    delay(1000);
}
