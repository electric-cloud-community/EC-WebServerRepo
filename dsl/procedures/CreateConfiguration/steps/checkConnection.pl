#
#  Copyright 2018 Electric Cloud, Inc.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#

#########################
## checkConnection.pl
#########################
$[/myProject/scripts/preamble]

use ElectricCommander;
use ElectricCommander::PropDB;
use EC::ProxyDriver;
use LWP::UserAgent;
use HTTP::Request;
use Data::Dumper;
use Encode qw(encode);

my $ec = new ElectricCommander();
$ec->abortOnError(0);

my $url = $ec->getProperty('instance')->findvalue('//value')->string_value;
my $xpath = $ec->getFullCredential('credential');
my $clientID = $xpath->findvalue("//userName")->string_value;
my $clientSecret = $xpath->findvalue("//password")->string_value;

print "Instance: $url\n";
if ($clientID) {
    print "ID: $clientID\n";
}
else {
    print "Anonymous access\n";
}

# Init proxy if defined
my $proxy = undef;

my ($proxy_user, $proxy_pass, $http_proxy);
eval {
    my $http_proxy = '$[http_proxy]';
    if ($http_proxy) {
        $ENV{HTTP_PROXY} = $http_proxy;
        $ENV{HTTPS_PROXY} = $http_proxy;
        $ENV{FTP_PROXY} = $http_proxy;
    }
    else {
        return;
    }

    my $proxy_xpath = $ec->getFullCredential("proxy_credential");
    my $proxy_user = $proxy_xpath->findvalue("//userName");
    my $proxy_pass = $proxy_xpath->findvalue("//password");
    if ($proxy_user) {
        $ENV{HTTPS_PROXY_USERNAME} = $proxy_user;
    }
    if ($proxy_pass) {
        $ENV{HTTPS_PROXY_PASSWORD} = $proxy_pass;
    }

    $proxy = EC::ProxyDriver->new({
        url => $http_proxy,
        username => $proxy_user,
        password => $proxy_pass,
        debug => 1
    });
};

if ($proxy) {
    $proxy->apply();
}

my $ua = LWP::UserAgent->new;

if ($proxy) {
    $ua = $proxy->augment_lwp($ua);
}

my $uri = URI->new($url);
$uri->path_segments($uri->path_segments, 'api', 'repositories');

print "$uri\n";


my $request = HTTP::Request->new(GET => $uri);

if ($proxy) {
    $request = $proxy->augment_request($request);
}

if ($clientID) {
    $request->authorization_basic(encode('utf8', $clientID), encode('utf8', $clientSecret));
}
my $response = $ua->request($request);
if ($response->is_success) {
    exit 0;
}
else {
    my $code = $response->code;
    my $status_line = $response->status_line;
    print "$status_line\n";
    print $response->as_string;
    $ec->setProperty('/myJob/configError', "GET $uri: $status_line");
    exit 1;
}
