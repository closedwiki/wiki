# Install script for %$MODULE%
#
# Copyright (C) 2004 Crawford Currie http://c-dot.co.uk
#
# NOTE TO THE DEVELOPER: THIS FILE IS GENERATED AUTOMATICALLY
# BY THE BUILD PROCESS DO NOT EDIT IT - IT WILL BE OVERWRITTEN
#
use Socket;
use strict;

my $noconfirm = 0;

# Borrowed from geturl
# Copyright (C) 1999 Jon Udell, BYTE
# Copyright (C) 2000-2003 Peter Thoeny, peter@thoeny.com
sub getUrl
{
    my ( $localFile, $theHost, $thePort, $theUrl, $theHeader ) = @_;
    my $result = '';
    my $req = "GET $theUrl HTTP/1.0\r\n$theHeader\r\n\r\n";
    my ( $iaddr, $paddr, $proto );
    $iaddr   = inet_aton( $theHost );
    $paddr   = sockaddr_in( $thePort, $iaddr );
    $proto   = getprotobyname( 'tcp' );
    socket( SOCK, PF_INET, SOCK_STREAM, $proto )  or die "socket: $!";
    connect( SOCK, $paddr ) or die "connect: $!";
    select SOCK;
    $| = 1;
    print SOCK $req;
    while( <SOCK> ) {
        print $localFile $_;
    }
    close( SOCK )  or die "close: $!";
    select STDOUT;
}

# Satisfy dependencies
sub satisfy {
    my $dep = shift;
    my $msg = "";
    my $ok = 1;
    print "Checking dependency on $dep->{name}....\n";
    if ($dep->{type} eq "perl") {
        eval "use $dep->{name}";
        if ( $@ ) {
            $msg .= $@;
            $ok = 0;
        } else {
            if ( defined( $dep->{version} ) ) {
                my $ver;
                eval "\$ver = \$$dep->{name}::VERSION;";
                if ( $@ ) {
                    $msg .= "The VERSION of the package could not be found: $@";
                    $ok = 0;
                } else {
                    eval "\$ok = ( \$ver $dep->{version} )";
                    if ( $@ || ! $ok ) {
                        $msg .= " $ver is currently installed: $@";
                        $ok = 0;
                    }
                }
            }
        }
    } else {
        $ok = 0;
        $msg = "Module is type $dep->{type}, and cannot be automatically checked.\n";
    }

    unless ($ok) {
        print "%$MODULE% depends on package $dep->{name} $dep->{version},\n";
        print "which is described as \"$dep->{description}\"\nBut when I tried to find it I found this error: $msg\n";
    }

    if (!$ok && $dep->{name} =~ /^TWiki::(Contrib|Plugins)::(\w*)/) {
        my $pack = $1;
        my $packname = $2;
        my $reply = "y";
        $packname .= $pack if ($pack eq "Contrib");
        unless ($noconfirm) {
            print "Would you like me to try to download and install the correct version of $packname from twiki.org? [y/n] ";
            while (($reply = <STDIN>) !~ /^[yn]/i) {
                print "Please answer yes or no\n";
            }
        }
        if ($reply =~ /^y/i) {
            my $zip;
            eval {
                my $zip;
                open($zip, ">$packname.zip") or
                  die "Could not open $packname.zip for write";
                getUrl($zip, "twiki.org","cgi-bin/view/Plugins/$packname/$packname.zip");
                close($zip) or
                  die "Failed to close $packname.zip";
            };
            if ($@) {
                print "Download failed: $@\n";
            } else {
                print `unzip $zip`;
                unless ($?) {
                    if ( -e "${packname}_installer.pl" ) {
                        print `perl ${packname}_installer.pl install`;
                        unless ($?) {
                            print STDERR "Installation of $packname failed\n";
                        }
                    }
                } else {
                    print STDERR "Unzip of $zip failed\n";
                }
            }
        } else {
            print "You can re-run this installer at any time to revisit this decision\n\n";
        }
    }
}

sub usage {
    print "Usage:\t%$MODULE%_installer [-a] install\n";
    print "\t%$MODULE%_installer uninstall\n";
    print "Install or uninstall %$MODULE%. Default is to install. Should be run\n";
    print "from the top level of your TWiki installation.\n";
    print "Options:\n";
    print "\t-a Don't prompt for confirmations\n";
}

unshift(@INC, "lib");

print "%$MODULE% Installer\n\n";
my $n = 0;
my $install = 1;
while ($n < scalar(@ARGV)) {
    if ($ARGV[$n] eq "-a") {
        $noconfirm = 1;
    } elsif ($ARGV[$n] eq "install") {
        $install = 1;
    } elsif ($ARGV[$n] eq "uninstall") {
        $install = 0;
    } else {
        usage();
        die "Bad parameter $ARGV[$n]";
    }
    $n++;
}

print "This installer must be run from the root directory of your TWiki\n";
print "installation. It can also be run from another directory, but it will\n";
print "not detect previously installed dependencies if it is.\n";
if ($install && !$noconfirm) {
    print "\t* The script will not do anything without asking you for\n";
    print "\t  confirmation first.\n";
}
print "\t* You can abort the script at any point and re-run it later\n";
print "\t* If you answer 'no' to any questions you can always re-run\n";
print "\t  the script again later\n";

if ($install) {
    unless ($noconfirm) {
        print "Hit <Enter> to proceed with installation\n";
    }
    <STDIN>;
    foreach my $dep ( ( %$DEPENDENCIES% ) ) {
        satisfy($dep);
    }
    print "%$MODULE% installed\n";
} else {
    my @manifest = ( %$MANIFEST% );
    my $file;
    my @dead;
    foreach $file ( @manifest ) {
        if ( -e $file ) {
           push(@dead, $file);
        }
    }
    unless ($#dead > 1) {
        die "No part of %$MODULE% is installed";
    }
    print "To uninstall %$MODULE%, the following files will be deleted:\n";
    print join(", ", @dead);
    my $reply;
    print "Are you SURE you want to uninstall %$MODULE%? [y/n] ";
    while (($reply = <STDIN>) !~ /^[yn]/i) {
        print "Please answer yes or no\n";
    }
    if ($reply =~ /^y/i) {
        foreach $file ( @manifest ) {
            if ( -e $file ) {
                unlink($file);
            }
        }
    }
    print "%$MODULE% uninstalled\n";
}
