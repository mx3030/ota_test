################################################################################
# settings
################################################################################

SRC = ota_test.ino
CUSTOM_PARTITION = custom_partition.csv
SPIFFS_DIR = spiffs
ESP32_IP_ADDRESS = 192.168.178.129
OTA_PORT = 8266

ESP_MODULES_DIR = $(HOME)/code/esp_modules

INCLUDES = $(ESP_MODULES_DIR)/ota_module/ \
		   $(ESP_MODULES_DIR)/server_module/ \
		   $(ESP_MODULES_DIR)/wifi_module/

################################################################################
# Create build directory and get properties
################################################################################

BAUDRATE = 115200
PORT = /dev/ttyUSB0
BOARDCONFIG = esp32:esp32:esp32
BUILD_DIR = build
CUSTOM_PARTITIONS_BIN = $(BUILD_DIR)/$(SRC).custom_partitions.bin
SPIFFS_BIN = $(BUILD_DIR)/$(SRC).spiffs.bin

PROPS_FILE = $(BUILD_DIR)/props.tmp
$(shell mkdir -p $(BUILD_DIR))
$(shell arduino-cli compile --fqbn $(BOARDCONFIG) --show-properties > $(PROPS_FILE))

MKSPIFFS_PATH = $(shell grep 'runtime.tools.mkspiffs.path=' $(PROPS_FILE) | sed 's/runtime.tools.mkspiffs.path=//')
MKSPIFFS = $(MKSPIFFS_PATH)/mkspiffs
$(info MKSPIFFS_PATH: $(MKSPIFFS))

ESPTOOL_PATH = $(shell grep 'runtime.tools.esptool_py.path=' $(PROPS_FILE) | sed 's/runtime.tools.esptool_py.path=//')
ESPTOOL = $(ESPTOOL_PATH)/esptool.py
$(info ESPTOOL_PATH: $(ESPTOOL))

ESPOTA_CMD = $(shell grep 'tools.esptool_py.network_cmd=' $(PROPS_FILE) | sed 's/tools.esptool_py.network_cmd=//')
$(info ESPOTA_CMD: $(ESPOTA_CMD))

ESP32PART_CMD = $(shell grep 'tools.gen_esp32part.cmd=' $(PROPS_FILE) | sed 's/tools.gen_esp32part.cmd=//')
$(info ESP32PART_CMD: $(ESP32PART_CMD))

DEFAULT_PARTITIONS = $(shell grep 'runtime.platform.path=' $(PROPS_FILE) | sed 's/runtime.platform.path=//')/tools/partitions/default.csv
$(info DEFAULT_PARTITIONS: $(DEFAULT_PARTITIONS))
CUSTOM_PARTITIONS = $(if $(wildcard $(CUSTOM_PARTITION)),$(CUSTOM_PARTITION),$(DEFAULT_PARTITIONS))
$(info CUSTOM_PARTITIONS: $(CUSTOM_PARTITIONS))

# Extract partition data
$(info Partition data:)
APP_START = $(shell cat $(CUSTOM_PARTITIONS) | grep '^app0' | sed -E 's/,/\n/g' | grep '0x' | head -1)
$(info APP_START: $(APP_START))
SPIFFS_START = $(shell cat $(CUSTOM_PARTITIONS) | grep '^spiffs' | sed -E 's/,/\n/g' | grep '0x' | head -1)
$(info SPIFFS_START: $(SPIFFS_START))
SPIFFS_SIZE = $(shell cat $(CUSTOM_PARTITIONS) | grep '^spiffs' | sed -E 's/,/\n/g' | grep '0x' | tail -1)
$(info SPIFFS_SIZE: $(SPIFFS_SIZE))

################################################################################
# define targets
################################################################################

.PHONY: default help partition spiffs compile build flash-bootloader \
        flash-spiffs flash-app flash-all ota-app ota-spiffs run \
        run-all run-ota run-all-ota erase monitor clean

# Default target
default:
	@echo "No target specified. Run make help for available targets."

# Help target
help:
	@echo "Available targets:"
	@echo "  partition      	- Generate partition binary"
	@echo "  spiffs         	- Create SPIFFS image"
	@echo "  compile        	- Compile the source code"
	@echo "  build 				- Run partition, spiffs and compile"
	@echo "  flash-bootloader 	- Flash bootloader"
	@echo "  flash-partition 	- Flash parition table"
	@echo "  flash-spiffs   	- Flash SPIFFS"
	@echo "  flash-app      	- Flash application"
	@echo "  flash-all      	- Flash bootloader, SPIFFS, and application"
	@echo "  ota-app        	- Upload application via OTA"
	@echo "  ota-spiffs     	- Upload SPIFFS via OTA"
	@echo "  run            	- Compile and flash application only"
	@echo "  run-all        	- Full build, partition, and flash"
	@echo "  run-ota        	- Compile and upload application via OTA"
	@echo "  run-all-ota    	- Compile and upload spiffs and application via OTA"
	@echo "  erase          	- Erase flash"
	@echo "  monitor        	- Start serial monitor"
	@echo "  clean          	- Clean build directory"

# Determine if SPIFFS should be present
SPIFFS_PRESENT := $(if $(SPIFFS_START),$(if $(wildcard $(CURDIR)/$(SPIFFS_DIR)),true,false),false)

# Partition target
partition:
	@echo "Generating partition binary..."
	@echo "Using partition file: $(CUSTOM_PARTITIONS)"
	$(ESP32PART_CMD) $(CUSTOM_PARTITIONS) $(CUSTOM_PARTITIONS_BIN)
	@echo "Partition binary generated: $(CUSTOM_PARTITIONS_BIN)"

# SPIFFS target
spiffs:
	@if [ "$(SPIFFS_PRESENT)" = "true" ]; then \
		echo "Creating SPIFFS image..."; \
		echo "Using SPIFFS size: $(SPIFFS_SIZE)"; \
		$(MKSPIFFS) -c $(SPIFFS_DIR) -b 4096 -p 256 -s $(SPIFFS_SIZE) $(SPIFFS_BIN); \
		echo "SPIFFS image created: $(SPIFFS_BIN)"; \
	else \
		echo "No SPIFFS entry found in partition file or SPIFFS directory does not exist."; \
	fi

# Library flags
LIB_FLAGS := $(foreach dir,$(INCLUDES),--library $(dir))

# Compile target
compile: $(PROPS_FILE)
	@echo "Compiling source..."
	@echo "Library flags: $(LIB_FLAGS)"
	@arduino-cli compile --fqbn $(BOARDCONFIG) $(LIB_FLAGS) --export-binaries --output-dir $(BUILD_DIR) $(SRC) || (echo "Compilation failed!" && exit 1)
	@echo "Compilation complete. Binaries in $(BUILD_DIR)"

# Available after arduino cli compilation
ARDUINO_CLI_BOOTLOADER_BIN := $(BUILD_DIR)/$(SRC).bootloader.bin
ARDUINO_CLI_PARTITIONS_BIN := $(BUILD_DIR)/$(SRC).partitions.bin
ARDUINO_CLI_APP_BIN := $(BUILD_DIR)/$(SRC).bin

# Build target
build: partition spiffs compile

# Flash command
ESPTOOL_FLASH := python3 $(ESPTOOL) --port $(PORT) --baud $(BAUDRATE) --chip esp32 --before default_reset --after hard_reset write_flash --flash_freq 40m -z

# Flash bootloader target
flash-bootloader:
	@echo "Flashing bootloader..."
	@echo "Using bootloader binary: $(ARDUINO_CLI_BOOTLOADER_BIN)"
	$(ESPTOOL_FLASH) 0x1000 $(ARDUINO_CLI_BOOTLOADER_BIN)
	@echo "Bootloader flashed"

# Flash partition target
flash-partition:
	@if [ -f "$(CUSTOM_PARTITIONS_BIN)" ]; then \
		echo "Flashing custom partition table..."; \
		echo "Using custom partition binary: $(CUSTOM_PARTITIONS_BIN)"; \
		$(ESPTOOL_FLASH) 0x8000 $(CUSTOM_PARTITIONS_BIN); \
	else \
		echo "Custom partition binary not found, flashing Arduino CLI partition binary..."; \
		echo "Using Arduino CLI partition binary: $(ARDUINO_CLI_PARTITIONS_BIN)"; \
		$(ESPTOOL_FLASH) 0x8000 $(ARDUINO_CLI_PARTITIONS_BIN); \
	fi
	@echo "Partition table flashed"

# Flash SPIFFS target
flash-spiffs:
	@if [ "$(SPIFFS_PRESENT)" = "true" ]; then \
		echo "Flashing SPIFFS..."; \
		echo "Using SPIFFS binary: $(SPIFFS_BIN) at address $(SPIFFS_START)"; \
		$(ESPTOOL_FLASH) $(SPIFFS_START) $(SPIFFS_BIN); \
		echo "SPIFFS flashed"; \
	else \
		echo "No SPIFFS entry found in partition file."; \
	fi

# Flash application target
flash-app:
	@echo "Flashing application..."
	@echo "Using application binary: $(ARDUINO_CLI_APP_BIN) at address $(APP_START)"
	$(ESPTOOL_FLASH) $(APP_START) $(ARDUINO_CLI_APP_BIN)
	@echo "Application flashed"

flash-all: flash-bootloader flash-partition flash-spiffs flash-app

# OTA targets
ota-app:
	@echo "Uploading application via OTA..."
	@echo "Using application binary: $(ARDUINO_CLI_APP_BIN)"
	$(ESPOTA_CMD) -i $(ESP32_IP_ADDRESS) -p $(OTA_PORT) -f $(ARDUINO_CLI_APP_BIN)
	@echo "Application uploaded via OTA"

ota-spiffs:
	@if [ "$(SPIFFS_PRESENT)" = "true" ]; then \
		echo "Uploading SPIFFS via OTA..."; \
		echo "Using SPIFFS binary: $(SPIFFS_BIN)"; \
		$(ESPOTA_CMD) -i $(ESP32_IP_ADDRESS) -p $(OTA_PORT) -s -f $(SPIFFS_BIN); \
		echo "SPIFFS uploaded via OTA"; \
	else \
		echo "No SPIFFS entry found in partition file or SPIFFS directory does not exist."; \
	fi

# Run targets
run: compile flash-app

run-all: partition spiffs compile flash-all

run-ota: compile ota-app

run-all-ota: compile ota-spiffs ota-app

# Erase target
erase:
	@echo "Erasing flash..."
	python3 $(ESPTOOL) --port $(PORT) --baud $(BAUDRATE) --chip esp32 erase_flash
	@echo "Flash erased"

# Monitor target
monitor:
	@echo "Starting serial monitor..."
	arduino-cli monitor -b $(BOARDCONFIG) -p $(PORT) -c baudrate=$(BAUDRATE)

# Clean target
clean:
	@echo "Cleaning build directory..."
	rm -rf $(BUILD_DIR) $(PROPS_FILE)
	@echo "Build directory cleaned"

