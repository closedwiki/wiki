# Support functionality for the TWiki Collaboration Platform, http://TWiki.org/
#
#
# Jul 2004 - written by Martin "GreenAsJade" Gregory, martin@gregories.net

package TWikiCfg;

use strict; 

use vars '$twikiLibPath';   # read from setlib.cfg

use vars '$localPerlLibPath';   # read from setlib.cfg

use vars '@storeSettings';  # read from TWiki.cfg

use Data::Dumper;
use File::Copy;
use Carp;

=pod

---+ UNPUBLISHED package UpgradeTWikiConfig

Create an upgraded twiki installation configuration file from an existing one
and a new distribution.

Writes TWiki.cfg.new by default.

Dialogs with the user on STDIN/STDOUT.

=cut

sub UpgradeTWikiConfig {

    my $existingConfigInfo = shift or
      die "UpgradeTWikiConfig not passed any arguments!\n";

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
        my $newLibFile = "$targetDir/bin/LocalLib.cfg";
        open(NEW_CONFIG, ">$newLibFile") or die "Couldn't open $newLibFile to write it: $!\n";
        print NEW_CONFIG "# This is LocalLib.cfg. It contains the basic paths for your local\n";
        print NEW_CONFIG "# TWiki site.\n";
        if( $twikiLibPath ne "../lib" ) {
            print NEW_CONFIG "\$twikiLibPath = '$twikiLibPath';";
        }
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

    TWiki::upgradeConfig($twikiCfgFile, $newConfigFile);
}

package TWiki;
# must be package TWiki because of var xrefs in the config

no strict 'vars';

sub requireConfig {
    my $twikiCfgFile = shift;
    require $twikiCfgFile;
}

sub upgradeConfig {
    my( $twikiCfgFile, $newConfigFile ) = @_;

    open(CFG, ">$newConfigFile") or die "Couldn't open $newConfigFile to write it: $!\n";

    print CFG "# This file has been generated by UpgradeTwiki, taking\n";
    print CFG "# non-default values from $twikiCfgFile\n";

    my %ss = @storeSettings;
    # strip the old redirect, which interferes with the Sandbox
    foreach my $s ( keys %ss ) {
        $ss{$s} =~ s/\s+2>&1\s*$// if $s =~ /Cmd$/;
    }

    if ($ss{dataDir} ne $dataDir || $ss{pubDir} ne $pubDir) {
        die "storeSettings dataDir ($ss{dataDir}) or pubDir ($ss{pubDir}) is different to TWiki dataDir ($dataDir) or pubDir ($pubDir); please manually resolve this in the old config file before trying again (they should be identical)";
};

    print CFG "# This is LocalSite.cfg. It contains all the setups for your local\n";
    print CFG "# TWiki site.\n";
    print CFG old2new($defaultUrlHost, "http://your.domain.com",
                      "{DefaultUrlHost}", 1 );
    print CFG old2new($scriptUrlPath, "/twiki/bin",
                      "{ScriptUrlPath}", 1 );
    print CFG old2new($dispScriptUrlPath, "/twiki/bin",
                      "{DispScriptUrlPath}", 0 );
    print CFG old2new($pubUrlPath, "/twiki/pub",
                      "{PubUrlPath}" );
    print CFG old2new($dataDir, "/home/httpd/twiki/data",
                      "{DataDir}", 1 );
    print CFG old2new($pubDir, "/home/httpd/twiki/pub",
                      "{PubDir}", 1 );
    print CFG old2new($templateDir, "/home/httpd/twiki/templates",
                      "{TemplateDir}", 1 );
    print CFG old2new($logDir, "$dataDir",
                      "{LogDir}" );
    print CFG old2new($scriptSuffix, "",
                      "{ScriptSuffix}" );
    print CFG old2new($uploadFilter, "^(\.htaccess|.*\.(?:php[0-9s]?|phtm[l]?|pl|py|cgi))\$",
                      "{UploadFilter}" );
    print CFG old2new($safeEnvPath, "/bin:/usr/bin",
                      "{SafeEnvPath}" );
    print CFG old2new($mailProgram, "/usr/sbin/sendmail -t -oi -oeq",
                      "{MailProgram}" );
    print CFG old2new($noSpamPadding, "",
                      "{NoSpamPadding}" );
    print CFG old2new($mimeTypesFilename, "$dataDir/mime.types",
                      "{MimeTypesFileName}" );
    print CFG old2new($useRcsDir, "0",
                      "{UseRcsDir}" );
    print CFG old2new($storeTopicImpl, "RcsWrap"
                      , "{StoreImpl}" );
    print CFG old2new($displayTimeValues, "gmtime",
                      "{DisplayTimeValues}" );
    print CFG old2new($useLocale, 0,
                      "{UseLocale}" );
    print CFG old2new($siteLocale, "en_US.ISO-8859-1",
                      "{SiteLocale}" );
    print CFG old2new($siteCharsetOverride, "",
                      "{SiteCharsetOverride}" );
    print CFG old2new($localeRegexes, "1",
                      "{LocaleRegexes}" );
    print CFG old2new($upperNational, "",
                      "{UpperNational}" );
    print CFG old2new($lowerNational, "",
                      "{LowerNational}" );
    print CFG old2new($securityFilter, "[\\\*\?\~\^\$\@\%\`\"\'\&\;\|\<\>\x00-\x1F]",
                      "{NameFilter}" );
    print CFG old2new($defaultUserName, "guest", "{DefaultUserLogin}" );
    print CFG old2new($siteWebTopicName, "", "{SiteWebTopicName}" );
    print CFG old2new($mainWebname, "Main", "{UsersWebName}" );
    print CFG old2new($twikiWebname, "TWiki", "{SystemWebName}" );
    print CFG old2new($debugFilename, "$logDir/debug.txt", "{DebugFileName}" );
    print CFG old2new($warningFilename, "$logDir/warning.txt", "{WarningFileName}" );
    print CFG old2new($htpasswdFormatFamily, "htpasswd", "{HtpasswdFormatFamily}" );
    print CFG old2new($logFilename, "$logDir/log%DATE%.txt", "{LogFileName}" );
    print CFG old2new($remoteUserFilename, "$dataDir/remoteusers.txt", "{RemoteUserFileName}" );
    print CFG old2new($wikiUsersTopicname, "TWikiUsers", "{UsersTopicName}" );
    print CFG old2new($userListFilename, "$dataDir/$mainWebname/$wikiUsersTopicname.txt", "{UserListFileName}" );
    print CFG old2new($doMapUserToWikiName, "1", "{MapUserToWikiName}" );
    print CFG old2new($mainTopicname, "WebHome", "{UsersTopicName}" );
    print CFG old2new($notifyTopicname, "WebNotify", "{NotifyTopicName}" );
    print CFG old2new($wikiPrefsTopicname, "TWikiPreferences", "{SitePrefsTopicName}" );
    print CFG old2new($webPrefsTopicname, "WebPreferences", "{WebPrefsTopicName}" );
    print CFG old2new($statisticsTopicname, "WebStatistics", "{Stats}{TopicName}" );
    print CFG old2new($statsTopViews, "10", "{Stats][TopViews}" );
    print CFG old2new($statsTopContrib, "10", "{Stats}{TopContrib}" );
    print CFG old2new($numberOfRevisions, "3", "{NumberOfRevisions}" );
    print CFG old2new($doKeepRevIfEditLock?$editLockTime:0, 3600, "{ReplaceIfEditedAgainWithin}" );
    print CFG old2new($superAdminGroup, "TWikiAdminGroup", "{SuperAdminGroup}" );
    print CFG old2new($doGetScriptUrlFromCgi, "0", "{GetScriptUrlFromCgi}" );
    print CFG old2new($doRemovePortNumber, "0", "{RemovePortNumber}" );
    print CFG old2new($doRemoveImgInMailnotify, "1", "{RemoveImgInMailnotify}" );
    print CFG old2new($doRememberRemoteUser, "0", "{RememberUsersIPAddress}" );
    print CFG old2new($doPluralToSingular, "1", "{PluralToSingular}" );
    print CFG old2new($doHidePasswdInRegistration, "1", "{HidePasswdInRegistration}" );
    print CFG old2new($doSecureInclude, "1", "{DenyDotDotInclude}" );
    print CFG old2new($doLogTopicView, "1", "{Log}{view}" );
    print CFG old2new($doLogTopicEdit, "1", "{Log]{edit}" );
    print CFG old2new($doLogTopicSave, "1", "{Log}{save}" );
    print CFG old2new($doLogRename, "1", "{Log}{rename}" );
    print CFG old2new($doLogTopicAttach, "1", "{Log}{attach}" );
    print CFG old2new($doLogTopicUpload, "1", "{Log}{upload}" );
    print CFG old2new($doLogTopicRdiff, "1", "{Log}{rdiff}" );
    print CFG old2new($doLogTopicChanges, "1", "{Log}{changes}" );
    print CFG old2new($doLogTopicSearch, "1", "{Log}{search}" );
    print CFG old2new($doLogRegistration, "1", "{Log}{register}" );
    print CFG old2new($disableAllPlugins, "0", "{DisableAllPlugins}" );
    print CFG old2new($ss{attachAsciiPath}, "\.(txt|html|xml|pl)\$",
                      "{RCS}{asciiFileSuffixes}");
    print CFG old2new($ss{dirPermission}, 0775,
                      "{RCS}{dirPermission}");
    print CFG old2new($egrepCmd, "/bin/egrep", "{RCS}{EgrepCmd}" );
    print CFG old2new($fgrepCmd, "/bin/fgrep", "{RCS}{FgrepCmd}" );
    print CFG old2new($ss{initBinaryCmd}, "$rcsDir/rcs  -q -i -t-none -kb %FILENAME%",
                      "{RCS}{initBinaryCmd}");
    print CFG old2new($ss{tmpBinaryCmd}, "$rcsDir/rcs  -q -kb %FILENAME%",
                      "{RCS}{tmpBinaryCmd}");
    # hack, change lock behaviour
    $ss{ciCmd} =~ s/\b-l\b/-u/;
    print CFG old2new($ss{ciCmd}, "$rcsDir/ci  -q -u -m$cmdQuote%COMMENT%$cmdQuote -t-none -w$cmdQuote%USERNAME%$cmdQuote %FILENAME%",
                      "{RCS}{ciCmd}");
    print CFG old2new($ss{coCmd}, "$rcsDir/co  -q -p%REVISION% $keywordMode %FILENAME%",
                      "{RCS}{coCmd}");
    print CFG old2new($ss{histCmd}, "$rcsDir/rlog  -h %FILENAME%",
                      "{RCS}{histCmd}");
    print CFG old2new($ss{infoCmd}, "$rcsDir/rlog  -r%REVISION% %FILENAME%",
                      "{RCS}{infoCmd}");
    print CFG old2new($ss{diffCmd}, "$rcsDir/rcsdiff  -q -w -B -r%REVISION1% -r%REVISION2% $keywordMode --unified=%CONTEXT% %FILENAME%",
                      "{RCS}{diffCmd}");
    # hack, change lock behaviour
    $ss{unlockCmd} =~ s/\b-l\b/-u/;
    print CFG old2new($ss{unlockCmd}, "$rcsDir/rcs  -q -u -M %FILENAME%",
                      "{RCS}{unlockCmd}");
    $ss{lockCmd} =~ s/\b-l\b/-u/;
    print CFG old2new($ss{lockCmd}, "$rcsDir/rcs  -q -l %FILENAME%",
                      "{RCS}{lockCmd}");
    # hack, change lock behaviour
    $ss{ciDateCmd} =~ s/\b-l\b/-u/;
    print CFG old2new($ss{ciDateCmd}, "$rcsDir/ci -u  -q -mnone -t-none -d$cmdQuote%DATE%$cmdQuote -w$cmdQuote%USERNAME%$cmdQuote %FILENAME%",
                      "{RCS}{ciDateCmd}");
    print CFG old2new($ss{delRevCmd}, "$rcsDir/rcs  -q -o%REVISION% %FILENAME%",
                      "{RCS}{delRevCmd}");
    print CFG old2new($ss{tagCmd}, "$rcsDir/rcs  -N%TAG%:%REVISION% %FILENAME%",
                      "{RCS}{tagCmd}");

    close( CFG );
    print "$newConfigFile created...\n";
}

my @ActiveSubstitutions = ();

# If subs is true, then the mapping (from old value to new variable name)
# is cached and substituted into future expanded non-default values.
# Thus if $dataDir is /tmp/blah and debugLogFilename is
# "/tmp/blah/debug.txt" then this will be mapped to "$cfg{dataDir}/debug.txt"
# Note that the substitutions are done in order, so longer substitutions
# defined later in the config will override shorter ones defined earlier.
# NOTE THAT THE DEFAULT IS THE CAIRO DEFAULT, NOT THE DAKAR DEFAULT
sub old2new {
    my( $val, $default, $new, $subs) = @_;
    return "" unless defined $val;
    Carp::confess unless defined $default;
    if( $val ne $default ) {
        foreach my $subst ( @ActiveSubstitutions ) {
            $val =~ s/$subst/\$cfg$substs{$subst}/g;
        }

        if( $subs && $val ne "" ) {
            unshift(@ActiveSubstitutions, $val);
            $substs{$val} = $new;
        }

        return "\$cfg$new = \"$val\"; # $default\n";
    }
    return "";
}

1;


