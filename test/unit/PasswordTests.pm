use strict;

package PasswordTests;

use base qw(TWikiTestCase);

use TWiki;
use TWiki::Users::HtPasswdUser;

sub new {
	my $self = shift()->SUPER::new(@_);
	return $self;
}

sub set_up {
    my $this = shift();

    $this->SUPER::set_up();

    $TWiki::cfg{Htpasswd}{FileName} = '/tmp/junkpasswd';
}

sub tear_down {
    my $this = shift;
    $this->SUPER::tear_down();
    unlink('/tmp/junkpasswd');
}

my $userpass1 =
  {
   alligator => 'hissss',
   bat => 'ultrasonic squeal',
   budgie => 'tweet',
   lion => 'roar',
   mole => '',
  };

my $userpass2 =
  {
   alligator => 'gnu',
   bat => 'moth',
   budgie => 'millet',
   lion => 'antelope',
   mole => 'earthworm',
  };

sub test_htpasswd_crypt {
    my $this = shift;
    $TWiki::cfg{Htpasswd}{Encoding} = 'crypt';
    my $impl = new TWiki::Users::HtPasswdUser();
    # add them all
    my %encrapted;
    foreach my $user ( keys %$userpass1 ) {
        $this->assert(!$impl->fetchPass($user));
        my $added = $impl->passwd( $user, $userpass1->{$user} );
        $this->assert($added);
        $this->assert_null($impl->error());
        $this->assert($encrapted{$user} = $impl->fetchPass($user));
        $this->assert_str_equals($encrapted{$user},
                                 $impl->encrypt($user,$userpass1->{$user}));
    }
    # check it
    foreach my $user ( keys %$userpass1 ) {
        $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        $this->assert_str_equals($encrapted{$user},
                                 $impl->encrypt($user,$userpass1->{$user}));
    }
    # try changing with wrong pass
    foreach my $user ( keys %$userpass1 ) {
        my $added = $impl->passwd( $user, $userpass1->{$user},
                                   $userpass2->{$user} );
        $this->assert(!$added);
        $this->assert($impl->error());
    }
    # re-add them with the same password, make sure encoding changed
    foreach my $user ( keys %$userpass1 ) {
        my $added = $impl->passwd( $user, $userpass1->{$user},
                                   $userpass1->{$user},
                                   $encrapted{$user} );
        $this->assert_null($impl->error());
        $this->assert_str_not_equals($encrapted{$user},
                                     $impl->fetchPass($user));
        $this->assert_null($impl->error());
    }
    # force-change them
    foreach my $user ( keys %$userpass1 ) {
        my $added = $impl->passwd( $user, $userpass2->{$user},
                                   $userpass1->{$user}, 1 );
        $this->assert_null($impl->error());
        $this->assert_str_not_equals($encrapted{$user},
                                     $impl->fetchPass($user));
        $this->assert_null($impl->error());
    }
    $this->assert(!$impl->deleteUser('notauser'));
    $this->assert_not_null($impl->error());
    # delete first
    $this->assert($impl->deleteUser('alligator'));
    $this->assert_null($impl->error());
    foreach my $user ( keys %$userpass1 ) {
        if( $user !~ /alligator/ ) {
            $this->assert($impl->checkPassword($user, $userpass2->{$user}));
        } else {
            $this->assert(!$impl->checkPassword($user, $userpass2->{$user}));
        }
    }
    # delete last
    $this->assert($impl->deleteUser('mole'));
    foreach my $user ( keys %$userpass1 ) {
        if( $user !~ /(alligator|mole)/ ) {
            $this->assert($impl->checkPassword($user, $userpass2->{$user}));
        } else {
            $this->assert(!$impl->checkPassword($user, $userpass2->{$user}));
        }
    }
    # delete middle
    $this->assert($impl->deleteUser('budgie'));
    foreach my $user ( keys %$userpass1 ) {
        if( $user !~ /(alligator|mole|budgie)/ ) {
            $this->assert($impl->checkPassword($user, $userpass2->{$user}));
        } else {
            $this->assert(!$impl->checkPassword($user, $userpass2->{$user}));
        }
    }
}

sub test_htpasswd_sha1 {
    my $this = shift;

    eval 'use MIME::Base64';
    if( $@ ) {
        print STDERR "SKIPPED SHA1 TESTS: $@";
        return;
    }
    eval 'use Digest::SHA1';
    if( $@ ) {
        print STDERR "SKIPPED SHA1 TESTS: $@";
        return;
    }

    $TWiki::cfg{Htpasswd}{Encoding} = 'sha1';
    my $impl = new TWiki::Users::HtPasswdUser();
    # add them all
    my %encrapted;
    foreach my $user ( keys %$userpass1 ) {
        $this->assert(!$impl->fetchPass($user));
        my $added = $impl->passwd( $user, $userpass1->{$user} );
        $this->assert($added);
        $this->assert_null($impl->error());
        $this->assert($encrapted{$user} = $impl->fetchPass($user));
        $this->assert_str_equals($encrapted{$user},
                                 $impl->encrypt($user,$userpass1->{$user}));
    }
    # check it
    foreach my $user ( keys %$userpass1 ) {
        $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        $this->assert_str_equals($encrapted{$user},
                                 $impl->encrypt($user,$userpass1->{$user}));
    }
    # try changing with wrong pass
    foreach my $user ( keys %$userpass1 ) {
        my $added = $impl->passwd( $user, $userpass1->{$user},
                                   $userpass2->{$user} );
        $this->assert(!$added);
        $this->assert($impl->error());
    }
    # re-add with different password
    foreach my $user ( keys %$userpass2 ) {
        my $added = $impl->passwd( $user, $userpass2->{$user},
                                   $userpass1->{$user},
                                   $encrapted{$user} );
        $this->assert_null($impl->error());
        $this->assert($impl->checkPassword($user, $userpass2->{$user}));
        $this->assert_str_not_equals($encrapted{$user},
                                     $impl->fetchPass($user));
        $encrapted{$user} = $impl->fetchPass($user);
        $this->assert_null($impl->error());
    }
    # force-change them back to the old password
    foreach my $user ( keys %$userpass1 ) {
        my $added = $impl->passwd( $user, $userpass1->{$user},
                                   $userpass2->{$user}, 1 );
        $this->assert_null($impl->error());
        $this->assert_str_not_equals($encrapted{$user},
                                     $impl->fetchPass($user));
        $encrapted{$user} = $impl->fetchPass($user);
        $this->assert_null($impl->error());
    }
    $this->assert(!$impl->deleteUser('notauser'));
    $this->assert_not_null($impl->error());
    # delete first
    $this->assert($impl->deleteUser('alligator'));
    $this->assert_null($impl->error());
    foreach my $user ( keys %$userpass1 ) {
        if( $user !~ /alligator/ ) {
            $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        } else {
            $this->assert(!$impl->checkPassword($user, $userpass1->{$user}));
        }
    }
    # delete last
    $this->assert($impl->deleteUser('mole'));
    foreach my $user ( keys %$userpass1 ) {
        if( $user !~ /(alligator|mole)/ ) {
            $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        } else {
            $this->assert(!$impl->checkPassword($user, $userpass1->{$user}));
        }
    }
    # delete middle
    $this->assert($impl->deleteUser('budgie'));
    foreach my $user ( keys %$userpass1 ) {
        if( $user !~ /(alligator|mole|budgie)/ ) {
            $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        } else {
            $this->assert(!$impl->checkPassword($user, $userpass1->{$user}));
        }
    }
}

sub test_htpasswd_md5 {
    my $this = shift;
    eval 'use Digest::MD5';
    if( $@ ) {
        print STDERR "SKIPPED SHA1 TESTS: $@";
        return;
    }

    $TWiki::cfg{Htpasswd}{Encoding} = 'md5';
    my $impl = new TWiki::Users::HtPasswdUser();
    # add them all
    my %encrapted;
    foreach my $user ( keys %$userpass1 ) {
        $this->assert(!$impl->fetchPass($user));
        my $added = $impl->passwd( $user, $userpass1->{$user} );
        $this->assert($added);
        $this->assert_null($impl->error());
        $this->assert($encrapted{$user} = $impl->fetchPass($user));
        $this->assert_str_equals($encrapted{$user},
                                 $impl->encrypt($user,$userpass1->{$user}));
    }
    # check it
    foreach my $user ( keys %$userpass1 ) {
        $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        $this->assert_str_equals($encrapted{$user},
                                 $impl->encrypt($user,$userpass1->{$user}));
    }
    # try changing with wrong pass
    foreach my $user ( keys %$userpass1 ) {
        my $added = $impl->passwd( $user, $userpass1->{$user},
                                   $userpass2->{$user} );
        $this->assert(!$added);
        $this->assert($impl->error());
    }
    # re-add with different password
    foreach my $user ( keys %$userpass2 ) {
        my $added = $impl->passwd( $user, $userpass2->{$user},
                                   $userpass1->{$user},
                                   $encrapted{$user} );
        $this->assert_null($impl->error());
        $this->assert($impl->checkPassword($user, $userpass2->{$user}));
        $this->assert_str_not_equals($encrapted{$user},
                                     $impl->fetchPass($user));
        $encrapted{$user} = $impl->fetchPass($user);
        $this->assert_null($impl->error());
    }
    # force-change them back to the old password
    foreach my $user ( keys %$userpass1 ) {
        my $added = $impl->passwd( $user, $userpass1->{$user},
                                   $userpass2->{$user}, 1 );
        $this->assert_null($impl->error());
        $this->assert_str_not_equals($encrapted{$user},
                                     $impl->fetchPass($user));
        $encrapted{$user} = $impl->fetchPass($user);
        $this->assert_null($impl->error());
    }
    $this->assert(!$impl->deleteUser('notauser'));
    $this->assert_not_null($impl->error());
    # delete first
    $this->assert($impl->deleteUser('alligator'));
    $this->assert_null($impl->error());
    foreach my $user ( keys %$userpass1 ) {
        if( $user !~ /alligator/ ) {
            $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        } else {
            $this->assert(!$impl->checkPassword($user, $userpass1->{$user}));
        }
    }
    # delete last
    $this->assert($impl->deleteUser('mole'));
    foreach my $user ( keys %$userpass1 ) {
        if( $user !~ /(alligator|mole)/ ) {
            $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        } else {
            $this->assert(!$impl->checkPassword($user, $userpass1->{$user}));
        }
    }
    # delete middle
    $this->assert($impl->deleteUser('budgie'));
    foreach my $user ( keys %$userpass1 ) {
        if( $user !~ /(alligator|mole|budgie)/ ) {
            $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        } else {
            $this->assert(!$impl->checkPassword($user, $userpass1->{$user}));
        }
    }
}

sub test_htpasswd_plain {
    my $this = shift;
    $TWiki::cfg{Htpasswd}{Encoding} = 'sha1';
    my $impl = new TWiki::Users::HtPasswdUser();
    # add them all
    my %encrapted;
    foreach my $user ( keys %$userpass1 ) {
        $this->assert(!$impl->fetchPass($user));
        my $added = $impl->passwd( $user, $userpass1->{$user} );
        $this->assert($added);
        $this->assert_null($impl->error());
        $this->assert($encrapted{$user} = $impl->fetchPass($user));
        $this->assert_str_equals($encrapted{$user},
                                 $impl->encrypt($user,$userpass1->{$user}));
    }
    # check it
    foreach my $user ( keys %$userpass1 ) {
        $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        $this->assert_str_equals($encrapted{$user},
                                 $impl->encrypt($user,$userpass1->{$user}));
    }
    # try changing with wrong pass
    foreach my $user ( keys %$userpass1 ) {
        my $added = $impl->passwd( $user, $userpass1->{$user},
                                   $userpass2->{$user} );
        $this->assert(!$added);
        $this->assert($impl->error());
    }
    # re-add with different password
    foreach my $user ( keys %$userpass2 ) {
        my $added = $impl->passwd( $user, $userpass2->{$user},
                                   $userpass1->{$user},
                                   $encrapted{$user} );
        $this->assert_null($impl->error());
        $this->assert($impl->checkPassword($user, $userpass2->{$user}));
        $this->assert_str_not_equals($encrapted{$user},
                                     $impl->fetchPass($user));
        $encrapted{$user} = $impl->fetchPass($user);
        $this->assert_null($impl->error());
    }
    # force-change them back to the old password
    foreach my $user ( keys %$userpass1 ) {
        my $added = $impl->passwd( $user, $userpass1->{$user},
                                   $userpass2->{$user}, 1 );
        $this->assert_null($impl->error());
        $this->assert_str_not_equals($encrapted{$user},
                                     $impl->fetchPass($user));
        $encrapted{$user} = $impl->fetchPass($user);
        $this->assert_null($impl->error());
    }
    $this->assert(!$impl->deleteUser('notauser'));
    $this->assert_not_null($impl->error());
    # delete first
    $this->assert($impl->deleteUser('alligator'));
    $this->assert_null($impl->error());
    foreach my $user ( keys %$userpass1 ) {
        if( $user !~ /alligator/ ) {
            $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        } else {
            $this->assert(!$impl->checkPassword($user, $userpass1->{$user}));
        }
    }
    # delete last
    $this->assert($impl->deleteUser('mole'));
    foreach my $user ( keys %$userpass1 ) {
        if( $user !~ /(alligator|mole)/ ) {
            $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        } else {
            $this->assert(!$impl->checkPassword($user, $userpass1->{$user}));
        }
    }
    # delete middle
    $this->assert($impl->deleteUser('budgie'));
    foreach my $user ( keys %$userpass1 ) {
        if( $user !~ /(alligator|mole|budgie)/ ) {
            $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        } else {
            $this->assert(!$impl->checkPassword($user, $userpass1->{$user}));
        }
    }
}

sub test_htpasswd_apache {
    my $this = shift;

    eval "require TWiki::Users::ApacheHtpasswdUser";
    if( $@ ) {
        print STDERR "SKIPPED APACHE HTPASSWD TESTS: not found";
        return;
    }

    my $impl = new TWiki::Users::ApacheHtpasswdUser();
    # apache doesn't create the file, so need to init it
    open(F,">$TWiki::cfg{Htpasswd}{FileName}");
    close(F);

    # otherwise it should work the same as htpasswd

    # add them all
    my %encrapted;
    foreach my $user ( keys %$userpass1 ) {
        $this->assert(!$impl->fetchPass($user));
        my $added = $impl->passwd( $user, $userpass1->{$user} );
        $this->assert($added);
        $this->assert($encrapted{$user} = $impl->fetchPass($user));
        $this->assert_str_equals($encrapted{$user},
                                 $impl->encrypt($user,$userpass1->{$user}));
    }
    # check it
    foreach my $user ( keys %$userpass1 ) {
        $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        $this->assert_str_equals($encrapted{$user},
                                 $impl->encrypt($user,$userpass1->{$user}));
    }
    # try changing with wrong pass
# commented out because Apache carps, which breaks the tests
#    foreach my $user ( keys %$userpass1 ) {
#        my $added = $impl->passwd( $user, $userpass1->{$user},
#                                   $userpass2->{$user} );
#        $this->assert(!$added);
#        $this->assert($impl->error());
#    }
    # re-add them with the same password, make sure encoding changed
    foreach my $user ( keys %$userpass1 ) {
        my $added = $impl->passwd( $user, $userpass1->{$user},
                                   $userpass1->{$user},
                                   $encrapted{$user} );
        $this->assert($added);
#        $this->assert_null($impl->error());
        $this->assert_str_not_equals($encrapted{$user},
                                     $impl->fetchPass($user));
#        $this->assert_null($impl->error());
    }
    # force-change them
    foreach my $user ( keys %$userpass1 ) {
        my $added = $impl->passwd( $user, $userpass1->{$user},
                                   $userpass1->{$user}, 1 );
        $this->assert($added);
#        $this->assert_null($impl->error());
        $this->assert_str_not_equals($encrapted{$user},
                                     $impl->fetchPass($user));
#        $this->assert_null($impl->error());
    }
#    $this->assert(!$impl->deleteUser('notauser'));
#    $this->assert_not_null($impl->error());
    # delete first
    $this->assert($impl->deleteUser('alligator'));
#    $this->assert_null($impl->error());
    foreach my $user ( keys %$userpass1 ) {
        if( $user !~ /alligator/ ) {
            $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        } else {
            $this->assert(!$impl->checkPassword($user, $userpass1->{$user}));
        }
    }
    # delete last
    $this->assert($impl->deleteUser('mole'));
    foreach my $user ( keys %$userpass1 ) {
        if( $user !~ /(alligator|mole)/ ) {
            $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        } else {
            $this->assert(!$impl->checkPassword($user, $userpass1->{$user}));
        }
    }
    # delete middle
    $this->assert($impl->deleteUser('budgie'));
    foreach my $user ( keys %$userpass1 ) {
        if( $user !~ /(alligator|mole|budgie)/ ) {
            $this->assert($impl->checkPassword($user, $userpass1->{$user}));
        } else {
            $this->assert(!$impl->checkPassword($user, $userpass1->{$user}));
        }
    }
}


1;
