#!/usr/bin/perl -w
use strict;
# mirror cpan (adapted from Randal Schwartz' program at ...)
# Copyright 2004 Will Norris.  All Rights Reserved.
# License: GPL

my $Config;	# forward declaration

sub Usage
{
    print <<'__USAGE__';
Usage:
  ./mirror-cpan.pl [--configuration] [cpan modules list regex...]
      --h(elp) | --?	usage info

Examples:
Creates local mirror from CPAN containing only the latest version of each module (~476MB 17 Oct 2004)
  ./mirror-cpan.pl     
Creates a local mirror of everything related to WWW::Mechanize
  ./mirror-cpan.pl WWW::Mechanize
  ./mirror-cpan.pl \^WWW::Mechanize      # more selective; only WWW::Mechanize tree on down, but not, eg, Test::WWW::Mechanize
Creates a local mirror used by twiki modules
  ./mirror-cpan --twiki `./calc-twiki-deps.pl`
__USAGE__

    print "\nAvailable Configurations:  ";
    print Dumper( $Config );
    return 0;
}


$|++;
use Cwd qw( getcwd );
use Data::Dumper qw( Dumper );

## warning: unknown files below the =local= dir are deleted!
$Config = {
    cpan => {
	remote => "http://www.cpan.org/",
	local => getcwd() . "/MIRROR/MINICPAN/",
    },
    twiki => {
	remote => "file:" . getcwd() . "/MIRROR/MINICPAN/",
	local => getcwd() . "/MIRROR/TWIKI/",
    },
};

my $TRACE = 1;

### END CONFIG

my $where = 'cpan';
if ( ( $ARGV[0] || '' ) =~ /^--/ )
{
    ( $where = shift ) =~ s/^--//;
    exit Usage() if 
	( $where =~ /^(h(elp)?|\?)$/i ) { exit Usage() }
}

# pass module list on the command line
my @modules = @ARGV ? @ARGV : q(.+);
print Dumper( \@modules );

################################################################################

my $REMOTE = $Config->{$where}->{remote};
my $LOCAL = $Config->{$where}->{local};

## core -
use File::Path qw(mkpath);
use File::Basename qw(dirname);
use File::Spec::Functions qw(catfile);
use File::Find qw(find);

## LWP -
use URI ();
use LWP::Simple qw(mirror RC_OK RC_NOT_MODIFIED);

## Compress::Zlib -
use Compress::Zlib qw(gzopen $gzerrno);

## first, get index files
my_mirror($_) for qw(
                     authors/01mailrc.txt.gz
                     modules/02packages.details.txt.gz
                     modules/03modlist.data.gz
                    );

## now walk the packages list
my $details = catfile($LOCAL, qw(modules 02packages.details.txt.gz));
my $gz = gzopen($details, "rb") or die "Cannot open details: $gzerrno";
my $inheader = 1;
while ($gz->gzreadline($_) > 0) {
  if ($inheader) {
    $inheader = 0 unless /\S/;
    next;
  }

  my ($module, $version, $path) = split;
  next if $path =~ m{/perl-5};  # skip Perl distributions

  my $bMatch = 0;
  foreach my $modulePattern ( @modules )
  {
      $bMatch = 1, last if $module =~ /$modulePattern/i;
  }

  if ( $bMatch )
  {
#      print "[$module] [v$version, $path]\n";
      my_mirror("authors/id/$path", 1);
  }
}

## finally, clean the files we didn't stick there
clean_unmirrored();

exit 0;

BEGIN {
  ## %mirrored tracks the already done, keyed by filename
  ## 1 = local-checked, 2 = remote-mirrored
  my %mirrored;

  sub my_mirror {
    my $path = shift;           # partial URL
    my $skip_if_present = shift; # true/false

    my $remote_uri = URI->new_abs($path, $REMOTE)->as_string; # full URL
    my $local_file = catfile($LOCAL, split "/", $path); # native absolute file
    my $checksum_might_be_up_to_date = 1;

    if ($skip_if_present and -f $local_file) {
      ## upgrade to checked if not already
      $mirrored{$local_file} = 1 unless $mirrored{$local_file};
    } elsif (($mirrored{$local_file} || 0) < 2) {
      ## upgrade to full mirror
      $mirrored{$local_file} = 2;

      mkpath(dirname($local_file), $TRACE, 0711);
      print $path if $TRACE;
      my $status = mirror($remote_uri, $local_file);

      if ($status == RC_OK) {
        $checksum_might_be_up_to_date = 0;
        print " ... updated\n" if $TRACE;
      } elsif ($status != RC_NOT_MODIFIED) {
        warn "\n$remote_uri: $status\n";
        return;
      } else {
        print " ... up to date\n" if $TRACE;
      }
    }

    if ($path =~ m{^authors/id}) { # maybe fetch CHECKSUMS
      my $checksum_path =
        URI->new_abs("CHECKSUMS", $remote_uri)->rel($REMOTE);
      if ($path ne $checksum_path) {
        my_mirror($checksum_path, $checksum_might_be_up_to_date);
      }
    }
  }

  sub clean_unmirrored {
    find sub {
      return unless -f and not $mirrored{$File::Find::name};
      print "$File::Find::name ... removed\n" if $TRACE;
      unlink $_ or warn "Cannot remove $File::Find::name: $!";
    }, $LOCAL;
  }
}
