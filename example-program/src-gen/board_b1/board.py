from mqtt import MQTTClient
import machine
from machine import Timer
import time

class Board:
	def __init__(self, components):
		self.led = components["pycom_led"]()
		self.validate_components()
		self.mqtt = MQTTClient("b1", "<host>", user="<user>", password="<pass>", port=1883)

	def validate_components(self):
		set_intensity = getattr(self.led, "set_intensity", None)
		if set_intensity is None or not callable(set_intensity):
			raise Exception("led missing method set_intensity")
		
		set_status = getattr(self.led, "set_status", None)
		if set_status is None or not callable(set_status):
			raise Exception("led missing method set_status")

	def process_message(self, topic, msg):
		topic_str = topic.decode("utf-8")
		msg_str = msg.decode("utf-8")
		if topic_str == "b1/led/intensity":
			self.led.set_intensity(float(msg_str))
		if topic_str == "b1/led/status":
			self.led.set_status(msg_str)


	def run(self):
		self.mqtt.set_callback(self.process_message)
		self.mqtt.connect()

		self.mqtt.subscribe("b1/led/intensity")
		self.mqtt.subscribe("b1/led/status")

		alarms = []

		try:
			while True:
				self.mqtt.wait_msg()
				machine.idle()
		finally:
			for alarm in alarms:
				alarm.cancel()
			self.mqtt.disconnect()