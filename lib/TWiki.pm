# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
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
# As per the GPL, removal of this notice is prohibited.

=pod

---+ package TWiki

TWiki operates by creating a singleton object (known as the Session
object) that acts as a point of reference for all the different
modules in the system. This package is the class for this singleton,
and also contains the vast bulk of the basic constants and the per-
site configuration mechanisms.

=cut

package TWiki;

use strict;
use Assert;

require 5.005;		# For regex objects and internationalisation

# Site configuration constants
use vars qw( %cfg );

# Uncomment this and the __END__ to enable AutoLoader
#use AutoLoader 'AUTOLOAD';
# You then need to autosplit TWiki.pm:
# cd lib
# perl -e 'use AutoSplit; autosplit("TWiki.pm", "auto")'

# Other computed constants
use vars qw(
            $TranslationToken
            $twikiLibDir
            %regex
            %constantTags
            %functionTags
            $siteCharset
            $siteLang
            $siteFullLang
            $urlCharEncoding
            $langAlphabetic
            $VERSION
            $TRUE
            $FALSE
           );

# Token character that must not occur in any normal text - converted
# to a flag character if it ever does occur (very unlikely)
$TranslationToken= "\0";	# Null not allowed in charsets used with TWiki

BEGIN {

    $TRUE = 1;
    $FALSE = 0;

    if( DEBUG ) {
        # If ASSERTs are on, then warnings are errors. Paranoid,
        # but the only way to be sure we eliminate them all.
        $SIG{'__WARN__'} = sub { die @_ };
    }

    # automatically expanded on checkin of this module
    $VERSION = '$Date$ $Rev$ ';
    $VERSION =~ s/^.*?\((.*)\).*: (\d+) .*?$/$1 build $2/;

    # Default handlers for different %TAGS%
    %functionTags = (
                     ATTACHURLPATH     => \&_ATTACHURLPATH,
                     DATE              => \&_DATE,
                     DISPLAYTIME       => \&_DISPLAYTIME,
                     ENCODE            => \&_ENCODE,
                     FORMFIELD         => \&_FORMFIELD,
                     GMTIME            => \&_GMTIME,
                     HTTP_HOST         => \&_HTTP_HOST,
                     ICON              => \&_ICON,
                     INCLUDE           => \&_INCLUDE,
                     INTURLENCODE      => \&_INTURLENCODE,
                     METASEARCH        => \&_METASEARCH,
                     PLUGINVERSION     => \&_PLUGINVERSION,
                     RELATIVETOPICPATH => \&_RELATIVETOPICPATH,
                     REMOTE_ADDR       => \&_REMOTE_ADDR,
                     REMOTE_PORT       => \&_REMOTE_PORT,
                     REMOTE_USER       => \&_REMOTE_USER,
                     REVINFO           => \&_REVINFO,
                     SCRIPTNAME        => \&_SCRIPTNAME,
                     SEARCH            => \&_SEARCH,
                     SERVERTIME        => \&_SERVERTIME,
                     SPACEDTOPIC       => \&_SPACEDTOPIC,
                     'TMPL:P'          => \&_TMPLP,
                     TOPICLIST         => \&_TOPICLIST,
                     URLENCODE         => \&_ENCODE,
                     URLPARAM          => \&_URLPARAM,
                     VAR               => \&_VAR,
                     WEBLIST           => \&_WEBLIST,
                    );

    # Constant tag strings _not_ dependent on config
    %constantTags = (
                     ENDSECTION      => '',
                     WIKIVERSION     => $VERSION,
                     SECTION         => '',
                     STARTINCLUDE    => '',
                     STOPINCLUDE     => '',
                    );

    unless( ( $TWiki::cfg{DetailedOS} = $^O ) ) {
        require Config;
        $TWiki::cfg{DetailedOS} = $Config::Config{'osname'};
    }
    $TWiki::cfg{OS} = 'UNIX';
    if ($TWiki::cfg{DetailedOS} =~ /darwin/i) { # MacOS X
        $TWiki::cfg{OS} = 'UNIX';
    } elsif ($TWiki::cfg{DetailedOS} =~ /Win/i) {
        $TWiki::cfg{OS} = 'WINDOWS';
    } elsif ($TWiki::cfg{DetailedOS} =~ /vms/i) {
        $TWiki::cfg{OS} = 'VMS';
    } elsif ($TWiki::cfg{DetailedOS} =~ /bsdos/i) {
        $TWiki::cfg{OS} = 'UNIX';
    } elsif ($TWiki::cfg{DetailedOS} =~ /dos/i) {
        $TWiki::cfg{OS} = 'DOS';
    } elsif ($TWiki::cfg{DetailedOS} =~ /^MacOS$/i) { # MacOS 9 or earlier
        $TWiki::cfg{OS} = 'MACINTOSH';
    } elsif ($TWiki::cfg{DetailedOS} =~ /os2/i) {
        $TWiki::cfg{OS} = 'OS2';
    }

    # Get LocalSite first, to pick up definitions of things like
    # {RCS}{BinDir} and {LibDir} that are used in TWiki.cfg
    # do, not require, because we do it twice
    do 'LocalSite.cfg';
    # Now get all the defaults
    require 'TWiki.cfg';
    die "Cannot read TWiki.cfg: $@" if $@;
    die "Bad configuration: $@" if $@;
    # Make sure key variables are defined
    foreach my $var ( 'DataDir', 'DefaultUrlHost', 'PubUrlPath',
                      'PubDir', 'TemplateDir' ) {
        die "$var must be defined in LocalSite.cfg"
          unless( defined $TWiki::cfg{$var} );
    }
    # read localsite again to ensure local definitions override TWiki.cfg
    do 'LocalSite.cfg';
    die "Bad configuration: $@" if $@;

    if( $TWiki::cfg{UseLocale} ) {
        require locale;
    }

    $TWiki::cfg{DispScriptUrlPath} = $TWiki::cfg{ScriptUrlPath}
      unless defined( $TWiki::cfg{DispScriptUrlPath} );

    # Constant tags dependent on the config
    $constantTags{HOMETOPIC}       = $TWiki::cfg{HomeTopicName};
    $constantTags{MAINWEB}         = $TWiki::cfg{UsersWebName};
    $constantTags{NOTIFYTOPIC}     = $TWiki::cfg{NotifyTopicName};
    $constantTags{PUBURLPATH}      = $TWiki::cfg{PubUrlPath};
    $constantTags{SCRIPTSUFFIX}    = $TWiki::cfg{ScriptSuffix};
    $constantTags{SCRIPTURLPATH}   = $TWiki::cfg{DispScriptUrlPath};
    $constantTags{STATISTICSTOPIC} = $TWiki::cfg{Stats}{TopicName};
    $constantTags{TWIKIWEB}        = $TWiki::cfg{SystemWebName};
    $constantTags{WEBPREFSTOPIC}   = $TWiki::cfg{WebPrefsTopicName};
    $constantTags{WIKIHOMEURL}     =
      $TWiki::cfg{DefaultUrlHost} .
        '/' . $TWiki::cfg{ScriptUrlPath} . '/view' .
          $TWiki::cfg{ScriptSuffix};
    $constantTags{WIKIPREFSTOPIC}  = $TWiki::cfg{SitePrefsTopicName};
    $constantTags{WIKIUSERSTOPIC}  = $TWiki::cfg{UsersTopicName};
    $constantTags{NOFOLLOW} = $TWiki::cfg{NoFollow};

    # locale setup
    #
    # SMELL: mod_perl compatibility note: If TWiki is running under Apache,
    # won't this play with the Apache process's locale settings too?
    # What effects would this have?
    #
    # Note that 'use locale' must be done in BEGIN block for regexes and
    # sorting to
    # work properly, although regexes can still work without this in
    # 'non-locale regexes' mode.
    $siteCharset = 'ISO-8859-1';	# Default values if locale mis-configured
    $siteLang = 'en';
    $siteFullLang = 'en-us';

    # Language assumed alphabetic unless otherwise configured - used to 
    # turn on filtering-in of valid characters in user input 
    $langAlphabetic = 1 if not defined $langAlphabetic;      # Default is 1 if not configured

    if ( $TWiki::cfg{UseLocale} ) {
        if ( ! defined $TWiki::cfg{SiteLocale} ||
             $TWiki::cfg{SiteLocale} !~ /[a-z]/i ) {

            die "UseLocale set but SiteLocale $TWiki::cfg{SiteLocale} unset or has no alphabetic characters";
        }
        # Extract the character set from locale and use in HTML templates
        # and HTTP headers
        $TWiki::cfg{SiteLocale} =~ m/\.([a-z0-9_-]+)$/i;
        $siteCharset = $1 if defined $1;
        $siteCharset =~ s/^utf8$/utf-8/i;	# For convenience, avoid overrides
        $siteCharset =~ s/^eucjp$/euc-jp/i;

        # Override charset - used when locale charset not supported by Perl
        # conversion modules
        $siteCharset = $TWiki::cfg{SiteCharsetOverride} || $siteCharset;
        $siteCharset = lc $siteCharset;

        # Extract the default site language - ignores '@euro' part of
        # 'fr_BE@euro' type locales.
        $TWiki::cfg{SiteLocale} =~ m/^([a-z]+)_([a-z]+)/i;
        $siteLang = (lc $1) if defined $1;	# Not including country part
        $siteFullLang = (lc "$1-$2" ) 		# Including country part
          if defined $1 and defined $2;

        # Set environment variables for grep 
        $ENV{'LC_CTYPE'}= $TWiki::cfg{SiteLocale};

        # Load POSIX for I18N support.
        require POSIX;
        import POSIX qw( locale_h LC_CTYPE );

        # Set new locale - deliberately not checked since tested
        # in testenv
        my $locale = setlocale(&LC_CTYPE, $TWiki::cfg{SiteLocale});
    }

    # Check for unusable multi-byte encodings as site character set
    # - anything that enables a single ASCII character such as '[' to be
    # matched within a multi-byte character cannot be used for TWiki.

    # Refuse to work with character sets that allow TWiki syntax
    # to be recognised within multi-byte characters.

    # FIXME: match other problematic multi-byte character sets
    if( $siteCharset =~ /^(?:iso-?2022-?|hz-?|gb2312|gbk|gb18030|.*big5|.*shift_?jis|ms.kanji|johab|uhc)/i ) {

        die "Cannot use this multi-byte encoding ('$siteCharset') as site character encoding\nPlease set a different character encoding in the SiteLocale setting.";
    }

    $constantTags{CHARSET} = $siteCharset;
    $constantTags{SHORTLANG} = $siteLang;
    $constantTags{LANG} = $siteFullLang;

    # Set up pre-compiled regexes for use in rendering.  All regexes with
    # unchanging variables in match should use the '/o' option.
    # In the regex hash, all precompiled REs have "Regex" at the
    # end of the name. Anything else is a string, either intended
    # for use as a character class, or as a sub-expression in
    # another compiled RE.

    # Build up character class components for use in regexes.
    # Depends on locale mode and Perl version, and finally on
    # whether locale-based regexes are turned off.
    if ( not $TWiki::cfg{UseLocale} or $] < 5.006
         or not $TWiki::cfg{LocaleRegexes} ) {

        # No locales needed/working, or Perl 5.005, so just use
        # any additional national characters defined in TWiki.cfg
        $regex{upperAlpha} = 'A-Z'.$TWiki::cfg{UpperNational};
        $regex{lowerAlpha} = 'a-z'.$TWiki::cfg{LowerNational};
        $regex{numeric}    = '\d';
        $regex{mixedAlpha} = $regex{upperAlpha}.$regex{lowerAlpha};
    } else {
        # Perl 5.006 or higher with working locales
        $regex{upperAlpha} = '[:upper:]';
        $regex{lowerAlpha} = '[:lower:]';
        $regex{numeric}    = '[:digit:]';
        $regex{mixedAlpha} = '[:alpha:]';
    }
    $regex{mixedAlphaNum} = $regex{mixedAlpha}.$regex{numeric};
    $regex{lowerAlphaNum} = $regex{lowerAlpha}.$regex{numeric};
    $regex{upperAlphaNum} = $regex{upperAlpha}.$regex{numeric};

    # Compile regexes for efficiency and ease of use
    # Note: qr// locks in regex modes (i.e. '-xism' here) - see Friedl
    # book at http://regex.info/. 

    $regex{linkProtocolPattern} =
      '(file|ftp|gopher|https|http|irc|news|nntp|telnet)';

    # Header patterns based on '+++'. The '###' are reserved for numbered
    # headers
    # '---++ Header', '---## Header'
    $regex{headerPatternDa} = '^---+(\++|\#+)\s*(.+)\s*$';
    # '   ++ Header', '   + Header'
    # SMELL: is this ever used? It's not documented AFAICT
    $regex{headerPatternSp} = '^\t(\++|\#+)\s*(.+)\s*$';
    # '<h6>Header</h6>
    $regex{headerPatternHt} = '^<h([1-6])>\s*(.+?)\s*</h[1-6]>';
    # '---++!! Header' or '---++ Header %NOTOC% ^top'
    $regex{headerPatternNoTOC} = '(\!\!+|%NOTOC%)';

    # TWiki concept regexes
    $regex{wikiWordRegex} = qr/[$regex{upperAlpha}]+[$regex{lowerAlpha}]+[$regex{upperAlpha}]+[$regex{mixedAlphaNum}]*/o;
    $regex{webNameRegex} = qr/[$regex{upperAlpha}]+[$regex{mixedAlphaNum}]*/o;
    $regex{defaultWebNameRegex} = qr/_[$regex{mixedAlphaNum}_]+/o;
    $regex{anchorRegex} = qr/\#[$regex{mixedAlphaNum}_]+/o;
    $regex{abbrevRegex} = qr/[$regex{upperAlpha}]{3,}s?\b/o;

    # Simplistic email regex, e.g. for WebNotify processing - no i18n
    # characters allowed
    $regex{emailAddrRegex} = qr/([A-Za-z0-9\.\+\-\_]+\@[A-Za-z0-9\.\-]+)/;

    # Filename regex, for attachments
    $regex{filenameRegex} = qr/[$regex{mixedAlphaNum}\.]+/o;

    # Multi-character alpha-based regexes
    $regex{mixedAlphaNumRegex} = qr/[$regex{mixedAlphaNum}]*/o;

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
};

use TWiki::Sandbox;   # system command sandbox
use TWiki::Store;     # file I/O and rcs related functions
use TWiki::Prefs;     # preferences
use TWiki::Access;    # access control
use TWiki::Form;      # forms
use TWiki::Search;    # search engine
use TWiki::Plugins;   # plugins handler
use TWiki::Users;     # user handler
use TWiki::Render;    # HTML generation
use TWiki::Templates; # TWiki template language
use TWiki::Net;       # SMTP, get URL
use TWiki::Time;      # date/time conversions

# Auto-detect UTF-8 vs. site charset in URL, and convert UTF-8 into site charset.
# TODO: remove dependence on webname and topicname.
sub _convertUtf8URLtoSiteCharset {
    my $this = shift;

    my $fullTopicName = $this->{webName}.'.'.$this->{topicName};
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
        } elsif ( $siteCharset eq 'utf-8' ) {
            # Convert into internal Unicode characters if on Perl 5.8 or higher.
            if( $] >= 5.008 ) {
                require Encode;			# Perl 5.8 or higher only
                $fullTopicName = Encode::decode('utf8', $fullTopicName);	# 'decode' into UTF-8
            } else {
                $this->writeWarning( "UTF-8 not supported on Perl $] - use Perl 5.8 or higher." );
            }
            $this->writeWarning( 'UTF-8 not yet supported as site charset - TWiki is likely to have problems' );
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

---++ ObjectMethod writeCompletePage( $text )

Write a complete HTML page with basic header to the browser.
$text is the HTML of the page body (&lt;html&gt; to &lt;/html&gt;)

=cut

sub writeCompletePage {
    my ( $this, $text, $pageType, $contentType ) = @_;

    ASSERT(ref($this) eq 'TWiki') if DEBUG;

    $text .= "\n" unless $text =~ /\n$/s;

    # can't use simple length() in case we have UNICODE
    # see perldoc -f length
    my $len = do { use bytes; length( $text ); };
    $this->writePageHeader( undef, $pageType, $contentType, $len );
    print $text;
}

=pod

---++ ObjectMethod writePageHeader( $query, $pageType, $contentType, $contentLength )

All parameters are optional.

   * =$query= CGI query object | Session CGI query (there is no good reason to set this)
   * =$pageType= - May be "edit", which will cause headers to be generated that force caching for 24 hours, to prevent Codev.BackFromPreviewLosesText bug, which caused data loss with IE5 and IE6.
   * =$contentType= - page content type | text/html
   * =$contentLength= - content-length | no content-length will be set if this is undefined, as required by HTTP1.1

Implements the post-Dec2001 release plugin API, which requires the
writeHeaderHandler in plugin to return a string of HTTP headers, CR/LF
delimited. Filters any illegal headers. Plugin headers will override
core settings.

=cut

sub writePageHeader {
    my( $this, $query, $pageType, $contentType, $contentLength ) = @_;

    ASSERT(ref($this) eq 'TWiki') if DEBUG;

    $query = $this->{cgiQuery} unless $query;

    # Handle Edit pages - future versions will extend to caching
    # of other types of page, with expiry time driven by page type.
    my( $pluginHeaders, $coreHeaders );

    my @hopts = ();

    $contentType = 'text/html' unless $contentType;
    $contentType .= '; charset='.$siteCharset;
    push( @hopts, -content_type => $contentType );

    if ($pageType && $pageType eq 'edit') {
        # Get time now in HTTP header format
        my $lastModifiedString =
          TWiki::Time::formatTime(time, '\$http', 'gmtime');

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

---++ ObjectMethod redirect( $url, ... )

Generate a CGI redirect to $url unless (1) $session->{cgiQuery} is undef or
(2) $query->param('noredirect') is set to a true value. Thus a redirect is
only generated when in a CGI context.

The ... parameters are concatenated to the message written when printing
to STDOUT, and are ignored for a redirect.

Redirects the request to $url, via the CGI module object $query unless
overridden by a plugin declaring a =redirectCgiQueryHandler=.

=cut

sub redirect {
    my $this = shift;
    my $url = shift;

    ASSERT(ref($this) eq 'TWiki') if DEBUG;

    my $query = $this->{cgiQuery};

    unless( $this->{plugins}->redirectCgiQueryHandler( $query, $url ) ) {
        if ( $query && $query->param( 'noredirect' )) {
            my $content = join(' ', @_) . " \n";
            $this->writeCompletePage( $query, $content );
        } elsif ( $query ) {
            print $query->redirect( $url );
        }
    }
}

=pod

---++ StaticMethod isValidWikiWord (  $name  ) -> $boolean

Check for a valid WikiWord or WikiName

=cut

sub isValidWikiWord {
    my $name  = shift || '';
    return ( $name =~ m/^$regex{wikiWordRegex}$/o )
}

=pod

---++ StaticMethod isValidTopicName (  $name  ) -> $boolean

Check for a valid topic name

=cut

sub isValidTopicName {
    my( $name ) = @_;

    return isValidWikiWord( @_ ) || isValidAbbrev( @_ );
}

=pod

---++ StaticMethod isValidAbbrev (  $name  ) -> $boolean

Check for a valid ABBREV (acronym)

=cut

sub isValidAbbrev {
    my $name = shift || '';
    return ( $name =~ m/^$regex{abbrevRegex}$/o )
}

=pod

---++ StaticMethod isValidWebName (  $name, $system  ) -> $boolean

STATIC Check for a valid web name. If $system is true, then
system web names are considered valid (names starting with _)
otherwise only user web names are valid

=cut

sub isValidWebName {
    my $name = shift || '';
    my $sys = shift;
    return 1 if ( $sys && $name =~ m/^$regex{defaultWebNameRegex}$/o );
    return ( $name =~ m/^$regex{webNameRegex}$/o )
}

=pod

---++ ObjectMethod readOnlyMirrorWeb (  $theWeb  ) -> ( $mirrorSiteName, $mirrorViewURL, $mirrorLink, $mirrorNote )

If this is a mirrored web, return information about the mirror. The info
is returned in a quadruple:

| site name | URL | link | note |

=cut

sub readOnlyMirrorWeb {
    my( $this, $theWeb ) = @_;

    ASSERT(ref($this) eq 'TWiki') if DEBUG;

    my @mirrorInfo = ( '', '', '', '' );
    if( $TWiki::cfg{SiteWebTopicName} ) {
        my $mirrorSiteName =
          $this->{prefs}->getPreferencesValue( 'MIRRORSITENAME', $theWeb );
        if( $mirrorSiteName && $mirrorSiteName ne $TWiki::cfg{SiteWebTopicName} ) {
            my $mirrorViewURL  =
              $this->{prefs}->getPreferencesValue( 'MIRRORVIEWURL', $theWeb );
            my $mirrorLink = $this->{templates}->readTemplate( 'mirrorlink' );
            $mirrorLink =~ s/%MIRRORSITENAME%/$mirrorSiteName/g;
            $mirrorLink =~ s/%MIRRORVIEWURL%/$mirrorViewURL/g;
            $mirrorLink =~ s/\s*$//g;
            my $mirrorNote = $this->{templates}->readTemplate( 'mirrornote' );
            $mirrorNote =~ s/%MIRRORSITENAME%/$mirrorSiteName/g;
            $mirrorNote =~ s/%MIRRORVIEWURL%/$mirrorViewURL/g;
            $mirrorNote = $this->{renderer}->getRenderedVersion
              ( $mirrorNote, $theWeb, $TWiki::cfg{HomeTopic} );
            $mirrorNote =~ s/\s*$//g;
            @mirrorInfo = ( $mirrorSiteName, $mirrorViewURL, $mirrorLink, $mirrorNote );
        }
    }
    return @mirrorInfo;
}

=pod

---++ StaticMethod getTWikiLibDir() -> $path

STATIC method.

Returns the full path of the directory containing TWiki.pm

=cut

sub getTWikiLibDir {
    if( $twikiLibDir ) {
        return $twikiLibDir;
    }

    # FIXME: Should just use $INC{"TWiki.pm"} to get path used to load this
    # module.
    my $dir = '';
    foreach $dir ( @INC ) {
        if( $dir && -e "$dir/TWiki.pm" ) {
            $twikiLibDir = $dir;
            last;
        }
    }

    # fix path relative to location of called script
    if( $twikiLibDir =~ /^\./ ) {
        print STDERR "WARNING: TWiki lib path $twikiLibDir is relative; you should make it absolute, otherwise some scripts may not run from the command line.";
        my $bin;
        if( $ENV{SCRIPT_FILENAME} &&
            $ENV{SCRIPT_FILENAME} =~ /^(.+)\/[^\/]+$/ ) {
            # CGI script name
            $bin = $1;
        } elsif ( $0 =~ /^(.*)\/.*?$/ ) {
            # program name
            $bin = $1;
        } else {
            # last ditch; relative to current directory.
            require Cwd;
            import Cwd qw( cwd );
            $bin = cwd();
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

---++ ObjectMethod getSkin () -> $string

Get the name of the currently requested skin

=cut

sub getSkin {
    my $this = shift;

    ASSERT(ref($this) eq 'TWiki') if DEBUG;

    my $skin = '';
    $skin = $this->{cgiQuery}->param( 'skin' ) if( $this->{cgiQuery} );
    $skin = $this->{prefs}->getPreferencesValue( 'SKIN' ) unless( $skin );
    return $skin;
}

=pod

---++ ObjectMethod getScriptURL( $web, $topic, $script ) -> $absoluteScriptURL

Returns the absolute URL to a TWiki script, providing the web and topic as
"path info" parameters.  The result looks something like this:
"http://host/twiki/bin/$script/$web/$topic"

=cut

sub getScriptUrl {
    my( $this, $theWeb, $theTopic, $theScript ) = @_;

    ASSERT(ref($this) eq 'TWiki') if DEBUG;

    $theTopic ||= '';
    $theWeb ||= '';

    # SMELL: topics and webs that contain spaces?

    # $this->{urlHost} is needed, see Codev.PageRedirectionNotWorking
    my $url = $this->{urlHost};
    $url .= $TWiki::cfg{DispScriptUrlPath} . "/$theScript";
    $url .= $TWiki::cfg{ScriptSuffix};
    $url .= "/$theWeb/$theTopic";
    # FIXME consider a plugin call here - useful for certificated
    # logon environment
    return $url;
}

=pod

---++ ObjectMethod getUniqueScriptURL( $web, $topic, $script ) -> $absoluteScriptURL

Returns the absolute URL to a TWiki script, providing the web and topic as
"path info" parameters.  Add a "t" parameter that makes the URL unique to
defeat browser cacheing. The result looks something like this:
"http://host/twiki/bin/$script/$web/$topic?t=123456"

=cut

sub getUniqueScriptUrl {
    my( $this, $web, $topic, $script ) = @_;

    return $this->getScriptUrl( $web, $topic, $script) . '?t=' . time();
}

=pod

---++ ObjectMethod getOopsUrl( $web, $topic, $template, @scriptParams ) -> $absoluteOopsURL

Composes a URL for an "oops" error page.  The last parameters depend on the
specific oops template in use, and are passed in the URL as '&param1=' etc.

The returned URL ends up looking something like this:
"http://host/twiki/bin/oops/$web/$topic?template=$template&param1=$scriptParams[0]..."

=cut

sub getOopsUrl {
    my $this = shift;
    my $web = shift || $this->{webName};
    my $topic = shift;
    my $template = shift;

    ASSERT(ref($this) eq 'TWiki') if DEBUG;

    my $url = $this->getScriptUrl( $web, $topic, 'oops' ) .
      '?template=' . urlEncode( $template );

    my $n = 1;
    my $p;
    while( $p = shift ) {
        $url .= "&param$n=" . urlEncode( $p );
        $n++;
    }

    return $url;
}

=pod

---++ ObjectMethod normalizeWebTopicName (  $theWeb, $theTopic  ) -> ( $theWeb, $theTopic )

Normalize a Web<nop>.<nop>TopicName
<pre>
Input:                      Return:
  ( 'Web',  'Topic' )         ( 'Web',  'Topic' )
  ( '',     'Topic' )         ( 'Main', 'Topic' )
  ( '',     '' )              ( 'Main', 'WebHome' )
  ( '',     'Web/Topic' )     ( 'Web',  'Topic' )
  ( '',     'Web.Topic' )     ( 'Web',  'Topic' )
  ( 'Web1', 'Web2.Topic' )    ( 'Web2', 'Topic' )
  ( '%MAINWEB%', 'Web2.Topic' ) ( 'Main', 'Topic' )
  ( '%TWIKIWEB%', 'Web2.Topic' ) ( 'TWiki', 'Topic' )
</pre>
Note: Function renamed from getWebTopic

SMELL: WARNING: this function defaults the web and topic names.
Be very careful where you use it!

=cut

sub normalizeWebTopicName {
    my( $this, $theWeb, $theTopic ) = @_;

    ASSERT(ref($this) eq 'TWiki') if DEBUG;
    ASSERT(defined $theTopic) if DEBUG;

    if( $theTopic =~ m|^([^.]+)[\.\/](.*)$| ) {
        $theWeb = $1;
        $theTopic = $2;
    }
    my( $web, $topic ) = ( $theWeb, $theTopic );
    $web ||= $cfg{UsersWebName};
    $topic ||= $cfg{HomeTopicName};
    $web =~ s/^%((MAIN|TWIKI)WEB)%$/$this->_expandTag( $1 )/e;
    return( $web, $topic );
}

=pod

---++ ClassMethod new( $pathInfo, $remoteUser, $topic, $url, $query )
Constructs a new TWiki object.

Initializes the Store, User, Access, and Prefs modules.

Also parses $theTopic to determine whether it's a URI, a 'Web.Topic'
pair, a 'Web.' WebHome shorthand, or just a topic name.  Note that
if $pathInfo is set, this overrides $theTopic.

   * =$pathInfo= .pathinfo from query
   * =$remoteUser= the logged-in user (login name)
   * =$topic= topic from 'topic' parameter to url (overrides pathinfo if present )
   * =$url= the full url used
   * =$query= the query

=cut

sub new {
    my( $class, $pathInfo, $remoteUser, $topic, $url, $query ) = @_;

    $pathInfo ||= '';
    $remoteUser ||= $TWiki::cfg{DefaultUserLogin};
    $topic ||= '';
    $url ||= '';

    my $this = bless( {}, $class );

    # create the various sub-objects
    $this->{sandbox} = new TWiki::Sandbox
      ( $this, $TWiki::cfg{OS}, $TWiki::cfg{DetailedOS} );

    $this->{plugins} = new TWiki::Plugins( $this );
    $this->{net} = new TWiki::Net( $this );
    $this->{store} = new TWiki::Store( $this );
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

	if ( # (-e $TWiki::cfg{HtpasswdFileName} ) && #<<< maybe
		( $TWiki::cfg{HtpasswdFormatFamily} eq 'htpasswd' ) ) {
        $this->{users} = new TWiki::Users( $this, 'HtPasswdUser' );
#	} elseif ($TWiki::cfg{HtpasswdFormatFamily} eq 'something?') {
#        $this->{users} = new TWiki::Users( $this, 'SomethingUser' );
	} else {
        $this->{users} = new TWiki::Users( $this, 'NoPasswdUser' );
	}

    # Make %ENV safer, preventing hijack of the search path
    # SMELL: can this be done in a BEGIN block? Or is the environment
    # set per-query?
    if( $TWiki::cfg{SafeEnvPath} ) {
        $ENV{'PATH'} = $TWiki::cfg{SafeEnvPath};
    }
    delete @ENV{ qw( IFS CDPATH ENV BASH_ENV ) };

    # Check for unsafe search regex mode (affects filtering in) - default
    # to safe mode
    $TWiki::cfg{ForceUnsafeRegexes} = 0 unless defined $TWiki::cfg{ForceUnsafeRegexes};

    # initialize lib directory early because of later 'cd's
    getTWikiLibDir();

    $this->{security} = new TWiki::Access( $this );

    my $web = '';
    if( $topic ) {
        if( $topic =~ /^$regex{linkProtocolPattern}\:\/\//o &&
            $this->{cgiQuery} ) {
            # redirect to URI
            print $this->redirect( $topic );
            return;
        } elsif( $topic =~ /(.*)[\.\/](.*)/ ) {
            # is 'bin/script?topic=Webname.SomeTopic'
            $web   = $1 || '';
            $topic = $2 || '';
            # jump to WebHome if 'bin/script?topic=Webname.'
            $topic = $TWiki::cfg{HomeTopicName} if( $web && ! $topic );
        }
        # otherwise assume 'bin/script/Webname?topic=SomeTopic'
    } else {
        $topic = '';
    }

    # Clean up PATH_INFO problems, e.g.  Support.CobaltRaqInstall.  A valid
    # PATH_INFO is '/Main/WebHome', i.e. the text after the script name;
    # invalid PATH_INFO is often a full path starting with '/cgi-bin/...'.
    my $cgiScriptName = $ENV{'SCRIPT_NAME'} || '';
    $pathInfo =~ s!$cgiScriptName/!/!i;

    # Get the web and topic names from PATH_INFO
    if( $pathInfo =~ /\/(.*)[\.\/](.*)/ ) {
        # is 'bin/script/Webname/SomeTopic' or 'bin/script/Webname/'
        $web   = $1 || '' unless $web;
        $topic = $2 || '' unless $topic;
    } elsif( $pathInfo =~ /\/(.*)/ ) {
        # is 'bin/script/Webname' or 'bin/script/'
        $web   = $1 || '' unless $web;
    }

    if ( $topic =~ /\.\./ ) {
        $topic = $this->{mainTopicname};
    }

    $topic =~ s/$TWiki::cfg{NameFilter}//go;
    $topic = $TWiki::cfg{HomeTopicName} unless $topic;
    $this->{topicName} = $topic;
    $web   =~ s/$TWiki::cfg{NameFilter}//go;
    $web = $TWiki::cfg{UsersWebName} unless $web;
    $this->{webName} = $web;

    # Convert UTF-8 web and topic name from URL into site charset 
    # if necessary - no effect if URL is not in UTF-8
    $this->_convertUtf8URLtoSiteCharset();

    $this->{scriptUrlPath} = $TWiki::cfg{ScriptUrlPath};

    # initialize $urlHost and $TWiki::cfg{ScriptUrlPath} 
    if( $url && $url =~ m!^([^:]*://[^/]*)(.*)/.*$! && $2 ) {
        if( $TWiki::cfg{GetScriptUrlFromCgi} ) {
            # SMELL: this is a really dangerous hack. It will fail
            # spectacularly with mod_perl.
            $this->{scriptUrlPath} = $2;
        }
        $this->{urlHost} = $1;
        if( $TWiki::cfg{RemovePortNumber} ) {
            $this->{urlHost} =~ s/\:[0-9]+$//;
        }
    } else {
        $this->{urlHost} = $TWiki::cfg{DefaultUrlHost};
    }

    # initialize preferences, first part for site and web level
    $this->{prefs} = new TWiki::Prefs( $this );

    # SMELL: there should be a way for the plugin to specify
    # the WikiName of the user as well as the login.
    my $login = $this->{plugins}->load( $TWiki::cfg{DisableAllPlugins} );
    unless( $login ) {
        $login = $this->{users}->initializeRemoteUser( $remoteUser );
    }
    my $user = $this->{users}->findUser( $login );
    $this->{user} = $user;

    # Static session variables that can be expanded in topics when they
    # are enclosed in % signs
    # SMELL: should collapse these into one. The duplication is pretty
    # pointless. Could get rid of the SESSION_TAGS hash, might be
    # the easiest thing to do, but then that would allow other
    # upper-case named fields in the object to be accessed as well...
    $this->{SESSION_TAGS}{USERNAME}       = $user->login();
    $this->{SESSION_TAGS}{WIKINAME}       = $user->wikiName();
    $this->{SESSION_TAGS}{WIKIUSERNAME}   = $user->webDotWikiName();
    $this->{SESSION_TAGS}{BASEWEB}        = $this->{webName};
    $this->{SESSION_TAGS}{BASETOPIC}      = $this->{topicName};
    $this->{SESSION_TAGS}{INCLUDINGTOPIC} = $this->{topicName};
    $this->{SESSION_TAGS}{INCLUDINGWEB}   = $this->{webName};
    $this->{SESSION_TAGS}{ATTACHURL}      = $this->{urlHost}.'%ATTACHURLPATH%';
    $this->{SESSION_TAGS}{PUBURL}         = $this->{urlHost}.$TWiki::cfg{PubUrlPath};
    $this->{SESSION_TAGS}{SCRIPTURL}      = $this->{urlHost}.$TWiki::cfg{DispScriptUrlPath};

    # initialize user preferences
    $this->{prefs}->initializeUser();

    $this->{renderer} = new TWiki::Render( $this );

    # Finish plugin initialization - register handlers
    $this->{plugins}->enable();

    # Assumes all preferences values are set by now, which may well be false!
    # populate the session hash with prefs values. These always override
    # default values of these tags, which is really a bad idea.
    $this->{prefs}->loadHash( \%{$this->{SESSION_TAGS}} );

    return $this;
}

# Uncomment when enabling AutoLoader
#__END__

=pod

---++ ObjectMethod writeLog (  $action, $webTopic, $extra, $user  )
   * =$action= - what happened, e.g. view, save, rename
   * =$wbTopic= - what it happened to
   * =$extra= - extra info, such as minor flag
   * =$user= - user who did the saving (user object or string user name)
Write the log for an event to the logfile

=cut

sub writeLog {
    my $this = shift;
    ASSERT(ref($this) eq 'TWiki') if DEBUG;
    my $action = shift || '';
    my $webTopic = shift || '';
    my $extra = shift || '';
    my $user = shift;

    $user = $this->{user} unless $user;
    if(ref($user) eq 'TWiki::User') {
        $user = $user->wikiName();
    }
    my $remoteAddr = $ENV{'REMOTE_ADDR'} || '';
    my $text = "| $user | $action | $webTopic | $extra | $remoteAddr |";

    $this->_writeReport( $TWiki::cfg{LogFileName}, $text );
}

=pod

---++ ObjectMethod writeWarning( $text )

Prints date, time, and contents $text to $TWiki::cfg{WarningFileName}, typically
'warnings.txt'. Use for warnings and errors that may require admin
intervention. Use this for defensive programming warnings (e.g. assertions).

=cut

sub writeWarning {
    my $this = shift;
    ASSERT(ref($this) eq 'TWiki') if DEBUG;
    $this->_writeReport( $TWiki::cfg{WarningFileName}, @_ );
}

=pod

---++ ObjectMethod writeDebug( $text )

Prints date, time, and contents of $text to $TWiki::cfg{DebugFileName}, typically
'debug.txt'.  Use for debugging messages.

=cut

sub writeDebug {
    my $this = shift;
    ASSERT(ref($this) eq 'TWiki') if DEBUG;
    $this->_writeReport( $TWiki::cfg{DebugFileName}, @_ );
}

# Concatenates date, time, and $text to a log file.
# The logfilename can optionally use a %DATE% variable to support
# logs that are rotated once a month.
# | =$log= | Base filename for log file |
# | =$message= | Message to print |
sub _writeReport {
    my ( $this, $log, $message ) = @_;

    if ( $log ) {
        my $time =
          TWiki::Time::formatTime( time(), "\$year\$mo", "servertime");
        $log =~ s/%DATE%/$time/go;
        $time = TWiki::Time::formatTime( time(), undef, 'servertime' );

        if( open( FILE, ">>$log" ) ) {
            print FILE "| $time | $message\n";
            close( FILE );
        } else {
            print STDERR "Couldn't write \"$message\" to $log: $!\n";
        }
    }
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
        $url = $theHost.$url;
    } elsif( $url =~ /^\./ ) {
        # fix relative URL
        $url = $theHost.$theAbsPath.'/'.$url;
    } elsif( $url =~ /^$regex{linkProtocolPattern}\:/o ) {
        # full qualified URL, do nothing
    } elsif( $url ) {
        # FIXME: is this test enough to detect relative URLs?
        $url = $theHost.$theAbsPath.'/'.$url;
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

---++ StaticMethod applyPatternToIncludedText (  $text, $pattern ) -> $text

Apply a pattern on included text to extract a subset

=cut

sub applyPatternToIncludedText {
    my( $theText, $thePattern ) = @_;
    $thePattern =~ s/([^\\])([\$\@\%\&\#\'\`\/])/$1\\$2/g;  # escape some special chars
    $thePattern = TWiki::Sandbox::untaintUnchecked( $thePattern );
    $theText = '' unless( $theText =~ s/$thePattern/$1/is );
    return $theText;
}

# Fetch content from a URL for inclusion by an INCLUDE
sub _includeUrl {
    my( $this, $theUrl, $thePattern, $theWeb, $theTopic ) = @_;
    my $text = '';
    my $host = '';
    my $port = 80;
    my $path = '';
    my $user = '';
    my $pass = '';

    # For speed, read file directly if URL matches an attachment directory
    if( $theUrl =~ /^$this->{urlHost}$TWiki::cfg{PubUrlPath}\/([^\/\.]+)\/([^\/\.]+)\/([^\/]+)$/ ) {
        my $web = $1;
        my $topic = $2;
        my $fileName = "$TWiki::cfg{PubDir}/$web/$topic/$3";
        if( $fileName =~ m/\.(txt|html?)$/i ) {       # FIXME: Check for MIME type, not file suffix
            unless( -e $fileName ) {
                return _inlineError( "Error: File attachment at $theUrl does not exist" );
            }
            if( $web ne $theWeb || $topic ne $theTopic ) {
                # CODE_SMELL: Does not account for not yet authenticated user
                unless( $this->{security}->checkAccessPermission( 'view',
                                                                 $this->{user},
                                                                 '', $topic,
                                                                 $web ) ) {
                    return _inlineError( "Error: No permission to view files attached to $web.$topic" );
                }
            }
            $text = $this->{store}->readFile( $fileName );
            $text = _cleanupIncludedHTML( $text, $this->{urlHost}, $TWiki::cfg{PubUrlPath} );
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
    my $contentType = '';
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

#
# SMELL: this is _not_ a tag handler in the sense of other builtin tags, because it requires
# far more context information (the text of the topic) than any handler. It is really
# a plugin, and since it has an interface exactly like a plugin, would be much
# happier as a plugin. Having it here requires more code, and offers no perceptible benefit.
#
#    * $text  : ref to the text of the current topic
#    * $topic : the topic we are in
#    * $web   : the web we are in
#    * $args  : 'Topic' [web='Web'] [depth='N']
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

    my $params = new TWiki::Attrs( $args );

    # get the topic name attribute
    my $topic = $params->{_DEFAULT} || $defaultTopic;

    # get the web name attribute
    my $web = $params->{web} || $defaultWeb;
    $web =~ s/\//\./g;
    my $webPath = $web;
    $webPath =~ s/\./\//g;

    # get the depth limit attribute
    my $depth = $params->{depth} || 6;

    # get the title attribute
    my $title = $params->{title} || '';
    $title = '<span class="twikiTocTitle">'.$title.'</span>' if( $title );

    if( $web ne $defaultWeb || $topic ne $defaultTopic ) {
        unless( $this->{security}->checkAccessPermission
                ( 'view', $this->{user}, '', $topic, $web ) ) {
            return _inlineError( 'Error: No permission to view '.
                                 $web.'.'.$topic );
        }
        my $meta;
        ( $meta, $text ) =
          $this->{store}->readTopic( $this->{user}, $web, $topic );
    }

    my $insidePre = 0;
    my $insideVerbatim = 0;
    my $highest = 99;
    my $result  = '';

    # SMELL: this handling of <pre> is archaic.
    foreach my $line ( split( /\r?\n/, $text ) ) {
        if( $line =~ /^.*<pre>.*$/io ) {
            $insidePre++;
            next;
        }
        if( $line =~ /^.*<\/pre>.*$/io ) {
            $insidePre--;
            next;
        }
        if( $line =~ /^<verbatim>.*$/io ) {
            $insideVerbatim++;
            next;
        }
        if( $line =~ /^<\/verbatim>.*$/io ) {
            $insideVerbatim--;
            next;
        }
        next if ($insidePre || $insideVerbatim);
        my $level;
        if ( $line =~ m/$regex{headerPatternDa}/o ) {
            $line = $2;
            $level = length $1;
        } elsif ( $line =~ m/$regex{headerPatternSp}/ ) {
            $line = $2;
            $level = length $1;
        } elsif ( $line =~ m/$regex{headerPatternHt}/io ) {
            $line = $2;
            $level = $1;
        } else {
            next;
        }
        my $urlPath = '';
        if( $web ne $defaultWeb || $topic ne $defaultTopic ) {
            # not current topic, can't omit URL
            $urlPath = $this->getScriptUrl($webPath, $topic, 'view');
        }
        if( $line && $level <= $depth ) {
            # cut TOC exclude '---+ heading !! exclude this bit'
            $line =~ s/\s*$regex{headerPatternNoTOC}.+$//go;
            next unless $line;
            my $anchor = $this->{renderer}->makeAnchorName( $line );
            $highest = $level if( $level < $highest );
            my $tabs = "\t" x $level;
            # Remove *bold*, _italic_ and =fixed= formatting
            $line =~ s/(^|[\s\(])\*([^\s]+?|[^\s].*?[^\s])\*($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
            $line =~ s/(^|[\s\(])_+([^\s]+?|[^\s].*?[^\s])_+($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
            $line =~ s/(^|[\s\(])=+([^\s]+?|[^\s].*?[^\s])=+($|[\s\,\.\;\:\!\?\)])/$1$2$3/g;
            # Prevent WikiLinks
            $line =~ s/\[\[.*?\]\[(.*?)\]\]/$1/g;  # '[[...][...]]'
            $line =~ s/\[\[(.*?)\]\]/$1/ge;        # '[[...]]'
            $line =~ s/([\s\(])($regex{webNameRegex})\.($regex{wikiWordRegex})/$1<nop>$3/go;  # 'Web.TopicName'
            $line =~ s/([\s\(])($regex{wikiWordRegex})/$1<nop>$2/go;  # 'TopicName'
            $line =~ s/([\s\(])($regex{abbrevRegex})/$1<nop>$2/go;    # 'TLA'
            # create linked bullet item, using a relative link to anchor
            $line = "$tabs* <a href=\"$urlPath#$anchor\">$line</a>";
            $result .= "\n".$line;
        }
    }
    if( $result ) {
        if( $highest > 1 ) {
            # left shift TOC
            $highest--;
            $result =~ s/^\t{$highest}//gm;
        }
        return '<div class="twikiToc">'.$title.$result."\n</div>";
    } else {
        return '';
    }
}

# Format an error for inline inclusion in HTML
sub _inlineError {
    my( $errormessage ) = @_;
    return '<font size="-1" class="twikiAlert" color="red">' .
      $errormessage .
        '</font>';
}

=pod

---++ ObjectMethod expandVariablesOnTopicCreation ( $text, $user ) -> $text
   * =$text= - text to expand
   * =$user= - reference to user object
Expand limited set of variables during topic creation. These are variables
expected in templates that must be statically expanded in new content.

The expanded variables are:
| =%<nop>DATE%= | Signature-format date |
| =%<nop>TIME%= | Server time |
| =%<nop>SERVERTIME%= | Server time |
| =%<nop>GMTIME%= | GM time |
| =%<nop>USERNAME%= | Base login name |
| =%<nop>WIKINAME%= | Wiki name |
| =%<nop>WIKIUSERNAME%= | Wiki name with prepended web |
| =%<nop>URLPARAM%= | Parameters to the current CGI query |
| =%<nop>NOP%= | No-op |

SMELL: This should really be done by _expandAllTags but with
a subset of the substitutions.

=cut

sub expandVariablesOnTopicCreation {
    my ( $this, $text, $user ) = @_;

    ASSERT(ref($this) eq 'TWiki') if DEBUG;
    ASSERT(ref($user) eq 'TWiki::User') if DEBUG;

    $text =~ s/%DATE%/$this->_DATE()/ge;
    $text =~ s/%TIME%/%SERVERTIME%/g;
    $text =~ s/%SERVERTIME(?:{(.*?)})?%/$this->_SERVERTIME(new TWiki::Attrs($1))/ge;
    $text =~ s/%GMTIME(?:{(.*?)})?%/$this->_GMTIME(new TWiki::Attrs($1))/ge;

    $text =~ s/%((USER|WIKI|WIKIUSER)NAME)%/$this->{SESSION_TAGS}{$1}/g;
    $text =~ s/%URLPARAM{(.*?)}%/$this->_URLPARAM(new TWiki::Attrs($1))/ge;

    # Remove filler: Use it to remove access control at time of
    # topic instantiation or to prevent search from hitting a template
    # SMELL: this expansion of %NOP{}% is different to the default
    # which retains content.....
    $text =~ s/%NOP{.*?}%//gos;
    $text =~ s/%NOP%//go;

    return $text;
}

sub _webOrTopicList {
    my( $this, $isWeb, $params ) = @_;
    my $format = $params->{_DEFAULT} || $params->{format};
    $format .= '$name' unless( $format =~ /\$name/ );
    my $separator = $params->{separator} || "\n";
    my $web = $params->{web} || '';
    my $webs = $params->{webs} || 'public';
    my $selection = $params->{selection} || '';
    $selection =~ s/\,/ /g;
    $selection = ' '.$selection.' ';
    my $marker    = $params->{marker} || 'selected="selected"';

    my @list = ();
    if( $isWeb ) {
        my @webslist = split( /,\s?/, $webs );
        foreach my $aweb ( @webslist ) {
            if( $aweb eq 'public' ) {
                push( @list, $this->{store}->getListOfWebs( 'user,public' ) );
            } elsif( $aweb eq 'webtemplate' ) {
                push( @list, $this->{store}->getListOfWebs( 'template' ));
            } else{
                push( @list, $aweb ) if( $this->{store}->webExists( $aweb ) );
            }
        }
    } else {
        $web = $this->{webName} if( ! $web );
        my $hidden =
          $this->{prefs}->getPreferencesValue( 'NOSEARCHALL', $web );
        if( ( $web eq $this->{webName}  ) || ( ! $hidden ) ) {
            @list = $this->{store}->getTopicNames( $web );
        }
    }
    my $text = '';
    my $item = '';
    my $line = '';
    my $mark = '';
    foreach $item ( @list ) {
        $line = $format;
        $line =~ s/\$web/$web/goi;
        $line =~ s/\$name/$item/goi;
        $line =~ s/\$qname/"$item"/goi;
        $mark = ( $selection =~ / \Q$item\E / ) ? $marker : '';
        $line =~ s/\$marker/$mark/goi;
        $text .= $line.$separator;
    }
    $text =~ s/$separator$//s;  # remove last separator
    return $text;
}

=pod

---++ StaticMethod entityEncode (text ) -> $html

Escape certain characters to HTML entities

=cut

sub entityEncode {
    my $text = shift;

    # HTML entity encoding
    $text =~ s/([\"\%\*\_\=\[\]\<\>\|])/"\&\#".ord( $1 ).';'/ge;
    return $text;
}

# Generate a $w-char hexidecimal number representing $n.
# Default $w is 2 (one byte)
sub _hexchar {
    my( $n, $w ) = @_;
    $w = 2 unless $w;
    return sprintf( "%0${w}x", ord( $n ));
}

=pod

---++ StaticMethod urlEncode( $string ) -> encoded string

Encode by converting characters that are illegal in URLs to
their %NN equivalents.

TODO: For non-ISO-8859-1 $siteCharset, need to convert to
UTF-8 before URL encoding.

=cut

# SMELL: what is the relationship to nativeUrlEncode??
sub urlEncode {
    my $text = shift;

    # URL encoding
    $text =~ s/[\n\r]/\%3Cbr\%20\%2F\%3E/g;
    $text =~ s/\s/\%20/g;
    $text =~ s/(["&+<>\\])/"%"._hexchar($1,2)/ge;
    # Encode characters > 0x7F (ASCII-derived charsets only)
	# TODO: Encode to UTF-8 first
    $text =~ s/([\x7f-\xff])/'%' . unpack( 'H*', $1 ) /ge;

    return $text;
}

=pod

---++ StaticMethod nativeUrlEncode ( $theStr, $doExtract ) -> encoded string

Perform URL encoding into native charset ($siteCharset) - for use when
viewing attachments via browsers that generate UTF-8 URLs, on sites running
with non-UTF-8 (Native) character sets.  Aim is to prevent UTF-8 URL
encoding.  For mainframes, we assume that UTF-8 URLs will be translated
by the web server to an EBCDIC character set.

=cut

sub nativeUrlEncode {
    my $theStr = shift;

    my $isEbcdic = ( 'A' eq chr(193) ); 	# True if Perl is using EBCDIC

    if( $siteCharset eq 'utf-8' or $isEbcdic ) {
        # Just strip double quotes, no URL encoding - let browser encode to
        # UTF-8 or EBCDIC based $siteCharset as appropriate
        $theStr =~ s/^"(.*)"$/$1/;	
        return $theStr;
    } else {
        return urlEncode( $theStr );
    }
}

=pod

---++ StaticMethod encodeSpecialChars (  $text  ) -> encoded string

Escape out the chars &, ", >, <, \r and \n with replaceable tokens.
This is used to protect hidden fields from the browser.

=cut

# "
sub encodeSpecialChars {
    my $text = shift;

    $text = '' unless defined( $text );
    $text =~ s/\%/%_P_%/g;
    $text =~ s/&/%_A_%/g;
    $text =~ s/\"/%_Q_%/g;
    $text =~ s/>/%_G_%/g;
    $text =~ s/</%_L_%/g;
    $text =~ s/\r*\n\r*/%_N_%/g;

    return $text;
}

=pod

---++ StaticMethod decodeSpecialChars (  $text  ) -> decoded $text

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

---++ StaticMethod searchableTopic (  $topic  ) -> spaced $topic

Space out the topic name for a search, by inserting ' *' at
the start of each component word.

=cut

sub searchableTopic {
    my( $topic ) = @_;
    # FindMe -> Find\s*Me
    $topic =~ s/([$regex{lowerAlpha}]+)([$regex{upperAlpha}$regex{numeric}]+)/$1%20*$2/go;   # "%20*" is " *" - I18N: only in ASCII-derived charsets
    return $topic;
}

# Expands variables by replacing the variables with their
# values. Some example variables: %<nop>TOPIC%, %<nop>SCRIPTURL%,
# %<nop>WIKINAME%, etc.
# $web and $incs are passed in for recursive include expansion. They can
# safely be undef.
# The rules for tag expansion are:
#    1 Tags are expanded left to right, in the order they are encountered.
#    1 Tags are recursively expanded as soon as they are encountered - the algorithm is inherently single-pass
#    1 A tag is not "encountered" until the matching }% has been seen, by which time all tags in parameters will have been expanded
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
    $this->{SESSION_TAGS}{EDITURL} =
      $this->getUniqueScriptUrl( $web, $topic, 'edit' );

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
    $$text = $this->_processTags( $$text, 16, '', @_ );

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

    return '' unless defined( $text );

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
    #my $tell = 0; # uncomment all tell lines set this to 1 to print debugging

    push( @stack, '' );
    while ( scalar( @queue )) {
        my $token = shift( @queue );
        #print ' ' x $tell,"PROCESSING $token \n" if $tell;

        # each % sign either closes an existing stacked context, or
        # opens a new context.
        if ( $token eq '%' ) {
            #print ' ' x $tell,"CONSIDER $stack[$#stack]\n" if $tell;
            # If this is a closing }%, try to rejoin the previous
            # tokens until we get to a valid tag construct. This is
            # a bit of a hack, but it's hard to think of a better
            # way to do this without a full parse that takes % signs
            # in tag parameters into account.
            if ( $stack[$#stack] =~ /}$/ ) {
                while ( $#stack &&
                        $stack[$#stack] !~ /^%([A-Z][A-Z0-9_:]*){(.*)}$/ ) {
                    my $top = pop( @stack );
                    #print ' ' x $tell,"COLLAPSE $top \n" if $tell;
                    $stack[$#stack] .= $top;
                }
            }
            if ( $stack[$#stack] =~ m/^%([A-Z][A-Z0-9_:]*)(?:{(.*)})?$/ ) {
                my $tag = $1;
                my $args = $2;
                #print ' ' x $tell,"POP $tag\n" if $tell;
                my $e = $this->_expandTag( $tag, $args, @_ );
                if ( defined( $e )) {
                    #print ' ' x $tell--,"EXPANDED $tag -> $e\n" if $tell;
                    pop( @stack );
                    # Choice: can either tokenise and push the expanded
                    # tag, or can recursively expand the tag. The
                    # behaviour is different in each case.
                    #unshift( @queue, split( /(%)/, $e ));
                    $stack[$#stack] .=
                      $this->_processTags($e, $depth+1, $expanding , @_ );
                } else { # expansion failed
                    #print ' ' x $tell++,"EXPAND $tag FAILED\n" if $tell;
                    push( @stack, '%' ); # push a new context, starting
                }
            } else {
                push( @stack, '%' ); # push a new context
                #$tell++ if ( $tell );
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

# Handle expansion of a tag (as against preference tags)
# $tag is the tag name
# $args is the bit in the {} (if there are any)
# $topic and $web should be passed for dynamic tags (not needed for
# session or constant tags
sub _expandTag {
    my $this = shift;
    my $tag = shift;
    my $args = shift;
    # my( $topic, $web ) = @_;

    my $res;

    if ( defined( $this->{SESSION_TAGS}{$tag} )) {
        $res = $this->{SESSION_TAGS}{$tag};
    } elsif ( defined( $constantTags{$tag} )) {
        $res = $constantTags{$tag};
    } elsif ( defined( $functionTags{$tag} )) {
        my $params = new TWiki::Attrs( $args );
        $res = &{$functionTags{$tag}}( $this, $params, @_ );
    }

    return $res;
}

=pod

---++ StaticMethod registerTagHandler( $fnref )

STATIC Add a tag handler to the function tag handlers.
   * =$tag= name of the tag e.g. MYTAG
   * =$fnref= Function to execute. Will be passed ($session, \%params, $web, $topic )

=cut

sub registerTagHandler {
    my ( $tag, $fnref ) = @_;
    $TWiki::functionTags{$tag} = \&$fnref;
}

=pod

---++ ObjectMethod handleCommonTags( $text, $web, $topic ) -> $text
Processes %<nop>VARIABLE%, and %<nop>TOC% syntax; also includes
'commonTagsHandler' plugin hook.

Returns the text of the topic, after file inclusion, variable substitution,
table-of-contents generation, and any plugin changes from commonTagsHandler.

=cut

sub handleCommonTags {
    my( $this, $text, $theWeb, $theTopic ) = @_;

    ASSERT(ref($this) eq 'TWiki') if DEBUG;
    ASSERT($theWeb) if DEBUG;
    ASSERT($theTopic) if DEBUG;

    # Plugin Hook (for cache Plugins only)
    $this->{plugins}->beforeCommonTagsHandler( $text, $theTopic, $theWeb );

    # remember the block for when we handle includes
    my $verbatims = {};
    $text = $this->{renderer}->takeOutBlocks( $text, 'verbatim',
                                              $verbatims );

    # Escape rendering: Change ' !%VARIABLE%' to ' %<nop>VARIABLE%', for final ' %VARIABLE%' output
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

    # 'Special plugin tag' TOC hack
    $text =~ s/%TOC(?:{(.*?)})?%/$this->_TOC($text, $theTopic, $theWeb, $1)/ge;

    # Codev.FormattedSearchWithConditionalOutput: remove <nop> lines,
    # possibly introduced by SEARCHes with conditional CALC. This needs
    # to be done after CALC and before table rendering
    # SMELL: is this a hack? Looks like it....
    $text =~ s/^<nop>\r?\n//gm;

    $this->{renderer}->putBackBlocks( $text, $verbatims, 'verbatim' );

    # TWiki Plugin Hook (for cache Plugins only)
    $this->{plugins}->afterCommonTagsHandler( $text, $theTopic, $theWeb );

    return $text;
}

=pod

---++ StaticMethod initialize( $pathInfo, $remoteUser, $topic, $url, $query ) -> ($topicName, $webName, $scriptUrlPath, $userName, $dataDir)

Return value: ( $topicName, $webName, $TWiki::cfg{ScriptUrlPath}, $userName, $TWiki::cfg{DataDir} )

Static method to construct a new singleton session instance.
It creates a new TWiki and sets the Plugins $SESSION variable to
point to it, so that TWiki::Func methods will work.

This method is *DEPRECATED* but is maintained for script compatibility.

=cut

sub initialize {
    my ( $pathInfo, $theRemoteUser, $topic, $theUrl, $theQuery ) = @_;

    my $twiki = new TWiki( $pathInfo, $theRemoteUser, $topic, $theUrl, $theQuery );

    # Attempt to force the new session into the plugins context. This may not work.
    $TWiki::Plugins::SESSION = $twiki;

    return ( $twiki->{topicName}, $twiki->{webName}, $twiki->{scriptUrlPath},
             $twiki->{userName}, $TWiki::cfg{DataDir} );
}

sub _FORMFIELD {
    my $this = shift;
    return $this->{renderer}->renderFormField( @_ );
}

sub _TMPLP {
    my( $this, $params ) = @_;
    return $this->{templates}->expandTemplate( $params->{_DEFAULT} );
}

sub _VAR {
    my( $this, $params, $topic, $inweb ) = @_;
    my $key = $params->{_DEFAULT};
    my $web = $params->{web} || $inweb;
    if( $web =~ /%[A-Z]+%/ ) { # handle %MAINWEB%-type cases 
        handleInternalTags( $web, $inweb, $topic );
    }
    return $this->{prefs}->getPreferencesValue( $key, $web );
}

sub _PLUGINVERSION {
    my( $this, $params ) = @_;
    $this->{plugins}->getPluginVersion( $params->{_DEFAULT} );
}

# Processes a specific instance %<nop>INCLUDE{...}% syntax.
# Returns the text to be inserted in place of the INCLUDE command.
# $topic and $web should be for the immediate parent topic in the
# include hierarchy. Works for both URLs and absolute server paths.
sub _INCLUDE {
    my ( $this, $params, $theTopic, $theWeb ) = @_;
    my $path = $params->remove('_DEFAULT') || '';
    my $pattern = $params->remove('pattern');
    my $rev     = $params->remove('rev');
    my $warn    = $params->remove('warn');

    if( $path =~ /^https?\:/ ) {
        # include web page
        return $this->_includeUrl( $path, $pattern, $theWeb, $theTopic );
    }

    $path =~ s/$TWiki::cfg{NameFilter}//go;    # zap anything suspicious
    if( $TWiki::cfg{DenyDotDotInclude} ) {
        # Filter out '..' from filename, this is to
        # prevent includes of '../../file'
        $path =~ s/\.+/\./g;
    } else {
        # danger, could include .htpasswd with relative path
        $path =~ s/passwd//gi;    # filter out passwd filename
    }

    my $text = '';
    my $meta = '';
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
        $warn = $this->{prefs}->getPreferencesValue( 'INCLUDEWARNING' ) unless( $warn );
        if( $warn && $warn =~ /^on$/i ) {
            return _inlineError( "Warning: Can't INCLUDE <nop>$inctopic, topic not found" );
        } elsif( $warn && $warn !~ /^(off|no)$/i ) {
            $inctopic =~ s/\//\./go;
            $warn =~ s/\$topic/$inctopic/go;
            return $warn;
        } # else fail silently
        return '';
    }
    $path = $incweb.'.'.$inctopic;

    # prevent recursive includes. Note that the inclusion of a topic into
    # itself is not blocked; however subsequent attempts to include the
    # topic will fail.
    if( grep( /^$path$/, @{$this->{includeStack}} )) {
        $warn = $this->{prefs}->getPreferencesValue( 'INCLUDEWARNING' ) unless( $warn );
        if( $warn && $warn !~ /^(off|no)$/i ) {
            my $mess = "Warning: Can't INCLUDE $incweb.<nop>$inctopic twice, topic is already included";
            if( $#{$this->{includeStack}} ) {
                $mess .= '; include path is ' .
                  join('/', @{$this->{includeStack}});
            }
            return _inlineError( $mess );
        } # else fail silently
        return '';
    }

    my %saveTags = %{$this->{SESSION_TAGS}};

    push( @{$this->{includeStack}}, $path );
    $this->{SESSION_TAGS}{INCLUDINGWEB} = $theWeb;
    $this->{SESSION_TAGS}{INCLUDINGTOPIC} = $theTopic;

    # copy params into session tags
    foreach my $k ( keys %$params ) {
        $this->{SESSION_TAGS}{$k} = $params->{$k};
    }

    $theTopic = $inctopic;
    $theWeb = $incweb;

    ( $meta, $text ) =
      $this->{store}->readTopic( $this->{user}, $theWeb, $theTopic,
                                 $rev );

    # remove everything before %STARTINCLUDE% and
    # after %STOPINCLUDE%
    $text =~ s/.*?%STARTINCLUDE%//s;
    $text =~ s/%STOPINCLUDE%.*//s;
    $text = applyPatternToIncludedText( $text, $pattern ) if( $pattern );

    # take out verbatims, pushing them into the same storage block
    # as the including topic so when we do the replacement at
    # the end they are all there
    $text = $this->{renderer}->takeOutBlocks( $text, 'verbatim',
                                              $this->{_verbatims} );

    # Escape rendering: Change ' !%VARIABLE%' to ' %<nop>VARIABLE%', for final ' %VARIABLE%' output
    $text =~ s/(\s)\!\%([A-Z])/$1%<nop>$2/g;

    $this->_expandAllTags( \$text, $theTopic, $theWeb );

    # 4th parameter tells plugin that its called for an included file
    $this->{plugins}->commonTagsHandler( $text, $theTopic, $theWeb, 1 );

    # If needed, fix all 'TopicNames' to 'Web.TopicNames' to get the
    # right context
    # SMELL: This is a hack.
    if( $theWeb ne $this->{webName} ) {
        # 'TopicName' to 'Web.TopicName'
        $text =~ s/(^|[\s\(])($regex{webNameRegex}\.$regex{wikiWordRegex})/$1$TranslationToken$2/go;
        $text =~ s/(^|[\s\(])($regex{wikiWordRegex})/$1$theWeb\.$2/go;
        $text =~ s/(^|[\s\(])$TranslationToken/$1/go;
        # '[[TopicName]]' to '[[Web.TopicName][TopicName]]'
        $text =~ s/\[\[([^\]]+)\]\]/&_fixIncludeLink( $theWeb, $1 )/geo;
        # '[[TopicName][...]]' to '[[Web.TopicName][...]]'
        $text =~ s/\[\[([^\]]+)\]\[([^\]]+)\]\]/&_fixIncludeLink( $theWeb, $1, $2 )/geo;
        # FIXME: Support for <noautolink>
    }

    # handle tags again because of plugin hook
    $this->_expandAllTags( \$text, $theTopic, $theWeb );

    # restore the tags
    pop( @{$this->{includeStack}} );
    %{$this->{SESSION_TAGS}} = %saveTags;

    $text =~ s/^\n+/\n/;
    $text =~ s/\n+$/\n/;

    return $text;
}

sub _HTTP_HOST {
    return $ENV{HTTP_HOST} || '';
}

sub _REMOTE_ADDR {
    return $ENV{REMOTE_ADDR} || '';
}

sub _REMOTE_PORT {
    return $ENV{REMOTE_PORT} || '';
}

sub _REMOTE_USER {
    return $ENV{REMOTE_USER} || '';
}

# Only does simple search for topicmoved at present, can be expanded when required
# SMELL: this violates encapsulation of Store and Meta, by exporting
# the assumption that meta-data is stored embedded inside topic
# text.
sub _METASEARCH {
    my( $this, $params ) = @_;

    return $this->{store}->searchMetaData( $params );
}

# Deprecated, but used in signatures
sub _DATE {
    my $this = shift;
    return TWiki::Time::formatTime(time(), "\$day \$mon \$year", 'gmtime');
}

sub _GMTIME {
    my( $this, $params ) = @_;
    return TWiki::Time::formatTime( time(), $params->{_DEFAULT} || '', 'gmtime' );
}

sub _SERVERTIME {
    my( $this, $params ) = @_;
    return TWiki::Time::formatTime( time(), $params->{_DEFAULT} || '', 'servertime' );
}

sub _DISPLAYTIME {
    my( $this, $params ) = @_;
    return TWiki::Time::formatTime( time(), $params->{_DEFAULT} || '', $TWiki::cfg{DisplayTimeValues} );
}

#| $web | web and  |
#| $topic | topic to display the name for |
#| $formatString | twiki format string (like in search) |
sub _REVINFO {
    my ( $this, $params, $theTopic, $theWeb ) = @_;
    my $format = $params->{_DEFAULT} || $params->{format};
    my $web    = $params->{web} || $theWeb;
    my $topic  = $params->{topic} || $theTopic;
    my $cgiQuery = $this->{cgiQuery};
    my $cgiRev = '';
    $cgiRev = $cgiQuery->param('rev') if( $cgiQuery );
    my $rev = $cgiRev || $params->{rev} || '';

    return $this->{renderer}->renderRevisionInfo( $web, $topic, $rev, $format );
}

sub _ENCODE {
    my( $this, $params ) = @_;
    my $type = $params->{type};
    my $text = $params->{_DEFAULT} || '';
    if ( $type && $type =~ /^entit(y|ies)$/i ) {
        return entityEncode( $text );
    } else {
        return urlEncode( $text );
    }
}

sub _SEARCH {
    my ( $this, $params, $theTopic, $theWeb ) = @_;
    # pass on all attrs, and add some more
    #$params->{_callback} = undef;
    $params->{inline} = 1;
    $params->{baseweb} = $theTopic;
    $params->{basetopic} = $theWeb;
    $params->{search} = $params->{_DEFAULT} if( $params->{_DEFAULT} );
    $params->{type} = $this->{prefs}->getPreferencesValue( 'SEARCHVARDEFAULTTYPE' ) unless( $params->{type} );

    my $s = $this->{search}->searchWeb( %$params );
    return $s;
}

sub _WEBLIST {
    my $this = shift;
    return $this->_webOrTopicList( 1, @_ );
}

sub _TOPICLIST {
    my $this = shift;
    return $this->_webOrTopicList( 0, @_ );
}

sub _URLPARAM {
    my( $this, $params ) = @_;
    my $param     = $params->{_DEFAULT} || '';
    my $newLine   = $params->{newline} || '';
    my $encode    = $params->{encode};
    my $multiple  = $params->{multiple};
    my $separator = $params->{separator} || "\n";

    my $value = '';
    if( $this->{cgiQuery} ) {
        if( $multiple ) {
            my @valueArray = $this->{cgiQuery}->param( $param );
            if( @valueArray ) {
                unless( $multiple =~ m/^on$/i ) {
                    my $item = '';
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
            $value = '' unless( defined $value );
        }
    }
    $value =~ s/\r?\n/$newLine/go if( $newLine );
    if ( $encode ) {
        if ( $encode =~ /^entit(y|ies)$/ ) {
        	$value = entityEncode( $value );
    	} else {
        	$value = urlEncode( $value );
    	}
    }
    unless( $value ) {
        $value = $params->{default} || '';
    }
    return $value;
}

# This routine was introduced to URL encode Mozilla UTF-8 POST URLs in the
# TWiki Feb2003 release - encoding is no longer needed since UTF-URLs are now
# directly supported, but it is provided for backward compatibility with
# skins that may still be using the deprecated %INTURLENCODE%.
sub _INTURLENCODE {
    my( $this, $params ) = @_;
    # Just strip double quotes, no URL encoding - Mozilla UTF-8 URLs
    # directly supported now
    return $params->{_DEFAULT} || '';
}

sub _SPACEDTOPIC {
    my ( $this, $params, $theTopic ) = @_;
    return urlEncode( searchableTopic( $theTopic ));
}

sub _ICON {
    my( $this, $params ) = @_;
    my $file = $params->{_DEFAULT};

    $file = '' unless $file;

    my $value = $this->{renderer}->filenameToIcon( 'file.'.$file );
    return $value;
}

sub _RELATIVETOPICPATH {
    my ( $this, $params, $theTopic, $web ) = @_;
    my $topic = $params->{_DEFAULT} || '';

    return '' unless $topic;

    my $theRelativePath;
    # if there is no dot in $topic, no web has been specified
    if ( index( $topic, '.' ) == -1 ) {
        # add local web
        $theRelativePath = $web . '/' . $topic;
    } else {
        $theRelativePath = $topic; #including dot
    }
    # replace dot by slash is not necessary; TWiki.MyTopic is a valid url
    # add ../ if not already present to make a relative file reference
    if ( $theRelativePath !~ m!^../! ) {
        $theRelativePath = "../$theRelativePath";
    }
    return $theRelativePath;
}

sub _ATTACHURLPATH {
    my ( $this, $params, $theTopic, $theWeb ) = @_;
    return nativeUrlEncode( "$TWiki::cfg{PubUrlPath}/$theWeb/$theTopic" );
}

sub _SCRIPTNAME {
    #my ( $this, $params, $theTopic, $theWeb ) = @_;
    my $value = $ENV{SCRIPT_URL};
    if( $value ) {
        # e.g. '/cgi-bin/view.cgi/TWiki/WebHome'
        $value =~ s|^$TWiki::cfg{DispScriptUrlPath}/?||o;  # cut URL path to get 'view.cgi/TWiki/WebHome'
        $value =~ s|/.*$||;                    # cut extended path to get 'view.cgi'
        return $value;
    }
    # no SCRIPT_URL, try SCRIPT_FILENAME
    $value = $ENV{SCRIPT_FILENAME};
    if( $value ) {
        $value =~ s!.*/([^/]+)$!$1!o;
        return $value;
    }
    # no joy
    return '';
}

1;
