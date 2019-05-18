package dk.sdu.mmmi.mdsd.iot_dsl.generator

import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.And
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Assignment
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Board
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Boolean
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Comparison
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Component
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.ComponentType
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Div
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Equality
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Expose
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Expression
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.ExternalUse
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.FloatNumber
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.If
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Loop
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Minus
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Mqtt
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Mult
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Number
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Or
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Percentage
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Plus
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Property
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.PropertyUse
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Reference
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.SensorType
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Statement
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Program
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.Text
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.VariableDeclaration
import java.util.List
import java.util.Map
import java.util.Set
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import org.eclipse.xtext.generator.IGenerator

import static extension org.eclipse.xtext.EcoreUtil2.*

class ServerGenerator implements IGenerator{
	
	var Map<Loop, String> loopNames
	var List<VariableDeclaration> stateVariables
	
	override doGenerate(Resource resource, IFileSystemAccess fsa) {
		val program = resource.allContents.filter(Program).next
		loopNames = newLinkedHashMap
		stateVariables = program.statevariables
		program.logic.filter(Loop).forEach[loop, i| loopNames.put(loop, "loop"+i)]
		fsa.generateFile('server/server.go', program.generateServer)
	}
	
	def CharSequence generateServer(Program program) '''
			package main
			
			import (
				"fmt"
				"net/http"
				"strconv"
				"time"
				
				mqtt "github.com/eclipse/paho.mqtt.golang"
				"github.com/gorilla/mux"
			)
			
			type Externals interface {
				«FOR ext : program.externals»
				«ext.name»(«FOR param : ext.parameters SEPARATOR ','»«param.name» «IF param.list»[]«ENDIF»«param.type.generateType»«ENDFOR») «ext.type.generateType»
				«ENDFOR»
			}
			
			func NewServer(externals Externals) *server {
				«program.mqtt.generateMQTT»
								
				return &server{
					externals,
					mqtt_client,
					&state{},
					«FOR board : program.boards»
					&board_«board.name»{«FOR component : board.elements.filter(Component)»&«component.type.name»{},«ENDFOR»},
					«ENDFOR»
				}
			}
			
			type server struct {
				externals Externals
				mqtt mqtt.Client
				state *state
				«FOR board : program.boards»
				«board.name» *board_«board.name»
				«ENDFOR»
			}
			
			type state struct {
				«FOR variable : program.statevariables»
				«variable.name» «variable.type.generateType»
				«ENDFOR»
			}
			
			func (s *server) send_message(topic string, payload interface{}) {
				token := s.mqtt.Publish(topic, 0, false, payload)
				token.Wait()
			}
			
			«FOR loop : program.logic.filter(Loop)»
			«loop.generateLoopFunction»
			«ENDFOR»
			
			«FOR expose : program.expose»
			«expose.generateExpose»
			«ENDFOR»
			
			«FOR board : program.boards»
			«board.generateBoardType»
			«ENDFOR»
			
			«FOR componentType : program.usedComponentTypes»
			«componentType.generateComponentType»
			«ENDFOR»
			
			func (s *server) run() {
				«FOR board : program.boards»
					«FOR component : board.elements.filter(Component)»
						«IF component.type instanceof SensorType»
							«FOR property : component.type.properties»
							«generatePropertySubscription(board, component, property)»
							«ENDFOR»
						«ENDIF»
					«ENDFOR»
				«ENDFOR»
				
				r := mux.NewRouter()
				«FOR expose : program.expose»
				r.HandleFunc("/«expose.name»", s.«expose.name»)
				«ENDFOR»
				
				«FOR loop : program.logic.filter(Loop)»
				go s.«loopNames.get(loop)»()
				«ENDFOR»
				
				http.ListenAndServe(":«program.server.port»", r)
			}
		'''
		
		def CharSequence generatePropertySubscription(Board board, Component component, Property property) '''
			s.mqtt.Subscribe("«board.name»/«component.name»/«property.name»", 0, func(client mqtt.Client, msg mqtt.Message) {
				«IF property.type.equals("string")»
				value := string(msg.Payload())
				s.«board.name».«component.name».«property.name» = value
				«ELSE»
				value, err := «property.generateStringConversion»
				if err != nil {
					fmt.Println(fmt.Errorf("Error on topic %v: %v", msg.Topic(), err))
				} else {
					s.«board.name».«component.name».«property.name» = value
				}
				«ENDIF»
				
			})
		'''
		
		def CharSequence generateStringConversion(Property property) {
			switch property.type {
				case "integer": "strconv.ParseInt(string(msg.Payload()), 10, 64)"
				case "float": "strconv.ParseFloat(string(msg.Payload()), 64)"
				case "boolean": "strconv.ParseBool(string(msg.Payload()))"
			}
		}
		
		def CharSequence generateMQTT(Mqtt mqtt) '''
			opts := mqtt.NewClientOptions()
			opts.AddBroker("«mqtt.host»:«mqtt.port»")
			opts.SetClientID("server")
			opts.SetUsername("«mqtt.user»")
			opts.SetPassword("«mqtt.pass»")
			
			mqtt_client := mqtt.NewClient(opts)
			if token := mqtt_client.Connect(); token.Wait() && token.Error() != nil {
				panic(token.Error())
			}
		'''
		
		def CharSequence generateLoopFunction(Loop loop) '''
			func (s *server) «loopNames.get(loop)»() {
				for _ = range time.Tick(«loop.time» * «loop.timeunit.generateTimeUnit») {
					«FOR statement : loop.statements»
					«statement.generateStatement»
					«ENDFOR»
				}
			}
		'''
		
		def CharSequence generateTimeUnit(String timeUnit) {
			switch timeUnit {
				case "hours": "time.Hour"
				case "minutes": "time.Minute"
				case "seconds": "time.Second"
			}
		}
		
		def CharSequence generateStatement(Statement statement) {
			switch statement {
				VariableDeclaration: '''«statement.name» := «statement.exp.generateExp»'''
				Assignment: statement.generateAssignment
				If: '''
				if «statement.condition.generateExp» {
					«FOR stmt : statement.statements»
					«stmt.generateStatement»
					«ENDFOR»
				}«FOR elseif : statement.elseifs» else if «elseif.condition.generateExp» {
					«FOR stmt : elseif.statements»
					«stmt.generateStatement»
					«ENDFOR»
				}«ENDFOR»«IF statement.^else !== null» else {
					«FOR stmt : statement.^else.statements»
					«stmt.generateStatement»
					«ENDFOR»
				}«ENDIF»
				'''
			}
		}
	
	def CharSequence generateAssignment(Assignment assignment) {
		var ref = assignment.ref
		switch ref {
			PropertyUse: {
				if (ref.board !== null) '''
					s.«ref.board.name».«ref.component.name».«ref.property.name» = «assignment.exp.generateExp»
					s.send_message("«ref.board.name»/«ref.component.name»/«ref.property.name»", fmt.Sprintf("%v", «assignment.exp.generateExp»))'''
				else {
					'''
					«FOR board : ref.getContainerOfType(Program).boards»
					«FOR component : board.getComponentsOfType(ref.componenttype)»
					s.«board.name».«component.name».«ref.property.name» = «assignment.exp.generateExp»
					s.send_message("«board.name»/«component.name»/«ref.property.name»", fmt.Sprintf("%v", «assignment.exp.generateExp»))
					«ENDFOR»
					«ENDFOR»'''
				}
			}
			Reference: '''«assignment.ref.generateReference» = «assignment.exp.generateExp»'''
		}
	}
		
		def CharSequence generateExp(Expression exp) {
			switch exp {
				Plus: '''«exp.left.generateExp» + «exp.right.generateExp»'''
				Minus: '''«exp.left.generateExp» - «exp.right.generateExp»'''
				Mult: '''«exp.left.generateExp» * «exp.right.generateExp»'''
				Div: '''«exp.left.generateExp» / «exp.right.generateExp»'''
				Text: '''"«exp.value»"'''
				ExternalUse: exp.generateExternalUse
				Percentage: '''«exp.value / 100.0»'''
				PropertyUse: exp.generatePropertyUse
				Reference: exp.generateReference
				Number: exp.value.toString
				Boolean: exp.value
				FloatNumber: exp.value.toString
				Or: '''«exp.left.generateExp» || «exp.right.generateExp»'''
				And: '''«exp.left.generateExp» && «exp.right.generateExp»'''
				Equality: '''«exp.left.generateExp» «exp.op» «exp.right.generateExp»'''
				Comparison: '''«exp.left.generateExp» «exp.op» «exp.right.generateExp»'''
			}
		}
	
		def CharSequence generateReference(Reference ref) {
			if(stateVariables.contains(ref.ref))
				'''s.state.«ref.ref.name»'''
			else
				ref.ref.name
		}
	
		def CharSequence generateExternalUse(ExternalUse use)
			'''s.externals.«use.ref.name»(«FOR arg : use.args SEPARATOR ','»«arg.generateExp»«ENDFOR»)'''
			
		def CharSequence generatePropertyUse(PropertyUse use) {
			if (use.board === null) {
				'''[]«use.property.type.generateType»{«use.generatePropertyList»}'''
			} else {
				'''s.«use.board.name».«use.component.name».«use.property.name»'''
			}
		}
		
		def CharSequence generatePropertyList(PropertyUse use) {
			var list = ""
			for (Board board : use.getContainerOfType(Program).boards) {
				for (Component component : board.getComponentsOfType(use.componenttype)) {
					list += '''s.«board.name».«component.name».«use.property.name», '''
				}
			}
			
			return list
		}
	
		def getComponentsOfType(Board board, ComponentType type) {
			var components = newArrayList
			for(Component component : board.elements.filter(Component)) {
				if (component.type == type) {
					components.add(component)
				}
			}
			return components
		}
		
		def CharSequence generateExpose(Expose expose) '''
			func (s *server) «expose.name»(w http.ResponseWriter, r *http.Request) {
				«FOR statement : expose.statements»
				«statement.generateStatement»
				«ENDFOR»
			}
		'''
		
		def CharSequence generateBoardType(Board board) '''
			type board_«board.name» struct {
				«FOR component : board.elements.filter(Component)»
				«component.name» *«component.type.name»
				«ENDFOR»
			}
		'''
		
		def CharSequence generateComponentType(ComponentType type) '''
			type «type.name» struct {
				«FOR property : type.properties»
				«property.name» «property.type.generateType»
				«ENDFOR»
			}
		'''
		
		def CharSequence generateType(String type) {
			switch type {
				case "string": "string"
				case "integer": "int64"
				case "float": "float64"
				case "boolean": "bool"
			}
		}
		
		def Set<ComponentType> getUsedComponentTypes(Program program) {
			val types = newLinkedHashSet
			program.boards.forEach[
				elements.filter(Component).forEach[
					types.add(type)
				]
			]
			return types
		}
	
}