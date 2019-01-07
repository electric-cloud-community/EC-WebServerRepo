def procName='RetrieveArtifactFromWebServer'
def stepName = 'retrieveArtifact'

procedure procName,
  description: 'Retrieve an artifact from a web server',
{
  property 'ec_customEditorData', {
    property 'nameIdentifier', value: 'artifact'
    property 'versionIdentifier', value: 'version'
  }

  step stepName,
    command: """
\$[/myProject/scripts/preamble]
use EC::WebServerRepo::Plugin;
EC::WebServerRepo::Plugin->new->run_step('retrieve_artifact');
""",
    errorHandling: 'failProcedure',
    exclusiveMode: 'none',
    releaseMode: 'none',
    shell: 'ec-perl',
    timeLimitUnits: 'minutes'
}
