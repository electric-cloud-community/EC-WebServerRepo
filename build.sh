#!/usr/bin/env bash


if [[ $1 = "--gwt" ]]
then
    ./gradlew compileGwt
    rm -rf htdocs/war
    mkdir htdocs/war
    cp -fr build/gwt/out/ecplugins.EC_WebServerRepo.RetrieveArtifactParameterPanel/ \
htdocs/war/ecplugins.EC_WebServerRepo.RetrieveArtifactParameterPanel/
#    cp -fr build/gwt/out/ecplugins.EC_WebServerRepo.PublishArtifactParameterPanel/ \
#htdocs/war/ecplugins.EC_WebServerRepo.PublishArtifactParameterPanel/
fi

PLUGIN_NAME=EC-WebServerRepo
PLUGIN_VERSION=1.0.0

../ecpluginbuilder --plugin-version $PLUGIN_VERSION --plugin-name $PLUGIN_NAME --folder dsl,htdocs,pages,META-INF

 ectool uninstallPlugin $PLUGIN_NAME-$PLUGIN_VERSION


#ectool --server nick login admin changeme
ectool installPlugin build/$PLUGIN_NAME.zip --force 1
echo "Installed"
ectool promotePlugin $PLUGIN_NAME-$PLUGIN_VERSION

# ectool setProperty /projects/$PLUGIN_NAME-$PLUGIN_VERSION/debugLevel 10
