#!/bin/bash


# Check if Mosquitto is installed
if ! dpkg -l | grep -q mosquitto; then
    # Install Mosquitto MQTT server
    sudo apt-get update
    sudo apt-get install -y mosquitto mosquitto-clients
fi

# Enable websockets in Mosquitto configuration if not already enabled
if ! grep -q "protocol websockets" /etc/mosquitto/mosquitto.conf; then
    sudo bash -c 'cat <<EOF >> /etc/mosquitto/mosquitto.conf
listener 1883
listener 9001
protocol websockets
allow_anonymous true
EOF'
fi

# Enable and start the Mosquitto service
sudo systemctl enable mosquitto
sudo systemctl restart mosquitto

# Install Go if not already installed or if the version is not 1.24
if ! go version | grep -q "go1.24"; then
    wget https://golang.org/dl/go1.24.0.linux-armv6l.tar.gz
    sudo tar -C /usr/local -xzf go1.24.0.linux-armv6l.tar.gz
    echo "export PATH=$PATH:/usr/local/go/bin" >> ~/.bashrc
    source ~/.bashrc
    rm -f go1.24.0.linux-armv6l.tar.gz 
fi

# Build the MQTT GPIO server
sudo mkdir -p /opt/mqtt-gpio-server
sudo chown $USER:$USER /opt/mqtt-gpio-server
go build -o /opt/mqtt-gpio-server/mqtt-gpio-server main.go
sudo chown root:root /opt/mqtt-gpio-server/mqtt-gpio-server

# Move the config.json file to the destination directory
sudo cp config.json /opt/mqtt-gpio-server/
sudo chown root:root /opt/mqtt-gpio-server/config.json

# Create a systemd service file
sudo bash -c 'cat <<EOF > /etc/systemd/system/mqtt-gpio-server.service
[Unit]
Description=MQTT GPIO Server
After=network.target

[Service]
ExecStart=/opt/mqtt-gpio-server/mqtt-gpio-server
WorkingDirectory=/opt/mqtt-gpio-server
StandardOutput=inherit
StandardError=inherit
Restart=always
User=${SUDO_USER:-$USER}

[Install]
WantedBy=multi-user.target
EOF'

# Enable and start the MQTT GPIO server service
sudo systemctl daemon-reload
sudo systemctl enable mqtt-gpio-server
sudo systemctl start mqtt-gpio-server

echo "Installation complete. Please edit the /opt/mqtt-gpio-server/config.json file to specify the GPIO pins you want to control."
echo "sudo nano /opt/mqtt-gpio-server/config.json"
echo "Then restart the service for the changes to take effect."
echo "sudo systemctl restart mqtt-gpio-server"
 