# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::BackupRestorePlugin::Core;

use strict;

use File::Copy;
use TWiki::Plugins::BackupRestorePlugin::CaptureOutput qw( capture_exec capture_exec_combined );

# Note: To remain compatible with older releases, do not use any TWiki internal
# modules except LocalSite.cfg

#==================================================================
# Constants
my @createZipCmd = ( 'zip', '-r' );   # Append: zip dir1 dir2 -x exlude1 exlude2
my @listZipCmd   = ( 'unzip', '-l' ); # Append: zip
my @unZipCmd     = ( 'unzip', '-o' ); # Append: zip

#==================================================================
sub new {
    my ( $class, $this ) = @_;

    TWiki::Func::writeDebug( "- BackupRestorePlugin constructor" ) if $this->{Debug};

    # $this->
    #   {BaseTopic}  => $baseTopic,
    #   {BaseWeb}    => $baseWeb,
    #   {User}       => $user,

    $this->{Debug}        = $TWiki::cfg{Plugins}{BackupRestorePlugin}{Debug} || 0;
    $this->{BackupDir}    = $TWiki::cfg{Plugins}{BackupRestorePlugin}{BackupDir} || '/tmp';
    $this->{KeepNumBUs}   = $TWiki::cfg{Plugins}{BackupRestorePlugin}{KeepNumberOfBackups} || '5';
    $this->{createZipCmd} = $TWiki::cfg{Plugins}{BackupRestorePlugin}{createZipCmd} || 'zip -r';
    $this->{listZipCmd}   = $TWiki::cfg{Plugins}{BackupRestorePlugin}{listZipCmd} || 'unzip -l';
    $this->{unZipCmd}     = $TWiki::cfg{Plugins}{BackupRestorePlugin}{unZipCmd} || 'unzip -o';

    $this->{error} = '';

    bless( $this, $class );
    return $this;
}

#==================================================================
sub BACKUPRESTORE {
    my( $this, $session, $params, $theTopic, $theWeb ) = @_;

    TWiki::Func::writeDebug( "- BackupRestorePlugin->BACKUPRESTORE" ) if $this->{Debug};

    my $text = "Placeholder for BACKUPRESTORE, user !$this->{User}, base web $this->{BaseWeb}";
    $text .= "<br /> " . $this->_testZipMethods();
    return $text;
}

#==================================================================
sub _testZipMethods {
    my( $this ) = @_;

    my $text = '';

    $text .= "\n<br />===== Test _listAllBackups()<pre>\n"
           . join( "\n", $this->_listAllBackups() )
           . "\n</pre>Error return: $this->{error} <p />\n";

    my $zip = 'twiki-backup-2011-01-18-19-33.zip';
    my @files = ( 'data/', 'pub/Main/', 'pub/Sandbox/', 'working/',
                  '\*.svn\*', 'working\/tmp\*' );
    chdir( '/var/www/twiki' );
    $this->{error} = '';
    $text .= "<br />===== Test _createZip( $zip, " . join( ", ", @files ) . " )<pre>\n" 
           . $this->_createZip( $zip, @files ) 
           . "\n</pre>Error return: $this->{error}\n";

    $this->{error} = '';
    $text .= "<br />===== Test _listZip( $zip )<pre>\n"
           . join( "\n", $this->_listZip( $zip ) )
           . "\n</pre>Error return: $this->{error}\n";

    chdir( $this->{BackupDir} );
    $this->{error} = '';
    $text .= "<br />===== Test _unZip( $zip )<pre>\n"
           . $this->_unZip( $zip )
           . "\n</pre>Error return: $this->{error}\n";

    $this->{error} = '';
    $text .= "<br />===== Test _deleteZip( $zip )<pre>\n"
           . join( "\n", $this->_deleteZip( "$zip" ) )
           . "\n</pre>Error return: $this->{error}\n";

    $this->{error} = '';
    $text .= "<br />===== Test _deleteZip( not-exist-$zip )<pre>\n"
           . join( "\n", $this->_deleteZip( "not-exist-$zip" ) )
           . "\n</pre>Error return: $this->{error}\n";

    return $text;
}

#==================================================================
sub _listAllBackups {
    my( $this ) = @_;

    TWiki::Func::writeDebug( "- BackupRestorePlugin->_listAllBackups" ) if $this->{Debug};

    my @files = ();
    unless( opendir( DIR, $this->{BackupDir} ) ) {
        $this->{error} = "Can't open the backup directory - $!";
        return @files;
    }
    @files = grep{ /twiki-backup-.*\.zip/ }
             grep{ -f "$this->{BackupDir}/$_" }
             readdir( DIR );
    closedir( LIST ); 

    return @files;
}

#==================================================================
sub _createZip {
    my( $this, $name, @files ) = @_;

    TWiki::Func::writeDebug( "- BackupRestorePlugin->_createZip( $name, " 
      . join( ", ", @files ) . " )" ) if $this->{Debug};

    my $zipFile = "$this->{BackupDir}/$name";
    my @cmd = split( /\s+/, $this->{createZipCmd} );
    my ( $stdOut, $stdErr, $success, $exitCode ) = capture_exec( @cmd, $zipFile, @files );
    if( $exitCode ) {
        $this->{error} = "Error creating $name. $stdErr";
    }
    return;
}

#==================================================================
sub _deleteZip {
    my( $this, $name ) = @_;

    TWiki::Func::writeDebug( "- BackupRestorePlugin->_deleteZip( $name )" ) if $this->{Debug};

    my $zipFile = "$this->{BackupDir}/$name";
    unless( -e $zipFile ) {
        $this->{error} = "Backup $name does not exist";
        return;
    }
    unless( unlink( $zipFile ) ) {
        $this->{error} = "Can't delete $name - $!";
    }
    return;
}

#==================================================================
sub _listZip {
    my( $this, $name ) = @_;

    TWiki::Func::writeDebug( "- BackupRestorePlugin->_listZip( $name )" ) if $this->{Debug};

    my @files = ();
    my $zipFile = "$this->{BackupDir}/$name";
    unless( -e $zipFile ) {
        $this->{error} = "Backup $name does not exist";
        return @files;
    }
    my @cmd = split( /\s+/, $this->{listZipCmd} );
    my ( $stdOut, $stdErr, $success, $exitCode ) = capture_exec( @cmd, $zipFile );
    if( $exitCode ) {
        $this->{error} = "Error listing content of $name. $stdErr";
    }
    @files = map{ s/^\s*([0-9\-\:]+\s*){3}//; $_ }   # remove size and timestamp
             grep{ /^\s*[0-9]+\s*[0-9]+\-.*[^\/]$/ } # exclude header, footer & directories
             split( /[\n\r]+/, $stdOut );
    return @files;
}

#==================================================================
sub _unZip {
    my( $this, $name ) = @_;

    TWiki::Func::writeDebug( "- BackupRestorePlugin->_unZip( $name )" ) if $this->{Debug};

    my $zipFile = "$this->{BackupDir}/$name";
    unless( -e $zipFile ) {
        $this->{error} = "Backup $name does not exist";
        return;
    }
    my @cmd = split( /\s+/, $this->{unZipCmd} );
    my ( $stdOut, $stdErr, $success, $exitCode ) = capture_exec( @cmd, $zipFile );
    if( $exitCode ) {
        $this->{error} = "Error unzipping $name. $stdErr";
    }
    return;
}

#==================================================================
sub readFile {
    my $name = shift;
    my $data = '';
    open( IN_FILE, "<$name" ) || return '';
    local $/ = undef; # set to read to EOF
    $data = <IN_FILE>;
    close( IN_FILE );
    $data = '' unless $data; # no undefined
    return $data;
}

#==================================================================
sub saveFile {
    my( $name, $text ) = @_;

    unless ( open( FILE, ">$name" ) )  {
        return "Can't create file $name - $!\n";
    }
    print FILE $text;
    close( FILE);
    return '';
}

#==================================================================
1;
