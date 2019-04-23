package dk.sdu.mmmi.mdsd.iot_dsl.generator

import org.eclipse.xtext.generator.IGenerator
import org.eclipse.emf.ecore.resource.Resource
import org.eclipse.xtext.generator.IFileSystemAccess
import java.util.Map
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.*
import java.util.Set
import static extension org.eclipse.xtext.EcoreUtil2.*

class ServerGenerator implements IGenerator{
	
	var Map<Loop, String> loopNames
	
	override doGenerate(Resource resource, IFileSystemAccess fsa) {
		val system = resource.allContents.filter(System).next
		loopNames = newLinkedHashMap
		system.logic.filter(Loop).forEach[loop, i| loopNames.put(loop, "loop"+i)]
		fsa.generateFile('server/main.go', system.generateServer)
	}
	
	def CharSequence generateServer(System system) '''
			package main
			
			import (
				"fmt"
				"net/http"
				"strconv"
				"time"
				
				mqtt "github.com/eclipse/paho.mqtt.golang"
				"github.com/gorilla/mux"
			)
			
			type server struct {
				client mqtt.Client
				«FOR board : system.boards»
				«board.name» *board_«board.name»
				«ENDFOR»
			}
			
			func (s *server) send_message(topic string, payload interface{}) {
				token := s.client.Publish(topic, 0, false, payload)
				token.Wait()
			}
			
			«FOR loop : system.logic.filter(Loop)»
			«loop.generateLoopFunction»
			«ENDFOR»
			
			«FOR expose : system.expose»
			«expose.generateExpose»
			«ENDFOR»
			
			«FOR board : system.boards»
			«board.generateBoardType»
			«ENDFOR»
			
			«FOR componentType : system.usedComponentTypes»
			«componentType.generateComponentType»
			«ENDFOR»
			
			func main() {
				«system.mqtt.generateMQTT»
				
				server := server{
					mqtt_client,
					«FOR board : system.boards»
					&board_«board.name»{«FOR component : board.elements.filter(Component)»&«component.type.name»{},«ENDFOR»},
					«ENDFOR»
				}
				
				«FOR board : system.boards»
					«FOR component : board.elements.filter(Component)»
						«IF component.type instanceof SensorType»
							«FOR property : component.type.properties»
							«generatePropertySubscription(board, component, property)»
							«ENDFOR»
						«ENDIF»
					«ENDFOR»
				«ENDFOR»
				
				r := mux.NewRouter()
				«FOR expose : system.expose»
				r.HandleFunc("/«expose.name»", server.«expose.name»)
				«ENDFOR»
				
				«FOR loop : system.logic.filter(Loop)»
				go server.«loopNames.get(loop)»()
				«ENDFOR»
				
				http.ListenAndServe(":«system.server.port»", r)
			}
			
			func float_average(xs []float64) float64 {
				total := float64(0)
				for _, x := range xs {
					total += x
				}
				return total / float64(len(xs))
			}
			
			func int_average(xs []int64) int64 {
				total := int64(0)
				for _, x := range xs {
					total += x
				}
				return total / int64(len(xs))
			}
		'''
		
		def CharSequence generatePropertySubscription(Board board, Component component, Property property) '''
			mqtt_client.Subscribe("«board.name»/«component.name»/«property.name»", 0, func(client mqtt.Client, msg mqtt.Message) {
				«IF property.type.equals("string")»
				value := string(msg.Payload())
				server.«board.name».«component.name».«property.name» = value
				«ELSE»
				value, err := «property.generateStringConversion»
				if err != nil {
					fmt.Println(fmt.Errorf("Error on topic %v: %v", msg.Topic(), err))
				} else {
					server.«board.name».«component.name».«property.name» = value
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
				Variable: '''«statement.name» := «statement.exp.generateExp»'''
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
					s.send_message("«ref.board.name»/«ref.component.name»/«ref.property.name»", «assignment.exp.generateExp»)'''
				else {
					'''
					«FOR board : ref.getContainerOfType(System).boards»
					«FOR component : board.getComponentsOfType(ref.componenttype)»
					s.«board.name».«component.name».«ref.property.name» = «assignment.exp.generateExp»
					s.send_message("«board.name»/«component.name»/«ref.property.name»", «assignment.exp.generateExp»)
					«ENDFOR»
					«ENDFOR»'''
				}
			}
			Reference: '''«assignment.ref.ref.name» = «assignment.exp.generateExp»'''
		}
	}
		
		def CharSequence generateExp(Expression exp) {
			switch exp {
				Plus: '''«exp.left.generateExp» + «exp.right.generateExp»'''
				Minus: '''«exp.left.generateExp» - «exp.right.generateExp»'''
				Mult: '''«exp.left.generateExp» * «exp.right.generateExp»'''
				Div: '''«exp.left.generateExp» / «exp.right.generateExp»'''
				Text: '''"«exp.value»"'''
				Average: exp.generateAverage
				Percentage: '''«exp.value / 100.0»'''
				PropertyUse: exp.generatePropertyUse
				Reference: exp.ref.name
				Number: exp.value.toString
				Boolean: exp.value
				FloatNumber: exp.value.toString
				Or: '''«exp.left.generateExp» || «exp.right.generateExp»'''
				And: '''«exp.left.generateExp» && «exp.right.generateExp»'''
				Equality: '''«exp.left.generateExp» «exp.op» «exp.right.generateExp»'''
				Comparison: '''«exp.left.generateExp» «exp.op» «exp.right.generateExp»'''
			}
		}
	
		def CharSequence generateAverage(Average avg) {
			if (avg.ref.property.type == "integer") {return '''int_average(«avg.ref.generatePropertyUse»)'''}
			else if (avg.ref.property.type == "float") {return '''float_average(«avg.ref.generatePropertyUse»)'''}

		} 
			
		def CharSequence generatePropertyUse(PropertyUse use) {
			if (use.board === null) {
				'''[]«use.property.type.generatePropertyType»{«use.generatePropertyList»}'''
			} else {
				'''s.«use.board.name».«use.component.name».«use.property.name»'''
			}
		}
		
		def CharSequence generatePropertyList(PropertyUse use) {
			var list = ""
			for (Board board : use.getContainerOfType(System).boards) {
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
				«property.name» «property.type.generatePropertyType»
				«ENDFOR»
			}
		'''
		
		def CharSequence generatePropertyType(String type) {
			switch type {
				case "string": "string"
				case "integer": "int64"
				case "float": "float64"
				case "boolean": "bool"
			}
		}
		
		def Set<ComponentType> getUsedComponentTypes(System system) {
			val types = newLinkedHashSet
			system.boards.forEach[
				elements.filter(Component).forEach[
					types.add(type)
				]
			]
			return types
		}
	
}