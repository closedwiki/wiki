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

    if( $ENV{'GATEWAY_INTERFACE'} ) {
        # script is called by browser
        $query = new CGI;
    } else {
        # script is called by cron job or user
        $scripted = 1;
        $user = '';
        $query = new CGI( "" );
        while( scalar( @ARGV )) {
            my $arg = shift( @ARGV );
            if ( $arg =~ /^-?([A-Za-z0-9_]+)$/o ) {
                my $name = $1;
                my $arg = shift( @ARGV );
                if( $name eq 'user' ) {
                    $user = $arg;
                } else {
                    $query->param( -name => $name, -value => $arg );
                }
            } else {
                $query->path_info( $arg );
            }
        }
    }

    my $script = $ENV{'SCRIPT_FILENAME'};
    if( $ENV{'REDIRECT_STATUS'} &&
        $ENV{'REDIRECT_STATUS'} eq '401'
        && $script !~/\boops\b/ ) {
        # bail out if authentication failed and this isn't an
        # oops script. The redirect is probably bogus.
        die "Trying to redirect to $script on authentication failure; this is not permitted. The target must be an oops.";
    }

    my $session = new TWiki( $user, $query );

    local $SIG{__DIE__} = \&Carp::confess;

    # end of comment out in production version

    try {
        $session->{client}->checkAccess();
        &$method( $session );
    } catch TWiki::AccessControlException with {
        my $e = shift;
        unless( $session->{client}->forceAuthentication() ) {
            # Client did not want to authenticate, perhaps because
            # we are already authenticated 
            my $url = $session->getOopsUrl( 'accessdenied',
                                            def => 'topic_access',
                                            web => $e->{web},
                                            topic => $e->{topic},
                                            params => [ $e->{mode},
                                                        $e->{reason} ] );
            $session->redirect( $url );
        }

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
        if( DEBUG ) {
            # output the full message and stacktrace to the browser
            print $e->stringify();
        } else {
            my $mess = $e->stringify();
            print STDERR $mess;
            $session->writeWarning( $mess );
            # tell the browser where to look for more help
            print 'TWiki detected an error or attempted hack - please check your TWiki logs and webserver logs for more information.'."\n\n";
            $mess =~ s/ at .*$//s;
            # cut out pathnames from public announcement
            $mess =~ s#/[\w./]+#path#g;
            print $mess;
        }
    } otherwise {
        print "Content-type: text/plain\n\n";
        print "Unspecified error";
    };

    $session->finish();
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

---++ StaticMethod readTemplateTopic( $session, $theTopicName ) -> ( $meta, $text )

Read a topic from the TWiki web, or if that fails from the current
web.

=cut

sub readTemplateTopic {
    my( $session, $theTopicName ) = @_;
    ASSERT($session->isa( 'TWiki')) if DEBUG;

    $theTopicName =~ s/$TWiki::cfg{NameFilter}//go;

    my $web = $TWiki::cfg{SystemWebName};
    if( $session->{store}->topicExists( $session->{webName}, $theTopicName )) {
        # try to read from current web, if found
        $web = $session->{webName};
    }
    return $session->{store}->readTopic(
        $session->{user}, $web, $theTopicName, undef );
}

1;
