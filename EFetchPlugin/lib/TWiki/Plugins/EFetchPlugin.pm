# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Cole Beck, cole.beck@vanderbilt.edu
# Copyright (C) 2004-2013 TWiki:TWiki.TWikiContributor
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
# This is the EFetchPlugin.  It utilizes the EFetch tool from Entrez
# with PubMed to lookup abstract information.
# See http://eutils.ncbi.nlm.nih.gov/entrez/query/static/eutils_help.html
#
# Thanks to FEH and JRH
#
# =========================
package TWiki::Plugins::EFetchPlugin;

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $pluginName
        $debug $doOldInclude $renderingWeb
        %pubmedCache $pubmedCacheFilename $pubmedCacheLockfile
        $retrievalError $maxAuthors
    );

$VERSION = '$Rev$';
$RELEASE = '2013-01-08';

$pluginName = 'EFetchPlugin';  # Name of this Plugin
$maxAuthors = 10;  # IH, 9/5/07
use LWP::Simple;
use DB_File;  # IH, 9/5/2007

# wrapper for LWP's get method that caches results -- IH, 9/5/2007
$pubmedCacheFilename = $TWiki::cfg{DataDir} . "/" . $pluginName . ".dbm";
$pubmedCacheLockfile = $pubmedCacheFilename . ".lock";
$retrievalError = "Document retrieval error";

sub getFromPubmedCache {
    my ($pmid, $rettype) = @_;
    my $url = "http://www.ncbi.nlm.nih.gov/entrez/eutils/efetch.fcgi?rettype=$rettype&retmode=text&db=pubmed&id=$pmid";
    my $key = "$pmid/$rettype";
    if (exists $pubmedCache{$key}) {
	TWiki::Func::writeDebug( "- ${pluginName}::getFromPubmedCache( $pmid, $rettype ): found in cache" ) if $debug;
	return $pubmedCache{$key};
    }
    my $ret;
    for (my $retry = 0; $retry < 4; ++$retry) {
	$ret = get($url);
	unless (!defined($ret) || $ret =~ /$retrievalError/) {
	    TWiki::Func::writeDebug( "- ${pluginName}::getFromPubmedCache( $pmid, $rettype ): not found in cache, fetched from NCBI" ) if $debug;
	    $pubmedCache{$key} = $ret;
	    return $ret;
	}
    }
    TWiki::Func::writeDebug( "- ${pluginName}::getFromPubmedCache( $pmid, $rettype ): not found in cache, not found at NCBI" ) if $debug;
    return undef;
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

    # Get plugin preferences
    $doOldInclude = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_OLDINCLUDE" ) || "";

    # Get plugin debug flag
    $debug = TWiki::Func::getPreferencesFlag( "\U$pluginName\E_DEBUG" );

    $renderingWeb = $web;

    # Plugin correctly initialized
    TWiki::Func::writeDebug( "- TWiki::Plugins::${pluginName}::initPlugin( $web.$topic ) is OK" ) if $debug;
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%

    # for compatibility for earlier TWiki versions:
    if( $doOldInclude ) {
        # allow two level includes
        $_[0] =~ s/%INCLUDE:"([^%\"]*?)"%/TWiki::handleIncludeFile( $1, $_[1], $_[2], "" )/geo;
        $_[0] =~ s/%INCLUDE:"([^%\"]*?)"%/TWiki::handleIncludeFile( $1, $_[1], $_[2], "" )/geo;
    }

    # assume locked by default, unless we have any %PMID... lines in the page, in which case check the lockfile/cache access times
    my $locked = 1;
    if ($_[0] =~ /%PMID/) {
	$locked = 0;
	if (-e $pubmedCacheLockfile) {
	    # lockfile exists, but check for stale locks
	    my @lockStat = stat $pubmedCacheLockfile;
	    my $lockTime = $lockStat[9];
	    my $now = time;
	    if ($lockTime >= $now - 60) { # allow 60 seconds for pages with lots of references
		$locked = 1;
	    } else {
		# double-check last access time of cache file, just to be sure this isn't a REEEEALLY slow page load
		if (-e $pubmedCacheFilename) {
		    my @cacheStat = stat $pubmedCacheFilename;
		    my $cacheTime = $cacheStat[9];
		    my $now = time;
		    if ($cacheTime >= $now - 10) { # allow 10 seconds for slow GET requests to pubmed
			$locked = 1;
		    }
		}
		if (!$locked) {
		    # lockfile is stale, so grab the lock
		    utime $now, $now, $pubmedCacheLockfile;
		}
	    }
	} else {  # lockfile doesn't exist, so create it
	    local *DUMMY;
	    open DUMMY, ">$pubmedCacheLockfile";
	    close DUMMY;
	}

	TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] ): DB is ".($locked?"locked":"unlocked") ) if $debug;
    }

    unless ($locked) {
	tie %pubmedCache, 'DB_File', $pubmedCacheFilename or die "Trying to tie ${pluginName} cache to $pubmedCacheFilename: $!";
    }

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
    $_[0] =~ s/%PMID{([0-9]{1,9}?)}%/&fetch($1)/ge;
    $_[0] =~ s/%PMIDL{(.*?)}%/&link($1)/ge;
    $_[0] =~ s/%PMIDC{([0-9]{1,9}?)}%/&citelink($1)/ge;

    unless ($locked) {
	untie %pubmedCache;
	unlink $pubmedCacheLockfile;
    }
}

# =========================
sub fetch {
    my $pmid = $_[0];
    my $results=getFromPubmedCache($pmid,"abstract");  # IH, 9/5/07
    my $link = "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=pubmed&dopt=Abstract&list_uids=$pmid";
    $results =~ s!($TWiki::regex{linkProtocolPattern}\:\S*[^\s\.,\);\:])([\s\.,\);\:])!<a href="$1">$1</a>$3!g;
    $results =~ s!$pmid!<a href="$link">$pmid</a>!;
    $results =~ s!\n1:\s*([^\n]*\S.*?)\s*?\n!\n<a href="$link">$1</a>\n!;
    return "<pre>".$results."</pre>";
}

# ========================
sub link {
    my ( $theAttributes ) = @_;
    my $pmid = &TWiki::Func::extractNameValuePair($theAttributes, "pmid");
    my $link = &TWiki::Func::extractNameValuePair($theAttributes, "name");
    $pmid = $_[0] if $pmid eq '';
    return '' if $pmid eq '';
    $link = $pmid if $link eq '';
    my $results="[[http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=pubmed&dopt=Abstract&list_uids=$pmid][$link]]";
    return $results;
}

# =========================
sub citelink {
    my $pmid = $_[0];
    my $results=getFromPubmedCache($pmid,"medline");  # IH, 9/5/07
    my $url = "http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=pubmed&dopt=Abstract&list_uids=$pmid";
    return "[[$url][PMID $pmid]]" unless defined $results;
    if ($results =~ /$retrievalError/) {
	return "[[$url][PubMed ID $pmid not yet in database]]";
    }
#create an array for each line
    @string=split /\n/, $results;
    $pcmd='';
#initialize empty arrays (otherwise multiple calls will keep appending values)
    $rec->{'AU'}=[];
    $rec->{'TI'}=[];
    $rec->{'SO'}=[];
#go through each line
    for($i=0; $i<@string; $i++) {
        next if $string[$i] =~ /^\s*$/o;
#store the first six characters
        $cmd=substr $string[$i],0,6;
        if($cmd=~/-/) {
#remove spaces and -'s
            $cmd=~s/ *-.*//o;
#then store the key
            $pcmd=$cmd;
        }
#create the key in the array if it does not exist
        if(!exists $rec->{$pcmd}) {
            $rec->{$pcmd}=[];
        }
#add the rest of the line to the array for the specified key
        push @{$rec->{$pcmd}},substr($string[$i],6);
    }
    $au=$ti=$so='';
    if(exists $rec->{'AU'}) {
	# limit number of authors -- IH, 8/4/07
	if (@{$rec->{'AU'}} > $maxAuthors) {
	    $au = $rec->{'AU'}->[0] . " <i>et al</i>";
	} else {
	    $au=join(', ', @{$rec->{'AU'}});
	}
	$au =~ s/\b([A-Z]+[a-z]+[A-Z][A-Za-z]+)\b/<nop>$1/g;  # prevent accidental wiki links -- IH, 8/4/07
    }
    if(exists $rec->{'TI'}) {
	$ti=join(' ', @{$rec->{'TI'}});
	$ti =~ s/\b([A-Z]+[a-z]+[A-Z][A-Za-z]+)\b/<nop>$1/g;  # prevent accidental wiki links -- IH, 8/4/07
    }
    if(exists $rec->{'SO'}) {
        $so=join(' ', @{$rec->{'SO'}});
	$so =~ s/\b([A-Z]+[a-z]+[A-Z][A-Za-z]+)\b/<nop>$1/g;  # prevent accidental wiki links -- IH, 8/4/07
    }
    $link="[[http://www.ncbi.nlm.nih.gov/entrez/query.fcgi?cmd=Retrieve&db=pubmed&dopt=Abstract&list_uids=$pmid][$ti]]";
    return $au.".&nbsp;&nbsp;".$link."&nbsp;&nbsp;".$so;
}

# =========================

1;
