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

---+ package TWiki::Client::TemplateLogin
Redirect to an template-based authentication page.

Subclass of TWiki::Client::NoLogin; see that class for documentation of the
methods of this class.

=cut

package TWiki::Client::TemplateLogin;

use strict;
use Assert;
use TWiki::Client;

@TWiki::Client::TemplateLogin::ISA = ( 'TWiki::Client' );

sub new {
    my( $class, $session ) = @_;

    my $this = bless( $class->SUPER::new($session), $class );
    $this->{canLogin} = 1;
    return $this;
}

sub authenticate {
    my $this = shift;

    my $twiki = $this->{twiki};
    my $query = $twiki->{cgiQuery};

    unless( $this->{sessionIsAuthenticated} ) {
        my $origurl = $query->url() . $query->path_info();
        my $url = $this->loginUrl( origurl => $origurl );
        $twiki->redirect( $url );
        # SMELL: this should use an exception. see the comment in Client.pm.
    }
    return 0;
}

sub loginUrl {
    my $this = shift;
    my $twiki = $this->{twiki};
    my $topic = $twiki->{topicName};
    my $web = $twiki->{webName};
    my $url = $twiki->getScriptUrl( $web, $topic, 'login', @_ );

    return $url;
}

1;
