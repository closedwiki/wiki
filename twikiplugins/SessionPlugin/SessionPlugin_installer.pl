# Install script for SessionPlugin
#
# Copyright (C) 2004 Crawford Currie http://c-dot.co.uk
#
# NOTE TO THE DEVELOPER: THIS FILE IS GENERATED AUTOMATICALLY
# BY THE BUILD PROCESS DO NOT EDIT IT - IT WILL BE OVERWRITTEN
#
use strict;

my $noconfirm = 0;
my $webGet;
my $twikipub = "http://twiki.org/p/pub";

# Satisfy dependencies on modules, by checking:
# 1. If the module is a perl module, then:
#    1. If the module is loadable in the current environment
#    2. If the dependency has specified a version constraint, then
#       the module must have a top-level variable VERSION which satisfies
#       the constraint.
#       Note that all TWiki modules are perl modules - even non-perl
#       distributions have a perl "stub" module that carries the version info.
# 2. If the module is _not_ perl, then we can't check it.
sub satisfy {
    my $dep = shift;
    my $msg = "";
    my $ok = 1;
    my $result = 1;

    print "Checking dependency on $dep->{name}....\n";
    if( $dep->{type} eq "perl" ) {
        # Try to 'use' the perl module
        eval "use $dep->{name}";
        if( $@ ) {
            $msg .= $@;
            $ok = 0;
        } else {
            # OK, it was loaded. See if a version constraint is specified
            if( defined( $dep->{version} ) ) {
                my $ver;
                # check the $VERSION variable in the loaded module
                eval "\$ver = \$$dep->{name}::VERSION;";
                if( $@ ) {
                    $msg .= "The VERSION of the package could not be found: $@";
                    $ok = 0;
                } else {
                    # The version variable exists
                    eval "\$ok = ( \$ver $dep->{version} )";
                    if( $@ || ! $ok ) {
                        # The version variable fails the constraint
                        $msg .= " $ver is currently installed: $@";
                        $ok = 0;
                    }
                }
            }
        }
    } else {
        # This module has no perl interface, and can't be checked
        $ok = 0;
        $msg = "Module is type $dep->{type}, and cannot be automatically checked.\nPlease check it manually and install if necessary.\n";
    }

    unless ( $ok ) {
        print "SessionPlugin depends on package $dep->{name} $dep->{version},\n";
        print "which is described as \"$dep->{description}\"\n";
        print "But when I tried to find it I got this error: $msg\n";
        $result = 0;
    }

    if( !$ok && $dep->{name} =~ m/^TWiki::(Contrib|Plugins)::(\w*)/ ) {
        my $pack = $1;
        my $packname = $2;
        my $reply = "y";
        $packname .= $pack if( $pack eq "Contrib" && $packname !~ /Contrib$/);
        unless ( $noconfirm ) {
            print "Would you like me to try to download and install the latest version of $packname from twiki.org? [y/n] ";
            while ( ( $reply = <STDIN> ) !~ /^[yn]/i ) {
                print "Please answer yes or no\n";
            }
        }
        if( $reply =~ /^y/i ) {
            $result = download( $packname );
        }
    }

    unless ( $result ) {
        print "You can re-run this installer at any time\n\n";
    }

    return $result;
}

# Download the zip file for the given package from twiki.org.
sub download {
    my $packname = shift;
    my $zip = "$packname.zip";

    eval 'use LWP';
    if ( $@ ) {
        print STDERR "LWP is not installed; cannot download\n";
        return 0;
    }
    eval 'use Archive::Zip';
    if ( $@ ) {
        print STDERR "Archive::Zip is not installed; cannot download\n";
        return 0;
    }

    $webGet = new LWP::UserAgent() unless ( $webGet );
    eval {
        $webGet->get( "$twikipub/Plugins/$packname/$zip",
                      ':content_file' => $zip );
    };
    if( $@ || ! -e $zip ) {
        print STDERR "Download of $zip failed: $@\n";
        return 0;
    }

    my $zip = new Archive::Zip( $zip );
    unless ( $zip ) {
        print STDERR "Could not open downloaded file $zip\n";
        return 0;
    }

    my @members = $zip->members();
    foreach my $file ( @members ) {
        my $err = $zip->extractMember( $file );
        if ( $err ) {
            print STDERR "Failed to read zip file $zip. Archive may be corrupt.\n";
            return 0;
        } else {
            print "\t".$file->fileName()."\n";
        }
    }

    if( -e "${packname}_installer.pl" ) {
        print `perl ${packname}_installer.pl install`;
        if ( $? ) {
            print STDERR "Installation of $packname failed\n";
            return 0;
        }
    }

    # Tidy up
    unlink( $zip );
    return 1;
}

sub usage {
    print "Usage:\tSessionPlugin_installer [-a] install\n";
    print "\tSessionPlugin_installer uninstall\n";
    print "Install or uninstall SessionPlugin. Default is to install. Should be run\n";
    print "from the top level of your TWiki installation.\n";
    print "Options:\n";
    print "\t-a Don't prompt for confirmations\n";
}

unshift( @INC, "lib" );

print "\n### SessionPlugin Installer ###\n\n";
my $n = 0;
my $install = 1;
while ( $n < scalar( @ARGV ) ) {
    if( $ARGV[$n] eq "-a" ) {
        $noconfirm = 1;
    } elsif( $ARGV[$n] eq "install" ) {
        $install = 1;
    } elsif( $ARGV[$n] eq "uninstall" ) {
        $install = 0;
    } else {
        usage( );
        die "Bad parameter $ARGV[$n]";
    }
    $n++;
}

print "This installer must be run from the root directory of your TWiki\n";
print "installation. It can also be run from another directory, but it will\n";
print "not detect previously installed dependencies if it is.\n";
if( $install && !$noconfirm ) {
    print "\t* The script will not do anything without asking you for\n";
    print "\t  confirmation first.\n";
}
print "\t* You can abort the script at any point and re-run it later\n";
print "\t* If you answer 'no' to any questions you can always re-run\n";
print "\t  the script again later\n";

if( $install ) {
    unless ( $noconfirm ) {
        print "Hit <Enter> to proceed with installation\n";
    }
    <STDIN>;
    my $unsatisfied = 0;
    foreach my $dep ( (  ) ) {
        unless ( satisfy( $dep ) ) {
            $unsatisfied++;
        }
    }
    print "\n### SessionPlugin installed";
    print " with $unsatisfied unsatisfied dependencies" if ( $unsatisfied );
    print " ###\n";
} else {
    my @manifest = ( 	"./data/TWiki/SessionPlugin.txt", # 
	"./lib/TWiki/Plugins/SessionPlugin/build.pl", # 
	"./lib/TWiki/Plugins/SessionPlugin/test.zip", # 
	"./lib/TWiki/Plugins/SessionPlugin.pm", # 
	"./SessionPlugin_installer.pl", # 
	"./bin/logon", # 
	"SessionPlugin_installer.pl", # Install script
 );
    my $file;
    my @dead;
    foreach $file ( @manifest ) {
        if( -e $file ) {
           push( @dead, $file );
        }
    }
    unless ( $#dead > 1 ) {
        die "No part of SessionPlugin is installed";
    }
    print "To uninstall SessionPlugin, the following files will be deleted:\n";
    print join( ", ", @dead );
    my $reply;
    print "\nAre you SURE you want to uninstall SessionPlugin? [y/n] ";
    while ( ( $reply = <STDIN> ) !~ /^[yn]/i ) {
        print "Please answer yes or no\n";
    }
    if( $reply =~ /^y/i ) {
        foreach $file ( @manifest ) {
            if( -e $file ) {
                unlink( $file );
            }
        }
    }
    print "SessionPlugin uninstalled\n";
}
