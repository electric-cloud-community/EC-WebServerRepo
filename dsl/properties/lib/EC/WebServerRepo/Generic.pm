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
