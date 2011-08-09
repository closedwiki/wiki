# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2011 Peter Thoeny, peter[at]thoeny.org
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

my @apacheConfLocations = (
    '/etc/httpd/conf.d',             # RHEL / Fedora / CentOS
    '/etc/apache2/conf.d/',          # Debian / Ubuntu / openSUSE
    '/usr/local/apache/conf.d',      # Cygwin
    '/usr/local/apache/conf/conf.d',
    '/usr/local/apache2/conf.d',
    '/usr/local/httpd/conf.d',
  );

my $checkStatusJS = << 'ENDJS';
<!--<pre>-->
<script type="text/javascript">
function ajaxStatusCheck( urlStr, queryStr ) {
  var request = false;
  var self = this;
  if (window.XMLHttpRequest) {
    self.request = new XMLHttpRequest();
  } else if (window.ActiveXObject) {
    self.request = new ActiveXObject("Microsoft.XMLHTTP");
  }
  self.request.open( "POST", urlStr, true );
  self.request.setRequestHeader( "Content-Type", "application/x-www-form-urlencoded" );
  self.request.onreadystatechange = function() {
    if (self.request.readyState == 4) {
      if( self.request.responseText.search( "backup_status:0" ) >= 0 ) {
          location = '%SCRIPTURLPATH{view}%/%WEB%/%TOPIC%';
      } else {
          checkStatusWithDelay();
      }
    }
  };
  self.request.send( queryStr );
};
function checkStatusWithDelay( ) {
  setTimeout(
    "ajaxStatusCheck( '%SCRIPTURLPATH{backuprestore}%', 'action=check_status' )",
    60000
  );
};
checkStatusWithDelay();
</script>
<!--</pre>-->
ENDJS

# Note: To remain compatible with older TWiki releases, do not use any TWiki internal
# modules except LocalSite.cfg, and that file is optional too.

#==================================================================
sub new {
    my ( $class, $this ) = @_;

    $this->{Debug}        = $TWiki::cfg{Plugins}{BackupRestorePlugin}{Debug} || 0;
    $this->{BackupDir}    = $TWiki::cfg{Plugins}{BackupRestorePlugin}{BackupDir} || '/tmp';
    $this->{TempDir}      = $TWiki::cfg{Plugins}{BackupRestorePlugin}{TempDir} || '/tmp';
    $this->{KeepNumBUs}   = $TWiki::cfg{Plugins}{BackupRestorePlugin}{KeepNumberOfBackups} || '5';
    $this->{createZipCmd} = $TWiki::cfg{Plugins}{BackupRestorePlugin}{createZipCmd} || 'zip -r';
    $this->{listZipCmd}   = $TWiki::cfg{Plugins}{BackupRestorePlugin}{listZipCmd} || 'unzip -l';
    $this->{unZipCmd}     = $TWiki::cfg{Plugins}{BackupRestorePlugin}{unZipCmd} || 'unzip -o';

    TWiki::Func::writeDebug( "- BackupRestorePlugin constructor" ) if $this->{Debug};

    bless( $this, $class );

    $this->{Location} = $this->_gatherLocation();
    $this->{SemaphorFile} = $this->{TempDir} . '/BackupRestorePlugin.dat';
    $this->{error} = '';

    return $this;
}

#==================================================================
# HIGH-LEVEL BACKUP/RESTORE METHODS
#==================================================================

#==================================================================
sub BACKUPRESTORE {
    my( $this, $session, $params, $theTopic, $theWeb ) = @_;

    my $action = $params->{action} || '';
    $this->{Debug} = 1 if( $action eq 'debug' );

    TWiki::Func::writeDebug( "- BackupRestorePlugin->BACKUPRESTORE" ) if $this->{Debug};

    my $text = '';
    if( TWiki::Func::isAnAdmin( TWiki::Func::getCanonicalUserID() ) ) {
        my $action = $params->{action} || '';
        if( $action eq 'backup_detail' ) {
            $text .= $this->_showBackupDetail( $session, $params );
        } elsif( $action eq 'create_backup' ) {
            $this->_startBackup( $session, $params );
            $text .= $this->_showBackupSummary( $session, $params );
        } elsif( $action eq 'cancel_backup' ) {
            $this->_cancelBackup( $session, $params );
            $text .= $this->_showBackupSummary( $session, $params );
        } elsif( $action eq 'delete_backup' ) {
            $this->_deleteBackup( $session, $params );
            $text .= $this->_showBackupSummary( $session, $params );
        } elsif( $action eq 'restore_backup' ) {
            $this->_restoreFromBackup( $session, $params );
            $text .= $this->_showBackupSummary( $session, $params );
        } elsif( $action eq 'debug' ) {
            $text .= $this->_debugBackup( $session, $params );
        } else {
            $text .= $this->_showBackupSummary( $session, $params );
        }

    } else {
        $this->{error} = 'ERROR: Only members of the %USERSWEB%.TWikiAdminGroup can see the backup & restore console.';
    }

    $text = $this->_renderError() . $text;
    return $text;
}

#==================================================================
sub _showBackupSummary {
    my( $this, $session, $params ) = @_;

    my $text = "";
    my( $inProgress, $fileName ) = $this->_checkBackupState();
    if( $inProgress ) {
        $text .= "$checkStatusJS\n";
        $text .= "| *Backup* | *Action* |\n";
        $text .= '| %ICON{processing}% ' . $fileName . '| Creating backup now, please wait. '
               . '<form action="%SCRIPTURL{view}%/%WEB%/%TOPIC%">'
               . '<input type="hidden" name="action" value="cancel_backup" />'
               . '<input type="submit" value="Cancel" class="twikiButton" />'
               . '</form> |' . "\n";
    } else {
        $text .= "| *Backup* | *Action* |\n";
        $text .= '| %ICON{newtopic}% ' . $fileName
               . '| <form action="%SCRIPTURL{view}%/%WEB%/%TOPIC%">'
               . '<input type="hidden" name="action" value="create_backup" />'
               . '<input type="submit" value="Create backup now" class="twikiButton" />'
               . '</form> |' . "\n";
    }
    my @backupFiles = $this->_listAllBackups();
    if( scalar @backupFiles ) {
        foreach $fileName ( reverse sort @backupFiles ) {
            $text .= '| %ICON{zip}% [[%SCRIPTURL{view}%/%WEB%/%TOPIC%/' . "$fileName][$fileName]] "
                   . '| <form action="%SCRIPTURL{view}%/%WEB%/%TOPIC%">'
                   . '<input type="hidden" name="action" value="backup_detail" />'
                   . '<input type="hidden" name="file" value="' . $fileName . '" />'
                   . '<input type="submit" value="Details / Restore..." class="twikiButton" />'
                   . '</form> '
                   . '<form action="%SCRIPTURL{view}%/%WEB%/%TOPIC%">'
                   . '<input type="hidden" name="action" value="delete_backup" />'
                   . '<input type="hidden" name="file" value="' . $fileName . '" />'
                   . '<input type="submit" value="Delete..." class="twikiButton" onClick="return confirm('
                   . "'Are you sure you want to delete $fileName?'" . ');" />'
                   . '</form> |' . "\n";
        }
    } else {
        $text .= "| (no existing backups ) | |\n";
    }
    return $text;
}

#==================================================================
sub _showBackupDetail {
    my( $this, $session, $params ) = @_;

    my $text = '';
    my $fileName = $params->{file};
    $text .= "(file: $fileName)";
    return $text;
}

#==================================================================
sub _debugBackup {
    my( $this, $session, $params ) = @_;

    my $text = "Debug BACKUPRESTORE, user " . TWiki::Func::getCanonicalUserID() . ", base web $this->{BaseWeb}";
    $text .= "<br /> " . $this->_testZipMethods();
    return $text;
}


#==================================================================
# MID-LEVEL BACKUP/RESTORE METHODS
#==================================================================

#==================================================================
sub _checkBackupState {
    my( $this ) = @_;
    return( -e $this->{SemaphorFile}, $this->_buildFileName() );
}

#==================================================================
sub _startBackup {
    my( $this, $session, $params ) = @_;

    if( -e $this->{SemaphorFile} ) {
        $this->{error} = 'ERROR: Backup is already in progress.';
    } else {
        my $text = "File: " . $this->_buildFileName() . "\n";
        _saveFile( $this->{SemaphorFile}, $text );
        #FIXME: start backup
    }
}

#==================================================================
sub _cancelBackup {
    my( $this, $session, $params ) = @_;

    if( -e $this->{SemaphorFile} ) {
        #FIXME: kill backup
        unlink( $this->{SemaphorFile} );
    } else {
        $this->{error} = 'ERROR: No backup in progress.';
    }
}

#==================================================================
sub _deleteBackup {
    my( $this, $session, $params ) = @_;

    return $this->_deleteZip( $params->{file} );
}

#==================================================================
sub _restoreFromBackup {
    my( $this, $session, $params ) = @_;
    #FIXME
}


#==================================================================
# LOW-LEVEL METHODS
#==================================================================

#==================================================================
sub _renderError {
    my( $this ) = @_;

    return '' unless $this->{error};

    my $text = '<div style="background-color: #f0f0f4; padding: 10px 20px">'
             . $this->{error}
             . "</div>\n";
    $this->{error} = '';
    return $text;
}

#==================================================================
sub _buildFileName {
    my( $this ) = @_;
    my( $sec, $min, $hour, $day, $mon, $year ) = localtime( time() );
    my $text = 'twiki-backup-';
    $text .= sprintf( "%.4u", $year + 1900 ) . '-';
    $text .= sprintf( "%.2u", $mon + 1 ) . '-';
    $text .= sprintf( "%.2u", $day ) . '-';
    $text .= sprintf( "%.2u", $hour ) . '-';
    $text .= sprintf( "%.2u", $min ) . '.zip';
    return $text;
}

#==================================================================
sub _gatherLocation {
    my( $this ) = @_;

    my $loc;

    # discover TWiki bin dir
    my $binDir = $ENV{SCRIPT_FILENAME} || '';
    $binDir =~ s|(.*)[\\/]+.*|$1|;       # cut off script to get name of bin dir
    unless( $binDir )  {
        # last resort to discover bin dir
        require Cwd;
        import Cwd qw( cwd );
        $binDir;
    }

    # discover TWiki root dir
    my $rootDir = $TWiki::cfg{DataDir} || $binDir;
    $rootDir =~ s|(.*)[\\/]+.*|$1|;      # go one directory up
    $loc->{RootDir} = $rootDir;

    # discover common TWiki directories
    $loc->{DataDir}    = $TWiki::cfg{DataDir} || "$rootDir/data";
    $loc->{PubDir}     = $TWiki::cfg{PubDir}  || "$rootDir/pub";
    $loc->{WorkingDir} = $TWiki::cfg{WorkingDir} || '';

    # discover twiki/bin/LocalLib.cfg
    $loc->{LocalLib}   = "$binDir/LocalLib.cfg" if( -e "$binDir/LocalLib.cfg" );

    # discover twiki/lib/LocalSite.cfg
    foreach my $dir ( @INC ) {
        if( -e "$dir/LocalSite.cfg" ) {
            $loc->{LocalSite} = "$dir/LocalSite.cfg";
            last;
        }
    }
    if( !$loc->{LocalSite} && -e "$rootDir/lib/LocalSite.cfg" ) {
        $loc->{LocalSite} =      "$rootDir/lib/LocalSite.cfg";
    }

    # discover apache conf file twiki.conf
    foreach my $dir ( @apacheConfLocations ) {
        if( -e "$dir/twiki.conf" ) {
            $loc->{ApacheConf} = "$dir/twiki.conf";
            last;
        }
    }

    return $loc;
}

#==================================================================
sub _testZipMethods {
    my( $this ) = @_;

    my $text = '';
    $text .= "\n<br />===== Dirs <pre>\n"
           . "-BaseTopic:    $this->{BaseTopic}\n"
           . "-BaseWeb:      $this->{BaseWeb}\n"
           . "-Root:         $this->{Location}{RootDir}\n"
           . "-DataDir:      $this->{Location}{DataDir}\n"
           . "-PubDir:       $this->{Location}{PubDir}\n"
           . "-WorkingDir:   $this->{Location}{WorkingDir}\n"
           . "-LocalLib:     $this->{Location}{LocalLib}\n"
           . "-LocalSite:    $this->{Location}{LocalSite}\n"
           . "-ApacheConf:   $this->{Location}{ApacheConf}\n"
           . "-TempDir:      $this->{TempDir}\n"
           . "-SemaphorFile: $this->{SemaphorFile}\n"
           . "\n</pre>\n";

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
sub _readFile {
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
sub _saveFile {
    my( $name, $text ) = @_;

    unless ( open( FILE, ">$name" ) )  {
        return "Can't create file $name - $!\n";
    }
    print FILE $text;
    close( FILE );
    return '';
}

#==================================================================
1;
