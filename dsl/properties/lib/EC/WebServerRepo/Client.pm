package EC::WebServerRepo::Client;

use strict;
use warnings;
use LWP::UserAgent;
use JSON;
use Encode qw(encode);
use Data::Dumper;

sub new {
    my ($class, %params) = @_;

    my $self = {
        url => $params{url},
        username => $params{userName},
        password => $params{password},
        logger => $params{logger},
        proxy_dispatcher => $params{proxy_dispatcher}
    };

    $self->{proxy} = $self->{proxy_dispatcher}->proxy();

    return bless $self, $class;
}

sub logger { shift->{logger} }

# pro version
sub latest_version {
    my ($self, %params) = @_;

    return $self->_request('GET', 'api/search/latestVersion', \%params);
}

sub quick_search {
    my ($self, %params) = @_;

    return $self->_request('GET', 'api/search/artifact', \%params);
}

sub gavc {
    my ($self, %params) = @_;

    return $self->_request('GET', 'api/search/gavc', \%params);
}

sub properties {
    my ($self, $path) = @_;
    return $self->_request('GET', "api/storage/$path?properties");
}

sub artifact_data {
    my ($self, $path) = @_;

    return $self->_request('GET', "api/storage/$path");
}

sub download {
    my ($self, $path) = @_;
    return $self->_request('GET', $path);
}

sub _request {
    my ($self, $method, $url, $query, $payload, %params) = @_;

    my $uri = $self->{url} . "/$url";
    $uri = URI->new($uri);
    $uri->query_form(%$query);

    if ($self->{proxy}) {
        $self->{proxy}->apply();
    }

    my $request = HTTP::Request->new($method => $uri);

    if ($self->{proxy}) {
        $request = $self->{proxy}->augment_request($request);
    }

    if ($payload) {
        $request->content($payload);
    }
    $request->header('Content-Type' => 'application/json');
    if ($self->{username} && $self->{password}) {
        $request->authorization_basic(
            encode('utf8', $self->{username}),
            encode('utf8', $self->{password})
        );
    }
    if ($params{headers}) {
        for my $name (keys %{$params{headers}}) {
            $request->header($name => $params{headers}->{$name});
        }
    }
    my $ua = LWP::UserAgent->new;

    if ($self->{proxy}) {
        $ua = $self->{proxy}->augment_lwp($ua);
    }

    $self->logger->trace($request->as_string);
    my $response = $ua->request($request);

    $self->logger->trace($response->as_string);

    if ($response->is_success) {
        my $content_type = $response->header('Content-Type');
        if ($content_type =~ /json/) {
            return decode_json($response->content);
        }
        else {
            return $response->content;
        }
    }
    else {
        die sprintf 'Request failed: %d, %s', $response->code, $response->content;
    }
}

sub deploy {
    my ($self, $path, $path_to_file) = @_;

    open my $fh, $path_to_file or die "Cannot open $path_to_file: $!";
    my $response = $self->_request('PUT', $path, {}, sub {
        my $buffer;
        my $bytes_read = read($fh, $buffer, 1024);
        return $buffer;

    });

    if ($fh) {
        close $fh;
    }
    return $response;
}


sub deploy_with_checksum {
    my ($self, $path, $path_to_file, $sha1_checksum, $sha256_checksum) = @_;

    my $headers = {'X-Checksum-Deploy' => 'true'};
    if ($sha1_checksum) {
        $headers->{'X-Checksum-Sha1'} = $sha1_checksum;
    }
    if ($sha256_checksum) {
        $headers->{'X-Checksum-Sha256'} = $sha256_checksum;
    }
    open my $fh, $path_to_file or die "Cannot open $path_to_file: $!";
    my $response = $self->_request('PUT', $path, {}, sub {
        my $buffer;
        my $bytes_read = read($fh, $buffer, 1024);
        return $buffer;

    }, headers => $headers);

    if ($fh) {
        close $fh;
    }
    return $response;

}


sub get_artifact_versions {
    my ( $self, $params ) = @_;

    my %request_params = ();

    for my $required (qw/orgPath artifact/) {
        die "Argument \"$required\" is mandatory.\n" unless $required
    }
    $request_params{g} = $params->{orgPath};
    $request_params{a} = $params->{artifact};

    # Optional parameter
    if ($params->{classifier}) {
        $request_params{c} = $params->{classifier};
    }
    if ($params->{repository}) {
        $request_params{repos} = $params->{repository};
    }

    my $response = $self->_request('GET', 'api/search/versions', \%request_params);
    if (! $response) {
        die "Failed to retrieve versions.\n";
    }
    elsif ($response->{errors}){
        die $response->{errors}->[0]->{message} . "\n";
    }

    my @results = @{$response->{results}};
    if (! @results) {
        die "No versions for given arguments.\n";
    }

    return [ sort (map {$_->{version}} @results) ];
}

1;
