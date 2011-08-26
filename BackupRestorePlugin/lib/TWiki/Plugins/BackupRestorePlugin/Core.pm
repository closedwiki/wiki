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
      if( self.request.responseText.search( "backup_status: 0" ) >= 0 ) {
          location = '%SCRIPTURL%/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%';
      } else {
          checkStatusWithDelay();
      }
    }
  };
  self.request.send( queryStr );
};
function checkStatusWithDelay( ) {
  setTimeout(
    "ajaxStatusCheck( '%SCRIPTURLPATH%/backuprestore%SCRIPTSUFFIX%', 'action=status' )",
    10000
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
    $this->{KeepNumBUs}   = $TWiki::cfg{Plugins}{BackupRestorePlugin}{KeepNumberOfBackups} || '7';
    my $dir               = $TWiki::cfg{Plugins}{BackupRestorePlugin}{BackupDir} || '/tmp';
    $this->{BackupDir}    = _untaintChecked( $dir );
    $dir                  = $TWiki::cfg{Plugins}{BackupRestorePlugin}{TempDir} || '/tmp';
    $this->{TempDir}      = _untaintChecked( $dir );
    $dir                  = $TWiki::cfg{Plugins}{BackupRestorePlugin}{createZipCmd} || 'zip -r';
    $this->{createZipCmd} = _untaintChecked( $dir );
    $dir                  = $TWiki::cfg{Plugins}{BackupRestorePlugin}{listZipCmd} || 'unzip -l';
    $this->{listZipCmd}   = _untaintChecked( $dir );
    $dir                  = $TWiki::cfg{Plugins}{BackupRestorePlugin}{unZipCmd} || 'unzip -o';
    $this->{unZipCmd}     = _untaintChecked( $dir );

    bless( $this, $class );

    $this->_writeDebug( "constructor" );

    $this->{Location} = $this->_gatherLocation();
    $this->{DaemonDir} = $this->{TempDir} . '/TWiki_BackupRestorePlugin_Daemon';
    $this->_clearError();

    return $this;
}

#==================================================================
# HIGH-LEVEL BACKUP/RESTORE METHODS
#==================================================================

#==================================================================
# Callback of registerTagHandler
#==================================================================
sub BACKUPRESTORE {
    my( $this, $params ) = @_;

    my $action = $params->{action} || '';
    $this->{Debug} = 1 if( $action eq 'debug' );

    $this->_writeDebug( "BACKUPRESTORE action=$action" );

    my $accessOK = 0;
    if( $this->{ScriptType} eq 'cli' ) {
        $this->_setError( 'Note: The backup and restore console is only available in CGI context' );
    } elsif( exists( &TWiki::Func::isAnAdmin ) && exists( &TWiki::Func::getCanonicalUserID ) ) {
        $accessOK = TWiki::Func::isAnAdmin( TWiki::Func::getCanonicalUserID() );
    } else {
        $accessOK = 1;
        $this->_setError( 'WARNING: This is an older TWiki version, access to the backup and restore '
                        . 'console __is not resticted__ to the TWiki admin group. Everybody can create '
                        . 'and download backups! Disable the BackupRestorePlugin after use!' );
    }

    my $text = '';
    if( $accessOK ) {
        if( $action eq 'backup_detail' ) {
            $text .= $this->_showBackupDetail( $params );
        } elsif( $action eq 'status' ) {
            $text .= $this->_showBackupStatus( $params );
        } elsif( $action eq 'create_backup' ) {
            $this->_startBackup( $params );
            $text .= $this->_showBackupSummary( $params );
        } elsif( $action eq 'restore_backup' ) {
            $this->_startRestore( $params );
            $text .= $this->_showBackupSummary( $params );
        } elsif( $action eq 'cancel_backup' ) {
            $this->_cancelBackup( $params );
            $text .= $this->_showBackupSummary( $params );
        } elsif( $action eq 'delete_backup' ) {
            $this->_deleteBackup( $params );
            $text .= $this->_showBackupSummary( $params );
        } elsif( $action eq 'debug' ) {
            $text .= $this->_debugBackup( $params );
        } else {
            $text .= $this->_showBackupSummary( $params );
        }

    } elsif( $this->{ScriptType} eq 'cli' ) {
        # error already set
    } else {
        $this->_setError( 'ERROR: Only members of the %USERSWEB%.TWikiAdminGroup can see the backup & restore console.' );
    }

    $text = $this->_renderError() . $text;
    return $text;
}

#==================================================================
# Main entry point of backuprestore utility (cgi & cli)
#==================================================================
sub backuprestore {
    my( $this, $params ) = @_;

    my $action = $params->{action} || 'usage';
    $this->{Debug} = 1 if( $action eq 'debug' );

    $this->_writeDebug( "backuprestore, action=$action" );
    my $text = '';
    if( $action eq 'status' ) {
        print "Content-type: text/html\n\n" if( $this->{ScriptType} eq 'cgi' );
        $text .= $this->_showBackupStatus( $params );
    } elsif( $action eq 'debug' ) {
        print "Content-type: text/html\n\n" if( $this->{ScriptType} eq 'cgi' );
        $text .= $this->_debugBackup( $params );
    } elsif( $action eq 'create_backup' ) {
        print "Content-type: text/html\n\n" if( $this->{ScriptType} eq 'cgi' );
        $text .= $this->_createBackup( $params );
    } elsif( $action eq 'restore_backup' ) {
        print "Content-type: text/html\n\n" if( $this->{ScriptType} eq 'cgi' );
        $text .= $this->_restoreFromBackup( $params );
    } elsif( $action eq 'download_backup' ) {
        # content type is printed in _downloadBackup
        $text .= $this->_downloadBackup( $params );
    } else {
        print "Content-type: text/html\n\n" if( $this->{ScriptType} eq 'cgi' );
        $text .= $this->_showUsage( $params );
    }
    $text = $this->_renderError() . $text;
    return $text;
}

#==================================================================
sub _showUsage {
    my( $this, $params ) = @_;

    my $text = '';
    $text .= "<pre>\n" if( $this->{ScriptType} eq 'cgi' );
    $text .= "Backup and restore utility of TWiki's BackupRestorePlugin.\n";
    $text .= "Copyright 2011 Peter[at]Thoeny.org and TWiki Contributors.\n";
    $text .= "Plugin home and documentation:\n";
    $text .= "  http://twiki.org/cgi-bin/view/Plugins/BackupRestorePlugin\n";
    $text .= "Usage:\n";
    if( $this->{ScriptType} ne 'cgi' ) {
        $text .= "  ./backuprestore status                   # show backup status\n";
        $text .= "  ./backuprestore create_backup            # create new backup\n";
        $text .= "  ./backuprestore download_backup name     # download a backup file\n";
    } else {
        $text .= "  /backuprestore?action=status             # show backup status\n";
    }
    $text .= "</pre>\n" if( $this->{ScriptType} eq 'cgi' );
    return $text;
}

#==================================================================
sub _showBackupStatus {
    my( $this, $params ) = @_;

    my $daemonStatus = $this->_daemonRunning();
    my $fileName = $this->_getBackupName( $daemonStatus );
    my $text = '';
    $text .= "<pre>\n" if( $this->{ScriptType} eq 'cgi' );
    $text .= "backup_status: $daemonStatus\nfile_name: $fileName\n";
    $text .= "</pre>\n" if( $this->{ScriptType} eq 'cgi' ); 
    return $text;
}

#==================================================================
sub _showBackupSummary {
    my( $this, $params ) = @_;

    $this->_writeDebug( '_showBackupSummary' );
    my $text = "";
    my $daemonStatus = $this->_daemonRunning();
    my $fileName = $this->_getBackupName( $daemonStatus );
    if( $daemonStatus ) {
        my $message = $daemonStatus == 1 ? 'Creating backup now' : 'Restoring from backup now';
        $text .= "$checkStatusJS\n";
        $text .= "| *Backup* | *Size* | *Action* |\n";
        $text .= '| <img src="%PUBURLPATH%/%WEB%/BackupRestorePlugin/processing.gif" '
               . 'width="16" height="16" alt="Processing..." /> ' . $fileName
               . '| <img src="%PUBURLPATH%/%WEB%/BackupRestorePlugin/processing-bar.gif" '
               . 'width="92" height="16" alt="Processing..." /> '
               . "| $message, please wait. "
               . '<form action="%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%">'
               . '<input type="hidden" name="action" value="cancel_backup" />'
               . '<input type="submit" value="Cancel" class="twikiButton" />'
               . '</form> |' . "\n";
    } else {
        $text .= "| *Backup* | *Size* | *Action* |\n";
        $text .= '| <img src="%PUBURLPATH%/%WEB%/BackupRestorePlugin/newtopic.gif" '
               . 'width="16" height="16" alt="New backup" /> ' . $fileName . ' | '
               . '| <form action="%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%">'
               . '<input type="hidden" name="action" value="create_backup" />'
               . '<input type="submit" value="Create backup now" class="twikiButton" />'
               . '</form> |' . "\n";
    }
    my @backupFiles = $this->_listAllBackups();
    if( scalar @backupFiles ) {
        my $magic = $this->_generateMagic();
        foreach $fileName ( reverse sort @backupFiles ) {
            my $size = -s $this->{BackupDir} . "/$fileName";
            $size =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g;
            $text .= '| <img src="%PUBURLPATH%/%WEB%/BackupRestorePlugin/zip.gif" '
                   . 'width="16" height="16" alt="ZIP" /> [[%SCRIPTURL%/backuprestore%SCRIPTSUFFIX%?'
                   . "action=download_backup;file=$fileName;magic=$magic][$fileName]] "
                   . "|   $size "
                   . '| <form action="%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%">'
                   . '<input type="hidden" name="action" value="backup_detail" />'
                   . '<input type="hidden" name="file" value="' . $fileName . '" />'
                   . '<input type="submit" value="Details / Restore..." class="twikiButton" />'
                   . '</form> '
                   . '<form action="%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%">'
                   . '<input type="hidden" name="action" value="delete_backup" />'
                   . '<input type="hidden" name="file" value="' . $fileName . '" />'
                   . '<input type="submit" value="Delete..." class="twikiButton" onClick="return confirm('
                   . "'Are you sure you want to delete $fileName?'" . ');" />'
                   . '</form> |' . "\n";
        }
    } else {
        $text .= "| (no existing backups ) | | |\n";
    }
    return $text;
}

#==================================================================
sub _showBackupDetail {
    my( $this, $params ) = @_;

    my $fileName = $params->{file} || '';
    $this->_writeDebug( "_showBackupDetail file=$fileName" );
    my $buDate = $fileName;
    $buDate = '' unless( $buDate =~ s/[^0-9]*(.*?)-([0-9]+)-([0-9]+)\.zip/$1 $2:$3/ );
    my @fileList = $this->_listZip( $fileName );
    return '' unless( -e $this->_getZipFilePath( $fileName ) ); # bail out if file does not exist

    my ( $buVersion ) = map{ s/^.*BackupRestorePlugin\/twiki-version-long-(.*?)\.txt$/$1/; $_ }
        grep{ /BackupRestorePlugin\/twiki-version-long-/ }
        @fileList;
    my ( $buShort ) = map{ s/^.*BackupRestorePlugin\/twiki-version-short-(.*?)\.txt$/$1/; $_ }
        grep{ /BackupRestorePlugin\/twiki-version-short-/ }
        @fileList;
    my @webList = map{ s/^data\/(.*)\/WebPreferences\.txt$/$1/; $_ }
        grep{ /^data\/.*\/WebPreferences\.txt$/ }
        sort
        @fileList;
    my $magic = $this->_generateMagic();
    my ( $twikiVersion, $twikiShort ) = $this->_getTWikiVersion();
    my $buSize = -s $this->{BackupDir} . "/$fileName";
    $buSize =~ s/(^[-+]?\d+?(?=(?>(?:\d{3})+)(?!\d))|\G\d{3}(?=\d))/$1,/g;
    my $text = '<form action="%SCRIPTURLPATH%/view%SCRIPTSUFFIX%/%WEB%/%TOPIC%">' . "\n"
        . "| *Details of $fileName:* ||\n"
        . '| Backup file: | [[%SCRIPTURL%/backuprestore%SCRIPTSUFFIX%?'
        . "action=download_backup;file=$fileName;magic=$magic][$fileName]] |\n"
        . "| Backup date: | $buDate \%GRAY\% - local time of server \%ENDCOLOR\% |\n"
        . "| Backup size: | $buSize \%GRAY\% Bytes \%ENDCOLOR\% |\n"
        . "| Backup of: | $buVersion \%GRAY\% - the TWiki version this backup was taken from \%ENDCOLOR\% |\n"
        . "| This TWiki: | $twikiVersion \%GRAY\% - the TWiki version of the current installation \%ENDCOLOR\% |\n"
        . "| *Restore Options:* ||\n"
        . '| | <input type="checkbox" name="copysys" id="copysys" /> '
        . '<label for="copysys"> Copy latest system pages (<nop>WebSearch etc.) to restored webs </label>|' . "\n"
        . '| | <input type="checkbox" name="overwrite" id="overwrite" /> '
        . '<label for="overwrite"> Overwrite existing pages </label>|' . "\n"
        . '| | <input type="checkbox" name="workarea" id="workarea" /> '
        . '<label for="workarea"> Restore plugin work area </label>|' . "\n"
        . "| *Restore Webs:* ||\n";
    my $systemWeb = 'TWiki';
    $systemWeb =  $TWiki::cfg{SystemWebName} if( defined $TWiki::cfg{SystemWebName} );
    foreach my $web ( @webList ) {
        my $checked = 1;
        my $note = '';
        if( $buShort != $twikiShort && $web =~ /^($systemWeb|_default)$/ ) {
             $checked = 0;
             $note = 'do not restore over a different TWiki version!'
        }
        $text .= _renderWebRow( $web, $checked, $note );
    }
    $text .= "| *Restore Action:* ||\n"
        . "| (Restore is work in progress. Check TWiki:Plugins.BackupRestorePlugin for an updated plugin) ||\n"
        . '</form>';
    return $text;
}
    
#==================================================================
sub _renderWebRow {
    my( $web, $checked, $note ) = @_;
    my $text = "| | <input type=\"checkbox\" name=\"web_$web\" id=\"web_$web\"";
    $text .= ' checked="checked"' if( $checked );
    $text .= " /> <label for=\"web_$web\">$web</label>";
    if( $note ) {
        $text .= " - \%RED\% $note \%ENDCOLOR\%";
    }
    $text .= " |\n";
    return $text;
}

#==================================================================
sub _debugBackup {
    my( $this, $params ) = @_;

    my $text = "Debug BACKUPRESTORE, base web $this->{BaseWeb}";
    $text .= "<br /> " . $this->_testZipMethods();
    return $text;
}


#==================================================================
# MID-LEVEL BACKUP/RESTORE METHODS
#==================================================================

#==================================================================
sub _generateMagic {
    my( $this ) = @_;

    # create new magic number, used to protect web-based download of backups
    my $magic = $this->_buildFileName();
    $magic =~ s/\.zip//o;
    $magic .= '-' . sprintf( "%.10u", int( rand( 10000000000 ) ) );

    # read file with magic number array, add new magic number, and truncate array
    $this->_makeDir( $this->{DaemonDir} ) unless( -e $this->{DaemonDir} );
    my @magicArray = split( /\n/, _readFile( $this->{DaemonDir} . '/magic.txt' ) );
    push( @magicArray, $magic );
    my $size = scalar @magicArray;
    if( $size > 32 ) {
        splice( @magicArray, 0, $size - 32 );
    }
    _saveFile( $this->{DaemonDir} . '/magic.txt', join( "\n", @magicArray ) . "\n" );

    $this->_writeDebug( "_generateMagic() => $magic" );

    return $magic;
}

#==================================================================
sub _checkMagic {
    my( $this, $magic ) = @_;

    my @magicArray = grep{ /^$magic$/ }
                     split( /\n/, _readFile( $this->{DaemonDir} . '/magic.txt' ) );
    my $found = scalar @magicArray;
    $this->_writeDebug( "_checkMagic( $magic ) => $found" );

    return $found;
}

#==================================================================
sub _daemonRunning {
    my( $this ) = @_;
    my $pid = _untaintChecked( _readFile( $this->{DaemonDir} . '/pid.txt' ) );
    if( $pid && (kill 0, $pid) ) {
        my $text = _readFile( $this->{DaemonDir} . '/file_name.txt' );
        if( $text =~ m/type: ([0-9])-/s ) {
            # type: 1-backup, type: 2-restore (return only a digit)
            return $1;
        }
        return 1;
    }
    return 0;
}

#==================================================================
sub _getBackupName {
    my( $this, $inProgress ) = @_;
    if( $inProgress ) {
        my $text = _readFile( $this->{DaemonDir} . '/file_name.txt' );
        if( $text =~ m/file_name: ([^\n]+)/ ) {
            return _untaintChecked( $1 );
        }
        $this->_setError( 'ERROR: Can\'t determine backup filename.' );
        return '';
    } else {
        return $this->_buildFileName();
    }
}

#==================================================================
sub _startBackup {
    my( $this, $params ) = @_;

    $this->_writeDebug( "_startBackup()" );
    $this->_makeDir( $this->{DaemonDir} ) unless( -e $this->{DaemonDir} );

    my $daemonType = $this->_daemonRunning();
    if( $daemonType == 1 ) {
        $this->_setError( 'ERROR: Backup is already in progress.' );
    } elsif( $daemonType > 1 ) {
        $this->_setError( 'ERROR: Backup not possible while restore is in progress.' );
    } else {
        my $fileName = $this->_buildFileName();
        my $text = "file_name: " . $fileName . "\n"
                 . "type: 1-backup\n";
        _saveFile( $this->{DaemonDir} . '/file_name.txt', $text );
        # daemon is running as shell script, do not pass env vars that make it look like a cgi
        my $SaveGATEWAY_INTERFACE;
        if( $ENV{GATEWAY_INTERFACE} ) {
            $SaveGATEWAY_INTERFACE = $ENV{GATEWAY_INTERFACE};
            delete $ENV{GATEWAY_INTERFACE};
        }
        my $SaveMOD_PERL; 
        if( $ENV{MOD_PERL} ) {
            $SaveMOD_PERL = $ENV{MOD_PERL};
            delete $ENV{MOD_PERL};
        }
        # build backup daemon command
        my $cmd = $this->{Location}{BinDir} . "/backuprestore create_backup $fileName";
        $this->_writeDebug( "start new daemon: $cmd" );
        require TWiki::Plugins::BackupRestorePlugin::ProcDaemon;
        my $daemon = TWiki::Plugins::BackupRestorePlugin::ProcDaemon->new(
            work_dir     => $this->{Location}{BinDir},
            child_STDOUT => $this->{DaemonDir} . '/stdout.txt',
            child_STDERR => $this->{DaemonDir} . '/stderr.txt',
            pid_file     => $this->{DaemonDir} . '/pid.txt',
            exec_command => $cmd,
        );
        # fork background daemon process
        my $pid = $daemon->Init();
        # restore environment variables
        $ENV{GATEWAY_INTERFACE} = $SaveGATEWAY_INTERFACE if( $SaveGATEWAY_INTERFACE );
        $ENV{MOD_PERL}          = $SaveMOD_PERL if( $SaveMOD_PERL );
    }
}

#==================================================================
sub _startRestore {
    my( $this, $params ) = @_;

    my $fileName = $params->{file} || '';
    $this->_writeDebug( "_startRestore file=$fileName" );
    $this->_makeDir( $this->{DaemonDir} ) unless( -e $this->{DaemonDir} );

    unless( -e $this->_getZipFilePath( $fileName ) ) {
        # bail out if file does not exist
        $this->_setError( "ERROR: Backup $fileName does not exist" );
        return;
    }

    my $daemonType = $this->_daemonRunning();
    if( $daemonType == 1 ) {
        $this->_setError( 'ERROR: Restore not possible while backup is in progress.' );
    } elsif( $daemonType > 1 ) {
        $this->_setError( 'ERROR: Restore from backup is already in progress.' );
    } else {
        my $fileName = $params->{file};
        my $text = "file_name: " . $fileName . "\n"
                 . "type: 2-restore\n";
        _saveFile( $this->{DaemonDir} . '/file_name.txt', $text );
        # daemon is running as shell script, do not pass env vars that make it look like a cgi
        my $SaveGATEWAY_INTERFACE;
        if( $ENV{GATEWAY_INTERFACE} ) {
            $SaveGATEWAY_INTERFACE = $ENV{GATEWAY_INTERFACE};
            delete $ENV{GATEWAY_INTERFACE};
        }
        my $SaveMOD_PERL; 
        if( $ENV{MOD_PERL} ) {
            $SaveMOD_PERL = $ENV{MOD_PERL};
            delete $ENV{MOD_PERL};
        }
        # build restore daemon command
        my $cmd = $this->{Location}{BinDir} . "/backuprestore restore_backup $fileName";
        $this->_writeDebug( "start new daemon: $cmd" );
        require TWiki::Plugins::BackupRestorePlugin::ProcDaemon;
        my $daemon = TWiki::Plugins::BackupRestorePlugin::ProcDaemon->new(
            work_dir     => $this->{Location}{BinDir},
            child_STDOUT => $this->{DaemonDir} . '/stdout.txt',
            child_STDERR => $this->{DaemonDir} . '/stderr.txt',
            pid_file     => $this->{DaemonDir} . '/pid.txt',
            exec_command => $cmd,
        );
        # fork background daemon process
        my $pid = $daemon->Init();
        # restore environment variables
        $ENV{GATEWAY_INTERFACE} = $SaveGATEWAY_INTERFACE if( $SaveGATEWAY_INTERFACE );
        $ENV{MOD_PERL}          = $SaveMOD_PERL if( $SaveMOD_PERL );
    }
}

#==================================================================
sub _cancelBackup {
    my( $this, $params ) = @_;

    my $daemonType = $this->_daemonRunning();
    if( $daemonType ) {
        my $pid = _untaintChecked( _readFile( $this->{DaemonDir} . '/pid.txt' ) );
        kill( 6, $pid ) if( $pid ); # send ABORT signal to backuprestore script
        unlink( $this->{DaemonDir} . '/pid.txt' );
        sleep( 10 ); # wait for zip to cleanup before deleting zip file
        if( $daemonType == 1 ) {
            # cleanup backup
            my $text = _readFile( $this->{DaemonDir} . '/file_name.txt' );
            if( $text =~ m/file_name: ([^\n]+)/ ) {
                my $zipFile = _untaintChecked( "$this->{BackupDir}/$1" );
                unlink( $zipFile ) if( -e $zipFile );
            }
        } else {
            # FIXME cleanup restore
        }

    } else {
        $this->_setError( 'ERROR: No backup or restore is in progress.' );
    }
}

#==================================================================
sub _createBackup {
    my( $this, $params ) = @_;

    my $name = $params->{file} || '';
    $name =~ s/[^0-9a-zA-Z_\-\.]//g;
    $name = $this->_buildFileName() unless( $name );
    $name = _untaintChecked( $name );
    $this->_writeDebug( "_createBackup( $name )" ) if $this->{Debug};

    # delete old backups based on $TWiki::cfg{Plugins}{BackupRestorePlugin}{KeepNumberOfBackups}
    if( $this->{KeepNumBUs} > 0 ) {
        my @backupFiles = sort $this->_listAllBackups();
        my $nFiles = scalar @backupFiles;
        if( $nFiles > $this->{KeepNumBUs} ) {
            splice( @backupFiles, $nFiles - $this->{KeepNumBUs} + 1, $nFiles );
            foreach my $fileName ( @backupFiles ) {
                $this->_deleteZip( _untaintChecked( $fileName ) );
            }
        }
    }

    my @exclude = ( '-x', '*.svn/*' );

    # backup data dir
    my( $base, $dir ) = _splitTopDir( $this->{Location}{DataDir} );
    $this->_createZip( $name, $base, $dir, @exclude );

    # backup pub dir
    ( $base, $dir ) = _splitTopDir( $this->{Location}{PubDir} );
    $this->_createZip( $name, $base, $dir, @exclude );

    # backup system configuration files (backed-up later in working dir)
    $dir = $this->{Location}{WorkingDir};
    $this->_makeDir( $dir ) unless( -e $dir );
    $dir .= "/work_areas";
    $this->_makeDir( $dir ) unless( -e $dir );
    $dir .= "/BackupRestorePlugin";
    $this->_makeDir( $dir ) unless( -e $dir );
    foreach my $junk ( _getDirContent( $dir ) ) {
        unless( unlink( "$dir/$junk" ) ) {
            $this->_setError( "Can't delete $dir/$junk - $!" );
        }
    }
    my $file = $this->{Location}{LocalLib};
    $this->_copyFile( $file, $dir ) if( $file && -e $file );
    $file = $this->{Location}{LocalSite};
    $this->_copyFile( $file, $dir ) if( $file && -e $file );
    $file = $this->{Location}{ApacheConf};
    $this->_copyFile( $file, $dir ) if( $file && -e $file );
    my( $version, $short ) = $this->_getTWikiVersion();
    if( $version ) {
        _saveFile( "$dir/twiki-version.txt", "version: $version\nshort: $short\n" );
        _saveFile( "$dir/twiki-version-long-$version.txt", "(version is in file name)\n" );
        _saveFile( "$dir/twiki-version-short-$short.txt", "(version is in file name)\n" );
    }

    # backup working dir
    ( $base, $dir ) = _splitTopDir( $this->{Location}{WorkingDir} );
    push( @exclude, '*/tmp/*', '*/registration_approvals/*' );
    $this->_createZip( $name, $base, $dir, @exclude );
    return '';
}

#==================================================================
sub _restoreFromBackup {
    my( $this, $params ) = @_;

    my $name = $params->{file} || '';
    $name =~ s/[^0-9a-zA-Z_\-\.]//g;
    $name = $this->_buildFileName() unless( $name );
    $name = _untaintChecked( $name );
    $this->_writeDebug( "_restoreFromBackup( $name )" ) if $this->{Debug};

    #FIXME
    _saveFile( $this->{DaemonDir} . '/blah1.txt', 'restore!!' );
    sleep( 30 );
    _saveFile( $this->{DaemonDir} . '/blah2.txt', 'restore!!' );
}

#==================================================================
sub _downloadBackup {
    my( $this, $params ) = @_;

    my $text = '';
    my $name = $params->{file} || '';
    $name =~ s/[^0-9a-zA-Z_\-\.]//g;
    $name = _untaintChecked( $name );
    unless( $name ) {
        print "Content-type: text/html\n\n" if( $this->{ScriptType} eq 'cgi' );
        $this->_setError( "Backup filename must be specified" );
        return $text;
    }

    my $magic = $params->{magic};
    if( $this->{ScriptType} eq 'cgi' && ! $this->_checkMagic( $magic ) ) {
        print "Content-type: text/html\n\n";
        $this->_setError( "Sorry, only TWiki administrators can download backups" );
        return $text;
    }

    my $file = $this->_getZipFilePath( $name );
    my $size = -s $file;
    unless( open( ZIPFILE, $file ) ) {
        print "Content-type: text/html\n\n" if( $this->{ScriptType} eq 'cgi' );
        $this->_setError( "Backup $name does not exist" );
        return $text;
    }

    # enforce binmode for binary zip file
    binmode( ZIPFILE );
    binmode( STDOUT );

    # if in cgi context, output content-type
    if( $this->{ScriptType} eq 'cgi' ) {
        print "Content-Type: application/zip\n";
        print "Content-Length: $size\n";
        print "Content-Disposition: attachment; filename=$name\n\n";
    }

    # directly print to STDOUT because of potentially big zip file size
    my $buffer;
    while( read( ZIPFILE, $buffer, 8 * 2**10 ) ) {
        print STDOUT $buffer;
    }
    close( ZIPFILE );

    return ''; # empty
}

#==================================================================
sub _deleteBackup {
    my( $this, $params ) = @_;

    my $name = $params->{file} || '';
    $name =~ s/[^0-9a-zA-Z_\-\.]//g;
    return $this->_deleteZip( _untaintChecked( $name ) );
}


#==================================================================
# LOW-LEVEL METHODS
#==================================================================

#==================================================================
sub _clearError {
    my( $this ) = @_;
    $this->{error} = '';
}

#==================================================================
sub _setError {
    my( $this, $error ) = @_;
    $this->{error} .=  "$error\n"
}

#==================================================================
sub _renderError {
    my( $this ) = @_;

    my $text = '';
    return $text unless $this->{error};

    if( $this->{ScriptType} eq 'cgi' ) {
        $this->{error} =~ s/\n*$//; # remove trailing newline
        $this->{error} =~ s/\n/<br \/>\n/go if( $this->{error} ); # separate errors with <br />
        $text = '<div style="background-color: #f0f0f4; padding: 10px 20px">'
              . $this->{error}
              . "</div>\n";
    } else {
        print STDERR $this->{error};
    }
    $this->{error} = '';
    return $text;
}

#==================================================================
sub _getTWikiVersion {
    my( $this ) = @_;

    my $version = '';
    my $short = '';
    my $text = _readFile( $this->{Location}{LibDir} . "/TWiki.pm" );
    if( $text =~ m/\$wikiversion *= *['"]([^'"]+)/s ) {
        # older than TWiki-4.0
        $version = 'TWiki-' . $1;
        $version =~ s/ /-/go;
        $short = '1.0' if( $version =~ m/-2001/ );
        $short = '2.0' if( $version =~ m/-2003/ );
        $short = '3.0' if( $version =~ m/-2004/ );
        $this->_writeDebug( "found old $version, short version $short" );
    } elsif( $text =~ m/\$RELEASE *= *['"]([^'"]+)/s ) {
        # TWiki-4.0 and newer
        $version = $1;
        $short = $1 if( $version =~ m/([0-9]+\.[0-9]+)/ );
        $this->_writeDebug( "found $version, short version $short" );
    }
    return( $version, $short );
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
    return _untaintChecked( $text );
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
        $binDir = cwd();
    }
    $loc->{BinDir} = _untaintChecked( $binDir );

    # discover twiki/bin/LocalLib.cfg
    $loc->{LocalLib}   = _untaintChecked( "$binDir/LocalLib.cfg" ) if( -e "$binDir/LocalLib.cfg" );

    # discover lib dir via twiki/lib/TWiki.pm
    foreach my $dir ( @INC ) {
        if( -e "$dir/TWiki.pm" ) {
            $loc->{LibDir} = _untaintChecked( $dir );
            last;
        }
    }
    if( ! $loc->{LibDir} && $TWiki::cfg{DataDir} ) {
        my $dir = $TWiki::cfg{DataDir};
        $dir =~ s|(.*)[\\/]+.*|$1|;      # go one directory up
        if( -e "$dir/lib/TWiki.pm" ) {
            $loc->{LibDir} = _untaintChecked( "$dir/lib" );
        }
    }
    unless( $loc->{LibDir} ) {
        my $dir = $loc->{BinDir};
        $dir =~ s|(.*)[\\/]+.*|$1|;      # go one directory up
        $loc->{LibDir} = _untaintChecked( "$dir/lib" );
    }

    # discover twiki/lib/LocalSite.cfg
    if( -e $loc->{LibDir} . "/LocalSite.cfg" ) {
        $loc->{LocalSite} = $loc->{LibDir} . "/LocalSite.cfg";
    }

    # discover TWiki root dir
    my $rootDir = $TWiki::cfg{DataDir} || $loc->{LibDir};
    $rootDir =~ s|(.*)[\\/]+.*|$1|;      # go one directory up
    $loc->{RootDir} = _untaintChecked( $rootDir );

    # discover common TWiki directories
    $loc->{DataDir}    = _untaintChecked( $TWiki::cfg{DataDir}    || "$rootDir/data" );
    $loc->{PubDir}     = _untaintChecked( $TWiki::cfg{PubDir}     || "$rootDir/pub" );
    $loc->{WorkingDir} = _untaintChecked( $TWiki::cfg{WorkingDir} || "$rootDir/working" );

    # discover apache conf file twiki.conf
    foreach my $dir ( @apacheConfLocations ) {
        if( -e "$dir/twiki.conf" ) {
            $loc->{ApacheConf} = _untaintChecked( "$dir/twiki.conf" );
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
           . "- BaseTopic:    $this->{BaseTopic}\n"
           . "- BaseWeb:      $this->{BaseWeb}\n"
           . "- Root:         $this->{Location}{RootDir}\n"
           . "- BinDir:       $this->{Location}{BinDir}\n"
           . "- LibDir:       $this->{Location}{LibDir}\n"
           . "- DataDir:      $this->{Location}{DataDir}\n"
           . "- PubDir:       $this->{Location}{PubDir}\n"
           . "- WorkingDir:   $this->{Location}{WorkingDir}\n"
           . "- LocalLib:     $this->{Location}{LocalLib}\n"
           . "- LocalSite:    $this->{Location}{LocalSite}\n"
           . "- ApacheConf:   $this->{Location}{ApacheConf}\n"
           . "- TempDir:      $this->{TempDir}\n"
           . "- DaemonDir:    $this->{DaemonDir}\n"
           . "\n</pre>\n";

    $text .= "\n<br />===== Test _listAllBackups()<pre>\n"
           . join( "\n", $this->_listAllBackups() )
           . "\n</pre>Error return: $this->{error} <p />\n";

    my $zip = 'twiki-backup-2011-01-18-19-33.zip';
    $this->{error} = '';
    $text .= "<br />===== Test _createBackup( { file => $zip } )<pre>\n" 
           . $this->_createBackup( undef, { file => $zip } ) 
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

#    $this->{error} = '';
#    $text .= "<br />===== Test _deleteZip( $zip )<pre>\n"
#           . join( "\n", $this->_deleteZip( "$zip" ) )
#           . "\n</pre>Error return: $this->{error}\n";

    $this->{error} = '';
    $text .= "<br />===== Test _deleteZip( not-exist-$zip )<pre>\n"
           . join( "\n", $this->_deleteZip( "not-exist-$zip" ) )
           . "\n</pre>Error return: $this->{error}\n";

    return $text;
}

#==================================================================
sub _listAllBackups {
    my( $this ) = @_;

    $this->_writeDebug( "_listAllBackups" );

    my @files = ();
    unless( opendir( DIR, $this->{BackupDir} ) ) {
        $this->_setError( "Can't open the backup directory - $!" );
        return @files;
    }
    @files = grep{ /twiki-backup-.*\.zip/ }
             grep{ -f "$this->{BackupDir}/$_" }
             readdir( DIR );
    closedir( DIR ); 

    return @files;
}

#==================================================================
sub _getZipFilePath {
    my( $this, $name ) = @_;
    return "$this->{BackupDir}/$name";
}

#==================================================================
sub _createZip {
    my( $this, $name, $baseDir, @dirs ) = @_;

    $this->_writeDebug( "_createZip( $name, $baseDir, " 
      . join( ", ", @dirs ) . " )" ) if $this->{Debug};

    chdir( $baseDir );
    my $zipFile = "$this->{BackupDir}/$name";
    my @cmd = split( /\s+/, $this->{createZipCmd} );
    if( $this->{ScriptType} eq 'cli' ) {
        print "Backing up to $name: " . join( ", ", @dirs ) . "\n";
    }
    my ( $stdOut, $stdErr, $success, $exitCode ) = capture_exec( @cmd, $zipFile, @dirs );
    if( $exitCode ) {
        $this->_setError( "Error creating $name. $stdErr" );
    }
    return;
}

#==================================================================
sub _deleteZip {
    my( $this, $name ) = @_;

    $this->_writeDebug( "_deleteZip( $name )" ) if $this->{Debug};

    my $zipFile = "$this->{BackupDir}/$name";
    unless( -e $zipFile ) {
        $this->_setError( "Backup $name does not exist" );
        return;
    }
    unless( unlink( $zipFile ) ) {
        $this->_setError( "Can't delete $name - $!" );
    }
    return;
}

#==================================================================
sub _listZip {
    my( $this, $name ) = @_;

    $this->_writeDebug( "_listZip( $name )" ) if $this->{Debug};

    my @files = ();
    my $zipFile = "$this->{BackupDir}/$name";
    unless( -e $zipFile ) {
        $this->_setError( "Backup $name does not exist" );
        return @files;
    }
    my @cmd = split( /\s+/, $this->{listZipCmd} );
    my ( $stdOut, $stdErr, $success, $exitCode ) = capture_exec( @cmd, $zipFile );
    if( $exitCode ) {
        $this->_setError( "Error listing content of $name. $stdErr" );
    }
    @files = map{ s/^\s*([0-9\-\:]+\s*){3}//; $_ }   # remove size and timestamp
             grep{ /^\s*[0-9]+\s*[0-9]+\-.*[^\/]$/ } # exclude header, footer & directories
             split( /[\n\r]+/, $stdOut );
    return @files;
}

#==================================================================
sub _unZip {
    my( $this, $name ) = @_;

    $this->_writeDebug( "_unZip( $name )" ) if $this->{Debug};

    my $zipFile = "$this->{BackupDir}/$name";
    unless( -e $zipFile ) {
        $this->_setError( "Backup $name does not exist" );
        return;
    }
    my @cmd = split( /\s+/, $this->{unZipCmd} );
    my ( $stdOut, $stdErr, $success, $exitCode ) = capture_exec( @cmd, $zipFile );
    if( $exitCode ) {
        $this->_setError( "Error unzipping $name. $stdErr" );
    }
    return;
}

#==================================================================
sub _writeDebug {
    my( $this, $text ) = @_;

    return unless( $this->{Debug} );
    if( $this->{ScriptType} eq 'cli' ) {
        print "DEBUG: $text\n";
    } elsif( exists( &TWiki::Func::writeDebug ) ) {
        TWiki::Func::writeDebug( "- BackupRestorePlugin: $text" );
    } else {
        print STDERR "DEBUG BackupRestorePlugin: $text\n";
    }
}

#==================================================================
sub _makeDir {
    my( $this, $dir ) = @_;

    unless( mkdir( $dir ) ) {
        $this->_setError( "Error creating $dir" );
    }
}

#==================================================================
sub _copyFile {
    my( $this, $fromFile, $toDir ) = @_;

    unless( File::Copy::copy( $fromFile, $toDir ) ) {
        $this->_setError( "Error copying $fromFile to $toDir" );
    }
}

#==================================================================
# LOW LEVEL FUNCTIONS (NOT METHODS)
#==================================================================

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
sub _getDirContent {
    my( $dir ) = @_;

    my @files;
    opendir( DIR, $dir ) or return;
    while( my $file = readdir( DIR )) {
        next if( $file =~ m/^\./ );
	push( @files, _untaintChecked( $file ) );
    }
    closedir( DIR );

    return @files;
}

#==================================================================
sub _splitTopDir {
    my( $dir ) = @_;

    my $base = '';
    if( $dir =~ /^(.*)[\/\\]+(.*)$/ ) {
        $base = $1;
        $dir  = $2;
    }
    return( $base, $dir );
}

#==================================================================
sub _untaintChecked {
    my( $text ) = @_;

    $text = $1 if( $text =~ /^(.*)$/ );
    return $text;
}

#==================================================================
1;
