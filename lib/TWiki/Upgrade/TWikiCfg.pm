# Support functionality for the TWiki Collaboration Platform, http://TWiki.org/
#
#
# Jul 2004 - written by Martin "GreenAsJade" Gregory, martin@gregories.net

package TWikiCfg;

use strict; 

use vars '$twikiLibPath';   # read from setlib.cfg

use vars '@storeSettings';  # read from TWiki.cfg

# default Twiki.cfg contents, set in BEGIN block far below...
use vars qw($InitialBlurb @ConfigFileScalars @ConfigFileOSScalars @ConfigFileArrays @SubstituteBackVars);

use vars qw(@ActiveSubstitutions);  
 
use Data::Dumper;
use File::Copy;

=pod
---+ UpgradeTWikiConfig

Create an upgraded twiki installation configuration file from an existing one
and a new distribution.

Writes TWiki.cfg.new by default.

Dialogs with the user on STDIN/STDOUT.

=cut

sub UpgradeTWikiConfig
{

    my $existingConfigInfo = shift or die "UpgradeTWikiConfig not passed any arguments!\n";

    my $targetDir = (shift or '.');

    my $newConfigFile = "$targetDir/lib/LocalSite.cfg";

    my $twikiCfgFile;

    if (-f "$existingConfigInfo/setlib.cfg") {
        my ($setlibPath) = $existingConfigInfo;

        # Find out from there where TWiki.cfg is
	
        require "$setlibPath/setlib.cfg";
	
        print "\nGreat - found it OK, and it tells me that the rest of the config is in $twikiLibPath,\n";
        print "so that's where I'll be looking!\n\n";

        print "Now generating new LocalLib.cfg from settings in old setlib.cfg...\n\n";
        my $newf = "# This is LocalLib.cfg. It contains all the paths for your local\n".
          "# TWiki site.\n".
            TWiki::old2new($twikiLibPath, "../lib", "\$twikiLibPath").
              TWiki::old2new($localPerlLibPath, "", "\@localperlLibPath");
        my $newLibFile = "$targetDir/bin/LocalLib.cfg";
        open(NEW_CONFIG, ">$newLibFile") or die "Couldn't open $newLibFile to write it: $!\n";
        printToNewConfig( $newf );
        close(NEW_CONFIG);

        if ($twikiLibPath =~ m|^[~/]|) {
            # absolute path in $twikiLibPath
            $twikiCfgFile = "$twikiLibPath/TWiki.cfg";
        } else {
            # relative path in $twikiLibPath
            $twikiCfgFile = "$existingConfigInfo/$twikiLibPath/TWiki.cfg";
        }
    } elsif (-f "$existingConfigInfo/TWiki.cfg") {
        $twikiCfgFile = "$existingConfigInfo/TWiki.cfg";
    } else {
        die "UpgradeTwikiConfig couldn't find either setlib.cfg or TWiki.cfg at $existingConfigInfo: seems like a bug, someone needs to check it's arguments!\n";
    }

    TWiki::requireConfig($twikiCfgFile);

    # and now we have the old definitions...
    # ...  write those out where we can, or new defaults where we can't

    open(NEW_CONFIG, ">$newConfigFile") or die "Couldn't open $newConfigFile to write it: $!\n";

    printToNewConfig( "$InitialBlurb\n\n");

    printToNewConfig( "#  This file has been generated by UpgradeTwiki, taking values from
#   $twikiLibPath/Twiki.cfg where they could be found, and using
#  default values for the remainder.
#
");

    printToNewConfig( TWiki:: upgradeConfig() );

    print "$targetDir/lib/TWiki.cfg created...\n";
}

package TWiki;

no strict 'vars';

sub requireConfig {
    my $twikiCfgFile = shift;
    require $twikiCfgFile;
}

sub upgradeConfig {

    my %ss = @storeSettings;
    if ($ss{dataDir} ne $dataDir || $ss{pubDir} ne $pubDir) {
        die "storeSettings dataDir ($ss{dataDir}) or pubDir ($ss{pubDir}) is different to TWiki dataDir ($dataDir) or pubDir ($pubDir); please manually resolve this in the old config file before trying again (they should be identical)";
};

    my $newf = "# This is LocalSite.cfg. It contains all the setups for your local\n";
    $newf .= "# TWiki site.\n";
    $newf .= old2new($defaultUrlHost, "http://your.domain.com",  "\$cfg{DefaultUrlHost}" );
    $newf .= old2new($scriptUrlPath, "/twiki/bin",  "\$cfg{ScriptUrlPath}" );
    $newf .= old2new($dispScriptUrlPath, "/twiki/bin",  "\$cfg{DispScriptUrlPath}" );
    $newf .= old2new($pubUrlPath, "/twiki/pub",  "\$cfg{PubUrlPath}" );
    $newf .= old2new($pubDir, "/home/httpd/twiki/pub",  "\$cfg{PubDir}" );
    $newf .= old2new($templateDir, "/home/httpd/twiki/templates",  "\$cfg{TemplateDir}" );
    $newf .= old2new($dataDir, "/home/httpd/twiki/data",  "\$cfg{DataDir}" );
    $newf .= old2new($logDir, "$dataDir",  "\$cfg{LogDir}" );
    $newf .= old2new($scriptSuffix, "",  "\$cfg{ScriptSuffix}" );
    $newf .= old2new($uploadFilter, "^(\.htaccess|.*\.(?:php[0-9s]?|phtm[l]?|pl|py|cgi))\$",  "\$cfg{UploadFilter}" );
    $newf .= old2new($safeEnvPath, "/bin:/usr/bin",  "\$cfg{SafeEnvPath}" );
    $newf .= old2new($mailProgram, "/usr/sbin/sendmail -t -oi -oeq",  "\$cfg{MailProgram}" );
    $newf .= old2new($noSpamPadding, "",  "\$cfg{NoSpamPadding}" );
    $newf .= old2new($mimeTypesFilename, "$dataDir/mime.types",  "\$cfg{MimeTypesFileName}" );
    $newf .= old2new($useRcsDir, "0",  "\$cfg{UseRcsDir}" );
    $newf .= old2new($storeTopicImpl, "RcsWrap",  "\$cfg{StoreImpl}" );
    $newf .= old2new($egrepCmd, "/bin/egrep",  "\$cfg{EgrepCmd}" );
    $newf .= old2new($fgrepCmd, "/bin/fgrep",  "\$cfg{FgrepCmd}" );
    $newf .= old2new($displayTimeValues, "gmtime",  "\$cfg{DisplayTimeValues}" );
    $newf .= old2new($useLocale, 0,  "\$cfg{UseLocale}" );
    $newf .= old2new($siteLocale, "en_US.ISO-8859-1",  "\$cfg{SiteLocale}" );
    $newf .= old2new($siteCharsetOverride, "",  "\$cfg{SiteCharsetOverride}" );
    $newf .= old2new($localeRegexes, "1",  "\$cfg{LocaleRegexes}" );
    $newf .= old2new($upperNational, "",  "\$cfg{UpperNational}" );
    $newf .= old2new($lowerNational, "",  "\$cfg{LowerNational}" );
    $newf .= old2new($securityFilter, "[\\\*\?\~\^\$\@\%\`\"\'\&\;\|\<\>\x00-\x1F]",  "\$cfg{NameFilter}" );
    $newf .= old2new($defaultUserName, "guest",  "\$cfg{DefaultUserLogin}" );
    $newf .= old2new($siteWebTopicName, "",  "\$cfg{SiteWebTopicName}" );
    $newf .= old2new($mainWebname, "Main",  "\$cfg{UsersWebName}" );
    $newf .= old2new($twikiWebname, "TWiki",  "\$cfg{SystemWebName}" );
    $newf .= old2new($debugFilename, "$logDir/debug.txt",  "\$cfg{DebugFileName}" );
    $newf .= old2new($warningFilename, "$logDir/warning.txt",  "\$cfg{WarningFileName}" );
    $newf .= old2new($htpasswdFormatFamily, "htpasswd",  "\$cfg{HtpasswdFormatFamily}" );
    $newf .= old2new($authRealm, "Enter your WikiName. (First name and last name, no space, no dots, capitalized, e.g. JohnSmith). Cancel to register if you do not have one.",  "\$cfg{AuthRealm}" );
    $newf .= old2new($logFilename, "$logDir/log%DATE%.txt",  "\$cfg{LogFileName}" );
    $newf .= old2new($remoteUserFilename, "$dataDir/remoteusers.txt",  "\$cfg{RemoteUserFileName}" );
    $newf .= old2new($wikiUsersTopicname, "TWikiUsers",  "\$cfg{UsersTopicName}" );
    $newf .= old2new($userListFilename, "$dataDir/$mainWebname/$wikiUsersTopicname.txt",  "\$cfg{UserListFileName}" );
    $newf .= old2new($doMapUserToWikiName, "1",  "\$cfg{MapUserToWikiName}" );
    $newf .= old2new($mainTopicname, "WebHome",  "\$cfg{UsersTopicName}" );
    $newf .= old2new($notifyTopicname, "WebNotify",  "\$cfg{NotifyTopicName}" );
    $newf .= old2new($wikiPrefsTopicname, "TWikiPreferences",  "\$cfg{SitePrefsTopicName}" );
    $newf .= old2new($webPrefsTopicname, "WebPreferences",  "\$cfg{WebPrefsTopicName}" );
    $newf .= old2new($statisticsTopicname, "WebStatistics",  "\$cfg{Stats}{TopicName}" );
    $newf .= old2new($statsTopViews, "10",  "\$cfg{Stats][TopViews}" );
    $newf .= old2new($statsTopContrib, "10",  "\$cfg{Stats}{TopContrib}" );
    $newf .= old2new($numberOfRevisions, "3",  "\$cfg{NumberOfRevisions}" );
    $newf .= old2new($editLockTime, "3600",  "\$cfg{EditLockTime}" );
    $newf .= old2new($superAdminGroup, "TWikiAdminGroup",  "\$cfg{SuperAdminGroup}" );
    $newf .= old2new($doGetScriptUrlFromCgi, "0",  "\$cfg{GetScriptUrlFromCgi}" );
    $newf .= old2new($doRemovePortNumber, "0",  "\$cfg{RemovePortNumber}" );
    $newf .= old2new($doRemoveImgInMailnotify, "1",  "\$cfg{RemoveImgInMailnotify}" );
    $newf .= old2new($doRememberRemoteUser, "0",  "\$cfg{RememberUsersIPAddress}" );
    $newf .= old2new($doPluralToSingular, "1",  "\$cfg{PluralToSingular}" );
    $newf .= old2new($doHidePasswdInRegistration, "1",  "\$cfg{HidePasswdInRegistration}" );
    $newf .= old2new($doSecureInclude, "1",  "\$cfg{DenyDotDotInclude}" );
    $newf .= old2new($doLogTopicView, "1",  "\$cfg{Log}{view}" );
    $newf .= old2new($doLogTopicEdit, "1",  "\$cfg{Log]{edit}" );
    $newf .= old2new($doLogTopicSave, "1",  "\$cfg{Log}{save}" );
    $newf .= old2new($doLogRename, "1",  "\$cfg{Log}{rename}" );
    $newf .= old2new($doLogTopicAttach, "1",  "\$cfg{Log}{attach}" );
    $newf .= old2new($doLogTopicUpload, "1",  "\$cfg{Log}{upload}" );
    $newf .= old2new($doLogTopicRdiff, "1",  "\$cfg{Log}{rdiff}" );
    $newf .= old2new($doLogTopicChanges, "1",  "\$cfg{Log}{changes}" );
    $newf .= old2new($doLogTopicSearch, "1",  "\$cfg{Log}{search}" );
    $newf .= old2new($doLogRegistration, "1",  "\$cfg{Log}{register}" );
    $newf .= old2new($disableAllPlugins, "0",  "\$cfg{DisableAllPlugins}" );
    $newf .= old2new($ss{attachAsciiPath}, "\.(txt|html|xml|pl)\$", "\$cfg{RCS}{asciiFileSuffixes}");
    $newf .= old2new($ss{dirPermission}, 0775, "\$cfg{RCS}{dirPermission}");
    $newf .= old2new($ss{initBinaryCmd}, "$rcsDir/rcs  -q -i -t-none -kb %FILENAME% ", "\$cfg{RCS}{initBinaryCmd}");
    $newf .= old2new($ss{tmpBinaryCmd}, "$rcsDir/rcs  -q -kb %FILENAME% ", "\$cfg{RCS}{tmpBinaryCmd}");
    $newf .= old2new($ss{ciCmd}, "$rcsDir/ci  -q -l -m$cmdQuote%COMMENT%$cmdQuote -t-none -w$cmdQuote%USERNAME%$cmdQuote %FILENAME% ", "\$cfg{RCS}{ciCmd}");
    $newf .= old2new($ss{coCmd}, "$rcsDir/co  -q -p%REVISION% $keywordMode %FILENAME% ", "\$cfg{RCS}{coCmd}");
    $newf .= old2new($ss{histCmd}, "$rcsDir/rlog  -h %FILENAME% ", "\$cfg{RCS}{histCmd}");
    $newf .= old2new($ss{infoCmd}, "$rcsDir/rlog  -r%REVISION% %FILENAME% ", "\$cfg{RCS}{infoCmd}");
    $newf .= old2new($ss{diffCmd}, "$rcsDir/rcsdiff  -q -w -B -r%REVISION1% -r%REVISION2% $keywordMode --unified=%CONTEXT% %FILENAME% ", "\$cfg{RCS}{diffCmd}");
    $newf .= old2new($ss{breakLockCmd}, "$rcsDir/rcs  -q -l -M %FILENAME% ", "\$cfg{RCS}{breakLockCmd}");
    $newf .= old2new($ss{ciDateCmd}, "$rcsDir/ci -l  -q -mnone -t-none -d$cmdQuote%DATE%$cmdQuote -w$cmdQuote%USERNAME%$cmdQuote %FILENAME% ", "\$cfg{RCS}{ciDateCmd}");
    $newf .= old2new($ss{delRevCmd}, "$rcsDir/rcs  -q -o%REVISION% %FILENAME% ", "\$cfg{RCS}{delRevCmd}");
    $newf .= old2new($ss{unlockCmd}, "$rcsDir/rcs  -q -u %FILENAME%  ", "\$cfg{RCS}{unlockCmd}");
    $newf .= old2new($ss{lockCmd}, "$rcsDir/rcs  -q -l %FILENAME% ", "\$cfg{RCS}{lockCmd}");
    $newf .= old2new($ss{tagCmd}, "$rcsDir/rcs  -N%TAG%:%REVISION% %FILENAME% ", "\$cfg{RCS}{tagCmd}");

    return newf;
}

sub old2new {
    my( $var, $val, $new) = @_;

    if( $var ne "$val" ) {
        return "$new = \"$var\";\n";
    }
    return "";
}

1;


