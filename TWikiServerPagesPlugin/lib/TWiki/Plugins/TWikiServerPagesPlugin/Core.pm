# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2010 Peter Thoeny, peter@thoeny.org and TWiki
# Contributors.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.
#
# =========================
#
# This is the core module of the TWikiServerPagesPlugin.

package TWiki::Plugins::TWikiServerPagesPlugin::Core;

# =========================
use vars qw(
        $vars
    );

undef $vars;

# =========================
sub VarGET
{
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    my $rawParam = $params->{_RAW};
    my $text = "TWiki::Plugins::TWikiServerPagesPlugin::Core::VarGET( $rawParam ) called";
    return $text;
}

# =========================
sub VarSET
{
    my ( $session, $params, $theTopic, $theWeb ) = @_;
    my $rawParam = $params->{_RAW};
    my $text = "TWiki::Plugins::TWikiServerPagesPlugin::Core::VarSET( $rawParam ) called";
    return $text;  
}

1;

# EOF
