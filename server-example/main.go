package main

import (
	"fmt"
	"net/http"
	"strconv"
	"time"

	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/gorilla/mux"
)

type server struct {
	client mqtt.Client
	b1     *board_b1
	b2     *board_b2
}

func (s *server) send_message(topic string, payload interface{}) {
	token := s.client.Publish(topic, 0, false, payload)
	token.Wait()
}

func (s *server) loop0() {
	for _ = range time.Tick(1 * time.Second) {
		fmt.Println("light:", s.b1.lightsensor.lightlevel)
	}
}

func (s *server) turn_on(w http.ResponseWriter, r *http.Request) {
	// Insert statement here
}
func (s *server) turn_off(w http.ResponseWriter, r *http.Request) {
	// Insert statement here
}

type board_b1 struct {
	lightsensor *pycom_lightsensor
	led         *led
}
type board_b2 struct {
	lightsensor *pycom_lightsensor
	led         *led
}

type pycom_lightsensor struct {
	lightlevel int64
}
type led struct {
	intensity float64
	status    string
}

func main() {
	opts := mqtt.NewClientOptions()
	opts.AddBroker("mndkk.dk:1883")
	opts.SetClientID("server")
	opts.SetUsername("iot")
	opts.SetPassword("3Y5s6JrX")

	mqtt_client := mqtt.NewClient(opts)
	if token := mqtt_client.Connect(); token.Wait() && token.Error() != nil {
		panic(token.Error())
	}

	server := server{
		mqtt_client,
		&board_b1{&pycom_lightsensor{}, &led{}},
		&board_b2{&pycom_lightsensor{}, &led{}},
	}

	mqtt_client.Subscribe("b1/lightsensor/lightlevel", 0, func(client mqtt.Client, msg mqtt.Message) {
		value, err := strconv.ParseInt(string(msg.Payload()), 10, 64)
		if err != nil {
			fmt.Println(fmt.Errorf("Error on topic %v: %v", msg.Topic(), err))
		}
		server.b1.lightsensor.lightlevel = value
	})
	mqtt_client.Subscribe("b2/lightsensor/lightlevel", 0, func(client mqtt.Client, msg mqtt.Message) {
		value, err := strconv.ParseInt(string(msg.Payload()), 10, 64)
		if err != nil {
			fmt.Println(fmt.Errorf("Error on topic %v: %v", msg.Topic(), err))
		}
		server.b2.lightsensor.lightlevel = value
	})

	r := mux.NewRouter()
	r.HandleFunc("/turn_on", server.turn_on)
	r.HandleFunc("/turn_off", server.turn_off)

	go server.loop0()

	http.ListenAndServe(":50001", r)
}
