#!/usr/bin/perl -w

# Copyright (C) 2004 C-Dot Consultants - All rights reserved
# Portions (C) 2004 Martin Cleaver

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

# Script that downloads zips and CVS for each of the plugins, skins and
# addons, and then analyses them for "badness" i.e. the amount by which
# they violate the standards for working in a TWiki context. The downloads
# are performed to two subdirectories created where the script is run,
# repository and download.
#
# The script also has the capability to download TWikiReleases and store them
# in the same download directory, this resulting download directory is used by the
# DistributionContrib so that adminstrators can pick up a single file of a past release.
# The downloading of releases is commented out by default. [MRJC]
#
# Usage: -nodownload will skip the update from the web and re-analyse
# previously downloaded data. -debug will switch on a verbose debug trace.
# -used will automatically assume the last download was the right one.
#
use strict;
use Time::ParseDate;

# Constants for URL fragments
my $TWikiOrg = "http://twiki.org";
my $View     = "/cgi-bin/view";

my $twikiReleaseURL = "$TWikiOrg/release/";

# update this with your credentials.
my $wgetOptions = "--http-user TWikiGuest --http-passwd guest";

# Other constants
my $red      = "#FF9999";
my $green    = "#99FF66";
my @handlers = (
 "earlyInitPlugin",            "initPlugin",
 "initializeUserHandler",      "registrationHandler",
 "commonTagsHandler",          "startRenderingHandler",
 "outsidePREHandler",          "insidePREHandler",
 "endRenderingHandler",        "beforeEditHandler",
 "afterEditHandler",           "beforeSaveHandler",
 "afterSaveHandler",           "beforeAttachmentSaveHandler",
 "afterAttachmentSaveHandler", "writeHeaderHandler",
 "redirectCgiQueryHandler",    "getSessionValueHandler",
 "setSessionValueHandler",     "renderFormFieldForEditHandler",
 "renderWikiWordHandler"
);

# Options
my $update          = 1;
my $interactivePick = 1;
my $debug           = 0;

# Database of analysis results
# Top level hash fields and semantics are:
# howbad - {module|token}
# cvs - {module}[{file,download,cvs}] - cvs mismatch
# illmod - {module}{illegal token}{file} - illegal token context
# illtok - {illegal token}{module} - illegal token context
# funcsyms - {TWiki::Func symbol} - symbols in Func
# suspect - {module}{file}{code fragment} - suspect code
# handlers - {token}{module} handler defined by module
my %data;

# Analyse options
foreach my $parm (@ARGV) {
 if ( $parm =~ m/^-nod/o ) {

  # If -nod is chosen, will not download unles absolutely necessary
  $update = 0;
 }
 elsif ( $parm =~ /^-used/o ) {

  # If -used chosen, will assume that default pick for download module from
  # last time still holds
  $interactivePick = 0;
 }
 elsif ( $parm =~ /^-d/o ) {
  $debug = 1;
 }
}

#downloadReleases();
analyseConformance();

sub analyseConformance() {
 my @modules = downloadModuleList();

 # Download list of functions in Func.pm
 my $text = getTopic( "Codev", "FuncDotPm" );
 foreach my $line ( split( /\n/, $text ) ) {
  if ( $line =~ /^<h3><a .*?<a .*?">\s*(\w+)/ ) {
   $data{funcsyms}{$1} = 1;
  }
 }

 # repository contains CVS, download contains expanded zips
 mkdir("repository") unless ( -d "repository" );
 mkdir("download")   unless ( -d "download" );

 # The workhouse - download and analyse
 my $module;
 foreach $module ( sort @modules ) {
  print STDERR "--- Updating $module\n";

  updateCVS($module) if ($update);

  my $zip = "__NO ZIP__";
  $zip = updateDownload($module);

  print STDERR "--- Analysing $module\n";

  compareCVS2Download( $module, $zip, \%data );

  analyseCode( $module, \%data );
 }
 generateReport( \%data, @modules );
}

sub downloadReleaseList {
 unlink "index.html";
 `wget $wgetOptions $twikiReleaseURL`;
 my $text           = readFile("index.html");
 my @releasesWanted = ();
 foreach my $line ( split( /\n/, $text ) ) {
  my $url;
  my $release;
  if ( $line =~ m!^<li> <a href="([\w_\.]+)\">(.*?)<\/a>! ) {
   ( $url, $release ) = ( $1, $2 );
   if ( $release !~ m!beta! ) {
    push @releasesWanted, $release;
   }
   elsif ( $release =~ m/TWiki200[2|3|4|5|6|7|8|9]/ ) {    #CODE_SMELL lazy
    push @releasesWanted, $release;
   }
  }
 }
 print "Releases wanted " . join( ", ", @releasesWanted ) . "\n";
 return @releasesWanted;
}

sub downloadReleases {
 my @releaseZips = downloadReleaseList();

 foreach my $releaseZip (@releaseZips) {
  my $dir = dirForRelease($releaseZip);
  mkdir "download/$dir";
  `wget $wgetOptions -P release/$dir $twikiReleaseURL/$releaseZip`;
 }

 foreach my $releaseZip (@releaseZips) {
  my $dir = dirForRelease($releaseZip);
  `cd download/$dir && unzip $releaseZip`;
 }
}

sub dirForRelease {
 my ($zip) = @_;
 my $dir = $zip;
 $dir =~ s/\.zip$//;
 return $dir;
}

sub downloadModuleList {

 # Download list of modules from TWiki.org
 my @modules;
 getPackageList( "PluginPackage", \@modules );
 getPackageList( "SkinPackage",   \@modules );
 getPackageList( "AddOnPackage",  \@modules );
 return @modules;
}

sub generateReport {
 my ( $dataRef, @modules ) = @_;
 %data = %{$dataRef};

 # print results
 print "---+ Report on the current status of packages in the Plugins web\n";
 print RED( "This report was script-generated on " . `date` . "<p>" );
 print "The goal of the analysis is to determine conformance to standards.\n";

 my $cvsReport = "";
 foreach my $module ( sort keys %{ $data{cvs} } ) {
  my @records = @{ $data{cvs}{$module} };
  my $lc      = scalar(@records);
  foreach my $record (@records) {
   my $cvt = $record->{cvs}      ? gmtime( $record->{cvs} )      : "Not found";
   my $dlt = $record->{download} ? gmtime( $record->{download} ) : "Not found";
   my $ctc = $green;
   my $dtc = $green;
   if ( $record->{cvs} && $record->{download} ) {
    if ( $record->{cvs} > $record->{download} ) {
     $ctc = $green;
     $dtc = $red;
    }
    else {
     $ctc = $red;
     $dtc = $green;
    }
   }
   elsif ( $record->{cvs} ) {
    $ctc = $green;
    $dtc = $red;
   }
   elsif ( $record->{download} ) {
    $ctc = $red;
    $dtc = $green;
   }
   $cvsReport .= TR(
    TDS( $lc, $module ),
    TD( "<nop>" . $record->{file} ),
    TD_SHADE( $dtc, $dlt ),
    TD_SHADE( $ctc, $cvt )
   );
   $lc = 0;
  }
 }

 if ( $cvsReport ne "" ) {
  print "---++ Modules with questionable CVS status\n";
  print TABLE( THR( "Module", "File", "Zip Time", "CVS Time" ), $cvsReport );
 }

 my $funcUsageReport = "";
 foreach my $key ( sort { $data{funcsyms}{$a} <=> $data{funcsyms}{$b} }
  keys %{ $data{funcsyms} } )
 {
  $funcUsageReport .= TR( TD($key), TD( $data{funcsyms}{$key} - 1 ) );
 }

 if ( $funcUsageReport ne "" ) {
  print "---++ Usage of functions in Func\n";
  print TABLE( THR( "Function", "Calls" ), $funcUsageReport );
 }

 my $handlerReport = "";
 foreach my $h (@handlers) {
  if ( $data{handlers}{$h} ) {
   $handlerReport .= TR( TD($h), TD( join( ", ", @{ $data{handlers}{$h} } ) ) );
  }
 }

 if ( $handlerReport ne "" ) {
  print "---++ Handlers defined by modules\n";
  print TABLE( THR( "Handler", "Modules" ), $handlerReport );
 }

 my $illegalCallsReport = "";
 my @badtoks            = keys %{ $data{illtok} };
 @badtoks = sort { $data{howbad}{$b} <=> $data{howbad}{$a} } @badtoks;
 foreach my $token (@badtoks) {
  my @badmods = sort keys %{ $data{illtok}{$token} };
  $illegalCallsReport .= TR(
   TD("<nop>$token"),
   TD( $data{howbad}{$token} ),
   TD( join( " ", @badmods ) )
  );
 }

 if ( $illegalCallsReport ne "" ) {
  print "---++ Calls to TWiki symbols not published through TWiki::Func\n";
  print TABLE( THR( "Symbol", "Calls", "Callers" ), $illegalCallsReport );
 }

 # Table of each module, each token it calls, and what files call them
 my $badModsReport = "";
 my @badmods       = sort keys %{ $data{illmod} };
 foreach my $module (@badmods) {
  my @badtoks = keys %{ $data{illmod}{$module} };
  @badtoks = sort { $data{howbad}{$b} <=> $data{howbad}{$a} } @badtoks;
  my $tokc = scalar(@badtoks);
  foreach my $token (@badtoks) {
   my @files = sort keys %{ $data{illmod}{$module}{$token} };
   my $desc  = "";
   foreach my $file (@files) {
    $desc .= "<nop>$file (" . $data{illmod}{$module}{$token}{$file} . ")<br>";
   }
   $badModsReport .= TR( TDS( $tokc, $module ), TD("<nop>$token"), TD($desc) );
   $tokc = 0;
  }
 }

 if ( $badModsReport ne "" ) {
  print "---++ Analysis of illegal calls made by modules\n";
  print TABLE( THR( "Module", "Symbol", "File (calls)" ), $badModsReport );
 }

 # Table of each module and each file with questionable code
 my $questionableCodeReport = "";
 foreach my $module ( sort keys %{ $data{suspect} } ) {
  my $filc = scalar( keys %{ $data{suspect}{$module} } );
  foreach my $file ( keys %{ $data{suspect}{$module} } ) {
   if ( defined( $data{suspect}{$module}{$file} ) ) {
    $questionableCodeReport .= TR( TDS( $filc, $module ),
     TD("$file"),
     TD( "\n<pre>\n" . $data{suspect}{$module}{$file} . "</pre>\n" ) );
    $filc = 0;
   }
  }
 }

 if ( $questionableCodeReport ne "" ) {
  print "---++ Other questionable code in modules\n";
  print "\nQuestionable code is code that appears to read or write topics ";
  print "or webs directly.\n\n";
  print TABLE( THR( "Module", "File", "Code Fragment" ),
   $questionableCodeReport );
 }

 my $conformanceReport = "";
 my @sm = sort { $data{howbad}{$a} <=> $data{howbad}{$b} } @modules;
 my $n  = $data{howbad}{ @sm[ scalar(@sm) - 1 ] };
 my $i  = 0;
 foreach my $module (@sm) {
  my $howbad = $data{howbad}{$module} || 0;
  $conformanceReport .= TR_SHADE( $howbad, $n, TD($module), TD($howbad) );
 }

 if ( $conformanceReport ne "" ) {
  print "---++ Estimated module conformance\n";
  print "Conformance is degree to which module conforms with published ";
  print "interfaces. Low number *good*, high number *bad*\n";
  print TABLE( THR( "Module", "Conformance rating" ), $conformanceReport );
 }

 my $directivesReport = "";
 foreach my $find ( sort keys( %{ $data{directives} } ) ) {
  $directivesReport .=
    TR( TD($find),
   TD( join( ", ", sort( keys %{ $data{directives}{$find} } ) ) ) );
 }

 if ( $directivesReport ne "" ) {
  print "---++ Directives apparently expanded by modules\n";
  print TABLE( THR( "Directive", "Module(s)" ), $directivesReport );
 }
}

# Find occurences of TWiki functions not from TWiki::Func in the module.
# Also analyse module for questionable code use.
sub analyseCode {
 my ( $module, $data ) = @_;
 if ( -d "download/$module" ) {
  my $text = `cd download/$module && find . -name '*.pm' -print`;
  return if ($?);
  my @files = split( /\n/, $text );
  foreach my $file ( grep( !/\/test\//, @files ) ) {
   $file =~ s/^\.\///o;
   my $r = "download/$module/$file";
   my @finds = split( /\n/, `grep "TWiki::" $r` );
   my $find;
   foreach $find (@finds) {
    if ($find =~ /^(use|require)/
     || $find =~ /package TWiki/
     || $find =~ /COMPATIBILITY/ )
    {
    }
    else {
     while ( $find =~ s/\b(TWiki(::(\w+))+)[^\w:]//o ) {
      my $token = $1;
      if ($token !~ /TWiki::Func/o
       && $token !~ /TWiki::Plugins/o
       && $token !~ /TWiki::TestMaker/o )
      {

       # Index twice, by module and by token
       $data->{illmod}{$module}{$token}{$file}++;
       $data->{illtok}{$token}{$module}++;
       $token =~ m/(\w+)$/o;
       if ( $data->{funcsyms}{$1} ) {
        $data->{howbad}{$module} += 5;
        $data->{howbad}{$token}  += 5;
       }
       else {
        $data->{howbad}{$module}++;
        $data->{howbad}{$token}++;
       }
      }
      elsif ( $token =~ /TWiki::Func::(\w+)\b/o ) {
       $token = $1;
       if ( defined( $data->{funcsyms}{$token} ) ) {
        $data->{funcsyms}{$token}++;
       }
      }
     }
    }
   }

   # search for handler definitions
   foreach my $h (@handlers) {
    `egrep -s -e "sub[ \t]*$h" $r`;
    if ( !$? ) {
     push( @{ $data->{handlers}{$h} }, $module );
    }
   }

   # search for probable directives %DIRECTIVE
   @finds = split( /\n/, `egrep '^.*s/%[^\/]*%' $r` );
   foreach $find (@finds) {
    if ( $find !~ /^\s*\#/o ) {
     if ( $find =~ s/^.*s\/%(\w+)%.*$/$1/o ) {
      $data->{directives}{$find}{$module} = 1;
     }
    }
   }

   # search for suspect code
   my $cmd = "egrep 'opendir[ \t]*\\(*[ \t]*[A-Z][A-Z]*,' $r";
   my $grr .= `$cmd`;
   $cmd = "egrep -e '=[ \t]*<[A-Z]*>' $r";
   $grr .= `$cmd`;
   $cmd = "egrep 'open[ \t]*\\(*[ \t]*[A-Z][A-Z]*,' $r";
   $grr .= `$cmd`;
   $grr =~ s/^\s*\#.*$//mgo;
   $grr =~ s/</&lt;/o;
   $grr =~ s/>/&gt;/o;
   $grr =~ s/^\s*//go;
   $grr =~ s/\n\n/\n/gos;
   if ( $grr !~ /^\s*$/os ) {
    $data->{suspect}{$module}{$file} = $grr;
    $data->{howbad}{$module} += scalar( split( /\n/, $grr ) ) * 3;
   }
  }
 }
}

# Compare CVS to the download. Could do this by simply layering
# the zip over the CVS repository and doing a CVS update, but
# several of the plugins are so crap that would probably break.
# So instead, we use recursive diff and analyse the result.
sub compareCVS2Download {
 my ( $module, $zip, $data ) = @_;
 if (-d "repository/twikiplugins/$module"
  && -d "download/$module" )
 {
  my $diffs =
`diff -rq download/$module repository/twikiplugins/$module | grep -v ": CVS"| grep -v ": $zip"`;
  if ($?) {
   print STDERR $diffs;
   return;
  }
  my $error = "";
  foreach my $diff ( split( /\n/, $diffs ) ) {
   if ( $diff =~ /^Files (.*?) and (.*?) differ/ ) {
    my $dnl  = getFileTime($1);
    my $cvs  = getCVSFileTime($2);
    my $file = $1;
    next if ( $file =~ m/\.(zip|gz|tgz)$/o );
    $file =~ s/download\/$module\///;
    if ( $dnl > $cvs ) {
     push(
      @{ $data->{cvs}{$module} },
      { file => $file, download => $dnl, cvs => $cvs }
     );
     $data->{howbad}{$module} += 10;
    }
   }
   elsif ( $diff =~ /Only in (download\/$module\/.*?): (.*)$/ ) {
    my $file = "$1/$2";
    next if ( $file =~ m/\.(zip|gz|tgz)$/o );
    my $dt = getFileTime($file);
    $file =~ s/download\/$module\///;
    push(
     @{ $data->{cvs}{$module} },
     { file => $file, download => $dt, cvs => undef }
    );
    $data->{howbad}{$module} += 10;
   }
   elsif ( $diff =~ /Only in (repository\/twikiplugins\/$module\/.*?): (.*)$/ )
   {
    my $file = "$1/$2";

    # only in CVS
    my $cvt = ( -d $file ) ? time() : getCVSFileTime($file);
    $file =~ s/repository\/twikiplugins\/$module\///;
    push(
     @{ $data->{cvs}{$module} },
     { file => $file, download => undef, cvs => $cvt }
    );
   }
  }
 }
}

# Download a url, targeting the given local file name
sub getURL {
 my ( $url, $file ) = @_;

 unlink($file) if ( $update && -f $file );
 if ( !-f $file ) {
  print STDERR "--- Getting $url\n";
  `wget -q $url`;
  if ($?) {
   print STDERR "Failed to download $url\n";
   return undef;
  }
 }
 return readFile($file);
}

sub readFile {
 my $file = shift;
 if ( !open( FH, "<$file" ) ) {
  print STDERR "Failed to open $file\n";
  return undef;
 }
 my $text = "";
 while ( my $line = <FH> ) {
  $text .= $line;
 }
 return $text;
}

# Download a topic using ?skin=plain
sub getTopic {
 my ( $web, $topic ) = @_;

 my $file = "$topic?skin=plain";
 return getURL( "$TWikiOrg$View/$web/$file", $file );
}

# Get a list of attachments for a given web/topic, matching an optional
# re for the name, and pushing the attachment names onto the provided
# array.
sub getAttachments {
 my ( $web, $topic, $re ) = @_;

 my $atts = {};

 # get the list of attachments.
 my $text = "";
 if ( !$update && -f "$web.$topic.index.html" ) {
  $text = readFile("$web.$topic.index.html");
 }
 else {
  unlink("index.html");
  $text = getURL( "$TWikiOrg/p/pub/$web/$topic", "index.html" );
  `mv index.html $web.$topic.index.html` if ($text);
 }
 return $atts unless ($text);

 foreach my $line ( split( /\n/, $text ) ) {
  if ( $line =~
   m/^<IMG.*?>\s*<A HREF=\"([\w_\.]+)\">.*?<\/A>\s*([\w\-]+\s*[\d:]+)\s+\w*/i )
  {
   my $file = $1;
   my $time = $2;
   if ( !defined($re) || $file =~ /$re/ ) {
    print STDERR "--- Found attachment $file\n" if ($debug);
    $atts->{$file} = Time::ParseDate::parsedate($time);
   }
  }
 }
 return $atts;
}

# Get a list of modules from a topic
sub getPackageList {
 my ( $packs, $packages ) = @_;
 my $text = getTopic( "Plugins", $packs );
 if ($text) {
  foreach my $line ( split( /\n/, $text ) ) {
   if ( $line =~ /<a href=\"$View\/Plugins\/(\w+(Plugin|Skin|AddOn))/o ) {
    my $p = $1;
    push( @$packages, $p ) unless ( grep( /^$p$/, @$packages ) );
   }
  }
 }
}

# Update a module in CVS. Fails silently if module is not in CVS
sub updateCVS {
 my $module = shift;
 my $quiet  = $debug ? "" : " >/dev/null";

 if ( -d "repository/twikiplugins/$module" ) {
  print STDERR "--- Updating CVS $module\n";
`cd repository/twikiplugins/$module && cvs -d:pserver:anonymous\@cvs.sourceforge.net:/cvsroot/twikiplugins update $quiet`;
  if ($?) {
   print STDERR "CVS update on $module failed: $?\n";
  }
 }
 else {
  print "--- Checking out CVS $module\n";
`cd repository && cvs -d:pserver:anonymous\@cvs.sourceforge.net:/cvsroot/twikiplugins checkout twikiplugins/$module $quiet`;
 }
}

# Get the time a file was created
sub getFileTime {
 my $file  = shift;
 my @sinfo = stat($file);
 return $sinfo[9];
}

# Get the time a file was checked into CVS
sub getCVSFileTime {
 my $file = shift;
 $file =~ s/^(.*?)\/([^\/]*)$/$2/o;
 my $ents = "$1/CVS/Entries";
 my $tim  = `grep /$file/ $ents`;
 $tim =~ s/^\/.*\/.*\/(.*)\/.*\/$/$1/;
 return Time::ParseDate::parsedate($tim);
}

# Update the download of a module. This is done by
# 1. Getting a list of the attachments on the module's page
# 2. If there is only one attachment of compressed type, downloading it
# 3. Asking the user to select/confirm the choice if there are multiple
sub updateDownload {
 my $module = shift;
 my $atts   = getAttachments( "Plugins", $module, qr/\.(zip|tgz|tar\.gz|pm)$/ );

 while ( scalar(%$atts) ) {
  my $chosen = undef;
  my $time;
  my $def;
  my $npicks = 0;

  if ( scalar(%$atts) == 1 ) {

   # if there is only one attachment, it's easy; it must be that
   my @k = keys(%$atts);
   $chosen = $k[0];
   $time   = $atts->{$chosen};
   delete $atts->{$chosen};
  }
  else {
   print STDERR "Choose attachment for $module (* = default):\n";
   print STDERR "0  <none>\n";
   my $i = 1;
   my @sat = sort { $atts->{$a} <=> $atts->{$b} } keys %$atts;
   foreach my $a (@sat) {
    print STDERR $i++;
    if ( -f "download/$module/$a" ) {
     print STDERR "*";
     $def = $i - 1;
     $npicks++;
    }
    else {
     print STDERR " ";
    }
    print STDERR " " . gmtime( $atts->{$a} ) . "\t$a\n";
   }
   if ( $npicks != 1 || $interactivePick ) {
    $i = <STDIN>;
    $i = $def if ( $def && $i =~ /^\s*$/ );
   }
   else {
    $i = $def;
   }
   if ( $i > 0 ) {
    $chosen = $sat[ $i - 1 ];
    $time   = $atts->{$chosen};
    delete $atts->{$chosen};
   }
  }
  last unless ($chosen);
  print STDERR "--- Picked $chosen\n";

  # see if the local file (if it exists) is the same as the
  # remote file time. If so, don't reload.
  if ( -f "download/$module/$chosen" ) {
   if ( getFileTime("download/$module/$chosen") == $time ) {
    last;
   }
  }

  return $chosen if ( !$update && -f "download/$module/$chosen" );

  unlink($chosen) if ( -f $chosen );
  my $url = "$TWikiOrg/p/pub/Plugins/$module/$chosen";
  print STDERR "--- Downloading $url\n";
  `wget -q $url`;
  if ( !$? && -f $chosen ) {
   `chmod -R 777 download/$module && rm -rf download/$module`
     if ( -d "download/$module" );
   mkdir("download/$module");
   `mv $chosen download/$module/`;
   if ( !$? ) {
    if ( $chosen =~ /\.zip$/ ) {
     `cd download/$module && unzip $chosen`;
    }
    elsif ( $chosen =~ /\.tar\.gz$/ || $chosen =~ /\.tgz/ ) {
     `cd download/$module && tar zxf $chosen`;
    }
   }
   return $chosen unless ($?);
   if ( scalar(%$atts) > 1 ) {
    print STDERR "Download $module failed\n";
    last;
   }
  }
  print STDERR "Failed to download $url\n";
 }
 return undef;
}

# Generate HTML for red text
sub RED {
 my $s = join( " ", @_ );
 return "<font color=\"#DD0000\">$s</font>";
}

# Generate HTML for green text
sub GREEN {
 my $s = join( " ", @_ );
 return "<font color=\"#00DD00\">$s</font>";
}

# Generate a table data
sub TD {
 my $s = join( "", @_ );
 return "<td> $s </td>";
}

# Generate a table data with background
sub TD_SHADE {
 my $c = shift;
 my $s = join( "", @_ );
 return "<td bgcolor=\"$c\"> $s </td>";
}

# Generate a row-spanning table data. The TD is generated
# only if the row count is non-zero
sub TDS {
 my $c = shift;
 my $s = join( "", @_ );
 return "" unless ($c);
 return "<td rowspan=\"$c\"> $s </td>";
}

# Generate a table header cell
sub TH {
 my $s = join( "", @_ );
 return "<th> $s </th>";
}

# Generate a table row
sub TR {
 my $s = join( "", @_ );
 return "<tr valign=\"top\">$s</tr>\n";
}

sub THR {
 my $s = "<th>" . join( "</th><th>", @_ ) . "</th>";
 return TR($s);
}

# Generate a coloured table cell.
sub TR_SHADE {
 my $i   = shift;
 my $n   = shift;
 my $s   = join( "", @_ );
 my $q   = 255 * ( $n - $i ) / $n;
 my $col = uc( sprintf( "%02x", $q ) );
 return "<tr valign=\"top\" bgcolor=\"#FF${col}FF\" valign=\"top\">$s</tr>\n";
}

# Generate a table
sub TABLE {
 my $s = join( "", @_ );
 return "<table width=\"100%\" border=\"1\">$s</table>\n";
}

1;
