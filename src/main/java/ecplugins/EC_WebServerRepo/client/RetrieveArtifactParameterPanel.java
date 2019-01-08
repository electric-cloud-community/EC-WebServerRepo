
// RetrieveArtifactParameterPanel.java --
//
// RetrieveArtifactParameterPanel.java is part of ElectricCommander.
//
// Copyright (c) 2005-2014 Electric Cloud, Inc.
// All rights reserved.
//

package ecplugins.EC_Maven.client;

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
    private static final String TYPE       = "type";
    private static final String CLASSIFIER = "classifier";
    private static final String VERSION    = "version";
    private static final String ARTIFACT   = "artifact";
    private static final String REPOSITORY = "repository";
    private static final String SERVER     = "server";
    private static final String RESULT_PROPERTY = "resultProperty";
    private static final String MISSING_SERVER_OR_CONFIG = "Either 'Server URL' or 'Configuration Name' must be specified.";

    //~ Instance fields --------------------------------------------------------

    private FormTable    m_form;
    private RadioText    m_Config;
    private RadioText    m_Server;
    private TextBox      m_Repository;
    private TextBox      m_Artifact;
    private TextBox      m_Type;
    private TextBox      m_Classifier;
    private VersionRange m_VersionRange;
    private CheckBox     m_Overwrite;
    private TextBox      m_Directory;
    private TextBox      m_ResultProperty;

    //~ Methods ----------------------------------------------------------------

    @Override public Widget doInit()
    {
        m_form         = getUIFactory().createFormTable();
        m_Config       = new RadioText("repository_config", true);
        m_Server       = new RadioText("repository_config");
        m_Repository   = new TextBox();
        m_Artifact     = new TextBox();
        m_Type         = new TextBox();
        m_Classifier   = new TextBox();
        m_VersionRange = new VersionRange();
        m_Overwrite    = new CheckBox();
        m_Directory    = new TextBox();
        m_ResultProperty = new TextBox();

        m_form.addFormRow(CONFIG, "Configuration Name:", m_Config, false,
                "Name of the configuration to be used for retrieving Maven Server's URL and credentials.<br/><br/>A Configuration defines connection details and can be created by going to plugin <a style=\"text-decoration: none !important; border-bottom-style: dashed; border-bottom-width: thin; font-size: inherit; color: inherit; font-family: inherit; border-color: #d8d8d8; border-spacing: 2px;\" target=\"_blank\" href=\"/commander/pages/EC-Maven/configurations\">configuration page</a>.");
        m_form.addFormRow(SERVER, "Public Server URL:", m_Server, false,
            "URL of public maven repository, for example, http://repo.spring.io/");
        m_form.addFormRow(REPOSITORY, "Repository:", m_Repository, true,
            "Name of maven repository, for example, 'repo'");
        m_form.addFormRow(ARTIFACT, "Artifact:", m_Artifact, true,
            "Id of artifact to be retrieved, in form of <artifact group>:<artifact key>, for example, 'org.apache.activemq:activemq-all'");
        m_form.addFormRow(VERSION, "Version:", m_VersionRange, false,
            "Artifact version");
        m_form.addFormRow(CLASSIFIER, "Classifier:", m_Classifier, false,
                "Artifact classifier");
        m_form.addFormRow(TYPE, "Artifact Extension:", m_Type, true,
            "Artifact type extension, for example, '.jar', '.txt'");
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

        if (StringUtil.isEmpty(m_Repository.getValue())) {
            m_form.setErrorMessage(REPOSITORY, MISSING_REQUIRED_ERROR_MESSAGE);

            return false;
        }
        else if (StringUtil.isEmpty(m_Artifact.getValue())) {
            m_form.setErrorMessage(ARTIFACT, MISSING_REQUIRED_ERROR_MESSAGE);

            return false;
        }
        else if (StringUtil.isEmpty(m_Type.getValue())) {
            m_form.setErrorMessage(TYPE, MISSING_REQUIRED_ERROR_MESSAGE);

            return false;
        }

        if(StringUtil.isEmpty(m_Server.getValue()) && StringUtil.isEmpty(m_Config.getValue())) {
            m_form.setErrorMessage(SERVER, MISSING_SERVER_OR_CONFIG);
            m_form.setErrorMessage(CONFIG, MISSING_SERVER_OR_CONFIG);

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
        values.put(SERVER, m_Server.getValue());
        values.put(REPOSITORY, m_Repository.getValue());
        values.put(ARTIFACT, m_Artifact.getValue());
        values.put(CLASSIFIER, m_Classifier.getValue());
        values.put(VERSION, m_VersionRange.getValue());
        values.put(TYPE, m_Type.getValue());
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
        m_VersionRange.setValue(null);

        for (ActualParameter actualParameter : actualParameters) {
            String name  = actualParameter.getName();
            String value = actualParameter.getValue();

            if (CONFIG.equals(name)) {
                m_Config.setValue(value);
            }
            else if (SERVER.equals(name)) {
                m_Server.setValue(value);
            }
            else if (REPOSITORY.equals(name)) {
                m_Repository.setValue(value);
            }
            else if (ARTIFACT.equals(name)) {
                m_Artifact.setValue(value);
            }
            else if (CLASSIFIER.equals(name)) {
                m_Classifier.setValue(value);
            }
            else if (VERSION.equals(name)) {
                m_VersionRange.setValue(value);
            }
            else if (TYPE.equals(name)) {
                m_Type.setValue(value);
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
