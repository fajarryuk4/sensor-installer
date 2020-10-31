#!/bin/bash

if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi

command -v docker >/dev/null 2>&1 || { echo >&2 "This service requires Docker, but your computer doesn't have it. Install Docker then try again. Aborting."; exit 1; }

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"


read -p "Protected subnet : " PROTECTED_SUBNET
read -p "External subnet [default is any] : " EXTERNAL_SUBNET
EXTERNAL_SUBNET=${EXTERNAL_SUBNET:-any}
echo "Available Network Interface : `ls -C /sys/class/net`"
read -p "Network Interface : " NETINT
read -p "Device ID : " DEVICE_ID
read -p "Company : " COMPANY

read -p "Mosquitto (MQTT Broker) IP : " ALERT_MQTT_SERVER
read -p "Mosquitto (MQTT Broker) Port [default is 1883] : " ALERT_MQTT_PORT
ALERT_MQTT_PORT=${ALERT_MQTT_PORT:-1883}
read -p "Netflowmeter MQTT topic [default is netflowmqtt] : " MQTT_TOPIC
ALERT_MQTT_TOPIC=${MQTT_TOPIC:-netflowmqtt}
read -p "Snort MQTT topic [default is snoqttv5] : " ALERT_MQTT_TOPIC
ALERT_MQTT_TOPIC=${ALERT_MQTT_TOPIC:-snoqttv5}
echo -e "What kind rules do you want to use?\n\t1. Community\n\t2. Registered (required oinkcode)\n"
read -p "Your choice : " RULE_CHOICE

if [[ ! $RULE_CHOICE -eq 1 && ! $RULE_CHOICE -eq 2 ]]; then
  echo -e "Choose a valid choice.\nExited."
  exit 1
fi

if [[ $RULE_CHOICE -eq 2 ]]; then
  read -p "Input your oinkcode here : " OINKCODE
fi

echo
echo "Preparing ..."
/usr/bin/docker pull ryuk4/netflowmqtt-sensor:latest
/usr/bin/docker pull mataelang/snorqttalpine-sensor:latest
mkdir -p /etc/mataelang-sensor

echo
echo "Configuring ..."
cat > /etc/mataelang-sensor/netflowmeter.env <<EOL
MQTT_TOPIC=${MQTT_TOPIC}
MQTT_SERVER=${ALERT_MQTT_SERVER}
MQTT_PORT=${ALERT_MQTT_PORT}
NETINT=${NETINT}
EOL

cat > /etc/mataelang-sensor/snort.env <<EOL
PROTECTED_SUBNET=${PROTECTED_SUBNET}
EXTERNAL_SUBNET=${EXTERNAL_SUBNET}
ALERT_MQTT_TOPIC=${ALERT_MQTT_TOPIC}
ALERT_MQTT_SERVER=${ALERT_MQTT_SERVER}
ALERT_MQTT_PORT=${ALERT_MQTT_PORT}
DEVICE_ID=${DEVICE_ID}
NETINT=${NETINT}
COMPANY=${COMPANY}
EOL

cp ${SCRIPTPATH}/service/mataelang-snort.service /etc/systemd/system/
cp ${SCRIPTPATH}/service/mataelang-netflowmeter.service /etc/systemd/system/

docker tag ryuk4/netflowmqtt-sensor:latest mataelang-netflowmeter

if [[ $RULE_CHOICE -eq 1 ]]; then
  echo "Using Snort Community Rules.."
  docker tag mataelang/snorqttalpine-sensor:latest mataelang-snort
fi

if [[ $RULE_CHOICE -eq 2 ]]; then
  echo "Using Snort Regular Rules with Oinkcode.."
  /usr/bin/docker build --no-cache --build-arg OINKCODE=${OINKCODE} -f ${SCRIPTPATH}/dockerfiles/snort.dockerfile -t mataelang-snort ${SCRIPTPATH}/
fi

echo
systemctl daemon-reload
echo "Registering Mata Elang sensor service..."
systemctl enable mataelang-snort.service
systemctl enable mataelang-netflowmeter.service
echo "Creating container..."
/usr/bin/docker create --name mataelang-netflowmeter --network host -v /etc/localtime:/etc/localtime -v /etc/timezone:/etc/timezone --env-file /etc/mataelang-sensor/netflowmeter.env mataelang-netflowmeter
/usr/bin/docker create --name mataelang-snort --network host -v /etc/localtime:/etc/localtime -v /etc/timezone:/etc/timezone --env-file /etc/mataelang-sensor/snort.env mataelang-snort
echo
echo "Starting sensor..."
systemctl start mataelang-snort.service
systemctl start mataelang-netflowmeter.service

echo "Setup completed."
echo -e "You can start/stop/restart the service now with the following command : 
\tsudo systemctl start/stop/restart mataelang-snort 
\tsudo systemctl start/stop/restart mataelang-netflowmeter"