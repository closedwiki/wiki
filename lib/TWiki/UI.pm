# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki::UI

Service functions used by the UI packages

=cut

package TWiki::UI;

use strict;
use Error qw( :try );
use Assert;
use CGI::Carp qw( fatalsToBrowser );
use CGI qw( :cgi -any );
use TWiki;
use TWiki::OopsException;

=pod

---++ StaticMethod run( \&method )

Entry point for execution of a UI function. The parameter is a
reference to the method.

=cut

sub run {
    my $method = shift;

    my ( $query, $pathInfo, $user, $url, $topic );
    my $scripted = 0;

    # Use unbuffered IO
    $| = 1;

    if( DEBUG || $TWiki::cfg{WarningsAreErrors} ) {
        # For some mysterious reason if this handler is defined
        # in 'new TWiki' it gets lost again before we get here
        $SIG{__WARN__} = sub { die @_; };
    }

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
        # To benchmark a script, put the following lines into
        # the top level CGI script.
        # use Benchmark qw(:all :hireswallclock);
        # use vars qw( $begin );
        # BEGIN{$begin=new Benchmark;}
        # END{print STDERR 'Total '.timestr(timediff(new Benchmark,$begin))."\n";}
        #
        # and uncomment the following lines and the lines at ****:
        # my $bm = $query->param( 'benchmark' );
        # if ( $bm ) {
        #     eval 'use Data::Dumper;';
        #     open(OF, ">$bm") || throw Error::Simple( 'Store failed' );
        #     print OF Dumper(\$query, $pathInfo, $user, $url);
        #     close(OF);
        # }
    } else {
        # script is called by cron job or user
        $query = new CGI( '' );
        $scripted = 1;
        $user = '';
        $url = '';
        $topic = '';
        $pathInfo = '';
        while( scalar( @ARGV )) {
            my $arg = shift( @ARGV );
            if ( $arg =~ /^-?([A-Za-z0-9_]+)$/o ) {
                my $name = $1;
                my $arg = shift( @ARGV );
                if( $name eq 'user' ) {
                    $user = $arg;
                } else {
                    $query->param( $name => $arg );
                }
            } else {
                $pathInfo = $arg;
            }
        }
        # Benchmark code ****
        # my $bm = $query->param( 'benchmark' );
        # if( $bm ) {
        #     open(IF, "<$bm") || die "Benchmark query $bm retrieve failed";
        #     undef $/;
        #     my $dump = <IF>;
        #     close(IF);
        #     my ( $VAR1, $VAR2, $VAR3, $VAR4 );
        #     eval $dump;
        #     ( $query, $pathInfo, $user, $url ) =
        #         ( $$VAR1, $VAR2, $VAR3, $VAR4 );
        # }
    }

    my $script = $ENV{'SCRIPT_FILENAME'};
    if( $ENV{'REDIRECT_STATUS'} &&
        $ENV{'REDIRECT_STATUS'} eq '401'
        && $script !~/\boops\b/ ) {
        # bail out if authentication failed and this isn't an
        # oops script. The redirect is probably bogus.
        die "Trying to redirect to $script on authentication failure; this is not permitted. The target must be an oops.";
    }

    my $session = new TWiki( $pathInfo, $user, $topic, $url, $query );

    # comment out in production version
    $Error::Debug = 1;
    local $SIG{__DIE__} = sub { Carp::confess $_[0] };
    # end of comment out in production version

    try {
        &$method( $session );
    } catch TWiki::AccessControlException with {
        my $e = shift;
        # Had an access control violation. See if there is an 'auth' version
        # of this script, may be a result of not being logged in.
        my $url;
        $script =~ s/^(.*\/)([^\/]+)($TWiki::cfg{ScriptSuffix})?$/$1/;
        my $scriptPath = $1;
        my $scriptName = $2;
        $script .= "$scriptPath${scriptName}auth$TWiki::cfg{ScriptSuffix}";
        if( ! $query->remote_user() && -e $script ) {
            $url = $ENV{REQUEST_URI};
            if( $url && $url =~ s/\/$scriptName/\/${scriptName}auth/ ) {
                # $url i.e. is "twiki/bin/view.cgi/Web/Topic?cms1=val1&cmd2=val2"
                $url = $session->{urlHost}.$url;
            } else {
                # If REQUEST_URI is rewritten and does not contain the script
                # name, try looking at the CGI environment variable
                # SCRIPT_NAME.
                #
                # Assemble the new URL using the host, the changed script name,
                # the path info, and the query string.  All three query
                # variables are in the list of the canonical request meta
                # variables in CGI 1.1.
                $scriptPath      = $ENV{'SCRIPT_NAME'};
                my $pathInfo    = $ENV{'PATH_INFO'};
                my $queryString = $ENV{'QUERY_STRING'};
                $pathInfo    = '/' . $pathInfo    if ($pathInfo);
                $queryString = '?' . $queryString if ($queryString);
                if( $scriptPath && $scriptPath =~ s/\/$scriptName/\/${scriptName}auth/ ) {
                    $url = $session->{urlHost}.$scriptPath;
                } else {
                    # If SCRIPT_NAME does not contain the script name
                    # the last hope is to try building up the URL using
                    # the SCRIPT_FILENAME.
                    $url = $session->{urlhost}.$session->{scriptUrlPath}.'/'.
                      ${scriptName}.$TWiki::cfg{ScriptSuffix};
                }
                $url .= $pathInfo.$queryString;
            }
            $session->redirect( $url );
        } else {
            $url = $session->getOopsUrl( 'accessdenied',
                                         def => 'topic_access',
                                         web => $e->{web},
                                         topic => $e->{topic},
                                         params => [ $e->{mode},
                                                     $e->{reason} ] );
        }
        $session->redirect( $url );

    } catch TWiki::OopsException with {
        my $e = shift;
        if( $e->{keep} ) {
            # must keep params from the query, so can't use redirect
            require TWiki::UI::Oops;
            $e->{template} = 'oops'.$e->{template};
            TWiki::UI::Oops::oops( $session, $e->{web}, $e->{topic},
                                   $session->{cgiQuery}, $e );
        } else {
            # no need to keep params, so can use a redirect
            my $url = $session->getOopsUrl( $e );
            $session->redirect( $url );
        }

    } catch Error::Simple with {
        my $e = shift;
        print "Content-type: text/plain\n\n";
        print $e->stringify();
    };
}

=pod twiki

---++ StaticMethod checkWebExists( $session, $web, $topic, $op )

Check if the web exists. If it doesn't, will throw an oops exception.
 $op is the user operation being performed.

=cut

sub checkWebExists {
    my ( $session, $webName, $topic, $op ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;

    unless ( $session->{store}->webExists( $webName ) ) {
        throw
          TWiki::OopsException( 'accessdenied',
                                def => 'no_such_web',
                                web => $webName,
                                topic => $topic,
                                params => $op );
    }
}

=pod

---++ StaticMethod topicExists( $session, $web, $topic, $op ) => boolean
Check if the given topic exists, throwing an OopsException
if it doesn't. $op is the user operation being performed.

=cut

sub checkTopicExists {
    my ( $session, $webName, $topic, $op ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;

    unless( $session->{store}->topicExists( $webName, $topic )) {
        throw TWiki::OopsException( 'accessdenied',
                                    def => 'no_such_topic',
                                    web => $webName,
                                    topic => $topic,
                                    params => $op );
    }
}

=pod twiki

---++ StaticMethod checkMirror( $session, $web, $topic )
Checks if this web is a mirror web, throwing an OopsException
if it is.

=cut

sub checkMirror {
    my ( $session, $webName, $topic ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;

    my( $mirrorSiteName, $mirrorViewURL ) =
      $session->readOnlyMirrorWeb( $webName );

    return unless ( $mirrorSiteName );

    throw TWiki::OopsException( 'mirror',
                                web => $webName,
                                topic => $topic,
                                params => [ $mirrorSiteName,
                                            $mirrorViewURL ] );
}

=pod twiki

---++ StaticMethod checkAccess( $web, $topic, $mode, $user )
Check if the given mode of access by the given user to the given
web.topic is permissible, throwing a TWiki::OopsException if not.

=cut

sub checkAccess {
    my ( $session, $web, $topic, $mode, $user ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;

    unless( $session->{security}->checkAccessPermission( $mode, $user, '',
                                                         $topic, $web )) {
        throw TWiki::OopsException( 'accessdenied',
                                    def => 'topic_access',
                                    web => $web,
                                    topic => $topic,
                                    params =>
                                    [ $mode,
                                      $session->{security}->getReason()]);
    }
}

=pod

---++ StaticMethod readTemplateTopic ( $session, $theTopicName  )

Read a topic from the TWiki web, or if that fails from the current
web.

=cut

sub readTemplateTopic {
    my( $session, $theTopicName ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;

    $theTopicName =~ s/$TWiki::cfg{NameFilter}//go;    # zap anything suspicious

    # try to read in current web, if not read from TWiki web

    my $web = $TWiki::cfg{SystemWebName};
    if( $session->{store}->topicExists( $session->{webName}, $theTopicName ) ) {
        $web = $session->{webName};
    }
    return $session->{store}->readTopic( $session->{user}, $web, $theTopicName, undef );
}

1;
