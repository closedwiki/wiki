# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2010-2011 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2010-2011 TWiki Contributors
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
# This is the core module of the PingPlugin.

package TWiki::Plugins::PingPlugin::Core;

use Net::Ping;

# =========================
sub new {
    my ( $class, $debug ) = @_;

    my $this = {
          Debug          => $debug
        };
    bless( $this, $class );
    TWiki::Func::writeDebug( "- PingPlugin Core constructor" ) if $this->{Debug};

    return $this;
}

# =========================
sub VarPING
{
    my ( $this, $session, $params, $topic, $web ) = @_;
    TWiki::Func::writeDebug( "- PingPlugin enter VarPING" ) if $this->{Debug};

    my $ret = '';
    my $format = '';
    my $hold = '';
    my $host = $params->{host};
    &TWiki::Func::writeDebug( "- ${pluginName}::VarPING() host: $host" ) if $this->{Debug};
    return '' unless( $host );
    my $wait = $params->{wait} || 5;
    &TWiki::Func::writeDebug( "- ${pluginName}::VarPING() wait: $wait" ) if $this->{Debug};

    if( defined $params->{format} ) {
        $format = $params->{format};
    } else {
        $format = "%\$color%\$host%ENDCOLOR%";
    }
    &TWiki::Func::writeDebug( "- ${pluginName}::VarPING() format: $format" ) if $this->{Debug};

    unless ($wait =~ /^-?[0-9]+$/)
    {
        return qq(%RED% PING{host="$host" wait="$wait"} : Wait value not a number %ENDCOLOR%);
    }

    # PING CODE
    $p = Net::Ping->new();
    if ( $p->ping($host, $wait) )
    {
	$result = "1";
        $color = "GREEN";
        $hold = $format;
        $hold =~ s/\$color/$color/g;
        $hold =~ s/\$host/$host/g;
        $hold =~ s/\$result/$result/g;
        $ret = "$hold";
    }
    else
    {
	$result = "0";
        $color = "RED";
        $hold = $format;
        $hold =~ s/\$color/$color/g;
        $hold =~ s/\$host/$host/g;
        $hold =~ s/\$result/$result/g;
        $ret = "$hold";
    }

    $p->close();

    #$ret = TWiki::Func::expandCommonVariables($ret, $topic, $web);
    $ret = &TWiki::Func::expandCommonVariables($ret);

    return $ret;
}

# =========================
# =========================
1;
