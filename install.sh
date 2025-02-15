
### `install.sh`

```sh
#!/bin/bash

# Update and upgrade the system
sudo apt-get update
sudo apt-get upgrade -y

# Install Mosquitto MQTT server
sudo apt-get install -y mosquitto mosquitto-clients

# Enable websockets in Mosquitto configuration
sudo bash -c 'cat <<EOF >> /etc/mosquitto/mosquitto.conf
listener 1883
listener 9001
protocol websockets
allow_anonymous true
EOF'

# Enable and start the Mosquitto service
sudo systemctl enable mosquitto
sudo systemctl restart mosquitto

# Install Go
wget https://golang.org/dl/go1.20.1.linux-armv6l.tar.gz
sudo tar -C /usr/local -xzf go1.20.1.linux-armv6l.tar.gz
echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.profile
source ~/.profile

# Build the MQTT GPIO server
go build -o mqtt-gpio-server main.go

# Create a systemd service file
sudo bash -c 'cat <<EOF > /etc/systemd/system/mqtt-gpio-server.service
[Unit]
Description=MQTT GPIO Server
After=network.target

[Service]
ExecStart=/home/pi/mqtt-gpio-server/mqtt-gpio-server
WorkingDirectory=/home/pi/mqtt-gpio-server
StandardOutput=inherit
StandardError=inherit
Restart=always
User=pi

[Install]
WantedBy=multi-user.target
EOF'

# Enable and start the MQTT GPIO server service
sudo systemctl daemon-reload
sudo systemctl enable mqtt-gpio-server
sudo systemctl start mqtt-gpio-server

echo "Installation complete. Please edit the config.json file to specify the GPIO pins you want to control."