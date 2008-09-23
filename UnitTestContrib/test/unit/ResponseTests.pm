package ResponseTests;

use base qw(Unit::TestCase);
use strict;
use warnings;

use TWiki::Response;

sub set_up {
    my $this = shift;
    $this->SUPER::set_up(@_);
    $TWiki::cfg{ScriptUrlPath} = '/twiki/bin';
    delete $TWiki::cfg{ScriptUrlPaths};
}

sub test_empty_new {
    my $this = shift;
    my $res = new TWiki::Response;

    $this->assert_null($res->status, 'Non-empty initial status');
    $this->assert_null($res->body,   'Non-empty initial body');
    $this->assert_matches('ISO-8859-1', $res->charset, 'Bad default initial charset');
    
    my @cookies = $res->cookies();
    $this->assert_str_equals(0, scalar @cookies, '$res->cookies not empty');

    my $ref = $res->headers;
    $this->assert_str_equals('HASH', ref($ref), '$res->headers did not return HASHREF');
    $this->assert_num_equals(0, (scalar keys %$ref), 'Non-empty initial headers');
}

sub test_status {
    my $this = shift;
    my $res = new TWiki::Response;

    my @status = (200, 302, 401, 402, '404 not found', 500);
    foreach (@status) {
        $res->status($_);
        $this->assert_str_equals($_, $res->status, 'Wrong return value from status()');
    }
    $res->status('ivalid status');
    $this->assert_null($res->status, 'It was possible to set an invalid status');
}

sub test_charset {
    my $this = shift;
    my $res = new TWiki::Response;

    foreach (qw(utf8 iso-8859-1 iso-8859-15 utf16)) {
        $res->charset($_);
        $this->assert_str_equals($_, $res->charset, 'Wrong charset value');
    }
}

sub test_headers {
    my $this = shift;
    my $res  = new TWiki::Response;

    my %hdr = (
        'CoNtEnT-tYpE' => 'text/plain; charset=utf8',
        'sTATUS'       => '200 OK',
        'Connection'   => 'Close',
        'f-o-o-bar'    => 'baz',
        'Set-COOKIe'   => [
            'TWIKISID=4ed0fb8647881e17852dff882f0cfaa7; path=/',
            'SID=8f3d9cb028e4f7dabe435bcfc4905cda; path=/'
        ],
    );
    $res->headers( \%hdr );
    $this->assert_deep_equals(
        [ sort qw(Content-Type Status Connection F-O-O-Bar Set-Cookie) ],
        [ sort $res->getHeader() ],
        'Wrong header field names'
    );
    $this->assert_str_equals(
        'Close',
        $res->getHeader('connection'),
        'Wrong header value'
    );
    $this->assert_str_equals(
        'text/plain; charset=utf8',
        $res->getHeader('CONTENT-TYPE'),
        'Wrong header value'
    );
    $this->assert_str_equals(
        '200 OK',
        $res->getHeader('Status'),
        'Wrong header value'
    );
    $this->assert_str_equals(
        'baz',
        $res->getHeader('F-o-o-bAR'),
        'Wrong header value'
    );
    my @cookies = $res->getHeader('Set-Cookie');
    $this->assert_deep_equals(
        [
            'TWIKISID=4ed0fb8647881e17852dff882f0cfaa7; path=/',
            'SID=8f3d9cb028e4f7dabe435bcfc4905cda; path=/'
        ],
        \@cookies,
        'Wrong multivalued header value'
    );

    $res->pushHeader( 'f-o-o-bar' => 'baz2' );
    $this->assert_deep_equals(
        [qw(baz baz2)],
        [ $res->getHeader('F-O-o-bAR') ],
        'pushHeader did not work'
    );

    $res->pushHeader( 'f-o-o-bar' => 'baz3' );
    $this->assert_deep_equals(
        [qw(baz baz2 baz3)],
        [ $res->getHeader('F-o-o-bar') ],
        'pushHeader did not work'
    );

    $res->pushHeader( 'pragma' => 'no-cache' );
    $this->assert_str_equals(
        'no-cache',
        $res->getHeader('PRAGMA'),
        'pushHeader did not work'
    );

    $res->deleteHeader(qw(coNNection content-TYPE set-cookie f-o-o-bar));
    $this->assert_deep_equals(
        [qw(Pragma Status)],
        [ sort $res->getHeader ],
        'Wrong header fields'
    );
}

1;
