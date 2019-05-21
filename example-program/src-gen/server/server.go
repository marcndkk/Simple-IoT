package main

import (
	"fmt"
	"net/http"
	"time"
	
	mqtt "github.com/eclipse/paho.mqtt.golang"
	"github.com/gorilla/mux"
)

type Externals interface {
}

func NewServer(externals Externals) *server {
	opts := mqtt.NewClientOptions()
	opts.AddBroker("<host>:1883")
	opts.SetClientID("server")
	opts.SetUsername("<user>")
	opts.SetPassword("<pass>")
	
	mqtt_client := mqtt.NewClient(opts)
	if token := mqtt_client.Connect(); token.Wait() && token.Error() != nil {
		panic(token.Error())
	}
					
	return &server{
		externals,
		mqtt_client,
		&state{},
		&board_b1{&pycom_led{},},
	}
}

type server struct {
	externals Externals
	mqtt mqtt.Client
	state *state
	b1 *board_b1
}

type state struct {
	led_on bool
}

func (s *server) send_message(topic string, payload interface{}) {
	token := s.mqtt.Publish(topic, 0, false, payload)
	token.Wait()
}

func (s *server) loop0() {
	for _ = range time.Tick(5 * time.Second) {
		s.b1.led.intensity = 0.7
		s.send_message("b1/led/intensity", fmt.Sprintf("%v", 0.7))
		if s.state.led_on {
			s.b1.led.status = "OFF"
			s.send_message("b1/led/status", fmt.Sprintf("%v", "OFF"))
			s.state.led_on = false
		} else {
			s.b1.led.status = "ON"
			s.send_message("b1/led/status", fmt.Sprintf("%v", "ON"))
			s.state.led_on = true
		}
	}
}


type board_b1 struct {
	led *pycom_led
}

type pycom_led struct {
	intensity float64
	status string
}

func (s *server) run() {
	
	r := mux.NewRouter()
	
	go s.loop0()
	
	http.ListenAndServe(":8080", r)
}
