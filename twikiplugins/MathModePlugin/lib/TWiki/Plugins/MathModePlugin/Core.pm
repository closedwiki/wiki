# MathModePlugin/Core.pm
#
# Copyright (C) 2006 MichaelDaum@WikiRing.com
# Copyright (C) 2002 Graeme Lufkin, gwl@u.washington.edu
#
# TWiki WikiClone ($wikiversion has version info)
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
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
###############################################################################

package TWiki::Plugins::MathModePlugin::Core;

use strict;
use vars qw($debug);
use Digest::MD5 qw( md5_hex );
use File::Copy qw( move );
use File::Temp;

$debug = 0; # toggle me

###############################################################################
# static
sub writeDebug {
  #&TWiki::Func::writeDebug('- MathModePlugin - '.$_[0]) if $debug;
  print STDERR '- MathModePlugin - '.$_[0]."\n" if $debug;
}

###############################################################################
sub new {
  my $class = shift;

  my $this = {
    hashedMathStrings => {}, 
      # contains the math strings, indexed by their hash code

    hashCodeLength => $TWiki::cfg{MathModePlugin}{HashCodeLength} || 32,

      # length of the hash code. If you switch to a different
      # hash function, you will likely have to change this

    imagePrefix => $TWiki::cfg{MathModePlugin}{ImagePrefix} || '_MathModePlugin_',
      # string to be prepended to any auto-generated image

    latex2Html => $TWiki::cfg{MathModePlugin}{Latex2Html} || '/usr/bin/latex2html', 
      # the path to invoke the latex2html command

    antiAlias => $TWiki::cfg{MathModePlugin}{AntiAlias} || 'on',
      # flag to indicate if images should be anti-aliased

    initFile => $TWiki::cfg{MathModePlugin}{InitFile} || '',
      # init file for latex2html

    scaleFactor => $TWiki::cfg{MathModePlugin}{ScaleFactor} || 1.8,
      # factor to scale images this value has no effect if you
      # specified an initFile; may be overridden by a LATEXSCALEFACTOR 
      # TWiki preference variable

    latexPreamble => $TWiki::cfg{MathModePlugin}{Preamble} || '\usepackage{mathptmx}',
      # latex preamble, e.g. to include additional packages; may be 
      # overridden by a LATEXPREAMBLE preference variable;
      # Example: \usepackage{mathptmx} to change the math font

    fontSize => $TWiki::cfg{MathModePlugin}{FontSize} || '12pt',
      # font size used for the latex document and the math images;
      # may be overridden by a LATEXFONTSIZE preference variable

    imageType => $TWiki::cfg{MathModePlugin}{ImageType} || 'gif',
      # extension of the image type;
      # may be overridden by a LATEXIMAGETYPE preference variable

    @_
  };

  return bless($this, $class);
}

###############################################################################
# delayed initialization
sub init {
  my ($this, $web, $topic) = @_;

  # prevent a doubled invokation
  return if $this->{isInitialized};
  $this->{isInitialized} = 1;

  # get preverences
  my $value = TWiki::Func::getPreferencesValue('LATEXSCALEFACTOR');
  $this->{scaleFactor} = $value if $value;

  $value = TWiki::Func::getPreferencesValue('LATEXFONTSIZE');
  $this->{fontSize} = $value if $value;

  $value = TWiki::Func::getPreferencesValue('LATEXIMAGETYPE');
  $this->{imageType} = $value if $value;

  $value = TWiki::Func::getPreferencesValue('LATEXPREAMBLE');
  $this->{latexPreamble} = $value if $value;

  #writeDebug("scaleFactor=$this->{scaleFactor}");
  #writeDebug("fontSize=$this->{fontSize}");
  #writeDebug("imageType=$this->{imageType}");
  #writeDebug("latexPreamble=$this->{latexPreamble}");

  # get the current cgi
  my $pathInfo = $ENV{'PATH_INFO'};
  my $script = $ENV{'REQUEST_URI'} || '';
  if ($script =~ /^.*?\/([^\/]+)$pathInfo.*$/) {
    $script = $1;
  } else {
    $script = 'view';
  }
  $this->{cgiScript} = $script;

  # compute filenname length of an image
  $this->{imageFileNameLength} =
    $this->{hashCodeLength}+length($this->{imageType})+length($this->{imagePrefix})+1;

  # get refresh request
  my $query = TWiki::Func::getCgiQuery();
  my $refresh = $query->param('refresh') || '';
  $this->{doRefresh} = ($refresh =~ /^(on|yes|1)$/)?1:0;

  # fix antialias param
  $this->{antiAlias} = ($this->{antiAlias} =~ /^\s*(on|yes|1)\s*$/)?1:0;

  # create a sandbox
  unless (defined &TWiki::Sandbox::new) {
    eval "use TWiki::Contrib::DakarContrib;";
    $this->{sandbox} = new TWiki::Sandbox();
  } else {
    $this->{sandbox} = $TWiki::sharedSandbox;
  }

  # create the topic pubdir if it does not exist already
  my $topicPubDir = &TWiki::Func::getPubDir()."/$web/$topic";
  $topicPubDir = TWiki::Sandbox::normalizeFileName($topicPubDir);
  unless (-d $topicPubDir) {
    mkdir $topicPubDir or die "can't create directory $topicPubDir";
  }
  $this->{topicPubDir} = $topicPubDir;

}

###############################################################################
# This function takes a string of math, computes its hash code, and returns a
# link to what will be the image representing this math.
sub handleMath {
  my ($this, $web, $topic, $text, $inlineFlag, $args) = @_;
  
  $args ||= '';

  # store the string in a hash table, indexed by the MD5 hash
  my $hashCode = md5_hex($text);
  $this->{hashedMathStrings}{$hashCode} = $text;
  
  # construct url path to image
  my $url = &TWiki::Func::getPubUrlPath().'/'.$web.'/'.$topic.
    '/'.$this->{imagePrefix}.$hashCode.'.'.$this->{imageType};

  # return a link to an attached image, which we will create later
  my $container = $inlineFlag?'span':'div';
  my $result = '<img class="mmpImage" src="'.$url.'" '.$args.' />';
  $result = "<$container class='mmpContainer' align='center'>".$result."<\/$container>"
    unless $inlineFlag == 2;

  return $result;
}

###############################################################################
sub postRenderingHandler {
  my ($this, $web, $topic) = @_;

  return unless keys %{$this->{hashedMathStrings}};

  # initialize this call
  $this->init($web, $topic);
	
  # check if there are any new images to render
  return unless $this->checkImages();

  # do it
  my $msg = $this->renderImages();

  # append to text
  $_[3] .= $msg if $msg;
}
	
###############################################################################
# if this is a save script, then we will try to delete old files;
# existing files are checkd if they are still in use;
# returns the number of images to be re-rendered
sub checkImages {
  my $this = shift;

  # only delete during a save
  my $deleteFiles = ($this->{cgiScript} =~ /^save/ || $this->{doRefresh})?1:0;

  #writeDebug("deleteFiles=$deleteFiles, cgiScript=$this->{cgiScript}");

  # look for existing images, delete old ones
  opendir(DIR,$this->{topicPubDir}) or die "can't open directory $this->{topicPubDir}";
  my @files = grep(/$this->{imagePrefix}.*\.$this->{imageType}$/,readdir(DIR));
  foreach my $fileName (@files) {
    $fileName = TWiki::Sandbox::normalizeFileName($fileName);
    #writeDebug( "found image: $fileName");

    # is the filename the same length as one of our images?
    next unless length($fileName) == $this->{imageFileNameLength};

    # is the filename composed of the same characters as ours?
    my $hashCode = $fileName;
    next unless $hashCode =~ /^$this->{imagePrefix}(.*)\.$this->{imageType}$/;
    $hashCode = $1;
    next unless length($hashCode) == $this->{hashCodeLength};

    # is the image still used in the document?
    if (exists($this->{hashedMathStrings}{$hashCode} ) ) {
      # the image is already there, we don't need to re-render;
      # refresh the cache only if we asked for it
      unless ($this->{doRefresh}) {
	#writeDebug("skipping $this->{hashedMathStrings}{$hashCode}");
	delete $this->{hashedMathStrings}{$hashCode};
	next;
      }
    }
    
    # maintenance
    next unless $deleteFiles;
    $fileName = $this->{topicPubDir}.'/'.$fileName;
    #writeDebug("deleting old image $fileName");
    unlink $fileName or die "can't delete file $fileName";
  }

  return scalar(keys %{$this->{hashedMathStrings}});
}

###############################################################################
sub renderImages {
  my $this = shift;

  # used for reporting errors
  my $msg;

  # create temporary storage
  my $tempDir = File::Temp::tempdir(CLEANUP =>1);
  my $tempFile = new File::Temp(DIR=>$tempDir, SUFFIX=>'.tex');

  # create a latex2html init file; some options cannot be done on the cmdline
  my $initFile = $this->{initFile};
  my $closeIniFile = 0;
  unless ($initFile) {
    $closeIniFile = 1;
    $initFile = new File::Temp(DIR=>$tempDir, SUFFIX=>'.init');
    print $initFile "\$MATH_SCALE_FACTOR = $this->{scaleFactor};\n1;\n"
  }

  # maps math strings' hash codes to the filename latex2html generates
  my %hashCodeMapping = ();

  # latex2html names its image img(n).png where (n) is an integer
  # we will rename these files, so need to know which math string gets with image
  my $imageNumber = 0;

  # create the latex file on the fly
  print $tempFile "\\documentclass[fleqn,$this->{fontSize}]{article}\n"; 
  print $tempFile "$this->{latexPreamble}\n";
  print $tempFile "\\usepackage{amsmath}\n";
  print $tempFile "\\setlength{\\mathindent}{0cm}\n";
  print $tempFile "\\begin{document}\n";
  while (my ($key, $value) = each(%{$this->{hashedMathStrings}})) {
    $imageNumber++;
    $value =~ s/^\s+//o;
    $value =~ s/\s+$//o;

    # analyze which environment to use
    my $environment = ($value =~ /\\\\/)?'multiline*':'math';
    #writeDebug("using $environment for $value");
    print $tempFile "\\begin{$environment}\\displaystyle $value\\end{$environment}\n";
    $hashCodeMapping{$key} = 'img'.$imageNumber.'.'.$this->{imageType};
  }
  print $tempFile "\\end{document}\n";

  # run latex2html on the latex file we generated
  my $latex2HtmlCmd = $this->{latex2Html};
  $latex2HtmlCmd .= ' -init_file '.$initFile;
  $latex2HtmlCmd .= ' -no_math';
  $latex2HtmlCmd .= ' -image_type '.$this->{imageType};
  $latex2HtmlCmd .= ' -font_size '.$this->{fontSize};
  $latex2HtmlCmd .= ' -antialias' if $this->{antiAlias};
  $latex2HtmlCmd .= ' -noantialias' unless $this->{antiAlias};
  $latex2HtmlCmd .= ' -white';
  $latex2HtmlCmd .= ' -novalidate';
  $latex2HtmlCmd .= ' -dir '.$tempDir;
  $latex2HtmlCmd .= ' %FILENAME|F%';

  #writeDebug("executing $latex2HtmlCmd");
  my ($data, $exit) = $this->{sandbox}->sysCommand($latex2HtmlCmd, FILENAME=>"$tempFile");
  #writeDebug("exit=$exit");
  #writeDebug("data=$data");
  if ($exit) {
    $msg = '<div class="twikiAlert">Error during latex2html';
    $msg .= ": $data" if $data;
    $msg .= '</div>';
  } else {
    # rename the files to the hash code, so we can uniquely identify them
    while ((my $key, my $value) = each(%hashCodeMapping)) {
      my $source = $tempDir.'/'.$value;
      my $target = $this->{topicPubDir}.'/'.$this->{imagePrefix}.$key.'.'.$this->{imageType};
      #writeDebug("created new image $target");
      move($source, $target);# or die "can't move $source to $target: $@";
    }
  }

  # cleanup
  $this->{hashedMathStrings} =  {};
  File::Temp::cleanup();
  close $tempFile;
  close $initFile if $closeIniFile;
  return $msg;
}

1;
