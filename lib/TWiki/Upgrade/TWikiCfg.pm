# Support functionality for the TWiki Collaboration Platform, http://TWiki.org/
#
#
# Jul 2004 - written by Martin "GreenAsJade" Gregory, martin@gregories.net

package TWikiCfg;

use strict; 

use vars '$twikiLibPath';   # read from setlib.cfg

use vars '@storeSettings';  # read from TWiki.cfg

use vars qw($InitialBlurb @ConfigFileScalars @ConfigFileArrays);  # default Twiki.cfg contents, set in BEGIN block far below...
 
use Data::Dumper;
use File::Copy;

=begin twiki

---+ WriteNewTWikiCfg
    
Create a new TWiki.cfg with the default settings in it
    
=cut

sub WriteNewTWikiCfg
{
    my $NewFileName = (shift or "./TWiki.cfg");

    if (-f $NewFileName) 
    {
	print "Are you sure you want to overwrite $NewFileName?\n";
	my $response = <STDIN>;
	if ($response !~ m/[yY]/)
	{
	    die "WriteNewTWikiCfg passed unacceptable file name $NewFileName - can't proceed (sorry!)\n";
	}
    }
    open(NEW_CONFIG, ">$NewFileName") or die "Couldn't open $NewFileName for write: $!\n";
    
    print NEW_CONFIG "$InitialBlurb\n\n";
    print NEW_CONFIG "# This file created by WriteNewTWikiCfg, which provided default values\n\n";
    
    my $configVal;
    
    # @ConfigFileContents is an array of hashrefs, one per config variable
    for $configVal (@ConfigFileScalars)   # so $$configVal is a hash with a record about one config variable...
    {
	print NEW_CONFIG $$configVal{'comment'} . "\n";
	
	print NEW_CONFIG "\$$$configVal{varname} = $$configVal{default} ;\n";
    }
    
    for $configVal (@ConfigFileArrays)   # so $$configVal is a hash with a record about one config variable...
    {
	print NEW_CONFIG $$configVal{'comment'} . "\n";
	
	print NEW_CONFIG "\@$$configVal{varname} = $$configVal{default} ;\n";
    }
    
    print NEW_CONFIG "\n1;\n";
}

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

    my $newConfigFile = "$targetDir/lib/TWiki.cfg";

    my $twikiCfgFile;

    if (-f "$existingConfigInfo/setlib.cfg")
    {
	my ($setlibPath) = $existingConfigInfo;

        # Find out from there where TWiki.cfg is
	
	require "$setlibPath/setlib.cfg";
	
	print "\nGreat - found it OK, and it tells me that the rest of the config is in $twikiLibPath,\n";
	print "so that's where I'll be looking!\n\n";

	print "First, making a new copy of setlib.cfg in your new installation...\n";
	copy("$setlibPath/setlib.cfg", "$targetDir/bin/setlib.cfg") or 
	    die "Whoa - error copying $setlibPath/setlib.cfg to $targetDir/bin/setlib.cfg! $!\n";

	print "...$setlibPath/setlib.cfg has been copied into $targetDir/bin\n";

	print "Now reading the old TWiki.cfg  and generating the new...\n\n";

	$twikiCfgFile = "$twikiLibPath/TWiki.cfg";
    }
    elsif (-f "$existingConfigInfo/TWiki.cfg")
    {
	$twikiCfgFile = "$existingConfigInfo/TWiki.cfg";
    }

    # read 'em in...
    require $twikiCfgFile;
    
    # and now we have the old definitions...
    # ...  write those out where we can, or new defaults where we can't

    open(NEW_CONFIG, ">$newConfigFile") or die "Couldn't open $newConfigFile to write it: $!\n";

    print NEW_CONFIG "$InitialBlurb\n\n";

    print NEW_CONFIG "#  This file has been generated by UpgradeTwiki, taking values from
#   $twikiLibPath/Twiki.cfg where they could be found, and using
#  default values for the remainder.
#
";

  CLOSE_YOUR_EYES:   # unless you have a strong stomach... symbolic refs ahead...
    {
	no strict 'refs';

	my $configVal;
	my $usedADefault = 0;

	# Do scalars first...

	# @ConfigFileScalars is an array of hashrefs, one per config variable
	for $configVal (@ConfigFileScalars)   # so $$configVal is a hash with a record about one config variable...
	{   
	    print NEW_CONFIG $$configVal{'comment'} . "\n";

	    # ... and so this thing   vvvvvv  is the value of that variable, as read from $twikiCfgFile...
	    if (!defined(${$$configVal{'varname'}}))  
	    {	    
		# and if it is not defined, then we need to give it the default value
		print NEW_CONFIG "\$$$configVal{varname} = $$configVal{default} ;\n";
		print "There wasn't a definition for \"\$$$configVal{varname}\" in the old configuration... \n ...using the default: '$$configVal{default} '\n";
		$usedADefault = 1;
	    }
	    else
	    {
		# if it is defined, just write code to set the value to whatever it currently is

		print NEW_CONFIG Data::Dumper->Dump([${$$configVal{'varname'}}],[$$configVal{'varname'}]);
	    }
	}

	if ($usedADefault) 
	{
	    print "(You may want to check that the defaults used above work for you, edit if not!)\n";
	}

	# Now do Arrays ... exactly the same code, except for @ instead of $.  

	# We have to have this nonsense because pre-Cairo TWiki.cfgs had nuisance
        # stuff in @storeSettings (in particular, they referred to $TWiki::dataDir)
	# we need to get rid of that!

	# All this question stuff is commented out at the moment because of course they are upgrading
	# from a pre-Cairo release - there is no other sort.
	# this is the kind of stuff that will have to be done post-Cairo.

#	print "Are you upgrading from a pre-Cairo TWiki?\n";
#
#	my $response = <STDIN>;
#
#	my $keepDefaults = 0;
#
#	if ($response !~ m/[nN]/)
#	{
#	    print "\nAh...\n\n";
#	    print "Well, your new TWiki.cfg file (\"$newConfigFile\") is going to have the new default \@storeSettings in it.
#
#\tUnless someone changed the values in your old configuration, this will be just fine.
#
#\tIf someone did make some changes, you're going to have to manually copy those over (sorry!).
#
#\tIf in doubt, look at \@storeSettings in $twikiCfgFile 
#\tand compare to what I've put in $newConfigFile.
#
#";

	my $keepDefaults = 1;
#	}
	
	for $configVal (@ConfigFileArrays)  
	{   
	    print NEW_CONFIG $$configVal{'comment'} . "\n";

	    # ... and so this thing   vvvvvv  is the value of that variable, as read from $twikiCfgFile...
	    if (!defined(@{$$configVal{'varname'}}) or $keepDefaults)  
	    {	    
		# and if it is not defined, then we need to give it the default value
		print NEW_CONFIG "\@$$configVal{varname} = $$configVal{default} ;\n";
		print "There wasn't a definition for \"\$$$configVal{varname}\" in the old configuration... \n ...using the default: '$$configVal{default} '\n (You may want to check that this default works for you, edit if not!)\n" unless $keepDefaults;
	    }
	    else
	    {
		# if it is defined, just write code to set the value to whatever it currently is

		print NEW_CONFIG Data::Dumper->Dump([\@{$$configVal{'varname'}}],["*$$configVal{'varname'}"]);
	    }
	}

	close NEW_CONFIG or die "Yuck - couldn't close TWiki.cfg.new!\n";
    }

    print "$targetDir/lib/TWiki.cfg created...\n";
}

# Here follow the default contents of TWiki.cfg

# There are many ways that capture of the default TWiki.cfg settings could be done: 
#  text in the DATA segment etc etc

# I chose this way because it doesn't need any regex parsing stuff....
# I like the robustness that this confers: perl checks at least some aspects of it at compile time!

# These variables are declared down here in a BEGIN block simply to get all this
# mess out of the way: nice code first, lots of data second.

BEGIN {  

    $InitialBlurb = "# Module of TWiki Collaboration Platform  -*-Perl-*-
#
# This is the configuration file for TWiki, usually held in 'lib' directory.
#
# See 'setlib.cfg' in 'bin' directory to configure non-standard location
# for 'lib' directory or Perl modules.
#
# Copyright (C) 1999-2004 Peter Thoeny, peter\@thoeny.com
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
# Notes:
# - Latest version at http://twiki.org/
# - Installation instructions in \$dataDir/TWiki/TWikiDocumentation.txt
# - Customize variables in TWiki.cfg when installing TWiki.
# - Optionally create a new plugin or customize DefaultPlugin.pm for
#   custom extensions of rendering rules.
# - Upgrading TWiki is easy as long as you only customize DefaultPlugin.pm.
# - Variables that can be accessed from topics (see details in
#   TWikiDocumentation.html) :
#       %TOPIC%          name of current topic
#       %WEB%            name of current web
#       %SCRIPTURL%      base TWiki script URL (place of view, edit...)
#       %SCRIPTURLPATH%  like %SCRIPTURL%, but path only (cut protocol and domain)
#       %SCRIPTSUFFIX%   script suffix (empty by default, '.pl' if required)
#       %PUBURL%         public URL (root of attachment URL)
#       %PUBURLPATH%     path of public URL
#       %ATTACHURL%      attachment URL of current topic
#       %ATTACHURLPATH%  path of attachment URL of current topic
#       %DATE%           today's date
#       %WIKIVERSION%    tool version
#       %USERNAME%       login user name
#       %WIKIUSERNAME%   wiki user name
#       %MAINWEB%        main web name (Main)
#       %TWIKIWEB%       TWiki system web name (TWiki)
#       %HOMETOPIC%      home topic name (WebHome)
#       %NOTIFYTOPIC%    notify topic name (WebNotify)
#       %WIKIUSERSTOPIC% user list topic name (TWikiUsers)
#       %WIKIPREFSTOPIC% site-level preferences topic name (TWikiPreferences)
#       %WEBPREFSTOPIC%  web preferences topic name (WebPreferences)
#       %STATISTICSTOPIC statistics topic name (WebStatistics)
#       %INCLUDE{...}
#       %SEARCH{...}%    inline search


# variables that need to be changed when installing on a new server:
# ==================================================================
# ---- Windows paths should normally be written as 'c:/foo' not 'c:\foo' 
# ---- (which doesnt do what you may think it does).  You can use '\' 
# ---- without problems inside single quotes, e.g. 'c:\foo'.
";

    @ConfigFileScalars = 
	(
	 { 'varname' => 'defaultUrlHost',
	   'default' => '"http://your.domain.com"',
	   'comment' => '# URL for TWiki host :    (e.g. "http://myhost.com:123")'},
	 { 'varname' => 'scriptUrlPath',
	   'default' => ' "/twiki/bin"',
	   'comment' => '#                   %SCRIPTURLPATH% : cgi-bin URL path for TWiki:'},
	 { 'varname' => 'dispScriptUrlPath',
	   'default' => ' $scriptUrlPath',
	   'comment' => '#                   URL path to scripts used to render links.  Change if using redirection to shorten URLs'},
	 { 'varname' => 'dispViewPath',
	   'default' => ' "/view"',
	   'comment' => '#                   URL path to view script used to render links, relative to $dispScriptUrlPath'},
	 { 'varname' => 'pubUrlPath',
	   'default' => ' "/twiki/pub"',
	   'comment' => '#                   %PUBURLPATH% : Public data URL path for TWiki (root of attachments) :'},
	 { 'varname' => 'pubDir',
	   'default' => ' "/home/httpd/twiki/pub"',
	   'comment' => '#                   Public data directory (file path not URL), must match $pubUrlPath :'},
	 { 'varname' => 'templateDir',
	   'default' => ' "/home/httpd/twiki/templates"',
	   'comment' => '#                   Template directory :'},
	 { 'varname' => 'dataDir',
	   'default' => ' "/home/httpd/twiki/data"',
	   'comment' => '#                   Data (topic files) root directory (file path not URL):'},
	 { 'varname' => 'logDir',
	   'default' => ' "$dataDir"',
	   'comment' => '#                   Log directory for log files, debug and warning files. Default "$dataDir" :'},
	 { 'varname' => 'scriptSuffix',
	   'default' => ' ""',
	   'comment' => '# variables that might need to be changed:
# ==================================================================
#                   %SCRIPTSUFFIX% : Suffix of TWiki Perl scripts (e.g. ".pl") :'},
	 { 'varname' => 'uploadFilter',
	   'default' => ' "^(\.htaccess|.*\.(?:php[0-9s]?|phtm[l]?|pl|py|cgi))\$"',
	   'comment' => '#                   Regex security filter for uploaded (attached) files :
#                   (Matching filenames will have a ".txt" appended)
#		    WARNING: Be sure to update this list with any
#		    configuration or script filetypes that are
#		    automatically run by your web server'},
	 { 'varname' => 'safeEnvPath',
	   'default' => '"/bin:/usr/bin"',
	   'comment' => '#                   Set ENV{"PATH"} explicitly for taint checks ( #!perl -T option ) :
#                   (Note: PATH environment variable is not changed if set to "")
# $safeEnvPath - safe operating system PATH setting for use by TWiki scripts.
#
# ---- Check notes for your operating system and use appropriate line as model
# ---- Comment out unused lines (put "#" at start) and uncomment required line.
# ---- All Windows paths use "/" not "\" for simplicity.
#
# As long as you use full pathnames for $egrepCmd and similar (below),
# this path value is used only to find a shell (or cmd.exe) and by RCS programs 
# to find "diff".
#
# >> Unix or Linux - ensure "diff" and shell (Bourne or bash type) is found on 
# this path.
# Separator is ":"
# >> Windows: Cygwin Perl and RCS - ensure "diff" and "bash" found on this path.
# Same format as Unix PATH, separator is ":" not ";".  You must NOT use 
# "c:/foo" type paths, because ":" is taken as separator, meaning that 
# "c" is interpreted as a relative pathname, giving Perl "Insecure 
# directory in $ENV{PATH}" error on using "Diffs" link.
# Separator is ":"
# $safeEnvPath      = "/bin";		# Cygwin - uncomment, no need to customise

# >> Windows: ActiveState Perl, with Cygwin RCS and PERL5SHELL set to
# "c:/cygwin/bin/bash.exe -c".  Same format as the normal Windows PATH, 
# separator is ":" not ";".  Its best to avoid "c:/foo" type paths, 
# because in some cases these can cause a Perl "Insecure directory 
# in $ENV{PATH}" error on using "Diffs" link.  Since this setting is
# for Cygwin RCS, the best alternative is to convert "c:/foo" to 
# "/c/cygdrive/foo" - odd looking but it works!  The Windows system directory 
# (e.g. /cygdrive/c/winnt/system32) is required in this path for commands 
# using pipes to work (e.g. using the "Index" link).
# NOTE: Customise this path based on your Cygwin and Windows directories
# Separator is ";"
# $safeEnvPath      = "/cygdrive/c/YOURCYGWINDIR/bin;/cygdrive/c/YOURWINDOWSDIR/system32";

# >> Windows: ActiveState Perl, with non-Cygwin RCS, OR no PERL5SHELL setting.
# Windows PATH, separator is ";".  The Windows system directory 
# (e.g. c:\winnt\system32) is required in this path for commands using pipes 
# to work (e.g. using the "Index" link). Must NOT use "/" in pathnames
# as this upsets cmd.exe - single "\" is OK using Perl single-quoted string.
# FIXME: needs testing, not currently recommended.
# NOTE: Customise this path based on your RCS and Windows directories
# Separator is ";"
# $safeEnvPath      = "c:\YOUR_RCSPROGDIR\bin;c:\YOURWINDOWSDIR\system32";'
},
	 { 'varname' => 'mailProgram',
	   'default' => ' "/usr/sbin/sendmail -t -oi -oeq"',
	   'comment' => '#                   Mail program used in case Net::SMTP is not installed.
#                   See also SMTPMAILHOST in TWikiPreferences.
#		    Windows: this setting is ignored, just use Net::SMTP.'},
	 { 'varname' => 'noSpamPadding',
	   'default' => ' ""',
	   'comment' => '#                   Prevent spambots from grabbing addresses, default "":
#                   e.g. set to "NOSPAM" to get "user@somewhereNOSPAM.com"'},
	 { 'varname' => 'mimeTypesFilename',
	   'default' => ' "$dataDir/mime.types"',
	   'comment' => '#                   Pathname of mime types file that maps file suffixes to MIME types :
#                   For Apache server set this to Apaches mime.types file pathname.
#                   Default "$dataDir/mime.types"'},
	 { 'varname' => 'rcsDir',
	   'default' => ' "/usr/bin"',
	   'comment' => '#                   RCS directory (find out by "which rcs") :'},
	 { 'varname' => 'rcsArg',
	   'default' => ' ($OS eq "WINDOWS") ? "-x,v" : ""',
	   'comment' => '#                   Initialise RCS file, ignored if empty string,
#                   needed on Windows for binary files. Added JET 22-Feb-01'},
	 { 'varname' => 'nullDev',
	   'default' => ' {
    UNIX=>"/dev/null", OS2=>"", WINDOWS=>"NUL", DOS=>"NUL", MACINTOSH=>"", VMS=>""
    }->{$OS}',
	'comment' => '#                   null device /dev/null for unix, NUL for windows'},
	 { 'varname' => 'useRcsDir',
	   'default' => ' "0"',
	   'comment' => '#                   Store RCS history files in directory (RCS under content dir), default "0"
#                   Dont change this in a working installation, only change when initially setting up a TWiki installation
#                   You also need to create an RCS directory for each Web.  TWiki will create RCS directories under pub for attachments historys.'},
	 { 'varname' => 'endRcsCmd',
	   'default' => ' ($OS eq "UNIX") ? " 2>&1" : ""',
	   'comment' => '# This should enable gathering of extra error information on most OSes.  However, wont work on NT4 unless unix like shell is used'},
	 { 'varname' => 'cmdQuote',
	   'default' => ' ($OS eq "UNIX") ? "\\"" :  "\'" ' ,
	   'comment' => '#                   Command quote \' for unix, \" for Windows'},
	 { 'varname' => 'storeTopicImpl',
	   'default' => ' "RcsWrap"',
	   'comment' => '# Choice and configuration of Storage implementation
# Currently select either:
# RcsWrap - use RCS executables, see TWiki::Store::RcsWrap.pm for explanation of storeSettings
# RcsLite - use a 100% Perl simplified implementation of Perl (NOT yet ready for production use)'},
	 { 'varname' => 'lsCmd',
	   'default' => ' "/bin/ls"',
	   'comment' => '#                   NOTE: You might want to avoid c: at start of cygwin unix command for
#                   Windows, seems to cause a problem with pipe used in search
#                   Unix ls command :  (deprecated since 01 Nov 2003)'},
	 { 'varname' => 'egrepCmd',
	   'default' => ' "/bin/egrep"',
	   'comment' => '#                   Unix egrep command :'},
	 { 'varname' => 'fgrepCmd',
	   'default' => ' "/bin/fgrep"',
	   'comment' => '#                   Unix fgrep command :'},
	 { 'varname' => 'displayTimeValues',
	   'default' => ' "gmtime"',
	   'comment' => '
#display Time in the following timezones (this only effects the display of times, all internal storage is still in GMT)
# gmtime / servertime'},
	 { 'varname' => 'useLocale',
	   'default' => ' 0',
	   'comment' => '# internationalisation setup:
# ==================================================================
# See the output of the "testenv" script for help with these settings.

# Set $useLocale to 1 to enable internationalisation support for
# 8-bit character sets'},
	 { 'varname' => 'siteLocale',
	   'default' => ' "en_US.ISO-8859-1"',
	   'comment' => '# Site-wide locale - used by TWiki and external programs such as grep,
# and to specify the character set for the users web browser.  The
# language part also prevents English plural handling for non-English
# languages.  Ignored if $useLocale is 0.
#
# Locale names are not standardised - check "locale -a" on your system to
# see what"s installed, and check this works using command line tools.  You
# may also need to check what charsets your browsers accept - the
# "preferred MIME names" at http://www.iana.org/assignments/character-sets
# are a good starting point.
#
# WARNING: Topics are stored in site character set format, so data conversion of
# file names and contents will be needed if you change locales after
# creating topics whose names or contents include 8-bit characters.
#'},
	 { 'varname' => 'siteCharsetOverride',
	   'default' => ' ""',
	   'comment' => '#
# Examples only:  (choose suitable locale + charset for your own site)
#   $siteLocale = "de_AT.ISO-8859-15";	# Austria with ISO-8859-15 for Euro
#   $siteLocale = "ru_RU.KOI8-R";	# Russia
#   $siteLocale = "ja_JP.eucjp";	# Japan
#   $siteLocale = "C";			# English only, no I18N features

# Site character set override - set this only if you must match a specific
# locale (from "locale -a") whose character set is not supported by your
# chosen conversion module (i.e. Encode for Perl 5.8 or higher, or
# Unicode::MapUTF8 for other Perl versions).  For example, the locale
# "ja_JP.eucjp" exists on your system but only "euc-jp" is supported by
# Unicode::MapUTF8, set $siteCharsetOverride to "euc-jp".  Leave this as ""
# if you dont have this problem.'},
	 { 'varname' => 'localeRegexes',
	   'default' => ' 1',
	   'comment' => '# Set $localeRegexes to 0 to force explicit listing of national chars in
# regexes, rather than relying on locale-based regexes. Intended for Perl
# 5.6 or higher on platforms with broken locales: should only be set if
# you have locale problems with Perl 5.6 or higher.'},
	 { 'varname' => 'upperNational',
	   'default' => ' ""',
	   'comment' => '
# If a suitable working locale is not available (i.e. $useLocale is 0), OR 
# you are using Perl 5.005 (with or without working locales), OR
# $localeRegexes is 0, you can use WikiWords with accented national
# characters by putting any "8-bit" accented national characters within
# these strings - i.e. $upperNational should contain upper case non-ASCII
# letters.  This is termed "non-locale regexes" mode.
#
# If "non-locale regexes" is in effect, WikiWord linking will work, but 
# some features such as sorting of WikiWords in search results may not.  
# These features depend on $useLocale, which can be set independently of
# $localeRegexes, so they will work with Perl 5.005 as long as 
# $useLocale is set to 1 and you have working locales.
#
# Using the recommended setup of Perl 5.6.1 with working locales avoids the
# need to set these parameters.'},
	 { 'varname' => 'lowerNational',
	   'default' => ' ""',
	   'comment' => ''},
	 { 'varname' => 'keywordMode',
	   'default' => ' "-ko"',
	   'comment' => '
# variables that probably do not change:
# ==================================================================

# RCS keyword handling: change this to "" only if you want TWiki pages to
# include automatically-updated RCS ID keyword strings.  Leave this as
# "-ko" if you dont know what that means!  Default setting ensures that
# contents of TWiki pages are not changed by RCS. RcsLite always works in 
# "-ko" mode.
'},
	 { 'varname' => 'securityFilter',
	   'default' => ' "[\\\*\?\~\^\$\@\%\`\"\\\'\&\;\|\<\>\x00-\x1F]" ',
	   'comment' => '#                   Regex security filter for web name, topic name, user name :'},
	 { 'varname' => 'defaultUserName',
	   'default' => ' "guest"',
	   'comment' => '#                   Default user name, default "guest" :'},
	 { 'varname' => 'wikiToolName',
	   'default' => ' "TWiki"',
	   'comment' => '#                   Deprecated, replaced by %WIKITOOLNAME% preferences variable :'},
	 { 'varname' => 'wikiHomeUrl',
	   'default' => ' "http://your.domain.com/twiki"',
	   'comment' => '#                   Deprecated, here for compatibility :'},
	 { 'varname' => 'siteWebTopicName',
	   'default' => ' ""',
	   'comment' => '#                   Site Web.Topic name, e.g. "Main.TokyoOffice". Default "" :'},
	 { 'varname' => 'mainWebname',
	   'default' => ' "Main"',
	   'comment' => '#                   %MAINWEB% : Name of Main web, default "Main" :'},
	 { 'varname' => 'twikiWebname',
	   'default' => ' "TWiki"',
	   'comment' => '#                   %TWIKIWEB% : Name of TWiki system web, default "TWiki" :'},
	 { 'varname' => 'debugFilename',
	   'default' => ' "$logDir/debug.txt"',
	   'comment' => '#                   Pathname of debug file :'},
	 { 'varname' => 'warningFilename',
	   'default' => ' "$logDir/warning.txt"',
	   'comment' => '#                   Pathname of warning file. Default "$logDir/warning.txt" :
#                   (no warnings are written if empty)'},
	 { 'varname' => 'htpasswdFormatFamily',
	   'default' => ' "htpasswd" ',
	   'comment' => '#                   Password file format/encoding method :
#                   htpasswd:plain, htpasswd:crypt, htpasswd:md5 (currently unsupported),
#                   htpasswd:sha1, htdigest:md5, none:
#default htpasswd:crypt;'},
	 { 'varname' => 'htpasswdEncoding',
	   'default' => ' ($OS eq "WINDOWS") ? "sha1" : "crypt" ' ,
	   'comment' => '#'
	  },
	 { 'varname' => 'htpasswdFilename',
	   'default' => ' ($htpasswdFormatFamily eq "htpasswd") ? "$dataDir/.htpasswd" : "$dataDir/.htdigest" ' ,
	   'comment' => '#                   Pathname of user name/password file for authentication :'
	  },
	 { 'varname' => 'authRealm',
	   'default' => ' "Enter your WikiName. (First name and last name, no space, no dots, capitalized, e.g. JohnSmith). Cancel to register if you do not have one."',
	   'comment' => '#                   Authentication "realm" (must be the same as in
#                   password file, MUST NOT contain colons):'},
	 { 'varname' => 'logFilename',
	   'default' => ' "$logDir/log%DATE%.txt"',
	   'comment' => '#                   Pathname of log file :'},
	 { 'varname' => 'remoteUserFilename',
	   'default' => ' "$dataDir/remoteusers.txt"',
	   'comment' => '#                   Pathname of remote users file that maps IP to user :'},
	 { 'varname' => 'wikiUsersTopicname',
	   'default' => ' "TWikiUsers"',
	   'comment' => '#                   %WIKIUSERSTOPIC% : Name of users list topic :'},
	 { 'varname' => 'userListFilename',
	   'default' => ' "$dataDir/$mainWebname/$wikiUsersTopicname.txt"',
	   'comment' => '#                   Pathname of WebUsers topic, used to map Intranet login name
#                   (e.g. "fsmith") to Wiki name (e.g. "FredSmith") :'},
	 { 'varname' => 'doMapUserToWikiName',
	   'default' => ' "0"',
	   'comment' => '#                   Map login name to Wiki name, default "1", set to "0" for .htpasswd authenticated sites :'},
	 { 'varname' => 'mainTopicname',
	   'default' => ' "WebHome"',
	   'comment' => '#                   %HOMETOPIC% : Name of main topic in a web, default "WebHome" :'},
	 { 'varname' => 'notifyTopicname',
	   'default' => ' "WebNotify"',
	   'comment' => '#                   %NOTIFYTOPIC% : Name of topic for email notifications, default "WebNotify" :'},
	 { 'varname' => 'wikiPrefsTopicname',
	   'default' => ' "TWikiPreferences"',
	   'comment' => '#                   %WIKIPREFSTOPIC% : Name of site-level preferences topic, default "TWikiPreferences" :'},
	 { 'varname' => 'webPrefsTopicname',
	   'default' => ' "WebPreferences"',
	   'comment' => '#                   %WEBPREFSTOPIC% : Name of preferences topic in a web, default "WebPreferences" :'},
	 { 'varname' => 'statisticsTopicname',
	   'default' => ' "WebStatistics"',
	   'comment' => '#                   %STATISTICSTOPIC% : Name of statistics topic, default "WebStatistics" :'},
	 { 'varname' => 'statsTopViews',
	   'default' => ' "10"',
	   'comment' => '#                   Number of top viewed topics to show in statistics topic, default "10" :'},
	 { 'varname' => 'statsTopContrib',
	   'default' => ' "10"',
	   'comment' => '#                   Number of top contributors to show in statistics topic, default "10" :'},
	 { 'varname' => 'doDebugStatistics',
	   'default' => ' "0"',
	   'comment' => '#                   Statistics debugging - write invalid logfile lines to debug log'},
	 { 'varname' => 'numberOfRevisions',
	   'default' => ' "3"',
	   'comment' => '#                   Show how many revision links, "0" for all, default "3" :'},
	 { 'varname' => 'editLockTime',
	   'default' => ' "3600"',
	   'comment' => '#                   Number of seconds a topic is locked during edit, default "3600" :'},
	 { 'varname' => 'superAdminGroup',
	   'default' => ' "TWikiAdminGroup"',
	   'comment' => '#                   Group of users that can use cmd=repRev
#                   or that ALWAYS have edit powers (set $doSuperAdminGroup=1)'},
	 { 'varname' => 'doKeepRevIfEditLock',
	   'default' => ' "1"',
	   'comment' => '
# flag variables that could change:
# ==================================================================
# values are "0" for no, or "1" for yes
#                   Keep same revision if topic is saved again within edit lock time. Default "1"'},
	 { 'varname' => 'doGetScriptUrlFromCgi',
	   'default' => ' "0"',
	   'comment' => '#                   Build $scriptUrlPath from $query->url parameter. Default "0".
#                   Note that links are incorrect after failed authentication if "1"'},
	 { 'varname' => 'doRemovePortNumber',
	   'default' => ' "0"',
	   'comment' => '#                   Remove port number from URL. Default "0"'},
	 { 'varname' => 'doRemoveImgInMailnotify',
	   'default' => ' "1"',
	   'comment' => '#                   Remove IMG tags in mailnotify. Default "1"'},
	 { 'varname' => 'doRememberRemoteUser',
	   'default' => ' "0"',
	   'comment' => '#                   Remember remote user by matching the IP address
#                   in case REMOTE_USER is empty. Default "0"
#                   (Note: Does not work reliably with dynamic IP addresses)'},
	 { 'varname' => 'doPluralToSingular',
	   'default' => ' "1"',
	   'comment' => '#                   Change non existing plural topic name to singular,
#                   e.g. TestPolicies to TestPolicy. Default "1"'},
	 { 'varname' => 'doHidePasswdInRegistration',
	   'default' => ' "1"',
	   'comment' => '#                   Hide password in registration email'},
	 { 'varname' => 'doSecureInclude',
	   'default' => ' "1"',
	   'comment' => '#                   Remove ".." from %INCLUDE% filename, to
#                   prevent includes of "../../file". Default "1"'},
	 { 'varname' => 'doLogTopicView',
	   'default' => ' "1"',
	   'comment' => '#                   Log topic views to $logFilename. Default "1"'},
	 { 'varname' => 'doLogTopicEdit',
	   'default' => ' "1"',
	   'comment' => '#                   Log topic edits to $logFilename. Default "1"'},
	 { 'varname' => 'doLogTopicSave',
	   'default' => ' "1"',
	   'comment' => '#                   Log topic saves to $logFilename. Default "1"'},
	 { 'varname' => 'doLogRename',
	   'default' => ' "1"',
	   'comment' => '#                   Log renames to $logFilename. Default "1".  Added JET 22-Feb-01'},
	 { 'varname' => 'doLogTopicAttach',
	   'default' => ' "1"',
	   'comment' => '#                   Log view attach to $logFilename. Default "1"'},
	 { 'varname' => 'doLogTopicUpload',
	   'default' => ' "1"',
	   'comment' => '#                   Log file upload to $logFilename. Default "1"'},
	 { 'varname' => 'doLogTopicRdiff',
	   'default' => ' "1"',
	   'comment' => '#                   Log topic rdiffs to $logFilename. Default "1"'},
	 { 'varname' => 'doLogTopicChanges',
	   'default' => ' "1"',
	   'comment' => '#                   Log changes to $logFilename. Default "1"'},
	 { 'varname' => 'doLogTopicSearch',
	   'default' => ' "1"',
	   'comment' => '#                   Log search to $logFilename. Default "1"'},
	 { 'varname' => 'doLogRegistration',
	   'default' => ' "1"',
	   'comment' => '#                   Log user registration to $logFilename. Default "1"'},
	 { 'varname' => 'disableAllPlugins',
	   'default' => ' "0"',
	   'comment' => '#                   Disable plugins. Set to "1" in case TWiki is non functional after
#                   installing a new plugin. This allows you to remove the plugin from
#                   the ACTIVEPLUGINS list in TWikiPreferences. Default "0"'},
	 { 'varname' => 'doSuperAdminGroup',
	   'default' => ' "1"',
	   'comment' => '#                   Enable super-powers to $superAdminGroup members
#                   see Codev.UnchangeableTopicBug'}
	 );

    @ConfigFileArrays = 
	(
	 { 'varname' => 'storeSettings',
	   'default' => ' 
  (
    # RcsLite and Rcs
    dataDir         => $dataDir,
    pubDir          => $pubDir,
    attachAsciiPath => "\.(txt|html|xml|pl)\$",
    dirPermission   => 0775,
    useRcsDir       => $useRcsDir,

    # Rcs only 
    initBinaryCmd => "$rcsDir/rcs $rcsArg -q -i -t-none -kb %FILENAME% $endRcsCmd",
    tmpBinaryCmd  => "$rcsDir/rcs $rcsArg -q -kb %FILENAME% $endRcsCmd",
    ciCmd         => "$rcsDir/ci $rcsArg -q -l -m$cmdQuote%COMMENT%$cmdQuote -t-none -w$cmdQuote%USERNAME%$cmdQuote %FILENAME% $endRcsCmd",
    coCmd         => "$rcsDir/co $rcsArg -q -p%REVISION% $keywordMode %FILENAME% $endRcsCmd",
    histCmd       => "$rcsDir/rlog $rcsArg -h %FILENAME% $endRcsCmd",
    infoCmd       => "$rcsDir/rlog $rcsArg -r%REVISION% %FILENAME% $endRcsCmd",
    diffCmd       => "$rcsDir/rcsdiff $rcsArg -q -w -B -r%REVISION1% -r%REVISION2% $keywordMode --unified=%CONTEXT% %FILENAME% $endRcsCmd",
    breakLockCmd  => "$rcsDir/rcs $rcsArg -q -l -M %FILENAME% $endRcsCmd",
    ciDateCmd     => "$rcsDir/ci -l $rcsArg -q -mnone -t-none -d$cmdQuote%DATE%$cmdQuote -w$cmdQuote%USERNAME%$cmdQuote %FILENAME% $endRcsCmd",
    delRevCmd     => "$rcsDir/rcs $rcsArg -q -o%REVISION% %FILENAME% $endRcsCmd",
    unlockCmd     => "$rcsDir/rcs $rcsArg -q -u %FILENAME%  $endRcsCmd",
    lockCmd       => "$rcsDir/rcs $rcsArg -q -l %FILENAME% $endRcsCmd",
    tagCmd       => "$rcsDir/rcs $rcsArg -N%TAG%:%REVISION% %FILENAME% $endRcsCmd",
  )',
  'comment' => '# Settings for Rcs (standard RCS programs) and RcsLite (built-in)'}
);	 

    
};

1;

=end twiki

__DATA__
