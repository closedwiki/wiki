# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2010-2011 Peter Thoeny, peter@thoeny.org
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
# This is the core module of the SetGetPlugin.

package TWiki::Plugins::SetGetPlugin::Core;

# =========================
sub new {
    my ( $class, $debug ) = @_;

    my $this;
    $this->{Debug} = $debug;
    $this->{Vars} = undef;

    TWiki::Func::writeDebug( "- SetGetPlugin constructor" ) if $this->{Debug};
    bless( $this, $class );
    return $this;
}

# =========================
sub VarGET
{
    my ( $this, $session, $params, $topic, $web ) = @_;
    my $name  = _sanitizeName( $params->{_DEFAULT} );
    return '' unless( $name );
    if( $params->{topic} ) {
        $topic = $params->{topic};
        ( $web, $topic ) = TWiki::Func::normalizeWebTopicName( $web, $topic );
    }
    if( defined $this->{Vars}{$name} ) {
        return $this->{Vars}{$name};
    }
    return '';
}

# =========================
sub VarSET
{
    my ( $this, $session, $params, $topic, $web ) = @_;
    my $name  = _sanitizeName( $params->{_DEFAULT} );
    return '' unless( $name );
    my $value = $params->{value};
    if( $params->{topic} ) {
        $topic = $params->{topic};
        ( $web, $topic ) = TWiki::Func::normalizeWebTopicName( $web, $topic );
    }
    if( defined $value ) {
        $this->{Vars}{$name} = $value;
    }
    return '';
}

# =========================
sub _sanitizeName
{
    my ( $name ) = @_;
    $name = '' unless( defined $name );
    $name =~ s/[^a-zA-Z0-9\-]/_/go;
    $name =~ s/_+/_/go;
    return $name;
}

# =========================
1;
