# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2004 Peter Thoeny, peter@thoeny.com
#
# For licensing info read license.txt file in the TWiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html

# Service functions used by the UI packages

package TWiki::UI;

use strict;
use Error qw( :try );
use Assert;
use CGI::Carp qw( fatalsToBrowser );
use CGI;
use TWiki;
use TWiki::UI::OopsException;
use Data::Dumper;

use constant ENABLEBM => 0;

=pod

---++ run( $class, $method )
Entry point for execution of a UI function. The parameters are the
class that contains the method, and the name of the method. This
function handles redirection to Oops topics by catching OopsException.

=cut

sub run {
    my ( $class, $method ) = @_;

    my ( $query, $pathInfo, $user, $url, $topic );
    my $scripted = 0;

    # Use unbuffered IO
    $| = 1;

    if( $ENV{'DOCUMENT_ROOT'} ) {
        # script is called by browser
        $query = new CGI;
        # SMELL: The Microsoft Internet Information Server is broken with
        # respect to additional path information. If you use the Perl DLL
        # library, the IIS server will attempt to execute the additional
        # path information as a Perl script. If you use the ordinary file
        # associations mapping, the path information will be present in the
        # environment, but incorrect. The best thing to do is to avoid using
        # additional path information.
        $pathInfo = $query->path_info();
        $user = $query->remote_user();
        $url = $query->url;
        $topic = $query->param( 'topic' );
        # If the 'benchmark' parameter is set in the browser, save the
        # query and other info to the given file on the server.
        # To benchmark a script, set ENABLEBM above and
        # put the following lines into the top level CGI script.
        # use Benchmark qw(:all :hireswallclock);
        # use vars qw( $begin );
        # BEGIN{$begin=new Benchmark;}
        # END{print STDERR "Total ".timestr(timediff(new Benchmark,$begin))."\n";}
        if ( ENABLEBM ) {
            my $bm = $query->param( 'benchmark' );
            if ( $bm ) {
                open(OF, ">$bm") || throw Error::Simple( "Store failed" );
                print OF Dumper(\$query, $pathInfo, $user, $url);
                close(OF);
            }
        }
    } else {
        # script is called by cron job or user
        $query = new CGI( "" );
        $scripted = 1;
        # Interactive script name
        $user = "guest";
        $url = "";
        $topic = "";
        $pathInfo = "";
        foreach my $arg ( @ARGV ) {
            if ( $arg =~ /^-user=(.*)$/o ) {
                $user = $1;
            }
            # parse name=value parameter pairs
            if ( $arg =~ /^-?([A-Za-z0-9_]+)=(.*)$/o ) {
                $query->param( $1=>$2 );
            } else {
                $pathInfo = $arg;
            }
        }
        if( ENABLEBM ) {
            my $bm = $query->param( 'benchmark' );
            if( $bm ) {
                open(IF, "<$bm") || die "Benchmark query $bm retrieve failed";
                undef $/;
                my $blah = <IF>;
                close(IF);
                my ( $VAR1, $VAR2, $VAR3, $VAR4 );
                eval $blah;
                ( $query, $pathInfo, $user, $url ) =
                  ( $$VAR1, $VAR2, $VAR3, $VAR4 );
            }
        }
    }

    my $session = new TWiki( $pathInfo, $user, $topic, $url,
                             $query, $scripted );

    $Error::Debug = 1 if DEBUG; # comment out in production
    try {
        eval "use $class";
        my $m = "$class"."::$method";
        no strict 'refs';
        &$m( $session );
        use strict 'refs';
    } catch TWiki::UI::OopsException with {
        my $e = shift;
        my $url = $session->getOopsUrl( $e->{-web},
                                        $e->{-topic},
                                        "oops$e->{-template}",
                                        $e->{-param1},
                                        $e->{-param2},
                                        $e->{-param3},
                                        $e->{-param4} );
        $session->redirect( undef, $url );
    } catch Error::Simple with {
        my $e = shift;
        print "Content-type: text/plain\n\n";
        print $e->stringify();
    }
}

=pod twiki

---+++ redirect( $url, ... )
Generate a CGI redirect unless (1) $session->{cgiQuery} is undef or
(2) $query->param('noredirect') is set to any value. Thus a redirect is
only generated when in a CGI context. The ... parameters are
concatenated to the message written when printing to STDOUT, and are
ignored for a redirect.

=cut

sub redirect {
    my ($session, $url ) = @_;
    assert(ref($session) eq "TWiki") if DEBUG;

    my $query = $session->{cgiQuery};

    if ( $query && $query->param( 'noredirect' )) {
        my $content = join(" ", @_) . " \n";
        $session->writeHeader( $query, length( $content ) );
        print $content;
    } elsif ( $query ) {
        $session->redirect( $query, $url );
    }
}

=pod twiki

---+++ checkWebExists( $web, $topic )
Check if the web exists. If it doesn't, will throw an oops exception.

=cut

sub checkWebExists {
    my ( $session, $webName, $topic ) = @_;
    assert(ref($session) eq "TWiki") if DEBUG;

    unless ( $session->{store}->webExists( $webName ) ) {
        throw
          TWiki::UI::OopsException( $webName,
                                    $topic,
                                    "noweb",
                                    "ERROR $webName.$topic web does not exist" );
    }
}

=pod twiki

---+++ topicExists( $session, $web, $topic, $op ) => boolean
Check if the given topic exists, throwing an OopsException
if it doesn't. $op is %PARAM1% in the "oopsnotopic" template.

=cut

sub checkTopicExists {
    my ( $session, $webName, $topic, $op ) = @_;
    assert(ref($session) eq "TWiki") if DEBUG;

    unless( $session->{store}->topicExists( $webName, $topic )) {
        throw TWiki::UI::OopsException( $webName, $topic, "notopic", $op );
    }
}

=pod twiki

---+++ checkMirror( $session, $web, $topic )
Checks if this web is a mirror web, throwing an OopsException
if it is.

=cut

sub checkMirror {
    my ( $session, $webName, $topic ) = @_;
    assert(ref($session) eq "TWiki") if DEBUG;

    my( $mirrorSiteName, $mirrorViewURL ) =
      $session->readOnlyMirrorWeb( $webName );

    return unless ( $mirrorSiteName );

    throw TWiki::UI::OopsException( $webName, $topic,
                                    "mirror",
                                    $mirrorSiteName,
                                    $mirrorViewURL );
}

=pod twiki

---+++ checkAccess( $web, $topic, $mode, $user )
Check if the given mode of access by the given user to the given
web.topic is permissible, throwing a TWiki::UI::OopsException if not.

=cut

sub checkAccess {
    my ( $session, $web, $topic, $mode, $user ) = @_;
    assert(ref($session) eq "TWiki") if DEBUG;

    unless( $session->{security}->checkAccessPermission( $mode, $user, "",
                                                         $topic, $web )) {
        throw
          TWiki::UI::OopsException( $web,
                                    $topic,
                                    "access$mode" );
    }
}

=pod twiki

---+++ checkAdmin( $web, $topic, $user ) => boolean
Check if the user is an admin. If they are not, throw an
OopsException.

=cut

sub checkAdmin {
    my ( $session, $webName, $topic, $user ) = @_;
    assert(ref($session) eq "TWiki") if DEBUG;

    unless( $session->{security}->userIsInGroup( $user,
                                                 $TWiki::superAdminGroup )) {
        throw TWiki::UI::OopsException( $webName, $topic, "accessgroup",
                                        "$TWiki::mainWebname.$TWiki::superAdminGroup" );
    }
}

=pod

---++ sub readTemplateTopic (  $theTopicName  )

Read a topic from the TWiki web, or if that fails from the current
web.

=cut

sub readTemplateTopic {
    my( $session, $theTopicName ) = @_;
    assert(ref($session) eq "TWiki") if DEBUG;

    $theTopicName =~ s/$TWiki::securityFilter//go;    # zap anything suspicious

    # try to read in current web, if not read from TWiki web

    my $web = $TWiki::twikiWebname;
    if( $session->{store}->topicExists( $session->{webName}, $theTopicName ) ) {
        $web = $session->{webName};
    }
    return $session->{store}->readTopic( $session->{wikiUserName}, $web, $theTopicName, undef, 0 );
}

1;
