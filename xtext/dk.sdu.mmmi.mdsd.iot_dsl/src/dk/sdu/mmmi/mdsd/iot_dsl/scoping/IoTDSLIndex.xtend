package dk.sdu.mmmi.mdsd.iot_dsl.scoping

import com.google.inject.Inject
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.resource.impl.ResourceDescriptionsProvider
import dk.sdu.mmmi.mdsd.iot_dsl.ioTDSL.IoTDSLPackage
import org.eclipse.xtext.resource.IContainer
import org.eclipse.emf.ecore.EClass

class IoTDSLIndex {
	@Inject ResourceDescriptionsProvider rdp
	@Inject IContainer.Manager cm

	def getResourceDescription(EObject o) {
		val index = rdp.getResourceDescriptions(o.eResource)
		index.getResourceDescription(o.eResource.URI)
	}

	def getExportedEObjectDescriptions(EObject o) {
		o.getResourceDescription.getExportedObjects
	}

	def getExportedComponentTypesEObjectDescriptions(EObject o) {
		o.getResourceDescription.getExportedObjectsByType(IoTDSLPackage.eINSTANCE.componentType)
	}

	def getVisibleEObjectDescriptions(EObject o, EClass type) {
		o.getVisibleContainers.map [ container |
			container.getExportedObjectsByType(type)
		].flatten
	}

	def getVisibleContainers(EObject o) {
		val index = rdp.getResourceDescriptions(o.eResource)
		val rd = index.getResourceDescription(o.eResource.URI)
		cm.getVisibleContainers(rd, index)
	}

	def getVisibleComponentTypesDescriptions(EObject o) {
		o.getVisibleEObjectDescriptions(IoTDSLPackage.eINSTANCE.componentType)
	}

	def getVisibleExternalComponentTypesDescriptions(EObject o) {
		val allVisibleComponentTypes = o.getVisibleComponentTypesDescriptions
		val allExportedComponentTypes = o.getExportedComponentTypesEObjectDescriptions
		val difference = allVisibleComponentTypes.toSet
		difference.removeAll(allExportedComponentTypes.toSet)
		return difference.toMap[qualifiedName]
	}
	
	def getVisibleExternalDescriptionsForType(EObject o, EClass c) {
		val allVisibleObjects = o.getVisibleEObjectDescriptions(c)
		val allExportedObjects = o.resourceDescription.getExportedObjectsByType(c)
		val difference = allVisibleObjects.toSet
		difference.removeAll(allExportedObjects.toSet)
		return difference.toMap[qualifiedName]
	}
}
