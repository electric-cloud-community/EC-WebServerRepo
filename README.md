## EC-WebServerRepo

The ElectricFlow Web Server based artifact repository integration

### Description
This ElectricFlow plugin enables file retrieval from a URL. The plugin file retrieval procedure is exposed as one of the artifact retrieval options in a component definition.

### Installation
Upload the file EC-WebServerRepo.jar into your ElectricFlow server as with any ElectricFlow plugin. Then promote EC-WebServerRepo. See the Help page for details on use.

### Build
1. Download Java JDK 8 as you needs tools.jar
1. Download and install gradle
1. Download and build ecpluginbuilder
    ```
	git clone https://github.com/electric-cloud/ecpluginbuilder.git
    ```

1. Run it.
This will build it (gradle and PLuginWizard), install it and promote it.
    ```
	ec-perl ecpluginbuilder.pl
    ```
