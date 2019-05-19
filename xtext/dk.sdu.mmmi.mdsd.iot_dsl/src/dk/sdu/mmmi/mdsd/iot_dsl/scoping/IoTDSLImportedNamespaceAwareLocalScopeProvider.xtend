package dk.sdu.mmmi.mdsd.iot_dsl.scoping

import org.eclipse.xtext.scoping.impl.ImportedNamespaceAwareLocalScopeProvider
import org.eclipse.xtext.scoping.impl.ImportNormalizer
import org.eclipse.xtext.naming.QualifiedName

class IoTDSLImportedNamespaceAwareLocalScopeProvider extends ImportedNamespaceAwareLocalScopeProvider {
	override protected getImplicitImports(boolean ignoreCase) {
		newArrayList(new ImportNormalizer(
			QualifiedName.create("pycom"),
			true,
			ignoreCase
		))
	}
	
}