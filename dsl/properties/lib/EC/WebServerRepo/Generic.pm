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
    my ($self) = @_;

    my $layout = $self->params->{layout} || '';
    unless($layout) {
        $layout = $self->get_default_layout;
    }
    $self->logger->debug("Layout is $layout");

    return $layout;
}

sub get_default_layout {
    return "[artifact]-[version].rpm";
}

sub get_artifact_path {
    my ($self) = @_;

    my $layout = $self->params->{layout} || $self->get_layout;
    return $self->get_general_artifact_url($layout);
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

    for my $part (qw/artifact version/) {
        $url = $replacer->($url, $part, $params->{$part});
    }
    $url =~ s/\([.-]\)//g;

    die 'No instance found in config' unless $config->{instance};

    my $uri = URI->new($config->{instance});

    my $repo_path = $url;
    $repo_path =~ s/\/+/\//g;
    $repo_path =~ s/[()]//g;

    my $filename=basename($repo_path);

    $uri->path($uri->path . '/' . $repo_path);

    $self->logger->debug("Generated URL: $uri, $repo_path");
    $self->logger->debug("Generated filename: $filename");

    return ($repo_path, $filename);
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
