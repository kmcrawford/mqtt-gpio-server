package main

import (
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"periph.io/x/conn/v3/gpio"
	"periph.io/x/conn/v3/gpio/gpioreg"
	"periph.io/x/host/v3"
)

const (
	MQTT_BROKER   = "tcp://localhost:1883" // Use the IP of the Pi if external clients connect
	CONTROL_TOPIC = "gpio/control"
	STATUS_TOPIC  = "gpio/status"
)

var config Config

// Command struct for JSON messages
type Command struct {
	Pin   string `json:"pin"`
	State string `json:"state"`
}

// Config struct for JSON configuration file
type Config struct {
	Pins []string `json:"pins"`
}

func messageHandler(client mqtt.Client, msg mqtt.Message) {
	var cmd Command
	err := json.Unmarshal(msg.Payload(), &cmd)
	if err != nil {
		log.Println("Invalid message format:", err)
		return
	}

	if cmd.Pin == "ALL" {
		retrieveGPIOStates(client)
	}

	pin := gpioreg.ByName(cmd.Pin)
	if pin == nil {
		log.Printf("Invalid GPIO pin: %s\n", cmd.Pin)
		return
	}
	log.Printf("Request for GPIO pin: %s to set state %s\n", cmd.Pin, cmd.State)

	// Change GPIO state
	state := gpio.Low
	if cmd.State == "High" {
		state = gpio.High
	}
	pin.Out(state)

	client.Publish(STATUS_TOPIC, 0, false, fmt.Sprintf(`{"%s": "%s"}`, cmd.Pin, cmd.State))
}

func retrieveGPIOStates(client mqtt.Client) {
	publishGPIOStates(client, config.Pins, true)
}

// Function to read GPIO states and publish periodically
func publishGPIOStates(client mqtt.Client, pins []string, alwaysPublish bool) {
	statesPrev := make(map[string]string)
	for {
		states := make(map[string]string)
		for _, pinName := range pins {
			p := gpioreg.ByName(pinName)
			if p == nil {
				states[pinName] = "Invalid"
				continue
			}
			// Set it as input, with an internal pull down resistor:
			if err := p.In(gpio.PullDown, gpio.BothEdges); err != nil {
				log.Fatal(err)
			}
			p.WaitForEdge(-1)
			val := p.Read().String()
			states[pinName] = val
		}
		time.Sleep(100 * time.Millisecond) // Adjust update interval as needed

		//if states not equal to statesPrev continue
		if !compareMaps(states, statesPrev) || alwaysPublish {
			data, _ := json.Marshal(states)
			client.Publish(STATUS_TOPIC, 0, false, data)
			statesPrev = states
		}

		if alwaysPublish {
			break
		}
	}
}

func main() {
	// Initialize GPIO library
	if _, err := host.Init(); err != nil {
		log.Fatal("Failed to initialize GPIO:", err)
	}

	// Read configuration file
	configFile, err := os.Open("config.json")
	if err != nil {
		log.Fatal("Failed to open config file:", err)
	}
	defer configFile.Close()

	byteValue, _ := io.ReadAll(configFile)
	json.Unmarshal(byteValue, &config)

	// MQTT Client Setup
	opts := mqtt.NewClientOptions().AddBroker(MQTT_BROKER)
	client := mqtt.NewClient(opts)
	if token := client.Connect(); token.Wait() && token.Error() != nil {
		log.Fatal(token.Error())
	}

	// Subscribe to control topic
	client.Subscribe(CONTROL_TOPIC, 0, messageHandler)
	log.Println("Subscribed to", CONTROL_TOPIC)
	go publishGPIOStates(client, config.Pins, false)

	select {} // Keep running
}

func compareMaps(a, b map[string]string) bool {
	// If the lengths are different, they are not equal
	if len(a) != len(b) {
		return false
	}

	// Check each key-value pair
	for key, valA := range a {
		if valB, exists := b[key]; !exists || valA != valB {
			return false
		}
	}

	return true
}
