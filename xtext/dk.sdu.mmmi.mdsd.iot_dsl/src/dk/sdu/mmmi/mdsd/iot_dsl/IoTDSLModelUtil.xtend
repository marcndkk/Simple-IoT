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

class IoTDSLModelUtil {
	def getBoards(Program program) {
		program.elements.filter(Board)
	}
	
	def getComponentTypes(Program program) {
		program.elements.filter(ComponentType)
	}
	
	def getMqtt(Program program) {
		program.elements.filter(Mqtt).get(0)
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
	
	def getServer(Program program) {
		program.elements.filter(Server).get(0)
	}
}