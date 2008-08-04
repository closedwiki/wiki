use strict;

package UploadScriptTests;

use base qw(TWikiFnTestCase);

use strict;
use TWiki;
use TWiki::Request;
use TWiki::Request::Upload;
use TWiki::UI::Upload;
use CGI;
use Error qw( :try );

sub new {
    my $self = shift()->SUPER::new("UploadScript", @_);
    return $self;
}

# Set up the test fixture
sub set_up {
    my $this = shift;
    $this->SUPER::set_up();

    $this->{twiki}->{store}->saveTopic(
        $this->{test_user_wikiname}, $this->{test_web}, $this->{test_topic},
        "   * Set ATTACHFILESIZELIMIT = 511\n", undef );
}

sub do_upload {
    my $this = shift;
    my $fn = shift;
    my $data = shift;
    my %params = @_;
    my %args = (
        webName => [ $this->{test_web} ],
        topicName => [ $this->{test_topic} ],
       );
    while( scalar(@_)) {
        my $k = shift(@_);
        my $v = shift(@_);
        $args{$k} = [ $v ];
    }
    my $query = new TWiki::Request(\%args);
    $query->path_info( "/$this->{test_web}/$this->{test_topic}" );
    my %uploads = ();
    my $tmpfile = new CGITempFile(0);
    my $fh = Fh->new($fn, $tmpfile->as_string, 0);
    print $fh $data;
    seek($fh,0,0);
    $query->param( -name => 'filepath', -value => $fn );
    $uploads{filepath} = new TWiki::Request::Upload(
        name    => 'filepath',
        headers => {},
        tmpname => $tmpfile->as_string
    );
    $query->uploads( \%uploads );

    my $stream = $query->upload( 'filepath' );
    seek($stream,0,0);

    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );

    my ($text, $result) = $this->capture( \&TWiki::UI::Upload::upload, $this->{twiki});
    return $text;
}

sub test_simple_upload {
    my $this = shift;
    local $/;
    my $result = $this->do_upload(
        'Flappadoodle.txt',
        "BLAH",
        hidefile => 0,
        filecomment => 'Elucidate the goose',
        createlink => 0,
        changeproperties => 0,
       );
    $this->assert($result =~ /^OK/, $result);
    $this->assert(open(F, "<$TWiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/Flappadoodle.txt"));
    $this->assert_str_equals("BLAH", <F>);
    my ($meta, $text) = TWiki::Func::readTopic($this->{test_web},
                                               $this->{test_topic});

    # Check the meta
    my $at = $meta->get('FILEATTACHMENT', 'Flappadoodle.txt');
    $this->assert($at);
    $this->assert_str_equals('Elucidate the goose', $at->{comment});
}

sub test_oversized_upload {
    my $this = shift;
    local $/;
    my %args = (
        webName => [ $this->{test_web} ],
        topicName => [ $this->{test_topic} ],
       );
    my $query = new TWiki::Request(\%args);
    $query->path_info( "/$this->{test_web}/$this->{test_topic}" );
    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );
    $TWiki::Plugins::SESSION = $this->{twiki};
    my $data = '00000000000000000000000000000000000000';
    my $sz = TWiki::Func::getPreferencesValue('ATTACHFILESIZELIMIT') * 1024;
    $data .= $data while length($data) <= $sz;
    try {
        $this->do_upload(
            'Flappadoodle.txt',
            $data,
            hidefile => 0,
            filecomment => 'Elucidate the goose',
            createlink => 0,
            changeproperties => 0);
        $this->assert(0);
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("oversized_upload", $e->{def});
    };
}

sub test_zerosized_upload {
    my $this = shift;
    local $/;
    my $data = '';
    try {
        $this->do_upload(
            'Flappadoodle.txt',
            $data,
            hidefile => 0,
            filecomment => 'Elucidate the goose',
            createlink => 0,
            changeproperties => 0);
        $this->assert(0);
    } catch TWiki::OopsException with {
        my $e = shift;
        $this->assert_str_equals("zero_size_upload", $e->{def});
    };
}

sub test_propschanges {
    my $this = shift;
    local $/;
    my $data = '';
    my $result = $this->do_upload(
        'Flappadoodle.txt',
        "BLAH",
        hidefile => 0,
        filecomment => 'Grease the stoat',
        createlink => 0,
        changeproperties => 0,
       );
    $this->assert($result =~ /^OK/, $result);
    $result = $this->do_upload(
        'Flappadoodle.txt',
        $data,
        hidefile => 1,
        filecomment => 'Educate the hedgehog',
        createlink => 1,
        changeproperties => 1);
    $this->assert($result =~ /^OK/, $result);
    my ($meta, $text) = TWiki::Func::readTopic($this->{test_web},
                                               $this->{test_topic});

    # Check the link was created
    $this->assert_matches(qr/\[\[%ATTACHURL%\/Flappadoodle\.txt\]\[Flappadoodle\.txt\]\]: Educate the hedgehog/, $text);

    # Check the meta
    my $at = $meta->get('FILEATTACHMENT', 'Flappadoodle.txt');
    $this->assert($at);
    $this->assert_matches(qr/h/i, $at->{attr});
    $this->assert_str_equals('Educate the hedgehog', $at->{comment});
}

1;
