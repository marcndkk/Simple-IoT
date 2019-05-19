package dk.sdu.mmmi.mdsd.iot_dsl.generator

import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.ActuatorType
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Board
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Component
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.SensorType
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Program
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.WiFi
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator
import com.google.inject.Inject
import dk.sdu.mmmi.mdsd.iot_dsl.IoTDSLModelUtil
import java.io.File
import java.io.FileReader
import static extension com.google.common.io.CharStreams.*
import java.io.InputStreamReader
import com.google.common.reflect.Reflection

class ClientGenerator implements IGenerator{
	
	@Inject extension IoTDSLModelUtil
	
	override doGenerate(Resource resource, IFileSystemAccess fsa) {
		val program = resource.allContents.filter(Program).next
		for(board : program.boards){
			var dir = 'board_' + board.name + '/'
			fsa.generateFile(dir + 'boot.py', program.generateBootFile(board))
			fsa.generateFile(dir + 'board.py', program.generateBoardFile(board))
			copyExternalFile(fsa, "/pycom/lib/pycom.py", dir + "lib/pycom.py")
			copyExternalFile(fsa, "/pycom/lib/LTR329ALS01.py", dir + "lib/LTR329ALS01.py")
			copyExternalFile(fsa, "/pycom/lib/mqtt.py", dir + "lib/mqtt.py")
	}
	}
	
	def copyExternalFile(IFileSystemAccess fsa, String filename, String target) {
		var file = getClass.getResourceAsStream(filename)
		fsa.generateFile(target, '''
		«FOR line : new InputStreamReader(file).readLines»
		«line»
		«ENDFOR»
		''')
	}
	
	def CharSequence generateBootFile(Program program, Board board) {
		var wifi = board.elements.filter(WiFi).get(0)
		'''
		from network import WLAN
		import machine
		import pycom
		import time

		pycom.heartbeat(False)
		wlan = WLAN(mode=WLAN.STA)

		access_points = wlan.scan()
		for ap in access_points:
			if ap.ssid == '«wifi.ssid»':
				wlan.connect(ap.ssid, auth=(ap.sec, '«wifi.pass»'))
				while not wlan.isconnected():
					machine.idle() # save power while waiting

				# 5 second blue flash to show successful connection
				pycom.rgbled(0x0000FF)
				time.sleep(5)
				pycom.rgbled(0x000000)

				machine.main("main.py")
				break
		'''
	}
	
	def CharSequence generateBoardFile(Program program, Board board) '''
	from mqtt import MQTTClient
	import machine
	from machine import Timer
	import time
	
	class Board:
		def __init__(self, components):
			«FOR component : board.components»
			self.«component.name» = components["«component.type.name»"](«FOR arg : component.args SEPARATOR ", "»«arg»«ENDFOR»)
			«ENDFOR»
			self.validate_components()
			self.mqtt = MQTTClient("«board.name»", "«program.mqtt.host»", user="«program.mqtt.user»", password="«program.mqtt.pass»", port=«program.mqtt.port»)

		«generateComponentValidation(board)»

		«generateMessageProcessing(board)»

		«FOR sensor : board.sensors SEPARATOR "\n"»
		«FOR property : sensor.type.properties SEPARATOR "\n"»
		«generatePropertyPublishing(board.name, sensor.name, property.name)»
		«ENDFOR»
		«ENDFOR»

		def run(self):
			self.mqtt.set_callback(self.process_message)
			self.mqtt.connect()

			«FOR actuator : board.actuators»
			«FOR property : actuator.type.properties»
			self.mqtt.subscribe("«board.name»/«actuator.name»/«property.name»")
			«ENDFOR»
			«ENDFOR»

			alarms = []
			«FOR sensor : board.sensors»
			«FOR property : sensor.type.properties»
			alarms.append(Timer.Alarm(handler=self.publish_«sensor.name»_«property.name», s=«generateTimeUnit(sensor.rate.time, sensor.rate.timeUnit)», periodic=True))
			«ENDFOR»
			«ENDFOR»

			try:
				while True:
					self.mqtt.wait_msg()
					machine.idle()
			finally:
				for alarm in alarms:
					alarm.cancel()
				self.mqtt.disconnect()'''
	
	def CharSequence generateComponentValidation(Board board) '''
		def validate_components(self):
			«FOR component : board.components SEPARATOR "\n"»
			«FOR property : component.type.properties SEPARATOR "\n"»
			«IF component.type instanceof SensorType»
			«generateComponentMethodCheck(component.name, "get_" + property.name)»
			«ELSE»
			«generateComponentMethodCheck(component.name, "set_" + property.name)»
			«ENDIF»
			«ENDFOR»
			«ENDFOR»
	'''

	def CharSequence generateComponentMethodCheck(String componentName, String methodName) '''
	«methodName» = getattr(self.«componentName», "«methodName»", None)
	if «methodName» is None or not callable(«methodName»):
		raise Exception("«componentName» missing method «methodName»")
	'''

	def CharSequence generateMessageProcessing(Board board) '''
	def process_message(self, topic, msg):
		topic_str = topic.decode("utf-8")
		msg_str = msg.decode("utf-8")
		«FOR actuator : board.actuators»
		«FOR property : actuator.type.properties»
		if topic_str == "«board.name»/«actuator.name»/«property.name»":
			self.«actuator.name».set_«property.name»(«property.type.generateMsgConversion»)
		«ENDFOR»
		«ENDFOR»
	'''
	
	def CharSequence generateMsgConversion(String type) {
		switch type {
			case "string": "msg_str"
			case "integer": "int(msg_str)"
			case "float": "float(msg_str)"
			case "boolean": "bool(msg_str)"
		}
	}

	def CharSequence generatePropertyPublishing(String boardName, String componentName, String propertyName) '''
	def publish_«componentName»_«propertyName»(self, alarm):
		self.mqtt.publish(topic="«boardName»/«componentName»/«propertyName»", msg=str(self.«componentName».get_«propertyName»()))
	'''

	def CharSequence generateTimeUnit(int time, String timeUnit) {
		switch timeUnit {
			case "hours": '''«time*3600»'''
			case "minutes": '''«time*60»'''
			case "seconds": '''«time»'''
		}
	}

	def Iterable<Component> getSensors(Board board) {
		val sensors = newArrayList
		board.components.forEach[c| if(c.type instanceof SensorType) sensors.add(c)]
		sensors
	}

	def Iterable<Component> getActuators(Board board) {
		val actuators = newArrayList
		board.components.forEach[c| if(c.type instanceof ActuatorType) actuators.add(c)]
		actuators
	}

	def Iterable<Component> getComponents(Board board) {
		board.elements.filter(Component)
	}
}