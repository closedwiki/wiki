# used for testing only
use TWiki::TestMaker;

{ package TWiki;

use vars qw(
        $webName $topicName $includingWebName $includingTopicName
        $defaultUserName $userName $wikiName $wikiUserName
        $wikiHomeUrl $defaultUrlHost $urlHost
        $scriptUrlPath $pubUrlPath
        $pubDir $templateDir $dataDir $twikiLibDir
        $siteWebTopicName $wikiToolName $securityFilter $uploadFilter
        $debugFilename $warningFilename $htpasswdFilename
        $logFilename $remoteUserFilename $wikiUsersTopicname
        $userListFilename %userToWikiList %wikiToUserList
        $twikiWebname $mainWebname $mainTopicname $notifyTopicname
        $wikiPrefsTopicname $webPrefsTopicname
        $statisticsTopicname $statsTopViews $statsTopContrib
        $numberOfRevisions $editLockTime
        $attachAsciiPath $scriptSuffix $wikiversion
        $safeEnvPath $mailProgram $noSpamPadding $mimeTypesFilename
        $doKeepRevIfEditLock $doGetScriptUrlFromCgi $doRemovePortNumber
        $doRememberRemoteUser $doPluralToSingular
        $doHidePasswdInRegistration $doSecureInclude
        $doLogTopicView $doLogTopicEdit $doLogTopicSave $doLogRename
        $doLogTopicAttach $doLogTopicUpload $doLogTopicRdiff
        $doLogTopicChanges $doLogTopicSearch $doLogRegistration
        $disableAllPlugins
        @isoMonth $TranslationToken $code @code $depth %mon2num
        $newTopicFontColor $newTopicBgColor
        $headerPatternDa $headerPatternSp $headerPatternHt
        $debugUserTime $debugSystemTime
        $viewableAttachmentCount $noviewableAttachmentCount
        $superAdminGroup $doSuperAdminGroup
        $cgiQuery @publicWebList
        $formatVersion $OS
	$wikiWordRegex $webNameRegex $defaultWebNameRegex $anchorRegex $abbrevRegex $emailAddrRegex
	$singleUpperAlphaRegex $singleLowerAlphaRegex $singleUpperAlphaNumRegex
	$singleMixedAlphaNumRegex $singleMixedNonAlphaNumRegex 
	$singleMixedNonAlphaRegex $mixedAlphaNumRegex
    );

  use vars qw(
        $cmdQuote $lsCmd $egrepCmd $fgrepCmd
    );

  sub testinit {
    die "TWIKI_HOME not set" unless $ENV{'TWIKI_HOME'};
    do $ENV{'TWIKI_HOME'}."/lib/TWiki.cfg";
    $dataDir = TWiki::TestMaker::getDataDir();
    $pubDir =  TWiki::TestMaker::getPubDir();
    $notifyTopicname = "WebNotify";
    $egrepCmd = "/bin/egrep";
    $cmdQuote = "'";
    $securityFilter     = "[\\\*\?\~\^\$\@\%\`\"\'\&\;\|\<\>\x00-\x1F]";
	basicInitialize();
  }

sub basicInitialize() {
    # Set up locale for internationalisation and pre-compile regexes
    setupLocale();
    setupRegexes();
    
    $basicInitDone = 1;
}

sub setupLocale {
 
    $siteCharset = 'ISO-8859-1';	# Defaults if locale mis-configured
    $siteLang = 'en';

    if ( $useLocale ) {
	if ( not defined $siteLocale or $siteLocale !~ /[a-z]/i ) {
	  die "Locale $siteLocale unset or has no alphabetic characters";
	}
	# Extract the character set from locale and use in HTML templates
	# and HTTP headers
	$siteLocale =~ m/\.([a-z0-9_-]+)$/i;
	$siteCharset = $1 if defined $1;
	##writeDebug "Charset is now $siteCharset";

	# Extract the language - use to disable plural processing if
	# non-English
	$siteLocale =~ m/^([a-z]+)_/i;
	$siteLang = $1 if defined $1;
	##writeDebug "Language is now $siteLang";

	# Set environment variables for grep 
	# FIXME: collate probably not necessary since all sorting is done
	# in Perl
	$ENV{'LC_CTYPE'}= $siteLocale;
	$ENV{'LC_COLLATE'}= $siteLocale;

	# Load POSIX for i18n support 
	require POSIX;
	import POSIX qw( locale_h LC_CTYPE LC_COLLATE );

	##my $old_locale = setlocale(LC_CTYPE);
	##writeDebug "Old locale was $old_locale";

	# Set new locale
	my $locale = setlocale(&LC_CTYPE, $siteLocale);
	setlocale(&LC_COLLATE, $siteLocale);
	##writeDebug "New locale is $locale";
    }
}

sub setupRegexes {

    # Build up character class components for use in regexes.
    # Depends on locale mode and Perl version, and finally on
    # whether locale-based regexes are turned off.
    if ( not $useLocale or $] < 5.006 or not $localeRegexes ) {
	# No locales needed/working, or Perl 5.005_03 or lower, so just use
	# any additional national characters defined in TWiki.cfg
	$upperAlpha = "A-Z$upperNational";
	$lowerAlpha = "a-z$lowerNational";
	$numeric = '\d';
	$mixedAlpha = "${upperAlpha}${lowerAlpha}";
    } else {
	# Perl 5.6 or higher with working locales
	$upperAlpha = "[:upper:]";
	$lowerAlpha = "[:lower:]";
	$numeric = "[:digit:]";
	$mixedAlpha = "[:alpha:]";
    }
    $mixedAlphaNum = "${mixedAlpha}${numeric}";
    $lowerAlphaNum = "${lowerAlpha}${numeric}";

    # Compile regexes for efficiency and ease of use
    # Note: qr// locks in regex modes (i.e. '-xism' here) - see Friedl
    # book at http://regex.info/. 

    # TWiki concept regexes
    $wikiWordRegex = qr/[$upperAlpha]+[$lowerAlpha]+[$upperAlpha]+[$mixedAlphaNum]*/;
    $webNameRegex = qr/[$upperAlpha]+[$lowerAlphaNum]*/;
    $defaultWebNameRegex = qr/_[${mixedAlphaNum}_]+/;
    $anchorRegex = qr/\#[${mixedAlphaNum}_]+/;
    $abbrevRegex = qr/[$upperAlpha]{3,}/;

    # Simplistic email regex, e.g. for WebNotify processing - no i18n
    # characters allowed
    $emailAddrRegex = qr/([A-Za-z0-9\.\+\-\_]+\@[A-Za-z0-9\.\-]+)/;

    # Single-character alpha-based regexes
    $singleUpperAlphaRegex = qr/[$upperAlpha]/;
    $singleLowerAlphaRegex = qr/[$lowerAlpha]/;
    $singleUpperAlphaNumRegex = qr/[${upperAlpha}${numeric}]/;
    $singleMixedAlphaNumRegex = qr/[${upperAlpha}${lowerAlpha}${numeric}]/;

    $singleMixedNonAlphaRegex = qr/[^${upperAlpha}${lowerAlpha}]/;
    $singleMixedNonAlphaNumRegex = qr/[^${upperAlpha}${lowerAlpha}${numeric}]/;

    # Multi-character alpha-based regexes
    $mixedAlphaNumRegex = qr/[${mixedAlphaNum}]*/;

}
  sub initialize {
    my ( $path, $remuser, $topic, $url, $query ) = @_;

    # initialize $webName and $topicName
    $topicName = "";
    $webName   = "";
    if( $theTopic ) {
        if( $theTopic =~ /(.*)\.(.*)/ ) {
            # is "bin/script?topic=Webname.SomeTopic"
            $webName   = $1 || "";
            $topicName = $2 || "";
        } else {
            # is "bin/script/Webname?topic=SomeTopic"
            $topicName = $theTopic;
        }
    }
    ( $topicName =~ /\.\./ ) && ( $topicName = $mainTopicname );
    # filter out dangerous or unwanted characters:
    $topicName =~ s/$securityFilter//go;
    $topicName =~ /(.*)/;
    $topicName = $1 || $mainTopicname;  # untaint variable
    $webName   =~ s/$securityFilter//go;
    $webName   =~ /(.*)/;
    $webName   = $1 || $mainWebname;  # untaint variable
    $includingTopicName = $topicName;
    $includingWebName = $webName;

    return ( $topic, $webName, "scripturlpath", "testrunner", TWiki::TestMaker::getDataDir() );
  }

  sub getGmDate {
    return "GMDATE";
  }
}

1;
