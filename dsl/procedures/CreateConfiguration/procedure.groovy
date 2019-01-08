import java.io.File

def procName = 'CreateConfiguration'
procedure procName,
  description: 'Creates a plugin configuration',
  timeLimit: '5',
  timeLimitUnits: 'minutes',
{
  formalParameter(formalParameterName: 'credential', type: 'credential', required: '0')
  formalParameter(formalParameterName: 'proxy_credential', type: 'credential', required: '0')

  step 'checkConnection',
    command: new File(pluginDir, "dsl/procedures/$procName/steps/checkConnection.pl").text,
    errorHandling: 'abortProcedureNow',
    shell: 'ec-perl',
    timeLimit: '5',
    timeLimitUnits: 'minutes',
    condition: '$[checkConnection]', {
       attachParameter(formalParameterName: 'credential')
       attachParameter(formalParameterName: 'proxy_credential')
    }

    step 'createConfiguration',
            command: new File(pluginDir, "dsl/procedures/$procName/steps/createConfiguration.pl").text,
            errorHandling: 'abortProcedure',
            exclusiveMode: 'none',
            postProcessor: 'postp',
            releaseMode: 'none',
            shell: 'ec-perl',
            timeLimitUnits: 'minutes'

    step 'createAndAttachCredential',
        command: new File(pluginDir, "dsl/procedures/$procName/steps/createAndAttachCredential.pl").text,
        errorHandling: 'failProcedure',
        exclusiveMode: 'none',
        releaseMode: 'none',
        shell: 'ec-perl',
        timeLimitUnits: 'minutes'

}
