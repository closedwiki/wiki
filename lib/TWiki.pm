# Main Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2004 Peter Thoeny, peter@thoeny.com
#
#
# For licensing info read license.txt file in the TWiki root.
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
=begin twiki

---+ TWiki Package
This package stores all TWiki subroutines that haven't been modularized
into any of the others.

=cut

package TWiki;

use strict;
use Assert;

require 5.005;		# For regex objects and internationalisation

# TWiki config variables from TWiki.cfg. These should be regarded as constants.
use vars qw(
            $defaultUserName $defaultWikiName
            $wikiHomeUrl $defaultUrlHost
            $scriptUrlPath $pubUrlPath $pubDir $templateDir $dataDir $logDir
            $siteWebTopicName $wikiToolName $securityFilter $uploadFilter
            $debugFilename $warningFilename $htpasswdFilename
            $logFilename $remoteUserFilename $wikiUsersTopicname
            $userListFilename $doMapUserToWikiName
            $twikiWebname $mainWebname $mainTopicname $notifyTopicname
            $wikiPrefsTopicname $webPrefsTopicname
            $statisticsTopicname $statsTopViews $statsTopContrib
            $doDebugStatistics
            $numberOfRevisions $editLockTime $scriptSuffix
            $safeEnvPath $mailProgram $noSpamPadding $mimeTypesFilename
            $doKeepRevIfEditLock $doGetScriptUrlFromCgi $doRemovePortNumber
            $doRemoveImgInMailnotify $doRememberRemoteUser $doPluralToSingular
            $doHidePasswdInRegistration $doSecureInclude
            $doLogTopicView $doLogTopicEdit $doLogTopicSave $doLogRename
            $doLogTopicAttach $doLogTopicUpload $doLogTopicRdiff
            $doLogTopicChanges $doLogTopicSearch $doLogRegistration
            $superAdminGroup $doSuperAdminGroup $OS $detailedOS
            $disableAllPlugins $attachAsciiPath $displayTimeValues
            $dispScriptUrlPath
            $useLocale
            $rcsDir $rcsArg $nullDev $endRcsCmd $storeTopicImpl $keywordMode
            @storeSettings
            $cmdQuote $lsCmd $egrepCmd $fgrepCmd $forceUnsafeRegexes
           );

# Other constants
use vars qw(
            $localeRegexes $siteLocale $siteCharsetOverride
            $upperNational $lowerNational
            $TranslationToken $twikiLibDir
            %regex
            %staticInternalTags
            %dynamicInternalTags
            $siteCharset $siteLang $siteFullLang $urlCharEncoding
            $langAlphabetic $VERSION
           );

$VERSION = ' $Date$ $Rev$ ';

# SMELL: should this be part of the config?
$defaultWikiName = "TWikiGuest";

# (new variables must be declared in "use vars qw(..)" above)
use constant ISOMONTH => qw( Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec );
use constant WEEKDAY => qw( Sun Mon Tue Wed Thu Fri Sat );

# Token character that must not occur in any normal text - converted
# to a flag character if it ever does occur (very unlikely)
$TranslationToken= "\0";	# Null not allowed in charsets used with TWiki

# STATIC locale setup - If $useLocale is set, this function parses
# $siteLocale from TWiki.cfg and passes it to the POSIX::setlocale
#  function to change TWiki's operating environment.
#
# SMELL: mod_perl compatibility note: If TWiki is running under Apache,
# won't this play with the Apache process's locale settings too?
# What effects would this have?
#
# Note that 'use locale' must be done in BEGIN block for regexes and sorting to
# work properly, although regexes can still work without this in
# 'non-locale regexes' mode (see _setupRegexes).

sub _setupLocale {
    $siteCharset = 'ISO-8859-1';	# Default values if locale mis-configured
    $siteLang = 'en';
    $siteFullLang = 'en-us';

    # Language assumed alphabetic unless otherwise configured - used to 
    # turn on filtering-in of valid characters in user input 
    $langAlphabetic = 1 if not defined $langAlphabetic;      # Default is 1 if not configured

    if ( $useLocale ) {
        if ( not defined $siteLocale or $siteLocale !~ /[a-z]/i ) {
            die "\$useLocale set but \$siteLocale $siteLocale unset or has no alphabetic characters";
        }
        # Extract the character set from locale and use in HTML templates
        # and HTTP headers
        $siteLocale =~ m/\.([a-z0-9_-]+)$/i;
        $siteCharset = $1 if defined $1;
        $siteCharset =~ s/^utf8$/utf-8/i;	# For convenience, avoid overrides
        $siteCharset =~ s/^eucjp$/euc-jp/i;

        # Override charset - used when locale charset not supported by Perl
        # conversion modules
        $siteCharset = $siteCharsetOverride || $siteCharset;
        $siteCharset = lc $siteCharset;

        # Extract the default site language - ignores '@euro' part of
        # 'fr_BE@euro' type locales.
        $siteLocale =~ m/^([a-z]+)_([a-z]+)/i;
        $siteLang = (lc $1) if defined $1;	# Not including country part
        $siteFullLang = (lc "$1-$2" ) 		# Including country part
          if defined $1 and defined $2;

        # Set environment variables for grep 
        $ENV{'LC_CTYPE'}= $siteLocale;

        # Load POSIX for I18N support. Eval because otherwise
        # it gets compiled even if we don't have a locale
        # SMELL: eval should not be necessary for require+import!
        eval 'require POSIX; import POSIX qw( locale_h LC_CTYPE );';

        # Set new locale - deliberately not checked since tested
        # in testenv
        my $locale = setlocale(&LC_CTYPE, $siteLocale);
    }
    $staticInternalTags{CHARSET} = $siteCharset;
    $staticInternalTags{SHORTLANG} = $siteLang;
    $staticInternalTags{LANG} = $siteFullLang;
}

# STATIC Set up pre-compiled regexes for use in rendering.  All regexes with
# unchanging variables in match should use the '/o' option, even if not in a
# loop.
# SMELL: use of $ua etc makes this routine longer and less readable - done for performance?
sub _setupRegexes {
    $regex{linkProtocolPattern} = "(file|ftp|gopher|https|http|irc|news|nntp|telnet)";

    # Header patterns based on '+++'. The '###' are reserved for numbered
    # headers
    # '---++ Header', '---## Header'
    $regex{headerPatternDa} = '^---+(\++|\#+)\s*(.+)\s*$';
    # '   ++ Header', '   + Header'
    $regex{headerPatternSp} = '^\t(\++|\#+)\s*(.+)\s*$';
    # '<h6>Header</h6>
    $regex{headerPatternHt} = '^<h([1-6])>\s*(.+?)\s*</h[1-6]>';
    # '---++!! Header' or '---++ Header %NOTOC% ^top'
    $regex{headerPatternNoTOC} = '(\!\!+|%NOTOC%)';

    # Build up character class components for use in regexes.
    # Depends on locale mode and Perl version, and finally on
    # whether locale-based regexes are turned off.
    my ( $ua, $la, $num, $ma );
    if ( not $useLocale or $] < 5.006 or not $localeRegexes ) {
        # No locales needed/working, or Perl 5.005, so just use
        # any additional national characters defined in TWiki.cfg
        $ua = "A-Z$upperNational";
        $la = "a-z$lowerNational";
        $num = '\d';
        $ma = "$ua$la";
    } else {
        # Perl 5.006 or higher with working locales
        $ua = "[:upper:]";
        $la = "[:lower:]";
        $num = "[:digit:]";
        $ma = "[:alpha:]";
    }
    $regex{upperAlpha} = $ua;
    $regex{lowerAlpha} = $la;
    $regex{numeric} = $num;
    $regex{mixedAlpha} = $ma;

    my $man = "$ma$num";
    $regex{mixedAlphaNum} = $man;
    my $lan = "$la$num";
    $regex{lowerAlphaNum} = $lan;
    my $uan = "$ua$num";
    $regex{upperAlphaNum} = $uan;

    # Compile regexes for efficiency and ease of use
    # Note: qr// locks in regex modes (i.e. '-xism' here) - see Friedl
    # book at http://regex.info/. 

    # TWiki concept regexes
    $regex{wikiWordRegex} = qr/[$ua]+[$la]+[$ua]+[$man]*/o;
    $regex{webNameRegex} = qr/[$ua]+[$man]*/o;
    $regex{defaultWebNameRegex} = qr/_[${man}_]+/o;
    $regex{anchorRegex} = qr/\#[${man}_]+/o;
    $regex{abbrevRegex} = qr/[$ua]{3,}s?\b/o;

    # Simplistic email regex, e.g. for WebNotify processing - no i18n
    # characters allowed
    $regex{emailAddrRegex} = qr/([A-Za-z0-9\.\+\-\_]+\@[A-Za-z0-9\.\-]+)/;

    # Filename regex, for attachments
    $regex{filenameRegex} = qr/[$man\.]+/o;

    # Multi-character alpha-based regexes
    $regex{mixedAlphaNumRegex} = qr/[$man]*/o;

    # Character encoding regexes

    # 7-bit ASCII only
    $regex{validAsciiStringRegex} = qr/^[\x00-\x7F]+$/o;

    # Regex to match only a valid UTF-8 character, taking care to avoid
    # security holes due to overlong encodings by excluding the relevant
    # gaps in UTF-8 encoding space - see 'perldoc perlunicode', Unicode
    # Encodings section.  Tested against Markus Kuhn's UTF-8 test file
    # at http://www.cl.cam.ac.uk/~mgk25/ucs/examples/UTF-8-test.txt.
    $regex{validUtf8CharRegex} = qr{
				# Single byte - ASCII
				[\x00-\x7F] 
				|

				# 2 bytes
				[\xC2-\xDF][\x80-\xBF] 
				|

				# 3 bytes

				    # Avoid illegal codepoints - negative lookahead
				    (?!\xEF\xBF[\xBE\xBF])	

				    # Match valid codepoints
				    (?:
					([\xE0][\xA0-\xBF])|
					([\xE1-\xEC\xEE-\xEF][\x80-\xBF])|
					([\xED][\x80-\x9F])
				    )
				    [\x80-\xBF]
				|

				# 4 bytes 
				    (?:
					([\xF0][\x90-\xBF])|
					([\xF1-\xF3][\x80-\xBF])|
					([\xF4][\x80-\x8F])
				    )
				    [\x80-\xBF][\x80-\xBF]
			    }xo;

    $regex{validUtf8StringRegex} =
      qr/^ (?: $regex{validUtf8CharRegex} )+ $/xo;

}

# STATIC When _expandAllTags matches a tag it looks up the
# tag in the tables below, and either does a literal
# expansion or calls the relevant _handle method for
# the tag.
sub _setupHandlerMaps {
    %staticInternalTags =
      (
       ENDSECTION      => "",
       HOMETOPIC       => $mainTopicname,
       MAINWEB         => $mainWebname,
       NOTIFYTOPIC     => $notifyTopicname,
       PUBURLPATH      => $pubUrlPath,
       SCRIPTSUFFIX    => $scriptSuffix,
       SCRIPTURLPATH   => $dispScriptUrlPath,
       SECTION         => "",
       STARTINCLUDE    => "",
       STATISTICSTOPIC => $statisticsTopicname,
       STOPINCLUDE     => "",
       TWIKIWEB        => $twikiWebname,
       WEBPREFSTOPIC   => $webPrefsTopicname,
       WIKIHOMEURL     => "$defaultUrlHost/$scriptUrlPath/view$scriptSuffix",
       WIKIPREFSTOPIC  => $wikiPrefsTopicname,
       WIKITOOLNAME    => $wikiToolName,
       WIKIUSERSTOPIC  => $wikiUsersTopicname,
       WIKIVERSION     => $VERSION,
      );

    %dynamicInternalTags =
      (
       ATTACHURLPATH     => \&_handleATTACHURLPATH,
       DATE              => \&_handleDATE,
       DISPLAYTIME       => \&_handleDISPLAYTIME,
       ENCODE            => \&_handleENCODE,
       FORMFIELD         => \&_handleFORMFIELD,,
       GMTIME            => \&_handleGMTIME,
       HTTP_HOST         => \&_handleHTTP_HOST,
       ICON              => \&_handleICON,
       INCLUDE           => \&_handleINCLUDE,
       INTURLENCODE      => \&_handleINTURLENCODE,
       METASEARCH        => \&_handleMETASEARCH,
       PLUGINVERSION     => \&_handlePLUGINVERSION,
       RELATIVETOPICPATH => \&_handleRELATIVETOPICPATH,
       REMOTE_ADDR       => \&_handleREMOTE_ADDR,
       REMOTE_PORT       => \&_handleREMOTE_PORT,
       REMOTE_USER       => \&_handleREMOTE_USER,
       REVINFO           => \&_handleREVINFO,
       SEARCH            => \&_handleSEARCH,
       SERVERTIME        => \&_handleSERVERTIME,
       SPACEDTOPIC       => \&_handleSPACEDTOPIC,
       "TMPL:P"          => \&_handleTMPLP,,
       TOPICLIST         => \&_handleTOPICLIST,
       URLENCODE         => \&_handleENCODE,
       URLPARAM          => \&_handleURLPARAM,
       VAR               => \&_handleVAR,
       WEBLIST           => \&_handleWEBLIST,
      );
}

BEGIN {
    # Read the configuration files at compile time in order to set locale
    do "TWiki.cfg";

    if( $useLocale ) {
        eval 'require locale; import locale ();';
    }

    _setupHandlerMaps();
    _setupLocale();
    _setupRegexes();
}

use TWiki::Sandbox;   # system command sandbox
use TWiki::Store;     # file I/O and rcs related functions
use TWiki::Prefs;     # preferences
use TWiki::Access;    # access control
use TWiki::Form;      # forms
use TWiki::Search;    # search engine
use TWiki::Plugins;   # plugins handler
use TWiki::User;
use TWiki::Render;    # HTML generation
use TWiki::Templates; # TWiki template language
use TWiki::Net;       # SMTP, get URL

# Concatenates date, time, and $text to a log file.
# The logfilename can optionally use a %DATE% variable to support
# logs that are rotated once a month.
# | =$log= | Base filename for log file |
# | =$message= | Message to print |
sub _writeReport {
    my ( $this, $log, $message ) = @_;

    if ( $log ) {
        my ( $sec, $min, $hour, $mday, $mon, $year ) = localtime( time() );
        my $yearmonth = sprintf( "%.4u%.2u", $year, $mon+1 );
        $log =~ s/%DATE%/$yearmonth/go;

        my $tmon = (ISOMONTH)[$mon];
        $year = sprintf( "%.4u", $year + 1900 );
        my $time = sprintf( "%.2u ${tmon} %.2u - %.2u:%.2u",
                            $mday, $year, $hour, $min );

        if( open( FILE, ">>$log" ) ) {
            print FILE "| $time | $message\n";
            close( FILE );
        } else {
            print STDERR "Couldn't write \"$message\" to $log: $!\n";
        }
    }
}

=pod

---++ writeLog (  $action, $webTopic, $extra, $user  )

Write the log for an event to the logfile

=cut

sub writeLog {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki") if DEBUG;
    my $action = shift || "";
    my $webTopic = shift || "";
    my $extra = shift || "";
    my $user = shift || "";

    my $wuserName = $user || $this->{userName};
    $wuserName = $this->{users}->userToWikiName( $wuserName );
    my $remoteAddr = $ENV{'REMOTE_ADDR'} || "";
    my $text = "$wuserName | $action | $webTopic | $extra | $remoteAddr |";

    $this->_writeReport( $logFilename, $text );
}

=pod

---++ writeWarning( $text )

Prints date, time, and contents $text to $warningFilename, typically
'warnings.txt'. Use for warnings and errors that may require admin
intervention. Use this for defensive programming warnings (e.g. assertions).

=cut

sub writeWarning {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki") if DEBUG;
    $this->_writeReport( $warningFilename, @_ );
}

=pod

---++ writeDebug( $text )

Prints date, time, and contents of $text to $debugFilename, typically
'debug.txt'.  Use for debugging messages.

=cut

sub writeDebug {
    my $this = shift;
    ASSERT(ref($this) eq "TWiki") if DEBUG;
    $this->_writeReport( $debugFilename, @_ );
}

=pod

---++ initialize( $pathInfo, $remoteUser, $topic, $url, $query )
Return value: ( $topicName, $webName, $scriptUrlPath, $userName, $dataDir )

STATIC Constructs a new singleton session instance.

DEPRECATED maintained for script compatibility. Note that if a plugin
uses this method and then calls a Func method, the Func method will use
the session object in place when the plugin handler was invoked, and
_will not_ re-initialise twiki.

=cut

sub initialize {
    my ( $pathInfo, $theRemoteUser, $topic, $theUrl, $theQuery ) = @_;

    my $twiki = new TWiki( $pathInfo, $theRemoteUser, $topic, $theUrl, $theQuery );

    # Attempt to force the new session into the plugins context. This may not work.
    $TWiki::Plugins::SESSION = $twiki;

    return ( $twiki->{topicName}, $twiki->{webName}, $twiki->{scriptUrlPath},
             $twiki->{userName}, $dataDir );
}

# Return value: boolean $isCharsetInvalid
# Check for unusable multi-byte encodings as site character set
# - anything that enables a single ASCII character such as '[' to be
# matched within a multi-byte character cannot be used for TWiki.
sub _invalidSiteCharset {
    # FIXME: match other problematic multi-byte character sets 
    return ( $siteCharset =~ /^(?:iso-?2022-?|hz-?|gb2312|gbk|gb18030|.*big5|.*shift_?jis|ms.kanji|johab|uhc)/i );
}

# Auto-detect UTF-8 vs. site charset in URL, and convert UTF-8 into site charset.
# TODO: remove dependence on webname and topicname.
sub _convertUtf8URLtoSiteCharset {
    my $this = shift;

    my $fullTopicName = "$this->{webName}.$this->{topicName}";
    my $charEncoding;

    # Detect character encoding of the full topic name from URL
    if ( $fullTopicName =~ $regex{validAsciiStringRegex} ) {
        $urlCharEncoding = 'ASCII';
    } elsif ( $fullTopicName =~ $regex{validUtf8StringRegex} ) {
        $urlCharEncoding = 'UTF-8';

        # Convert into ISO-8859-1 if it is the site charset
        if ( $siteCharset =~ /^iso-?8859-?1$/i ) {
            # ISO-8859-1 maps onto first 256 codepoints of Unicode
            # (conversion from 'perldoc perluniintro')
            $fullTopicName =~ s/ ([\xC2\xC3]) ([\x80-\xBF]) / 
              chr( ord($1) << 6 & 0xC0 | ord($2) & 0x3F )
                /egx;
        } elsif ( $siteCharset eq "utf-8" ) {
            # Convert into internal Unicode characters if on Perl 5.8 or higher.
            if( $] >= 5.008 ) {
                require Encode;			# Perl 5.8 or higher only
                $fullTopicName = Encode::decode("utf8", $fullTopicName);	# 'decode' into UTF-8
            } else {
                $this->writeWarning( "UTF-8 not supported on Perl $] - use Perl 5.8 or higher." );
            }
            $this->writeWarning( "UTF-8 not yet supported as site charset - TWiki is likely to have problems" );
        } else {
            # Convert from UTF-8 into some other site charset
            $this->writeDebug( "Converting from UTF-8 to $siteCharset" );

            # Use conversion modules depending on Perl version
            if( $] >= 5.008 ) {
                require Encode;			# Perl 5.8 or higher only
                import Encode qw(:fallbacks);
                # Map $siteCharset into real encoding name
                $charEncoding = Encode::resolve_alias( $siteCharset );
                if( not $charEncoding ) {
                    $this->writeWarning( "Conversion to \$siteCharset '$siteCharset' not supported, or name not recognised - check 'perldoc Encode::Supported'" );
                } else {
                    ##$this->writeDebug "Converting with Encode, valid 'to' encoding is '$charEncoding'";
                    # Convert text using Encode:
                    # - first, convert from UTF8 bytes into internal (UTF-8) characters
                    $fullTopicName = Encode::decode("utf8", $fullTopicName);	
                    # - then convert into site charset from internal UTF-8,
                    # inserting \x{NNNN} for characters that can't be converted
                    $fullTopicName = Encode::encode( $charEncoding, $fullTopicName, &FB_PERLQQ() );
                    ##$this->writeDebug "Encode result is $fullTopicName";
                }
            } else {
                require Unicode::MapUTF8;	# Pre-5.8 Perl versions
                $charEncoding = $siteCharset;
                if( not Unicode::MapUTF8::utf8_supported_charset($charEncoding) ) {
                    $this->writeWarning( "Conversion to \$siteCharset '$siteCharset' not supported, or name not recognised - check 'perldoc Unicode::MapUTF8'" );
                } else {
                    # Convert text
                    ##$this->writeDebug "Converting with Unicode::MapUTF8, valid encoding is '$charEncoding'";
                    $fullTopicName = Unicode::MapUTF8::from_utf8({ 
                                                                  -string => $fullTopicName, 
                                                                  -charset => $charEncoding });
                    # FIXME: Check for failed conversion?
                }
            }
        }
        $fullTopicName =~ /^(.*?)\.([^.]*)$/;
        $this->{webName} = $1;
        $this->{topicName} = $2;
    } else {
        # Non-ASCII and non-UTF-8 - assume in site character set, 
        # no conversion required
        $urlCharEncoding = 'Native';
        $charEncoding = $siteCharset;
    }
    ##$this->writeDebug "Final web and topic are $this->{webName} $this->{topicName} ($urlCharEncoding URL -> $siteCharset)";
}

=pod

---++ writeCompletePage( $text )

Write a complete HTML page with basic header to the browser.

=cut

sub writeCompletePage {
    my ( $this, $text, $pageType, $contentType ) = @_;

    ASSERT(ref($this) eq "TWiki") if DEBUG;

    $text .= "\n" unless $text =~ /\n$/s;

    # can't use simple length() in case we have UNICODE
    # see perldoc -f length
    my $len = do { use bytes; length( $text ); };
    $this->writePageHeader( undef, $pageType, $contentType, $len );
    print $text;
}

=pod

---++ writePageHeader( $query, $pageType, $contentType, $contentLength )

All parameters are optional.

| $query | CGI query object | Session CGI query (there is no good reason to set this) |
| $pageType | May be "edit", which will cause headers to be generated that force caching for 24 hours, to prevent Codev.BackFromPreviewLosesText bug, which caused data loss with IE5 and IE6. |
| $contentType | page content type | text/html |
| $contentLength | content-length | no content-length will be set if this is undefined, as required by HTTP1.1 |

Implements the post-Dec2001 release plugin API, which requires the
writeHeaderHandler in plugin to return a string of HTTP headers, CR/LF
delimited. Filters any illegal headers. Plugin headers will override
core settings.

=cut

sub writePageHeader {
    my( $this, $query, $pageType, $contentType, $contentLength ) = @_;

    ASSERT(ref($this) eq "TWiki") if DEBUG;

    $query = $this->{cgiQuery} unless $query;

    # Handle Edit pages - future versions will extend to caching
    # of other types of page, with expiry time driven by page type.
    my( $pluginHeaders, $coreHeaders );

    my @hopts = ();

    $contentType = "text/html" unless $contentType;
    $contentType .= "; charset=$siteCharset";
    push( @hopts, -content_type => $contentType );

    if ($pageType && $pageType eq 'edit') {
        # Get time now in HTTP header format
        my $lastModifiedString = formatTime(time, '\$http', "gmtime");

        # Expiry time is set high to avoid any data loss.  Each instance of 
        # Edit page has a unique URL with time-string suffix (fix for 
        # RefreshEditPage), so this long expiry time simply means that the 
        # browser Back button always works.  The next Edit on this page 
        # will use another URL and therefore won't use any cached 
        # version of this Edit page.
        my $expireHours = 24;
        my $expireSeconds = $expireHours * 60 * 60;

        # and cache control headers, to ensure edit page 
        # is cached until required expiry time.
        push( @hopts, -last_modified => $lastModifiedString );
        push( @hopts, -expires => "+${expireHours}h" );
        push( @hopts, -cache_control => "max-age=$expireSeconds" );
    }

    # Add a content-length if one has been provided. HTTP1.1 says a
    # content-length should _not_ be specified unless the length is
    # known. There is a bug in Netscape such that it interprets a
    # 0 content-length as "download until disconnect" but that is
    # a bug. The correct way is to not set a content-length.
    push( @hopts, -content_length => $contentLength ) if $contentLength;

    # Wiki Plugin Hook - get additional headers from plugin
    # SMELL: it would be far better to pass down the hopts array
    # for the plugin to add to/remove from, rather than parsing the
    # string this way.
    $pluginHeaders = $this->{plugins}->writeHeaderHandler( $query ) || '';
    if( $pluginHeaders ) {
        foreach ( split /\r\n/, $pluginHeaders ) {
            if ( m/^([\-a-z]+): (.*)$/i ) {
                push( @hopts, $1 => $2 );
            }
        }
    }

    print $query->header( @hopts );
}

=pod

---++ redirect( $url, ... )

$url is required.

Generate a CGI redirect unless (1) $session->{cgiQuery} is undef or
(2) $query->param('noredirect') is set to any value. Thus a redirect is
only generated when in a CGI context.

The ... parameters are concatenated to the message written when printing
to STDOUT, and are ignored for a redirect.

Redirects the request to $url, via the CGI module object $query unless
overridden by a plugin declaring a =redirectCgiQueryHandler=.

=cut

sub redirect {
    my $this = shift;
    my $url = shift;

    ASSERT(ref($this) eq "TWiki") if DEBUG;

    my $query = $this->{cgiQuery};

    unless( $this->{plugins}->redirectCgiQueryHandler( $query, $url ) ) {
        if ( $query && $query->param( 'noredirect' )) {
            my $content = join(" ", @_) . " \n";
            $this->writeCompletePage( $query, $content );
        } elsif ( $query ) {
            print $query->redirect( $url );
        }
    }
}

=pod

---++ isValidWikiWord (  $name  )
Check for a valid WikiWord or WikiName

=cut

sub isValidWikiWord {
    my $name  = shift || "";
    return ( $name =~ m/^$regex{wikiWordRegex}$/o )
}

=pod

---++ isValidTopicName (  $name  )
Check for a valid topic name

=cut

sub isValidTopicName {
    my( $name ) = @_;

    return isValidWikiWord( @_ ) || isValidAbbrev( @_ );
}

=pod

---++ isValidAbbrev (  $name  )
Check for a valid ABBREV (acronym)

=cut

sub isValidAbbrev {
    my $name = shift || "";
    return ( $name =~ m/^$regex{abbrevRegex}$/o )
}

=pod

---++ isValidWebName (  $name  )

STATIC Check for a valid web name. If $system is true, then
system web names are considered valid (names startingn with _)
otherwise only user web names are valid

=cut

sub isValidWebName {
    my $name = shift || "";
    my $sys = shift;
    return 1 if ( $sys && $name =~ m/^$regex{defaultWebNameRegex}$/o );
    return ( $name =~ m/^$regex{webNameRegex}$/o )
}

=pod

---++ readOnlyMirrorWeb (  $theWeb  )

If this is a mirrored web, return information about the mirror. The info
is returned in a quadruple:
| site name | URL | link | note |

=cut

sub readOnlyMirrorWeb {
    my( $this, $theWeb ) = @_;

    ASSERT(ref($this) eq "TWiki") if DEBUG;

    my @mirrorInfo = ( "", "", "", "" );
    if( $siteWebTopicName ) {
        my $mirrorSiteName =
          $this->{prefs}->getPreferencesValue( "MIRRORSITENAME", $theWeb );
        if( $mirrorSiteName && $mirrorSiteName ne $siteWebTopicName ) {
            my $mirrorViewURL  =
              $this->{prefs}->getPreferencesValue( "MIRRORVIEWURL", $theWeb );
            my $mirrorLink = TWiki::Store::readTemplate( "mirrorlink" );
            $mirrorLink =~ s/%MIRRORSITENAME%/$mirrorSiteName/g;
            $mirrorLink =~ s/%MIRRORVIEWURL%/$mirrorViewURL/g;
            $mirrorLink =~ s/\s*$//g;
            my $mirrorNote = TWiki::Store::readTemplate( "mirrornote" );
            $mirrorNote =~ s/%MIRRORSITENAME%/$mirrorSiteName/g;
            $mirrorNote =~ s/%MIRRORVIEWURL%/$mirrorViewURL/g;
            $mirrorNote = $this->{renderer}->getRenderedVersion( $mirrorNote, $theWeb );
            $mirrorNote =~ s/\s*$//g;
            @mirrorInfo = ( $mirrorSiteName, $mirrorViewURL, $mirrorLink, $mirrorNote );
        }
    }
    return @mirrorInfo;
}

=pod

---++ getTWikiLibDir()

If necessary, finds the full path of the directory containing TWiki.pm,
and sets the variable $twikiLibDir so that this process is only performed
once per invocation.  (mod_perl safe: lib dir doesn't change.)

=cut

sub getTWikiLibDir {
    if( $twikiLibDir ) {
        return $twikiLibDir;
    }

    # FIXME: Should just use $INC{"TWiki.pm"} to get path used to load this
    # module.
    my $dir = "";
    foreach $dir ( @INC ) {
        if( -e "$dir/TWiki.pm" ) {
            $twikiLibDir = $dir;
            last;
        }
    }

    # fix path relative to location of called script
    if( $twikiLibDir =~ /^\./ ) {
        print STDERR "WARNING: TWiki lib path $twikiLibDir is relative; you should make it absolute, otherwise some scripts may not run from the command line.";
        my $bin;
        if( $ENV{"SCRIPT_FILENAME"} &&
            $ENV{"SCRIPT_FILENAME"} =~ /^(.+)\/[^\/]+$/ ) {
            # CGI script name
            $bin = $1;
        } elsif ( $0 =~ /^(.*)\/.*?$/ ) {
            # program name
            $bin = $1;
        } else {
            # last ditch; relative to current directory.
            eval 'use Cwd qw( cwd ); $bin = cwd();';
        }
        $twikiLibDir = "$bin/$twikiLibDir/";
        # normalize "/../" and "/./"
        while ( $twikiLibDir =~ s|([\\/])[^\\/]+[\\/]\.\.[\\/]|$1| ) {
        };
        $twikiLibDir =~ s|([\\/])\.[\\/]|$1|g;
    }
    $twikiLibDir =~ s|([\\/])[\\/]*|$1|g; # reduce "//" to "/"
    $twikiLibDir =~ s|[\\/]$||;           # cut trailing "/"

    return $twikiLibDir;
}

=pod

---++ getSkin ()

Get the name of the currently requested skin

=cut

sub getSkin {
    my $this = shift;

    ASSERT(ref($this) eq "TWiki") if DEBUG;

    my $skin = "";
    $skin = $this->{cgiQuery}->param( 'skin' ) if( $this->{cgiQuery} );
    $skin = $this->{prefs}->getPreferencesValue( "SKIN" ) unless( $skin );
    return $skin;
}

=pod

---++ getViewUrl (  $web, $topic  )

Returns a fully-qualified URL to the specified topic.
#SMELL - how is this diferent from getScriptUrl ?

=cut

sub getViewUrl {
    my( $this, $theWeb, $theTopic ) = @_;

    ASSERT(ref($this) eq "TWiki") if DEBUG;

    $theWeb = $this->{webName} unless $theWeb;

    $theTopic =~ s/\s*//gs; # Illegal URL, remove space

    return $this->{urlHost}."$dispScriptUrlPath/view$scriptSuffix/$theWeb/$theTopic";
}

=pod

---++ getScriptURL( $web, $topic, $script )
Return value: $absoluteScriptURL

Returns the absolute URL to a TWiki script, providing the wub and topic as
"path info" parameters.  The result looks something like this:
"http://host/twiki/bin/$script/$web/$topic"

=cut

sub getScriptUrl {
    my( $this, $theWeb, $theTopic, $theScript ) = @_;

    ASSERT(ref($this) eq "TWiki") if DEBUG;

    my $url = "$this->{urlHost}$dispScriptUrlPath/$theScript$scriptSuffix/$theWeb/$theTopic";
    # FIXME consider a plugin call here - useful for certificated logon environment
    return $url;
}

=pod

---++ getOopsUrl( $web, $topic, $template, @scriptParams )
Return Value: $absoluteOopsURL

Composes a URL for an "oops" error page.  The last parameters depend on the
specific oops template in use, and are passed in the URL as 'param1..paramN'.

The returned URL ends up looking something like:
"http://host/twiki/bin/oops/$web/$topic?template=$template&param1=$scriptParams[0]..."

=cut

sub getOopsUrl {
    my( $this, $theWeb, $theTopic, $theTemplate,
        $theParam1, $theParam2, $theParam3, $theParam4 ) = @_;

    ASSERT(ref($this) eq "TWiki") if DEBUG;

    my $web = $this->{webName};  # current web
    if( $theWeb ) {
        $web = $theWeb;
    }
    my $url = "";
    # $this->{urlHost} is needed, see Codev.PageRedirectionNotWorking
    $url = $this->getScriptUrl( $web, $theTopic, "oops" );
    $url .= "\?template=$theTemplate";
    $url .= "\&amp;param1=" . _urlEncode( $theParam1 ) if ( $theParam1 );
    $url .= "\&amp;param2=" . _urlEncode( $theParam2 ) if ( $theParam2 );
    $url .= "\&amp;param3=" . _urlEncode( $theParam3 ) if ( $theParam3 );
    $url .= "\&amp;param4=" . _urlEncode( $theParam4 ) if ( $theParam4 );

    return $url;
}

=pod

---++ normalizeWebTopicName (  $theWeb, $theTopic  )

Normalize a Web.TopicName
<pre>
Input:                      Return:
  ( "Web",  "Topic" )         ( "Web",  "Topic" )
  ( "",     "Topic" )         ( "Main", "Topic" )
  ( "",     "" )              ( "Main", "WebHome" )
  ( "",     "Web/Topic" )     ( "Web",  "Topic" )
  ( "",     "Web.Topic" )     ( "Web",  "Topic" )
  ( "Web1", "Web2.Topic" )    ( "Web2", "Topic" )
</pre>
Note: Function renamed from getWebTopic

=cut

sub normalizeWebTopicName {
    my( $this, $theWeb, $theTopic ) = @_;

    ASSERT(ref($this) eq "TWiki") if DEBUG;

    if( $theTopic =~ m|^([^.]+)[\.\/](.*)$| ) {
        $theWeb = $1;
        $theTopic = $2;
    }
    $theWeb = $this->{webName} unless( $theWeb );
    $theTopic = $this->{topicName} unless( $theTopic );

    return( $theWeb, $theTopic );
}

=pod

---++ extractParameters (  $str )

Extracts parameters from a variable string and returns a hash with all parameters.
The nameless parameter key is _DEFAULT.

   * Example variable: %TEST{ "nameless" name1="val1" name2="val2" }%
   * First extract text between {...} to get: "nameless" name1="val1" name2="val2"
   * Then call this on the text:
   * =my %params = TWiki::Func::extractParameters( $text );=
   * The hash contains now: <br />
     _DEFAULT => "nameless" <br />
     name1 => "val1" <br />
     name2 => "val2"

SMELL: shouldn't this return a Hash reference? (had to make makeHashRefFromHash for 
		 expandVariablesOnTopicCreation) 

=cut

sub extractParameters {
    my( $str ) = @_;

    my %params = ();
    return %params unless defined $str;
    $str =~ s/\\\"/\\$TranslationToken/g;  # escape \"

    if( $str =~ s/^\s*\"(.*?)\"\s*(\w+\s*=\s*\"|$)/$2/ ) {
        # is: %VAR{ "value" }%
        # or: %VAR{ "value" param="etc" ... }%
        # Note: "value" may contain embedded double quotes
        $params{"_DEFAULT"} = $1 if defined $1;  # distinguish between "" and "0";
        if( $2 ) {
            while( $str =~ s/^\s*(\w+)\s*=\s*\"([^\"]*)\"// ) {
                $params{"$1"} = $2 if defined $2;
            }
        }
    } elsif( ( $str =~ s/^\s*(\w+)\s*=\s*\"([^\"]*)\"// ) && ( $1 ) ) {
        # is: %VAR{ name = "value" }%
        $params{"$1"} = $2 if defined $2;
        while( $str =~ s/^\s*(\w+)\s*=\s*\"([^\"]*)\"// ) {
            $params{"$1"} = $2 if defined $2;
        }
    } elsif( $str =~ s/^\s*(.*?)\s*$// ) {
        # is: %VAR{ value }%
        $params{"_DEFAULT"} = $1 unless $1 eq "";
    }
    return map{ s/\\$TranslationToken/\"/go; $_ } %params;
}

=pod

---++ extractNameValuePair (  $str, $name  )

Extract a named or unnamed value from a variable parameter string
Function extractParameters is more efficient for extracting several parameters
| =$attr= | Attribute string |
| =$name= | Name, optional |
| Return: =$value=   | Extracted value |

=cut

sub extractNameValuePair {
    my( $str, $name ) = @_;

    my $value = "";
    return $value unless( $str );
    $str =~ s/\\\"/\\$TranslationToken/g;  # escape \"

    if( $name ) {
        # format is: %VAR{ ... name = "value" }%
        if( $str =~ /(^|[^\S])$name\s*=\s*\"([^\"]*)\"/ ) {
            $value = $2 if defined $2;  # distinguish between "" and "0"
        }

    } else {
        # test if format: { "value" ... }
        if( $str =~ /(^|\=\s*\"[^\"]*\")\s*\"(.*?)\"\s*(\w+\s*=\s*\"|$)/ ) {
            # is: %VAR{ "value" }%
            # or: %VAR{ "value" param="etc" ... }%
            # or: %VAR{ ... = "..." "value" ... }%
            # Note: "value" may contain embedded double quotes
            $value = $2 if defined $2;  # distinguish between "" and "0";

        } elsif( ( $str =~ /^\s*\w+\s*=\s*\"([^\"]*)/ ) && ( $1 ) ) {
            # is: %VAR{ name = "value" }%
            # do nothing, is not a standalone var

        } else {
            # format is: %VAR{ value }%
            $value = $str;
        }
    }
    $value =~ s/\\$TranslationToken/\"/go;  # resolve \"
    return $value;
}

sub _fixN {
    my( $theTag ) = @_;
    $theTag =~ s/[\r\n]+//gs;
    return $theTag;
}

# Convert relative URLs to absolute URIs
sub _fixURL {
    my( $theHost, $theAbsPath, $theUrl ) = @_;

    my $url = $theUrl;
    if( $url =~ /^\// ) {
        # fix absolute URL
        $url = "$theHost$url";
    } elsif( $url =~ /^\./ ) {
        # fix relative URL
        $url = "$theHost$theAbsPath/$url";
    } elsif( $url =~ /^$regex{linkProtocolPattern}\:/o ) {
        # full qualified URL, do nothing
    } elsif( $url ) {
        # FIXME: is this test enough to detect relative URLs?
        $url = "$theHost$theAbsPath/$url";
    }

    return $url;
}

sub _fixIncludeLink {
    my( $theWeb, $theLink, $theLabel ) = @_;

    # [[...][...]] link
    if( $theLink =~ /^($regex{webNameRegex}\.|$regex{defaultWebNameRegex}\.|$regex{linkProtocolPattern}\:)/o ) {
        if ( $theLabel ) {
            return "[[$theLink][$theLabel]]";
        } else {
            return "[[$theLink]]";
        }
    } elsif ( $theLabel ) {
        return "[[$theWeb.$theLink][$theLabel]]";
    } else {
        return "[[$theWeb.$theLink][$theLink]]";
    }
}

# Clean-up HTML text so that it can be shown embedded in a topic
sub _cleanupIncludedHTML {
    my( $text, $host, $path ) = @_;

    # FIXME: Make aware of <base> tag

    $text =~ s/^.*?<\/head>//is;            # remove all HEAD
    $text =~ s/<script.*?<\/script>//gis;   # remove all SCRIPTs
    $text =~ s/^.*?<body[^>]*>//is;         # remove all to <BODY>
    $text =~ s/(?:\n)<\/body>//is;          # remove </BODY>
    $text =~ s/(?:\n)<\/html>//is;          # remove </HTML>
    $text =~ s/(<[^>]*>)/&_fixN($1)/ges;     # join tags to one line each
    $text =~ s/(\s(href|src|action)\=[\"\']?)([^\"\'\>\s]*)/$1 . &_fixURL( $host, $path, $3 )/geois;

    return $text;
}

=pod

---++ applyPatternToIncludedText (  $theText, $thePattern )

Apply a pattern on included text to extract a subset

=cut

sub applyPatternToIncludedText {
    my( $theText, $thePattern ) = @_;
    $thePattern =~ s/([^\\])([\$\@\%\&\#\'\`\/])/$1\\$2/g;  # escape some special chars
    $thePattern = TWiki::Sandbox::untaintUnchecked( $thePattern );
    $theText = "" unless( $theText =~ s/$thePattern/$1/is );
    return $theText;
}

sub _handleFORMFIELD {
    my $this = shift;
    return $this->{renderer}->renderFormField( @_ );
}

sub _handleTMPLP {
    my( $this, $params ) = @_;
    return $this->{templates}->expandTemplate( $params->{_DEFAULT} );
}

sub _handleVAR {
    my( $this, $params, $topic, $inweb ) = @_;
    my $key = $params->{_DEFAULT};
    my $web = $params->{web} || $inweb;
    if( $web =~ /%[A-Z]+%/ ) { # handle %MAINWEB%-type cases 
        handleInternalTags( $web, $inweb, $topic );
    }
    return $this->{prefs}->getPreferencesValue( $key, $web );
}

sub _handlePLUGINVERSION {
    my( $this, $params ) = @_;
    $this->{plugins}->getPluginVersion( $params->{_DEFAULT} );
}

# Fetch content from a URL for includion by an INCLUDE
sub _includeUrl {
    my( $this, $theUrl, $thePattern, $theWeb, $theTopic ) = @_;
    my $text = "";
    my $host = "";
    my $port = 80;
    my $path = "";
    my $user = "";
    my $pass = "";

    # For speed, read file directly if URL matches an attachment directory
    if( $theUrl =~ /^$this->{urlHost}$pubUrlPath\/([^\/\.]+)\/([^\/\.]+)\/([^\/]+)$/ ) {
        my $web = $1;
        my $topic = $2;
        my $fileName = "$pubDir/$web/$topic/$3";
        if( $fileName =~ m/\.(txt|html?)$/i ) {       # FIXME: Check for MIME type, not file suffix
            unless( -e $fileName ) {
                return _inlineError( "Error: File attachment at $theUrl does not exist" );
            }
            if( "$web.$topic" ne "$theWeb.$theTopic" ) {
                # CODE_SMELL: Does not account for not yet authenticated user
                unless( $this->{security}->checkAccessPermission( "VIEW",
                                                                 $this->{wikiUserName},
                                                                 "", $topic,
                                                                 $web ) ) {
                    return _inlineError( "Error: No permission to view files attached to $web.$topic" );
                }
            }
            $text = $this->{store}->readFile( $fileName );
            $text = _cleanupIncludedHTML( $text, $this->{urlHost}, $pubUrlPath );
            $text = applyPatternToIncludedText( $text, $thePattern ) if( $thePattern );
            return $text;
        }
        # fall through; try to include file over http based on MIME setting
    }

    if( $theUrl =~ /http\:\/\/(.+)\:(.+)\@([^\:]+)\:([0-9]+)(\/.*)/ ) {
        ( $user, $pass, $host, $port, $path ) = ( $1, $2, $3, $4, $5 );
    } elsif( $theUrl =~ /http\:\/\/(.+)\:(.+)\@([^\/]+)(\/.*)/ ) {
        ( $user, $pass, $host, $path ) = ( $1, $2, $3, $4 );
    } elsif( $theUrl =~ /http\:\/\/([^\:]+)\:([0-9]+)(\/.*)/ ) {
        ( $host, $port, $path ) = ( $1, $2, $3 );
    } elsif( $theUrl =~ /http\:\/\/([^\/]+)(\/.*)/ ) {
        ( $host, $path ) = ( $1, $2 );
    } else {
        $text = _inlineError( "Error: Unsupported protocol. (Must be 'http://domain/...')" );
        return $text;
    }

    $text = $this->{net}->getUrl( $host, $port, $path, $user, $pass );
    $text =~ s/\r\n/\n/gs;
    $text =~ s/\r/\n/gs;
    $text =~ s/^(.*?\n)\n(.*)/$2/s;
    my $httpHeader = $1;
    my $contentType = "";
    if( $httpHeader =~ /content\-type\:\s*([^\n]*)/ois ) {
        $contentType = $1;
    }
    if( $contentType =~ /^text\/html/ ) {
        $path =~ s/(.*)\/.*/$1/; # build path for relative address
        $host = "http://$host";   # build host for absolute address
        if( $port != 80 ) {
            $host .= ":$port";
        }
        $text = _cleanupIncludedHTML( $text, $host, $path );

    } elsif( $contentType =~ /^text\/(plain|css)/ ) {
        # do nothing

    } else {
        $text = _inlineError( "Error: Unsupported content type: $contentType."
              . " (Must be text/html, text/plain or text/css)" );
    }

    $text = applyPatternToIncludedText( $text, $thePattern ) if( $thePattern );

    return $text;
}

# Processes a specific instance %<nop>INCLUDE{...}% syntax.
# Returns the text to be inserted in place of the INCLUDE command.
# $topic and $web should be for the immediate parent topic in the
# include hierarchy. Works for both URLs and absolute server paths.
sub _handleINCLUDE {
    my ( $this, $params, $theTopic, $theWeb ) = @_;
    my $path = $params->{_DEFAULT} || "";
    my $pattern = $params->{pattern};
    my $rev     = $params->{rev};
    my $warn    = $params->{warn};

    if( $path =~ /^https?\:/ ) {
        # include web page
        return $this->_includeUrl( $path, $pattern, $theWeb, $theTopic );
    }

    $path =~ s/$securityFilter//go;    # zap anything suspicious
    if( $doSecureInclude ) {
        # Filter out ".." from filename, this is to
        # prevent includes of "../../file"
        $path =~ s/\.+/\./g;
    } else {
        # danger, could include .htpasswd with relative path
        $path =~ s/passwd//gi;    # filter out passwd filename
    }

    my $text = "";
    my $meta = "";

    # test for different topic name and file name patterns
    # TopicName
    # Web.TopicName
    # Web/TopicName
    # TopicName.txt
    # Web.TopicName.txt
    # Web/TopicName.txt
    my $incweb = $theWeb;
    my $inctopic = $path;
    $inctopic =~ s/\.txt$//; # strip .txt extension
    if ( $inctopic =~ /^($regex{webNameRegex})[\.\/]($regex{wikiWordRegex})$/ ) {
        $incweb = $1;
        $inctopic = $2;
    }

    unless( $this->{store}->topicExists($incweb, $inctopic)) {
        # give up, file not found
        $warn = $this->{prefs}->getPreferencesValue( "INCLUDEWARNING" ) unless( $warn );
        if( $warn && $warn =~ /^on$/i ) {
            return _inlineError( "Warning: Can't INCLUDE <nop>$inctopic, topic not found" );
        } elsif( $warn && $warn !~ /^(off|no)$/i ) {
            $inctopic =~ s/\//\./go;
            $warn =~ s/\$topic/$inctopic/go;
            return $warn;
        } # else fail silently
        return "";
    }
    $path = "$incweb.$inctopic";

    # prevent recursive includes. Note that the inclusion of a topic into
    # itself is not blocked; however subsequent attempts to include the
    # topic will fail.
    if( $this->{processingTopic}{$path} ) {
        $warn = $this->{prefs}->getPreferencesValue( "INCLUDEWARNING" ) unless( $warn );
        if( $warn && $warn !~ /^(off|no)$/i ) {
            return _inlineError( "Warning: Can't INCLUDE <nop>$inctopic twice, topic is already included" );
        } # else fail silently
        return "";
    } else {
        $this->{processingTopic}{$path} = 1;
    }

    # set include web/filenames and current web/filenames
    $this->{SESSION_TAGS}{INCLUDINGWEB} = $theWeb;
    $this->{SESSION_TAGS}{INCLUDINGTOPIC} = $theTopic;

    $theWeb = $incweb;
    $theTopic = $inctopic;

    ( $meta, $text ) =
      $this->{store}->readTopic( $this->{wikiUserName}, $theWeb, $theTopic,
                                 $rev, 0 );

    # remove everything before %STARTINCLUDE% and
    # after %STOPINCLUDE%
    $text =~ s/.*?%STARTINCLUDE%//s;
    $text =~ s/%STOPINCLUDE%.*//s;

    $text = applyPatternToIncludedText( $text, $pattern ) if( $pattern );

    # take out verbatims, pushing them into the same storage block
    # as the including topic so when we do the replacement at
    # the end they are all there
    $text = $this->{renderer}->takeOutBlocks( $text, "verbatim",
                                              $this->{_verbatims} );

    # Escape rendering: Change " !%VARIABLE%" to " %<nop>VARIABLE%", for final " %VARIABLE%" output
    $text =~ s/(\s)\!\%([A-Z])/$1%<nop>$2/g;

    $this->_expandAllTags( \$text, $theTopic, $theWeb );

    # 4th parameter tells plugin that its called for an included file
    $this->{plugins}->commonTagsHandler( $text, $theTopic, $theWeb, 1 );

    # If needed, fix all "TopicNames" to "Web.TopicNames" to get the
    # right context
    # SMELL: This is a hack.
    if( $theWeb ne $this->{webName} ) {
        # "TopicName" to "Web.TopicName"
        $text =~ s/(^|[\s\(])($regex{webNameRegex}\.$regex{wikiWordRegex})/$1$TranslationToken$2/go;
        $text =~ s/(^|[\s\(])($regex{wikiWordRegex})/$1$theWeb\.$2/go;
        $text =~ s/(^|[\s\(])$TranslationToken/$1/go;
        # "[[TopicName]]" to "[[Web.TopicName][TopicName]]"
        $text =~ s/\[\[([^\]]+)\]\]/&_fixIncludeLink( $theWeb, $1 )/geo;
        # "[[TopicName][...]]" to "[[Web.TopicName][...]]"
        $text =~ s/\[\[([^\]]+)\]\[([^\]]+)\]\]/&_fixIncludeLink( $theWeb, $1, $2 )/geo;
        # FIXME: Support for <noautolink>
    }

    # handle tags again because of plugin hook
    $this->_expandAllTags( \$text, $theTopic, $theWeb );

    $text =~ s/^\n+/\n/;
    $text =~ s/\n+$/\n/;

    $this->{processingTopic}{$path} = 0;

    return $text;
}

sub _handleHTTP_HOST {
    return $ENV{HTTP_HOST} || "";
}

sub _handleREMOTE_ADDR {
    return $ENV{REMOTE_ADDR} || "";
}

sub _handleREMOTE_PORT {
    return $ENV{REMOTE_PORT} || "";
}

sub _handleREMOTE_USER {
    return $ENV{REMOTE_USER} || "";
}

# Only does simple search for topicmoved at present, can be expanded when required
# SMELL: this violates encapsulation of Store and Meta, by exporting
# the assumption that meta-data is stored embedded inside topic
# text.
sub _handleMETASEARCH {
    my( $this, $params ) = @_;

    return $this->{store}->searchMetaData( $params );
}

# Deprecated, but used in signatures
sub _handleDATE {
    my $this = shift;
    return formatTime(time(), "\$day \$mon \$year", "gmtime");
}

sub _handleGMTIME {
    my( $this, $params ) = @_;
    return formatTime( time(), $params->{_DEFAULT} || "", "gmtime" );
}

sub _handleSERVERTIME {
    my( $this, $params ) = @_;
    return formatTime( time(), $params->{_DEFAULT} || "", "servertime" );
}

sub _handleDISPLAYTIME {
    my( $this, $params ) = @_;
    return formatTime( time(), $params->{_DEFAULT} || "", $displayTimeValues );
}

=pod

---++ formatTime ($epochSeconds, $formatString, $outputTimeZone) ==> $value
| $epochSeconds | epochSecs GMT |
| $formatString | twiki time date format |
| $outputTimeZone | timezone to display. (not sure this will work)(gmtime or servertime) |

=cut
sub formatTime  {
    my ($epochSeconds, $formatString, $outputTimeZone) = @_;
    my $value = $epochSeconds;

    # use default TWiki format "31 Dec 1999 - 23:59" unless specified
    $formatString = "\$day \$month \$year - \$hour:\$min" unless( $formatString );
    $outputTimeZone = $displayTimeValues unless( $outputTimeZone );

    my( $sec, $min, $hour, $day, $mon, $year, $wday) = gmtime( $epochSeconds );
      ( $sec, $min, $hour, $day, $mon, $year, $wday ) = localtime( $epochSeconds ) if( $outputTimeZone eq "servertime" );

    #standard twiki date time formats
    if( $formatString =~ /rcs/i ) {
        # RCS format, example: "2001/12/31 23:59:59"
        $formatString = "\$year/\$mo/\$day \$hour:\$min:\$sec";
    } elsif ( $formatString =~ /http|email/i ) {
        # HTTP header format, e.g. "Thu, 23 Jul 1998 07:21:56 EST"
 	    # - based on RFC 2616/1123 and HTTP::Date; also used
        # by TWiki::Net for Date header in emails.
        $formatString = "\$wday, \$day \$month \$year \$hour:\$min:\$sec \$tz";
    } elsif ( $formatString =~ /iso/i ) {
        # ISO Format, see spec at http://www.w3.org/TR/NOTE-datetime
        # e.g. "2002-12-31T19:30Z"
        $formatString = "\$year-\$mo-\$dayT\$hour:\$min";
        if( $outputTimeZone eq "gmtime" ) {
            $formatString = $formatString."Z";
        } else {
            #TODO:            $formatString = $formatString.  # TZD  = time zone designator (Z or +hh:mm or -hh:mm) 
        }
    }

    $value = $formatString;
    $value =~ s/\$seco?n?d?s?/sprintf("%.2u",$sec)/geoi;
    $value =~ s/\$minu?t?e?s?/sprintf("%.2u",$min)/geoi;
    $value =~ s/\$hour?s?/sprintf("%.2u",$hour)/geoi;
    $value =~ s/\$day/sprintf("%.2u",$day)/geoi;
    my $tmp = (WEEKDAY)[$wday];
    $value =~ s/\$wday/$tmp/geoi;
    $tmp = (ISOMONTH)[$mon];
    $value =~ s/\$mont?h?/$tmp/goi;
    $value =~ s/\$mo/sprintf("%.2u",$mon+1)/geoi;
    $value =~ s/\$year?/sprintf("%.4u",$year+1900)/geoi;
    $value =~ s/\$ye/sprintf("%.2u",$year%100)/geoi;

#TODO: how do we get the different timezone strings (and when we add usertime, then what?)
    my $tz_str = "GMT";
    $tz_str = "Local" if ( $outputTimeZone eq "servertime" );
    $value =~ s/\$tz/$tz_str/geoi;

    return $value;
}

#
# SMELL: this is _not_ a tag handler in the sense of other builtin tags, because it requires
# far more context information (the text of the topic) than any handler. It is really
# a plugin, and since it has an interface exactly like a plugin, would be much
# happier as a plugin. Having it here requires more code, and offers no perceptible benefit.
#
# Parameters:
#    * $text  : ref to the text of the current topic
#    * $topic : the topic we are in
#    * $web   : the web we are in
#    * $args  : "Topic" [web="Web"] [depth="N"]
# Return value: $tableOfContents
# Handles %<nop>TOC{...}% syntax.  Creates a table of contents
# using TWiki bulleted
# list markup, linked to the section headings of a topic. A section heading is
# entered in one of the following forms:
#    * $headingPatternSp : \t++... spaces section heading
#    * $headingPatternDa : ---++... dashes section heading
#    * $headingPatternHt : &lt;h[1-6]> HTML section heading &lt;/h[1-6]>
sub _TOC {
    my ( $this, $text, $defaultTopic, $defaultWeb, $args ) = @_;

    my %params = extractParameters( $args );

    # get the topic name attribute
    my $topicname = $params{_DEFAULT} || $defaultTopic;

    # get the web name attribute
    my $web = $params{web} || $defaultWeb;
    $web =~ s/\//\./g;
    my $webPath = $web;
    $webPath =~ s/\./\//g;

    # get the depth limit attribute
    my $depth = $params{depth} || 6;

    # get the title attribute
    my $title = $params{title} || "";
    $title = "\n<span class=\"twikiTocTitle\">$title</span>" if( $title );

    my $result  = "";
    my $line  = "";
    my $level = "";
    if( "$web.$topicname" ne "$defaultWeb.$defaultTopic" ) {
        my %p = ( _DEFAULT => "$web.$topicname" );
        $text = $this->_handleINCLUDE( \%p, $defaultWeb, $defaultTopic );
    }

    my $headerDaRE =  $regex{headerPatternDa};
    my $headerSpRE =  $regex{headerPatternSp};
    my $headerHtRE =  $regex{headerPatternHt};
    my $webnameRE =   $regex{webNameRegex};
    my $wikiwordRE =  $regex{wikiWordRegex};
    my $abbrevRE =    $regex{abbrevRegex};
    my $headerNoTOC = $regex{headerPatternNoTOC};
    my @list =
      grep { /(<\/?pre>)|($headerDaRE)|($headerSpRE)|($headerHtRE)/o }
        split( /\n/, $text );

    my $insidePre = 0;
    my $i = 0;
    my $tabs = "";
    my $anchor = "";
    my $highest = 99;
    # SMELL: this handling of <pre> is archaic.
    foreach $line ( @list ) {
        if( $line =~ /^.*<pre>.*$/io ) {
            $insidePre = 1;
            $line = "";
        }
        if( $line =~ /^.*<\/pre>.*$/io ) {
            $insidePre = 0;
            $line = "";
        }
        if (!$insidePre) {
            $level = $line ;
            if ( $line =~  /$headerDaRE/o ) {
                $level =~ s/$headerDaRE/$1/go;
                $level = length $level;
                $line  =~ s/$headerDaRE/$2/go;
            } elsif
               ( $line =~  /$headerSpRE/o ) {
                $level =~ s/$headerSpRE/$1/go;
                $level = length $level;
                $line  =~ s/$headerSpRE/$2/go;
            } elsif
               ( $line =~  /$headerHtRE/io ) {
                $level =~ s/$headerHtRE/$1/gio;
                $line  =~ s/$headerHtRE/$2/gio;
            }
            my $urlPath = "";
            if( "$web.$topicname" ne "$defaultWeb.$defaultTopic" ) {
                # not current topic, can't omit URL
                $urlPath = TWiki::getScriptUrl($webPath, $topicname);
            }
            if( ( $line ) && ( $level <= $depth ) ) {
                $anchor = $this->{renderer}->makeAnchorName( $line );
                # cut TOC exclude '---+ heading !! exclude'
                $line  =~ s/\s*$headerNoTOC.+$//go;
                $line  =~ s/[\n\r]//go;
                next unless $line;
                $highest = $level if( $level < $highest );
                $tabs = "";
                for( $i=0 ; $i<$level ; $i++ ) {
                    $tabs = "\t$tabs";
                }
                # Remove *bold*, _italic_ and =fixed= formatting
                $line =~ s/(^|[\s\(])\*([^\s]+?|[^\s].*?[^\s])\*($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
                $line =~ s/(^|[\s\(])_+([^\s]+?|[^\s].*?[^\s])_+($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
                $line =~ s/(^|[\s\(])=+([^\s]+?|[^\s].*?[^\s])=+($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
                # Prevent WikiLinks
                $line =~ s/\[\[.*?\]\[(.*?)\]\]/$1/g;  # '[[...][...]]'
                $line =~ s/\[\[(.*?)\]\]/$1/ge;        # '[[...]]'
                $line =~ s/([\s\(])($webnameRE)\.($wikiwordRE)/$1<nop>$3/go;  # 'Web.TopicName'
                $line =~ s/([\s\(])($wikiwordRE)/$1<nop>$2/go;  # 'TopicName'
                $line =~ s/([\s\(])($abbrevRE)/$1<nop>$2/go;    # 'TLA'
                # create linked bullet item, using a relative link to anchor
                $line = "$tabs* <a href=\"$urlPath#$anchor\">$line</a>";
                $result .= "\n$line";
            }
        }
    }
    if( $result ) {
        if( $highest > 1 ) {
            # left shift TOC
            $highest--;
            $result =~ s/^\t{$highest}//gm;
        }
        $result = "<div class=\"twikiToc\">$title$result\n</div>";
        return $result;

    } else {
        return _inlineError("TOC: No TOC in $web.$topicname");
    }
}

#| $web | web and  |
#| $topic | topic to display the name for |
#| $formatString | twiki format string (like in search) |
sub _handleREVINFO {
    my ( $this, $params, $theTopic, $theWeb ) = @_;
    my $format = $params->{_DEFAULT} || $params->{format}
                 || "\$rev - \$date - \$wikiusername";
    my $web    = $params->{web} || $theWeb;
    my $topic  = $params->{topic} || $theTopic;
    my $cgiQuery = $this->{cgiQuery};
    my $cgiRev = "";
    $cgiRev = $cgiQuery->param("rev") if( $cgiQuery );
    my $revnum = $cgiRev || $params->{rev} || "";
    $revnum = $this->{store}->cleanUpRevID( $revnum );

    my( $date, $user, $rev, $comment ) =
      $this->{store}->getRevisionInfo( $web, $topic, $revnum );
    my $wikiName     = $this->{users}->userToWikiName( $user, 1 );
    my $wikiUserName = $this->{users}->userToWikiName( $user );

    my $value = $format;
    $value =~ s/\$web/$web/goi;
    $value =~ s/\$topic/$topic/goi;
    $value =~ s/\$rev/r$rev/goi;
    $value =~ s/\$date/&formatTime($date)/geoi;
    $value =~ s/\$comment/$comment/goi;
    $value =~ s/\$username/$user/goi;
    $value =~ s/\$wikiname/$wikiName/goi;
    $value =~ s/\$wikiusername/$wikiUserName/goi;

    return $value;
}

sub _handleENCODE {
    my( $this, $params ) = @_;
    my $type = $params->{type};
    my $text = $params->{_DEFAULT} || "";
    if ( $type && $type =~ /^entit(y|ies)$/i ) {
        return entityEncode( $text );
    } else {
        return _urlEncode( $text );
    }
}

sub _handleSEARCH {
    my ( $this, $params, $theTopic, $theWeb ) = @_;
    # pass on all attrs, and add some more
    #$params->{_callback} = undef;
    $params->{inline} = 1;
    $params->{baseweb} = $theTopic;
    $params->{basetopic} = $theWeb;
    $params->{search} = $params->{_DEFAULT} if( $params->{_DEFAULT} );
    $params->{type} = $this->{prefs}->getPreferencesValue( "SEARCHVARDEFAULTTYPE" ) unless( $params->{type} );

    return $this->{search}->searchWeb( %$params );
}

# Format an error for inline inclusion in HTML
sub _inlineError {
    my( $errormessage ) = @_;
    return "<font size=\"-1\" class=\"twikiAlert\" color=\"red\">$errormessage</font>" ;
}

=pod

---++ getPublicWebList ()
Return public web list, i.e. exclude hidden webs, but include current web

=cut

sub getPublicWebList {
    my $this = shift;

    ASSERT(ref($this) eq "TWiki") if DEBUG;

    if( ! @{$this->{publicWebList}} ) {
        my @list = $this->{store}->getAllWebs();
        my $item = "";
        my $hidden = "";
        foreach $item ( @list ) {
            $hidden = $this->{prefs}->getPreferencesValue( "NOSEARCHALL", $item );
            if( ( $item eq $this->{webName}  ) || ( ( ! $hidden ) && ( $item =~ /^[^\.\_]/ ) ) ) {
                push( @{$this->{publicWebList}}, $item );
            }
        }
    }
    return @{$this->{publicWebList}};
}

=pod

---++ expandVariablesOnTopicCreation ( $theText, $theUser, $theWikiName, $theWikiUserName )
Expand limited set of variables during topic creation. These are variables
expected in templates that must be statically expanded in new content.

The expanded variables are:
| =%DATE%= | Signature-format date |
| =%USERNAME%= | Base login name |
| =%WIKINAME%= | Wiki name |
| =%WIKIUSERNAME%= | Wiki name with prepended web |
| =%URLPARAM%= | Parameters to the current CGI query |
| =%NOP%= | No-op |

=cut

sub expandVariablesOnTopicCreation {
    my ( $this, $theText, $theUser, $theWikiName, $theWikiUserName ) = @_;

    ASSERT(ref($this) eq "TWiki") if DEBUG;

    $theUser = $this->{userName} unless $theUser;
    $theWikiName = $this->{users}->userToWikiName( $theUser, 1 )
      unless $theWikiName;
    $theWikiUserName = $this->{users}->userToWikiName( $theUser )
      unless $theWikiUserName;

    $theText =~ s/%DATE%/$this->_handleDATE()/ge;
    $theText =~ s/%USERNAME%/$theUser/go;               # "jdoe"
    $theText =~ s/%WIKINAME%/$theWikiName/go;           # "JonDoe"
    $theText =~ s/%WIKIUSERNAME%/$theWikiUserName/go; # "Main.JonDoe"
    $theText =~ s/%URLPARAM{(.*?)}%/$this->_handleURLPARAM(makeHashRefFromHash(extractParameters($1)))/geo;

    # Remove filler: Use it to remove access control at time of
    # topic instantiation or to prevent search from hitting a template
    # SMELL: this expansion of %NOP{}% is different to the default
    # which retains content.....
    $theText =~ s/%NOP{.*?}%//gos;
    $theText =~ s/%NOP%//go;

    return $theText;
}

=pod

---++ makeHashRefFromHash
implemented just to convert the Hash returned by extractParameters into the HashRef expected by _handleURLPARAM

=cut

sub makeHashRefFromHash
{
my %param = @_;
return \%param;
}

sub _handleWEBLIST {
    my $this = shift;
    return $this->_webOrTopicList( 1, @_ );
}

sub _handleTOPICLIST {
    my $this = shift;
    return $this->_webOrTopicList( 0, @_ );
}

sub _webOrTopicList {
    my( $this, $isWeb, $params ) = @_;
    my $format = $params->{_DEFAULT} || $params->{format};
    $format .= '$name' unless( $format =~ /\$name/ );
    my $separator = $params->{separator} || "\n";
    my $web = $params->{web} || "";
    my $webs = $params->{webs} || "public";
    my $selection = $params->{selection} || "";
    $selection =~ s/\,/ /g;
    $selection = " $selection ";
    my $marker    = $params->{marker} || 'selected="selected"';

    my @list = ();
    if( $isWeb ) {
        my @webslist = split( /,\s?/, $webs );
        foreach my $aweb ( @webslist ) {
            if( $aweb eq "public" ) {
                push( @list, $this->getPublicWebList() );
            } elsif( $aweb eq "webtemplate" ) {
                push( @list, grep { /^\_/o } $this->{store}->getAllWebs() );
            } else{
                push( @list, $aweb ) if( $this->{store}->webExists( $aweb ) );
            }
        }
    } else {
        $web = $this->{webName} if( ! $web );
        my $hidden =
          $this->{prefs}->getPreferencesValue( "NOSEARCHALL", $web );
        if( ( $web eq $this->{webName}  ) || ( ! $hidden ) ) {
            @list = $this->{store}->getTopicNames( $web );
        }
    }
    my $text = "";
    my $item = "";
    my $line = "";
    my $mark = "";
    foreach $item ( @list ) {
        $line = $format;
        $line =~ s/\$web/$web/goi;
        $line =~ s/\$name/$item/goi;
        $line =~ s/\$qname/"$item"/goi;
        $mark = ( $selection =~ / \Q$item\E / ) ? $marker : "";
        $line =~ s/\$marker/$mark/goi;
        $text .= "$line$separator";
    }
    $text =~ s/$separator$//s;  # remove last separator
    return $text;
}

sub _handleURLPARAM {
    my( $this, $params ) = @_;
    my $param     = $params->{_DEFAULT} || "";
    my $newLine   = $params->{newline} || "";
    my $encode    = $params->{encode};
    my $multiple  = $params->{multiple};
    my $separator = $params->{separator} || "\n";

    my $value = "";
    if( $this->{cgiQuery} ) {
        if( $multiple ) {
            my @valueArray = $this->{cgiQuery}->param( $param );
            if( @valueArray ) {
                unless( $multiple =~ m/^on$/i ) {
                    my $item = "";
                    @valueArray = map {
                        $item = $_;
                        $_ = $multiple;
                        $_ .= $item unless( s/\$item/$item/go );
                        $_
                    } @valueArray;
                }
                $value = join ( $separator, @valueArray );
            }
        } else {
            $value = $this->{cgiQuery}->param( $param );
            $value = "" unless( defined $value );
        }
    }
    $value =~ s/\r?\n/$newLine/go if( $newLine );
    if ( $encode ) {
        if ( $encode =~ /^entit(y|ies)$/ ) {
        	$value = entityEncode( $value );
    	} else {
        	$value = _urlEncode( $value );
    	}
    }
    unless( $value ) {
        $value = $params->{default} || "";
    }
    return $value;
}

=pod

---++ entityEncode (text )
| =$text= | Text to encode |
Escape certain characters to HTML entities

=cut

sub entityEncode {
    my $text = shift;

    # HTML entity encoding
    $text =~ s/([\"\%\*\_\=\[\]\<\>\|])/"\&\#".ord( $1 ).";"/ge;
    return $text;
}

# Generate a $w-char hexidecimal number representing $n.
# Default $w is 2 (one byte)
sub _hexchar {
    my( $n, $w ) = @_;
    $w = 2 unless $w;
    return sprintf( "%0${w}x", ord( $n ));
}

# Encode to URL parameter
# TODO: For non-ISO-8859-1 $siteCharset, need to convert to
# UTF-8 before URL encoding.
# | =$text= | Text to encode |
# SMELL: what is the relationship to nativeUrlEncode??
sub _urlEncode {
    my $text = shift;

    # URL encoding
    $text =~ s/[\n\r]/\%3Cbr\%20\%2F\%3E/g;
    $text =~ s/\s/\%20/g;
    $text =~ s/(["&+<>\\])/"%"._hexchar($1,2)/ge;
    # Encode characters > 0x7F (ASCII-derived charsets only)
	# TODO: Encode to UTF-8 first
    $text =~ s/([\x7f-\xff])/'%' . unpack( "H*", $1 ) /ge;

    return $text;
}

=pod

---++ nativeUrlEncode ( $theStr, $doExtract )
Perform URL encoding into native charset ($siteCharset) - for use when
viewing attachments via browsers that generate UTF-8 URLs, on sites running
with non-UTF-8 (Native) character sets.  Aim is to prevent UTF-8 URL
encoding.  For mainframes, we assume that UTF-8 URLs will be translated
by the web server to an EBCDIC character set.

SMELL: why is this different to _urlEncode?

=cut

sub nativeUrlEncode {
    my $theStr = shift;

    my $isEbcdic = ( 'A' eq chr(193) ); 	# True if Perl is using EBCDIC

    if( $siteCharset eq "utf-8" or $isEbcdic ) {
        # Just strip double quotes, no URL encoding - let browser encode to
        # UTF-8 or EBCDIC based $siteCharset as appropriate
        $theStr =~ s/^"(.*)"$/$1/;	
        return $theStr;
    } else {
        return _urlEncode( $theStr );
    }
}

# This routine was introduced to URL encode Mozilla UTF-8 POST URLs in the
# TWiki Feb2003 release - encoding is no longer needed since UTF-URLs are now
# directly supported, but it is provided for backward compatibility with
# skins that may still be using the deprecated %INTURLENCODE%.
sub _handleINTURLENCODE {
    my( $this, $params ) = @_;
    # Just strip double quotes, no URL encoding - Mozilla UTF-8 URLs
    # directly supported now
    return $params->{_DEFAULT} || "";
}

=pod

---++ sub encodeSpecialChars (  $text  )

Escape out the chars &, ", >, <, \r and \n with replaceable tokens.
This is used to protect hidden fields from the browser.

=cut

# "
sub encodeSpecialChars {
    my $text = shift;

    $text = "" unless defined( $text );
    $text =~ s/\%/%_P_%/g;
    $text =~ s/&/%_A_%/g;
    $text =~ s/\"/%_Q_%/g;
    $text =~ s/>/%_G_%/g;
    $text =~ s/</%_L_%/g;
    $text =~ s/\r*\n\r*/%_N_%/g;

    return $text;
}

=pod

---++ sub decodeSpecialChars (  $text  )

Reverse the encoding of encodeSpecialChars.

=cut

sub decodeSpecialChars {
    my $text = shift;

    $text =~ s/%_N_%/\n/g;
    $text =~ s/%_L_%/</g;
    $text =~ s/%_G_%/>/g;
    $text =~ s/%_Q_%/\"/g;
    $text =~ s/%_A_%/&/g;
    $text =~ s/%_P_%/%/g;

    return $text;
}

=pod

---++ sub searchableTopic (  $topic  )

Space out the topic name for a search, by inserting " *" at
the start of each component word.

=cut

sub searchableTopic {
    my( $topic ) = @_;
    # FindMe -> Find\s*Me
    $topic =~ s/([$regex{lowerAlpha}]+)([$regex{upperAlpha}$regex{numeric}]+)/$1%20*$2/go;   # "%20*" is " *" - I18N: only in ASCII-derived charsets
    return $topic;
}

sub _handleSPACEDTOPIC {
    my ( $this, $params, $theTopic ) = @_;
    return _urlEncode( searchableTopic( $theTopic ));
}

sub _handleICON {
    my( $this, $params ) = @_;
    my $file = $params->{_DEFAULT};

    $file = "" unless $file;

    my $value = $this->{renderer}->filenameToIcon( "file.$file" );
    return $value;
}

sub _handleRELATIVETOPICPATH {
    my ( $this, $params, $theTopic, $theWeb ) = @_;
    my $theStyleTopic = $params->{_DEFAULT} || "";

    return "" unless $theStyleTopic;

    my $theRelativePath;
    # if there is no dot in $theStyleTopic, no web has been specified
    if ( index( $theStyleTopic, "." ) == -1 ) {
        # add local web
        $theRelativePath = $theWeb . "/" . $theStyleTopic;
    } else {
        $theRelativePath = $theStyleTopic; #including dot
    }
    # replace dot by slash is not necessary; TWiki.MyTopic is a valid url
    # add ../ if not already present to make a relative file reference
    if ( index( $theRelativePath, "../" ) == -1 ) {
        $theRelativePath = "../" . $theRelativePath;
    }
    return $theRelativePath;
}

sub _handleATTACHURLPATH {
    my ( $this, $params, $theTopic, $theWeb ) = @_;
    return nativeUrlEncode( "$pubUrlPath/$theWeb/$theTopic" );
}

# Expands variables by replacing the variables with their
# values. Some example variables: %<nop>TOPIC%, %<nop>SCRIPTURL%,
# %<nop>WIKINAME%, etc.
# $web and $incs are passed in for recursive include expansion. They can
# safely be undef.
# The rules for tag expansion are:
#    1 Tags are expanded left to right, in the order they are encountered.
#    1 Tags are recursively expanded as soon as they are encountered - the algorithm is inherently single-pass
#    1 A tag is not ""encountered" until the matching }% has been seen, by which time all tags in parameters will have been expanded
#    1 Tag expansions that create new tags recursively are limited to a set number of hierarchical levels of expansion
# 
# Formerly known as handleInternalTags, but renamed when it was rewritten
# because the old name clashes with the namespace of handlers.
sub _expandAllTags {
    my $this = shift;
    my $text = shift; # reference
    my ( $topic, $web ) = @_;

    # push current context
    my $memTopic = $this->{SESSION_TAGS}{TOPIC};
    my $memWeb   = $this->{SESSION_TAGS}{WEB};
    my $memEurl  = $this->{SESSION_TAGS}{EDITURL};

    $this->{SESSION_TAGS}{TOPIC}   = $topic;
    $this->{SESSION_TAGS}{WEB}     = $web;
    # Make Edit URL unique - fix for RefreshEditPage.
    $this->{SESSION_TAGS}{EDITURL} =
      "$dispScriptUrlPath/edit$scriptSuffix/$web/$topic\?t=" . time();

    # SMELL: why is this done every time, and not statically during
    # template loading?
    $$text =~ s/%NOP{(.*?)}%/$1/gs;  # remove NOP tag in template topics but show content
    $$text =~ s/%NOP%/<nop>/g;
    my $sep = $this->{templates}->expandTemplate('"sep"');
    $$text =~ s/%SEP%/$sep/g;

    # NOTE TO DEBUGGERS
    # The depth parameter in the following call controls the maximum number
    # of levels of expansion. If it is set to 1 then only tags in the
    # topic will be expanded; tags that they in turn generate will be
    # left unexpanded. If it is set to 2 then the expansion will stop after
    # the first recursive inclusion, and so on. This is incredible useful
    # when debugging The default is set to 16
    # to match the original limit on search expansion, though this of
    # course applies to _all_ tags and not just search.
    $$text = $this->_processTags( $$text, 16, "", @_ );

    # restore previous context
    $this->{SESSION_TAGS}{TOPIC}   = $memTopic;
    $this->{SESSION_TAGS}{WEB}     = $memWeb;
    $this->{SESSION_TAGS}{EDITURL} = $memEurl;
}

# Process TWiki %TAGS{}% by parsing the input tokenised into
# % separated sections. The parser is a simple stack-based parse,
# sufficient to ensure nesting of tags is correct, but no more
# than that.
# $depth limits the number of recursive expansion steps that
# can be performed on expanded tags.
sub _processTags {
    my $this = shift;
    my $text = shift;

    return "" unless defined( $text );

    my $depth = shift;
    my $expanding = shift;

    # my( $topic, $web ) = @_;

    unless ( $depth ) {
        my $mess = "Max recursive depth reached: $expanding";
        $this->writeWarning( $mess );
        return $text;
        #return _inlineError( $mess );
    }

    my @queue = split( /(%)/, $text );
    my @stack;
    my $tell = 0; # uncomment all tell lines set this to 1 to print debugging

    push( @stack, "" );
    while ( scalar( @queue )) {
        my $token = shift( @queue );
        print " " x $tell,"PROCESSING $token \n" if $tell;

        # each % sign either closes an existing stacked context, or
        # opens a new context.
        if ( $token eq "%" ) {
            print " " x $tell,"CONSIDER $stack[$#stack]\n" if $tell;
            # If this is a closing }%, try to rejoin the previous
            # tokens until we get to a valid tag construct. This is
            # a bit of a hack, but it's hard to think of a better
            # way to do this without a full parse that takes % signs
            # in tag parameters into account.
            if ( $stack[$#stack] =~ /}$/ ) {
                while ( $#stack &&
                        $stack[$#stack] !~ /^%([A-Z][A-Z0-9_:]*){(.*)}$/ ) {
                    my $top = pop( @stack );
                    print " " x $tell,"COLLAPSE $top \n" if $tell;
                    $stack[$#stack] .= $top;
                }
            }
            if ( $stack[$#stack] =~ /^%([A-Z][A-Z0-9_:]*)(?:{(.*)})?$/ ) {
                my ( $tag, $args ) = ( $1, $2 );
                print " " x $tell,"POP $tag\n" if $tell;
                my ( $ok, $e ) = $this->_expandTag( $tag, $args, @_ );
                if ( $ok ) {
                    print " " x $tell--,"EXPANDED $tag -> $e\n" if $tell;
                    pop( @stack );
                    # Choice: can either tokenise and push the expanded
                    # tag, or can recursively expand the tag. The
                    # behaviour is different in each case.
                    #unshift( @queue, split( /(%)/, $e ));
                    $stack[$#stack] .=
                      $this->_processTags($e, $depth+1, $expanding , @_ );
                } else { # expansion failed
                    #print " " x $tell++,"EXPAND $tag FAILED\n" if $tell;
                    push( @stack, "%" ); # push a new context, starting
                }
            } else {
                push( @stack, "%" ); # push a new context
                $tell++ if ( $tell );
            }
        } else {
            $stack[$#stack] .= $token;
        }
    }

    # Run out of input. Gather up everything in the stack.
    while ( $#stack ) {
        my $expr = pop( @stack );
        $stack[$#stack] .= $expr;
    }

    return pop( @stack );
}

# Handle expansion of 'constant' tags (as against preference tags)
# $eref is a reference to the flag that records the number of
# successful expansions on a single pass through the text
# $result is (initially) the whole tag expression
# $tag is the tag part
# $args is the bit in the {} (if there are any)
sub _expandTag {
    my $this = shift;
    my $tag = shift;
    my $args = shift;
    # my( $topic, $web ) = @_;

    my $res;

    if ( defined( $this->{SESSION_TAGS}{$tag} )) {
        $res = $this->{SESSION_TAGS}{$tag};
    } elsif ( defined( $staticInternalTags{$tag} )) {
        $res = $staticInternalTags{$tag};
    } elsif ( defined( $dynamicInternalTags{$tag} )) {
        my %params = extractParameters( $args );

        $res = &{$dynamicInternalTags{$tag}}( $this, \%params, @_ );
    }

    return ( defined( $res ), $res );
}

=pod

---++ registerTagHandler( $fnref )

STATIC Add a tag handler to the function tag handlers.
| $tag | name of the tag e.g. MYTAG |
| $fnref | Function to execute. Will be passed ($session, \%params, $web, $topic )

=cut

sub registerTagHandler {
    my ( $tag, $fnref ) = @_;
    $TWiki::dynamicInternalTags{$tag} = \&$fnref;
}

=pod

---++ handleCommonTags( $text, $topic, $web ) => processed $text
Processes %<nop>VARIABLE%, and %<nop>TOC% syntax; also includes
"commonTagsHandler" plugin hook.

Returns the text of the topic, after file inclusion, variable substitution,
table-of-contents generation, and any plugin changes from commonTagsHandler.

=cut

sub handleCommonTags {
    my( $this, $text, $theTopic, $theWeb ) = @_;

    ASSERT(ref($this) eq "TWiki") if DEBUG;

    $theWeb = $this->{webName} unless $theWeb;

    # Plugin Hook (for cache Plugins only)
    $this->{plugins}->beforeCommonTagsHandler( $text, $theTopic, $theWeb );

    my @verbatim = ();
    # remember the block for when we handle includes
    $this->{_verbatims} = \@verbatim;
    $text = $this->{renderer}->takeOutBlocks( $text, "verbatim", \@verbatim );

    # Escape rendering: Change " !%VARIABLE%" to " %<nop>VARIABLE%", for final " %VARIABLE%" output
    $text =~ s/(\s)\!\%([A-Z])/$1%<nop>$2/g;

    my $memW = $this->{SESSION_TAGS}{INCLUDINGWEB};
    my $memT = $this->{SESSION_TAGS}{INCLUDINGTOPIC};
    $this->{SESSION_TAGS}{INCLUDINGWEB} = $theWeb;
    $this->{SESSION_TAGS}{INCLUDINGTOPIC} = $theTopic;

    $this->_expandAllTags( \$text, $theTopic, $theWeb );

    # Plugin Hook
    $this->{plugins}->commonTagsHandler( $text, $theTopic, $theWeb, 0 );

    # process tags again because plugin hook may have added more in
    $this->_expandAllTags( \$text, $theTopic, $theWeb );

    $this->{SESSION_TAGS}{INCLUDINGWEB} = $memW;
    $this->{SESSION_TAGS}{INCLUDINGTOPIC} = $memT;

    # "Special plugin tag" TOC hack
    $text =~ s/%TOC(?:{(.*?)})?%/$this->_TOC($text, $theTopic, $theWeb, $1)/ge;

    # Codev.FormattedSearchWithConditionalOutput: remove <nop> lines,
    # possibly introduced by SEARCHes with conditional CALC. This needs
    # to be done after CALC and before table rendering
    # SMELL: is this a hack? Looks like it....
    $text =~ s/^<nop>\r?\n//gm;

    $text = $this->{renderer}->putBackBlocks( $text, \@verbatim, "verbatim" );

    # TWiki Plugin Hook (for cache Plugins only)
    $this->{plugins}->afterCommonTagsHandler( $text, $theTopic, $theWeb );

    return $text;
}

=pod

---++ new( $pathInfo, $remoteUser, $topic, $url, $query )
Constructs a new TWiki object.

Initializes the Store, User, Access, and Prefs modules.

Also parses $theTopic to determine whether it's a URI, a "Web.Topic"
pair, a "Web." WebHome shorthand, or just a topic name.  Note that
if $pathInfo is set, this overrides $theTopic.

| =$pathInfo= | .pathinfo from query |
| =remoteUser= | the logged-in user |
| =topic= | topic from "topic" parameter to url (overrides pathinfo if present ) |
| =url= | the full url used |
| =query= | the query |
| =scripted= | true if this is called from a script rather than a browser query |

=cut

sub new {
    my( $class, $pathInfo, $remoteUser, $topic, $url, $query, $scripted ) = @_;

    my $this = bless( {}, $class );

    # create the various sub-objects
    $this->{sandbox} = new TWiki::Sandbox( $this,
                                           $TWiki::OS, $TWiki::detailedOS );

    $this->{plugins} = new TWiki::Plugins( $this );
    $this->{net} = new TWiki::Net( $this );
    my %ss = @storeSettings;
    $this->{store} = new TWiki::Store( $this, $storeTopicImpl, \%ss );
    $this->{search} = new TWiki::Search( $this );
    $this->{templates} = new TWiki::Templates( $this );
    $this->{attach} = new TWiki::Attach( $this );
    $this->{form} = new TWiki::Form( $this );

    # cache CGI information in the session object
    $this->{cgiQuery} = $query;
    $this->{remoteUser} = $remoteUser;
    $this->{url} = $url;
    $this->{pathInfo} = $pathInfo;

    @{$this->{publicWebList}} = ();

	if ( # (-e $TWiki::htpasswdFilename ) && #<<< maybe
		( $TWiki::htpasswdFormatFamily eq "htpasswd" ) ) {
        $this->{users} = new TWiki::User( $this, "HtPasswdUser" );
#	} elseif ($TWiki::htpasswdFormatFamily eq "something?") {
#        $this->{users} = new TWiki::User( $this, "SomethingUser" );
	} else {
        $this->{users} = new TWiki::User( $this, "NoPasswdUser" );
	}

    # Make %ENV safer, preventing hijack of the search path
    # SMELL: can this be done in a BEGIN block? Or is the environment
    # set per-query?
    if( $safeEnvPath ) {
        $ENV{'PATH'} = $safeEnvPath;
    }
    delete @ENV{ qw( IFS CDPATH ENV BASH_ENV ) };

    # Check for unsafe search regex mode (affects filtering in) - default
    # to safe mode
    $TWiki::forceUnsafeRegexes = 0 unless defined $TWiki::forceUnsafeRegexes;

    # initialize lib directory early because of later 'cd's
    getTWikiLibDir();

    $this->{security} = new TWiki::Access( $this );

    my $web = "";
    if( $topic ) {
        if( $topic =~ /^$regex{linkProtocolPattern}\:\/\//o &&
            $this->{cgiQuery} ) {
            # redirect to URI
            print $this->redirect( $topic );
            return;
        } elsif( $topic =~ /(.*)[\.\/](.*)/ ) {
            # is "bin/script?topic=Webname.SomeTopic"
            $web   = $1 || "";
            $topic = $2 || "";
            # jump to WebHome if "bin/script?topic=Webname."
            $topic = $mainTopicname if( $web && ! $topic );
        }
        # otherwise assume "bin/script/Webname?topic=SomeTopic"
    } else {
        $topic = "";
    }

    # Clean up PATH_INFO problems, e.g.  Support.CobaltRaqInstall.  A valid
    # PATH_INFO is '/Main/WebHome', i.e. the text after the script name;
    # invalid PATH_INFO is often a full path starting with '/cgi-bin/...'.
    my $cgiScriptName = $ENV{'SCRIPT_NAME'} || "";
    $pathInfo =~ s!$cgiScriptName/!/!i;

    # Get the web and topic names from PATH_INFO
    if( $pathInfo =~ /\/(.*)[\.\/](.*)/ ) {
        # is "bin/script/Webname/SomeTopic" or "bin/script/Webname/"
        $web   = $1 || "" unless $web;
        $topic = $2 || "" unless $topic;
    } elsif( $pathInfo =~ /\/(.*)/ ) {
        # is "bin/script/Webname" or "bin/script/"
        $web   = $1 || "" unless $web;
    }

    if ( $topic =~ /\.\./ ) {
        $topic = $this->{mainTopicname};
    }

    # Refuse to work with character sets that allow TWiki syntax
    # to be recognised within multi-byte characters.  Only allow 'oops'
    # page to be displayed (redirect causes this code to be re-executed).
    if ( _invalidSiteCharset() and $url !~ m!$scriptUrlPath/oops! ) {
        $this->writeWarning( "Cannot use this multi-byte encoding ('$siteCharset') as site character encoding" );
        $this->writeWarning( "Please set a different character encoding in the \$siteLocale setting in TWiki.cfg." );
        $url = $this->getOopsUrl( $web, $topic, "oopsbadcharset" );
        print $this->redirect( $url );
        return;
    }

    $topic =~ s/$securityFilter//go;
    $topic = $mainTopicname unless $topic;
    $this->{topicName} = $topic;
    $web   =~ s/$securityFilter//go;
    $web = $mainWebname unless $web;
    $this->{webName} = $web;

    # Convert UTF-8 web and topic name from URL into site charset 
    # if necessary - no effect if URL is not in UTF-8
    $this->_convertUtf8URLtoSiteCharset();

    $this->{scriptUrlPath} = $scriptUrlPath;

    # initialize $urlHost and $scriptUrlPath 
    if( $url && $url =~ m!^([^:]*://[^/]*)(.*)/.*$! && $2 ) {
        if( $doGetScriptUrlFromCgi ) {
            # SMELL: this is a really dangerous hack. It will fail
            # spectacularly with mod_perl.
            $this->{scriptUrlPath} = $2;
        }
        $this->{urlHost} = $1;
        if( $doRemovePortNumber ) {
            $this->{urlHost} =~ s/\:[0-9]+$//;
        }
    } else {
        $this->{urlHost} = $defaultUrlHost;
    }

    # initialize preferences, first part for site and web level
    $this->{prefs} = new TWiki::Prefs( $this );

    my $user = $this->{plugins}->load( $disableAllPlugins );
    unless( $user ) {
        $user = $this->{users}->initializeRemoteUser( $remoteUser );
    }

    # cache user information in the session object
    $this->{userName} = $user;
    # i.e. "Main.JonDoa"
    $this->{wikiUserName} = $this->{users}->userToWikiName( $user );

    # Static session variables that can be expanded in topics when they
    # are enclosed int % signs
    $this->{SESSION_TAGS}{USERNAME}       = $this->{userName};
    $this->{SESSION_TAGS}{WIKINAME}       =
      $this->{users}->userToWikiName( $this->{userName}, 1 );  # i.e. "JonDoe";
    $this->{SESSION_TAGS}{WIKIUSERNAME}   = $this->{wikiUserName};
    $this->{SESSION_TAGS}{BASEWEB}        = $this->{webName};
    $this->{SESSION_TAGS}{BASETOPIC}      = $this->{topicName};
    $this->{SESSION_TAGS}{INCLUDINGTOPIC} = $this->{topicName};
    $this->{SESSION_TAGS}{INCLUDINGWEB}   = $this->{webName};
    $this->{SESSION_TAGS}{ATTACHURL}      = "$this->{urlHost}%ATTACHURLPATH%";
    $this->{SESSION_TAGS}{PUBURL}         = $this->{urlHost}.$pubUrlPath;
    $this->{SESSION_TAGS}{SCRIPTURL}      = $this->{urlHost}.$dispScriptUrlPath;

    # initialize user preferences
    $this->{prefs}->initializeUser( $this->{wikiUserName}, $this->{topicName} );

    $this->{renderer} = new TWiki::Render( $this );

    # Finish plugin initialization - register handlers
    $this->{plugins}->enable();

    # Assumes all preferences values are set by now, which may well be false!
    # populate the session hash with prefs values. These always override
    # default values of these tags, which is really a bad idea.
    $this->{prefs}->loadHash( \%{$this->{SESSION_TAGS}} );

    return $this;
}

1;
