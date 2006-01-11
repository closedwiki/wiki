#! /usr/bin/perl -w
use strict;
use Data::Dumper qw( Dumper );

use FindBin;
use Cwd;

################################################################################

my ( $name ) = ( @ARGV, '' );
my @types = qw( Plugin Contrib HeaderArtContrib );
( my $type = $name ) =~ s/^.*?(Plugin|(HeaderArt)?Contrib)?$/$1/;
die "'$name' must end in one of: " . join( ', ', @types ) . "\n" unless $type;

usage(), exit 0 unless $name;

################################################################################

chdir $FindBin::Bin;

#print STDERR "$name already exists; will not overwrite (use --f/--force to override)\n";
# SMELL: should be -d?
-e $name && die "$name already exists; will not overwrite\n";

# TOOD: object
my $extension = TWiki::Builder::Extension::Factory::new( $type, $name );
#print Dumper( $extension );

# could have command-line switches to optionally not generate various bits
$extension->generateMinimalExtension();
$extension->generateBuildContrib();
$extension->generateSample();
$extension->generateUnitTests();

################################################################################

sub usage
{
    print STDERR <<__USAGE__;
Usage: create-new-extension.pl ExtensionName
__USAGE__
}

################################################################################

package TWiki::Builder::Extension;

use File::Path qw( mkpath );

################################################################################

sub generateMinimalExtension
{
    my $self = shift or die;

    my $lib_base_dir = $self->{lib_base_dir} or die "lib_base_dir?";
    my $name = $self->{name} or die "name?";

    # Plugin.pm
    my $pm = '';

    open( PM, '<', $self->{module_template} ) or die $!;
    local $/ = undef;
    $pm = <PM>;
    close PM;

    $pm =~ s/Empty$type/$name/g;
#    $pm =~ s/EmptyContrib/$name/g;
#    $pm =~ s/EmptyPlugin/$name/g;

    open( PM, '>', "$lib_base_dir/$name.pm" ) or die $!;
    print PM $pm;
    close PM;

    # Plugin.txt
    eval { mkpath "$name/data/TWiki/" };
    $@ && die $@;

    my $topic = '';
    open( TOPIC, '<', $self->{extension_topic_template} ) or die $!;
    local $/ = undef;
    $topic = <TOPIC>;
    close TOPIC;

    $topic =~ s/EmptyPlugin/$name/g;
    $topic =~ s/EmptyContrib/$name/g;

    # adjust variables examples to use the actual topic name
    $topic =~ s/EMPTYPLUGIN/\U$name/g;
    $topic =~ s/EMPTYCONTRIB/\U$name/g;

    # stick in the username as the author (hey, it's better than nothing)
    chop( my $whoami = `whoami` );
#    $topic =~ s/(\|\s*.*Author:\s*\|).*?(\|)/$1 TWiki:Main.$whoami $2/gs;
    $topic =~ s/%USERNAME%/$whoami/gs;

    open( TOPIC, '>', "$name/data/TWiki/$name.txt" ) or die $!;
    # TODO: get page from twiki.org
    print TOPIC $topic;
    close TOPIC;
}

################################################################################

sub generateBuildContrib
{
    my $self = shift or die;

    my $lib_base_dir = $self->{lib_base_dir} or die "lib_base_dir?";
    my $name = $self->{name} or die "name?";
    my $twiki_lib_dir = $self->{twiki_lib_dir} or die "twiki_lib_dir?";

    # build.pl
    open( BUILD, '<', "$self->{build_pl_dir}/build.pl" ) or die $!;
    local $/ = undef;
    my $build = <BUILD>;
    close BUILD;

    $build =~ s/(Build|Empty)(HeaderArt)?Contrib/$name/g;

    open( BUILD, '>', "$self->{lib_base_dir}/${name}/build.pl" ) or die $!;
    print BUILD $build;
    close BUILD;

    # MANIFEST
    open( MANIFEST, '>', "$lib_base_dir/$name/MANIFEST" ) or die $!;
    print MANIFEST <<__MANIFEST__;
data/TWiki/$name.txt  Plugin doc page
$twiki_lib_dir/$name.pm  Plugin Perl module 
__MANIFEST__
    close MANIFEST;

    # DEPENDENCIES
    open( DEPENDENCIES, '>', "$lib_base_dir/$name/DEPENDENCIES" ) or die $!;
    close DEPENDENCIES;
}

################################################################################

sub generateSample
{
    my $self = shift or die;

    my $name = $self->{name} or die "name?";
    my $lib_base_dir = $self->{lib_base_dir} or die "lib_base_dir?";

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

################################################################################

sub generateUnitTests
{
    my $self = shift or die;

    my $name = $self->{name} or die "name?";
    my $unit_test_dir = $self->{unit_test_template_dir} or die "unit_test_template_dir?";

    # yes, these all say EmptyContrib -- that's ok (replacements are purely based on the extension name)
    eval { mkpath "$name/test/unit/$name/" };
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
}    

################################################################################

package TWiki::Builder::Extension;

sub _init
{
    my $self = shift or die;

    $self->{unit_test_template_dir} = 'EmptyContrib/test/unit/EmptyContrib';
#    $self->{lib_base_dir} = "$self->{name}/$self->{twiki_lib_dir}";
}

################################################################################

package TWiki::Builder::Extension::Plugin;
use base( qw( TWiki::Builder::Extension ) );

use File::Path qw( mkpath );
use Data::Dumper qw( Dumper );

sub _init
{
    my $self = shift or die;

    $self->SUPER::_init();

    $self->{name} = $name;
    $self->{twiki_lib_dir} = 'lib/TWiki/Plugins';
    $self->{build_pl_dir} = 'BuildContrib/lib/TWiki/Contrib/BuildContrib';
    $self->{module_template} = '../lib/TWiki/Plugins/EmptyPlugin.pm';
    $self->{extension_topic_template} = '../data/TWiki/EmptyPlugin.txt';
    $self->{lib_base_dir} = "$self->{name}/$self->{twiki_lib_dir}";
}

sub new
{
#    print "new Plugin:", Dumper( \@_ );
    my $class = shift;
    my $name = shift;
    my $self  = {};
    bless( $self, $class );
    $self->_init();

    eval { mkpath "$self->{lib_base_dir}/$self->{name}" };
    $@ && die $@;

    return $self;
}

################################################################################

package TWiki::Builder::Extension::Contrib;
use base( qw( TWiki::Builder::Extension ) );

use File::Path qw( mkpath );

sub _init
{
    my $self = shift;

    $self->SUPER::_init();

    $self->{name} = $name;
    $self->{twiki_lib_dir} = 'lib/TWiki/Contrib';
    $self->{build_pl_dir} = 'EmptyContrib/lib/TWiki/Contrib/EmptyContrib';
    $self->{module_template} = 'EmptyContrib/lib/TWiki/Contrib/EmptyContrib.pm';
    $self->{extension_topic_template} = 'EmptyContrib/data/TWiki/EmptyContrib.txt';
    $self->{lib_base_dir} = "$self->{name}/$self->{twiki_lib_dir}";

    eval { mkpath "$self->{lib_base_dir}/$self->{name}" };
    $@ && die $@;
}

sub new
{
    my $class = shift;
    my $name = shift;
    my $self  = {};
    bless( $self, $class );
    $self->_init();

    return $self;
}

################################################################################

package TWiki::Builder::Extension::Contrib::HeaderArt;
use base( qw( TWiki::Builder::Extension::Contrib ) );

use File::Path qw( mkpath );

sub _init
{
    my $self = shift;

    $self->SUPER::_init();

    $self->{name} = $name;
    $self->{twiki_lib_dir} = 'lib/TWiki/Contrib';
    $self->{build_pl_dir} = 'EmptyHeaderArtContrib/lib/TWiki/Contrib/EmptyHeaderArtContrib';
    $self->{module_template} = 'EmptyHeaderArtContrib/lib/TWiki/Contrib/EmptyHeaderArtContrib.pm';
    $self->{extension_topic_template} = 'EmptyHeaderArtContrib/data/TWiki/EmptyHeaderArtContrib.txt';
    $self->{lib_base_dir} = "$self->{name}/$self->{twiki_lib_dir}";

    eval { mkpath "$self->{lib_base_dir}/$self->{name}" };
    $@ && die $@;
}

sub new
{
#    die "not implemented yet; will inherit from TWiki::Builder::Contrib";
    my $class = shift;
    my $self  = {};
    bless( $self, $class );
    $self->_init();
    return $self;
}

sub generateMinimalExtension
{
    my $self = shift or die;
    my $name = $self->{name} or die "name?";

    $self->SUPER::generateMinimalExtension();

    mkpath( "$name/pub/TWiki/$name" );
}

################################################################################

package TWiki::Builder::Extension::Factory;

sub new
{
    my ( $type, $name ) = @_;
    die "name?" unless $name;

    # may need to massage type into a class-compatable name
    my $class = $type;
    if ( my ( $subclass, $baseclass ) = $class =~ /(HeaderArt)(Contrib|Plugin)$/ )
    {
	$class = "$2::$1";
    }

    $class = "TWiki::Builder::Extension::$class";
    return $class->new( $name );
}

# replace-string EmptyPlugin $name (what does that mean?)
