/*
 * generated by Xtext 2.17.0
 */
package dk.sdu.mmmi.mdsd.iot_dsl.ui.wizard


import org.eclipse.core.runtime.Status
import org.eclipse.jdt.core.JavaCore
import org.eclipse.xtext.ui.XtextProjectHelper
import org.eclipse.xtext.ui.util.PluginProjectFactory
import org.eclipse.xtext.ui.wizard.template.IProjectGenerator
import org.eclipse.xtext.ui.wizard.template.IProjectTemplateProvider
import org.eclipse.xtext.ui.wizard.template.ProjectTemplate

import static org.eclipse.core.runtime.IStatus.*

/**
 * Create a list with all project templates to be shown in the template new project wizard.
 * 
 * Each template is able to generate one or more projects. Each project can be configured such that any number of files are included.
 */
class IoTDSLProjectTemplateProvider implements IProjectTemplateProvider {
	override getProjectTemplates() {
		#[new HelloWorldProject]
	}
}

@ProjectTemplate(label="Hello World", icon="project_template.png", description="<p><b>Hello World</b></p>
<p>This is a parameterized hello world for IoTDSL. You can set a parameter to modify the content in the generated file
and a parameter to set the package the file is created in.</p>")
final class HelloWorldProject {
	val advanced = check("Advanced:", false)
	val advancedGroup = group("Properties")
	val name = combo("Name:", #["Xtext", "World", "Foo", "Bar"], "The name to say 'Hello' to", advancedGroup)
	val path = text("Package:", "", "The package path to place the files in", advancedGroup)

	override protected updateVariables() {
		name.enabled = advanced.value
		path.enabled = advanced.value
		if (!advanced.value) {
			name.value = "Xtext"
			path.value = ""
		}
	}

	override protected validate() {
		if (path.value.matches('[a-z][a-z0-9_]*(/[a-z][a-z0-9_]*)*'))
			null
		else
			new Status(ERROR, "Wizard", "'" + path + "' is not a valid package name")
	}

	override generateProjects(IProjectGenerator generator) {
		generator.generate(new PluginProjectFactory => [
			projectName = projectInfo.projectName
			importedPackages += "dk.sdu.mmmi.mdsd.iot_dsl"
			location = projectInfo.locationPath
			projectNatures += #[JavaCore.NATURE_ID, "org.eclipse.pde.PluginNature", XtextProjectHelper.NATURE_ID]
			builderIds += #[JavaCore.BUILDER_ID, XtextProjectHelper.BUILDER_ID]
			folders += "src"
			addFile('''src/«path»/main.iot''', '''
				/*
				 * This is an example program
				 */
				mqtt(host="localhost", user='<user>', pass="<password>", port=1883)
				server:
					port=80
				board b1:
					wifi(ssid="<ssid>", pass="<password>")
					led pycom_led()
				var boolean led_on
				every 5 seconds do:
					if led_on then
						b1.led.status = "OFF"
						led_on = false
					else
						b1.led.status = "ON"
						led_on = true
			''')
		])
	}
}
