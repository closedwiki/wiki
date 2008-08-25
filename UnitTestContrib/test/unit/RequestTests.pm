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

    $this->assert_equals($req->action, '', '$req->action() not empty');
    $this->assert_equals($req->pathInfo, '', '$req->pathInfo() not empty');
    $this->assert_equals($req->remoteAddress, '', '$req->remoteAddress() not empty');
    $this->assert_equals($req->uri, '', '$req->uri() not empty');
    $this->assert_null($req->method, '$req->method() not null');
    $this->assert_null($req->remoteUser, '$req->remoteUser() not null');
    $this->assert_null($req->serverPort, '$req->serverPort() not null');

    my @list = $req->header();
    $this->assert_equals(scalar @list, 0, '$req->header not empty');
    
    @list = $req->param();
    $this->assert_equals(scalar @list, 0, '$req->param not empty');

    my $ref = $req->cookies();
    $this->assert_equals(ref($ref), 'HASH', '$req->cookies did not returned a hashref');
    $this->assert_equals(scalar keys %$ref, 0, '$req->cookies not empty');
    
    $ref = $req->uploads();
    $this->assert_equals(ref($ref), 'HASH', '$req->uploads did not returned a hashref');
    $this->assert_equals(scalar keys %$ref, 0, '$req->uploads not empty');
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
    $this->assert_equals(scalar $req->param(), 5, 'Wrong number of parameteres');
    $this->assert_equals($req->param('simple'), 's1', 'Wrong parameter value');
    $this->assert_equals($req->param('simple2'), 's2', 'Wrong parameter value');
    $this->assert_equals(scalar $req->param('multi'), 'm1', 'Wrong parameter value');
    my @values = $req->param('multi');
    $this->assert_equals(scalar @values, 2, 'Wrong number of values');
    $this->assert_equals($values[0], 'm1', 'Wrong parameter value');
    $this->assert_equals($values[1], 'm2', 'Wrong parameter value');
    $this->assert_equals($req->param('undef'), undef, 'Wrong parameter value');
    @values = $req->param('multi_undef');
    $this->assert_equals(scalar @values, 0, 'Wrong parameter value');
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
    $this->assert_equals(scalar $req->param(), 4, 'Wrong number of parameters');
    $this->assert_equals($req->param('simple'), 's1', 'Wrong parameter value');
    $this->assert_equals($req->param('simple2'), 's2', 'Wrong parameter value');
    my @values = $req->param('multi');
    $this->assert_equals(scalar @values, 2, 'Wrong number o values');
    $this->assert_equals($values[0], 'm1', 'Wrong parameter value');
    $this->assert_equals($values[1], 'm2', 'Wrong parameter value');
    $this->assert_equals($req->param('undef'), undef, 'Wrong parameter value');
}

sub test_get_action {
}

sub test_set_action {
}

sub test_get_method {
}

sub test_set_method {
}

sub test_get_pathInfo {
}

sub test_set_pathInfo {
}

sub test_get_uri {
}

sub test_set_uri {
}

sub test_get_secure {
}

sub test_set_secure {
}

sub test_get_remoteAddress {
}

sub test_set_remoteAddress {
}

sub test_get_remoteUser {
}

sub test_set_remoteUser {
}

sub test_get_serverPort {
}

sub test_set_serverPort {
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

sub test_get_cookies {
}

sub test_set_cookies {
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

sub test_get_uploads {
}

sub test_set_uploads {
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
