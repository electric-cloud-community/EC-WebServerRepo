package EC::WebServerRepo::Plugin;

use strict;
use warnings;
use Data::Dumper;
use File::Spec;
use base qw(EC::Plugin::Core);
use File::Path;
use EC::WebServerRepo::Client;
use EC::ProxyDispatcher;
use Archive::Zip;
use File::Basename;
use File::Copy;
use URI::Escape;
use Encode qw(decode encode);

=head2 after_init_hook

Debug level - we are reading property /projects/EC-PluginName-1.0.0/debugLevel.
If this property exists, it will set the debug level. Otherwize debug level will be 0, which is info.

=cut

sub after_init_hook {
    my ($self, %params) = @_;

    $self->{plugin_name} = '@PLUGIN_NAME@';
    $self->{plugin_key} = '@PLUGIN_KEY@';
    my $debug_level = 0;

    if ($self->{plugin_key}) {
        eval {
            $debug_level = $self->ec()->getProperty(
                "/plugins/$self->{plugin_key}/project/debugLevel"
            )->findvalue('//value')->string_value();
        };
    }
    if ($debug_level) {
        $self->debug_level($debug_level);
        $self->logger->level($debug_level);
        $self->logger->debug("Debug enabled for $self->{plugin_key}");
    }
    else {
        $self->debug_level(0);
    }

    # Init proxy if defined
    $self->{config_name} = $self->ec()->getProperty("config")->findvalue('//value')->string_value;
    $self->{proxy_dispatcher} = EC::ProxyDispatcher->new($self->ec(), $self->{config_name});
    $self->{proxy} = $self->{proxy_dispatcher}->proxy();

    print "Using plugin $self->{plugin_name}\n";
}


sub run_step {
    my ($self, $step_name) = @_;

    eval {
        my $method = $self->can("step_$step_name");
        $self->$method;
        1;
    } or do {
        my $err = $@;
        $self->bail_out($err);
    }
}

=head2 step_retrieve_artifact

Retrieving artifact (component). See GWT form for parameters.

=cut

sub step_retrieve_artifact {
    my ($self) = @_;

    my $params = $self->get_params_as_hashref(qw/
        config
        destination
        artifact
        version
        overwrite
        path
        resultPropertySheet
    /
    );

    my $result_property_sheet = '';
    eval {
        $result_property_sheet = $self->ec->getProperty({
            propertyName => 'resultPropertySheet',
            expand => 0,
        })->findvalue('//value')->string_value;
    };
    if ($result_property_sheet) {
        $result_property_sheet = $self->ec->expandString({value => $result_property_sheet})->findvalue('//value')->string_value;
    }
    $result_property_sheet ||= '/myJob/retrievedArtifactVersions/$[assignedResourceName]';
    $result_property_sheet = $self->ec->expandString({value => $result_property_sheet})->findvalue('//value')->string_value;

    $params->{resultPropertySheet} = $result_property_sheet;

    for my $param (sort keys %$params) {
        $self->logger->info(qq{Got parameter "$param" with value "$params->{$param}"});
    }
    # Release 1.0.0
    $params->{useRepositoryLayout} = 0;
    $self->params($params);


    for my $required (qw/artifact config/) {
        $self->validate_param_exists($required);
    }

    my $config = $self->get_config_values($self->{plugin_name}, $params->{config});

    $self->logger->trace('Parameters', $params);
    $self->logger->trace($config);

    $self->retrieved_artifact->{version} = $params->{version};
    my $class = 'EC::WebServerRepo::' . 'Generic'; # ucfirst(lc $params->{repoType});
    $self->logger->debug("Class name $class");

    eval "require $class";

    if ($@) {
        $self->logger->debug($@);
        $self->bail_out("Cannot work with repository type $params->{repoType}");
    }

    my $artifact_handler = $class->new(
        client => $self->client,
        plugin => $self,
        params => $params,
        config => $self->config,
        logger => $self->logger,
        proxy_dispatcher => $self->{proxy_dispatcher}
    );

    eval {
        my $layout = 'generic'; #$artifact_handler->get_layout($self->params->{repoType});
        if ($layout) {
            $self->logger->info(qq{Repository layout is "$layout"});
        }
    };

    eval {
        my $destination = $params->{destination};
        my $artifact_path = $params->{path};
        my $filename = $params->{artifact} . "-" . $params->{version} . ".rpm";
        $self->logger->info("Artifact path is $artifact_path/$filename");

        if ($destination && !-e $destination) {
            my $ok = mkpath($destination, 1);
            unless($ok) {
                $self->bail_out("Cannot create destination path: $!");
            }
            else {
                $self->logger->info("Created folder: $destination");
            }
        }

        my $filepath = $self->download_artifact($artifact_path, $filename, $destination);
        if ($params->{extract}) {
            $artifact_handler->extract($filepath, $params->{overwrite});
        }
        $self->save_result($self->retrieved_artifact);
        $self->set_properties_for_flow_ui($params, $self->retrieved_artifact->{url});
        1;
    } or do {
        $self->bail_out("Artifact retrieval failed: $@");
    };
}



=head2 save_result

Saves the results under the specified property sheet.

=cut

sub save_result {
    my ($self, $data) = @_;

    my $params = $self->params;
    my $result_property = $params->{resultPropertySheet};
    for my $field (keys %{$data}) {
        my $property = "$result_property/$params->{artifact}/$field";
        $property =~ s/\/+/\//g;
        my $val = $data->{$field};
        $self->ec->setProperty($property, "$val");
        $self->logger->info(qq{Set property "$property" to value "$val"});
    }
}

=head2 params

Returns params of the running step.

=cut

sub params {
    my ($self, $params) = @_;

    if ($params) {
        $self->{params} = $params;
    }
    return $self->{params};
}


=head2 client

WebServerRepo REST Client.

=cut
#@returns EC::WebServerRepo::Client
sub client {
    my ($self) = @_;

    unless($self->{client}) {
        $self->{client} = EC::WebServerRepo::Client->new(
            url => $self->config->{instance},
            userName => $self->config->{userName},
            password => $self->config->{password},
            logger => $self->logger,
            proxy_dispatcher => $self->{proxy_dispatcher}
        );

        unless($self->config->{userName}) {
            $self->logger->info("No username is provided in configuration, anonymous access");
        }
    }
    return $self->{client};
}




sub set_properties_for_flow_ui {
    my ($self, $params, $uri) = @_;

    # Store artifact info in step sheet for Electric Flow application
    # ** The Electric Flow UI depends on these properties being set **
    # See CEV-3471 for background info
    my $details_sheet = "/myJobStep/ec_inventory_details";

    my $artifact_name = $params->{artifact};
    my $version = $self->retrieved_artifact->{version};

    $self->ec->setProperty($details_sheet . "/deployedArtifactSource", $self->{plugin_key});
    $self->ec->setProperty($details_sheet . "/deployedArtifactName", $artifact_name);
    $self->ec->setProperty($details_sheet . "/deployedArtifactVersion", $version );
    $self->ec->setProperty($details_sheet . '/deployedArtifactSourceLocation', "$uri" );

    if ($self->{snapshot_version}) {
        $self->ec->setProperty($details_sheet."/deployedArtifactSnapshotVersion", $self->{snapshot_version});
    }
}

sub retrieved_artifact {
    my ($self) = @_;
    $self->{retrieved_artifact} ||= {};
    return $self->{retrieved_artifact};
}

sub published_artifact {
    my ($self) = @_;
    $self->{published_artifact} ||= {};
    return $self->{published_artifact};
}

sub download_artifact {
    my ($self, $repo_path, $artFilename, $destination) = @_;

    my $url = URI->new($self->config->{instance});
    my $new_path = $url->path .  "/$repo_path/$artFilename";
    $new_path =~ s{/+}{/}g;
    $url->path($new_path);

    $self->logger->info("Artifact URL: $url");

    if ($self->{proxy}) {
        $self->{proxy}->apply();
    }

    my $client = LWP::UserAgent->new;

    if ($self->{proxy}) {
        $client = $self->{proxy}->augment_lwp($client);
    }

    my $request = HTTP::Request->new(GET => $url);

    if ($self->{proxy}) {
        $request = $self->{proxy}->augment_request($request);
    }

    if ($self->config->{userName} && $self->config->{password}) {
        $request->authorization_basic(
            encode('utf8', $self->config->{userName}),
            encode('utf8', $self->config->{password})
        );
    }
    $self->logger->info("Downloading $url into " . ($destination ? $destination : 'the job workspace'));

    my $fh;
    my $filename;
    my $filepath;
    my $callback = sub {
        my ($chunk, $res) = @_;

        eval {
            unless($fh && $filename) {
                $filename = $artFilename;
                # In case non-ascii symbols are met
                $filename = uri_unescape($filename);
                $filename = decode('utf8', $filename);
                unless($filename) {
                  $self->bail_out('Cannot download artifact: ' . $res->content);
                }
                $filepath = $destination ? File::Spec->catfile($destination, $filename) : $filename;
                if (!$self->params->{overwrite} && -e $filepath) {
                    $self->bail_out(qq{Cannot overwrite "$filepath": file exists and the "overwrite" flag is not set});
                }

                $self->logger->debug("File path is $filepath");

                my $opened = open $fh, ">$filepath";
                unless($opened) {
                    $self->bail_out("Cannot open file $filepath: $!");
                }
                binmode $fh;
            }
            print $fh $chunk;
            1;
        } or do {
            $self->bail_out("Download failed: $@");
        };
    };
    my $response = $client->request($request, $callback);

    if ($fh) {
        close $fh;
    }
    $self->{filename} = $filename;
    $self->logger->trace($response->as_string);
    unless($response->is_success) {
        $self->logger->trace($response);
        $self->bail_out("Cannot download artifact: " . $response->content);
    }

    $self->log_summary(qq{Artifact "$filename" has been downloaded into } . ($destination ? $destination : 'current job workspace'));

    $self->retrieved_artifact->{url} = $url;
    $self->retrieved_artifact->{filename} = $filename;
    $self->retrieved_artifact->{fullFilename} = File::Spec->rel2abs($filename);
    return $filepath;
}

sub config {
    my ($self, $name) = @_;

    $name ||= $self->params->{config};
    unless($self->{configs}->{$name}) {
        $self->{configs}->{$name} = $self->get_config_values($self->{plugin_name}, $name);
    }
    return $self->{configs}->{$name};
}


sub log_summary {
    my ($self, $message) = @_;

    my $current_summary = eval { $self->ec->getProperty('/myJobStep/summary')->findvalue('//value')->string_value } || '';
    $current_summary .= $current_summary ? "\n$message" : $message;
    $self->ec->setProperty('/myJobStep/summary', $current_summary);
}


sub validate_param_exists {
    my ($self, $param_name) = @_;

    my $param_value = $self->params->{$param_name};
    unless(defined $param_value) {
        $self->bail_out(qq{Required parameter "$param_name" is missing});
    }
}

sub get_instance_uri {
    my ($self) = @_;

    my $uri = URI->new($self->config->{instance});
    return $uri;
}

sub get_webapp_uri {
    my ($self) = @_;

    my $uri = URI->new($self->config->{instance} . '/webapp');
    return $uri;

}

sub show_link {
    my ($self, $link_name, $link) = @_;

    $self->set_pipeline_summary($link_name, qq{<html><a target="_blank" href="$link">$link_name</a></html>});
    $self->ec->setProperty("/myJob/report-urls/$link_name", $link);
}


sub get_return_link {
    my ($self) = @_;

    my $servername = $ENV{COMMANDER_SERVER} || '';
    my $secure = $ENV{COMMANDER_SECURE};
    my $path = '';

    if ($self->in_pipeline) {
        my $pipeline_id = $self->ec->getProperty('/myPipeline/id')->findvalue('//value')->string_value;
        my $pipeline_runtime_id = $self->ec->getProperty('/myPipelineRuntime/id')->findvalue('//value')->string_value;
        if ($pipeline_id && $pipeline_runtime_id) {
            $path .= "flow/?#pipeline-run/$pipeline_id/$pipeline_runtime_id";
        }
    }
    else {
        my $job_id = $ENV{COMMANDER_JOBID} || '';
        $path .= "commander/link/jobDetails/jobs/$job_id";
    }
    my $scheme = $secure ? 'https' : 'http';
    my $uri = URI->new("$scheme://$servername/$path");
    $self->logger->debug("Return link is $uri");
    return $uri->as_string;
}

sub check_repo_exists {
    my ($self, $repo_name) = @_;

    my $repos = $self->client->repositories;
    my $exists = grep { $_->{key} eq $repo_name} @$repos;
    return $exists;
}

1;
