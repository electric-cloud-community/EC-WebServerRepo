
// RetrieveArtifactFactory.java --
//
// RetrieveArtifactFactory.java is part of ElectricCommander.
//
// Copyright (c) 2005-2019 Electric Cloud, Inc.
// All rights reserved.
//

package ecplugins.EC_WebServerRepo.client;

import ecinternal.client.InternalComponentBaseFactory;

import com.electriccloud.commander.gwt.client.Component;
import com.electriccloud.commander.gwt.client.ComponentContext;
import org.jetbrains.annotations.NotNull;

public class RetrieveArtifactFactory
    extends InternalComponentBaseFactory
{

    //~ Methods ----------------------------------------------------------------

    @NotNull
    @Override protected Component createComponent(ComponentContext jso)
    {
        return new RetrieveArtifactParameterPanel();
    }
}
