# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2005 Cole Beck, cole.beck@vanderbilt.edu
# Copyright (C) 2004-2011 TWikiContributors
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
# http://www.gnu.org/copyleft/gpl.html
#
# =========================
#
# This plugin creates a png file by using the graphviz dot command.
# See http://www.graphviz.org/ for more information.
# Note that png files created with this plugin can only be deleted
# manually; It stays there even after the dot tags are removed.

package TWiki::Plugins::DirectedGraphPlugin;

# =========================
use strict;

use Digest::MD5 qw( md5_hex );
use Storable qw(store retrieve freeze thaw);

use File::Path;
use File::Temp;
use File::Spec;
use File::Copy;    # Used for TWiki attach API bypass

our $VERSION = '$Rev$';
our $RELEASE = '2011-04-14';

our $SHORTDESCRIPTION = 'Draw graphs using the !GraphViz utility';
our $NO_PREFS_IN_TOPIC = 1;

#
#  General plugin information
#
my $web;           # Current web being processed
my $usWeb;         # Web name with subwebs delimiter changed to underscore
my $topic;         # Current topic
my $user;          # Current user
my $installWeb;    # Web where plugin topic is installed

#
# Plugin settings passed in URL or by preferences
#
my $debugDefault;          # Debug mode
my $antialiasDefault;      # Anti-ailas setting
my $densityDefault;        # Density for Postscript document
my $sizeDefault;           # Size of graph
my $vectorFormatsDefault;  # Types of images to be generated
my $hideAttachDefault;     # Should attachments be shown in the attachment table
my $inlineAttachDefault;   # Image type that will be shown inline in the topic
my $linkFilesDefault
  ;    # Should other file types have links shown under the inline image
my $engineDefault
  ;    # Which GraphVize engine should generate the image (default is "dot")
my $libraryDefault;           # Topic for images
my $deleteAttachDefault;      # Should old attachments be trashed
my $legacyCleanup;            # Backwards cleanup from TWiki implementation
my $forceAttachAPI;           # Force attachment processing using TWiki API
my $forceAttachAPIDefault;    #
my $svgFallbackDefault
  ;   # File graphics type attached as fallback for browsers without svg support
my $svgLinkTargetDefault;    #

#
# Locations of the commands, etc. passed in from LocalSite.cfg
#
my $enginePath;              # Location of the "dot" command
my $magickPath;              # Location of ImageMagick
my $toolsPath;               # Location of the Tools directory for helper script
my $attachPath;              # Location of attachments if not using TWiki API
my $attachUrlPath;           # URL to find attachments
my $perlCmd;                 # perl command

my $HASH_CODE_LENGTH = 32;

#
# Documentation on the sandbox command options taken from TWiki/Sandbox.pm
#
# '%VAR%' can optionally take the form '%VAR|FLAG%', where FLAG is a
# single character flag.  Permitted flags are
#   * U untaint without further checks -- dangerous,
#   * F normalize as file name,
#   * N generalized number,
#   * S simple, short string,
#   * D rcs format date

my $dotHelper = 'DirectedGraphPlugin.pl';
my $engineCmd =
' %HELPERSCRIPT|F% %DOT|F% %WORKDIR|F% %INFILE|F% %IOSTRING|U% %ERRFILE|F% %DEBUGFILE|F%';
my $antialiasCmd =
  'convert -density %DENSITY|N% -geometry %GEOMETRY|S% %INFILE|F% %OUTFILE|F%';
my $identifyCmd = 'identify %INFILE|F%';

my $sandbox = undef;

# The session variables are used to store the file names and md5hash of the input to the dot command
#   xxxHashArray{SET} - Set to 1 if the array has been initialized
#   xxxHashArray{GRNUM} - Counts the unnamed graphs for the page
#   xxxHashArray{FORMATS}{<filename>} - contains the list of output file types for the input file
#   xxxHashArray{MD5HASH}{<filename>} - contains the hash of the input used to create the files
#   xxxHashArray{IMAGESIZE}{<filename>} - contains the image size of the file for rendering

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    &_writeDebug(' >>> initPlugin Entered');

    #  Disable the plugin if a topic revision is requested in the query.
    my $query;
    if ( $TWiki::Plugins::VERSION >= 2.1 ) {
        $query = TWiki::Func::getRequestObject();
    }
    else {
        $query = TWiki::Func::getCgiQuery();
    }

    if ( $query && $query->param('rev') ) {
        if ( !$TWiki::cfg{Plugins}{DirectedGraphPlugin}
            {generateRevAttachments} )
        {
            &_writeDebug('DirectedGraphPlugin - Disabled  - revision provided');
            return 0;
        }
    }

    #  Disable the plugin if comparing two revisions (context = diff
    if ( TWiki::Func::getContext()->{'diff'} ) {
        if ( !$TWiki::cfg{Plugins}{DirectedGraphPlugin}
            {generateDiffAttachments} )
        {
            &_writeDebug('DirectedGraphPlugin - Disabled  - diff context');
            return 0;
        }
    }

    $usWeb = $web;
    $usWeb =~ s/\//_/g;    #Convert any subweb separators to underscore

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning(
            'Version mismatch between DirectedGraphPlugin and Plugins.pm');
        return 0;
    }

    # path to dot, neato, twopi, circo and fdp (including trailing /)
    $enginePath = $TWiki::cfg{DirectedGraphPlugin}{enginePath}
      || $TWiki::cfg{Plugins}{DirectedGraphPlugin}{enginePath};

    # path to imagemagick convert routine
    $magickPath = $TWiki::cfg{DirectedGraphPlugin}{magickPath}
      || $TWiki::cfg{Plugins}{DirectedGraphPlugin}{magickPath};

    # path to Plugin helper script
    $toolsPath =
         $TWiki::cfg{DirectedGraphPlugin}{toolsPath}
      || $TWiki::cfg{Plugins}{DirectedGraphPlugin}{toolsPath}
      || $TWiki::cfg{ToolsDir};

    # If toolsPath is not set, guess the current directory.
    if ( !$toolsPath ) {
        use Cwd;
        $toolsPath = getcwd;
        $toolsPath =~ s/\/[^\/]+$/\/tools/;
    }

# Fix the various paths - trim whitespace and add a trailing slash if none is provided.

    $toolsPath =~ s/\s+$//;
    $toolsPath .= '/' unless ( substr( $toolsPath, -1 ) eq '/' );
    if ($enginePath) {
        $enginePath =~ s/\s+$//;
        $enginePath .= '/' unless ( substr( $enginePath, -1 ) eq '/' );
    }
    if ($magickPath) {
        $magickPath =~ s/\s+$//;
        $magickPath .= '/' unless ( substr( $magickPath, -1 ) eq '/' );
    }

# path to store attachments - optional.  If not provided, TWiki attachment API is used
    $attachPath = $TWiki::cfg{DirectedGraphPlugin}{attachPath}
      || $TWiki::cfg{Plugins}{DirectedGraphPlugin}{attachPath};

# URL to retrieve attachments - optional.  If not provided, TWiki pub path is used.
    $attachUrlPath = $TWiki::cfg{DirectedGraphPlugin}{attachUrlPath}
      || $TWiki::cfg{Plugins}{DirectedGraphPlugin}{attachUrlPath};

    # path to perl interpreter
    $perlCmd =
         $TWiki::cfg{DirectedGraphPlugin}{perlCmd}
      || $TWiki::cfg{Plugins}{DirectedGraphPlugin}{perlCmd}
      || 'perl';

    # Get plugin debug flag
    $debugDefault =
      TWiki::Func::getPreferencesFlag('DIRECTEDGRAPHPLUGIN_DEBUG');

    # Get plugin antialias default
    $antialiasDefault =
      TWiki::Func::getPreferencesValue('DIRECTEDGRAPHPLUGIN_ANTIALIAS')
      || 'off';

    # Get plugin density default
    $densityDefault =
      TWiki::Func::getPreferencesValue('DIRECTEDGRAPHPLUGIN_DENSITY')
      || '300';

    # Get plugin size default
    $sizeDefault =
      TWiki::Func::getPreferencesValue('DIRECTEDGRAPHPLUGIN_SIZE')
      || 'auto';

    # Get plugin vectorFormats default
    $vectorFormatsDefault =
      TWiki::Func::getPreferencesValue('DIRECTEDGRAPHPLUGIN_VECTORFORMATS')
      || 'none';

    # Get plugin engine default
    $engineDefault =
      TWiki::Func::getPreferencesValue('DIRECTEDGRAPHPLUGIN_ENGINE') || 'dot';

    # Get plugin library default
    $libraryDefault =
      TWiki::Func::getPreferencesValue('DIRECTEDGRAPHPLUGIN_LIBRARY')
      || 'TWiki.DirectedGraphPlugin';

    # Get plugin hideattachments default
    $hideAttachDefault =
      TWiki::Func::getPreferencesValue('DIRECTEDGRAPHPLUGIN_HIDEATTACHMENTS')
      || 'on';

    # Get the default inline  attachment default
    $inlineAttachDefault =
      TWiki::Func::getPreferencesValue('DIRECTEDGRAPHPLUGIN_INLINEATTACHMENT')
      || 'png';

    # Get the default fallback format for SVG output
    $svgFallbackDefault =
      TWiki::Func::getPreferencesValue('DIRECTEDGRAPHPLUGIN_SVGFALLBACK')
      || 'png';

    # Get the default for overriding SVG link target.
    $svgLinkTargetDefault =
      TWiki::Func::getPreferencesValue('DIRECTEDGRAPHPLUGIN_SVGLINKTARGET')
      || 'on';

    # Get the default link file attachment default
    $linkFilesDefault =
      TWiki::Func::getPreferencesValue('DIRECTEDGRAPHPLUGIN_LINKATTACHMENTS')
      || 'on';

    # Get plugin deleteattachments default
    $deleteAttachDefault = TWiki::Func::getPreferencesValue(
        'DIRECTEDGRAPHPLUGIN_DELETEATTACHMENTS')
      || 'off';

    # Get plugin legacycleanup default
    $legacyCleanup =
      TWiki::Func::getPreferencesValue('DIRECTEDGRAPHPLUGIN_LEGACYCLEANUP')
      || 'off';

    # Get plugin force API default
    $forceAttachAPIDefault =
      TWiki::Func::getPreferencesValue('DIRECTEDGRAPHPLUGIN_FORCEATTACHAPI')
      || 'off';

    # Read in the attachment information from previous runs
    #  and save it into a session variable for use by the tag handlers
    # Also clear the new attachment table that will be built from this run

    my %oldHashArray =
      _loadHashCodes();    # Load the -filehash file into the old hash
    TWiki::Func::setSessionValue( 'DGP_hash', freeze \%oldHashArray );
    TWiki::Func::clearSessionValue('DGP_newhash')
      ;                    # blank slate for new attachments

    # Tell WyswiygPlugin to protect <dot>...</dot> markup
    if ( defined &TWiki::Plugins::WysiwygPlugin::addXMLTag ) {

        # Check if addXMLTag is defined, so that DirectedGraphPlugin
        # continues to work with older versions of WysiwygPlugin
        &_writeDebug(" DISAABLE the dot tag in WYSIWYIG ");
        TWiki::Plugins::WysiwygPlugin::addXMLTag( 'dot', sub { 1 } );

# Some older versions of the plugin used upper-case DOT tags - protect these as well.
        TWiki::Plugins::WysiwygPlugin::addXMLTag( 'DOT', sub { 1 } );
    }

    # Plugin correctly initialized
    &_writeDebug(
"- TWiki::Plugins::DirectedGraphPlugin::initPlugin( $web.$topic ) initialized OK"
    );

    return 1;
}    ### sub initPlugin

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    return if $_[3];    # Called in an include; do not process DOT macros

    $topic = $_[1];     # Can't trust globals
    $web   = $_[2];
    $usWeb = $web;
    $usWeb =~ s/\//_/g;    #Convert any subweb separators to underscore

    &_writeDebug("- DirectedGraphPlugin::commonTagsHandler( $_[2].$_[1] )");

    #pass everything within <dot> tags to handleDot function

    ( $_[0] =~ s/<DOT(.*?)>(.*?)<\/(DOT)>/&_handleDot($2,$1)/giseo );

# $3 will be left set if any matches were found in the topic.  If found, do cleanup processing
    if ( $3 && ( $3 eq 'dot' ) ) {
        &_writeDebug("DirectedGraphPlugin - FOUND MATCH  -  $3");
        wrapupTagsHandler();
    }

    &_writeDebug(' <<< EXIT  commonTagsHandler  ');

}    ### sub commonTagsHandler

# =========================
sub _handleDot {
    &_writeDebug(' >>> _handleDot Entered ');

    unless( $sandbox ) {
        if( $TWiki::Plugins::VERSION >= 1.1 ) {
            # Dakar provides a sandbox
            $sandbox = $TWiki::sharedSandbox ||
            $TWiki::sandbox;    # for TWiki 4.2
        } else {
            # in Cairo, must use the contrib package
            eval("use TWiki::Contrib::DakarContrib;");
            $sandbox = new TWiki::Sandbox();
        }
    }

  # Retrieve new attachments hash from the session variable from previous passes
    my %newHashArray = ();
    my $newHashRef   = thaw( TWiki::Func::getSessionValue('DGP_newhash') );
    if ($newHashRef) {
        %newHashArray = %{$newHashRef};
    }
    else {
        &_writeDebug(' _handleDot is initializing the newHashArray');
        $newHashArray{SET} =
          1;    # Tell afterCommonTagsHandler that commonTagsHandler has run.
        $newHashArray{GRNUM} = 0;    # Initialize graph count
    }

    my %oldHashArray = ();
    my $oldHashRef   = thaw( TWiki::Func::getSessionValue('DGP_hash') );
    if ($oldHashRef) {
        %oldHashArray = %{$oldHashRef};
    }

    my $tempdir = '';

    if ( defined $TWiki::cfg{TempfileDir} ) {
        $tempdir = $TWiki::cfg{TempfileDir};
    }
    else {
        $tempdir = File::Spec->tmpdir();
    }

    my $attr = $_[1] || '';   # Attributes from the <dot ...> tag
    my $desc = $_[0] || '';   # GraphViz input between the <dot> ... </dot> tags

    my $grNum = $newHashArray{GRNUM};

    my %params = TWiki::Func::extractParameters($attr)
      ;                       #extract all parms into a hash array

    # parameters with defaults set in the DirectedGraphPlugin topic.
    my $antialias     = $params{antialias}       || $antialiasDefault;
    my $density       = $params{density}         || $densityDefault;
    my $size          = $params{size}            || $sizeDefault;
    my $vectorFormats = $params{vectorformats}   || $vectorFormatsDefault;
    my $engine        = $params{engine}          || $engineDefault;
    my $library       = $params{library}         || $libraryDefault;
    my $hideAttach    = $params{hideattachments} || $hideAttachDefault;
    my $inlineAttach  = $params{inline}          || $inlineAttachDefault;
    $forceAttachAPI = $params{forceattachapi} || $forceAttachAPIDefault;
    my $linkFiles     = $params{linkfiles}     || $linkFilesDefault;
    my $svgFallback   = $params{svgfallback}   || $svgFallbackDefault;
    my $svgLinkTarget = $params{svglinktarget} || $svgLinkTargetDefault;

    # parameters with hardcoded defaults
    my $outFilename = $params{file}    || '';
    my $doMap       = $params{map}     || '';
    my $dotHash     = $params{dothash} || 'on';

    # Global parameters only specified in the DirectedGraphPlugin topic.
    # $debugDefault
    # $deleteAttachDefault
    # $legacyCleanup

# Strip all trailing white space on any parameters set by set statements - WYSIWYG seems to pad it.
    $antialias           =~ s/\s+$//;
    $density             =~ s/\s+$//;
    $size                =~ s/\s+$//;
    $vectorFormats       =~ s/\s+$//;
    $engine              =~ s/\s+$//;
    $library             =~ s/\s+$//;
    $hideAttach          =~ s/\s+$//;
    $inlineAttach        =~ s/\s+$//;
    $deleteAttachDefault =~ s/\s+$//;
    $forceAttachAPI      =~ s/\s+$//;

    # Make sure outFilename is clean
    $outFilename = TWiki::Sandbox::sanitizeAttachmentName($outFilename)
      if ( $outFilename ne '' );

    # clean up parms
    if ( $antialias =~ m/off/o ) {
        $antialias = 0;
    }

    #
    ###  Validate all of the <dot ...> input parameters
    #

    unless ( $density =~ m/^\d+$/o ) {
        return
"<font color=\"red\"><nop>DirectedGraph Error: density parameter should be given as a number (was: $density)</font>";
    }

    unless ( $size =~ m/^\d+x\d+|auto$/o ) {
        return
"<font color=\"red\"><nop>DirectedGraph Error: size parameter should be given in format: \"widthxheight\", or \"auto\" (was: $size)</font>";
    }

    unless ( $engine =~ m/^(dot|neato|twopi|circo|fdp)$/o ) {
        return
"<font color=\"red\"><nop>DirectedGraph Error: engine parameter must be one of the following: dot, neato, twopi, circo or fdp (was: $engine)</font>";
    }

    unless ( $dotHash =~ m/^(on|off)$/o ) {
        return
"<font color=\"red\"><nop>DirectedGraph Error: dothash must be either \"off\" or \"on\" (was: $dotHash)</font>";
    }

    unless ( $hideAttach =~ m/^(on|off)$/o ) {
        return
"<font color=\"red\"><nop>DirectedGraph Error: hideattachments  must be either \"off\" or \"on\" (was: $hideAttach)</font>";
    }

    unless ( $linkFiles =~ m/^(on|off)$/o ) {
        return
"<font color=\"red\"><nop>DirectedGraph Error: links  must be either \"off\" or \"on\" (was: $linkFiles)</font>";
    }

    unless ( $inlineAttach =~ m/^(png|jpg|svg)$/o ) {
        return
"<font color=\"red\"><nop>DirectedGraph Error: inline  must be either \"jpg\", \"png\" or \"svg\" (was: $inlineAttach)</font>";
    }

    unless ( $svgFallback =~ m/^(png|jpg|none)$/o ) {
        return
"<font color=\"red\"><nop>DirectedGraph Error: svg fallback must be either \"png\" or \"jpg\", or set to \"none\" to disable (was: $svgFallback)</font>";
    }

    unless ( $svgLinkTarget =~ m/^(on|off)$/o ) {
        return
"<font color=\"red\"><nop>DirectedGraph Error: svg Link Target must either be \"on\" or \"off\" (was: $svgLinkTarget)</font>";
    }

    unless ( $deleteAttachDefault =~ m/^(on|off)$/o ) {
        return
"<font color=\"red\"><nop>DirectedGraph Error in defaults: DELETEATTACHMENTS  must be either \"off\" or \"on\" (was: $deleteAttachDefault)</font>";
    }

    unless ( $forceAttachAPI =~ m/^(on|off)$/o ) {
        return
"<font color=\"red\"><nop>DirectedGraph Error in defaults: FORCEATTACHAPI  must be either \"off\" or \"on\" (was: $forceAttachAPI)</font>";
    }

    my $hide = undef;
    if ( $hideAttach =~ m/off/o ) {
        $hide = 0;
    }
    else {
        $hide = 1;
    }

    my $chkHash = undef;
    if ( $dotHash =~ m/off/o ) {
        $chkHash = 0;
    }
    else {
        $chkHash = 1;
    }

# SMELL:  This is not safe for the Store rewrite.
# Need to copy library attachments to a temporary directory for access by graphViz!

    $library =~ s/\./\//;
    my $workingDir = TWiki::Func::getPubDir() . "/$library";
    unless ( -e "$workingDir" ) {
        return
"<font color=\"red\"><nop>DirectedGraph Error: library parameter should point to topic with attachments to use: <br /> <nop>Web.TopicName (was: $library)  <br /> pub dir is $workingDir </font>";
    }

    # compatibility: check for old map indicator format (map=1 without quotes)
    if ( $attr =~ m/map=1/o ) {
        $doMap = 1;
    }

    &_writeDebug(
"incoming: $desc, $attr , antialias = $antialias, density = $density, size = $size, vectorformats = $vectorFormats, engine = $engine, library = $library, doMap = $doMap, hash = $dotHash \n"
    );

    foreach my $prm ( keys(%params) ) {
        &_writeDebug("PARAMETER $prm value is $params{$prm}");
    }

    # compute the MD5 hash of this string.  This used to detect
    # if any parameters or input change from run to run
    # Attachments recreated if the hash changes

# Hash is calculated against the <dot> command parameters and input,
# along with any parameters that are set in the Default topic which would modify the results.
# Parameters that are only set as part of the <dot> command do not need to be explicitly coded,
# as they are include in $attr.

    my $hashCode =
      md5_hex( 'DOT' 
          . $desc 
          . $attr
          . $antialias
          . $density
          . $size
          . $vectorFormats
          . $engine
          . $library
          . $hideAttach
          . $inlineAttach );

    # If a filename is not provided, set it to a name, with incrementing number.
    if ( $outFilename eq '' ) {    #no filename?  Create a new name
        $grNum++;                  # increment graph number.
        $outFilename = 'DirectedGraphPlugin_' . "$grNum";
    }

    # Make sure vectorFormats includes all required file types
    $vectorFormats =~ s/,/ /g;     #Replace any comma's in the list with spaces.
    $vectorFormats .= ' ' . $inlineAttach
      if !( $vectorFormats =~ m/$inlineAttach/ )
    ;                              # whatever specified inline is mandatory
    $vectorFormats .= ' ' . "$svgFallback"
      if ( $inlineAttach =~ m/svg/ && $svgFallback ne 'none' )
      ;    # Generate png if SVG is inline - for browser fallback

    $vectorFormats .= ' ps'
      if ( ($antialias)
        && !( $vectorFormats =~ m/ps/ )
        && !( $inlineAttach  =~ m/svg/ ) )
      ;    # postscript for antialias or as requested
    $vectorFormats .= ' cmapx'
      if ( ($doMap) && !( $vectorFormats =~ m/cmapx/ ) );    # client side map
    $vectorFormats =~ s/none//g;    # remove the "none" if set by default

    my %attachFile
      ;    # Hash to store attachment file names - key is the file type.

    my $oldHashCode = $oldHashArray{MD5HASH}{$outFilename}
      || ' ';    # retrieve hash code for filename

    $newHashArray{MD5HASH}{$outFilename} = $hashCode; # hash indexed by filename
    $newHashArray{FORMATS}{$outFilename} =
      $vectorFormats;    # output formats for eventual cleanup

    &_writeDebug("$outFilename: oldhash = $oldHashCode  newhash = $hashCode");

# Initialize the attachment filenames and copy over image sizes from the old hash.
    foreach my $key ( split( ' ', $vectorFormats ) ) {
        if ( $key ne 'none' ) {    # skip the bogus default
            $attachFile{$key} = "$outFilename.$key";
            $newHashArray{IMAGESIZE}{ $outFilename . $key } =
              $oldHashArray{IMAGESIZE}{ $outFilename . $key }
              || '';               # Copy the image size
        }    ### if ($key ne 'none'
    }    ### foreach my $key

    #  #######################################################
    #  Generate the attachments if hash or missing files require
    #  ########################################################

    #  If the hash codes don't match, the graph needs to be recreated
    #  otherwise just use the previous graph already attached.
    #  Also check if the inline attachment is missing and recreate if needed

    if ( ( ( $oldHashCode ne $hashCode ) && $chkHash ) |
        not _attachmentExists( $web, $topic, "$outFilename.$inlineAttach" ) )
    {

        &_writeDebug(
" >>> Processing changed dot tag or missing file $outFilename.$inlineAttach <<< "
        );

        my $outString = '';
        my %tempFile;

        foreach my $key ( keys(%attachFile) ) {
            if ( !exists( $tempFile{$key} ) ) {
                $tempFile{$key} = new File::Temp(
                    TEMPLATE => 'DGPXXXXXXXXXX',
                    DIR      => $tempdir,
                    UNLINK =>
                      0,    #  Manually unlink later if debug not specified.
                    SUFFIX => ".$key"
                );
                $outString .= "-T$key -o$tempFile{$key} ";
            }    ### if (!exists ($tempFile
        }    ### foreach my $key

        # Create a new temporary file to pass to GraphViz
        my $dotFile = new File::Temp(
            TEMPLATE => 'DiGraphPluginXXXXXXXXXX',
            DIR      => $tempdir,
            UNLINK => 0,       # Manually unlink later if debug not specified
            SUFFIX => '.dot'
        );
        TWiki::Func::saveFile( "$dotFile", $desc );

        my $debugFile = '';
        if ($debugDefault) {
            $debugFile = new File::Temp(
                TEMPLATE => 'DiGraphPluginRunXXXXXXXXXX',
                DIR      => $tempdir,
                UNLINK => 0,      # Manually unlink later if debug not specified
                SUFFIX => '.log'
            );
        }

        #  Execute dot - generating all output into the TWiki temp directory
        my ( $output, $status ) = $sandbox->sysCommand(
            $perlCmd . $engineCmd,
            HELPERSCRIPT => $toolsPath . $dotHelper,
            DOT          => $enginePath . $engine,
            WORKDIR      => $workingDir,
            INFILE       => "$dotFile",
            IOSTRING     => $outString,
            ERRFILE      => "$dotFile" . '.err',
            DEBUGFILE    => "$debugFile"
        );

        if ($status) {
            $dotFile =~ tr!\\!/!;
            unlink $dotFile unless $debugDefault;
            return _showError(
                $status,
                $output,
                "Processing $toolsPath$dotHelper - $enginePath$engine: <br />"
                  . $desc,
                $dotFile . '.err'
            );
        }    ### if ($status)
        $dotFile =~ tr!\\!/!;
        unlink "$dotFile.err" unless $debugDefault;
        unlink $dotFile unless $debugDefault;

        if (
            ($antialias)
            && (   ( $inlineAttach eq 'svg' && $svgFallback ne 'none' )
                || ( $inlineAttach ne 'svg' ) )
          )
        {    # Convert the postscript image to the inline format

            my $inlineType = "$tempFile{$inlineAttach}";
            if ( $inlineAttach eq 'svg' ) {
                my $inlineType = "$tempFile{$svgFallback}";
            }

            my ( $output, $status ) =
              $sandbox->sysCommand( $magickPath . $identifyCmd,
                INFILE => "$inlineType", );

            &_writeDebug(" _____IDENTIFY_____ $output");

            #$size = "auto";
            if (   $size eq "auto"
                && $output =~ m/.*\s([[:digit:]]+x[[:digit:]]+)\s.*/i )
            {
                &_writeDebug(" ______________ size $1");
                $size = $1;
            }

            ( $output, $status ) = $sandbox->sysCommand(
                $magickPath . $antialiasCmd,
                DENSITY  => $density,
                GEOMETRY => $size,
                INFILE   => "$tempFile{'ps'}",
                OUTFILE  => "$inlineType"
            );
            &_writeDebug("dgp-antialias: output: $output \n status: $status");
            if ($status) {
                return &_showError( $status, $output,
                    "Processing $magickPath.$antialiasCmd <br />" . $desc );
            }    ### if ($status)
        }    ### if ($antialias)

        ### Attach all of the files to the topic.  If a hard path is specified,
        ### then use perl file I/O, otherwise use TWiki API.
        &_writeDebug(
"### forceAttachAPI = |$forceAttachAPI|  attachPath = |$attachPath| "
        );

        #
        foreach my $key ( keys(%attachFile) ) {

# Get the images size for inline images so that the <object> or <img> tag can be built with the
# correct size.  Reserve # space in the browser to speed rendering a bit, and ensure SVG displays correctly.

            if ( ( $key eq $inlineAttach ) || ( $key eq $svgFallback ) ) {
                my ( $imgSize, $status ) = $sandbox->sysCommand(
                    $magickPath . $identifyCmd,
                    INFILE => "$tempFile{$key}",
                );

                &_writeDebug(
" _____IDENTIFY_____ $tempFile{$key}: OBJSIZE  $imgSize - STATUS $status"
                );
                $imgSize =~
s/.*\s([[:digit:]]+)x([[:digit:]]+)\s.*/width="$1" height="$2"/i;
                &_writeDebug(" _____MODIFIED $imgSize");
                chomp $imgSize;
                $newHashArray{IMAGESIZE}{ $outFilename . $key } = $imgSize;
            }

#  As of IE 7 / FF 3.0 and 3.5,  the only way to get consistent link behavior for
#  embedded links is to add target="_top".   Any other setting - IE opens the
#  link in the current page, FF opens the link within the svg object on the page.
#  This code overrides the target in the generated svg file for consistent operation.

            if ( ( $key eq 'svg' ) && ( $svgLinkTarget eq 'on' ) ) {
                my $svgfile = TWiki::Func::readFile("$tempFile{$key}");
                $svgfile =~ s/xlink\:href/target=\"_top\" xlink:href/g;
                TWiki::Func::saveFile( "$tempFile{$key}", "$svgfile" );
            }

# the "dot" suffix use for the directed graph input will be detected as a msword template
# by most servers/browsers.  Rename the dot file to dot.txt suffix.
#
            my $fname = "$attachFile{$key}";
            $fname .= '.txt' if ( $key eq 'dot' );

            if ( ($attachPath) && !( $forceAttachAPI eq 'on' ) ) {
                &_writeDebug(
                    "attaching $attachFile{$key} using direct file I/O  ");
                _make_path( $topic, $web );
                umask(002);
                my $tempoutfile = "$attachPath/$web/$topic/$fname";
                $tempoutfile = TWiki::Sandbox::untaintUnchecked($tempoutfile)
                  ;    #untaint - fails in Perl 5.10
                copy( "$tempFile{$key}", $tempoutfile );
            }
            else {
                my @stats    = stat $tempFile{$key};
                my $fileSize = $stats[7];
                my $fileDate = $stats[9];
                &_writeDebug(
"attaching $fname using TWiki API - Web = $web,  Topic = $topic, File=$tempFile{$key} Type = $key Size $fileSize date $fileDate"
                );
                $fname = TWiki::Sandbox::untaintUnchecked($fname)
                  ;    #untaint - fails on trunk
                TWiki::Func::saveAttachment(
                    $web, $topic, "$fname",
                    {
                        file     => "$tempFile{$key}",
                        filedate => $fileDate,
                        filesize => $fileSize,
                        comment  => '<nop>DirectedGraphPlugin: DOT graph',
                        hide     => $hide
                    }
                );
            }    # else if ($attachPath)
            $tempFile{$key} =~ tr!\\!/!;
            unlink $tempFile{$key} unless $debugDefault;
        }    ### foreach my $key (keys...

        &_writeDebug('attaching Files completed ');

    }    ### else [ if ($oldHashCode ne $hashCode) |

    $newHashArray{GRNUM} = $grNum;
    TWiki::Func::setSessionValue( 'DGP_newhash', freeze \%newHashArray );

    #  ##############################
    #  End Generation of attachments
    #  ###############################

    #  Build the path to use for attachment URL's
    #  $attachUrlPath is used only if attachments are stored in an explicit path
    #  and $attachUrlPath is provided,  and use of the API is not forced.

    my $urlPath = undef;
    if ( ($attachPath) && ($attachUrlPath) && !( $forceAttachAPI eq 'on' ) ) {
        $urlPath = $attachUrlPath;
    }
    else {
        $urlPath = TWiki::Func::getPubUrlPath();
    }

    #  Build a manual link for each specified file type except for
    #  The "inline" file format, and any image map file

    my $fileLinks = '';
    if ($linkFiles) {
        $fileLinks = '<br />';
        foreach my $key ( keys(%attachFile) ) {
            if ( ( $key ne $inlineAttach ) && ( $key ne 'cmapx' ) ) {
                my $fname = $attachFile{$key};
                $fname .= '.txt' if ( $key eq 'dot' );
                $fileLinks .=
                    '<a href=' 
                  . $urlPath
                  . TWiki::urlEncode("/$web/$topic/$fname")
                  . ">[$key]</a> ";
            }    # if (($key ne
        }    # foreach my $key
    }    # if ($linkFiles

    my $mapfile = '';
    if ($doMap) {

        # read and format map
        if ( ($attachPath) && ($attachUrlPath) && !( $forceAttachAPI eq 'on' ) )
        {
            $mapfile = TWiki::Func::readFile(
                "$attachPath/$web/$topic/$outFilename.cmapx");
            &_writeDebug("MAPFILE $outFilename.cmapx is  $mapfile");
        }
        else {
            if (
                TWiki::Func::attachmentExists(
                    $web, $topic, "$outFilename.cmapx"
                )
              )
            {
                $mapfile = TWiki::Func::readAttachment( $web, $topic,
                    "$outFilename.cmapx" );
            }
        }
        if ($mapfile) {    #If mapfile is empty for some reason, these will fail
            $mapfile =~
s/(<map\ id\=\")(.*?)(\"\ name\=\")(.*?)(\">)/$1$hashCode$3$hashCode$5/go;
            $mapfile =~ s/[\n\r]/ /go;
        }
        else {
            $mapfile = '';
        }
    }

    my $loc        = $urlPath . "/$web/$topic";
    my $src        = TWiki::urlEncode("$loc/$outFilename.$inlineAttach");
    my $returnData = '';

    my $fbtype =
      $inlineAttach;   # If not a SVG, fallback image becomes the primary image.

    $returnData = "<noautolink>\n";

    $returnData .= "$mapfile\n" if ($doMap);

    if ( $inlineAttach eq 'svg' ) {
        $fbtype = "$svgFallback";
        $returnData .=
          "<object data=\"$src\" type=\"image/svg+xml\" border=\"0\" "
          . $newHashArray{IMAGESIZE}{ $outFilename . $inlineAttach };
        $returnData .= " alt=\"$outFilename.$inlineAttach diagram\"";
        $returnData .= "> \n";
    }

# This is either the fallback image, or the primary image if not generating an inline SVG

    if (   ( $inlineAttach eq 'svg' && $svgFallback ne 'none' )
        || ( $inlineAttach ne 'svg' ) )
    {
        my $srcfb = TWiki::urlEncode("$loc/$outFilename.$fbtype");
        $returnData .=
          "<img src=\"$srcfb\" type=\"image/$fbtype\" "
          . $newHashArray{IMAGESIZE}
          { $outFilename . $fbtype };    #Embedded img tag for fallback
        $returnData .= " usemap=\"#$hashCode\""
          if ($doMap);                   #Include the image map if required
        $returnData .= " alt=\"$outFilename.$inlineAttach diagram\"";
        $returnData .= "> \n";
    }

    $returnData .= "</object>\n" if ( $inlineAttach eq "svg" );

    $returnData .= "</noautolink>";
    $returnData .= $fileLinks;

    return $returnData;

}    ### sub handleDot

### sub _showError
#
#   Display any GraphViz reported errors inline into the file
#   For easier debuggin of malformed <dot> tags.

sub _showError {
    my ( $status, $output, $text, $errFile ) = @_;

    # Check error file for detailed report from graphviz binary
    if ( defined $errFile && $errFile && -s $errFile ) {
        open( ERRFILE, $errFile );
        my @errLines = <ERRFILE>;
        $text =
            "*DirectedGraphPlugin error:* <verbatim>"
          . join( "", @errLines )
          . "</verbatim>";
        $errFile =~ tr!\\!/!;
        ($errFile) = ( $errFile =~ /(.*)/ );    # untaint $errFile for unlink
        unlink $errFile unless $debugDefault;
    }

    my $line = 1;
    $text =~ s/\n/sprintf("\n%02d: ", $line++)/ges if ($text);
    $output .= "<pre>$text\n</pre>";
    return
      "<font color=\"red\"><nop>DirectedGraph Error ($status): $output</font>";
}    ### sub _showError

### sub _writeDebug
#
#   Writes a common format debug message if debug is enabled

sub _writeDebug {
    &TWiki::Func::writeDebug( 'DirectedGraphPlugin - ' . $_[0] )
      if $debugDefault;
}    ### SUB _writeDebug

### sub afterRenameHandler
#
#   This routine will rename or delete any workarea files.  If topic is renamed
#   to the Trash web, then the workarea files are simply removed, otherwise they
#   are renamed to the new Web and topic name.

sub afterRenameHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment ) = @_;

    my $oldweb = $_[0];
    $oldweb =~ s/\//_/g;    # convert subweb separators to underscore
    my $oldtopic = $_[1];
    my $newweb   = $_[3];
    $newweb =~ s/\//_/g;    # convert subweb separators to underscore
    my $newtopic    = $_[4];
    my $workAreaDir = TWiki::Func::getWorkArea('DirectedGraphPlugin');

    &_writeDebug( "- DirectedGraphPlugin::afterRenameHandler( "
          . "$_[0].$_[1] $_[2] -> $_[3].$_[4] $_[5] )" );

    # Find all files in the workarea directory for the old topic
    # rename them unless new web is Trash, otherwise delete them.
    #
    # files are named any of $web_$topic_DirectedGraphPlugin_n
    #                     or $web_$topic_<user specified name>
    #                     or $web_$topic-filehash
    #

    opendir( DIR, $workAreaDir )
      || die "<ERR> Can't find directory --> $workAreaDir !";

    my @wfiles = grep { /^${oldweb}_${oldtopic}-/ } readdir(DIR);
    foreach my $f (@wfiles) {
        my $prefix = "${oldweb}_${oldtopic}-";
        my ($suffix) = ( $f =~ "^$prefix(.*)" );
        $f = TWiki::Sandbox::untaintUnchecked($f);
        if ( $newweb eq 'Trash' ) {
            unlink "$workAreaDir/$f";
        }
        else {
            my $newname = "${newweb}_${newtopic}-${suffix}";
            $newname = TWiki::Sandbox::untaintUnchecked($newname);
            &_writeDebug(" Renaming $workAreaDir/$f to $workAreaDir/$newname ");
            rename( "$workAreaDir/$f", "$workAreaDir/$newname" );
        }
    }
}    ### sub afterRenameHandler

### sub _loadHashCodes
#
#   This routine loads the hash array from the stored file in the workarea directory
#   It also will convert any older style hash files into the new single file written
#   by the Storable routines.

sub _loadHashCodes {

    my $workAreaDir = TWiki::Func::getWorkArea('DirectedGraphPlugin');

    opendir( DIR, $workAreaDir )
      || die "<ERR> Can't find directory --> $workAreaDir !";

    my %tempHash;

    if ( -e "$workAreaDir/${usWeb}_${topic}-filehash" ) {
        &_writeDebug(' loading filehash  ');
        my $hashref = retrieve("$workAreaDir/${usWeb}_${topic}-filehash");
        %tempHash = %$hashref;
        return %tempHash;
    }

    return %tempHash unless ( $legacyCleanup eq 'on' );

    ### Temporary Code - Convert file hash codes
    ### and delete the old files from the workarea
    ### Also insert any old format attachments into the table
    ### for later cleanup.

    my %typeHash;

    # Get all the attachments filenames and extract their types
    &_writeDebug(' entering legacy cleanup routine  ');

    my ( $met, $tex ) = TWiki::Func::readTopic( $web, $topic );
    my @attachments = $met->find('FILEATTACHMENT');
    &_writeDebug(' converting old filehash  ');
    foreach my $a (@attachments) {
        my $aname = $a->{name};
        my ( $n, $t ) = $aname =~ m/^(.*)\.(.*)$/;    # Split file name and type
        next unless $t;    # If no type, skip it, it's not ours.
        &_writeDebug("    - Attach = |$aname| Name = |$n| Type = |$t| ");
        $typeHash{$n} .= ' ' . $t;
        my ($on) = $n =~
          m/^graph([0-9a-f]{32})$/;   # old style attachment graph<hashcode>.xxx
        if ($on) {
            $tempHash{MD5HASH}{$n} = $on;
            $tempHash{FORMATS}{$n} .= ' ' . $t;
        }                             # if ($on)
    }    # foreach my $a

    # Read in all of the hash files for the generated attachments
    # and build a new format hash table.

    my $fPrefix = $usWeb . '_' . $topic . '_';
    my @wfiles = grep { /^$fPrefix/ } readdir(DIR);
    &_writeDebug(" unlinking old hash files for $fPrefix");
    foreach my $f (@wfiles) {
        my $key = TWiki::readFile("$workAreaDir/$f");
        $f = TWiki::Sandbox::untaintUnchecked($f);
        unlink "$workAreaDir/$f";    # delete the old style hash file
        &_writeDebug(" unlinking old filehash $workAreaDir/$f  ");
        $f =~ s/^${usWeb}_${topic}_(.*)/$1/g
          ;                          # recover the original attachment filename
        $tempHash{FORMATS}{$f} =
          $typeHash{$f};    # insert hash of types found in attachment table
        $tempHash{MD5HASH}{$f} = $key;    # insert hash indexed by filename
        &_writeDebug(
            "$f = |$tempHash{MD5HASH}{$f}| types |$tempHash{FORMATS}{$f}| ");
    }

    # Write out new hashfile
    if ( keys %tempHash ) {
        &_writeDebug("    - Writing hashfile ");
        store \%tempHash, "$workAreaDir/${usWeb}_${topic}-filehash";
    }
    return %tempHash;

}    ### sub _loadHashCodes

#
#  sub wrapupTagsHandler
#   - Find any files or file types that are no longer needed
#     and move to Trash with a unique name.
#
sub wrapupTagsHandler {

    &_writeDebug(' >>> wrapupTagsHandler  entered ');

    my %newHash    = ();
    my $newHashRef = thaw( TWiki::Func::getSessionValue('DGP_newhash') );

    if ($newHashRef) {    # DGP_newhash existed
        &_writeDebug('     -- newHashRef existed in session - writing out ');
        %newHash = %{$newHashRef};
        my $workAreaDir = TWiki::Func::getWorkArea('DirectedGraphPlugin');
        store \%newHash, "$workAreaDir/${usWeb}_${topic}-filehash";

        if ( $newHash{SET} ) {    # dot tags have been processed
            my %oldHash    = ();
            my $oldHashRef = thaw( TWiki::Func::getSessionValue('DGP_hash') );
            if ($oldHashRef) { %oldHash = %{$oldHashRef}; }

            &_writeDebug(" afterCommon - Value of SET s $newHash{SET} ");
            &_writeDebug(" delete = $deleteAttachDefault");
            &_writeDebug( ' keys = ' . ( keys %oldHash ) );

            if ( ($deleteAttachDefault) && ( keys %oldHash ) )
            {                     # If there are any old files to deal with
                foreach my $filename ( keys %{ $oldHash{FORMATS} } )
                {                 # Extract filename
                    my $oldTypes = $oldHash{FORMATS}{$filename} || '';
                    if ($debugDefault) {
                        &_writeDebug("old  $filename ... types= $oldTypes ");
                        &_writeDebug(
"new  $filename ... types= $newHash{FORMATS}{$filename} "
                        );
                    }             ### if ($debugDefault
                    if ($oldTypes) {
                        foreach my $oldsuffix ( split( ' ', $oldTypes ) ) {
                            if (
                                ( !defined $newHash{FORMATS}{$filename} )
                                || ( !$newHash{FORMATS}{$filename} =~
                                    (/$oldsuffix/) )
                              )
                            {
                                _deleteAttach("$filename.$oldsuffix");
                                _deleteAttach("$filename.$oldsuffix.txt")
                                  if ( $oldsuffix eq 'dot' );
                            }     ### if (%newHash
                        }    ### foreach my $olsduffix
                    }    ### if ($oldTypes)
                }    ### foreach my $filename
            }    ### if (keys %{$oldHash

            # Clear the session values
            TWiki::Func::clearSessionValue('DGP_hash');
            TWiki::Func::clearSessionValue('DGP_newhash');
        }    ### if ($newHash{SET}
    }    ### if ($newHashRef)

}    ### sub wrapupTagsHandler

### sub _deleteAttach
#
#   Handles moving unneeded attachments to the Trash web with a new name which includes
#   the Web name and Topic name.  On older versions of TWiki, it simply deleted the files
#   with perl's unlink.  Also use unlink if direct file I/O requested.

sub _deleteAttach {

    my $fn = TWiki::Sandbox::normalizeFileName( $_[0] );

    &_writeDebug(" DELETE ATTACHMENT entered for $fn");

    if ( _attachmentExists( $web, $topic, $fn ) ) {

        if ( ($attachPath) && !( $forceAttachAPI eq 'on' ) )
        {    # Direct file I/O requested
            unlink "$attachPath/$web/$topic/$fn";
            &_writeDebug(" ### Unlinked $attachPath/$web/$topic/$fn ");

        }
        else {    # TWiki attach API used
                  # If the TrashAttachment topic is missing, create it.
            if (
                !TWiki::Func::topicExists(
                    $TWiki::cfg{TrashWebName},
                    'TrashAttachment'
                )
              )
            {
                &_writeDebug(' ### Creating missing TrashAttachment topic ');
                my $text =
                  "---+ %MAKETEXT{\"Placeholder for trashed attachments\"}%\n";
                TWiki::Func::saveTopic( "$TWiki::cfg{TrashWebName}",
                    "TrashAttachment", undef, $text, undef );
            }    # if (! TWiki::Func::topicExists

            &_writeDebug(" >>> Trashing $web . $topic . $fn");

            my $i  = 0;
            my $of = $fn;
            while (
                TWiki::Func::attachmentExists(
                    $TWiki::cfg{TrashWebName}, 'TrashAttachment',
                    "$web.$topic.$of"
                )
              )
            {
                &_writeDebug(" ------ duplicate in trash  $of");
                $i++;
                $of .= "$i";
            }    # while (TWiki::Func

            TWiki::Func::moveAttachment( $web, $topic, $fn,
                $TWiki::cfg{TrashWebName},
                'TrashAttachment', "$web.$topic.$of" );
        }    # else if ($attachPath)
    }    # _attachmentExists
}    ### sub _deleteFile

#
#  _make_path
#    For direct file i/o, make sure the target directory exists
#    returns the target directory for the attachments.
#
sub _make_path {
    my ( $topic, $web ) = @_;

    my @webs = split( '/', $web );    # Split web in case subwebs are present
    my $dir = $attachPath || TWiki::Func::getPubDir();

    foreach my $val (@webs) {         # Process each subweb in the web path
        $dir .= '/' . $val;
        if ( !-e $dir ) {
            umask(002);
            mkdir( $dir, 0775 );
        }                             # if (! -e $dir
    }    # foreach

    # If the top level "pub/$web/$topic" directory doesn't exist, create
    # it.
    $dir .= '/' . $topic;
    if ( !-e "$dir" ) {
        umask(002);
        mkdir( $dir, 0775 );
    }

    # Return the complete path to target directory
    return ($dir);
}    ### sub _make_path

#
# _attachmentExists
#    Check if attachment exists - use TWiki API or direct file I/O
#
sub _attachmentExists {
    my ( $web, $topic, $fn ) = @_;

    if ( ($attachPath) && !( $forceAttachAPI eq 'on' ) ) {
        return ( -e "$attachPath/$web/$topic/$fn" );
    }
    else {
        return TWiki::Func::attachmentExists( $web, $topic, $fn );
    }
}

1;

