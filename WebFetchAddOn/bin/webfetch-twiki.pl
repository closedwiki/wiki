#!/usr/bin/perl
# webfetch-twiki.pl - TWiki Feed handler for TWiki WebFetchAddOn
# reads configuration from a TWiki page to operate WebFetch feed-gathering
# Copyright (C) 2009 Ian Kluft
# contributed to the TWiki.Org community under the GNU General Public License

use strict;
use Getopt::Long;
use WebFetch;
use WebFetch::Output::TWiki;

# configuration
my $debug = 0;
my $cfg_web = "Feeds";
my $cfg_topic = "WebFetchConfig";
my ( $twiki_root );

# usage description
sub usage
{
	die "usage: $0 [--debug] --web=web_name --topic=topic_name "
		."--root=twiki_root\n";
}

# process command-line
GetOptions (
	"debug" => \$debug,
	"web:s" => \$cfg_web,
	"topic:s" => \$cfg_topic,
	"root=s" => \$twiki_root,
) or usage;
( defined $cfg_web ) or usage;
( defined $cfg_topic ) or usage;
( defined $twiki_root ) or usage;

# generate the working directory path and check directory
my $work_dir = $twiki_root."/working/work_areas/WebFetchAddOn";
if ( ! -d $work_dir ) {
	mkdir $work_dir or die "$0: failed to create $work_dir: $!\n";
}

# read the configuration from TWiki
( -d $twiki_root  and -d $twiki_root."/lib" )
	or die "$0: twiki lib directory $twiki_root/lib not found\n";
eval { require TWiki; require TWiki::Func; };
if ( $@ ) {
	die "$0: failed to load TWiki modules: $@\n";
}
my $twiki_obj = TWiki->new( "WebFetch" );
my $config = TWiki::Func::readTopic( $cfg_web, $cfg_topic );

# if STARTINCLUDE and STOPINCLUDE are present, use only what's between
if ( $config =~ /%STARTINCLUDE%\s*(.*)\s*%STOPINCLUDE%/s ) {
	$config = $1;
}

# parse the configuration
$debug and print STDERR "parsing configuration\n";
my ( @fnames, $line );
my @twiki_config_all;
my %twiki_keys;
foreach $line ( split /\r*\n+/s, $config ) {
	if ( $line =~ /^\|\s*(.*)\s*\|\s*$/ ) {
		my @entries = split /\s*\|\s*/, $1;
		$debug and print STDERR "read entries: "
			.join( ', ', @entries )."\n";

		# first line contains field headings
		if ( ! @fnames) {
			# save table headings as field names
			my $field;
			foreach $field ( @entries ) {
				my $tmp = lc($field);
				$tmp =~ s/\W//g;
				push @fnames, $tmp;
			}
			next;
		}
		$debug and print STDERR "field names: ".join " ", @fnames."\n";

		# save the entries
		# it isn't a heading row if we got here
		# transfer array @entries to named fields in %config
		$debug and print STDERR "data row: ".join " ", @entries."\n";
		my ( $i, $key, %config );
		for ( $i=0; $i < scalar @fnames; $i++ ) {
			$config{ $fnames[$i]} = $entries[$i];
			if ( $fnames[$i] eq "key" ) {
				$key = $entries[$i];
			}
		}

		# save the %config row in @twiki_config_all
		if (( defined $key )
			and ( !exists $twiki_keys{$key}))
		{
			push @twiki_config_all, \%config;
			$twiki_keys{$key} = ( scalar @twiki_config_all) - 1;
		}
	}
}

# launch feed readers based on configuration data
my ( $feed, $field );
foreach $feed ( @twiki_config_all ) {
	$debug and print STDERR "running ".$feed->{key}."\n";

	# check that required parameters are present
	(( !exists $feed->{key}) or ! $feed->{key}) and next;
	foreach $field ( "web", "parent", "prefix", "template",
		"form", "options", "module", "source" )
	{
		if (( !exists $feed->{$field}) or ! $feed->{$field}) {
			$debug and print STDERR "$0: skipping ".
				$feed->{key}." due to missing $field\n";
		}
	}

	# run a reader for the feed
	my $class = "WebFetch::Input::".$feed->{module};
	eval "require $class";
	if ( $@ ) {
		$debug and print STDERR "$0: skipping ".$feed->{key}
			." because $class failed to load: $@\n";
		next;
	}
	if ( ! $class->isa( "WebFetch" )) {
		$debug and print STDERR "$0: skipping ".$feed->{key}
			." because $class is not a subclass of WebFetch\n";
		next;
	}
	my $wf_obj;
	eval {
		$wf_obj = $class->new(
			"dir" => $work_dir,
			"source" => $feed->{source},
			"source_format" => lc($feed->{module}),
			"dest" => "twiki",
			"dest_format" => "twiki",
			"twiki_root" => $twiki_root,
			"config_topic" => $cfg_web.".".$cfg_topic,
			"config_key" => $feed->{key},
			( $debug ? ( "debug" => $debug ) : ()),
		);
		$wf_obj->do_actions; # process output
		$wf_obj->save; # save results
	};
	if ( $debug ) {
		if ( $@ ) {
			print STDERR $feed->{key}." ";
			if ( $@ =~ /nothing to save/ ) {
				print "success (0 records)\n";
			} else {
				print "failed: $@\n";
			}
		} else {
			print "success (".(scalar @{$wf_obj->{data}})
				." records)\n";
		}
	}
}
