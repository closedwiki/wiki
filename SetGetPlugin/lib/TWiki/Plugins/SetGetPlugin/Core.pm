# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2010-2012 Peter Thoeny, peter[at]thoeny.org
# Copyright (C) 2010-2012 TWiki Contributors
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

    my $this = {
          Debug          => $debug,
          VolatileVars   => undef,
          PersistentVars => undef,
          StoreFile      => TWiki::Func::getWorkArea( 'SetGetPlugin' ) . "/persistentvars.dat",
          StoreTimeStamp => 0,
        };
    bless( $this, $class );
    TWiki::Func::writeDebug( "- SetGetPlugin Core constructor" ) if $this->{Debug};

    $this->_loadPersistentVars();

    return $this;
}

# =========================
sub VarDUMP
{
    my ( $this, $params ) = @_;
    my $name  = _sanitizeName( $params->{_DEFAULT} );
    TWiki::Func::writeDebug( "- SetGetPlugin DUMP ($name)" ) if $this->{Debug};
    #return '' unless( $name );

    my $value = '';
    my $hold = '';
    my $sep = '';

    if( defined $params->{format} ) {
        $format = $params->{format};
    } else {
        $format = "name: \$name, value: \$value <br />";
    }

    if( defined $params->{separator} ) {
        $sep = $params->{separator};
    } else {
        $sep = "\n";
    }

    $sep =~ s/\$n/\n/g;
    while( my ($k, $v) = each %{$this->{PersistentVars}} ) {
        $hold = $format;
        $hold =~ s/\$name/$k/g;
        $hold =~ s/\$key/$k/g; # undocumented for compatibility
        $hold =~ s/\$value/$v/g;
        $value .= "$hold$sep";
    }
    $value =~ s/$sep$//;

    return $value;
}

# =========================
sub VarGET
{
    my ( $this, $params ) = @_;
    my $name  = _sanitizeName( $params->{_DEFAULT} );
    TWiki::Func::writeDebug( "- SetGetPlugin GET ($name)" ) if $this->{Debug};
    return '' unless( $name );

    my $value = '';
    my $isDefined = 0;
    my $isPersistent = 0;
    my $useDefault = 0;
    if( defined $this->{VolatileVars}{$name} ) {
        $isDefined = 1;
        $value = $this->{VolatileVars}{$name};
        TWiki::Func::writeDebug( "-   set volatile -> $value" ) if $this->{Debug};

    } elsif( defined $this->{PersistentVars}{$name} ) {
        $isDefined = 1;
        $isPersistent = 1;
        $value = $this->{PersistentVars}{$name};
        TWiki::Func::writeDebug( "-   get persistent -> $value" ) if $this->{Debug};

    } elsif( defined $params->{default} ) {
        $value = $params->{default};
        $useDefault = 1;
    }

    if( defined $params->{format} && ! $useDefault ) {
        my $v = $value;
        $value = $params->{format};
        $value =~ s/\$name/$name/g;
        $value =~ s/\$value/$v/g;
        $value =~ s/\$isdefined/$isDefined/g;
        $value =~ s/\$isset/_isTrue( $v )/ge;
        $value =~ s/\$ispersistent/$isPersistent/g;
        $value = TWiki::Func::decodeFormatTokens( $value );
    }

    return $value;
}

# =========================
sub VarSET
{
    my ( $this, $params ) = @_;
    my $name  = _sanitizeName( $params->{_DEFAULT} );
    TWiki::Func::writeDebug( "- SetGetPlugin SET ($name)" ) if $this->{Debug};
    return '' unless( $name );
    my $value = $params->{value};
    return '' unless( defined $value );

    my $remember = $params->{remember} || 0;
    if( $remember && ! ( $remember =~ /^off$/i ) ) {
        if( defined $this->{PersistentVars}{$name} && $value eq $this->{PersistentVars}{$name} ) {
                TWiki::Func::writeDebug( "-   eliding set persistent -> $value" ) if $this->{Debug};
        } else {
                $this->_savePersistentVar( $name, $value );
        }

    } else {
        TWiki::Func::writeDebug( "-   set volatile -> $value" ) if $this->{Debug};
        $this->{VolatileVars}{$name} = $value;
    }
    return '';
}

# =========================
sub _isTrue {
    my( $value ) = @_;
    return 0 unless( defined( $value ) );
    $value =~ s/^\s*(.*?)\s*$/$1/gi;
    $value =~ s/off//gi;
    $value =~ s/no//gi;
    $value =~ s/false//gi;
    return ( $value ) ? 1 : 0;
}

# =========================
sub _loadPersistentVars
{
    my ( $this ) = @_;

    # check if store is newer, load persistent vars if needed
    my $timeStamp = ( stat( $this->{StoreFile} ) )[9];
    if( defined $timeStamp && $timeStamp != $this->{StoreTimeStamp} ) {
        $this->{StoreTimeStamp} = $timeStamp;
        my $text = TWiki::Func::readFile( $this->{StoreFile} );
        $text =~ /^(.*)$/gs; # untaint, it's safe
        $text = $1;
        $this->{PersistentVars} = eval $text;
    }
}

# =========================
sub _savePersistentVar
{
    my ( $this, $name, $value ) = @_;

    # FIXME: Do atomic transaction to avoid race condition
    $this->_loadPersistentVars();            # re-load latest from disk in case updated
    $this->{PersistentVars}{$name} = $value; # set variable
    require Data::Dumper;
    my $text = Data::Dumper->Dump([$this->{PersistentVars}], [qw(PersistentVars)]);
    TWiki::Func::saveFile( $this->{StoreFile}, $text ) ;
    $this->{StoreTimeStamp} = ( stat( $this->{StoreFile} ) )[9];
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
