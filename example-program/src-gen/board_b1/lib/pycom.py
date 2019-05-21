import pycom
from lib.LTR329ALS01 import LTR329ALS01
import machine
from machine import Pin
class pycom_led:
    def __init__(self):
        self.status = "ON"
        self.value = 0x000000
    def set_status(self, status):
        if status in ("ON", "OFF"):
            self.status = status
        self._update()
    def set_intensity(self, intensity):
        if intensity < 0:
            intensity = 0
        if intensity > 1:
            intensity = 1
        v = int(intensity * 255)
        self.value = int('0x%02x%02x%02x' % (v, v, v))
        self._update()
    def _update(self):
        if self.status == "ON":
            pycom.rgbled(self.value)
        else:
            pycom.rgbled(0x000000)
class pycom_lightsensor:
    def __init__(self):
        self.lt = LTR329ALS01()
    def get_lightlevel(self):
        return self.lt.light()[0]
class thermometer:
    def __init__(self, pin_in, pin_out):
        machine.Pin('P{}'.format(pin_out), mode=Pin.OUT).value(1)
        adc = machine.ADC()
        self.apin = adc.channel(pin='P{}'.format(pin_in))
    def get_temp(self):
        voltage = self.apin.voltage()
        degC = (voltage - 500.0) / 10.0
        return degC
def get_components():
    return {
        'pycom_led': pycom_led,
        'pycom_lightsensor': pycom_lightsensor,
        'thermometer': thermometer
    }
