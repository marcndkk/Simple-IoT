package dk.sdu.mmmi.mdsd.iot_dsl

import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Program
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Board
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.ComponentType
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Mqtt
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.VariableDeclaration
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Loop
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.External
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Expose
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Server
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.WiFi
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Component
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.SensorType

class IoTDSLModelUtil {
	def getBoards(Program program) {
		program.elements.filter(Board)
	}
	
	def getComponentTypes(Program program) {
		program.elements.filter(ComponentType)
	}
	
	def getMqtts(Program program) {
		program.elements.filter(Mqtt)
	}
	
	def getStateVariables(Program program) {
		program.elements.filter(VariableDeclaration)
	}
	
	def getLoops(Program program) {
		program.elements.filter(Loop)
	}
	
	def getExternals(Program program) {
		program.elements.filter(External)
	}
	
	def getExposes(Program program) {
		program.elements.filter(Expose)
	}
	
	def getServers(Program program) {
		program.elements.filter(Server)
	}
	
	def getWifis(Board board) {
		board.elements.filter(WiFi)
	}
	
	def getComponents(Board board) {
		board.elements.filter(Component)
	}
	
	def numberOfSensors(Program p) {
		val sensors = newArrayList
		p.boards.forEach[
			it.components.forEach[if (it.type instanceof SensorType) sensors.add(it)]
		]
		return sensors.size
	}
}