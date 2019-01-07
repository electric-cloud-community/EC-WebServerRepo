package EC::WebServerRepo::Generic;

use strict;
use warnings;
use URI;
use Digest::SHA;
use File::Basename;
use JSON;
use URI::Escape;
use Archive::Tar;
use File::Spec;
use Archive::Zip;


sub new {
    my ($class, %param) = @_;

    my $self = {%param};
    return bless $self, $class;
}

sub logger { shift->{logger} }

sub params { shift->{params} }

sub config { shift->{config} }

sub plugin { shift->{plugin} }

sub client { shift->{client} }


sub get_layout {
    my ($self, $type) = @_;

    my $layouts = $self->config->{layouts} || '';
    my @lines = split(/\n+/, $layouts);
    my %parsed_layouts = map { my ($type, $layout) = split /\s*=\s*/ => $_ } grep { $_ }  @lines;

    my $layout = $parsed_layouts{lc $type};
    unless($layout) {
        $layout = $self->get_default_layout($type);
    }
    $self->logger->debug("Layout for $type is $layout");

    return $layout;
}

sub get_default_layout {
    my ($self, $type) = @_;

    $type = lc $type;
    my $layouts = {
        nuget => '[orgPath]/[module]/[module].[baseRev](-[fileItegRev]).nupkg',
        maven2 => '[orgPath]/[module]/[baseRev](-[folderItegRev])/[module]-[baseRev](-[fileItegRev])(-[classifier]).[ext]',
        npm => '[orgPath]/[module]/[module]-[baseRev](-[fileItegRev]).tgz',
        generic => '[orgPath]/[module]/[module]-[baseRev].[ext]',
        php => '[orgPath]/[module]/[module]-[baseRev](-[fileItegRev]).[ext]'
    };
    my $layout = $layouts->{$type};
    if ($layout) {
        return $layout;
    }
    else {
        die "No layout found for repository type: $type";
    }
}

sub get_artifact_path {
    my ($self) = @_;

    my $layout = $self->params->{repositoryLayout} || $self->get_layout($self->params->{repoType});
    if ($self->params->{useRepositoryLayout} && $self->params->{latestVersion}) {
        unless($layout) {
            $self->plugin->bail_out('No layout was defined for the generic repository');
        }
        my $version = $self->layout_based_latest_version;
        $self->plugin->retrieved_artifact->{version} = $version;
        return $self->get_general_artifact_url($layout, {version => $version});
    }
    elsif ($self->params->{useRepositoryLayout}) {
        return $self->get_general_artifact_url($layout);
    }
    else {
        $self->plugin->validate_param_exists('repositoryPath');
        my $repo_path = $self->params->{repositoryPath};
        return $repo_path;
    }
}

sub get_general_artifact_url {
    my ($self, $layout, $params_redefined) = @_;

    my $config = $self->config;
    $params_redefined ||= {};
    my $params = { %{$self->params}, %$params_redefined };

    my $url = $layout;
    my $replacer = sub {
        my ($string, $token, $value) = @_;

        $value ||= '';
        $string =~ s/\[$token\]/$value/g;
        return $string;
    };

    for my $part (qw/orgPath fileItegRev folderItegRev classifier org type/) {
        $url = $replacer->($url, $part, $params->{$part});
    }
    $url = $replacer->($url, 'module', $params->{artifact});
    $url = $replacer->($url, 'baseRev', $params->{version});
    $url = $replacer->($url, 'ext', $params->{extension});
    $url =~ s/\([.-]\)//g;

    die 'No instance found in config' unless $config->{instance};

    my $uri = URI->new($config->{instance});

    my $repo_path = $url;
    $repo_path =~ s/\/+/\//g;
    $repo_path =~ s/[()]//g;


    $uri->path($uri->path . '/' . $repo_path);

    $self->logger->debug("Generated URL: $uri, $repo_path");

    return $repo_path;
}


sub layout_based_latest_version {
    my ($self) = @_;

    my $params = $self->params;
    $self->plugin->validate_param_exists('artifact');
    my $org = $params->{org};
    my $org_path = $params->{orgPath};

    unless($org || $org_path) {
        $self->plugin->bail_out(qq{Either "org" or "orgPath" parameter should be specified for the latest version retrieval});
    }

    my $latest_version;
    $org ||= $org_path;
    eval {
        $latest_version = $self->client->latest_version(
            g => $org,
            a => $params->{artifact},
            repos => $params->{repository},
            v => '*',
        );
        1;
    } or do {
        if ($@ =~ /Unable to find artifact versions/) {
            $latest_version = $self->client->latest_version(
                g => $org,
                a => $params->{artifact},
                repos => $params->{repository}
            );
        }
        else {
            $self->plugin->bail_out("Cannot find latest version: $@");
        }
    };

    unless($latest_version) {
        $self->plugin->bail_out("Cannot find latest version for $params->{artifact}, group $org, repos $params->{repository}");
    }

    $self->logger->info("Latest version for $org:$params->{artifact} is $latest_version");
    return $latest_version;
}


sub publish {
    my ($self) = @_;

    if ($self->params->{useRepositoryLayout}) {
        my $layout = $self->params->{repositoryLayout} || $self->get_layout($self->params->{repoType});
        my $url = $self->get_general_artifact_url($layout);

        my $deploy_path = $self->params->{repository} . '/' . $url;
        $self->deploy_with_checksum($deploy_path, $self->params->{artifactPath});
    }
    else {
        my $deploy_path = $self->params->{repository};
        $self->plugin->validate_param_exists('repositoryPath');
        if ($self->params->{repositoryPath}) {
            $deploy_path .= '/' . $self->params->{repositoryPath};
        }
        $self->deploy_with_checksum($deploy_path, $self->params->{artifactPath});
    }
}

sub deploy_with_checksum {
    my ($self, $path, $filepath) = @_;

    my $sha1_checksum = $self->calculate_checksum_sha1($filepath);
    my $sha256_checksum = $self->calculate_checksum_sha256($filepath);

    my $deployed_artifact_data;
    eval {
        $deployed_artifact_data = $self->client->artifact_data($path);
        1;
    } or do {
        my $err = $@;
        if ($err =~ /Unable to find item/) {
            $deployed_artifact_data = {};
        }
        else {
            $self->plugin->bail_out("Cannot get deployed artifact data: $err");
        }
    };
    $self->logger->trace($deployed_artifact_data);

    my $old_sha1_checksum = $deployed_artifact_data->{checksums}->{sha1} || '';
    if ($old_sha1_checksum && $old_sha1_checksum ne $sha1_checksum) {
        $self->plugin->bail_out("The artifact is already deployed on path $path and checksums are differ: old $old_sha1_checksum, new $sha1_checksum");
    }

    my $properties = $self->parse_properties;
    for my $key (sort keys %$properties) {
        $self->logger->info("Property to set: $key, $properties->{$key}");
    }
    my @lines = map { "$_=$properties->{$_}"} keys %$properties;
    if (@lines) {
        $path .= ';' . join(';', @lines);
    }

    my $repository = $self->params->{repository};

    # Checksum search is not available in OSS version
    $self->client->deploy($path, $filepath);
    $self->client->deploy_with_checksum($path, $filepath, $sha1_checksum, $sha256_checksum);


    $self->plugin->published_artifact->{sha1_checksum} = $sha1_checksum;
    $self->plugin->published_artifact->{sha256_checksum} = $sha256_checksum;
    $path =~ s/;.+$//g;
    $self->plugin->published_artifact->{path} = $path;
}

sub calculate_checksum_sha1 {
    my ($self, $filepath) = @_;

    my $sha = Digest::SHA->new('SHA1');
    $sha->addfile($filepath);
    return $sha->hexdigest;
}

sub calculate_checksum_sha256 {
    my ($self, $filepath) = @_;

    my $sha = Digest::SHA->new('SHA256');
    $sha->addfile($filepath);
    return $sha->hexdigest;
}

sub parse_properties {
    my ($self) = @_;

    my $props = $self->params->{artifactProperties} || '';
    my $retval = {};
    eval {
        $retval = decode_json($props);
        1;
    } or do {
        my @lines = split(/\n+/, $props);
        for my $line (@lines) {
            my ($key, $value) = split(/\s*=\s*/, $line);
            $retval->{$key} = uri_escape($value);
        }
    };
    $retval->{'ElectricFlow.PublishedBy'} = uri_escape($self->plugin->get_return_link);
    return $retval;
}

sub extract {
    my ($self, $path, $overwrite) = @_;

    require Archive::Zip;
    my $zip = Archive::Zip->new;
    if ( $zip->read($path) == Archive::Zip::AZ_OK ) {
        return $self->extract_zip($path, $overwrite);
    }
    require Archive::Tar;
    my $tar = Archive::Tar->new($path);
    if ($tar) {
        $self->extract_tgz($path, $overwrite);
    }

    $self->plugin->bail_out("The archive is neither .zip nor .tar.gz, cannot extract it");
}

sub extract_zip {
    my ($self, $path, $overwrite) = @_;

    my $destination = $self->params->{destination};
    my $artifact = $self->params->{artifact};
    my $version = $self->plugin->retrieved_artifact->{version};
    require Archive::Zip;
    my $zip = Archive::Zip->new;
    unless ( $zip->read($path) == Archive::Zip::AZ_OK() ) {
        $self->plugin->bail_out("Cannot read zip archive: $path");
    }
    my @members = $zip->members;
    my $extraction_folder = "eflow-$artifact-$version";
    my $extraction_path = $destination ?
        File::Spec->catfile($destination, $extraction_folder)
        : $extraction_folder ;

    $zip->extractTree('', $extraction_path . '/');
    my @filenames = map { $_->fileName } @members;

    $self->logger->info('Files extracted: ',
        map { "  - $_" . '(' . File::Spec->rel2abs($_, $destination) . ')'
     }
    sort @filenames);
    $self->plugin->retrieved_artifact->{extractionPath} = $extraction_path;
    $self->plugin->retrieved_artifact->{fullExtractionPath} = File::Spec->rel2abs($extraction_path);
}


sub extract_tgz {
    my ($self, $path, $overwrite, %params) = @_;

    my $destination = $self->params->{destination};
    my $artifact = $self->params->{artifact};
    my $version = $self->plugin->retrieved_artifact->{version};

    require Archive::Tar;
    my $tar = Archive::Tar->new($path);
    unless($tar) {
        $self->plugin->bail_out("Archive is not .tar.gz, cannot extract it");
    }
    my $extraction_folder = "eflow-$artifact-$version";
    my $extraction_path = $destination ?
        File::Spec->catfile($destination, $extraction_folder)
        : $extraction_folder;
    $tar->setcwd($extraction_path);
    my @files = $tar->list_files;

    @files = $tar->extract;

    unless(@files) {
        $self->plugin->bail_out("Extraction failed: " . $tar->error);
    }
    $self->logger->info('Files extracted: ',
        map { "  - " . $_->name . ' (' . File::Spec->rel2abs($_->name, $destination) . ')' }
    sort @files);
    $self->plugin->retrieved_artifact->{extractionPath} = $extraction_path;
    $self->plugin->retrieved_artifact->{fullExtractionPath} = File::Spec->rel2abs($extraction_path);
}


1;
