use strict;

package UploadScriptTests;

use base qw(TWikiFnTestCase);

use strict;
use TWiki;
use Unit::Request;
use TWiki::UI::Upload;
use CGI;
use Error qw( :try );
use File::Temp qw/tmpnam/;


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

# Following subroutine uploads single file 
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
    my $query = new Unit::Request(\%args);
    $query->path_info( "/$this->{test_web}/$this->{test_topic}" );
    $query->request_method('POST');
    $TWiki::cfg{CryptToken}{Enable}=0;
    my $tmpfile = new CGITempFile(0);
    my $fh = Fh->new($fn, $tmpfile->as_string, 0);
    print $fh $data;
    seek($fh,0,0);
    my ( $release ) = $TWiki::RELEASE =~ /-(\d+)\.\d+\.\d+/;
    if ( $release >= 5 ) {
        $query->param( -name => 'filepath', -value => $fn );
        my %uploads = ();
        require TWiki::Request::Upload;
        $uploads{$fh} = new TWiki::Request::Upload(
            headers => {},
            tmpname => $tmpfile->as_string
        );
        $query->uploads( \%uploads );
    }
    else {
        $query->{'.tmpfiles'}->{$$fh} = {
            hndl => $fh,
            name => $tmpfile,
            info => {},
        };
        push( @{ $query->{'filepath'} }, $fh );
        $query->param( 'filepath', $fh );
    }

    my $stream = $query->upload( 'filepath' );
    seek($stream,0,0);

    $this->{twiki}->finish();
    $this->{twiki} = new TWiki( $this->{test_user_login}, $query );

    my ($text, $result) = $this->capture( \&TWiki::UI::Upload::upload, $this->{twiki});
    return $text;
}
# upload two files 
# TODO - make it generic later
sub do_multiple_upload {
    my $this = shift;
    my $filedata = shift;   # hash filepath=>, data=>, filepath0=>, data0=>
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
   

    my $query = new Unit::Request(\%args);
    $query->path_info( "/$this->{test_web}/$this->{test_topic}" );
   
    $query->request_method('POST');
    $TWiki::cfg{CryptToken}{Enable}=0;
  
    my $tmpfile = tmpnam();  # Using from File::Temp
    my $tmpfiletwo = tmpnam(); 

    my $fnone = $filedata->{filepath};
    my $fhone = Fh->new($fnone, $tmpfile, 0);   # Fh is package under CGI

    my $fntwo = $filedata->{filepath0};
    my $fhtwo = Fh->new($fntwo, $tmpfiletwo, 0); 

    print $fhone $filedata->{data};
    print $fhtwo $filedata->{data0};

    seek($fhone,0,0);
    seek($fhtwo,0,0);

    my ( $release ) = $TWiki::RELEASE =~ /-(\d+)\.\d+\.\d+/;
    if ( $release >= 5 ) {
        $query->param( -name => 'filepath', -value => $fnone );
        $query->param( -name => 'filepath0', -value => $fntwo );
        my %uploads = ();
        require TWiki::Request::Upload;
        $uploads{$fhone} = new TWiki::Request::Upload(
            headers => {},
            tmpname => $tmpfile
        );
        $uploads{$fhtwo} = new TWiki::Request::Upload(
            headers => {},
            tmpname => $tmpfiletwo
        );
        $query->uploads( \%uploads );
    } else {
        $query->{'.tmpfiles'}->{$$fhone} = { hndl => $fhone, name => $tmpfile, info => {}, };
        push( @{ $query->{'filepath'} }, $fhone );
        $query->param( 'filepath', $fhone );
        $query->{'.tmpfiles'}->{$$fhtwo} = { hndl => $fhtwo, name => $tmpfiletwo, info => {}, };
        push( @{ $query->{'filepath0'} }, $fhtwo );
        $query->param( 'filepath0', $fhtwo );
    }


    #my $stream = $query->upload( 'filepath' );
    #seek($stream,0,0);

    #my $streamone = $query->upload( 'filepath0' );
    #seek($streamone,0,0);


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
    my $query = new Unit::Request(\%args);
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

# Test two file upload

sub test_twofile_upload_one {
    my $this = shift;
    local $/;
    my $result = $this->do_multiple_upload(
        {  
          filepath=>'POTATOONE.txt',
          data=>'POTATO',
          filepath0=>'POTATOTWO.txt',
          data0=>'POTATOPOTATO', 
        },
        hidefile => 0,
        filecomment => 'MY NAME IS COMMENT',
        createlink => 0,
        changeproperties => 0,
       );
    $this->assert($result =~ /^OK/, $result);
  
    $this->assert(open(F, "<$TWiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/POTATOONE.txt"));
    $this->assert_str_equals("POTATO", <F>);
 
    #$this->assert(open(FF, "<$TWiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/POTATOTWO.txt"));
    #$this->assert_str_equals("POTATOPOTATO", <FF>);
    my ($meta, $text) = TWiki::Func::readTopic($this->{test_web}, $this->{test_topic});

    # Check the meta
    my $at = $meta->get('FILEATTACHMENT', 'POTATOONE.txt');
    $this->assert($at);
    $this->assert_str_equals('MY NAME IS COMMENT', $at->{comment});

}

sub test_twofile_upload_two {
    my $this = shift;
    local $/;
    my $result = $this->do_multiple_upload(
        {  
          filepath=>'POTATOONE.txt',
          data=>'POTATO',
          filepath0=>'POTATOTWO.txt',
          data0=>'POTATOPOTATO', 
        },
        hidefile => 1,
        filecomment => 'MY NAME IS COMMENT',
        createlink => 0,
        changeproperties => 0,
       );
    $this->assert($result =~ /^OK/, $result);
    $this->assert(open(F, "<$TWiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/POTATOONE.txt"));
    $this->assert_str_equals("POTATO", <F>);

    #$this->assert(open(FF, "<$TWiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/POTATOTWO.txt"));
    #$this->assert_str_equals("POTATOPOTATO", <FF>);
    my ($meta, $text) = TWiki::Func::readTopic($this->{test_web}, $this->{test_topic});

    # Check the meta
    my $at = $meta->get('FILEATTACHMENT', 'POTATOONE.txt');
    $this->assert($at);
    $this->assert_str_equals('MY NAME IS COMMENT', $at->{comment});


}

sub test_twofile_upload_three {
    my $this = shift;
    local $/;
    my $result = $this->do_multiple_upload(
        {  
          filepath=>'POTATOONE.txt',
          data=>'POTATO',
          filepath0=>'POTATOTWO.txt',
          data0=>'POTATOPOTATO', 
        },
        hidefile => 1,
        filecomment => 'MY NAME IS COMMENT',
        createlink => 1,
        changeproperties => 0,
       );
    $this->assert($result =~ /^OK/, $result);
      $this->assert(open(F, "<$TWiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/POTATOONE.txt"));
    $this->assert_str_equals("POTATO", <F>);

    #$this->assert(open(FF, "<$TWiki::cfg{PubDir}/$this->{test_web}/$this->{test_topic}/POTATOTWO.txt"));
    #$this->assert_str_equals("POTATOPOTATO", <FF>);
    my ($meta, $text) = TWiki::Func::readTopic($this->{test_web}, $this->{test_topic});

    # Check the meta
    my $at = $meta->get('FILEATTACHMENT', 'POTATOONE.txt');
    $this->assert($at);
    $this->assert_str_equals('MY NAME IS COMMENT', $at->{comment});


}

1;
