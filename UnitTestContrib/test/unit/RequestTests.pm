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

# Test CGI.pm interface compatibility
sub test_cgi_compat {
    my $this = shift;
}

1;
