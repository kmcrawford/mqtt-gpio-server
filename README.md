# MQTT GPIO Server

This project sets up an MQTT server to control GPIO pins on a Raspberry Pi. It reads the GPIO pin configuration from an external JSON file and listens for MQTT messages to control the GPIO pins.

## Prerequisites

- Raspberry Pi with Raspbian OS
- Internet connection

## Installation

1. **Clone the repository:**

    ```sh
    git clone https://github.com/yourusername/mqtt-gpio-server.git
    cd mqtt-gpio-server
    ```

2. **Run the installation script:**

    ```sh
    chmod +x install.sh
    ./install.sh
    ```

3. **Edit the [config.json](http://_vscodecontentref_/0) file to specify the GPIO pins you want to control:**

    ```json
    {
        "pins": ["GPIO27", "GPIO6"]
    }
    ```

4. **Reboot the Raspberry Pi to start the service:**

    ```sh
    sudo reboot
    ```

## Usage

- The program will automatically start on boot and listen for MQTT messages on the [gpio/control](http://_vscodecontentref_/1) topic.
- You can send JSON messages to control the GPIO pins. For example:

    ```json
    {
        "pin": "GPIO27",
        "state": "High"
    }
    ```

## Uninstallation

To remove the service, run:

```sh
sudo systemctl stop mqtt-gpio-server
sudo systemctl disable mqtt-gpio-server
sudo rm /etc/systemd/system/mqtt-gpio-server.service
sudo systemctl daemon-reload