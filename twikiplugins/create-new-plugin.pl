#! /usr/bin/perl -w
use strict;

use FindBin;
use File::Path qw( mkpath );
use Cwd;

################################################################################

my ( $name ) = ( @ARGV, '' );
my @types = qw( Plugin Contrib );
#print "[$name]\n";
( my $type = $name ) =~ s/^.*?(Plugin|Contrib)?$/$1/;
die "'$name' must end in one of: " . join( ', ', @types ) . "\n" unless $type;

usage(), exit 0 unless $name;

################################################################################

chdir $FindBin::Bin;

#print STDERR "$name already exists; will not overwrite (use --f/--force to override)\n";
-e $name && die "$name already exists; will not overwrite\n";

my $twiki_lib_dir = '';
# TOOD: object
if ( $type =~ /^Plugin/ ) {
    $twiki_lib_dir = "lib/TWiki/Plugins";
} elsif ( $type =~ /^Contrib/ ) {
    $twiki_lib_dir = "lib/TWiki/Contrib";
}
my $lib_base_dir = "$name/$twiki_lib_dir";
eval { mkpath "$lib_base_dir/$name" };
$@ && die $@;

{ # BuildContrib
    # TODO: object
    my $build_pl_dir;
    if ( $type =~ /^Plugin/ ) {
	$build_pl_dir = "BuildContrib/lib/TWiki/Contrib/BuildContrib";
    } elsif ( $type =~ /^Contrib/ ) {
	$build_pl_dir = "EmptyContrib/lib/TWiki/Contrib/EmptyContrib";
    }
    open( BUILD, '<', "$build_pl_dir/build.pl" ) or die $!;
    local $/ = undef;
    my $build = <BUILD>;
    close BUILD;

    $build =~ s/(Build|Empty)Contrib/$name/g;

    open( BUILD, '>', "$lib_base_dir/$name/build.pl" ) or die $!;
    print BUILD $build;
    close BUILD;
}

{ # PluginSkeleton
    my $pm = '';
    # TOOD: object
    if ( $type =~ /^Plugin/ )
    {
	open( PM, '<', "../lib/TWiki/Plugins/EmptyPlugin.pm" ) or die $!;
	local $/ = undef;
	$pm = <PM>;
	close PM;
    } elsif ( $type =~ /^Contrib/ )
    {
	open( CONTRIB, '<', "EmptyContrib/lib/TWiki/Contrib/EmptyContrib.pm" ) or die $!;
	local $/ = undef;
	$pm = <CONTRIB>;
	close CONTRIB;
    }

    $pm =~ s/Empty$type/$name/g;

    open( PM, '>', "$lib_base_dir/$name.pm" ) or die $!;
    print PM $pm;
    close PM;

    open( MANIFEST, '>', "$lib_base_dir/$name/MANIFEST" ) or die $!;
    print MANIFEST <<__MANIFEST__;
data/TWiki/$name.txt  Plugin doc page
$twiki_lib_dir/$name.pm  Plugin Perl module 
__MANIFEST__
    close MANIFEST;

    open( DEPENDENCIES, '>', "$lib_base_dir/$name/DEPENDENCIES" ) or die $!;
    close DEPENDENCIES;

    eval { mkpath "$name/data/TWiki/" };
    $@ && die $@;

    # TODO: object
    my $topic = '';
    if ( $type =~ /^Plugin/ ) {
	open( TOPIC, '<', "../data/TWiki/EmptyPlugin.txt" ) or die $!;
	local $/ = undef;
	$topic = <TOPIC>;
	close TOPIC;

	$topic =~ s/EmptyPlugin/$name/g;
	# adjust examples to use the actual topic name
	$topic =~ s/EMPTYPLUGIN/\U$name/g;

	# stick in the username as the author (hey, it's better than nothing)
	chop( my $whoami = `whoami` );
	$topic =~ s/(\|\s*Plugin\s+Author:\s*\|).*?(\|)/$1 TWiki:Main.$whoami $2/gs;
	$topic =~ s/(\-\-\-\+ )Empty TWiki Plugin.*?(\-\-\-\+)/$1$name\n\nDescribe the plugin\n\n$2/gs;

    } elsif ( $type =~ /^Contrib/ ) {
	open( TOPIC, '<', "EmptyContrib/data/TWiki/EmptyContrib.txt" ) or die $!;
	local $/ = undef;
	$topic = <TOPIC>;
	close TOPIC;

	$topic =~ s/EmptyContrib/$name/g;
    }

    open( TOPIC, '>', "$name/data/TWiki/$name.txt" ) or die $!;
    # TODO: get page from twiki.org
    print TOPIC $topic;
    close TOPIC;

    ################################################################################
    # make unit tests
    ################################################################################
    eval { mkpath "$name/test/unit/$name/" };
    my $unit_test_dir;
    if ( $type =~ /^Plugin/ ) {
	$unit_test_dir = "EmptyContrib/test/unit/EmptyContrib";
    } elsif ( $type =~ /^Contrib/ ) {
	$unit_test_dir = "EmptyContrib/test/unit/EmptyContrib";
    }
    # *Tests.pm
    {
	my $template_file = "$unit_test_dir/EmptyContribTests.pm";
	open( TEST, '<', $template_file ) or die $!;
	local $/ = undef;
	my $test = <TEST>;
	close TEST;

	$test =~ s/EmptyContrib/$name/g;
	( my $output_file = $template_file ) =~ s/EmptyContrib/$name/g;

	open( TEST, '>', $output_file ) or die $!;
	print TEST $test;
	close TEST;
    }

    # *Suite.pm
    {
	my $template_file = "$unit_test_dir/EmptyContribSuite.pm";
	open( TEST, '<', $template_file ) or die $!;
	local $/ = undef;
	my $test = <TEST>;
	close TEST;

	$test =~ s/EmptyContrib/$name/g;
	( my $output_file = $template_file ) =~ s/EmptyContrib/$name/g;

	open( TEST, '>', $output_file ) or die $!;
	print TEST $test;
	close TEST;
    }
    
    # Sandbox example topic
    eval { mkpath "$name/data/Sandbox/" };
    {
	my $template_file = "EmptyContrib/data/Sandbox/PluginTestEmptyContrib.txt";
	open( TEST, '<', $template_file ) or die $!;
	local $/ = undef;
	my $test = <TEST>;
	close TEST;

	$test =~ s/EmptyContrib/$name/g;
	( my $output_file = $template_file ) =~ s/EmptyContrib/$name/g;

	open( TEST, '>', $output_file ) or die $!;
	print TEST $test;
	close TEST;

	# update MANIFEST
	open( MANIFEST, '>>', "$lib_base_dir/$name/MANIFEST" ) or die $!;
	print MANIFEST <<__MANIFEST__;
data/Sandbox/PluginTest$name.txt  Plugin examples
__MANIFEST__
	close MANIFEST;
    }
}

# replace-string EmptyPlugin $name

################################################################################

sub usage
{
    print STDERR <<__USAGE__;
Usage: create-new-extension.pl ExtensionName
__USAGE__
}

################################################################################

__DATA__

# create build.pl
plugins: BuildContrib
contribs: EmptyContrib

twikiplugins/EmptyContrib
lib/TWiki/Plugins/EmptyPlugin.pm
