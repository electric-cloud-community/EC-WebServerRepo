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
    $request->ssl_opts('verify_hostnames' => 0 ,'SSL_verify_mode' => 0x00);
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
    $ua->ssl_opts(verify_hostname => 0, SSL_verify_mode => 0x00);

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


1;
