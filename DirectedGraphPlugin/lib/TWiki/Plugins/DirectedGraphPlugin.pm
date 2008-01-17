# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2005 Cole Beck, cole.beck@vanderbilt.edu
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
# Each plugin is a package that may contain these functions:        VERSION:
#
#   initPlugin              ( $topic, $web, $user, $installWeb )    1.000
#   commonTagsHandler       ( $text, $topic, $web )                 1.000
#
# =========================
#
# This plugin creates a png file by using the graphviz dot command.
# See http://www.graphviz.org/ for more information.
# Note that png files created with this plugin can only be deleted manually;
# it stays there even after the dot tags are removed.

package TWiki::Plugins::DirectedGraphPlugin;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $pluginName
  $debug $exampleCfgVar $sandbox $isInitialized $antialiasDefault
  $densityDefault $sizeDefault $vectorFormatsDefault $engineDefault
  $libraryDefault $enginePath $magickPath $workAreaDir $grNum
  $toolsPath $perlCmd
);

use vars qw( %TWikiCompatibility );

# This should always be $Rev$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

use strict;

$pluginName = 'DirectedGraphPlugin';
use Digest::MD5 qw( md5_hex );

#the MD5 and hash table are used to create a unique name for each graph
use File::Path;
use File::Temp;

my $HASH_CODE_LENGTH    = 32;
my %hashed_math_strings = ();


my $dotHelper = "DirectedGraphPlugin.pl";
my $engineCmd      = " %HELPERSCRIPT|F% %DOT|F% %WORKDIR|F% %INFILE|F% %IOSTRING|U% %ERRFILE|F% ";
my $antialiasCmd = "convert -density %DENSITY|N% -geometry %GEOMETRY|S% %INFILE|F% %OUTFILE|F%";
my $tempdir = "";

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning("Version mismatch between $pluginName and Plugins.pm");
      return 0;
    }

    if ( defined $TWiki::cfg{DataDir} ) {
       # TWiki-4 or more recent
       # path to dot, neato, twopi, circo and fdp (including trailing /)
       $enginePath = $TWiki::cfg{DirectedGraphPlugin}{enginePath};
       # path to imagemagick convert routine
       $magickPath = $TWiki::cfg{DirectedGraphPlugin}{magickPath};
       # path to imagemagick convert routine
       $toolsPath = $TWiki::cfg{DirectedGraphPlugin}{toolsPath};
       # path to imagemagick convert routine
       $perlCmd = $TWiki::cfg{DirectedGraphPlugin}{perlCmd};
    } else {
       # Cairo or earlier
       $enginePath = '/usr/bin/';
       $magickPath = '/usr/bin/';
       $toolsPath = '/var/www/wapa412/htdocs/tools/';
       $perlCmd = '/usr/bin/perl';
       }
       
    die "Path to GraphViz commands not defined use bin/configure or edit DirectedGraphPlugin.pm " unless $enginePath;
    
    if ( defined $TWiki::cfg{TempfileDir} ) {
       $tempdir = $TWiki::cfg{TempfileDir};
    } else {
       $tempdir = File::Spec->tmpdir();
       }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag("\U$pluginName\E_DEBUG");

    # Get plugin antialias default
    $antialiasDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_ANTIALIAS");

    # Get plugin density default
    $densityDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_DENSITY");

    # Get plugin size default
    $sizeDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_SIZE");

    # Get plugin vectorFormats default
    $vectorFormatsDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_VECTORFORMATS");

    # Get plugin engine default
    $engineDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_ENGINE");

    # Get plugin library default
    $libraryDefault = TWiki::Func::getPreferencesValue("\U$pluginName\E_LIBRARY");

    # Initialize graph number for auto-generated graphs.
    $grNum = 0;

    # Plugin correctly initialized
    TWiki::Func::writeDebug("- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK")
      if $debug;
  return 1;
} ### sub initPlugin

sub doInit
{
  return if $isInitialized;

  unless (defined &TWiki::Sandbox::new) {
    eval "use TWiki::Contrib::DakarContrib;";
    $sandbox = new TWiki::Sandbox();
  } else {
    $sandbox = $TWiki::sharedSandbox # 4.0 - 4.1.2
      || $TWiki::sandbox; # 4.2
  }


    &writeDebug("called doInit");

    # for getRegularExpression
    if ( $TWiki::Plugins::VERSION < 1.020 ) {
        eval 'use TWiki::Contrib::CairoContrib;';
    }

    $workAreaDir = TWiki::Func::getWorkArea('DirectedGraphPlugin');

    &writeDebug("doInit( ) is OK");
    $isInitialized = 1;

  return '';
} ### sub doInit

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug("- ${pluginName}::commonTagsHandler( $_[2].$_[1] )")
      if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    #pass everything within <dot> tags to handleDot function
    $_[0] =~ s/<DOT(.*?)>(.*?)<\/DOT>/&handleDot($2,$1)/giseo;
} ### sub commonTagsHandler

# =========================
sub handleDot
{
    $grNum++;   # Increment a sequential graph number for un-named graphs

    my $errMsg = &doInit();
  return $errMsg if $errMsg;

    my $attr = $_[1] || "";
    my $desc = $_[0] || "";

    my %params = TWiki::Func::extractParameters($attr);  #extract all parms into a hash array

    my $antialias = $params{antialias} || $antialiasDefault;;
    my $density = $params{density} || $densityDefault;
    my $size = $params{size} || $sizeDefault;
    my $vectorFormats = $params{vectorformats} || $vectorFormatsDefault;
    my $engine = $params{engine} || $engineDefault;
    my $library = $params{library} || $libraryDefault;
    my $outFilename = $params{file} || "";
    my $doMap = $params{map} || "";
    my $dotHash = $params{dothash} || "on";

    # Strip all leading / trailing white space - WYSIWYG seems to pad it.
    $antialias =~ s/^\s+//;
    $antialias =~ s/\s+$//;
    $density =~ s/^\s+//;
    $density =~ s/\s+$//;
    $size =~ s/^\s+//;
    $size =~ s/\s+$//;
    $vectorFormats =~ s/^\s+//;
    $vectorFormats =~ s/\s+$//;
    $engine =~ s/^\s+//;
    $engine  =~ s/\s+$//;
    $library =~ s/^\s+//;
    $library =~ s/\s+$//;
    $outFilename =~ s/^\s+//;
    $outFilename =~ s/\s+$//;
    $dotHash =~ s/^\s+//;
    $dotHash =~ s/\s+$//;

    # Make sure outFilename is clean 
    $outFilename = TWiki::Sandbox::sanitizeAttachmentName($outFilename) if ($outFilename ne "");

    # clean up parms
    if ( $antialias =~ m/off/o ) {
        $antialias = 0;
    }

    unless ( $density =~ m/^\d+$/o ) {
      return
"<font color=\"red\"><nop>DirectedGraph Error: density parameter should be given as a number (was: $density)</font>";
    }
    unless ( $size =~ m/^\d+x\d+$/o ) {
      return
"<font color=\"red\"><nop>DirectedGraph Error: size parameter should be given in format: widthxheight (was: $size)</font>";
    }

    unless ( $engine =~ m/^(dot|neato|twopi|circo|fdp)$/o ) {
      return
"<font color=\"red\"><nop>DirectedGraph Error: engine parameter must be one of the following: dot, neato, twopi, circo or fdp (was: $engine)</font>";
    }

    unless ( $dotHash =~ m/^(on|off)$/o ) {
          return "<font color=\"red\"><nop>DirectedGraph Error: dothash must be either \"off\" or \"on\" (was: $dotHash)</font>";
       }

    my $chkHash = undef;   
    if ( $dotHash =~ m/off/o ) {
        $chkHash = 0;
    } else {
        $chkHash = 1;
    }	

    # FIXME  This is not safe for the Store rewrite.  
    # Need to copy attachments to a temporary directory!

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

    &writeDebug(
"incoming: $desc, $attr , antialias = $antialias, density = $density, size = $size, vectorformats = $vectorFormats, engine = $engine, library = $library, doMap = $doMap, hash = $dotHash \n"
    );

    foreach my $prm (keys(%params)) {
            &writeDebug( "PARAMETER $prm value is $params{$prm} \n");
   }

    # compute the MD5 hash of this string.  This used to detect
    # if any parameters or input change from run to run
    # Attachments recreated if the hash changes

    my $hashCode =
      md5_hex( "DOT" . $desc . $attr . $antialias . $density . $size . $vectorFormats . $engine . $library . $doMap );

    $hashed_math_strings{"$hashCode"} = $_[0];

    # If a filename is not provided, set it to a name, with incrementing number.
    if ($outFilename eq "") {$outFilename = "DirectedGraphPlugin_"."$grNum";} 
    
    my $oldHashCode = TWiki::Func::readFile( "$workAreaDir/${web}_${topic}_${outFilename}");

    # Make sure vectorFormats includes all required file types
    # dups okay, will scrub them out below.
    $vectorFormats .= " png";
    $vectorFormats .= " ps" if ($antialias);
    $vectorFormats .= " cmapx" if ($doMap);

    my $outString = "";
    my %tempFile;
    my %attachFile;
    foreach my $key (split(" ",$vectorFormats) ) {
       if ( $key ne "none" ) {   # skip the bogus default
          if (!exists ($tempFile{$key})) {
             $tempFile{$key} = new File::Temp(TEMPLATE => 'DGPXXXXXXXXXX',
                         DIR => $tempdir,
	                 #UNLINK => 0, # DEBUG
                         SUFFIX => ".$key" );
             # Don't create the GraphViz PNG output if antialias is requested			 
             $outString .= "-T$key -o$tempFile{$key} " unless ($antialias && $key eq "png");
             $attachFile{$key} = "$outFilename.$key";
          }   
       }
    }

    #  If the hash codes don't match, the graph needs to be recreated
    #  otherwise just use the previous graph already attached.
    #  Also check if someone has deleted the attachment and recreate if needed
    #
    if ( (($oldHashCode ne $hashCode) && $chkHash ) | 
         not TWiki::Func::attachmentExists( $web, $topic, "$outFilename.png" )) {

        # Save the hash for the new graph.
        if ( $chkHash ) { TWiki::Func::saveFile( "$workAreaDir/${web}_${topic}_${outFilename}", $hashCode ); } 

        # Create a new temporary file to pass to GraphViz
        my $dotFile = new File::Temp(TEMPLATE => 'DiGraphPluginXXXXXXXXXX',
                         DIR => $tempdir,
                         #UNLINK => 0, # DEBUG
                         SUFFIX => '.dot');
        TWiki::Func::saveFile( "$dotFile", $desc);

        #  Execute dot - generating all output into the TWiki temp directory
        my ( $output, $status ) = $sandbox->sysCommand(
                $perlCmd . $engineCmd,
                HELPERSCRIPT => $toolsPath . $dotHelper,
                DOT          => $enginePath . $engine,
                WORKDIR      => $workingDir,
                INFILE       => "$dotFile",
                IOSTRING      => $outString,
                ERRFILE      => "$dotFile" . ".err"
            );
	
	if ($status) {
	     unlink $dotFile          unless $debug;
             return showError( $status, $output, $hashed_math_strings{"$hashCode"}, $dotFile.".err" );
	     } ### if ($status)
	unlink "$dotFile.err" unless $debug;     
        unlink $dotFile unless $debug;

	### Possible improvement - let the engine create the PNG file and
	### then set the size & density below to match so the image map
	### matches correctly.

        if ($antialias) {  # Convert the postscript image to the png
            my ( $output, $status ) = $sandbox->sysCommand(
                $magickPath . $antialiasCmd,
                DENSITY  => $density,
                GEOMETRY => $size,
                INFILE   => "$tempFile{'ps'}",
                OUTFILE  => "$tempFile{'png'}"
            );
            &writeDebug("dgp-png: output: $output \n status: $status");
            if ($status) {
              return &showError( $status, $output, $hashed_math_strings{"$hashCode"} );
            } ### if ($status)
        } ### if ($antialias)

        foreach my $key (keys(%attachFile)) {
            TWiki::Func::saveAttachment(
                $web, $topic,
                "$attachFile{$key}",
                {
		    file => "$tempFile{$key}",
                    comment => '<nop>DirectedGraphPlugin: DOT graph',
                    hide    => 1
                }
            );
        unlink $tempFile{$key} unless $debug ;
        } ### foreach my $key (keys....

    } ### else [ if ($oldHashCode ne $hashCode) |

    if ($doMap) {
        # read and format map
        my $mapfile = TWiki::Func::readAttachment($web, $topic, "$outFilename.cmapx");
        $mapfile =~ s/(<map\ id\=\")(.*?)(\"\ name\=\")(.*?)(\">)/$1$hashCode$3$hashCode$5/go;
        $mapfile =~ s/[\n\r]/ /go;

        # place map and "foo.png" at the source of the <dot> tag in $Web.$Topic
        my $loc = TWiki::Func::getPubUrlPath() . "/$web/$topic";
        my $src = TWiki::urlEncode("$loc/$outFilename.png");
        return "$mapfile<img usemap=\"#$hashCode\" src=\"$src\"/>";
    } else {
        # attach "foo.png" at the source of the <dot> tag in $Web.$Topic
        my $loc = TWiki::Func::getPubUrlPath() . "/$web/$topic";
        my $src = TWiki::urlEncode("$loc/$outFilename.png");
      return "<img src=\"$src\"/>";
    } ### else [ if ($doMap)
} ### sub handleDot

# =========================
sub showError
{
    my ( $status, $output, $text, $errFile ) = @_;

    # Check error file for detailed report from graphviz binary
    if (defined $errFile && $errFile && -s $errFile)
    {
        open (ERRFILE, $errFile);
        my @errLines = <ERRFILE>;
        $text = "*DirectedGraphPlugin error:* <verbatim>" . join("", @errLines) . "</verbatim>";
        unlink $errFile unless $debug;
    }

    my $line = 1;
    $text =~ s/\n/sprintf("\n%02d: ", $line++)/ges if ($text);
    $output .= "<pre>$text\n</pre>";
  return "<font color=\"red\"><nop>DirectedGraph Error ($status): $output</font>";
} ### sub showError

sub writeDebug
{
    &TWiki::Func::writeDebug( "$pluginName - " . $_[0] ) if $debug;
}

sub afterRenameHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment ) = @_;

    my $oldweb = $_[0];
    my $oldtopic = $_[1];
    my $newweb = $_[3];
    my $newtopic = $_[4];
    my $workAreaDir = TWiki::Func::getWorkArea('DirectedGraphPlugin');
    
   TWiki::Func::writeDebug( "- ${pluginName}::afterRenameHandler( " .
                            "$_[0].$_[1] $_[2] -> $_[3].$_[4] $_[5] )" ) if $debug;

   # Find all files in the workarea directory for the old topic
   # rename them unless new web is Trash, otherwise delete them.
   # 
   # files are named either $web_$topic_graph_nn 
   #                     or $web_$topic_<user specified name>
   #

   opendir(DIR, $workAreaDir) || die "<ERR> Can't find directory --> $workAreaDir !";
   
   my @wfiles  = grep { /^${oldweb}_${oldtopic}_/ } readdir(DIR);
   foreach my $f (@wfiles) {
      my $prefix = "${oldweb}_${oldtopic}_";
      my ($suffix) = ($f =~  "^$prefix(.*)" );
      $f = TWiki::Sandbox::untaintUnchecked($f);
      if ($newweb eq "Trash") {
         unlink "$workAreaDir/$f";
      } else {
         my $newname = "${newweb}_${newtopic}_${suffix}";
	 $newname = TWiki::Sandbox::untaintUnchecked($newname);
         rename ("$workAreaDir/$f", "$workAreaDir/$newname");
      }
  }
}

1;
