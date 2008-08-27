package RequestTests;

use base qw(Unit::TestCase);
use strict;
use warnings;

use TWiki::Request;
use TWiki::Request::Upload;

# Test default empty constructor
sub test_empty_new {
    my $this = shift;
    my $req = new TWiki::Request("");

    $this->assert_str_equals('', $req->action, '$req->action() not empty');
    $this->assert_str_equals('', $req->pathInfo, '$req->pathInfo() not empty');
    $this->assert_str_equals('', $req->remoteAddress, '$req->remoteAddress() not empty');
    $this->assert_str_equals('', $req->uri, '$req->uri() not empty');
    $this->assert_null($req->method, '$req->method() not null');
    $this->assert_null($req->remoteUser, '$req->remoteUser() not null');
    $this->assert_null($req->serverPort, '$req->serverPort() not null');

    my @list = $req->header();
    $this->assert_str_equals(0, scalar @list, '$req->header not empty');
    
    @list = $req->param();
    $this->assert_str_equals(0, scalar @list, '$req->param not empty');

    my $ref = $req->cookies();
    $this->assert_str_equals('HASH', ref($ref), '$req->cookies did not returned a hashref');
    $this->assert_str_equals(0, scalar keys %$ref, '$req->cookies not empty');
    
    $ref = $req->uploads();
    $this->assert_str_equals('HASH', ref($ref), '$req->uploads did not returned a hashref');
    $this->assert_str_equals(0, scalar keys %$ref, '$req->uploads not empty');
}

sub test_new_from_hash {
    my $this = shift;
    my %init = (
        simple      => 's1',
        simple2     => ['s2'],
        multi       => [qw(m1 m2)],
        'undef'     => undef,
        multi_undef => [],
    );
    my $req = new TWiki::Request(\%init);
    $this->assert_str_equals(5, scalar $req->param(), 'Wrong number of parameteres');
    $this->assert_str_equals('s1', $req->param('simple'), 'Wrong parameter value');
    $this->assert_str_equals('s2', $req->param('simple2'), 'Wrong parameter value');
    $this->assert_str_equals('m1', scalar $req->param('multi'), 'Wrong parameter value');
    my @values = $req->param('multi');
    $this->assert_str_equals(2, scalar @values, 'Wrong number of values');
    $this->assert_str_equals('m1', $values[0], 'Wrong parameter value');
    $this->assert_str_equals('m2', $values[1], 'Wrong parameter value');
    $this->assert_null($req->param('undef'), 'Wrong parameter value');
    @values = $req->param('multi_undef');
    $this->assert_str_equals(0, scalar @values, 'Wrong parameter value');
}

sub test_new_from_file {
    my $this = shift;
    require File::Temp;
    my $tmp = File::Temp->new(UNLINK => 1);
    print($tmp <<EOF
simple=s1
simple2=s2
multi=m1
multi=m2
undef=
=
EOF
);
    seek($tmp, 0, 0);
    my $req = new TWiki::Request($tmp);
    $this->assert_str_equals(4, scalar $req->param(), 'Wrong number of parameters');
    $this->assert_str_equals('s1', $req->param('simple'), 'Wrong parameter value');
    $this->assert_str_equals('s2', $req->param('simple2'), 'Wrong parameter value');
    my @values = $req->param('multi');
    $this->assert_str_equals(2, scalar @values, 'Wrong number o values');
    $this->assert_str_equals('m1', $values[0], 'Wrong parameter value');
    $this->assert_str_equals('m2', $values[1], 'Wrong parameter value');
    $this->assert_null($req->param('undef'), 'Wrong parameter value');
}

sub test_action {
    my $this = shift;
    my $req = new TWiki::Request("");
    foreach (qw(view edit save upload preview rdiff)) {
        $this->assert_str_not_equals($_, $req->action, 'Wrong initial "action" value');
        $req->action($_);
        $this->assert_str_equals($_, $req->action, 'Wrong action value');
        $this->assert_str_equals($_, $ENV{TWIKI_ACTION}, 'Wrong TWIKI_ACTION environment');
    }
}

sub test_method {
    my $this = shift;
    my $req = new TWiki::Request("");
    foreach (qw(GET HEAD POST)) {
        $this->assert_str_not_equals($_, $req->method || '', 'Wrong initial "method" value');
        $req->method($_);
        $this->assert_str_equals($_, $req->method, 'Wrong method value');
    }
}

sub test_pathInfo {
    my $this = shift;
    my $req = new TWiki::Request("");
    foreach (qw(/ /abc /abc/ /abc/def /abc/def/), '') {
        $this->assert_str_not_equals($_, $req->pathInfo, 'Wrong initial "pathInfo" value');
        $req->pathInfo($_);
        $this->assert_str_equals($_, $req->pathInfo, 'Wrong pathInfo value');
    }
}

sub test_protocol {
    my $this = shift;
    my $req = new TWiki::Request("");
    $req->secure(0);
    $this->assert_str_equals('http', $req->protocol, 'Wrong protocol');
    $this->assert_num_equals(0, $req->secure, 'Wrong secure flag');
    $req->secure(1);
    $this->assert_str_equals('https', $req->protocol, 'Wrong protocol');
    $this->assert_num_equals(1, $req->secure, 'Wrong secure flag');
}

sub test_uri {
    my $this = shift;
    my $req = new TWiki::Request("");
    foreach (qw(/ /abc/def /abc/ /Web/Topic?a=b&b=c), '') {
        $this->assert_str_not_equals($_, $req->uri, 'Wrong initial "uri" value');
        $req->uri($_);
        $this->assert_str_equals($_, $req->uri, 'Wrong uri value');
    }
}

sub test_remoteAddress {
    my $this = shift;
    my $req = new TWiki::Request("");
    foreach (qw(127.0.0.1 10.1.1.1 192.168.0.1)) {
        $req->remoteAddress($_);
        $this->assert_str_equals($_, $req->remoteAddress, 'Wrong remoteAddress value');
    }
}

sub test_remoteUser {
    my $this = shift;
    my $req = new TWiki::Request("");
    foreach (qw(TWikiGuest guest foo bar Baz)) {
        $req->remoteUser($_);
        $this->assert_str_equals($_, $req->remoteUser, 'Wrong remoteUser value');
    }
}

sub test_serverPort {
    my $this = shift;
    my $req = new TWiki::Request("");
    foreach (qw(80 443 8080)) {
        $req->serverPort($_);
        $this->assert_num_equals($_, $req->serverPort, 'Wrong serverPort value');
    }
}

sub test_queryString_x {
# Verify CGI.pm behavior:
# - Query & body_param (only one, only the other, both)
# refer to new_from_file
}

sub test_url_full {
}

sub test_url_absolute {
}

sub test_url_relative {
}

sub test_url_with_path {
}

sub test_url_with_queryString {
}

sub test_queryParam_x {
}

sub test_bodyParam_x {
}

sub test_param_x {
}

sub test_cookie_x {
}

sub test_cookies {
}

sub test_delete {
}

sub test_delete_all {
}

sub test_header_x {
}

sub test_save_x {
}

sub test_load_x {
}

sub test_upload_x {
}

sub test_uploadInfo {
}

sub test_tmpFileName {
}

sub test_uploads {
}

sub test_accessors {
}

# Test CGI.pm interface compatibility
sub test_cgi_compat {
    my $this = shift;
# - Verify methods availability:
#   - Aliases
#   - http()
#   - https()
}

1;
