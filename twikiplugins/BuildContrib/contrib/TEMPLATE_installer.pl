# Install script
# Copyright (C) 2004 Crawford Currie http://c-dot.co.uk
use Socket;
use strict;

my $module;

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

sub satisfy {
    my ($dep, $type, $version, $description) = @_;
    my $msg = "";
    my $ok = 1;
    print "Checking dependency on $dep....\n";
    if ($type eq "perl") {
        eval "use $dep";
        if ( $@ ) {
            $msg .= $@;
            $ok = 0;
        } else {
            if ( defined( $version ) ) {
                my $ver;
                eval "\$ver = \$${module}::VERSION;";
                if ( $@ ) {
                    $msg .= "The VERSION of the package could not be found: $@";
                    $ok = 0;
                } else {
                    eval "\$ok = ( \$ver $version )";
                    if ( $@ || ! $ok ) {
                        $msg .= " $ver is currently installed: $@";
                        $ok = 0;
                    }
                }
            }
        }
    } else {
        $ok = 0;
        $msg = "Module is type $type, and cannot be automatically checked for.\n";
    }

    unless ($ok) {
        print "$module depends on package $dep $version,\n";
        print "which is described as \"$description\"\nBut when I tried to find it I found this error: $msg\n";
    }

    if (!$ok && $dep =~ /^TWiki::(Contrib|Plugins)::(\w*)/) {
        my $pack = $1;
        my $packname = $2;
        $packname .= $pack if ($pack eq "Contrib");
        print "Would you like me to try to download and install the correct version of $packname from twiki.org? [y/n] ";
        my $reply;
        while (($reply = <STDIN>) !~ /^[yn]/i) {
            print "Please answer yes or no\n";
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
                    print `perl ${packname}_installer.pl install`;
                    unless ($?) {
                        print STDERR "Installation of $packname failed\n";
                    }
                }
            }
        } else {
            print "You can re-run this installer at any time to revisit this decision\n\n";
        }
    }
}

print "This install script must be run from the root directory where you unzipped the package.\n";
print "   * The script will not do anything without asking you for confirmation first.\n";
print "   * You can abort the script at any point and re-run it later\n";
print "   * If you answer 'no' to any questions you can always re-run the script again later\n";
print "Hit <Enter> to proceed\n";
<STDIN>;

