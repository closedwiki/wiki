#
# TWiki WikiClone (see $wikiversion for version)
#
# Configuration and custom extensions for wiki.pm of TWiki.
#
# Copyright (C) 1999, 2000 Peter Thoeny, TakeFive Software Inc., 
# peter.thoeny@takefive.com , peter.thoeny@attglobal.net
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.ai.mit.edu/copyleft/gpl.html 
#
# Notes:
# - Latest version at http://www.mindspring.net/~peterthoeny/twiki/
# - Installation instructions in $dataDir/Main/TWikiDocumentation.txt
# - Customize variables in wikicfg.pm when installing TWiki.
# - Optionally change wikicfg.pm for custom extensions of rendering rules.
# - Files wikifcg.pm and wikisearch.pm are included by wiki.pm
# - Upgrading TWiki is easy as long as you do not customize wiki.pm.
# - Variables that can be accessed from topics (see details in
#   TWikiDocumentation.html) :
#       %TOPIC%          name of current topic
#       %WEB%            name of current web
#       %WIKIHOMEURL%    link of top left icon
#       %SCRIPTURL%      base TWiki script URL (place of view, edit...)
#       %SCRIPTURLPATH%  like %SCRIPTURL%, but path only (cut protocol and domain)
#       %SCRIPTSUFFIX%   script suffix (empty by default, ".pl" if required)
#       %PUBURL%         public URL (root of attachment URL)
#       %PUBURLPATH%     path of public URL
#       %ATTACHURL%      attachment URL of current topic
#       %ATTACHURLPATH%  path of attachment URL of current topic
#       %DATE%           today's date
#       %WIKIVERSION%    tool version
#       %USERNAME%       login user name
#       %WIKIUSERNAME%   wiki user name
#       %WIKITOOLNAME%   tool name (TWiki)
#       %MAINWEB%        main web name (Main)
#       %HOMETOPIC%      home topic name (WebHome)
#       %NOTIFYTOPIC%    notify topic name (WebNotify)
#       %WIKIUSERSTOPIC% user list topic name (TWikiUsers)
#       %WIKIPREFSTOPIC% site-level preferences topic name (TWikiPreferences)
#       %WEBPREFSTOPIC%  web preferences topic name (WebPreferences)
#       %STATISTICSTOPIC statistics topic name (WebStatistics)
#       %INCLUDE{...}%   server side include
#       %SEARCH{...}%    inline search


# variables that need to be changed when installing on a new server:
# ==================================================================
#                   %WIKIHOMEURL% : link of TWiki icon in upper left corner :
$wikiHomeUrl      = "http://your.domain.com/twiki/";
#                   Host of TWiki URL :    (Example "http://myhost.com:123")
$defaultUrlHost   = "http://your.domain.com";
#                   %SCRIPTURLPATH% : cgi-bin path of TWiki URL:
$scriptUrlPath    = "/twiki/bin";
#                   %PUBURLPATH% : Public data path of TWiki URL (root of attachments) :
$pubUrlPath       = "/twiki/pub";
#                   Public data directory, must match $pubUrlPath :
$pubDir           = "/home/httpd/twiki/pub";
#                   Template directory :
$templateDir      = "/home/httpd/twiki/templates";
#                   Data (topic files) root directory :
$dataDir          = "/home/httpd/twiki/data";

# variables that might need to be changed:
# ==================================================================
#                   %SCRIPTSUFFIX% : Suffix of TWiki Perl scripts (i.e. ".pl") :
$scriptSuffix     = "";
#                   set ENV{'PATH'} explicitly for taint checks ( #!perl -T option ) :
$envPath          = "/bin:/usr/bin";
#                   mail program :
$mailProgram      = "/usr/sbin/sendmail -t -oi -oeq";
#                   RCS directory (find out by 'which rcs') :
$rcsDir           = "/usr/bin";
#                   RCS check in command :
$revCiCmd         = "$rcsDir/ci -l -q -mnone -t-none -w'%USERNAME%' %FILENAME%";
#                   RCS check in command with date :
$revCiDateCmd     = "$rcsDir/ci -l -q -mnone -t-none -d'%DATE%' -w'%USERNAME%' %FILENAME%";
#                   RCS check out command :
$revCoCmd         = "$rcsDir/co -q -p%REVISION% %FILENAME%";
#                   RCS history command :
$revHistCmd       = "$rcsDir/rlog -h %FILENAME%";
#                   RCS history on revision command :
$revInfoCmd       = "$rcsDir/rlog -r%REVISION% %FILENAME%";
#                   RCS revision diff command :
$revDiffCmd       = "$rcsDir/rcsdiff -q -w -B -r%REVISION1% -r%REVISION2% %FILENAME%";
#                   RCS delete revision command :
$revDelRevCmd     = "$rcsDir/rcs -q -o%REVISION% %FILENAME%";
#                   RCS unlock command :
$revUnlockCmd     = "$rcsDir/rcs -q -u %FILENAME%";
#                   RCS lock command :
$revLockCmd       = "$rcsDir/rcs -q -l %FILENAME%";
#                   Unix ls command :
$lsCmd            = "/bin/ls";
#                   Unix cp command :
$cpCmd            = "/bin/cp";
#                   Unix egrep command :
$egrepCmd         = "/bin/egrep";
#                   Unix fgrep command :
$fgrepCmd         = "/bin/fgrep";

# variables that probably do not change:
# ==================================================================
#                   %WIKITOOLNAME% : TWiki tool name, default "TWiki" :
$wikiToolName       = "TWikibeta";
#                   Regex security filter for web name, topic name, user name :
$securityFilter     = "[\\\*\?\~\^\$\@\%\`\"\'\&\;\|\<\>\n\r]";
#                   Default user name, default "guest" :
$defaultUserName    = "guest";
#                   %MAINWEB% : Name of Main web, default "Main" :
$mainWebname        = "Main";
#                   Pathname of debug file :
$debugFilename      = "$dataDir/debug.txt";
#                   Pathname of user name/password file for authentication :
$htpasswdFilename   = "$dataDir/.htpasswd";
#                   Pathname of log file :
$logFilename        = "$dataDir/log%DATE%.txt";
#                   %WIKIUSERSTOPIC% : Name of users list topic :
$wikiUsersTopicname = "TWikiUsers";
#                   Pathname of users topic, used to translate Intranet name to Wiki name :
$userListFilename   = "$dataDir/$mainWebname/$wikiUsersTopicname.txt";
#                   %HOMETOPIC% : Name of main topic in a web, default "WebHome" :
$mainTopicname      = "WebHome";
#                   %NOTIFYTOPIC% : Name of topic for email notifications, default "WebNotify" :
$notifyTopicname  = "WebNotify";
#                   %WIKIPREFSTOPIC% : Name of site-level preferences topic, default "TWikiPreferences" :
$wikiPrefsTopicname = "TWikiPreferences";
#                   %WEBPREFSTOPIC% : Name of preferences topic in a web, default "WebPreferences" :
$webPrefsTopicname  = "WebPreferences";
#                   %STATISTICSTOPIC% : Name of statistics topic, default "WebStatistics" :
$statisticsTopicname = "WebStatistics";
#                   Number of top viewed topics to show in statistics topic, default "10" :
$statsTopViews      = "10";
#                   Number of top contributors to show in statistics topic, default "10" :
$statsTopContrib    = "10";
#                   Show how many number of revision links, "0" for all, default "4" :
$numberOfRevisions  = "4";
#                   Number of seconds a topic is locked during edit, default "3600" :
$editLockTime       = "3600";

# flag variables that could change:
# ==================================================================
# values are "0" for no, or "1" for yes
#                   Keep same revision if topic is saved again within edit lock time. Default "1"
$doKeepRevIfEditLock = "1";
#                   Remove port number from URL. Default "0"
$doRemovePortNumber = "0";
#                   Change non existing plural topic name to singular,
#                   e.g. TestPolicies to TestPolicy. Default "1"
$doPluralToSingular = "1";
#                   Log topic views to $logFilename. Default "0"
$doLogTopicView     = "0";
#                   Log topic saves to $logFilename. Default "0"
$doLogTopicEdit     = "0";
#                   Log topic saves to $logFilename. Default "1"
$doLogTopicSave     = "1";
#                   Log view attach to $logFilename. Default "0"
$doLogTopicAttach   = "0";
#                   Log file upload to $logFilename. Default "1"
$doLogTopicUpload   = "1";
#                   Log topic rdiffs to $logFilename. Default "0"
$doLogTopicRdiff    = "0";
#                   Log view changes to $logFilename. Default "0"
$doLogTopicChanges  = "0";
#                   Log view changes to $logFilename. Default "0"
$doLogTopicSearch   = "0";
#                   Log user registration to $logFilename. Default "1"
$doLogRegistration  = "1";


# =========================
sub extendHandleCommonTags
{
    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    my( $text, $topic ) = @_;

    # for compatibility for earlier TWiki versions:
    $text=~ s/%INCLUDE:"(.*?)"%/&handleIncludeFile($1)/geo;
    $text=~ s/%INCLUDE:"(.*?)"%/&handleIncludeFile($1)/geo;  # allow two level includes

    # do custom extension rule, like for example:
    # $text=~ s/%WIKIWEB%/$wikiToolName.$webName/go;

    return $text;
}


# =========================
sub extendGetRenderedVersionOutsidePRE
{
    # This is the place to define customized rendering rules
    # Called by sub getRenderedVersion, in loop outside of <PRE> tag

    my( $text ) = @_;

    # do custom extension rule, like for example:
    # s/old/new/go;

    # render *_text_* as "bold italic" text:
    s/(^|\s)\*_([^\s].*?[^\s])_\*(\s|$)/$1<STRONG><EM>$2<\/EM><\/STRONG>$3/go;

    # Use alternate %Web:WikiName% syntax (versus the standard Web.WikiName).
    # This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
#    s/(^|\s|\()\%([^\s].*?[^\s]):([^\s].*?[^\s])\%/&internalLink($2,$3,"$2:$3",$1,1)/geo;

    # Use "forced" non-WikiName links (i.e. %Linkname%)
    # This is an old JosWiki render option. (Uncomment for JosWiki compatibility)
#    s/(^|\s|\()\%([^\s].*?[^\s])\%/&internalLink($wiki::webName,$2,$2,$1,1)/geo;

    # Use "forced" non-WikiName links (i.e. %Web.Linkname%)
    # This is an old JosWiki render option combined with the new Web.LinkName notation
    # (Uncomment for JosWiki compatibility)
#    s/(^|\s|\()\%([a-zA-Z0-9]+)\.(.*?[^\s])\%(\s|\)|$)/&internalLink($2,$3,$3,$1,1)/geo;

    return $_;
}


# =========================
sub extendGetRenderedVersionInsidePRE
{
    # This is the place to define customized rendering rules
    # Called by sub getRenderedVersion, in loop inside of <PRE> tag

    my( $text ) = @_;

    # do custom extension rule, like for example:
    # s/old/new/go;

    return $_;
}
