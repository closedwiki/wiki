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
use CGI;
use TWiki;
use TWiki::UI::OopsException;

=pod

---++ StaticMethod run( $class, $method )

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
        # To benchmark a script, put the following lines into
        # the top level CGI script.
        # use Benchmark qw(:all :hireswallclock);
        # use vars qw( $begin );
        # BEGIN{$begin=new Benchmark;}
        # END{print STDERR "Total ".timestr(timediff(new Benchmark,$begin))."\n";}
        #
        # and uncomment the following lines and the lines at ****:
        # my $bm = $query->param( 'benchmark' );
        # if ( $bm ) {
        #     eval 'use Data::Dumper;';
        #     open(OF, ">$bm") || throw Error::Simple( "Store failed" );
        #     print OF Dumper(\$query, $pathInfo, $user, $url);
        #     close(OF);
        # }
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

    my $session = new TWiki( $pathInfo, $user, $topic, $url,
                             $query, $scripted );

    # comment out in production version
    $Error::Debug = 1;
    local $SIG{__DIE__} = sub { Carp::confess $_[0] };
    # end of comment out in production version

    my $m = "$class"."::$method";
    try {
        eval "use $class";
        if( $@ ) {
            die "$class compile failed: $@";
        }
        no strict 'refs';
        &$m( $session );
        use strict 'refs';
    } catch TWiki::AccessControlException with {
        my $e = shift;
        # Had an access control violation. See if there is an "auth" version
        # of this script, may be a result of not being logged in.
        my $url;
        my $script = $ENV{'SCRIPT_FILENAME'};
        $script =~ s/^(.*\/)([^\/]+)($TWiki::cfg{ScriptSuffix})?$/$1/;
        my $scriptPath = $1;
        my $scriptName = $2;
        $script .= "$scriptPath${scriptName}auth$TWiki::cfg{ScriptSuffix}";
        if( ! $query->remote_user() && -e $script ) {
            $url = $ENV{"REQUEST_URI"};
            if( $url && $url =~ s/\/$scriptName/\/${scriptName}auth/ ) {
                # $url i.e. is "twiki/bin/view.cgi/Web/Topic?cms1=val1&cmd2=val2"
                $url = "$session->{urlHost}$url";
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
                    $url = "$session->{urlHost}$scriptPath$pathInfo$queryString";
                } else {
                    # If SCRIPT_NAME does not contain the script name
                    # the last hope is to try building up the URL using
                    # the SCRIPT_FILENAME.
                    $url = "$session->{urlhost}$session->{scriptUrlPath}/${scriptName}$TWiki::cfg{ScriptSuffix}$pathInfo$queryString";
                }
            }
            $session->redirect( $url );
        } else {
            $url = $session->getOopsUrl( $e->{-web}, $e->{-topic},
                                         "oopsaccessdenied",
                                         $e->{-mode}, $e->{-reason} );
        }
        $session->redirect( $url );
    } catch TWiki::UI::OopsException with {
        my $e = shift;
        my $url = $session->getOopsUrl( $e->{-web},
                                        $e->{-topic},
                                        "oops$e->{-template}",
                                        @{$e->{-params}} );
        $session->redirect( $url );
    } catch Error::Simple with {
        my $e = shift;
        print "Content-type: text/plain\n\n";
        print $e->stringify();
    };
}

=pod twiki

---++ StaticMethod checkWebExists( $web, $topic )

Check if the web exists. If it doesn't, will throw an oops exception.

=cut

sub checkWebExists {
    my ( $session, $webName, $topic ) = @_;
    ASSERT(ref($session) eq "TWiki") if DEBUG;

    unless ( $session->{store}->webExists( $webName ) ) {
        throw
          TWiki::UI::OopsException( $webName,
                                    $topic,
                                    "noweb",
                                    "ERROR $webName.$topic web does not exist" );
    }
}

=pod twiki

---++ StaticMethod topicExists( $session, $web, $topic, $op ) => boolean
Check if the given topic exists, throwing an OopsException
if it doesn't. $op is %PARAM1% in the "oopsnotopic" template.

=cut

sub checkTopicExists {
    my ( $session, $webName, $topic, $op ) = @_;
    ASSERT(ref($session) eq "TWiki") if DEBUG;

    unless( $session->{store}->topicExists( $webName, $topic )) {
        throw TWiki::UI::OopsException( $webName, $topic, "notopic", $op );
    }
}

=pod twiki

---++ StaticMethod checkMirror( $session, $web, $topic )
Checks if this web is a mirror web, throwing an OopsException
if it is.

=cut

sub checkMirror {
    my ( $session, $webName, $topic ) = @_;
    ASSERT(ref($session) eq "TWiki") if DEBUG;

    my( $mirrorSiteName, $mirrorViewURL ) =
      $session->readOnlyMirrorWeb( $webName );

    return unless ( $mirrorSiteName );

    throw TWiki::UI::OopsException( $webName, $topic,
                                    "mirror",
                                    $mirrorSiteName,
                                    $mirrorViewURL );
}

=pod twiki

---++ StaticMethod checkAccess( $web, $topic, $mode, $user )
Check if the given mode of access by the given user to the given
web.topic is permissible, throwing a TWiki::UI::OopsException if not.

=cut

sub checkAccess {
    my ( $session, $web, $topic, $mode, $user ) = @_;
    ASSERT(ref($session) eq "TWiki") if DEBUG;

    unless( $session->{security}->checkAccessPermission( $mode, $user, "",
                                                         $topic, $web )) {
        throw TWiki::UI::OopsException( $web, $topic,
                                        "accessdenied",
                                        $mode,
                                        $session->{security}->getReason());
    }
}

=pod

---++ StaticMethod readTemplateTopic ( $session, $theTopicName  )

Read a topic from the TWiki web, or if that fails from the current
web.

=cut

sub readTemplateTopic {
    my( $session, $theTopicName ) = @_;
    ASSERT(ref($session) eq "TWiki") if DEBUG;

    $theTopicName =~ s/$TWiki::cfg{NameFilter}//go;    # zap anything suspicious

    # try to read in current web, if not read from TWiki web

    my $web = $TWiki::cfg{SystemWebName};
    if( $session->{store}->topicExists( $session->{webName}, $theTopicName ) ) {
        $web = $session->{webName};
    }
    return $session->{store}->readTopic( $session->{user}, $web, $theTopicName, undef );
}

1;
