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
    );

  use vars qw(
        $cmdQuote $lsCmd $egrepCmd $fgrepCmd
    );

  die "TWIKI_HOME not set" unless $ENV{'TWIKI_HOME'};
  do $ENV{'TWIKI_HOME'}."/lib/TWiki.cfg";
  TWiki::TestMaker::init();
  $dataDir = TWiki::TestMaker::getDataDir();
  $pubDir =  TWiki::TestMaker::getPubDir();
  $notifyTopicname = "WebNotify";
  $egrepCmd = "/bin/egrep";
  $cmdQuote = "'";
$securityFilter     = "[\\\*\?\~\^\$\@\%\`\"\'\&\;\|\<\>\x00-\x1F]";
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
    if( $thePathInfo =~ /\/(.*)\/(.*)/ ) {
        # is "bin/script/Webname/SomeTopic" or "bin/script/Webname/"
        $webName   = $1 || "" if( ! $webName );
        $topicName = $2 || "" if( ! $topicName );
    } elsif( $thePathInfo =~ /\/(.*)/ ) {
        # is "bin/script/Webname" or "bin/script/"
        $webName   = $1 || "" if( ! $webName );
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
}

1;
