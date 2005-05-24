# Install script for %$MODULE%
#
# Copyright (C) 2004 Crawford Currie http://c-dot.co.uk
#
# NOTE TO THE DEVELOPER: THIS FILE IS GENERATED AUTOMATICALLY
# BY THE BUILD PROCESS DO NOT EDIT IT - IT WILL BE OVERWRITTEN
#
# It's not smart enough to use the TWiki.cfg to drive the
# installation - yet.
#
use strict;
use Socket;

my $noconfirm = 0;
my $twiki;
my $NL = "\n";

BEGIN {
    unless ( -d 'lib' &&
             -d 'bin' &&
             -e 'bin/setlib.cfg' ) {
        die 'This installer must be run from the root directory of a TWiki installation';
    }
    my $here = `pwd`; # in case bin is a link
    # read setlib.cfg
    chdir('bin');
    require 'setlib.cfg';
    chomp($here); chdir($here);
    # See if we can make a TWiki. If we can, then we can save topic
    # and attachment histories
    eval 'use TWiki::Merge';
    unless( $@ ) {
        require TWiki;
        $twiki = TWiki->new();
    }
}

# Satisfy dependencies on modules, by checking:
# 1. If the module is a perl module, then:
#    1. If the module is loadable in the current environment
#    2. If the dependency has specified a version constraint, then
#       the module must have a top-level variable VERSION which satisfies
#       the constraint.
#       Note that all TWiki modules are perl modules - even non-perl
#       distributions have a perl 'stub' module that carries the version info.
# 2. If the module is _not_ perl, then we can't check it.
sub satisfy {
    my $dep = shift;
    my $msg = '';
    my $ok = 1;
    my $result = 1;
    my $trig = eval $dep->{trigger};

    return 1 unless ( $trig );

    print '##########################################################'.$NL;
    print 'Checking dependency on '.$dep->{name}.'....'.$NL;
    if( $dep->{type} eq 'perl' ) {
        # Try to 'use' the perl module
        eval 'use '.$dep->{name};
        if( $@ ) {
            $msg = $@;
            $msg =~ s/ in .*$/\n/s;
            $ok = 0;
        } else {
            # OK, it was loaded. See if a version constraint is specified
            if( defined( $dep->{version} ) ) {
                my $ver;
                # check the $VERSION variable in the loaded module
                eval '$ver = $'.$dep->{name}.'::VERSION;';
                if( $@ || !defined( $ver ) ) {
                    $msg .= 'The VERSION of the package could not be found: '.
                      $@;
                    $ok = 0;
                } else {
                    # The version variable exists
                    eval '$ok = ( $ver '.$dep->{version}.' )';
                    if( $@ || ! $ok ) {
                        # The version variable fails the constraint
                        $msg .= ' '.$ver.' is currently installed: '.$@;
                        $ok = 0;
                    }
                }
            }
        }
    } else {
        # This module has no perl interface, and can't be checked
        $ok = 0;
        $msg = 'Module is type '.$dep->{type}.
          ', and cannot be automatically checked.'.$NL.
            'Please check it manually and install if necessary.'.$NL;
    }

    unless ( $ok ) {
        print '*** %$MODULE% depends on package ',$dep->{name},' ',
          $dep->{version},$NL;
        print 'which is described as "'.$dep->{description}.'"'.$NL;
        print 'But when I tried to find it I got this error:'.$NL.$NL.$msg.$NL;
        $result = 0;
    }

    if( !$ok && $dep->{name} =~ m/^TWiki::(Contrib|Plugins)::(\w*)/ ) {
        my $pack = $1;
        my $packname = $2;
        my $reply = 'y';
        $packname .= $pack if( $pack eq 'Contrib' && $packname !~ /Contrib$/);
        unless ( $noconfirm ) {
            $reply = ask('Would you like me to try to download and install the latest version of '.$packname.' from twiki.org?');
        }
        if( $reply ) {
            $result = download( $packname );
        }
    }

    return $result;
}

sub ask {
    my $q = shift;
    my $reply;
    print $q.' [y/n] ';
    while ( ( $reply = <STDIN> ) !~ /^[yn]/i ) {
        print 'Please answer yes or no'.$NL;
    }
    return ( $reply =~ /^y/i );
}

# Try and download a zip
sub getzip {
    my ( $pack, $zip ) = @_;

    if ( -e $zip ) {
        my $ans = 'y';

        unless ( $noconfirm ) {
            $ans = ask( 'An existing $zip exists; would you like me to use it?');
        }

        return 1 if $ans;

        unless ( unlink( $zip )) {
            print STDERR 'Could not remove old $zip'.$NL;
            return 0;
        }
    }

    print 'Waiting for twiki.org.....'.$NL;
    my $step = 'socket';
    if ( socket( SOCK, PF_INET, SOCK_STREAM, getprotobyname( 'tcp' ))) {
        my $paddr = sockaddr_in( 80, inet_aton( 'twiki.org' ));
        $step = 'connect';
        if ( connect( SOCK, $paddr )) {
            select( SOCK );
            $| = 1;
            print SOCK "GET /p/pub/Plugins/$pack/$zip HTTP/1.0\r\nHost: twiki.org\r\n\r\n";
            my $sep = $/;
            undef $/;
            my $result = <SOCK>;
            $/ = $sep;
            $step = 'close';
            if ( close( SOCK )) {
                select( STDOUT );
                if ( $result =~ /^HTTP\/1.1 200 OK/ ) {
                    $step = 'open';
                    if ( open( ZF, '>'.$zip )) {
                        $result =~ s/^.*?Content-Type: application\/zip\s*//s;
                        print ZF $result;
                        close( ZF );
                        return 1;
                    }
                } else {
                    print $result;
                }
            }
        }
    }
    print STDERR 'Could not download '.$zip.': '.$step.' '.$!;
    return 0;
}

# Download the zip file for the given package from twiki.org.
sub download {
    my $packname = shift;
    my $zip = $packname.'.zip';

    return 0 unless getzip( $packname, $zip );

    unzip( $zip );

    if( -e $packname.'_installer.pl' ) {
        print `perl ${packname}_installer.pl install`;
        if ( $? ) {
            print STDERR 'Installation of ',$packname,' failed',$NL;
            return 0;
        }
    }

    # Tidy up
    unlink( $zip );

    return 1;
}

# unzip a zip using Archive::Zip if possible, falling back to
# unzip otherwise
sub unzip {
    my $zipname = shift;

    require Archive::Zip;
    unless ( $@ ) {
        my $zip = new Archive::Zip( $zipname );
        unless ( $zip ) {
            print STDERR 'Could not open zip file '.$zipname.$NL;
            return 0;
        }

        my @members = $zip->members();
        foreach my $file ( @members ) {
            my $err = $zip->extractMember( $file );
            my $fn = $file->fileName();
            if ( $err ) {
                print STDERR 'Failed to extract ',$fn,' from zip file ',
                  $zip,'. Archive may be corrupt.',$NL;
                return 0;
            } else {
                print "\t$fn\n";
            }
        }
    } else {
        print STDERR 'Archive::Zip is not installed; trying unzip'.$NL;
        print `unzip $zipname`;
        if ( $! ) {
            print STDERR 'Unzip failed: ',$!,$NL;
            return 0;
        }
    }

    return 1;
}

# Check in. On Cairo, do nothing because the apache user
# has everything checked out :-(
sub checkin {
    my( $web, $topic, $file ) = @_;

    # If this is Dakar, we have a good chance of completing the
    # install.
    my $err = 1;
    if( $twiki ) {
        my $user =
          $twiki->{users}->findUser($TWiki::cfg{DefaultUserLogin});
        if( $file ) {
            $err = $twiki->{store}->saveAttachment
              ( $web, $topic, $file, $user,
                { comment => 'Saved by installer' } );
        } else {
            # read the topic to recover meta-data
            my( $meta, $text ) =
              $twiki->{store}->readTopic( $user, $web, $topic );
            $err = $twiki->{store}->saveTopic
              ( $user, $web, $topic, $text, $meta,
                { comment => 'Saved by installer' } );
        }
    }
    if( $err ) {
        if( $file ) {
            $err = $web.'.'.$topic.':'.$file;
        } else {
            $err = $web.'.'.$topic;
        }
        print STDERR 'WARNING: I cannot automatically update the revision history for',
          $NL,$err.$NL.'Please ';
        unless ( $file ) {
            print STDERR 'edit the topic in TWiki and Save without changing it';
        } else {
            print STDERR 'upload the file in TWiki';
        }
        print STDERR ' to update the history, if you require it.'.$NL;
    }
}

# Print a useful message
sub usage {
    print STDERR "Usage:\t%$MODULE%_installer [-a] install\n";
    print STDERR "\t%$MODULE%_installer uninstall\n";
    print STDERR "Install or uninstall %$MODULE%. Default is to install. Should be run\n";
    print STDERR "from the top level of your TWiki installation.\n";;
    print STDERR "Options:\n";;
    print STDERR "\t-a Don't prompt for confirmations\n";
}

unshift( @INC, 'lib' );

print $NL,'### %$MODULE% Installer ###',$NL,$NL;
my $n = 0;
my $install = 1;
while ( $n < scalar( @ARGV ) ) {
    if( $ARGV[$n] eq '-a' ) {
        $noconfirm = 1;
    } elsif( $ARGV[$n] eq 'install' ) {
        $install = 1;
    } elsif( $ARGV[$n] eq 'uninstall' ) {
        $install = 0;
    } else {
        usage( );
        die 'Bad parameter '.$ARGV[$n];
    }
    $n++;
}

print "This installer must be run from the root directory of your TWiki\ninstallation.\n";
if( $install && !$noconfirm ) {
    print "\t* The script will not do anything without asking you for\n";
    print "\t  confirmation first.\n";
}
print "\t* You can abort the script at any point and re-run it later\n";
print "\t* If you answer 'no' to any questions you can always re-run\n";
print "\t  the script again later\n";

my @manifest = ( %$MANIFEST% );

if( $install ) {
    %$PREINSTALL%;
    unless ( $noconfirm ) {
        print 'Hit <Enter> to proceed with installation'.$NL;
        <STDIN>;
    }
    my $unsatisfied = 0;
    foreach my $dep ( ( %$DEPENDENCIES% ) ) {
        unless ( satisfy( $dep ) ) {
            $unsatisfied++;
        }
    }

    # For each file in the MANIFEST, check to see if it is targeted
    # at pub or data. If it is, then add a call to "checkin" for the
    # file.
    my @topic;
    my @pub;
    my $file;
    foreach $file ( @manifest ) {
        if( $file =~ /^data\/(\w+)\/(\w+).txt$/ ) {
            push(@topic, $file);
        } elsif( $file =~ /^pub\/(\w+)\/(\w+)\/([^\/]+)$/ ) {
            push(@pub, $file);
        }
    }
    foreach $file ( @topic ) {
        $file =~ /^data\/(\w+)\/(\w+).txt$/;
        checkin( $1, $2, undef );
    }
    foreach $file ( @pub ) {
        $file =~ /^pub\/(\w+)\/(\w+)\/([^\/]+)$/;
        checkin( $1, $2, $3 );
    }

    print $NL.'### %$MODULE% installed';
    print ' with ',$unsatisfied.' unsatisfied dependencies' if ( $unsatisfied );
    print ' ###'.$NL;
    %$POSTINSTALL%;

    print $NL,'### Installation finished ###',$NL;
} else {
    my $file;
    my @dead;
    foreach $file ( @manifest ) {
        if( -e $file ) {
            push( @dead, $file );
        }
    }
    unless ( $#dead > 1 ) {
        die 'No part of %$MODULE% is installed';
    }
    print 'To uninstall %$MODULE%, the following files will be deleted:'.$NL;
    print join( ', ', @dead );
    my $reply = ask('Are you SURE you want to uninstall %$MODULE%?');
    if( $reply ) {
        %$PREUNINSTALL%;
        foreach $file ( @manifest ) {
            if( -e $file ) {
                unlink( $file );
            }
        }
        %$POSTUNINSTALL%;
    }
    print '### %$MODULE% uninstalled ###'.$NL;
}
