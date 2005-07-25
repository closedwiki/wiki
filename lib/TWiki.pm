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

require 5.005;        # For regex objects and internationalisation

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
            $VERSION
            $TRUE
            $FALSE
           );

# Token character that must not occur in any normal text - converted
# to a flag character if it ever does occur (very unlikely)
$TranslationToken= "\0";    # Null not allowed in charsets used with TWiki

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

BEGIN {

    use TWiki::Sandbox;   # system command sandbox

    $TRUE = 1;
    $FALSE = 0;

    if( DEBUG ) {
        # If ASSERTs are on, then warnings are errors. Paranoid,
        # but the only way to be sure we eliminate them all.
        # Look out also for $cfg{WarningsAreErrors}, below, which
        # is another way to install this handler without enabling
        # ASSERTs
        $SIG{'__WARN__'} = sub { die @_ };
    }

    # DO NOT CHANGE THE FORMAT OF $VERSION without updating tools/distro/build-twiki-kernel.pl !!!
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
                     ICONPATH          => \&_ICONPATH,
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
                     SPACEDTOPIC       => \&_SPACEDTOPIC, # deprecated, use SPACEOUT
                     SPACEOUT           => \&_SPACEOUT,
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

    # Validate and untaint Apache's SERVER_NAME Environment variable
    # for use in referencing virtualhost-based paths for separate data/ and templates/ instances, etc
    if ( $ENV{SERVER_NAME} &&
         $ENV{SERVER_NAME} =~ /^(([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,6})$/ ) {
        $ENV{SERVER_NAME} =
          TWiki::Sandbox::untaintUnchecked( $ENV{SERVER_NAME} );
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

    if( $TWiki::cfg{WarningsAreErrors} ) {
        # Note: Warnings are always errors if ASSERTs are enabled
        $SIG{'__WARN__'} = sub { die @_ };
    }

    if( $TWiki::cfg{UseLocale} ) {
        require locale;
    }

    $TWiki::cfg{DispScriptUrlPath} = $TWiki::cfg{ScriptUrlPath}
      unless defined( $TWiki::cfg{DispScriptUrlPath} );

    # Constant tags dependent on the config
    $constantTags{HOMETOPIC}       = $TWiki::cfg{HomeTopicName};
    $constantTags{MAINWEB}         = $TWiki::cfg{UsersWebName};
    $constantTags{USERWEB}         = $TWiki::cfg{UsersWebName};
    $constantTags{TRASHWEB}        = $TWiki::cfg{TrashWebName};
    $constantTags{NOTIFYTOPIC}     = $TWiki::cfg{NotifyTopicName};
    $constantTags{PUBURLPATH}      = $TWiki::cfg{PubUrlPath};
    $constantTags{SCRIPTSUFFIX}    = $TWiki::cfg{ScriptSuffix};
    $constantTags{SCRIPTURLPATH}   = $TWiki::cfg{DispScriptUrlPath};
    $constantTags{STATISTICSTOPIC} = $TWiki::cfg{Stats}{TopicName};
    $constantTags{TWIKIWEB}        = $TWiki::cfg{SystemWebName};
    $constantTags{WEBPREFSTOPIC}   = $TWiki::cfg{WebPrefsTopicName};
    $constantTags{DEFAULTURLHOST}  = $TWiki::cfg{DefaultUrlHost};
    $constantTags{WIKIHOMEURL}     =
      $TWiki::cfg{DefaultUrlHost} .
        '/' . $TWiki::cfg{ScriptUrlPath} . '/view' .
          $TWiki::cfg{ScriptSuffix};
    $constantTags{WIKIPREFSTOPIC}  = $TWiki::cfg{SitePrefsTopicName};
    $constantTags{WIKIUSERSTOPIC}  = $TWiki::cfg{UsersTopicName};
    if( $TWiki::cfg{NoFollow} ) {
        $constantTags{NOFOLLOW} = 'rel='.$TWiki::cfg{NoFollow};
    }

    # locale setup
    #
    #
    # Note that 'use locale' must be done in BEGIN block for regexes and
    # sorting to
    # work properly, although regexes can still work without this in
    # 'non-locale regexes' mode.

    if ( $TWiki::cfg{UseLocale} ) {
        # Set environment variables for grep 
        $ENV{LC_CTYPE} = $TWiki::cfg{Site}{Locale};

        # Load POSIX for I18N support.
        require POSIX;
        import POSIX qw( locale_h LC_CTYPE );

        # SMELL: mod_perl compatibility note: If TWiki is running under Apache,
        # won't this play with the Apache process's locale settings too?
        # What effects would this have?
        setlocale(&LC_CTYPE, $TWiki::cfg{Site}{Locale});
    }

    $constantTags{CHARSET} = $TWiki::cfg{Site}{CharSet};
    $constantTags{SHORTLANG} = $Wiki::cfg{Site}{Lang};
    $constantTags{LANG} = $TWiki::cfg{Site}{FullLang};

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
         or not $TWiki::cfg{Site}{LocaleRegexes} ) {

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
    $regex{webNameBaseRegex} = qr/[$regex{upperAlpha}]+[$regex{mixedAlphaNum}_]*/o;
    $regex{webNameRegex} = qr/$regex{webNameBaseRegex}(?:(?:[\.\/]$regex{webNameBaseRegex})+)*/o;
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

    # %TAG% name
    $regex{tagNameRegex} = qr/[$regex{upperAlpha}][$regex{upperAlphaNum}_:]*/o;

    # Set statement in a topic
    $regex{bulletRegex} = qr/^(?:\t|   )+\*/;
    $regex{setRegex} = qr/$regex{bulletRegex}\s+Set\s+/o;
    # SMELL: this ought to use $regex{tagNameRegex}
    $regex{setVarRegex} = qr/$regex{setRegex}(\w+)\s*=\s*(.*)$/o;

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

    # Check for unsafe search regex mode (affects filtering in) - default
    # to safe mode
    $TWiki::cfg{ForceUnsafeRegexes} = 0 unless defined $TWiki::cfg{ForceUnsafeRegexes};

    # initialize lib directory early because of later 'cd's
    getTWikiLibDir();
};

use TWiki::Access;    # access control
use TWiki::Attach;    # file attachments
use TWiki::Attrs;     # tag attribute handling
use TWiki::Client;    # client session handling
use TWiki::Form;      # forms
use TWiki::Net;       # SMTP, get URL
use TWiki::Plugins;   # plugins handler
use TWiki::Prefs;     # preferences
use TWiki::Render;    # HTML generation
use TWiki::Search;    # search engine
use TWiki::Store;     # file I/O and rcs related functions
use TWiki::Templates; # TWiki template language
use TWiki::Time;      # date/time conversions
use TWiki::Users;     # user handler

=pod

---++ ObjectMethod UTF82SiteCharSet( $utf8 ) -> $ascii
Auto-detect UTF-8 vs. site charset in string, and convert UTF-8 into site
charset.

=cut

sub UTF82SiteCharSet {
    my( $this, $text ) = @_;

    # Detect character encoding of the full topic name from URL
    return undef if( $text =~ $regex{validAsciiStringRegex} );

    # If not UTF-8 - assume in site character set, no conversion required
    return undef unless( $text =~ $regex{validUtf8StringRegex} );

    # Convert into ISO-8859-1 if it is the site charset
    if ( $TWiki::cfg{Site}{CharSet} =~ /^iso-?8859-?1$/i ) {
        # ISO-8859-1 maps onto first 256 codepoints of Unicode
        # (conversion from 'perldoc perluniintro')
        $text =~ s/ ([\xC2\xC3]) ([\x80-\xBF]) / 
          chr( ord($1) << 6 & 0xC0 | ord($2) & 0x3F )
            /egx;
    } elsif ( $TWiki::cfg{Site}{CharSet} eq 'utf-8' ) {
        # Convert into internal Unicode characters if on Perl 5.8 or higher.
        if( $] >= 5.008 ) {
            require Encode;            # Perl 5.8 or higher only
            # 'decode' into UTF-8
            $text = Encode::decode('utf8', $text);
        } else {
            $this->writeWarning( 'UTF-8 not supported on Perl '.$].
                                 ' - use Perl 5.8 or higher..' );
        }
        $this->writeWarning( 'UTF-8 not yet supported as site charset -'.
                             'TWiki is likely to have problems' );
    } else {
        # Convert from UTF-8 into some other site charset
        if( $] >= 5.008 ) {
            require Encode;
            import Encode qw(:fallbacks);
            # Map $TWiki::cfg{Site}{CharSet} into real encoding name
            my $charEncoding =
              Encode::resolve_alias( $TWiki::cfg{Site}{CharSet} );
            if( not $charEncoding ) {
                $this->writeWarning
                  ( 'Conversion to "'.$TWiki::cfg{Site}{CharSet}.
                    '" not supported, or name not recognised - check '.
                    '"perldoc Encode::Supported"' );
            } else {
                # Convert text using Encode:
                # - first, convert from UTF8 bytes into internal
                # (UTF-8) characters
                $text = Encode::decode('utf8', $text);    
                # - then convert into site charset from internal UTF-8,
                # inserting \x{NNNN} for characters that can't be converted
                $text =
                  Encode::encode( $charEncoding, $text,
                                  &FB_PERLQQ() );
            }
        } else {
            require Unicode::MapUTF8;    # Pre-5.8 Perl versions
            my $charEncoding = $TWiki::cfg{Site}{CharSet};
            if( not Unicode::MapUTF8::utf8_supported_charset($charEncoding) ) {
                $this->writeWarning
                  ( 'Conversion to "'.$TWiki::cfg{Site}{CharSet}.
                    '" not supported, or name not recognised - check '.
                    '"perldoc Unicode::MapUTF8"' );
            } else {
                # Convert text
                $text =
                  Unicode::MapUTF8::from_utf8({
                                               -string => $text,
                                               -charset => $charEncoding
                                              });
                # FIXME: Check for failed conversion?
            }
        }
    }
    return $text;
}

=pod

---++ ObjectMethod writeCompletePage( $text )

Write a complete HTML page with basic header to the browser.
$text is the HTML of the page body (&lt;html&gt; to &lt;/html&gt;)

This method removes noautolink and no tags before outputting the page.

=cut

sub writeCompletePage {
    my ( $this, $text, $pageType, $contentType ) = @_;

    ASSERT($this->isa( 'TWiki')) if DEBUG;

    if( ($contentType||'') ne 'text/plain' ) {
        # Remove <nop> and <noautolink> tags
        $text =~ s/([\t ]?)[ \t]*<\/?(nop|noautolink)\/?>/$1/gis;
        $text .= "\n" unless $text =~ /\n$/s;
        spamProof( $text );
    }

    # can't use simple length() in case we have UNICODE
    # see perldoc -f length
    my $len = do { use bytes; length( $text ); };
    $this->writePageHeader( undef, $pageType, $contentType, $len );
    my $htmlHeader = join(
        "\n",
        map { '<!--'.$_.'-->'.$this->{htmlHeaders}{$_} }
          keys %{$this->{htmlHeaders}} );
    $text =~ s/([<]\/head[>])/$htmlHeader$1/i if $htmlHeader;
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

    ASSERT($this->isa( 'TWiki')) if DEBUG;

    $query = $this->{cgiQuery} unless $query;

    # Handle Edit pages - future versions will extend to caching
    # of other types of page, with expiry time driven by page type.
    my( $pluginHeaders, $coreHeaders );

    my $hopts = {};

    # Add a content-length if one has been provided. HTTP1.1 says a
    # content-length should _not_ be specified unless the length is
    # known. There is a bug in Netscape such that it interprets a
    # 0 content-length as "download until disconnect" but that is
    # a bug. The correct way is to not set a content-length.
    $hopts->{'Content-Length'} = $contentLength if $contentLength;

    if ($pageType && $pageType eq 'edit') {
        # Get time now in HTTP header format
        my $lastModifiedString =
          TWiki::Time::formatTime(time, '$http', 'gmtime');

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
        $hopts->{'last-modified'} = $lastModifiedString;
        $hopts->{expires} = "+${expireHours}h";
        $hopts->{'cache-control'} = "max-age=$expireSeconds";
    }

    # DEPRECATED plugins header handler. Plugins should use
    # modifyHeaderHandler instead.
    $pluginHeaders = $this->{plugins}->writeHeaderHandler( $query ) || '';
    if( $pluginHeaders ) {
        foreach ( split /\r\n/, $pluginHeaders ) {
            if ( m/^([\-a-z]+): (.*)$/i ) {
                $hopts->{$1} = $2;
            }
        }
    }

    $contentType = 'text/html' unless $contentType;
    if(defined($TWiki::cfg{Site}{CharSet})) {
      $contentType .= '; charset='.$TWiki::cfg{Site}{CharSet};
    }

    # use our version of the content type
    $hopts->{'Content-Type'} = $contentType;

    # New (since 1.026)
    $this->{plugins}->modifyHeaderHandler( $hopts );

    # add cookie(s)
    $this->{client}->modifyHeader( $hopts );

    my $hdr = CGI::header( $hopts );

    print $hdr;
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

    ASSERT($this->isa( 'TWiki')) if DEBUG;

    my $query = $this->{cgiQuery};

    unless( $this->{plugins}->redirectCgiQueryHandler( $query, $url ) ) {
        if ( $query && $query->param( 'noredirect' )) {
            my $content = join(' ', @_) . " \n";
            $this->writeCompletePage( $query, $content );
        } elsif ( $this->{client}->redirectCgiQuery( $query, $url ) ) {
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

    ASSERT($this->isa( 'TWiki')) if DEBUG;

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

---++ ObjectMethod getSkin () -> $string

Get the currently requested skin path

=cut

sub getSkin {
    my $this = shift;

    ASSERT($this->isa( 'TWiki')) if DEBUG;

    my $skinpath = $this->{prefs}->getPreferencesValue( 'SKIN' ) || '';
    if( $this->{cgiQuery} ) {
        # Replace existing skin path
        my $resurface = $this->{cgiQuery}->param( 'skin' );
        $skinpath = $resurface if $resurface;
        # add to skin path
        my $epidermis = $this->{cgiQuery}->param( 'cover' );
        $skinpath = $epidermis.','.$skinpath if $epidermis;
    }
    return $skinpath;
}

=pod

---++ ObjectMethod getScriptUrl( $web, $topic, $script, ... ) -> $absoluteScriptURL

Returns the absolute URL to a TWiki script, providing the web and topic as
"path info" parameters.  The result looks something like this:
"http://host/twiki/bin/$script/$web/$topic".
   * =...= - an arbitrary number of name,value parameter pairs that will be url-encoded and added to the url. The special parameter name '#' is reserved for specifying an anchor. e.g. <tt>getScriptUrl('x','y','view','#'=>'XXX',a=>1,b=>2)</tt> will give <tt>.../view/x/y#XXX?a=1&b=2</tt>

=cut

sub getScriptUrl {
    my( $this, $theWeb, $theTopic, $theScript, @params ) = @_;

    ASSERT($this->isa( 'TWiki')) if DEBUG;

    ( $theWeb, $theTopic ) =
      $this->normalizeWebTopicName( $theWeb, $theTopic );
    $theWeb ||= '';

    # SMELL: topics and webs that contain spaces?

    # $this->{urlHost} is needed, see Codev.PageRedirectionNotWorking
    my $url = $this->{urlHost};
    $url .= $TWiki::cfg{DispScriptUrlPath} . "/$theScript";
    $url .= $TWiki::cfg{ScriptSuffix};
    $url .= "/$theWeb/$theTopic";

    my $ps = '';
    while( my $p = shift @params ) {
        if( $p eq '#' ) {
            $url .= '#' . shift( @params );
        } else {
            $ps .= ';' . $p.'='.urlEncode( shift( @params ));
        }
    }
    if( $ps ) {
        $ps =~ s/^;/?/;
        $url .= $ps;
    }

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

    return $this->getScriptUrl( $web, $topic, $script, t => time() );
}

=pod

---++ ObjectMethod getOopsUrl( $template, @options ) -> $absoluteOopsURL

Composes a URL for an "oops" error page. The @options consists of a list
of key => value pairs. The following keys are used:
   * =-web= - web name
   * =-topic= - topic name
   * =-def= - optional template def within the main template file
   * =-params= - a single parameter, or a reference to an array of parameters  These are passed in the URL as '&param1=' etc.

Do _not_ include the "oops" part in front of the template name.

Alternatively you can pass a reference to an OopsException in place of the template. All other parameters will be ignored.

The returned URL ends up looking something like this:
"http://host/twiki/bin/oops/$web/$topic?template=$template&param1=$scriptParams[0]..."

=cut

sub getOopsUrl {
    my $this = shift;
    my $template = shift;
    my $params;

    if( $template->isa('TWiki::OopsException') ) {
        $params = $template;
        $template = $params->{template};
    } else {
        $params = { @_ };
    }
    my $web = $params->{web} || $this->{webName};
    my $topic = $params->{topic} || $this->{topicName};
    my $def = $params->{def};
    my $PARAMS = $params->{params};

    ASSERT($this->isa( 'TWiki')) if DEBUG;

    my @urlParams = ( template => 'oops'.$template );

    push( @urlParams, def => $def ) if $def;

    if( ref($PARAMS) eq "ARRAY" ) {
        my $n = 1;
        my $p;
        while( $p = shift @$PARAMS ) {
            push( @urlParams, "param$n" => $p );
            $n++;
        }
    } elsif( defined $PARAMS ) {
        push( @urlParams, param1=> $PARAMS );
    }

    return $this->getScriptUrl( $web, $topic, 'oops', @urlParams );
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

    ASSERT($this->isa( 'TWiki')) if DEBUG;
    ASSERT(defined $theTopic) if DEBUG;

    if( $theTopic =~ m|^([^.]+)[\.\/](.*)$| ) {
        $theWeb = $1;
        $theTopic = $2;
    }
    my( $web, $topic ) = ( $theWeb, $theTopic );
    $web ||= $cfg{UsersWebName};
    $topic ||= $cfg{HomeTopicName};
    $web =~ s/^%((MAIN|TWIKI)WEB)%$/$this->_expandTag( $1 )/e;
    $web =~ s#\.#/#go;
    return( $web, $topic );
}

=pod

---++ ClassMethod new( $remoteUser, $query )
Constructs a new TWiki object. Parameters are taken from the query object.

   * =$remoteUser= the logged-in user (login name)
   * =$query= the query

=cut

sub new {
    my( $class, $remoteUser, $query, $d ) = @_;
    ASSERT(!defined($d)) if DEBUG; # upgrade check
    $query ||= new CGI( {} );
    $remoteUser ||= $query->remote_user() || $TWiki::cfg{DefaultUserLogin};

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
    $this->{client} = TWiki::Client::makeClient( $this );
    # cache CGI information in the session object
    $this->{cgiQuery} = $query;
    $this->{remoteUser} = $remoteUser;

    $this->{htmlHeaders} = {};

    $this->{context} = {};

    $this->{users} = new TWiki::Users( $this );

    # Make %ENV safer, preventing hijack of the search path
    # SMELL: can this be done in a BEGIN block? Or is the environment
    # set per-query?
    if( $TWiki::cfg{SafeEnvPath} ) {
        $ENV{'PATH'} = $TWiki::cfg{SafeEnvPath};
    }
    delete @ENV{ qw( IFS CDPATH ENV BASH_ENV ) };

    $this->{security} = new TWiki::Access( $this );

    my $web = '';
    my $topic = $query->param( 'topic' );
    if( $topic ) {
        if( $topic =~ /^$regex{linkProtocolPattern}\:\/\//o &&
            $this->{cgiQuery} ) {
            # redirect to URI
            print $this->redirect( $topic );
            return;
        } elsif( $topic =~ /((?:.*[\.\/])+)(.*)/ ) {
            # is 'bin/script?topic=Webname.SomeTopic'
            $web   = $1;
            $topic = $2;
            $web =~ s/\./\//go;
            $web =~ s/\/$//o;
            # jump to WebHome if 'bin/script?topic=Webname.'
            $topic = $TWiki::cfg{HomeTopicName} if( $web && ! $topic );
        }
        # otherwise assume 'bin/script/Webname?topic=SomeTopic'
    } else {
        $topic = '';
    }

    # SMELL: "The Microsoft Internet Information Server is broken with
    # respect to additional path information. If you use the Perl DLL
    # library, the IIS server will attempt to execute the additional
    # path information as a Perl script. If you use the ordinary file
    # associations mapping, the path information will be present in the
    # environment, but incorrect. The best thing to do is to avoid using
    # additional path information."

    # Clean up PATH_INFO problems, e.g.  Support.CobaltRaqInstall.  A valid
    # PATH_INFO is '/Main/WebHome', i.e. the text after the script name;
    # invalid PATH_INFO is often a full path starting with '/cgi-bin/...'.
    my $pathInfo = $query->path_info();
    my $cgiScriptName = $ENV{'SCRIPT_NAME'} || '';
    $pathInfo =~ s!$cgiScriptName/!/!i;

    # Get the web and topic names from PATH_INFO
    if( $pathInfo =~ /\/((?:.*[\.\/])+)(.*)/ ) {
        # is 'bin/script/Webname/SomeTopic' or 'bin/script/Webname/'
        $web   = $1 unless $web;
        $topic = $2 unless $topic;
        $web =~ s/\./\//go;
        $web =~ s/\/$//o;
    } elsif( $pathInfo =~ /\/(.*)/ ) {
        # is 'bin/script/Webname' or 'bin/script/'
        $web = $1 unless $web;
    }

    # Check to see if we just dissected a web path missing its WebHome
    if($topic ne "" && $this->{store}->webExists("$web/$topic")) {
        $web .= '/'.$topic;
        $topic = "";
    }
    # All roads lead to WebHome
    $topic = $TWiki::cfg{HomeTopicName} if ( $topic =~ /\.\./ );
    $topic =~ s/$TWiki::cfg{NameFilter}//go;
    $topic = $TWiki::cfg{HomeTopicName} unless $topic;
    $this->{topicName} = TWiki::Sandbox::untaintUnchecked( $topic );

    $web   =~ s/$TWiki::cfg{NameFilter}//go;
    $web = $TWiki::cfg{UsersWebName} unless $web;
    $this->{webName} = TWiki::Sandbox::untaintUnchecked( $web );

    # Convert UTF-8 web and topic name from URL into site charset
    # if necessary - no effect if URL is not in UTF-8
    my $newt = $this->UTF82SiteCharSet( $this->{webName}.'.'.
                                        $this->{topicName} );
    if( $newt ) {
        $newt =~ /^(.*?)\.([^.]*)$/;
        $this->{webName} = $1;
        $this->{topicName} = $2;
    }

    $this->{scriptUrlPath} = $TWiki::cfg{ScriptUrlPath};

    my $url = $query->url();
    if( $url && $url =~ m!^([^:]*://[^/]*)(.*)/.*$! && $2 ) {
        $this->{urlHost} = $1;
        # If the urlHost in the url is localhost, this is a lot less
        # useful than the default url host. This is because new CGI("")
        # assigns this host by default - it's a default setting, used
        # when there is nothing better available.
        if( $this->{urlHost} eq 'http://localhost' ) {
            $this->{urlHost} = $TWiki::cfg{DefaultUrlHost};
        } elsif( $TWiki::cfg{RemovePortNumber} ) {
            $this->{urlHost} =~ s/\:[0-9]+$//;
        }
        if( $TWiki::cfg{GetScriptUrlFromCgi} ) {
            # SMELL: this is a really dangerous hack. It will fail
            # spectacularly with mod_perl.
            # SMELL: why not just use $query->script_name?
            $this->{scriptUrlPath} = $2;
        }
    } else {
        $this->{urlHost} = $TWiki::cfg{DefaultUrlHost};
    }

    # setup the cgi session, from a cookie or the url. this may return
    # the login, but even if it does, plugins will get the chance to override
    # it below.
    my $login = $this->{client}->load();

    # initialize preferences, first part for site and web level
    $this->{prefs} = new TWiki::Prefs( $this );

    # SMELL: there should be a way for the plugin to specify
    # the WikiName of the user as well as the login.
    $login = $this->{plugins}->load( $TWiki::cfg{DisableAllPlugins} ) || $login;
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

    $this->{prefs}->loadUserAndTopicPreferences(
        $this->{webName}, $this->{topicName}, $user );

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

---++ ObjectMethod finish
Complete processing after the client's HTTP request has been responded
to. Right now this only entails one activity: calling TWiki::Client to
flushing the user's
session (if any) to disk.

=cut

sub finish {
    my $this = shift;
    $this->{client}->finish();
}

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
    ASSERT($this->isa( 'TWiki')) if DEBUG;
    my $action = shift || '';
    my $webTopic = shift || '';
    my $extra = shift || '';
    my $user = shift;

    $user = $this->{user} unless $user;
    if( ref($user) && $user->isa('TWiki::User')) {
        $user = $user->wikiName();
    }

    if ($user eq 'TWikiGuest') {
       my $cgiQuery = $this->{cgiQuery};
       if( $cgiQuery ) {
           my $agent = $cgiQuery->user_agent();
           if( $agent ) {
               $agent =~ m/([\w]+)/;
               $extra .= ' '.$1;
           }
       }
    }

    my $remoteAddr = $ENV{'REMOTE_ADDR'} || '';
    my $text = "$user | $action | $webTopic | $extra | $remoteAddr |";

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
    ASSERT($this->isa( 'TWiki')) if DEBUG;
    $this->_writeReport( $TWiki::cfg{WarningFileName}, @_ );
}

=pod

---++ ObjectMethod writeDebug( $text )

Prints date, time, and contents of $text to $TWiki::cfg{DebugFileName}, typically
'debug.txt'.  Use for debugging messages.

=cut

sub writeDebug {
    my $this = shift;
    ASSERT($this->isa( 'TWiki')) if DEBUG;
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
          TWiki::Time::formatTime( time(), '$year$mo', 'servertime');
        $log =~ s/%DATE%/$time/go;
        $time = TWiki::Time::formatTime( time(), undef, 'servertime' );

        if( open( FILE, ">>$log" ) ) {
            print FILE "| $time | $message\n";
            close( FILE );
        } else {
            print STDERR 'Could not write "'.$message.'" to '."$log: $!\n";
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
    my( $theHost, $theAbsPath, $url ) = @_;

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
        my $attname = $3;
        # FIXME: Check for MIME type, not file suffix
        if( $attname =~ m/\.(txt|html?)$/i ) {
            unless( $this->{store}->attachmentExists( $web, $topic,
                                                      $attname )) {
                return $this->inlineAlert( 'alerts', 'no_such_attachment',
                                           $theUrl );
            }
            if( $web ne $theWeb || $topic ne $theTopic ) {
                # CODE_SMELL: Does not account for not yet authenticated user
                unless( $this->{security}->checkAccessPermission(
                    'view', $this->{user}, '', $topic, $web ) ) {
                    return $this->inlineAlert( 'alerts', 'access_denied',
                                               $web, $topic );
                }
            }
            $text = $this->{store}->readAttachment( undef, $web, $topic,
                                                    $attname );
            $text = _cleanupIncludedHTML( $text, $this->{urlHost},
                                          $TWiki::cfg{PubUrlPath} );
            $text = applyPatternToIncludedText( $text, $thePattern )
              if( $thePattern );
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
        $text = $this->inlineAlert( 'alerts', 'bad_protocol', $theUrl );
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
        $host = 'http://'.$host;   # build host for absolute address
        if( $port != 80 ) {
            $host .= ":$port";
        }
        $text = _cleanupIncludedHTML( $text, $host, $path );

    } elsif( $contentType =~ /^text\/(plain|css)/ ) {
        # do nothing

    } else {
        $text = $this->inlineAlert( 'alerts', 'bad_content', $contentType );
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
    $title = CGI::span( { class => 'twikiTocTitle' }, $title ) if( $title );

    if( $web ne $defaultWeb || $topic ne $defaultTopic ) {
        unless( $this->{security}->checkAccessPermission
                ( 'view', $this->{user}, '', $topic, $web ) ) {
            return $this->inlineAlert( 'alerts', 'access_denied',
                                       $web, $topic );
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
    # SMELL: use forEachLine
    foreach my $line ( split( /\r?\n/, $text ) ) {
        if( $line =~ /^.*<pre\b/io ) {
            $insidePre++;
            next;
        }
        if( $line =~ /^.*<\/pre>/io ) {
            $insidePre--;
            next;
        }
        if( $line =~ /^<verbatim\b/io ) {
            $insideVerbatim++;
            next;
        }
        if( $line =~ /^<\/verbatim>$/io ) {
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
        # Prevent manual links
        $line =~ s/<[\/]?a\b[^>]*>//gi;   
            # create linked bullet item, using a relative link to anchor
            $line = $tabs.'* '.
              CGI::a( { href=>$urlPath.'#'.$anchor }, $line );
            $result .= "\n".$line;
        }
    }
    if( $result ) {
        if( $highest > 1 ) {
            # left shift TOC
            $highest--;
            $result =~ s/^\t{$highest}//gm;
        }
        return CGI::div( { class=>'twikiToc' }, "$title$result\n" );
    } else {
        return '';
    }
}

=pod

---++ ObjectMethod inlineAlert($template, $def, ... ) -> $string
Format an error for inline inclusion in rendered output. The message string
is obtained from the template 'oops'.$template, and the DEF $def is
selected. The parameters (...) are used to populate %PARAM1%..%PARAMn%

=cut

sub inlineAlert {
    my $this = shift;
    my $template = shift;
    my $def = shift;

    my $text = $this->{templates}->readTemplate( 'oops'.$template,
                                                 $this->getSkin() );
    if( $text ) {
        my $blah = $this->{templates}->expandTemplate( $def );
        $text =~ s/%INSTANTIATE%/$blah/;
        # web and topic can be anything; they are not used
        $text = $this->handleCommonTags( $text, $this->{webName},
                                         $this->{topicName} );
        my $n = 1;
        while( defined( my $param = shift )) {
            $text =~ s/%PARAM$n%/$param/g;
            $n++;
        }

    } else {
        $text = CGI::h1('TWiki Installation Error')
          . 'Template file '.$template.'.tmpl not found or template directory '
            . $TWiki::cfg{TemplateDir}.' not found.'.CGI::p()
              . 'Check the configuration setting for TemplateDir.';
    }

    return $text;
}

=pod

---++ ObjectMethod expandVariablesOnTopicCreation ( $text, $user ) -> $text
   * =$text= - text to expand
   * =$user= - reference to user object. This is the user expanded in e.g. %USERNAME. Optional, defaults to logged-in user.
Expand limited set of variables during topic creation. These are variables
expected in templates that must be statically expanded in new content.

The expanded variables are:
| =%<nop>DATE%= | Signature-format date |
| =%<nop>SERVERTIME%= | Server time |
| =%<nop>GMTIME%= | GM time |
| =%<nop>USERNAME%= | Base login name |
| =%<nop>WIKINAME%= | Wiki name |
| =%<nop>WIKIUSERNAME%= | Wiki name with prepended web |
| =%<nop>URLPARAM%= | Parameters to the current CGI query |
| =%<nop>NOP%= | No-op |

=cut

sub expandVariablesOnTopicCreation {
    my ( $this, $text, $user ) = @_;

    ASSERT($this->isa( 'TWiki')) if DEBUG;
    $user ||= $this->{user};
    ASSERT($user->isa( 'TWiki::User')) if DEBUG;

    # Must do URLPARAM first
    $text =~ s(%URLPARAM{(.*?)}%)
      ($this->_URLPARAM(new TWiki::Attrs($1)))ge;

    $text =~ s(%DATE%)
      ($this->_DATE())ge;
    $text =~ s(%SERVERTIME(?:{(.*?)})?%)
      ($this->_SERVERTIME(new TWiki::Attrs($1)))ge;
    $text =~ s(%GMTIME(?:{(.*?)})?%)
      ($this->_GMTIME(new TWiki::Attrs($1)))ge;

    $text =~ s/%USERNAME%/$user->login()/ge;
    $text =~ s/%WIKINAME%/$user->wikiName()/ge;
    $text =~ s/%WIKIUSERNAME%/$user->webDotWikiName()/ge;

    # Remove template-only text and variable protection markers. These
    # are normally expanded to their content during topic display, but
    # are filtered out during template topic instantiation. They are typically
    # used for establishing topic protections over the template topics that
    # are not inherited by the instantiated topic.
    # See TWiki.TWikiTemplates for details.
    $text =~ s/%NOP{.*?}%//gs;
    $text =~ s/%NOP%//g;
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
    $web =~ s#\.#/#go;

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
        $line =~ s/\$web\b/$web/goi;
        $line =~ s/\$name\b/$item/goi;
    if($isWeb) {
      my $webindent=$item;
      $webindent=~s/\/$//go;
      $webindent =~ s/\w+\//\&nbsp;\&nbsp;/go;
      $webindent =~ s/[A-Z]+.*//go;
      my $indenteditem=$item;
      $indenteditem=~s/\/$//go;
      $indenteditem =~ s/\w+\///go;
      $line =~ s/\$webindent/$webindent/goi;
      $line =~ s/\$indentedname/$indenteditem/goi;
    }
        $line =~ s/\$qname/"$item"/goi;
        $mark = ( $selection =~ / \Q$item\E / ) ? $marker : '';
        $line =~ s/\$marker/$mark/goi;
        $text .= $line.$separator;
    }
    $text =~ s/$separator$//s;  # remove last separator
    return $text;
}

=pod

---++ StaticMethod entityEncode( $text ) -> $encodedText

Escape characters to HTML entities. Should handle unicode
characters.

HTML4.0 spec:
"Certain characters in HTML are reserved for use as markup and must be
escaped to appear literally. The "&lt;" character may be represented with
an <em>entity</em>, <strong class=html>&amp;lt;</strong>. Similarly, "&gt;"
is escaped as <strong class=html>&amp;gt;</strong>, and "&amp;" is escaped
as <strong class=html>&amp;amp;</strong>. If an attribute value contains a
double quotation mark and is delimited by double quotation marks, then the
quote should be escaped as <strong class=html>&amp;quot;</strong>.</p>

Other entities exist for special characters that cannot easily be entered
with some keyboards...

This method encodes &lt;, &gt;, &amp;, &quot; and any 8-bit characters
using numeric entities.

=cut

sub entityEncode {
    my $text = shift;

    $text =~ s/([^ -~\n\r]|["<>&])/'&#'.ord( $1 ).';'/ge;
    return $text;
}

=pod

---++ StaticMethod entityDecode ( $encodedText ) -> $text

Revrses the encoding from =entityEncode=. _Does not_ decode
named entities such as &amp;

=cut

sub entityDecode {
    my $text = shift;

    $text =~ s/&#(\d+);/chr($1)/ge;
    return $text;
}

=pod

---++ StaticMethod urlEncode( $string ) -> encoded string

Encode by converting characters that are illegal in URLs to
their %NN equivalents. This method is used for encoding
strings that must be embedded _verbatim_ in URLs; it cannot
be applied to URLs themselves, as it escapes reserved
characters such as = and ?.

RFC 1738, Dec. '94:
<verbatim>>
...Only alphanumerics [0-9a-zA-Z], the special
characters $-_.+!*'(), and reserved characters used for their
reserved purposes may be used unencoded within a URL.
</verbatim>
Reserved characters are $&+,/:;=?@ - these are _also_ encoded by
this method.

SMELL: For non-ISO-8859-1 $TWiki::cfg{Site}{CharSet}, need to convert to
UTF-8 before URL encoding. This encoding only supports 8-bit
character codes.

=cut

sub urlEncode {
    my $text = shift;

    $text =~ s/([^0-9a-zA-Z-_.!*'()\/%])/'%'.sprintf('%02x',ord($1))/ge;

    return $text;
}

=pod

---++ StaticMethod urlDecode( $string ) -> decoded string

Reverses the encoding done in urlEncode.

=cut

sub urlDecode {
    my $text = shift;

    $text =~ s/%([\da-f]{2})/chr(hex($1))/gei;

    return $text;
}

=pod

---++ StaticMethod nativeUrlEncode ( $theStr, $doExtract ) -> encoded string

Perform URL encoding into native charset ($TWiki::cfg{Site}{CharSet}) - for use when
viewing attachments via browsers that generate UTF-8 URLs, on sites running
with non-UTF-8 (Native) character sets.  Aim is to prevent UTF-8 URL
encoding.  For mainframes, we assume that UTF-8 URLs will be translated
by the web server to an EBCDIC character set.

THIS METHOD SHOULD ONLY BE USED IF YOU ABSOLUTELY UNDERSTAND IT. It is
most likely you were looking for =urlEncode=.

=cut

sub nativeUrlEncode {
    my $theStr = shift;

    my $isEbcdic = ( 'A' eq chr(193) );     # True if Perl is using EBCDIC

    if( $TWiki::cfg{Site}{CharSet} eq 'utf-8' or $isEbcdic ) {
        # SMELL: does this really work? What if non RFC-1738 characters
        # are in the string?

        # Just strip double quotes, no URL encoding - let browser encode to
        # UTF-8 or EBCDIC based $TWiki::cfg{Site}{CharSet} as appropriate
        $theStr =~ s/^"(.*)"$/$1/;    
        return $theStr;
    } else {
        return urlEncode( $theStr );
    }
}

=pod

---++ StaticMethod isTrue( $value, $default ) -> $boolean

Returns 1 if =$value= is true, and 0 otherwise. "true" means set to
something with a Perl true value, with the special cases that "off",
"false" and "no" (case insensitive) are forced to false. Leading and
trailing spaces in =$value= are ignored.

If the value is undef, then =$default= is returned. If =$default= is
not specified it is taken as 0.

=cut

sub isTrue {
    my( $value, $default ) = @_;

    $default ||= 0;

    return $default unless defined( $value );

    $value =~ s/^\s*(.*?)\s*$/$1/gi;
    $value =~ s/off//gi;
    $value =~ s/no//gi;
    return ( $value ) ? 1 : 0;
}

=pod

---++ StaticMethod spaceOutWikiWord( $word, $sep ) -> $string

Spaces out a wiki word by inserting a string (default: one space) between each word component.
With parameter 'sep' any string may be used as separator between the word components; if 'sep' is undefined it defaults to a space.

=cut

sub spaceOutWikiWord {
    my $word = shift;
    my $sep = shift || ' ';
    $word =~ s/([$regex{lowerAlpha}])([$regex{upperAlpha}$regex{numeric}]+)/$1$sep$2/go;
    $word =~ s/([$regex{numeric}])([$regex{upperAlpha}])/$1$sep$2/go;
    return $word;
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
    $web =~ s#\.#/#go;

    # push current context
    my $memTopic = $this->{SESSION_TAGS}{TOPIC};
    my $memWeb   = $this->{SESSION_TAGS}{WEB};
    my $memEurl  = $this->{SESSION_TAGS}{EDITURL};

    $this->{SESSION_TAGS}{TOPIC}   = $topic;
    $this->{SESSION_TAGS}{WEB}     = $web;
    $this->{SESSION_TAGS}{EDITURL} =
      $this->getUniqueScriptUrl( $web, $topic, 'edit' );

    # Escape ' !%VARIABLE%'
    $$text =~ s/(?<=\s)!%($regex{tagNameRegex})/&#37;$1/g;

    # SMELL: why is this done every time, and not statically during
    # template loading?
    $$text =~ s/%NOP{(.*?)}%/$1/gs;  # remove NOP tag in template topics but show content
    $$text =~ s/%NOP%/<nop>/g;

    # SMELL: this is crap, a hack, and should go. It should be handled with
    # %TMPL:P{"sep"}% or a built-in.
    my $sep = $this->{templates}->expandTemplate('sep');
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
    }

    my @queue = split( /(%)/, $text );
    my @stack;
    my $stackTop = ''; # the top stack entry. Done this way instead of
    # referring to the top of the stack for efficiency. This var
    # should be considered to be $stack[$#stack]

    #my $tell = 0; # uncomment all tell lines set this to 1 to print debugging
    while ( scalar( @queue )) {
        my $token = shift( @queue );
        #print ' ' x $tell,"PROCESSING $token \n" if $tell;

        # each % sign either closes an existing stacked context, or
        # opens a new context.
        if ( $token eq '%' ) {
            #print ' ' x $tell,"CONSIDER $stackTop\n" if $tell;
            # If this is a closing }%, try to rejoin the previous
            # tokens until we get to a valid tag construct. This is
            # a bit of a hack, but it's hard to think of a better
            # way to do this without a full parse that takes % signs
            # in tag parameters into account.
            if ( $stackTop =~ /}$/ ) {
                while ( scalar( @stack) &&
                        $stackTop !~ /^%($regex{tagNameRegex}){.*}$/o ) {
                    my $top = $stackTop;
                    #print ' ' x $tell,"COLLAPSE $top \n" if $tell;
                    $stackTop = pop( @stack ) . $top;
                }
            }
            if ( $stackTop =~ m/^%($regex{tagNameRegex})(?:{(.*)})?$/o ) {
                my( $tag, $args ) = ( $1, $2 );
                #print ' ' x $tell,"POP $tag\n" if $tell;
                my $e;
                if ( defined( $this->{SESSION_TAGS}{$tag} )) {
                    $e = $this->{SESSION_TAGS}{$tag};
                } elsif ( defined( $constantTags{$tag} )) {
                    $e = $constantTags{$tag};
                } elsif ( defined( $functionTags{$tag} )) {
                    $e = &{$functionTags{$tag}}
                      ( $this, new TWiki::Attrs( $args ), @_ );
                }

                if ( defined( $e )) {
                    #print ' ' x $tell--,"EXPANDED $tag -> $e\n" if $tell;
                    $stackTop = pop( @stack );
                    # Choice: can either tokenise and push the expanded
                    # tag, or can recursively expand the tag. The
                    # behaviour is different in each case.
                    #unshift( @queue, split( /(%)/, $e ));
                    $stackTop .=
                      $this->_processTags($e, $depth-1, $expanding , @_ );
                } else { # expansion failed
                    #print ' ' x $tell++,"EXPAND $tag FAILED\n" if $tell;
                    push( @stack, $stackTop );
                    $stackTop = '%'; # push a new context
                }
            } else {
                push( @stack, $stackTop );
                $stackTop = '%'; # push a new context
                #$tell++ if ( $tell );
            }
        } else {
            $stackTop .= $token;
        }
    }

    # Run out of input. Gather up everything in the stack.
    while ( scalar( @stack )) {
        my $expr = $stackTop;
        $stackTop = pop( @stack );
        $stackTop .= $expr;
    }

    return $stackTop;
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

---++ ObjectMethod enterContext( $id, $val )

Add the context id $id into the set of active contexts. The $val
can be anything you like, but should always evaluate to boolean
TRUE.

An example of the use of contexts is in the use of tag
expansion. The commonTagsHandler in plugins is called every
time tags need to be expanded, and the context of that expansion
is signalled by the expanding module using a context id. So the
forms module adds the context id "form" before invoking common
tags expansion.

Contexts are not just useful for tag expansion; they are also
relevant when rendering.

Contexts are intended for use mainly by plugins. Core modules can
use $session->{context}->{$id} to determine if a context is active.

=cut

sub enterContext {
    my( $this, $id, $val ) = @_;
    $val ||= 1;
    $this->{context}->{$id} = $val;
}

=pod

---++ ObjectMethod leaveContext( $id )

Remove the context id $id from the set of active contexts.
(see =enterContext= for more information on contexts)

=cut

sub leaveContext {
    my( $this, $id ) = @_;
    my $res = $this->{context}->{$id};
    delete $this->{context}->{$id};
    return $res;
}

=pod

---++ StaticMethod registerTagHandler( $tag, $fnref )

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

    ASSERT($this->isa( 'TWiki')) if DEBUG;
    ASSERT($theWeb) if DEBUG;
    ASSERT($theTopic) if DEBUG;

    # Plugin Hook (for cache Plugins only)
    $this->{plugins}->beforeCommonTagsHandler( $text, $theTopic, $theWeb );

    my $verbatims = {};
    $text = $this->{renderer}->takeOutBlocks( $text, 'verbatim',
                                              $verbatims );

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

    $this->{renderer}->putBackBlocks( \$text, $verbatims, 'verbatim' );

    # TWiki Plugin Hook (for cache Plugins only)
    $this->{plugins}->afterCommonTagsHandler( $text, $theTopic, $theWeb );

    return $text;
}

=pod

---++ StaticMethod spamProof( $text ) -> $text

Find and replace all explicit links (&lt;a etc) in $text and apply anti spam measures
to them. This method is designed to be called on text just about to be printed to the
browser, and needs to be very fast.

Links to URLs that are escaped by $cfg{AntiSpam}{Clean} are left untouched. All
other links have $cfg{AntiSpam}{Options} added.

=cut

sub spamProof {
    return unless( defined( $TWiki::cfg{AntiSpam}{Options} ));
    $_[0] =~ s;<a(\s+[^>]*\bhref\s*=\s*['"](?!$TWiki::cfg{AntiSpam}{Clean}));<a $TWiki::cfg{AntiSpam}{Options}$1;gio;
}


=pod

---++ ObjectMethod addToHEAD( $id, $html )
Add =$html= to the HEAD tag of the page currently being generated.

Note that TWiki variables may be used in the HEAD. They will be expanded
according to normal variable expansion rules.

The 'id' is used to ensure that multiple adds of the same block of HTML don't
result in it being added many times.

=cut

sub addToHEAD {
	my ($this,$tag,$header) = @_;
    ASSERT($this->isa( 'TWiki')) if DEBUG;
	
	$header = $this->handleCommonTags( $header, $this->{webName},
                                       $this->{topicName} );
	
	$this->{htmlHeaders}{$tag} = $header;
}

=pod

---++ StaticMethod initialize( $pathInfo, $remoteUser, $topic, $url, $query ) -> ($topicName, $webName, $scriptUrlPath, $userName, $dataDir)

Return value: ( $topicName, $webName, $TWiki::cfg{ScriptUrlPath}, $userName, $TWiki::cfg{DataDir} )

Static method to construct a new singleton session instance.
It creates a new TWiki and sets the Plugins $SESSION variable to
point to it, so that TWiki::Func methods will work.

This method is *DEPRECATED* but is maintained for script compatibility.

Note that $theUrl, if specified, must be identical to $query->url()

=cut

sub initialize {
    my ( $pathInfo, $theRemoteUser, $topic, $theUrl, $query ) = @_;

    if( !$query ) {
        $query = new CGI( {} );
    }
    if( $query->path_info() ne $pathInfo ) {
        $query->path_info( $pathInfo );
    }
    if( $topic ) {
        $query->param( -name => 'topic', -value => '' );
    }
    # can't do much if $theUrl is specified and it is inconsistent with
    # the query. We are trying to get to all parameters passed in the
    # query.
    if( $theUrl && $theUrl ne $query->url()) {
        die 'Sorry, this version of TWiki does not support the url parameter to TWiki::initialize being different to the url in the query';
    }
    my $twiki = new TWiki( $theRemoteUser, $query );

    # Force the new session into the plugins context.
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
    return $this->{templates}->expandTemplate( $params );
}

sub _VAR {
    my( $this, $params, $topic, $inweb ) = @_;
    my $key = $params->{_DEFAULT};
    my $web = $params->{web} || $inweb;
    if( $web =~ m/%$regex{tagNameRegex}%/o ) { # handle %MAINWEB%-type cases 
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
    # Remove params, so they don't get expanded in the included page
    my $path = $params->remove('_DEFAULT') || '';
    my $pattern = $params->remove('pattern');
    my $rev = $params->remove('rev');
    my $warn = $params->remove('warn');

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
        # SMELL: this hack is a bit pointless, really.
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
    if ( $inctopic =~ /^($regex{webNameRegex})[\.\/]($regex{wikiWordRegex})$/o ) {
        $incweb = $1;
        $inctopic = $2;
    }

    # See Codev.FailedIncludeWarning for the history.
    unless( $this->{store}->topicExists($incweb, $inctopic)) {
        $warn ||= $this->{prefs}->getPreferencesValue( 'INCLUDEWARNING' );
        if( $warn eq 'on' ) {
            return $this->inlineAlert( 'alerts', 'no_such_topic', $inctopic );
        } elsif( $warn ne 'off' ) {
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
        $warn ||= $this->{prefs}->getPreferencesValue( 'INCLUDEWARNING' );
        if( $warn eq 'on' ) {
            my $more = '';
            if( $#{$this->{includeStack}} ) {
                $more .= join( '/', @{$this->{includeStack}} );
            }
            return $this->inlineAlert( 'alerts', 'already_included',
                                       $incweb, $inctopic, $more );
        } elsif( $warn ne 'off' ) {
            $inctopic =~ s/\//\./go;
            $warn =~ s/\$topic/$inctopic/go;
            return $warn;
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
    if( $text =~ s/.*?%STARTINCLUDE({([^}]*)})?%//s ) {
        if( $2 ) {
            # if STARTINCLUDE has a parameter, then evaluate it
            # to see if we should include this topic or not.
            my $attr = $2;
            $this->_expandAllTags( \$attr, $theTopic, $theWeb );
            $this->{plugins}->commonTagsHandler( $attr, $theTopic, $theWeb, 1 );
            $text = "" if( !$attr || $attr == 0 );
        }
    }
    $text =~ s/%STOPINCLUDE%.*//s;
    $text = applyPatternToIncludedText( $text, $pattern ) if( $pattern );

    # take out verbatims, pushing them into the same storage block
    # as the including topic so when we do the replacement at
    # the end they are all there
    $text = $this->{renderer}->takeOutBlocks( $text, 'verbatim',
                                              $this->{_verbatims} );

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

sub _DATE {
    my $this = shift;
    return TWiki::Time::formatTime(time(), '$day $mon $year', 'gmtime');
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

    return $this->{renderer}->renderRevisionInfo( $web, $topic, undef,
                                                  $rev, $format );
}

sub _ENCODE {
    my( $this, $params ) = @_;
    my $type = $params->{type};
    my $text = $params->{_DEFAULT} || '';
    if ( $type && $type =~ /^entit(y|ies)$/i ) {
        return entityEncode( $text );
    } else {
        $text =~ s/\r*\n\r*/<br \/>/; # Legacy.
        return urlEncode( $text );
    }
}

sub _SEARCH {
    my ( $this, $params, $theTopic, $theWeb ) = @_;
    # pass on all attrs, and add some more
    #$params->{_callback} = undef;
    $params->{inline} = 1;
    $params->{baseweb} = $theWeb;
    $params->{basetopic} = $theTopic;
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
        if( TWiki::isTrue( $multiple )) {
            my @valueArray = $this->{cgiQuery}->param( $param );
            if( @valueArray ) {
                # SMELL: this is pretty foul
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
            $value =~ s/\r*\n\r*/<br \/>/; # Legacy
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

# This routine is deprecated as of DakarRelease,
# and is maintained only for backward compatibility.
# Spacing of WikiWords is now done with %SPACEOUT%
# (and the private routine _SPACEOUT).
sub _SPACEDTOPIC {
    my ( $this, $params, $theTopic ) = @_;
    my $topic = spaceOutWikiWord( $theTopic );
    $topic =~ s/ / */g;
    return urlEncode( $topic );
}

# ---++ routine _SPACEOUT( $topic, $sep ) -> $string
# Returns a topic name with spaces (or another separator string) in between each word component.
# Parameter 'topic' is the topic name to space out.
# Parameter 'sep' is the string to separate the word components.
# Calls spaceOutWikiWord; if no 'sep' is passed, spaceOutWikiWord assumes a space as separator.
sub _SPACEOUT {
    my ( $this, $params ) = @_;
    my $spaceOutTopic = $params->{_DEFAULT};
    my $sep = $params->{'sep'};
    $spaceOutTopic = spaceOutWikiWord( $spaceOutTopic, $sep );
    return $spaceOutTopic;
}

sub _ICON {
    my( $this, $params ) = @_;
    my $file = ( $params->{_DEFAULT} || '' );

    return $this->{renderer}->getIconHTML( $file );
}

sub _ICONPATH {
    my( $this, $params ) = @_;
    my $file = ( $params->{_DEFAULT} || '' );

    return $this->{renderer}->getIconURL( $file );
}

sub _RELATIVETOPICPATH {
    my ( $this, $params, $theTopic, $web ) = @_;
    my $topic = $params->{_DEFAULT};

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
