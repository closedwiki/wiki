#
# TWiki WikiClone (see $wikiversion for version)
#
# Configuration and custom extensions for wiki.pm of TWiki.
#
# Copyright (C) 1999 Peter Thoeny, peter.thoeny@takefive.com , 
# TakeFive Software Inc.
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
# - Latest version at http://www.mindspring.net/~peterthoeny/twiki/index.html
# - Installation instructions in $dataDir/Main/TWikiDocumentation.txt
# - Customize variables in wikicfg.pm when installing TWiki.
# - Use package wikicfg.pm for custom extensions of rendering rules.
# - Upgrading TWiki is easy as long as you do not customize wiki.pm.
# - You can use variables in the wiki.pm namespace by including the
#   package name, e.g. $wiki::webName (name of the current web.)
# - Variables that can be accessed from topics (see details in
#   TWikiDocumentation.html) :
#       %TOPIC%          name of current topic
#       %WEB%            name of current web
#       %WIKIHOMEURL%    link of top left icon
#       %SCRIPTURL%      base TWiki script URL (place of view, edit...)
#       %PUBURL%         public URL (root of attachment URL)
#       %ATTACHURL%      attachment URL of current topic
#       %DATE%           today's date
#       %WIKIWEBMASTER%  webmaster email
#       %WIKIVERSION%    tool version
#       %USERNAME%       login user name
#       %WIKIUSERNAME%   wiki user name
#       %WIKITOOLNAME%   tool name

package wikicfg;
use wiki;

# variables that need to be changed when installing on a new server:
# ==================================================================
#                   %WIKIHOMEURL% : link of TWiki icon in upper left corner :
$wikiHomeUrl      = "http://your.domain.com/twiki";
#                   %SCRIPTURL% : cgi-bin URL of TWiki :
$defaultRootUrl   = "http://your.domain.com/twiki/bin";
#                   %PUBURL% : public data URL (root of attachments) :
$pubUrl           = "http://your.domain.com/twiki/pub";   # must match $pubDir
#                   TWiki root directory :
$wikiDir          = "/home/httpd/twiki";
#                   %WIKIWEBMASTER% : webmaster ("From:" in email notification) :
$wikiwebmaster    = "yourname\@your.domain.com";

# variables that might need to be changed:
# ==================================================================
#                   shell command to get date for $logFilename :
$logDateCmd       = "date '+%Y%m'";
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
$revDiffCmd       = "$rcsDir/rcsdiff -w -B -r%REVISION1% -r%REVISION2% %FILENAME%";
#                   RCS delete revision command :
$revDelRevCmd     = "$rcsDir/rcs -u %FILENAME%; rcs -o%REVISION% %FILENAME%; rcs -l %FILENAME%";
#                   Delete RCS repository file command :
$revDelRepCmd     = "rm -f %FILENAME%,v";
#                   Print head of files command :
$headCmd          = "head -%LINES% %FILENAME%";
#                   Delete file command :
$rmFileCmd        = "rm -f %FILENAME%";

# variables that probably do not change:
# ==================================================================
#                   %WIKITOOLNAME% : TWiki tool name :
$wikiToolName     = "betaTWiki";
#                   Template directory :
$templateDir      = "$wikiDir/bin/templates";
#                   Data (topic files) root directory :
$dataDir          = "$wikiDir/bin/data";
#                   Public data directory (root of attachments), must match $pubUrl :
$pubDir           = "$wikiDir/pub";
#                   Pathname of debug file :
$debugFilename    = "$wikiDir/bin/debug.txt";
#                   Pathname of log file :
$logFilename      = "$dataDir/log%DATE%.txt";
#                   Pathname of users topic, used to translate Intranet name to Wiki name :
$userListFilename = "$dataDir/Main/TWikiUsers.txt";
#                   Default user name :
$defaultUserName  = "guest";
#                   Name of Main web :
$mainWebname      = "Main";
#                   Name of main topic in a web :
$mainTopicname    = "WebHome";
#                   Name of topic for email notifications :
$notifyTopicname  = "WebNotify";


# =========================
sub extendHandleCommonTags
{
    # This is the place to define customized tags and variables
    # Called by wiki::handleCommonTags, after %INCLUDE:"..."%

    my( $text, $topic ) = @_;

    # do custom extension rule, like for example:
    # $text=~ s/%WIKIWEB%/$wiki::wikiToolName.$wiki::webName/go;

    return $text;
}


# =========================
sub extendGetRenderedVersionOutsidePRE
{
    # This is the place to define customized rendering rules
    # Called by wiki::getRenderedVersion, in loop outside of <PRE> tag

    my( $text ) = @_;

    # do custom extension rule, like for example:
    # s/old/new/go;

    # render *_text_* as "bold italic" text:
    s/(^|\s)\*_([^\s].*?[^\s])_\*(\s|$)/$1<STRONG><EM>$2<\/EM><\/STRONG>$3/go;

    return $_;
}


# =========================
sub extendGetRenderedVersionInsidePRE
{
    # This is the place to define customized rendering rules
    # Called by wiki::getRenderedVersion, in loop inside of <PRE> tag

    my( $text ) = @_;

    # do custom extension rule, like for example:
    # s/old/new/go;

    return $_;
}

1;
