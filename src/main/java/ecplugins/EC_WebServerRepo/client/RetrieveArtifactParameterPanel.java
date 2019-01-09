
// RetrieveArtifactParameterPanel.java --
//
// RetrieveArtifactParameterPanel.java is part of ElectricCommander.
//
// Copyright (c) 2005-2019 Electric Cloud, Inc.
// All rights reserved.
//

package ecplugins.EC_WebServerRepo.client;

import java.util.Collection;
import java.util.HashMap;
import java.util.Map;
import java.lang.String;

import com.google.gwt.user.client.ui.CheckBox;
import com.google.gwt.user.client.ui.TextBox;
import com.google.gwt.user.client.ui.Widget;

import com.electriccloud.commander.client.domain.ActualParameter;
import com.electriccloud.commander.client.domain.FormalParameter;
import com.electriccloud.commander.client.util.StringUtil;
import com.electriccloud.commander.gwt.client.ui.FormTable;
import com.electriccloud.commander.gwt.client.ui.ParameterPanel;
import com.electriccloud.commander.gwt.client.ui.ParameterPanelProvider;

import ecinternal.client.InternalComponentBase;

import static com.electriccloud.commander.gwt.client.ui.FormBuilder.MISSING_REQUIRED_ERROR_MESSAGE;

public class RetrieveArtifactParameterPanel
    extends InternalComponentBase
    implements ParameterPanel,
        ParameterPanelProvider
{

    //~ Static fields/initializers ---------------------------------------------

    private static final String CONFIG  = "config";
    private static final String OVERWRITE  = "overwrite";
    private static final String DIRECTORY  = "directory";
    private static final String PATH       = "path";
    private static final String VERSION    = "version";
    private static final String ARTIFACT   = "artifact";
    private static final String RESULT_PROPERTY = "resultProperty";

    //~ Instance fields --------------------------------------------------------

    private FormTable    m_form;
    private TextBox      m_Config;
    private TextBox      m_Path;
    private TextBox      m_Artifact;
    private TextBox      m_Version;
    private CheckBox     m_Overwrite;
    private TextBox      m_Directory;
    private TextBox      m_ResultProperty;

    //~ Methods ----------------------------------------------------------------

    @Override public Widget doInit()
    {
        m_form          = getUIFactory().createFormTable();
        m_Config        = new TextBox();
        m_Path          = new TextBox();
        m_Artifact      = new TextBox();
        m_Version       = new TextBox();
        m_Overwrite     = new CheckBox();
        m_Directory     = new TextBox();
        m_ResultProperty = new TextBox();

        m_form.addFormRow(CONFIG, "Configuration Name:", m_Config, false,
            "Name of the configuration to be used for retrieving Web Server's URL and credentials.<br/><br/>A Configuration defines connection details and can be created by going to plugin <a style=\"text-decoration: none !important; border-bottom-style: dashed; border-bottom-width: thin; font-size: inherit; color: inherit; font-family: inherit; border-color: #d8d8d8; border-spacing: 2px;\" target=\"_blank\" href=\"/commander/pages/EC-Maven/configurations\">configuration page</a>.");
        m_form.addFormRow(PATH, "Path:", m_Path, true,
            "Path under the webServer root");
        m_form.addFormRow(ARTIFACT, "Artifact:", m_Artifact, true,
            "Id of artifact to be retrieved, in form of <artifact group>:<artifact key>, for example, 'org.apache.activemq:activemq-all'");
        m_form.addFormRow(VERSION, "Version:", m_Version, false,
            "Artifact version");
        m_form.addFormRow(DIRECTORY, "Retrieve to Directory:", m_Directory,
            false,
            "Directory to retrieve artifact to. Defaults to workspace directory");
        m_form.addFormRow(OVERWRITE, "Overwrite:", m_Overwrite, false,
            "Overwrite file if it exists");
        m_form.addFormRow(RESULT_PROPERTY, "Retrieved Artifact Location Property:",
            m_ResultProperty, false,
            "Name of property sheet path used by the step to create a property sheet. This property sheet stores information about the retrieved artifact version, including its location in the file system.");
        // Default value
        m_ResultProperty.setValue("/myJob/retrievedArtifactVersions/$[assignedResourceName]");

        return m_form.asWidget();
    }

    @Override public boolean validate()
    {
        m_form.clearAllErrors();

        if (StringUtil.isEmpty(m_Artifact.getValue())) {
            m_form.setErrorMessage(ARTIFACT, MISSING_REQUIRED_ERROR_MESSAGE);

            return false;
        }
        else if (StringUtil.isEmpty(m_Version.getValue())) {
            m_form.setErrorMessage(VERSION, MISSING_REQUIRED_ERROR_MESSAGE);

            return false;
        }

        return true;
    }

    @Override public ParameterPanel getParameterPanel()
    {
        return this;
    }

    @Override public Map<String, String> getValues()
    {
        Map<String, String> values = new HashMap<String, String>();

        values.put(CONFIG, m_Config.getValue());
        values.put(PATH, m_Path.getValue());
        values.put(ARTIFACT, m_Artifact.getValue());
        values.put(VERSION, m_Version.getValue());
        values.put(DIRECTORY, m_Directory.getValue());
        values.put(OVERWRITE, m_Overwrite.getValue()
                ? "1"
                : "0");
        values.put(RESULT_PROPERTY, m_ResultProperty.getValue());

        return values;
    }

    @Override public void setActualParameters(
            Collection<ActualParameter> actualParameters)
    {
        m_Version.setValue(null);

        for (ActualParameter actualParameter : actualParameters) {
            String name  = actualParameter.getName();
            String value = actualParameter.getValue();

            if (CONFIG.equals(name)) {
                m_Config.setValue(value);
            }
            else if (PATH.equals(name)) {
                m_Path.setValue(value);
            }
            else if (ARTIFACT.equals(name)) {
                m_Artifact.setValue(value);
            }
            else if (VERSION.equals(name)) {
                m_Version.setValue(value);
            }
            else if (DIRECTORY.equals(name)) {
                m_Directory.setValue(value);
            }
            else if (OVERWRITE.equals(name)) {
                m_Overwrite.setValue("0".equals(value)
                        ? false
                        : true);
            }
            else if (RESULT_PROPERTY.equals(name)) {
                m_ResultProperty.setValue(value);
            }
        }
    }

    @Override public void setFormalParameters(
            Collection<FormalParameter> formalParameters) { }
}
