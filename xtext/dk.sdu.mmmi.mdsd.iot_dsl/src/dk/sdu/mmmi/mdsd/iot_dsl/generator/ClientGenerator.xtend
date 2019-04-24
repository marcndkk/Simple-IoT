package dk.sdu.mmmi.mdsd.iot_dsl.generator

import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.ActuatorType
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Board
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Component
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Loop
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Property
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.SensorType
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Statement
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.System
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.WiFi
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator

class ClientGenerator implements IGenerator{
	
	
	override doGenerate(Resource resource, IFileSystemAccess fsa) {
		val system = resource.allContents.filter(System).next
		for(board : system.boards){
			fsa.generateFile('client_'+board.name+'/boot.py', system.generateClientBoot(board))
			fsa.generateFile('client_'+board.name+'/core.py', system.generateClientMain(board))
			fsa.generateFile('client_'+board.name+'/components.py', system.generateClientComponents(board))
		}

	}
	
	def CharSequence generateClientComponents(System system, Board board)'''
	from abc import ABC, abstractmethod
	«FOR component : board.elements.filter(Component)»
	class «component.type.name»(ABC):
	
		def «component.type.external.name»(self):
			pass
		
		«FOR property : component.type.properties»
		def «property.name»(self):
			pass
			
		«ENDFOR»
	«ENDFOR»
	'''
	
	def CharSequence generateClientBoot(System system, Board board) '''
	from network import WLAN
	import machine
	import pycom
	import time
	wlan = WLAN(mode=WLAN.STA)
	
	nets = wlan.scan()
	for net in nets:
	«FOR wifi : board.elements.filter(WiFi)»
	    if net.ssid == '«wifi.ssid»':
	        print('Network found!')
	        wlan.connect(net.ssid, auth=(net.sec, '«wifi.pass»'), timeout=5000)
    «ENDFOR»
	        while not wlan.isconnected():
	            machine.idle() # save power while waiting
	        print('WLAN connection succeeded!')
	        pycom.heartbeat(False)
	        pycom.rgbled(0x0000FF)
	        time.sleep(5)
	        pycom.rgbled(0x000000)
	        machine.main("main.py")
	        break
	
	'''
	
	def CharSequence generatePropertySubscription(Board board, Component component, Property property) '''
			client.subscribe("«board.name»/«component.name»/«property.name»)
		'''
	
	def CharSequence generateClientMain(System system, Board board) '''
	from mqtt import MQTTClient
	import machine
	from machine import Timer
	import time
	
	class Core:
		def __init__(self, «FOR comp : board.elements.filter(Component) SEPARATOR ","»«comp.name»«ENDFOR»):
			«FOR component : board.elements.filter(Component)»
			self.«component.name» = «component.name»
			«ENDFOR»
			self.client = MQTTClient("«board.name»", "«system.mqtt.host»", user="«system.mqtt.user»", password="«system.mqtt.pass»", port=«system.mqtt.port»)
			
		def sub_cb(self, topic, msg):
			topic_str = topic.decode("utf-8")
			msg_str = msg.decode("utf-8")
			«FOR component : board.elements.filter(Component)»
			«IF component.type instanceof ActuatorType»
			«FOR property : component.type.properties»
			if topic_str == "«board.name»/«component.name»/«property.name»":
				self.«component.name».«property.name»(msg_str)
			«ENDFOR»
			«ENDIF»
			«ENDFOR»
			
		def run(self):
			self.client.set_callback(self.sub_cb)
			self.client.connect()
			«FOR component : board.elements.filter(Component)»
			«IF component.type instanceof ActuatorType»
			«FOR property : component.type.properties»
			self.client.subscribe("«board.name»/«component.name»/«property.name»")
			«ENDFOR»
			«ENDIF»
			«ENDFOR»
			«FOR logic : system.logic.filter(Loop)»
			
			«FOR component : board.elements.filter(Component)»
			«IF component.type instanceof SensorType»
			«FOR property : component.type.properties»
			def _«component.name»_handler(self, alarm):
			   self.client.publish(topic="«board.name»/«component.name»/«property.name»", msg=self.«component.name».«property.name»())
			
			alarm = Timer.Alarm(handler=_«component.name»_handler, s=«generateTimeUnit(component.rate.time, component.rate.timeUnit)», periodic=True)	
			«ENDFOR»
			«ENDIF»
			«ENDFOR»
		   «ENDFOR»
			try:
				while True:
					self.client.wait_msg()
					machine.idle()
			finally:
				alarm.cancel()
				self.client.disconnect()	
		'''
	
	def CharSequence generateStatement(Statement statement) '''
			// Insert statement here
		'''
	
	def CharSequence generateTimeUnit(int seconds, String timeUnit) {
			switch timeUnit {
				case "hours": ""+seconds*3600+""
				case "minutes": ""+seconds*60+""
				case "seconds": ""+seconds+""
			}
		}
}