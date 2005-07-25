# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Copyright (C) 2005 Greg Abbas, twiki@abbas.org
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

---+ package TWiki::Client::ApacheLogin
Redirect to a script to ask Apache to ask for a username & password.

Subclass of TWiki::Client::NoLogin; see that class for documentation of the
methods of this class.

=cut

package TWiki::Client::ApacheLogin;

use strict;
use Assert;

@TWiki::Client::ApacheLogin::ISA = qw( TWiki::Client );

sub new {
    my( $class, $twiki ) = @_;
    my $this = bless( $class->SUPER::new($twiki), $class );
    $this->{canLogin} = 1;
    return $this;
}

sub authenticate {
    my $this = shift;

    my $twiki = $this->{twiki};
    my $query = $twiki->{cgiQuery};

    # Had an access control violation. See if there is an 'auth' version
    # of this script, may be a result of not being logged in.
    my $script = $ENV{SCRIPT_FILENAME};
    $script =~ s/^(.*\/)([^\/]+)($TWiki::cfg{ScriptSuffix})?$/$1/o;
    my $scriptPath = $1;
    my $scriptName = $2;
    $script .= $scriptPath.$scriptName.'auth'.$TWiki::cfg{ScriptSuffix};
    if( ! $query->remote_user() && -e $script ) {
        my $url = $ENV{REQUEST_URI};
        if( $url && $url =~ s/\/$scriptName/\/${scriptName}auth/ ) {
            # $url i.e. is "twiki/bin/view.cgi/Web/Topic?cms1=val1&cmd2=val2"
            $url = $twiki->{urlHost}.$url;
        } else {
            # If REQUEST_URI is rewritten and does not contain the script
            # name, try looking at the CGI environment variable
            # SCRIPT_NAME.
            #
            # Assemble the new URL using the host, the changed script name,
            # the path info, and the query string.  All three query
            # variables are in the list of the canonical request meta
            # variables in CGI 1.1.
            $scriptPath     = $ENV{'SCRIPT_NAME'};
            my $pathInfo    = $ENV{'PATH_INFO'};
            my $queryString = $ENV{'QUERY_STRING'};
            $pathInfo    = '/' . $pathInfo    if ($pathInfo);
            $queryString = '?' . $queryString if ($queryString);
            if( $scriptPath && $scriptPath =~ s/\/$scriptName/\/${scriptName}auth/ ) {
                $url = $twiki->{urlHost}.$scriptPath;
            } else {
                # If SCRIPT_NAME does not contain the script name
                # the last hope is to try building up the URL using
                # the SCRIPT_FILENAME.
                $url = $twiki->{urlhost}.$twiki->{scriptUrlPath}.'/'.
                    ${scriptName}.$TWiki::cfg{ScriptSuffix};
            }
            $url .= $pathInfo.$queryString;
        }
        # SMELL: this should use an exception
        $twiki->redirect( $url );
        return 1;
    }

    return 0; # can't redirect to an auth script
}

sub loginUrl {
    my $this = shift;
    my $twiki = $this->{twiki};
    my $topic = $twiki->{topicName};
    my $web = $twiki->{webName};
    return $twiki->getScriptUrl( $web, $topic, 'logon', @_ );
}

sub getUser {
    my $this = shift;
    my $query = $this->{twiki}->{cgiQuery};
    return $query->remote_user() if(defined($query));
    return undef;
}

sub checkSession {
    my $this = shift;
    my $cgisession = $this->{cgisession};
    my $query = $this->{twiki}->{cgiQuery};
    my $authUserSessionVar = $TWiki::Client::authUserSessionVar;

    $cgisession->clear() if(
        defined($cgisession) && defined($cgisession->param) &&
        defined($query) && defined( $query->remote_user() ) &&
        defined($authUserSessionVar) &&
        defined( $cgisession->param( $authUserSessionVar ) ) &&
        "" ne $query->remote_user() &&
        "" ne $cgisession->param( $authUserSessionVar ) &&
        $query->remote_user() ne $cgisession->param( $authUserSessionVar ) );
}

1;
