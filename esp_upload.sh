#!/bin/bash

SKETCH="ota_test.ino"
LIBS=(wifi_module ota_module)
SPIFFS_DATA=$(realpath ./spiffs)
BAUDRATE=115200
PORT="/dev/ttyUSB0"
BOARDCONFIG="esp32:esp32:esp32"

BUILD_DIR=$(realpath ./build)
ARDUINO_USER_DIR=$(arduino-cli config dump --format json | jq -r .directories.user)
ARDUINO_DIR=$(arduino-cli config dump --format json | jq -r .directories.data)
PROPS=$(arduino-cli --verbose compile --fqbn $BOARDCONFIG --show-properties)
ESP_VERSION=$(echo "$PROPS" | grep '^version=' | sed -E 's/version=//')
MKSPIFFS_VERSION=$(echo "$PROPS" | grep 'mkspiffs' | grep 'runtime.tools' | head -1 | sed -E 's/\//\n/g' | tail -1)
ESPTOOL_VERSION=$(echo "$PROPS" | grep 'esptool' | grep 'runtime.tools' | head -1 | sed -E 's/\//\n/g' | tail -1)
ESPTOOL=$ARDUINO_DIR/packages/esp32/tools/esptool_py/$ESPTOOL_VERSION/esptool.py

# try to erase flash if wifi not working
if [ "$1" = "--erase_flash" ]; then
    python3 $ESPTOOL --port $PORT --baud $BAUDRATE --chip esp32 erase_flash
    exit
fi

# get partition information from default
DEFAULT_LAYOUT="$ARDUINO_DIR/packages/esp32/hardware/esp32/$ESP_VERSION/tools/partitions/default.csv"
APP_START=$(cat $DEFAULT_LAYOUT | grep '^app0' | sed -E 's/,/\n/g' | grep '0x' | head -1)
SPIFFS_START=$(cat $DEFAULT_LAYOUT | grep '^spiffs' | sed -E 's/,/\n/g' | grep '0x' | head -1)
SPIFFS_SIZE=$(cat $DEFAULT_LAYOUT | grep '^spiffs' | sed -E 's/,/\n/g' | grep '0x' | tail -1)

# compile
ESP_MODULES_DIR="/home/$USER/code/esp_modules"
LIBS_STRING=""
for lib in "${LIBS[@]}"; do
    LIBS_STRING="$LIBS_STRING --library $ESP_MODULES_DIR/$lib"
done
arduino-cli compile --fqbn $BOARDCONFIG $LIBS_STRING --export-binaries --output-dir $BUILD_DIR $SKETCH 

# compile other partition tables
#arduino-cli compile --fqbn $BOARDCONFIG $LIBS_STRING --export-binaries --output-dir $BUILD_DIR $SKETCH --build-property build.partitions=default 

if [ "$1" = "--spiffs" ]; then
    # create spiffs
    MKSPIFFS=$ARDUINO_DIR/packages/esp32/tools/mkspiffs/$MKSPIFFS_VERSION/mkspiffs
    SPIFFS_FILE=$BUILD_DIR/$SKETCH.spiffs.bin
    $MKSPIFFS -c $SPIFFS_DATA -b 4096 -p 256 -s $SPIFFS_SIZE $SPIFFS_FILE
fi

# flash
BOOTLOADER_FILE=$BUILD_DIR/$SKETCH.bootloader.bin
PARTITIONS_FILE=$BUILD_DIR/$SKETCH.partitions.bin
APP_FILE=$BUILD_DIR/$SKETCH.bin
FLASH_COMMAND="0x1000 $BOOTLOADER_FILE 0x8000 $PARTITIONS_FILE $APP_START $APP_FILE"
if [ $# -eq 1 ] && [ "$1" = "--spiffs" ]; then
    # flash spiffs
    FLASH_COMMAND="$FLASH_COMMAND $SPIFFS_START $SPIFFS_FILE"
fi

python3 $ESPTOOL --port $PORT --baud $BAUDRATE --chip esp32 --before default_reset --after hard_reset write_flash -z $FLASH_COMMAND

rm -r $BUILD_DIR

# monitor serial port
arduino-cli monitor -b $BOARDCONFIG -p $PORT -c baudrate=$BAUDRATE
