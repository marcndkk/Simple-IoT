package main

import (
	"fmt"
	"strconv"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
)

type server struct {
	b1     *board_b1
	b2     *board_b2
	client mqtt.Client
}

type board_b1 struct {
	lightsensor *pycom_lightsensor
	led         *led
}

type board_b2 struct {
	thermometer *thermometer
	lightsensor *pycom_lightsensor
	led         *led
}

type led struct {
	intensity float32
	status    string
}

type thermometer struct {
	temp float32
}

type pycom_lightsensor struct {
	lightlevel int
}

func main() {
	opts := mqtt.NewClientOptions()
	opts.AddBroker("mndkk.dk:1883")
	opts.SetClientID("server")
	opts.SetUsername("iot")
	opts.SetPassword("3Y5s6JrX")

	c := mqtt.NewClient(opts)

	if token := c.Connect(); token.Wait() && token.Error() != nil {
		panic(token.Error())
	}

	b1 := board_b1{}
	b1.led = &led{}
	b1.lightsensor = &pycom_lightsensor{}

	b2 := board_b2{&thermometer{}, &pycom_lightsensor{}, &led{}}

	server := server{&b1, &b2, c}

	c.Subscribe("b1/lightsensor/lightlevel", 0, func(client mqtt.Client, msg mqtt.Message) {
		value, err := strconv.Atoi(string(msg.Payload()))
		if err != nil {
			fmt.Println(fmt.Errorf("Error on topic %v: %v", msg.Topic(), err))
		}
		server.b1.lightsensor.lightlevel = value
	})

	defer c.Disconnect(250)
	doshit(c, &server)

}

func doshit(c mqtt.Client, s *server) {
	for _ = range time.Tick(2 * time.Second) {
		fmt.Println("sending", s.b1.lightsensor.lightlevel)
		token := c.Publish("test", 0, false, fmt.Sprint("light:", s.b1.lightsensor.lightlevel))
		token.Wait()
	}
}
