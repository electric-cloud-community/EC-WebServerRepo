// RetrieveArtifactResources.java --
//
// RetrieveArtifactResources.java is part of ElectricCommander.
//
// Copyright (c) 2005-2019 Electric Cloud, Inc.
// All rights reserved.
//
package ecplugins.EC_WebServerRepo.client;
import com.google.gwt.core.client.GWT;
import com.google.gwt.resources.client.ClientBundle;
/**
 * This interface houses a class that extends CssResource.
 *
 * <p>More information here:
 * http://code.google.com/webtoolkit/doc/latest/DevGuideClientBundle.html</p>
 */
public interface RetrieveArtifactResources
    extends ClientBundle
{
    //~ Instance fields --------------------------------------------------------
    // The instance of the ClientBundle that must be injected during doInit()
    RetrieveArtifactResources RESOURCES = GWT.create(RetrieveArtifactResources.class);
    //~ Methods ----------------------------------------------------------------
    // Specify explicit stylesheet. Every class in the stylesheet should have a
    // function defined in RetrieveArtifactStyles
    @Source("RetrieveArtifact.css")
    RetrieveArtifactStyles css();
}
