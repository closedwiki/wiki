# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-2004 Patrick Diamond, patrick_diamond@mailc.net
# Copyright (C) 2001-2003 Peter Thoeny, peter@thoeny.com
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
# Requirements on external modules
#     XML::LibXML 
#     XML::LibXSLT
#     XML::Simple
#     Text::ParseWords
#     Cache::Cache
#     String::CRC
#
#


# =========================
package TWiki::Plugins::XmlQueryPlugin;    # change the package name and $pluginName!!!

use TWiki;
use TWiki::Func;

# =========================
use strict;
use vars qw(
        $web $topic $user $installWeb $VERSION $pluginName
        $debug $activeCfgVar $initialized $xmldir $cache $cachelimit $cacheexpires $datadir $pubdir
    );

BEGIN {
    $initialized = 0;
    $xmldir = '/var/tmp/twiki_xml';
    $xmldir = 'c:/.twiki_xml' if $^O eq 'MSWin32' and $xmldir !~ /^\[a-z]\:/i;
    $VERSION = '1.003';
    $debug=0;
    $cache=undef;
    $cachelimit=1024*1024*100; # default 100 meg
    $cacheexpires='never';
    $pluginName = 'XmlQueryPlugin';  # Name of this Plugin
}

# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" ) || $debug;

    # Get plugin preferences, the variable defined by:          * Set EXAMPLE = ...
    $xmldir = &TWiki::Func::getPreferencesValue( "${pluginName}_XMLDIR" ) || $xmldir;
    my $cl = &TWiki::Func::getPreferencesValue( "${pluginName}_CACHESIZELIMIT" ) || $cachelimit;
    my ($cl_value,$cl_type) = ($cl =~ /^\s*([0-9]*)\s*([a-z]*)\s*$/);
    if (defined $cl_value) {
      if (not defined $cl_type =~  /^m/i ) {
	$cachelimit = $cl_value * 1024  * 1024;# megabytes default
      } else {
	if ($cl_type =~  /^k/i) {
	  $cachelimit = $cl_value * 1024;# kilobytes
	} elsif ($cl_type =~  /^g/i) {
	  $cachelimit = $cl_value * 1024 * 1024 * 1024;# gigabytes!!!
	}
      }
    }

    my $ct = &TWiki::Func::getPreferencesValue( "${pluginName}_CACHEEXPIRES" ) || $cacheexpires;
    $ct =~ s/^\s*//; $ct =~ s/\s*$//; # strip leading and trailing spaces
    if ($ct =~ /^(now|never)$/ or $ct =~ /^[0-9]+\s+(s|second|seconds|sec|m|minute|minutes|min|h|hour|hours|d|day|days|w|week|weeks|M|month|months|y|year|years)$/) {
      $cacheexpires = $ct;
    } else {
      TWiki::Func::writeWarning( "Error CACHEEXPIRES incorrect for $web, $topic Value=\"$ct\"");
    }

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;

    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1] ... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2] $_[1] )" ) if $debug;

    return unless ( $_[0] =~ m/\%(XSLTSTART|XMLSTART)/o );

    $_[0] =~ s/%XSLTSTART{(.*?)}%(.*?)%XSLTEND%/&_handle_XSLT_tag($1,$2,$_[1],$_[2])/geos;
    $_[0] =~ s/%XMLSTART{(.*?)}%(.*?)%XMLEND%/&_handle_XML_tag($1,$2,$_[1],$_[2])/geos;

}

# =========================
sub beforeSaveHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

  TWiki::Func::writeDebug("- ${pluginName}::beforeSaveHandler( $_[2] $_[1] )" ) if $debug;
  generateXML($_[0],$_[1],$_[2]);
}

# =========================
sub afterEditHandler
{
  
    TWiki::Func::writeDebug( "- ${pluginName}::afterEditHandler( $_[2].$_[1] )" ) if $debug;
    # ensure that the cache has a copy of the previewed xml to work with
    generateXML($_[0],$_[1],$_[2],1);
}


sub generateXML {

    #return if $activeCfgVar !~ /true/i;
    TWiki::Func::writeDebug( "TWiki::Plugins::XmlQueryPlugin::_generateXML  $_[1] $_[2]"  ) if $debug;
    return if not _initialize();

    # initize vars
    my $text  = $_[0];
    my $topic = $_[1];
    my $web   = $_[2];
    my $preview = $_[3]; # flaged this xml as preview only
    my $data  = {'metadata'=>{}, 'actions'=>{},'tables'=>{}};

    # extract data
    my $metadata = _processMetaData($text,$topic,$web);
    my $actions  = _processActions($text,$topic,$web);
    my $tables   = _processTables($text,$topic,$web);
    my $xml      = _processXML($text,$topic,$web);

    # build data structure to generate XML
    my $out; $out    = $data;
    $out->{'metadata'} = $metadata;
    $out->{'tables'} = {};
    $out->{'tables'}->{'table'} = $tables;
    $out->{'actions'}->{'action'} = $actions;
    $out->{'xmldata'}->{'xml'}   = $xml;
    $out->{'web'} = $web;
    $out->{'topic'} = $topic;
    $out->{'version'} = $VERSION;
    $out->{'preview'} = 1 if defined $preview;
    my $page = {};
    $page->{'data'} = $out;

    # Generate XML to temporary file
    mkdir ($xmldir) if not -d $xmldir;
    mkdir ("$xmldir/$web") if not -d "$xmldir/$web";
    my $xmlfile = "$xmldir/$web/$topic.xml";
    $xmlfile .= '.preview' if defined $preview;
    open (FH, ">$xmlfile")
      or TWiki::Func::writeWarning( "Error opening XML outputfile $xmldir/$web/$topic.xml $!")
	and return;
    print FH XMLout($page, KeepRoot => 1, XMLDecl => "<?xml version='1.0' encoding='ISO-8859-1'?>");
    close FH;
    $out=undef;
}

sub _processXML {
    # extract XML DATA from the topic text
    my $text  = $_[0];
    my $topic = $_[1];
    my $web   = $_[2];
    TWiki::Func::writeDebug( "TWiki::Plugins::XmlQueryPlugin::_processXML $web $topic "  ) if $debug;
    my $xml = [];

    my $i=-1;
    while ($text =~ /\s*\%XMLSTART\{(.*?)\}\%(.*?)%XMLEND/gs) {
#(.*)\%XMLEND\%/gm) {
	$i++;
	my ($xmlargs,$xmltxt) = ($1,$2);

	$xmlargs = TWiki::Func::expandCommonVariables($xmlargs,$topic,$web) if $xmlargs =~ /\%.*\%/;
	my $h = _args2hash($xmlargs);
	$xml->[$i] = XMLin($xmltxt, KeepRoot => 1, ForceArray => 1) if $xmltxt =~ /\<.*\>/;
	foreach my $key (keys %$h) {
	    $xml->[$i]->{$key} = $h->{$key};
	}
    }
    return $xml;
}


sub _processMetaData {
    # extract META DATA from the topic text
    my $text  = $_[0];
    my $topic = $_[1];
    my $web   = $_[2];
    TWiki::Func::writeDebug( "TWiki::Plugins::XmlQueryPlugin::_processMetaData $web $topic "  ) if $debug;
    my $metadata = {};
    my $reg_m = '\s*\%META:([A-Z]+)\{(.*)\}\%';

    while ($text =~ /$reg_m/g) {
	my ($metatype,$metaargs) = ($1,$2);
	my $args = _args2hash($metaargs);
	# translate dates to a more parseable format
	if (exists $args->{'date'}) {
	    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday) = gmtime($args->{'date'});
	    $year += 1900;
	    $args->{'date'} = sprintf('%04d-%02d-%02dT%02d:%02d:%02d', $year, $mon, $mday, $hour, $min, $sec);
	}
	$metatype = lc($metatype);
	$metadata->{$metatype} = [] if not exists $metadata->{$metatype};
	push @{$metadata->{$metatype}}, {%$args};
    }
    return $metadata;
}

sub _processActions {
    # extract Actions from the topic text
    my $text  = $_[0];
    my $topic = $_[1];
    my $web   = $_[2];
    TWiki::Func::writeDebug( "TWiki::Plugins::XmlQueryPlugin::_processActions $web $topic "  ) if $debug;
    my $actions=[];

    my $gathering;
    my $processAction = 0;
    my $attrs;
    my $descr;
    my $i=-1;
    foreach my $line ( split( /\r?\n/, $text )) {
	if ( $gathering ) {
	    if ( $line =~ m/^$gathering\b.*/ ) {
		$gathering = undef;
		$processAction = 1;
	    } else {
		$descr .= "$line\n";
		next;
	    }
	} elsif ( $line =~ m/.*?%ACTION{(.*?)}%(.*)$/o ) {
	    $attrs = $1;
	    $descr = $2;
	    if ( $descr =~ m/\s*<<(\w+)\s*(.*)$/o ) {
		$descr = $2;
		$gathering = $1;
		next;
	    }
	    $processAction = 1;
	}
	if ( $processAction ) {
	    $i++;
	    $actions->[$i] =  _args2hash($attrs);
	    $actions->[$i]->{'description'} = $descr;
	    $processAction = 0;
	}
    }
    return $actions;
}

sub _processTables {
    # extract table data from the topic text
    my $text  = $_[0];
    my $topic = $_[1];
    my $web   = $_[2];
    TWiki::Func::writeDebug( "TWiki::Plugins::XmlQueryPlugin::_processTables $web $topic "  ) if $debug;
    my $state = '';
    my $i=-1;
    my $row=-1;
    my $tables = [];
    foreach my $line  (split /\n/,$text) {
	if ($line =~ /^\s*\%(EDITTABLE|TABLE)\{(.*?)\}\%/) {
	    # Table defined using EDITTABLE or TABLE macro
	    my $t_type=$1;
	    my $t_args=$2;
	    $i++; # new table
	    $row=-1;
	    $t_args =~ s/(format=[\"\'](.*?)[^\\][\'\"])//ig;#
	    $t_args =~ s/(^\s*,\s*)//;#
	    TWiki::Func::writeDebug( "Args $t_args "  ) if $debug;
	    my $args=_args2hash($t_args);
	    $tables->[$i] = $args if defined $args;
	    $tables->[$i]->{'type'} = $t_type;
	    $tables->[$i]->{'row'} = [];
	    $state='table';
	} elsif ($line =~ /^\s*\|/) {
	    if ($state ne 'table') {
		$i++; # new table
		$row=-1;
		$tables->[$i]->{'row'} = [];
		$state = 'table';
	    }
	    $row++;
	    #$tables->[$i]->{'row'}->[$row] = {'title'=>[], 'data'=>[]};
	    $tables->[$i]->{'row'}->[$row] = {'field' => []};
	    $line =~ s/^\s*\|//; # strip leading |
	    $line =~ s/\|\s*$//; # strip trailing |
	    my @args = split /\|/,$line;
	    $a=-1;
	    ############################
	    # process each cell in a row
	    foreach my $arg (@args) {
		my $header=0; $a++;
		$arg =~ s/^\s+//; # strip leading spaces
		$arg =~ s/\s+$//; # strip trailing spaces
		if ($arg =~ /^(.*)\s*\%EDITCELL\{.*\}\%\s*$/i) {
		    $arg = $1; # strip EDITCELL tags from cell
		}
		
		if ($arg =~ /^(\s*\*\s*)(.*)(\s*\*\s*)/) {
		    $header=1; # flag cell as header
		    $arg=$2;
		}

		$tables->[$i]->{'row'}->[$row]->{'field'}->[$a] = {};
		$tables->[$i]->{'row'}->[$row]->{'field'}->[$a]->{'content'} = $arg;
		if ($header) {
		  $tables->[$i]->{'row'}->[$row]->{'field'}->[$a]->{'type'} = 'title'
		} else {
		  $tables->[$i]->{'row'}->[$row]->{'field'}->[$a]->{'type'} = 'data';
		}
	      }
	  } else {
	    $state='';
	  }
      }
    return $tables;
  }

sub _args2hash {
    # convert a list of arguments as found in a twiki macro into a hash
    my ($string) = @_;

    $string =~ s/^\s*//; # strip leading spaces
    $string =~ s/\s*$//; # strip trailing spaces

    # extact values
    my @e= &quotewords('(\s+|\=)',1,$string);
    my %h = @e;

    # strip leading and trailing spaces & quotes from arg values
    foreach my $key (keys %h) {
      $h{$key} =~ s/^[\s\"\']*//;
      $h{$key} =~ s/[\s\"\']*$//;
    }
    return \%h;
  }

sub _handle_XSLT_tag {
    # process an xslt tag
    my ($args_txt,$xslt_txt,$topic,$web) = @_;
    TWiki::Func::writeDebug( "TWiki::Plugins::XmlQueryPlugin::_handle_XSLT_tag $web $topic "  ) if $debug;
    return if not _initialize();

    my $t0 = new Benchmark;
    my $benchmark = 0;
    my $b = "";
    my $xmlstr;
    my $preview;

    ###############################
    # read the args associated with the xslt
    $args_txt = TWiki::Func::expandCommonVariables($args_txt,$topic,$web) if $args_txt =~ /\%.*\%/;
    my $args = _args2hash($args_txt); 
    $benchmark = 1 if (exists $args->{'benchmark'} and
		       lc($args->{'benchmark'}) eq 'on') or
			 (exists $args->{'debug'} and
			  lc($args->{'debug'}) eq 'on');

    # check for a web def
    my $quiet=0;
    $quiet=1 if (exists $args->{'quiet'} and lc($args->{'quiet'}) eq 'on');

    my $debug_output=0;
    $debug_output = 1 if exists $args->{'debug'} and $args->{'debug'} =~ /^(on|full)$/i;

    # check for caching request
    my $usecache=1; 
    my $crcstr="$VERSION,"; # str used to generate checksum
    my $localcacheexpires = $cacheexpires; # set cache expires to default
    $usecache=0 if (exists $args->{'cache'} and lc($args->{'cache'}) eq 'off');
    if (exists $args->{'cacheexpires'} and 
	($args->{'cacheexpires'} =~ /^(now|never)$/ 
	 or ($args->{'cacheexpires'} =~ /^[0-9]+\s+(s|second|seconds|sec|m|minute|minutes|min|h|hour|hours|d|day|days|w|week|weeks|M|month|months|y|year|years)$/))) {
      $usecache=1;
      $localcacheexpires = $args->{'cacheexpires'};
    }
    $b .= '<tr><td>Eval Args:</td><td>' . timestr(timediff(new Benchmark, $t0)) . "</td></tr>\n" if $benchmark;

    if (not exists $args->{'url'} or (exists $args->{'url'} and $args->{'url'} !~ /^\s*$/)) {
      ##########################################
      # fetch a local web/topic/[attachment]

      # determine the source of the xml
      my ($xweb,$attach) = ($web,undef);
      my @xtopic = ($topic);
      my @attach;
      my $files = {};
      my $fcount=0;

      # check for a web def
      if (exists $args->{'web'}) {
	my @xw = grep {basename($_) =~ /$args->{'web'}/} <$datadir/[A-Z]*>; # find match to web
	if (not @xw) {
	  return if $quiet;
	  return '<font color=red>Error Web ' .  _escapeHTML($args->{'web'}) . ' not matched </font><br>';
	}
	foreach (@xw) {$files->{basename($_)} = {}};
      } else {
	$files->{$web} = {};
      }

      # check for a topic def
      if (exists $args->{'topic'}) {
	foreach my $xweb (keys %$files) {
	  foreach (grep {/$args->{'topic'}/} TWiki::Func::getTopicList($xweb)) {
	    $files->{$xweb}->{$_} = [];
	    $fcount++;
	  };

	}
	if ($fcount == 0) {
	  return if $quiet;
	  return '<font color=red>Error no topics for web '.
	    _escapeHTML($args->{'web'}) .
	      ' topic ' .
		_escapeHTML($args->{'topic'}) .
		  " found </font>$fcount<br>";
	}
      } else {
	# by default the current topic in the current web is used
	$files->{$web}->{$topic} = [];
      }

      # check for an attachment def
      if (exists $args->{'attach'} and $args->{'attach'} !~ /^\s*$/) {
	foreach my $xweb (sort keys %$files) {
	  foreach my $atopic (sort keys %{$files->{$xweb}}) {
	    if (-d "$pubdir/$xweb/$atopic") {
	      foreach my $f (sort grep {/$args->{'attach'}/} <$pubdir/$xweb/$atopic/*>) {
		push @{$files->{$xweb}->{$atopic}}, $f;
		if ($usecache) {
		  my @s = stat($f);
		  $crcstr .= $s[9] . ','; # add last modified date to crc string
		}
		$fcount++;
	      }
	    }
	  }
	}
      }

      $b .= "<tr><td>Files Ref Checked $fcount :</td><td>" . timestr(timediff(new Benchmark, $t0)) . "</td></tr>\n" if $benchmark;

      # include multiple xml topics
      $xmlstr='<?xml version="1.0" encoding="ISO-8859-1"?>
<twiki xmlns:xi="http://www.w3.org/2001/XInclude">
';
      # include topic info
      my ($timestamps,$num_updated) = _ensureXMLUptodate($files);
      $crcstr .= $timestamps;
      foreach my $xweb (sort keys %$files) {
	$xmlstr.="<web name=\"$xweb\">\n";
	foreach my $atopic (sort keys %{$files->{$xweb}}) {
	  $xmlstr.="\n<topic name=\"$atopic\">\n";

	  # insert the topic xml, preview xml if it is available for this topic
	  if ($xweb eq $web and $atopic eq $topic and -r "$xmldir/$xweb/$atopic.xml.preview" ) {
	    $usecache = 0;
	    $preview = "$xmldir/$xweb/$atopic.xml.preview";
	    $xmlstr .= "<xi:include href=\"$xmldir/$xweb/$atopic.xml.preview\"/>\n";
	    $crcstr .= localtime();
	  } else {
	    $crcstr .= ',';
	    $xmlstr .= "<xi:include href=\"$xmldir/$xweb/$atopic.xml\"/>\n";
	  }

	  # now include attachments
	  $xmlstr.='<attachments>' . "\n";
	  foreach my $attach (@{$files->{$xweb}->{$atopic}}) {
	    $xmlstr .= '<attachment name=\"' . basename($attach) . "\">\n";
	    $xmlstr .= "<xi:include href=\"$attach\"/>\n";
	    $xmlstr .= '</attachment>' . "\n";
	  }
	  $xmlstr .= '</attachments>' . "\n";
	  $xmlstr .= '</topic>' . "\n";
	}

	$xmlstr .= '</web>'."\n";
      }
      $xmlstr .= '</twiki>';

      $b .= "<tr><td>XML Updated $num_updated:</td><td>" . timestr(timediff(new Benchmark, $t0)) . "</td></tr>\n" if $benchmark;
    }

    $crcstr .= $xmlstr; # add the toplevel xml to the checksum

    # where  a url has been defined setup appropiate crcstr
    if (exists $args->{'url'} and $args->{'url'} !~ /^\s*$/) {
      $crcstr .= $args->{'url'};
    }

    # when caching is on and debug off then use cache
    my $cache_available=0;
    my $checksum;
    my $result_str;
    if ($usecache and not $debug_output) {
      $cache->set_namespace('XSLT_Result');
      $checksum = crc($crcstr . $xslt_txt . $args_txt);
      $result_str = $cache->get($checksum);
      if (defined $result_str) { 
	$b .= '<tr><td>Cache Fetch:</td><td>' . timestr(timediff(new Benchmark, $t0)) . "</td></tr>\n" if $benchmark;
	$cache_available=1;
      } else {
	$b .= '<tr><td>Cache Check:</td><td>' . timestr(timediff(new Benchmark, $t0)) . "</td></tr>\n" if $benchmark;
      }
    }

    ##########################################
    # if a URL has been defined then fetch that
    if (not $cache_available and exists $args->{'url'} and  $args->{'url'} !~ /^\s*$/) {
      my $ua = LWP::UserAgent->new;
      $ua->env_proxy;
      my $response = $ua->get($args->{'url'});
      if ($response->is_success) {
	$xmlstr = $response->content;
      } else {
	return '<font color=red>Error loading ' .  _escapeHTML($args->{'url'}) . '<br>'. $response->status_line .' </font><br>';
      }
      $b .= '<tr><td>URL Get:</td><td>' . timestr(timediff(new Benchmark, $t0)) . "</td></tr>\n" if $benchmark;
    }

    if ( not $cache_available) {
      # generate the result directly

      #############################################
      # prepare the stylesheets, catching any errors
      my $stylesheet;
      my $xml;
      eval {
	my $parser = XML::LibXML->new();
	my $xmlcrc = crc($crcstr);
	$b .= '<tr><td>XML parser Setup:</td><td>' . timestr(timediff(new Benchmark, $t0)) . "</td></tr>\n" if $benchmark;
	$xml = $parser->parse_string($xmlstr);
	$b .= '<tr><td>XML parse toplevel string:</td><td>' . timestr(timediff(new Benchmark, $t0)) . "</td></tr>\n" if $benchmark;
	$parser->process_xincludes($xml);
	$b .= '<tr><td>XML parse includes:</td><td>' . timestr(timediff(new Benchmark, $t0)) . "</td></tr>\n" if $benchmark;
	my $style_doc = $parser->parse_string($xslt_txt);
	my $xslt = XML::LibXSLT->new();
	$stylesheet = $xslt->parse_stylesheet($style_doc);
      };

      if ($@ or not defined $xml) {
	unlink $preview if defined $preview;
	return if $quiet;
	return '<table border=1><caption>XSLT ERRORS</caption>' .
	  '<tr><th valign=top>Error Message</th><td><pre>' . 
	    _escapeHTML($@) . 
	      '...</pre></td></tr><tr><th valign=top>XSLT</th><td><pre>' . 
		_escapeHTML($xslt_txt) . 
		  '</pre></td></tr><tr><th valign=top>XML</th><td><pre>'.
		    _escapeHTML(substr($xml->toString,0,9999)) . 
		      '</pre></td></tr></table>';
      }
      unlink $preview if defined $preview;
      $b .= '<tr><td>XML Parse XSLT:</td><td>' . timestr(timediff(new Benchmark, $t0)) . "</td></tr>\n" if $benchmark;

      #############################
      # transform the xml with the xslt
      my $results;
      eval {
	if (not scalar(keys %$args)) {
	  # no args to pass
	  $results = $stylesheet->transform($xml);
	} else {
	  # pass args into stylesheet
	  $results = $stylesheet->transform($xml, XML::LibXSLT::xpath_to_string(%$args));
	}
      };
      if ($@) {
	return if $quiet;
	return "<pre>\n($@)</pre>" if $@;
      }

      $b .= '<tr><td>XSLT Transform:</td><td>' . timestr(timediff(new Benchmark, $t0)) . "</td></tr>\n" if $benchmark;
      $result_str = $stylesheet->output_string($results);

      # save the result
      $cache->set($checksum,$result_str,$localcacheexpires) if ($usecache and not $debug_output);

      # user requested debug output
      if ($debug_output) {
	my $xml_string;
	if ($args->{'debug'} =~ /^full$/) {
	  $xml_string = $xml->toString;
	} else {
	  $xml_string = substr($xml->toString,0,9999);
	}
	return "<table border=1><caption>DEBUG=$args->{'debug'}</caption>" .
	  '<tr><th valign=top>XML</th><td><pre>' .
	    _escapeHTML($xml_string) .
	      '...</pre></td></tr><tr><th valign=top>XSLT</th><td><pre>' . 
		_escapeHTML($xslt_txt) . 
		  '</pre></td></tr><tr><th valign=top>Result</th><td><pre>'.
		    _escapeHTML($result_str) .
		      '</pre></td></tr><tr><th valign=top>Settings</th><td>'.
			"<table><th>Using Cache</th><td>$usecache</td></tr><tr><th>Cache size limit</th><td>$cachelimit</td></tr><tr><th>Cache Expires</th><td>$localcacheexpires</td></tr><tr><th>XMLDIR</th><td>$xmldir</td></tr></table>".
			  '</td></tr><tr><th valign=top>Benchmark</th><td><table>' .
			    _escapeHTML($b) . 
			      '</table></td></tr></table>';
      }
      }

    # user requested benchmark numbers along with result
    return $result_str . "<br><b>Benchmark</b><table>$b</table>" if $benchmark;

    # vanilla result
    return $result_str;
}

sub _handle_XML_tag {
    # process an xml tag
    my ($args_txt,$xml_txt,$topic,$web) = @_;
    TWiki::Func::writeDebug( "TWiki::Plugins::XmlQueryPlugin::_handle_XML_tag $web $topic "  ) if $debug;
    return if not _initialize();

    # read the args associated with the xml
    $args_txt = TWiki::Func::expandCommonVariables($args_txt,$topic,$web) if $args_txt =~ /\%.*\%/;
    my $args = _args2hash($args_txt);

    # by default the xml is displayed vertbatium
    $args->{'display'} = 'verbatim' if not exists $args->{'display'};

    if ($args->{'display'} eq 'include') {
      return "<!-- <pre> -->\n$xml_txt\n</pre>";
      #return _reformatXML($xml_txt);
    }

    return '' if $args->{'display'} eq 'hidden';
    if ($args->{'display'} eq 'verbatim') {
      return _escapeHTML($xml_txt);
    };

}

sub _escapeHTML {
  my $txt = $_[0];
  $txt =~ s<([^\x20\x21\x23\x27-\x3b\x3d\x3F-\x5B\x5D-\x7E])>
           <'&#'.(ord($1)).';'>seg;
  return $txt;
}

sub _ensureXMLUptodate {
  # ensure that the XML files which tracks the topic are up todate
  # returns the last modified date stamps
  my $files = $_[0];

  TWiki::Func::writeDebug( "TWiki::Plugins::XmlQueryPlugin::_ensureXMLUptodate $web $topic "  ) if $debug;

  my $return_str;
  my $updated = 0;
  foreach my $web (sort keys %$files) {
    foreach my $topic (sort keys %{$files->{$web}}) {
      my $xml_file = "$xmldir/$web/$topic.xml";
      if (! -r $xml_file)  {
	# generate xml as no xml is currently available
	my $txt = TWiki::Func::readTopicText($web,$topic);
	generateXML($txt,$topic,$web);
	$txt = undef;
	my @stat = stat($xml_file);
	$return_str.= $stat[9];
	$updated++;
      } else {
	# generate xml if topic text is older than xml (within a couple of seconds)
	my @s1 = stat($datadir . "/$web/$topic.txt");
	my @s2 = stat($xml_file);
	if ($s1[9] > $s2[9]+1) {
	  my $txt = TWiki::Func::readTopicText($web,$topic);
	  generateXML($txt,$topic,$web);
	  $updated++;
	  $txt = undef;
	}
	$return_str .= $s2[9];
      }
    }
  }
  return ($return_str, $updated);
}

sub _initialize {
  # optimized loading of external Modules

  if (! $initialized) {
	foreach my $lib ('XML::LibXML', 'XML::LibXSLT', 'XML::Simple', 'Benchmark', 'Text::ParseWords', 'Cache::SizeAwareFileCache', 'String::CRC', 'File::Basename', 'LWP::UserAgent') {
	  eval "use $lib;";
	  if ($@) {
		TWiki::Func::writeWarning( "Module $lib failed to load $@" );
		return 0;
	    }
	}

	$xmldir =~ s/\/$//; # remove trailing /
	$xmldir .= "/$VERSION"; # ensure that the XML generated per topic is versioned

	# setup filecase in xmldir limited to 100 Megs
	$cache = new Cache::SizeAwareFileCache( { 'namespace' => 'XSLT_Result',
						  'cache_root' => "$xmldir/_xmlquerycache",
						  'max_size' => $cachelimit } );
	if (not defined $cache) {
	  TWiki::Func::writeWarning( "Couldn't instantiate SizeAwareFileCache $!" );
	  return 0;
	}

	$datadir = TWiki::Func::getDataDir();
	$pubdir = TWiki::Func::getPubDir();
	$initialized=1;
    }
    return 1;
}

1;

