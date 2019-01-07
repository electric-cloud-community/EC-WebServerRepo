package EC::ProxyDispatcher;

use strict;
use warnings;
use Data::Dumper;
use ElectricCommander;
use ElectricCommander::PropDB;
use EC::ProxyDriver;

our $VERSION = 0.01;

sub new {
    my ($class, $ec, $config_name, $params) = @_;

    my $self = {
        ec => $ec,
        config_name => $config_name
    };

    bless $self, $class;

    $self->load_configuration($params);

    return $self;
}


sub load_configuration {
    my ($self, $params) = @_;

    my $cfg = new ElectricCommander::PropDB($self->{ec}, "/myProject/ec_plugin_cfgs");
    eval {
        $self->{http_proxy} = $cfg->getCol($self->{config_name}, 'http_proxy');
        if (defined $self->{http_proxy} && $self->{http_proxy} ne '') {
            my $proxy_xpath = $self->{ec}->getFullCredential($self->{config_name} . "_proxy_credential");

            if($proxy_xpath) {
                $self->{proxy_username} = $proxy_xpath->findvalue("//userName");
                $self->{proxy_password} = $proxy_xpath->findvalue("//password");
            }
        }
        1;
    } or do {
        print "No proxy settings found.\n";
    };
}

sub proxy {
    my ($self) = @_;

    if (!$self->is_proxy_defined()) {
        return undef;
    }

    if ($self->{proxy}) {
        return $self->{proxy};
    }

    $self->{proxy} = EC::ProxyDriver->new({
        url => $self->{http_proxy},
        username => $self->{proxy_username},
        password => $self->{proxy_password},
        debug => 1
    });

    return $self->{proxy};
}


sub is_proxy_defined {
    my ($self) = @_;

    if (defined $self->{http_proxy} && $self->{http_proxy} ne '') {
        return 1;
    }
    return 0;
}

1;
