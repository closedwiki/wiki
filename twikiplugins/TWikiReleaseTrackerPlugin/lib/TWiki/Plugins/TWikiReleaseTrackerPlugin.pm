#! perl -w
use strict;

# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004-     Martin Cleaver, Martin@Cleaver.org
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
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

# =========================
package TWiki::Plugins::TWikiReleaseTrackerPlugin;
use TWiki::Func;
use TWiki;
use CGI;

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $pluginName
  $debug $cgiQuery %showStatusFilter
  %listingFormat
  $fdcsFormat $fscsFormat $fscdFormat $fdcdFormat
);

BEGIN {

# The following adds context to @INC such that it can find the modules it depends on
# without requiring those (generic) modules to be in the TWiki::Plugins namespace
	unshift @INC, "../lib/TWiki/Plugins/TWikiReleaseTrackerPlugin";
}

$VERSION    = '1.010';
$pluginName = 'TWikiReleaseTrackerPlugin';    # Name of this Plugin
$debug      = 0;

# =========================
sub commonTagsHandler {
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead
	writeDebug("commonTagsHandler( $_[2].$_[1] )");
	$_[0] =~ s/%DIFFWIKI{(.*?)}%/&handleDiffWiki($1)/ge;
	$_[0] =~ s/%DIFFWIKIINDEX{(.*?)}%/&handleShowIndex($1)/ge;
}

sub getParam {
	my ( $inlineParamString, $paramName ) = @_;
	my $ans = untaint( $cgiQuery->param($paramName) );

	#    writeDebug("$inlineParamString\n1: $paramName = $ans");
	unless ( $ans ne "" ) {
		$ans =
		  TWiki::Func::extractNameValuePair( $inlineParamString, $paramName );
	}

	#    writeDebug("2: $paramName = $ans");
	unless ( $ans ne "" ) {
		$ans =
		  TWiki::Prefs::getPreferencesValue("\U$pluginName\E_\U$paramName\E");
	}

	#    writeDebug("$paramName = $ans");
	return $ans;
}

sub handleDiffWiki {
	my ($param) = @_;

	$cgiQuery = new CGI;

	my $fileParam = getParam( $param, 'file' );
	my @distributions = split /,/, getParam( $param, 'to' );
	if ( ( $#distributions == -1 ) || ( $distributions[0] eq "all" ) ) {
		@distributions = ();
	}

	my $modeParam = getParam( $param, 'mode' ) || 'listing';
	my $compareFromDistribution = getParam( $param, 'from' )
	  || 'localInstallation';
	Common::setIndexTopic( getParam( $param, 'indexTopic' )
		  || 'TWiki.TWikiReleaseTrackerPlugin' );

	$fscsFormat = getParam( $param, "fscsFormat" )
	  || '| $relativeFile | FSCS | $locations |' . "\n";

	$fscdFormat = getParam( $param, "fscdFormat" )
	  || '<TABLE border=1> <TR><TD><b> $fromDistribution - $relativeFile (FSCDCALLBACK)</b>'
	  . "\n"
	  . '</TD><TD>FSCDDIFF </TD></TR></TABLE>';

	#        '| $relativeFile | FSCDCALLBACK | FSCDDIST |'."\n";

	$fdcdFormat = getParam( $param, "fdcdFormat" )
	  || '| ($relativeFile name not recognised, and no content match)  | FDCD | |'
	  . "\n";

	$listingFormat{'FDCS'} = getParam( $param, "fdcsFormat" )
	  || '| $relativeFile | FDCS | $locations |' . "\n";

	$debug = getParam( $param, 'debug' ) || 0;
	if ( $debug eq "1" ) { $debug = "on" }
	;    # NB. BROKEN should allow CGI to carry the debug flag

	setStatusFilter(
		getParam( $param, "statusFilter" )
		  || "FSCS, FSCD, FDCS, FDCD" #Filename Same/Different, Content Same/Different
	);

	writeDebug("handling...");

	my $ans;
	$ans = "$param" if $debug;
	if ( !defined($modeParam) or $modeParam eq 'listing' ) {
		$ans .=
		  listFiles( $compareFromDistribution, @distributions )
		  ; # calls back to foundFile() with each file found in the current distro.
	}
	elsif ( $modeParam eq 'dumpIndex' ) {
		$ans .= dumpIndex();
	}
	elsif ($modeParam eq 'indexLocalInstallation' ) {
	    $ans = "<pre>".IndexDistributions::indexLocalInstallation()."</pre>";
	}
	else {
		$ans .=
		  compareFile( $fileParam, $modeParam, $compareFromDistribution,
			@distributions );
	}
	return $ans;
}

sub formatList {
	my ( $format, $separator, $selection, $marker, @list ) = @_;

#CodeSmell - stolen from handleWebAndTopicList, this needs making generic in Func.pm:
	my $ans  = "";
	my $item = "";
	my $line = "";
	my $mark = "";

	foreach my $item (@list) {
		my $line = $format;
		$line =~ s/\$name/$item/goi;
		$mark = ( $item eq $selection ) ? $marker : "";
		$line =~ s/\$marker/$mark/goi;
		$ans .= "$line$separator";
	}
	return $ans;
}

sub handleShowIndex {
	my ($param) = @_;
	loadIndexes();

	$cgiQuery = new CGI;

	my $format = TWiki::Func::extractNameValuePair( $param, "format" ) || ',';
	my $separator = TWiki::Func::extractNameValuePair( $param, "separator" )
	  || "";
	$format .= '$name' if ( !( $format =~ /\$name/ ) );
	my $selection = TWiki::Func::extractNameValuePair( $param, "selection" )
	  || "";
	my $marker = TWiki::Func::extractNameValuePair( $param, "marker" )
	  || "selected";

	if ( $param =~ m/distributions/ ) {
		return formatList( $format, $separator, $selection, $marker,
			sort &FileDigest::getDistributions );
	}
	elsif ( $param =~ m/filenames/ ) {
		return formatList( $format, sort &FileDigest::getFilenames );
	}
	else {
		return "usage: distributions or filenames\n";
	}

}

sub foundFile {
	my ( $debugInfo, $status, $relativeFile, $locations,
		$comparedToDistribution, @allDistributionsForFilename )
	  = @_;
	my $ans;
	$ans .= $debugInfo if ( $debug eq "2" );

	return $ans unless $showStatusFilter{$status};

	# FIXME: simplify into a hash
	if ( $status eq "FSCS" ) {
		if ($fscsFormat) {
			my $line = $fscsFormat;
			$ans .= $line;
		}
	}
	elsif ( $status eq "FSCD" ) {
		if ($fscdFormat) {
			my $line = $fscdFormat;
			$ans .= $line;
		}
	}
	elsif ( $status eq "FDCS" ) {
		if ( $listingFormat{'FDCS'} ) {
			my $line = $listingFormat{'FDCS'};
			$ans .= $line;
		}
	}
	elsif ( $status eq "FDCD" ) {
		if ($fdcdFormat) {
			my $line = $fdcdFormat;
			$ans .= $line;
		}
	}
	else {
		unless ($debug) {
			die "Illegal status - $!";
		}
		$ans .= "| $relativeFile | DIED | $locations |\n";
	}
	$ans =~ s/\$relativeFile/$relativeFile/;
	$ans =~ s/\$locations/$locations/;
	$ans =~ s/\$fromDistribution/$comparedToDistribution/;

	$ans =~ s/FSCDCALLBACK/&browserCallback("FSCD",
					   'file'=>$relativeFile,
					   'mode'=>'lineCount',
					   'to'=> join(",",@allDistributionsForFilename))/e;
	$ans =~ s/FSCDDIST/"<LI>".join("<LI>", @allDistributionsForFilename)/e;
	$relativeFile           = untaint($relativeFile);
	$comparedToDistribution = untaint($comparedToDistribution);

	if ( $ans =~ m/FSCDDIFF/ ) {
		my $comparison;
		foreach my $dist (@allDistributionsForFilename) {
			$dist = untaint($dist);

			my ( $output, $changeExpression, $cmd ) =
			  diffFiles( $relativeFile, $comparedToDistribution, $dist, "-u" );
			$comparison .= "<b>\$toDistribution</b>\n<pre>$output</pre>\n";
			$comparison =~ s/\$toDistribution/$dist/;
		}
		$ans =~ s!FSCDDIFF!$comparison!;
	}

	$ans .= $debugInfo if ( $debug eq "on" );
	return $ans;
}

# =========================

sub compareFile {
	my ( $file, $mode, $compareToDistribution, @distributions ) = @_;

	my $ans;
	my $modeCallback = selectModeCallback($mode);

	my $distString = join( ",", @distributions );
	$ans .=
	  browserCallback( "   <LI> Back to file listing", 'mode' => 'listing' )
	  . "\n";
	$ans .= browserCallback(
		"   <LI> Linecount differences for distribution(s) " . $distString,
		'file' => $file,
		'to'   => $distString,
		'mode' => "lineCount"
	  )
	  . "\n";
	$ans .= browserCallback(
		"   <LI> Detailed differences for distribution(s) " . $distString,
		'file' => $file,
		'to'   => $distString,
		'mode' => 'diff'
	  )
	  . "\n";

	$ans .= "---++!! Comparing $compareToDistribution:$file ($mode) \n";
	$ans .= "%TOC%\n";    # FIXME (NB. This TOC does not work);
	foreach my $distribution ( reverse sort @distributions ) {
		next if ( $distribution eq $compareToDistribution );
		$ans .= "---++ With <nop>$distribution\n";
		$ans .=
		  &$modeCallback( $file, $distribution, $compareToDistribution, "-u " );
		$ans .= "\n\n";
	}
	loadIndexes();

	# e.g.
	# if  allDistributions = (A, B, C);
	# and distributions = (A, B)
	# then unmentionedDistributions = (C);
	my @mentionedDistributions = sort @distributions, $compareToDistribution;
	my @allDistributions = FileDigest::retreiveDistributionsForFilename($file);
	my @remainingDistributions = sort @allDistributions;

	my $mentionedCount = 0;
	foreach my $distribution (@mentionedDistributions) {
		if ( $mentionedDistributions[$mentionedCount] eq $distribution ) {
			shift @remainingDistributions;

#	    $ans .= "<LI> (so remainingDistributions now =)".join(",", @remainingDistributions);
		}
		$mentionedCount++;
	}
	my $unmentionedDistributions = join( ",", @remainingDistributions );
	my $allDistributions         = join( ",", sort @allDistributions );
	$ans .= "---++ Widen comparison for $file to other distributions \n";
	if ($unmentionedDistributions) {
		$ans .=
"This file also occurs in other distributions - clicking below will open the comparison to these too<BR>"
		  . "<LI> "
		  . browserCallback(
			"Unlisted: <nop>" . join( ", <nop>", @remainingDistributions ),
			'to' => $unmentionedDistributions )
		  . "\n" . "<LI> "
		  . browserCallback(
			"All: <nop>" . join( ", <nop>", sort @allDistributions ),
			'to' => $allDistributions )
		  . "\n";
	}
	else {
		$ans .= "All distributions where this file occurs are listed above\n";
	}
	$ans .= "---++ Swap to and from\n" . "<LI>"
	  . browserCallback(
		"Swap to and from distributions",
		'to'   => $compareToDistribution,
		'from' => $distString
	  )
	  . "\n";

	return $ans;
}

#==============================================================

sub diffFiles {
	my ( $file, $distribution, $comparedDistribution, $fileDiffParams ) = @_;
	my $ans;
	$ans .=
"   * file = '$file', dist='$distribution', comp='$comparedDistribution' <HR>"
	  if $debug;

	my $file1 = getFile( $file, $distribution );
	my $file2 = getFile( $file, $comparedDistribution );

	my $cmd              = "diff $fileDiffParams $file1 $file2";
	my $output           = captureOutput($cmd);
	my $changeExpression = countChangesUnifiedDiff($output);

	return ( $output, $changeExpression, $cmd );
}

sub diffFilesLineCountModeCallback {
	my ( $file, $distribution, $comparedDistribution, $fileDiffParams ) = @_;

	my ( $output, $changeExpression, $cmd ) =
	  diffFiles( $file, $distribution, $comparedDistribution, $fileDiffParams );

	my $ans = "<LI> Show diff detail for only this distribution: "
	  . browserCallback(
		$changeExpression,
		'file' => $file,
		'to'   => $distribution,
		'mode' => 'diff'
	  );
	return $ans;

}

# from http://www.premodern.org/~nlanza/software/diffbrowse#parse_patch
sub countChangesUnifiedDiff {
	my ($udiff) = @_;
	if ( $udiff =~ /^diff:/ ) {
		return "-1 (cannot parse $udiff)";
	}    # FIXME
	my @lines = split /\n/, $udiff;

	my $chunkno = -1;
	my @changeLines;
	my $totalChanged = 0;
	foreach (@lines) {
		if (m|\@\@|) {
			$chunkno++;    # new chunk

			my ( $oldline, $changeLine, $oldlen, $newline, $newlen ) =
			  (m|^\@\@\s+(\-([0-9]+),([0-9]+)\s+\+([0-9]+),([0-9]+))+\s+\@\@|);

			my $change = $newlen + $oldlen;
			$totalChanged += $change;
			push @changeLines, $oldline;
		}
	}
	my $changeExpression =
	  "$totalChanged (" . join( ", ", @changeLines ) . ")\n";
	return $changeExpression;
}

sub diffFilesModeCallback {
	my ( $file, $distribution, $comparedDistribution, $fileDiffParams ) = @_;
	my ( $output, $changeExpression, $cmd ) =
	  diffFiles( $file, $distribution, $comparedDistribution, $fileDiffParams );

	return "---+++ " . $changeExpression . "$cmd\n" . monotypeToHTML($output);
}

# counts the number of lines changed in a normal (not unified) diff
sub countChangesNormalDiff {
	my ($output) = @_;
	my @changeLines;
	my $totalChanged = 0;
	foreach my $line ( split /\n/, $output ) {
		next unless ( $line =~ m/^\*\*\* (.*),(.*) \*\*\*\*$/ );
		my ( $first, $last ) = ( $1, $2 );
		$totalChanged += ( $last - $first );
		push @changeLines, "$first - $last";
	}
	my $changeExpression =
	  "$totalChanged (" . join( ", ", @changeLines ) . ")\n";
	return $changeExpression;
}

# =====================================================

sub dumpIndex {
	loadIndexes();

	return "<pre>" . FileDigest::dataOutline() . "</pre>";
}

# =====================================================

sub listFiles {
	my ( $compareToDistribution, @distributions ) = @_;
	use Cwd;
	my $ans;
	$| = 1;    # unbuffered CGI output, not sure if this works.

	loadIndexes();

	$ans .= $@ if ($@);
	$ans .= "| *File* | *Status* | *Also Occurs In* |\n";

# This sub is called for every file found to match the compareToDistribution parameter
	my $matchCallback = sub {
		my ( $comparedDistribution, $distributionLocation, $absoluteFile,
			$relativeFile, $digest )
		  = @_;
		my $debugInfo;

		my @distributionsWithDigest =
		  FileDigest::retreiveDistributionsForDigest( $digest, $relativeFile );
		@distributionsWithDigest =
		  grep { !/$compareToDistribution/ }
		  @distributionsWithDigest;    # don't match self

		my @allDistributionsForFilename =
		  FileDigest::retreiveDistributionsForFilename($relativeFile);
		@allDistributionsForFilename =
		  grep { !/$compareToDistribution/ }
		  @allDistributionsForFilename;    # don't match self

		if ( $#distributions > -1 ) {      # restrict to specified distributions
			$debugInfo .=
			  "|*<LI> Pre-filter results: filename: "
			  . join( ", ", @allDistributionsForFilename ) . " <BR>";
			$debugInfo .=
			  "<LI> Pre-filter results: digest: "
			  . join( ", ", @distributionsWithDigest ) . "*|\n";
			@allDistributionsForFilename =
			  restrictDistributionsToFilter( \@allDistributionsForFilename,
				\@distributions );
			@distributionsWithDigest =
			  restrictDistributionsToFilter( \@distributionsWithDigest,
				\@distributions );
		}
		my $locations = "<LI>"
		  . join( "<LI>", @distributionsWithDigest )
		  ;    #CodeSmell: why not need the filename dists?

		my $numberOfDigestMatches   = $#distributionsWithDigest + 1;
		my $numberOfFilenameMatches = $#allDistributionsForFilename + 1;

		$debugInfo .=
"|*$relativeFile = $digest<BR> comparedDistribution='$comparedDistribution', location='$distributionLocation', absoluteFile='$absoluteFile'  "
		  . "<BR>Distributions: "
		  . join( ", <nop>", @distributions )
		  . "<BR>All distributions where filename occurred: ("
		  . $numberOfFilenameMatches
		  . ") <nop>"
		  . join( ", <nop>", @allDistributionsForFilename )
		  . "<BR> Matched in: ("
		  . $numberOfDigestMatches
		  . ") <nop>"
		  . join( ", <nop>", @distributionsWithDigest ) . " <BR>" . "*| "
		  . " \n";

		if ( $numberOfFilenameMatches > 0 )
		{    # filename normally occurs somewhere
			if ( $numberOfDigestMatches > 0 ) { # and contents matched somewhere
				$ans .=
				  foundFile( $debugInfo, "FSCS", $relativeFile, $locations )
				  ;                             # so say where
			}
			else {    # filename occurred, but our content different
				$ans .=
				  foundFile( $debugInfo, "FSCD", $relativeFile, $locations,
					$comparedDistribution, @allDistributionsForFilename );
			}
		}
		else {        # this is a filename that has never occurred in a distro
			if ( $numberOfDigestMatches > 0 ) {   #content matches - was renamed
				$ans .=
				  foundFile( $debugInfo, "FDCS", $relativeFile, $locations );
			}
			else {                                # new file
				$ans .=
				  foundFile( $debugInfo, "FDCD", $relativeFile, $locations );
			}
		}

	};    # sub $matchCallback

	writeDebug("handling 3...");

	#    InstallationWalker::match("",
	#			     $Common::installationDir,
	#			     $Common::excludeFilePattern,
	#			     $matchCallback);
	my $countMatches = DistributionWalker::match(
		$compareToDistribution,      $Common::installationDir,
		$Common::excludeFilePattern, $matchCallback
	);
	if ( $countMatches < 1 ) {
		$ans = "No matches - is there an index for $compareToDistribution?";
	}

	writeDebug("handling 4...");
	return $ans;
}

# =====================================================

sub getFile {
	my ( $file, $distribution ) = @_;
	if ( $distribution eq "localInstallation" ) {
		return getLocalVersion($file);
	}
	else {
		return getDistributionVersion( $file, $distribution );
	}
}

sub getLocalVersion {
	return "../../" . $_[0];
}

sub getDistributionVersion {
	my ( $file, $distribution ) = @_;
	$file =~ s!^twiki/!!;
	my $file2 = $Common::downloadDir . "/" . $distribution . "/" . $file;
	return $file2;
}

# =====================================================

sub selectModeCallback {
	my ($selector) = @_;
	my $modeCallback;
	if ( $selector eq "diff" ) {
		$modeCallback = \&diffFilesModeCallback;
	}
	else {
		$modeCallback = \&diffFilesLineCountModeCallback;
	}
	return $modeCallback;
}

sub untaint {
	my ($param) = @_;
	return "" unless ( defined $param );
	$param =~ s/$TWiki::securityFilter//go;
	$param =~ /(.*)/;
	return $1;
}

sub browserCallback {
	my ( $text, @newParamsArray ) = @_;
	my $newQuery  = new CGI($cgiQuery);    # clone existing;
	my %newParams = @newParamsArray;

	#    $newQuery->param(\%newParams); # bang in the new params - didn't work
	while ( my ( $k, $v ) = ( each %newParams ) ) {
		$newQuery->param( -name => $k, -values => $v ); # bang in the new params
	}
	return "<A HREF=\"" . $newQuery->self_url . "\">$text</A>";
}

sub captureOutput {
	my ($cmd) = @_;
	my $res = $cmd . "\n\n";
	$res = `$cmd 2>&1`;
	return $res;
}

sub monotypeToHTML {
	my ($res) = @_;
	my $ans = "\n<verbatim>\n";
	$ans .= CGI::escapeHTML($res);
	$ans .= "\n</verbatim>\n";
	return $ans;
}

sub restrictDistributionsToFilter {
	my ( $listRef, $filterListRef ) = @_;
	my @ans;
	foreach my $element ( @{$listRef} ) {
	  ELEMENT:
		foreach my $filter ( @{$filterListRef} ) {
			if ( $element =~ m/^$filter/ ) {

	 # has to appear at the start to avoid problems of distro names appearing in
	 # filenames
				push @ans, $element;
				next ELEMENT;
			}
		}
	}
	return @ans;
}

sub setStatusFilter {
	my ($statusFilter) = @_;
	foreach my $f ( split /,/, $statusFilter ) {
		$f =~ s/ //g;
		$showStatusFilter{$f} = 1;
	}
	if ( $statusFilter eq 'all' ) {
		foreach my $f (qw(FSCS FSCD FDCS FDCD)) {
			$showStatusFilter{$f} = 1;
		}
	}
}

sub writeDebug {
	my ($message) = @_;
	TWiki::Func::writeDebug("- TWiki::Plugins::${pluginName} $message")
	  if $debug;
}

# =========================
sub initPlugin {
	( $topic, $web, $user, $installWeb ) = @_;

	# check for Plugins.pm versions
	if ( $TWiki::Plugins::VERSION < 1 ) {
		TWiki::Func::writeWarning(
			"Version mismatch between $pluginName and Plugins.pm");
		return 0;
	}

	my $pluginNameCaps = "\U$pluginName\E";

	# Get plugin debug flag
	$debug = 1;    #TWiki::Func::getPreferencesFlag( "$pluginNameCaps_DEBUG" );
	writeDebug("initialising");

	use TWiki::Plugins::TWikiReleaseTrackerPlugin::DistributionWalker;

	#    use TWiki::Plugins::TWikiReleaseTrackerPlugin::InstallationWalker;
	use TWiki::Plugins::TWikiReleaseTrackerPlugin::Common;

	# Plugin correctly initialized
	writeDebug("initPlugin( $web.$topic ) is OK");
	return 1;
}

sub loadIndexes {
	writeDebug("Loading from $Common::md5IndexDir");
	eval {
		FileDigest::emptyIndexes();
		FileDigest::loadIndexes($Common::md5IndexDir);
	};
	writeDebug($@) if ($@);
	return $@;
}

1;
