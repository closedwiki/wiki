package RequestTests;

use base qw(Unit::TestCase);
use strict;
use warnings;

use TWiki::Request;
use TWiki::Request::Upload;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    $TWiki::cfg{ScriptUrlPath} = '/twiki/bin';
    delete $TWiki::cfg{ScriptUrlPaths};
}

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
    
    @list = ();
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

sub test_queryString {
    my $this = shift;
    my $req  = new TWiki::Request("");
    $req->param( -name => 'simple1', -value => 's1' );
    $this->assert_equals( 'simple1=s1', $req->query_string,
        'Wrong query string' );
    $req->param( -name => 'simple2', -value => 's2' );
    $this->assert_matches( 'simple1=s1[;&]simple2=s2', $req->query_string,
        'Wrong query string' );
    $req->param( -name => 'multi', -value => [qw(m1 m2)] );
    $this->assert_matches( 'simple1=s1[;&]simple2=s2[;&]multi=m1[;&]multi=m2',
        $req->query_string, 'Wrong query string' );
}

sub perform_url_test {
    my $this = shift;
    my $req  = new TWiki::Request("");
    my ( $secure, $host, $action, $path ) = @_;
    $req->secure($secure);
    $req->header( Host => $host );
    $req->action($action);
    $req->path_info($path);
    $req->param( -name => 'simple1', -value => 's1 s1' );
    $req->param( -name => 'simple2', -value => 's2' );
    $req->param( -name => 'multi',   -value => [qw(m1 m2)] );
    my $base = $secure ? 'https' : 'http';
    $base .= '://' . $host;
    $this->assert_str_equals( $base, $req->url( -base => 1 ),
        'Wrong BASE url' );
    my $absolute .= $TWiki::cfg{ScriptUrlPath} . "/$action";
    $this->assert_str_equals( $base . $absolute, $req->url, 'Wrong FULL url' );
    $this->assert_str_equals( $absolute,
        $req->url( -absolute => 1, 'Wrong ABSOLUTE url' ) );
    $this->assert_str_equals( $action,
        $req->url( -relative => 1, 'Wrong RELATIVE url' ) );

    $this->assert_str_equals(
        $base . $absolute . $path,
        $req->url( -full => 1, -path => 1 ),
        'Wrong FULL+PATH url'
    );
    $this->assert_str_equals(
        $absolute . $path,
        $req->url( -absolute => 1, -path => 1 ),
        'Wrong ABSOLUTE+PATH url'
    );
    $this->assert_str_equals(
        $action . $path,
        $req->url( -relative => 1, -path => 1 ),
        'Wrong RELATIVE+PATH url'
    );

    my $query = '\?simple1=s1%20s1[&;]simple2=s2[;&]multi=m1[;&]multi=m2';
    $base =~ s/\./\\./g;
    $this->assert_matches(
        $base . $absolute . $query,
        $req->url( -full => 1, -query => 1 ),
        'Wrong FULL+QUERY_STRING url'
    );
    $this->assert_matches(
        $absolute . $query,
        $req->url( -absolute => 1, -query => 1 ),
        'Wrong ABSOLUTE+QUERY_STRING url'
    );
    $this->assert_matches(
        $action . $query,
        $req->url( -relative => 1, -query => 1 ),
        'Wrong RELATIVE+QUERY_STRING url'
    );

    $this->assert_matches(
        $base . $absolute . $query,
        $req->url( -full => 1, -query => 1, -path => 1 ),
        'Wrong FULL+PATH_INFO+QUERY_STRING url'
    );
    $this->assert_matches(
        $absolute . $query,
        $req->url( -absolute => 1, -query => 1, -path => 1 ),
        'Wrong ABSOLUTE+PATH_INFO+QUERY_STRING url'
    );
    $this->assert_matches(
        $action . $query,
        $req->url( -relative => 1, -query => 1, -path => 1 ),
        'Wrong RELATIVE+PATH_INFO+QUERY_STRING url'
    );
}

sub test_url {
    my $this = shift;
    $this->perform_url_test(0, 'foo.bar',  'baz', '/Web/Topic');
    $this->perform_url_test(1, 'foo.bar',  'baz', '/Web/Topic');
    $this->perform_url_test(0, 'example.com', 'view', '/Main/WebHome');
    $this->perform_url_test(1, 'example.com', 'edit', '/Sandbox/TestTopic');
}

sub test_query_param {
    my $this = shift;
    my $req  = new TWiki::Request("");
    
    $req->queryParam( -name => 'q1', -value => 'v1' );
    my @result = $req->param('q1');
    $this->assert_str_equals( 'v1', $result[0],
        'wrong value from queryParam()' );
    $this->assert_num_equals(
        1,
        scalar @result,
        'wrong number of returned values from queryParam()'
    );
    $req->queryParam( -name => 'q2', -values => [qw(v1 v2)] );
    
    @result = ();
    @result = $req->param('q2');
    $this->assert_str_equals( 'v1', $result[0],
        'wrong value from queryParam()' );
    $this->assert_str_equals( 'v2', $result[1],
        'wrong value from queryParam()' );
    $this->assert_num_equals(
        2,
        scalar @result,
        'wrong number of returned values from queryParam()'
    );
    $req->queryParam('p', qw(qv1 qv2 qv3));
    
    @result = ();
    @result =  $req->param('p');
    $this->assert_str_equals( 'qv1', $result[0],
        'wrong value from queryParam()' );
    $this->assert_str_equals( 'qv2', $result[1],
        'wrong value from queryParam()' );
    $this->assert_str_equals( 'qv3', $result[2],
        'wrong value from queryParam()' );
    $this->assert_num_equals(
        3,
        scalar @result,
        'wrong number of returned values from queryParam()'
    );
    
    @result = ();
    @result = $req->queryParam();
    $this->assert_str_equals( 'q1', $result[0],
        'wrong parameter name from queryParam()' );
    $this->assert_str_equals( 'q2', $result[1],
        'wrong parameter name from queryParam()' );
    $this->assert_str_equals( 'p',  $result[2],
        'wrong parameter name from queryParam()' );
    $this->assert_num_equals(
        3,
        scalar @result,
        'wrong number of returned values from queryParam()'
    );
    
    @result = ();
    @result = (scalar $req->param('q2'));
    $this->assert_str_equals( 'v1', $result[0],
        'wrong parameter name from queryParam()' );
    $this->assert_num_equals(
        1,
        scalar @result,
        'wrong number of returned values from queryParam()'
    );

    @result = ();
    @result = (scalar $req->queryParam('nonexistent'));
    $this->assert_str_equals(1, scalar @result, '$req->param(nonexistent) not empty');
    $this->assert_null($result[0], q{$req->param(nonexistent) didn't return undef});
    
    @result = ();
    @result = $req->queryParam('nonexistent');
    $this->assert_str_equals(0, scalar @result, '$req->param(nonexistent) not empty');
}

sub test_body_param {
    my $this = shift;
    my $req  = new TWiki::Request("");
    $req->bodyParam( -name => 'q1', -value => 'v1' );
    my @result = $req->param('q1');
    $this->assert_str_equals( 'v1', $result[0],
        'wrong value from bodyParam()' );
    $this->assert_num_equals(
        1,
        scalar @result,
        'wrong number of returned values from bodyParam()'
    );
    $req->bodyParam( -name => 'q2', -values => [qw(v1 v2)] );
    @result = ();
    @result = $req->param('q2');
    $this->assert_str_equals( 'v1', $result[0],
        'wrong value from bodyParam()' );
    $this->assert_str_equals( 'v2', $result[1],
        'wrong value from bodyParam()' );
    $this->assert_num_equals(
        2,
        scalar @result,
        'wrong number of returned values from bodyParam()'
    );
    $req->bodyParam('p', qw(qv1 qv2 qv3));
    @result = ();
    @result =  $req->param('p');
    $this->assert_str_equals( 'qv1', $result[0],
        'wrong value from bodyParam()' );
    $this->assert_str_equals( 'qv2', $result[1],
        'wrong value from bodyParam()' );
    $this->assert_str_equals( 'qv3', $result[2],
        'wrong value from bodyParam()' );
    $this->assert_num_equals(
        3,
        scalar @result,
        'wrong number of returned values from bodyParam()'
    );
    @result = ();
    @result = $req->bodyParam();
    $this->assert_str_equals( 'q1', $result[0],
        'wrong parameter name from bodyParam()' );
    $this->assert_str_equals( 'q2', $result[1],
        'wrong parameter name from bodyParam()' );
    $this->assert_str_equals( 'p',  $result[2],
        'wrong parameter name from bodyParam()' );
    $this->assert_num_equals(
        3,
        scalar @result,
        'wrong number of returned values from bodyParam()'
    );
    @result = ();
    @result = (scalar $req->param('q2'));
    $this->assert_str_equals( 'v1', $result[0],
        'wrong parameter name from bodyParam()' );
    $this->assert_num_equals(
        1,
        scalar @result,
        'wrong number of returned values from bodyParam()'
    );
    
    @result = ();
    @result = (scalar $req->bodyParam('nonexistent'));
    $this->assert_str_equals(1, scalar @result, '$req->param(nonexistent) not empty');
    $this->assert_null($result[0], q{$req->param(nonexistent) didn't return undef});
    
    @result = ();
    @result = $req->bodyParam('nonexistent');
    $this->assert_str_equals(0, scalar @result, '$req->param(nonexistent) not empty');
}

sub test_query_body_param {
    my $this = shift;
    my $req  = new TWiki::Request("");
    $req->queryParam( -name => 'p', -values => [qw(qv1 qv2)] );
    $req->bodyParam(  -name => 'p', -values => [qw(bv1 bv2)] );
    my @result = $req->param('p');
    $this->assert_num_equals(
        4,
        scalar @result,
        'wrong number of returned values from bodyParam()+queryParam()'
    );
    $this->assert_str_equals( 'bv1', $result[0],
        'wrong value on bodyParam()+queryparam()' );
    $this->assert_str_equals( 'bv2', $result[1],
        'wrong value on bodyParam()+queryparam()' );
    $this->assert_str_equals( 'qv1', $result[2],
        'wrong value on bodyParam()+queryparam()' );
    $this->assert_str_equals( 'qv2', $result[3],
        'wrong value on bodyParam()+queryparam()' );
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
