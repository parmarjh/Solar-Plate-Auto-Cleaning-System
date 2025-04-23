#!/bin/bash
#
# Solar Plate Auto-Cleaning System Deployment Script
# This script helps deploy the code to Arduino boards
#

# Set default values
ARDUINO_PORT="/dev/ttyUSB0"
BOARD_TYPE="arduino:avr:uno"
SKETCH_PATH="src/main.ino"
ESP32_MODE=false
OTA_IP=""

# Print ASCII art banner
echo "
 _____       _              _____ _                          
/  ___|     | |            /  __ \ |                         
\ \`--.  ___ | | __ _ _ __  | /  \/ | ___  __ _ _ __   ___ _ __ 
 \`--. \/ _ \| |/ _\` | '__| | |   | |/ _ \/ _\` | '_ \ / _ \ '__|
/\__/ / (_) | | (_| | |    | \__/\ |  __/ (_| | | | |  __/ |   
\____/ \___/|_|\__,_|_|     \____/_|\___|\__,_|_| |_|\___|_|   
                                                             
"
echo "Solar Plate Auto-Cleaning System Deployment Tool"
echo "==============================================="

# Show usage information
function show_usage {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -p, --port PORT       Serial port for Arduino (default: $ARDUINO_PORT)"
    echo "  -b, --board BOARD     Board type (default: $BOARD_TYPE)"
    echo "  -s, --sketch PATH     Path to sketch (default: $SKETCH_PATH)"
    echo "  -e, --esp32           Deploy to ESP32 instead of Arduino"
    echo "  -o, --ota IP          Deploy to ESP32 via OTA (provide IP address)"
    echo "  -c, --config          Display current configuration"
    echo "  -h, --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --port /dev/ttyACM0                      # Deploy to Arduino on specified port"
    echo "  $0 --esp32 --port /dev/ttyUSB1              # Deploy to ESP32 on specified port"
    echo "  $0 --esp32 --ota 192.168.1.100              # Deploy to ESP32 via OTA"
    echo ""
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -p|--port)
            ARDUINO_PORT="$2"
            shift
            shift
            ;;
        -b|--board)
            BOARD_TYPE="$2"
            shift
            shift
            ;;
        -s|--sketch)
            SKETCH_PATH="$2"
            shift
            shift
            ;;
        -e|--esp32)
            ESP32_MODE=true
            BOARD_TYPE="esp32:esp32:esp32"
            SKETCH_PATH="iot/dashboard.ino"
            shift
            ;;
        -o|--ota)
            ESP32_MODE=true
            OTA_IP="$2"
            shift
            shift
            ;;
        -c|--config)
            echo "Current Configuration:"
            echo "  Port:       $ARDUINO_PORT"
            echo "  Board:      $BOARD_TYPE"
            echo "  Sketch:     $SKETCH_PATH"
            echo "  ESP32 Mode: $ESP32_MODE"
            echo "  OTA IP:     $OTA_IP"
            exit 0
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Check if Arduino CLI is installed
if ! command -v arduino-cli &> /dev/null; then
    echo "Arduino CLI not found. Installing..."
    curl -fsSL https://raw.githubusercontent.com/arduino/arduino-cli/master/install.sh | sh
    export PATH=$PATH:$HOME/bin
fi

# Check if board cores are installed
if $ESP32_MODE; then
    # Check if ESP32 core is installed
    if ! arduino-cli core list | grep -q "esp32"; then
        echo "Installing ESP32 core..."
        arduino-cli core update-index
        arduino-cli core install esp32:esp32
    fi
else
    # Check if Arduino AVR core is installed
    if ! arduino-cli core list | grep -q "arduino:avr"; then
        echo "Installing Arduino core..."
        arduino-cli core update-index
        arduino-cli core install arduino:avr
    fi
fi

# Install required libraries
echo "Installing required libraries..."
arduino-cli lib install ArduinoOTA PubSubClient ArduinoJson

# Compile and upload
if [ -n "$OTA_IP" ]; then
    # OTA upload for ESP32
    echo "Deploying to ESP32 via OTA at $OTA_IP..."
    
    # Get ESP32 port
    PORT=$(arduino-cli board list | grep ESP32 | awk '{print $1}')
    if [ -z "$PORT" ]; then
        echo "Error: ESP32 not found. Connect via USB first to get port."
        exit 1
    fi
    
    # Compile and upload via OTA
    echo "Compiling sketch..."
    arduino-cli compile --fqbn $BOARD_TYPE $SKETCH_PATH
    
    echo "Uploading via OTA..."
    # Use espota.py for OTA updates
    python $(arduino-cli config dump | grep packagesDir | cut -d '"' -f 4)/esp32/tools/espota.py -i $OTA_IP -p 3232 -f $SKETCH_PATH.ino.bin
    
    if [ $? -eq 0 ]; then
        echo "OTA update successful!"
    else
        echo "OTA update failed!"
        exit 1
    fi
else
    # Regular USB upload
    echo "Compiling and uploading to $BOARD_TYPE on $ARDUINO_PORT..."
    arduino-cli compile --upload --port $ARDUINO_PORT --fqbn $BOARD_TYPE $SKETCH_PATH
    
    if [ $? -eq 0 ]; then
        echo "Upload successful!"
    else
        echo "Upload failed. Check port and board type."
        exit 1
    fi
fi

echo "Deployment completed successfully."
echo "You can monitor the device using: arduino-cli monitor -p $ARDUINO_PORT"
