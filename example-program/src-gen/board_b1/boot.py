from network import WLAN
import machine
import pycom
import time

pycom.heartbeat(False)
wlan = WLAN(mode=WLAN.STA)

access_points = wlan.scan()
for ap in access_points:
	if ap.ssid == '<ssid>':
		wlan.connect(ap.ssid, auth=(ap.sec, '<pass>'))
		while not wlan.isconnected():
			machine.idle() # save power while waiting

		# 5 second blue flash to show successful connection
		pycom.rgbled(0x0000FF)
		time.sleep(5)
		pycom.rgbled(0x000000)

		machine.main("main.py")
		break
