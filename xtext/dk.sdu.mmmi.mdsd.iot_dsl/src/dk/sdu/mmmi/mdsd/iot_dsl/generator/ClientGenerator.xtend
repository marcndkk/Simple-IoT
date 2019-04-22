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

class ClientGenerator implements IGenerator{
	
//	var Map<Loop, String> loopNames
	
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
	def CharSequence generateClientMain(System system, Board board) '''
	from mqtt import MQTTClient
	import machine
	from machine import Pin
	from machine import Timer
	import time
	
	server = '«system.mqtt.host»'
	«FOR component : board.elements.filter(Component)»
	«component.name» = «component.type.name» («component.args»)
	«ENDFOR»
«««	p_out = Pin('P19', mode=Pin.OUT)
«««	p_out.value(1)
«««	
«««	adc = machine.ADC()             # create an ADC object
«««	apin = adc.channel(pin='P16')   # create an analog pin on P16
«««	val = apin()
	
	
	def sub_cb(topic, msg):
	   pass
	   # print(msg)
	
	
	client = MQTTClient(str(«board.name»), server, user="«system.mqtt.user»", password="«system.mqtt.pass»", port=«system.mqtt.port»)
	
	client.connect()
	
	«IF !system.logic.filter(Loop).empty»
	
	«FOR logic : system.logic.filter(Loop)»
	
	«FOR statement : logic.statements.filter(Variable)»
	
	def _«statement.name»_handler(alarm):
	   millivolts = apin.voltage()
	   degC = (millivolts - 500.0) / 10.0
	   degC_data = str(degC)
	   client.publish(topic="«board.name»/«getPropertyUses(logic)»", msg=degC_data)

	Timer.Alarm(handler=_«statement.name»_handler, s=«generateTimeUnit(logic.time, logic.timeunit)», periodic=True)	
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
	«ENDIF»
	
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