package dk.sdu.mmmi.mdsd.iot_dsl.generator

import org.eclipse.xtext.generator.IGenerator
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import java.util.Map
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Loop
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.System
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Board
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Component
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.ComponentType
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Statement
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Expose
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Mqtt
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.SensorType
import java.util.Set
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Property
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.WiFi
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Variable
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Assignment
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.PropertyUse
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.ActuatorType

class ClientGenerator implements IGenerator{
	
	var Set<PropertyUse> property_uses
	
	override doGenerate(Resource resource, IFileSystemAccess fsa) {
		val system = resource.allContents.filter(System).next
//		loopNames = newLinkedHashMap
//		system.logic.filter(Loop).forEach[loop, i| loopNames.put(loop, "loop"+i)]
		for(board : system.boards){
			fsa.generateFile('client_'+board.name+'/boot.py', system.generateClientBoot(board))
			fsa.generateFile('client_'+board.name+'/main.py', system.generateClientMain(board))
		}

	}
	
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
	from machine import Pin
	from machine import Timer
	import time
	
	
	def sub_cb(topic, msg):
	«FOR component : board.elements.filter(Component)»
	«««	«component.name» = «component.type.name» («component.args»)
		«IF component.type instanceof ActuatorType»
			«FOR property : component.type.properties»
			if topic == "«board.name»/«component.name»/«property.name»":
				«component.name».«property.name» = msg
			«««			«generatePropertySubscription(board, component, property)»
			«ENDFOR»
		«ENDIF»
«««		pycom.rgbled(intesity)
	«ENDFOR»
	
	«FOR component : board.elements.filter(Component)»
		«IF component.type instanceof ActuatorType»
			«FOR property : component.type.properties»
	client.subscribe("«board.name»/«component.name»/«property.name»")
			«ENDFOR»
		«ENDIF»
«««		pycom.rgbled(intesity)
	«ENDFOR»

		
		
	client = MQTTClient(str(«board.name»), server, user="«system.mqtt.user»", password="«system.mqtt.pass»", port=«system.mqtt.port»)
	
	client.set_callback(sub_cb)
	client.connect()
	
«««	server = '«system.mqtt.host»'
	
«««	p_out = Pin('P19', mode=Pin.OUT)
«««	p_out.value(1)
«««	
«««	adc = machine.ADC()             # create an ADC object
«««	apin = adc.channel(pin='P16')   # create an analog pin on P16
«««	val = apin()
		
	«FOR logic : system.logic.filter(Loop)»
	
«««	«FOR statement : logic.statements.filter(Variable)»
	«FOR component : board.elements.filter(Component)»
		«IF component.type instanceof SensorType»
			«FOR property : component.type.properties»
	def _«component.name»_handler(alarm):
	   millivolts = apin.voltage()
	   degC = (millivolts - 500.0) / 10.0
	   degC_data = str(degC)
	   client.publish(topic="«board.name»/«component.name»/«property.name»", msg=«component.name».«property.name»)

	Timer.Alarm(handler=_«component.name»_handler, s=«generateTimeUnit(component.rate.time, component.rate.timeUnit)», periodic=True)	
			«ENDFOR»
		«ENDIF»
	«ENDFOR»

«««		   millivolts = apin.voltage()
«««		   degC = (millivolts - 500.0) / 10.0
«««		   client.publish(topic="test/feeds/count", msg=str(count))
«««		
«««		   degC_data = str(degC)
«««		   time.sleep(1)
«««		
«««		
«««		   client.publish(topic="test/feeds/temp", msg=degC_data)
«««		   count += 1
   «ENDFOR»
   
	while True:
		machine.idle()	
	'''
	
	def CharSequence getPropertyUses(Loop loop)'''
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