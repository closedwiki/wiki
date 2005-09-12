#!perl -w
# Replaces sh version of mklinks

# This is alpha software. There are severe known bugs.
# die "Make sure you know about the BUGs"

# Usage:
# mklinks.pl [-cp|-echo] <plugin> ...

# I intend this to become a TWikiShellContrib CommandSet

# Make links from the core into twikiplugins, to pseudo-install these
# components into a subversion checkout area. Default is to process
# all plugins and contribs, or you can do just a subset. You can also
# request a cp instead of ln -s.
#    -cp - copy files from the twikiplugins area instead of linking them.
#    -echo - just print the names of files that would be linked/copied
#    <plugin>... list of plugins and contribs to link into the core.
#    Example: CommentPlugin RenderListPlugin JSCalendarContrib
#    Optional, defaults to all plugins and contribs.

use File::Find;
use Cwd;
use FindBin;
use Getopt::Long;
use Pod::Usage;
use File::Basename;
use File::Glob ':glob';
use File::Copy;
use Data::Dumper;

my $Config;

BEGIN {

# TODO mode should default according to windows, linux, etc.
    $Config = {
#
	   	root => Cwd::abs_path( "$FindBin::Bin/../" ),
# 
		mode => "cp",		
		verbose => 0,
		debug => 1,
		help => 0,
		man => 0,
		extensions => [],
		build => '',
		destroy => ''
    };
    
    chdir($Config->{root}) || die "Cannot chdir to $Config->{root}";
    
    my $result = GetOptions( $Config,
			     'smells!',
# miscellaneous/generic options
			     'mode=s', 'build=s', 'destroy=s', 'help', 'man', 'debug', 'verbose|v',
			     );
    pod2usage( 1 ) if $Config->{help};
    pod2usage({ -exitval => 1, -verbose => 2 }) if $Config->{man};
#    print STDERR Dumper( $Config ) if $Config->{debug};
    
    unshift @INC, "$Config->{root}/bin";
    do 'setlib.cfg';
}

    configMode($Config->{mode});
    configExtensions(@ARGV);
    main();
    print STDERR Dumper( $Config ) if $Config->{debug};

sub configMode {
    my ($mode) = @_;
	if ( $mode eq "cp" ) {
    	# must be -r to catch dirs
	    $Config->{build} = "cp -r";
    	$Config->{destroy} = "rm -r";
	} elsif ( $mode eq "echo" ) {
	    $Config->{build} = "echo";
	    $Config->{destroy} = "echo";
	} else {
	    $Config->{build} = "ln -s";
	    $Config->{destroy} = "rm";
	}
}

# BUG: Ignores extensions passed to it. They go in but disappear.
sub configExtensions {
    my (@ext) = @_;	

    push @{$Config->{extensions}}, @ext;
	print STDERR "Adding extensions: ".join(", ", @{$Config->{extensions}})."\n" if $Config->{debug};    

	# default is to do all plugins and contribs
	unless ( @ext ) {
	    foreach my $ext (glob("twikiplugins/*Contrib")) {
	        push @{$Config->{extensions}}, $ext;
	    }
	    foreach my $ext (glob("twikiplugins/*Plugin")) {
	        push @{$Config->{extensions}}, $ext;
	    }
	}
	print STDERR "Extensions adding: ".join(", ", @{$Config->{extensions}})."\n" if $Config->{debug};;
}

sub destroy {
  my ($param) = @_;
  print "\t\tDESTROY $param\n";
  if ($Config->{mode} eq "cp") {
  	if (-f $param) {
		print "\t\tDestroying $param\n";
  	} else {
  		print "\t\tNo $param to destroy\n";  	
  	}
  	`$Config->{destroy} $param`;
    } else {
      die "Not implemented";
  } 
  
}

sub build {
  my ($from, $to) = @_;
  print "\t\tBUILD $from -> $to\n";
  
  # SMELL should be a class
  if ($Config->{mode} eq "cp") {
  	`$Config->{build} $from $to`;
  } else {
      die "Not implemented";
  }
}

sub mklink {
	my ($param) = @_;
	my $link = $param;
	$link =~ s#twikiplugins/[A-Za-z0-9]*/##;
	my $cwd = getcwd();
	print "MKLINK\t$param \n  ->\t$link\n" if $Config->{debug};
	if ( -l $link ) {
        destroy ($link);
    }
    
    if ( -e $link ) {
        my $x =`diff -q $param $link`;
        if ( "$x" eq "" ) {
        	print "$param and $link are not different - destroying $link\n";
            destroy $link;
        } else {
            print "diff $param $link different - Keeping $link intact\n";
        }
    } 
    
    build ("$cwd/$param", $link);
    
}

sub getPubDir ($$) {
  my ($dir,$ext) = @_;
  return "$dir/pub/TWiki/$ext";
}

sub linkPubDir {
	my ($dir, $ext) = @_;
	    my $pub = getPubDir($dir,$ext);
		print "PUB $pub:\n" if $Config->{debug};
	    if ( -d $pub ) {
	        mklink $pub;
	    }
	    foreach my $pubdir (glob("$dir/pub/*")) {
	        unless (-e 'pub/'.basename($pubdir) ) {
	            mklink $pubdir;
	        }
	    }
}

sub getLibDir ($$$) {
  my ($dir,$type,$ext) = @_;
  return "$dir/lib/TWiki/$type/$ext";
}


sub linkLibDir {
	my ($dir, $ext) = @_;
    foreach my $type qw(Plugins Contrib) {
    	my $lib = getLibDir($dir, $type, $ext);
    	
		print "LIB $lib:\n" if $Config->{debug};;
        if (! -d $lib ) {
            mkdir $lib;
        }
        
        if (-e "$lib.pm") {
        	mklink "$lib.pm"
        }
        
        foreach my $pm (glob("$lib/*.pm")) {
            mklink $pm
        }
    }
}

sub getDataDir ($$) {
  my ($dir,$ext) = @_;
  #NB $ext dir not used, as they are in the TWiki dir.
  return "$dir/data/TWiki/";
}

sub linkDataDir {
	my ($dir, $ext) = @_;
	my $data = getDataDir($dir, $ext);
    print "DATA $data:\n" if $Config->{debug};
    if ( -d $data) {

        foreach my $txt (glob("$data/*.txt")) {
            mklink $txt
        }
    }
}

sub getTemplateDir ($$) {
  my ($dir,$ext) = @_;
  return "$dir/templates/TWiki/$ext";
}

sub linkTemplatesDir {
	my ($dir, $ext) = @_;
	my $templates = getTemplateDir($dir, $ext);

	print "TEMPLATES $templates:\n" if $Config->{debug};;
    if ( -d $templates ) {
        foreach my $tmpl (glob("$templates/*.tmpl")) {
            mklink $tmpl;
        }
    }
}


sub main {
	my @ext = @{$Config->{extensions}};
    foreach my $dir (@ext) { 
    	my $extension = basename($dir);
    	print "Linking $extension from $dir ... \n";
    	
		linkPubDir($dir, $extension);
		linkLibDir($dir, $extension);
		linkDataDir($dir, $extension);
		linkTemplatesDir($dir, $extension);

		print "... DONE\n\n";
	}
}

__DATA__
=head1 NAME

mklinks.pl - 

=head1 SYNOPSIS

mklinks.pl [options] 

Shell version Copyright (C) 2005 Crawford Currie.  All Rights Reserved.
Perl version Copyright (C) 2005 Martin Cleaver.   All Rights Reserved.
Perl version closely followed the design of the shell version. 

 Options:
   -build
   -destroy
   -verbose
   -debug
   -help			this documentation
   -man				full docs

=head1 OPTIONS

=over 8

=item B<-build>

=back

=head1 DESCRIPTION

B<mklinks.pl> ...

=head2 SEE ALSO

	http://twiki.org/cgi-bin/view/Codev/...

=cut