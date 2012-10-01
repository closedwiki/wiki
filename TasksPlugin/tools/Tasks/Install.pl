#!/usr/bin/perl
# -*- mode: CPerl; -*-
#
# TWiki/Foswiki  off-line task management framework installer
#
my $COPYRIGHT = "Copyright (C) 2011 Timothe litt <litt at acm dot org>";
#
# License is at end of module and can be displayed with the -L command..
# Removal of Copyright and/or License prohibited.

use warnings;
use strict;

# This utility handles tasks required to complete the installation of the TASK framework, as well as some
# management and developer functions.
#
# See HELP_MESSAGE and the README file for the details.  

use Cwd qw/realpath getcwd/;
use File::Basename;
use File::Spec;
use FindBin;
use Getopt::Long;
use POSIX qw/lchown/;
use Sys::Hostname;

our $VERSION = '3.0-001';
sub HELP_MESSAGE;

Getopt::Long::Configure( "auto_version", "no_ignore_case" );

my( $opt_L, $opt_q, $opt_v, $opt_f, $opt_n, $opt_b, $opt_t, $opt_M,
    $opt_s, $opt_m, $opt_p, $opt_u, $opt_U, $opt_Z, $opt_z, $opt_d );

GetOptions(
             "license|L"	   => \$opt_L,
             "quiet|q"		   => \$opt_q,
             "verbose|v"	   => \$opt_v,
             "force|f"		   => \$opt_f,
             "test|n"		   => \$opt_n,
             "bindir|b=s"	   => \$opt_b,
             "toolsdir|t=s"	   => \$opt_t,
             "startdir|s=s"	   => \$opt_s,
             "mapfile|m=s"	   => \$opt_m,
             "permissive|p"	   => \$opt_p,
             "file-umask|u=i"	   => \$opt_u,
             "directory-umask|U=i" => \$opt_U,
             "selinux|Z"	   => \$opt_Z,
             "no-selinux|z"	   => \$opt_z,
             "manifest|M"	   => \$opt_M,
             "developer|d"	   => \$opt_d,
             "help"                => sub { HELP_MESSAGE( \*STDERR ); exit 0; },
            ) or exit( 1 );

if( -t STDOUT && !$opt_q ) {
    print "$COPYRIGHT\nFor license terms use the $FindBin::Script LICENSE command.\n\n";
}
exit license() if( $opt_L || $ARGV[0]  =~ /^license$/i );

my $verbose = 0;
$verbose = 1 if( $opt_v );

my $rootdir;
my $bindir = realpath( $opt_b || 'bin/');
die "No bin directory specified/available\n" unless( $bindir );

my $libdir;
my $toolsdir = realpath( $opt_t || 'tools/'); # Foswiki will over-ride
my $inidir = realpath( $opt_s || (-d '/etc/init.d'? '/etc/init.d/' : '-'));
undef $inidir if $inidir =~ m!/-$!;

my $permissiveOK = $opt_p;
our $fileUmask;
our $dirUmask;

my( $Wikiname, $OtherWikiname) = -r "$bindir/setlib.cfg" && 
                  (system( "grep -q '\$foswikiLibPath' $bindir/setlib.cfg >/dev/null 2>&1" ) == 0) ? ('Foswiki', 'TWiki') : ('TWiki', 'Foswiki');
unless( $Wikiname ) {
    print STDERR "No wiki detected in $bindir\n";
    exit 1;
}
my $wikiname = lc $Wikiname;
my $otherwikiname = lc $OtherWikiname;
my $wikiver;

my $wikilib;
my $tasklib;
my $cfg;
my $MANIFEST = "lib/$Wikiname/Plugins/TasksPlugin/MANIFEST";

our $selinux = !$opt_z && !system( "selinuxenabled" );
if( $opt_Z && !$selinux ) {
    print STDERR "SeLinux requested but not enabled (or both -Z and -z specified)\n";
    exit 1;
}
my $perms;

# Cached user and group name => id mappings

my( %users, %groups);

# Distribution (or local) mapping file

my $mapfile = $opt_m;

# Selinux types (no defaults)
our %selinuxTypeMap;

# Optional SeLinux user type to apply (Default is unchanged)

our $selinuxUser;

# Known user and groups (defaults here)

our %userGroupMap = (
    rootUser => 'root',
    rootGroup => 'root',
    webserverUser => 'apache',
    webserverGroup => 'apache',
		 );

# File and directory permission maps (default to identity mapping)

our( %filePermMap, %dirPermMap );

my $cmd = shift || '';

if( $cmd eq 'install' ) {
    exit( install( @ARGV ) );
} elsif( $cmd eq 'uninstall' ) {
    exit( uninstall( @ARGV ) );
} elsif( $cmd eq 'gendoc' ) {
    exit( gendoc( @ARGV ) );
} elsif( $cmd eq 'genkit' ) {
    exit( genkit( @ARGV ) );
} else {
    print STDERR ( "Unknown command $cmd, try --help\n" );
    exit 1;
}

sub install {
    return 1 unless( checkwiki() && checkinit( ) );

    # Read the manifest mapping data

    $mapfile = getmappings( $mapfile, "$wikilib/Plugins/TasksPlugin/MANIFEST.map", "$libdir/MANIFEST.map" );

    # Apply umasks from command line, or use default from map file, or hardcoded

    if( defined $opt_u ) {
	$fileUmask = $opt_u =~ /^0/? oct($opt_u) : $opt_u;
    }else {
	$fileUmask = 007 unless( defined $fileUmask );
    }
    if( defined $opt_U ) {
	$dirUmask = $opt_U =~ /^0/? oct($opt_U) : $opt_U;
    }else {
	$dirUmask = 006 unless( defined $dirUmask );
    }

    # Read the manifest for permissions/ownership/selinux information

    if( 1 ) {
	$perms = getperms( "$wikilib/Plugins/TasksPlugin/MANIFEST" );
    } else {
	# For entire installation

	require File::Find;
	File::Find->import (qw//);
	$perms = $File::Find::name;
	$perms = {};
	File::Find::find( {
			   wanted => sub {
			       return unless /^MANIFEST$/;
			       $perms = { %$perms,
					  %{ getperms( $File::Find::name ) },
					};
			   }, follow => 1, follow_skip => 2, }, $rootdir );
    }
    print "Installing framework\n";

    unless(
	   # Link for cgi-initiated start
	   slink( "$tasklib/Daemon", "$bindir/TaskDaemon" ) && 
	   ( !$inidir || initlink( $bindir, $inidir ) )
	  ) {
	print STDERR "Setup failed\n";
	exit 1;
    }

    # Apply permissions, ownership and security contexts

    for my $file (keys %$perms) {
	setperms( $rootdir, $file );
    }

    #    tick_$wikiname => .bak, and link.?
    # The idea here is to slip under tick_twiki and let its crontab entry start the daemon if stopped.
    # Not sure I want to do this.

    if( $inidir ) {
	my $initname = initname();

	if( $opt_n ) {
	    print "Would enable autostart & start $initname\n";
	} else {
	    print "Enabling $initname autostart\n";
	    unless( system( "chkconfig --add $initname" ) == 0 ) {
		print STDERR "Failed to enable $initname autostart\n";
		return 1;
	    }
	    print "Starting $initname\n";
	    unless( system(  "$inidir/$initname start" ) == 0 ) {
		print STDERR "Failed to start $initname\n";
		return 1;
	    }
	}
    }

    # Success
    return 0;
}

sub uninstall {
    return 1 unless( checkwiki( ) && checkinit( ) );

    my $initname = initname() if $inidir;

    if( $inidir ) {
	if( $opt_n ) {
	    print "Would disable autostart & stop $initname\n";
	} else {
	    print "Disabling $initname autostart\n";
	    unless( system( "chkconfig --del $initname" ) == 0 ) {
		print STDERR "Failed to disable $initname autostart\n";
	    }
	    print "Stopping $initname\n";
	    unless( system( "$inidir/$initname stop" ) == 0 ) {
		print STDERR "Failed to stop $initname\n";
	    }
	}
    }

    unless(
	   sunlink( "$bindir/TaskDaemon" ) && 
	   ( !$inidir || sunlink( realpath( "$inidir/$initname" ) . '_bin' ) ) &&
	   ( !$inidir || sunlink( realpath( "$inidir/$initname" ) . '_init' ) ) &&
	   ( !$inidir || sunlink( "$inidir/$initname" ) )
	  ) {
	print STDERR "Uninstall failed\n";
	exit 1;
    }

    return 0;
}

sub initname {

    # Name by which startup knows this wiki

    my $inilink = "$tasklib/Daemon" . '_init';
    if( -l $inilink ) {
	return (fileparse( readlink( $inilink ) ))[0];
    }

    # Default to primary (first) if no backlink

    return "${Wikiname}TaskDaemon";
}

sub initlink {
    my( $bindir, $inidir ) = @_;

    # Create startup (system boot) links for init
    # Each installed wiki can have one, so this requires a bit of work.

    return 1 unless $inidir;

    my $ininame;
    my $inilink = "$tasklib/Daemon" . '_init';
    if( -l $inilink ) {
	$ininame = (fileparse( readlink( $inilink ) ))[0];
    } else {
	my $suffix = '';
	my $seq = 0;
	while( -e "$inidir/${Wikiname}TaskDaemon$suffix" && 
	       realpath( "$inidir/${Wikiname}TaskDaemon$suffix" ) ne
	       realpath( "$tasklib/Daemon" ) ) {

	    $suffix = '_' . ++$seq;
	    die "Unable to find a free name for $inidir/${Wikiname}TaskDaemon after $seq attempts\n"
	      if $seq >= 100;
	}
	$ininame = "${Wikiname}TaskDaemon$suffix";
    }

    unless( 
	   # Startup (system boot) link for init
	   slink( "$tasklib/Daemon", "$inidir/$ininame" ) &&

	   # Following links will be followed from "$inidir/$ininame", but those won't
	   # exist if we're running -n.  Since they get realpathed, using the eventual
	   # target has the same effect.

	   # Link for startup to find bin/
	   slink( $bindir, realpath( "$tasklib/Daemon" ) . '_bin' ) &&

	   # Link from Daemon to selected ini file name for uninstall

	   slink( "$inidir/$ininame", realpath( "$tasklib/Daemon" ) . '_init' )
	  ) {
	print STDERR "Unable to register daemon startup links\n";
	return 0;
    }

    return 1;
}

sub slink {
    my( $old, $new ) = @_;

    # $new is the symlink being created, $old is what will be the target of the symlink
    # Try to create a relative path from the new back to the target.
    #
    # This is ugly because abs2rel/rel2abs want just directory specs.

    my $relTgt = $old;
    $relTgt .= '/' if -d $old;

    $relTgt = File::Spec->abs2rel( (fileparse($relTgt))[1], (fileparse($new))[1] ) . (-d $old? '' : '/' . (fileparse($relTgt))[0] );

    print "    symlink: $new => $relTgt  " if $verbose;

    # If the desired link already exists
    #  If it points to where we want, we're done.
    #  Otherwise, we can remove it -- only if -f was used.

    if( -l $new ) {
	# Existing link is relative to its location; make absolute so we can realpath it
	my $oldLnk = readlink( $new  );

	if( $relTgt eq $oldLnk ) {
	    print "[ok] - no change\n" if $verbose;
	    return 1;
	}

	print "    $new => $old  " unless $verbose;

	print "exists => " . readlink($new);

	unless( $opt_f ) {
	    print " -f required to remove\n";
	    return 0;
	}
	if( $opt_n ) {
	    print " [Would remove $new]\n";
	    return 1;
	}
	undef $opt_f;

	print " [Removing $new";
	unless( unlink( $new ) ) {
	    print " - failed: $!\n";
	    return 0;
	}
	print " - OK]";
    }

    if( $opt_n ) {
	print "\n" if $verbose;
	return 1;
    }

    if( symlink $relTgt, $new ) {
	print "[OK]\n" if $verbose;
	return 1;
    }
    print "    $new => $relTgt  " unless $verbose;
    print "Failed: $!\n";
    return 0;
}

sub sunlink {
    my( $link ) = @_;

    unless( -l $link ) {
	print "$link: Not a symlink\n";
	return 0;
    }

    print "    Removing symlink $link => " . readlink($link) if $verbose;

    if( $opt_n ) {
	print "\n" if $verbose;
	return 1;
    }

    if( unlink $link ) {
	print "[OK]\n" if $verbose;
	return 1;
    }
    print "    Remove $link  " unless $verbose;
    print "Failed: $!\n";
    return 0;
}

sub checkwiki {

    unless( -d $bindir && -x "$bindir/configure" && 
	    -x "$bindir/view" && -x "$bindir/edit" && 
	    -r "$bindir/setlib.cfg" ) {
	print STDERR "$bindir does not appear to be a wiki bin directory\n";
	return 0;
    }
    my $wd = getcwd();
    chdir File::Spec->catfile( $bindir, File::Spec->updir ) or die "Chdir:$!\n";
    $rootdir = realpath( '.' );
    unshift @INC, '.', $bindir;
    eval "
	our \$${wikiname}LibPath;
	unless( my \$sts = do \"$bindir/setlib.cfg\" ) {
	    die \"Couldn't parse $bindir/setlib.cfg: \$@\\n\" if( \$@ );
	    die \"Couldn't read $bindir/setlib.cfg: \$!\\n\" unless defined \$sts;
	    die \"Unsuccessful status from $bindir/setlib.cfg: \$sts\\n\" unless \$sts;
            die \"lost\";
	}
	die \"$bindir/setlib.cfg does not contain a valid \\\$${wikiname}LibPath\\n\"
            unless( \$${wikiname}LibPath && -r \"\$${wikiname}LibPath/LocalSite.cfg\" );
        \$libdir = \$${wikiname}LibPath;
    "; if( $@ ) {
	chdir $wd or die "chdir:$!\n";
	print STDERR "$bindir does not contain a valid setlib.cfg:$@\n";
	return 0;
    }
    $libdir .= '/' unless $libdir =~ m./$.;
    $libdir = File::Spec->rel2abs( (fileparse($libdir))[1], $bindir );
#    $libdir .= '/' unless $libdir =~ m./$.;
    $libdir = realpath( $libdir );

    $wikiver = `grep '\$RELEASE = ' $libdir/$Wikiname.pm`;
    $wikiver =~ s/^.*?\$RELEASE = '([^']*)'.*$/$1/ms;
    print "$Wikiname ($wikiver) platform detected\n" if $verbose;

    eval "
	unless( my \$sts = do \"$libdir/LocalSite.cfg\" ) {
	    die \"Couldn't parse $libdir/LocalSite.cfg: \$@\\n\" if( \$@ );
	    die \"Couldn't read $libdir/LocalSite.cfg: \$!\\n\" unless defined \$sts;
	    die \"Unsuccessful status from $libdir/LocalSite.cfg: \$sts\\n\" unless \$sts;
            die \"lost\";
        }
# Not in TWiki 4/5
#	die \"$libdir/LocalSite.cfg does not contain a valid \\\%${Wikiname}::cfg\\n\"
#            unless \$${Wikiname}::cfg{ScriptDir} && realpath( \$${Wikiname}::cfg{ScriptDir} ) eq \$bindir;
        \$cfg = \\\%${Wikiname}::cfg;
    "; if( $@ || !( $cfg->{PubDir} && -d $cfg->{PubDir} &&
	    $cfg->{DataDir} && -d $cfg->{DataDir} &&
	    $cfg->{TemplateDir} && -d $cfg->{TemplateDir} &&
	    $cfg->{LocalesDir} && -d $cfg->{LocalesDir} &&
# Not in TWiki 4/5
#	    $cfg->{ToolsDir} && -d $cfg->{ToolsDir} &&
	    $cfg->{WorkingDir} && -d $cfg->{WorkingDir} ) ) {
	   chdir $wd or die "chdir:$!\n";
	   print STDERR "$libdir does not contain a valid LocalSite.cfg:$@\n";
	   return 0;
    }
    chdir $wd or die "chdir:$!\n";

    $wikilib = "$libdir/$Wikiname";
    $tasklib  = "$wikilib/Tasks";

    unless( -r "$libdir/$Wikiname.pm" && 
	    -r "$wikilib/Plugins/TasksPlugin.pm" && 
	    -x "$wikilib/Tasks/Daemon" && (-r "$wikilib/Plugins/TasksPlugin/MANIFEST" || $opt_M) ) {
	print STDERR "$libdir does not appear to be a $Wikiname lib directory (or the installation is incomplete\n";
	return 0;
    }

    if( exists $cfg->{ToolsDir} ) { # Believe config if present ( currently only Foswiki)
	print STDERR "-t ignored because tools directory found in $Wikiname configuration\n" if( $opt_t );
	$toolsdir = $cfg->{ToolsDir};
    }
    unless( defined $toolsdir ) {
        print STDERR "Tools directory not found, use -t\n";
        return 0;
    }
    unless( -d $toolsdir && -x "$toolsdir/tick_$wikiname.pl" && (-f "$toolsdir/tick_$wikiname.pl" || -l "$toolsdir/tick_$wikiname.pl")  && -r "$toolsdir/extender.pl" ) {
	print STDERR "$toolsdir does not appear to be a $Wikiname tools directory\n";
	return 0;
    }

    if( $verbose ) {
	print "Using the following directories for installation:\n",
	"    bin: $bindir => " . realpath( $bindir ) . "\n",
	"    lib: $libdir => " . realpath( $libdir ) . "\n",
	"  tools: $toolsdir => " . realpath( $toolsdir ) . "\n";
    }

    return 1;
}

sub checkinit {
    unless( defined $inidir ) {
	print STDERR "Autostart will not be enabled\n";
	return 1;
    }

    unless( -d $inidir && -w $inidir ) {
	print STDERR "$inidir does not appear to be valid and writable\n";
	return 0;
    }
    return 1;
}

sub getmappings {
    my( $usermap, $kitmap, $libmap ) = @_;

    # File specified with -m, then machine-specific policy, site policy

    foreach my $mapfile ( $usermap, "$libmap." . hostname, "$libmap.LocalSite" ) {
      next unless( $mapfile && -f $mapfile );

	readmapfile( $mapfile ) or die "Failed to read $mapfile: $!\n";
	return $mapfile;
    }

    # Look for a distribution-specific file
    my $mapfile;

    # First, get OS (or distribution) name & version

    my $distname = $^O;
    my $distver = '';

    if( $distname eq 'linux' ) {
	# linux requires extra work...

	require Linux::Distribution;
	$distname =  Linux::Distribution::distribution_name();
	unless( $distname ) {
	    print STDERR "Unable to determine distribution name; update Linux::Distribution or use -m to specify manifest mapping file\n";
	    exit 1;
	}
	$distver = Linux::Distribution::distribution_version();
	unless( $distver ) {
	    if( $distname eq 'fedora' ) {
		print STDERR "Can't determine fedora distribution's version; see https://rt.cpan.org/Public/Bug/Display.html?id=69671 for a patch\n";
	    } else {
		print STDERR "Unable to determine $distname version - is lsb package (containing lsb_release command and data) installed?\nWill only look for generic $distname mapping\n";
	    }
	}
    }

    # Try the current kit's MANIFEST's directory, then the wiki library
    foreach my $mapbase ($kitmap, $libmap) {
	# First, distribution.version
	$mapfile = "$mapbase.$distname.$distver";
	if( $distver && -f $mapfile ) {
	    readmapfile( $mapfile ) or die "Failed to read $mapfile: $!\n";
	    return $mapfile;
	}
	# Use generic distribution
	$mapfile = "$mapbase.$distname";
	if( -f $mapfile ) {
	    readmapfile( $mapfile ) or die "Failed to read $mapfile: $!\n";
	    return $mapfile;
	}
    }
    # No map file found
    if( $selinux ) {
	print STDERR "Selinux install requires a manifest mapping file, which is not present.  Obtain mapping file, or use -z to install without setting selinux types\n";
	exit 1;
    }
    print "No mapping file found, proceeding with defaults\n" if( $verbose );
    return '';
}

sub readmapfile {
    my $mapfile = shift;

    eval {
	unless( my $sts = do $mapfile ) {
	    die "Couldn't parse $mapfile: $@\n" if( $@ );
	    die "Couldn't read $mapfile: $!" unless( defined $sts );
	    die "Unsuccessful status from $mapfile\n" unless( $sts );
	}
    }; if( $@ ) {
	print STDERR "Unable to process configuration map: $@\n";
	exit 1;
    }

    print STDERR "Obtained configuration from $mapfile\n" if( $verbose );
    return 1;
}

sub getperms {
    my( $manfile ) = @_;

    # Extract permissions from the manifest file
    # Structured comments provide additional information
    # ##S foo_t - selinux context for following files (just type or whole specifier)
    # ##U user.group - to be applied to file
    # ##D dirname mode desc - permissions for directories (not traditionally in MANIFEST)
    #
    # All permissions and users can be mapped through a site or distribution-specific
    # configuration file.  This is required to translate the generic wiki selinux
    # types used in MANIFEST to provide distribution independence.  It's optional
    # for mode, user and group to allow for site policy.
    # The mappings have already been read from $mapfile

    print STDERR "Processing $manfile\n" if $verbose;

    # Would be nice to validate security contexts, but we use older type names for maximum compatibility
    # and these are aliases in current releases.  And seinfo won't list aliases (nor will anything else
    # identified so far... If we had a list we could validate ##S lines and save a lot of chcon errors.

    my %sectxlist;
    if( 0&& $selinux && open( my $ctx, '-|', 'seinfo -t' ) ) {
	while( <$ctx> ) {
	    chomp;
	    s/^\s+//;
	    s/\s+$//;
	    $sectxlist{$_} = 1;
	}
	close $ctx;
    }

    open( my $fh, '<', $manfile ) or die "Can't open $manfile: $!\n";
    my $perms = {};
    my( $sctxu, $sctxt, $user, $group ) = ( '', '', '', '');

    while( <$fh> ) {
	if( /^##S\s+-?\s*(?:#.*)?$/ ) { # Null or '-' (don't change or inherit)
            next unless( $selinux );
            $sctxt = '';
            $sctxu = '';
            next;
        }
	if( /^##S\s+([\w_-]+)\s*(?:#.*)?$/ ) { # E.g. wiki_topic_t
	    # Security context type introducer
	    # Map from generic to distribution and save for following files

	    next unless( $selinux );

	    $sctxt = $selinuxTypeMap{$1};
	    unless( defined $sctxt ) {
		print STDERR "No mapping in $mapfile for $1, please update file\n";
		exit 1;
	    }
	    $sctxu = $selinuxUser;
	    next;
	}
	if( /^##U\s+([\w_-]+)\.([\w_-]+)\s*(?:#.*)?$/ ) { # E.g. webserverUser.webserverGroup
	    # File ownership introducer
	    # Map from generic name to distribution (or default) & save for following files

	    ( $user, $group ) = ($userGroupMap{$1}, $userGroupMap{$2} );
	    unless( defined $user ) {
		print STDERR "No mapping for user $1 in $mapfile\n";
		exit 1;
	    }
	    unless( defined $group ) {
		print STDERR "No mapping for group $2 in $mapfile\n";
		exit 1;
	    }

	    # Convert names to uid/gid & cache

	    $users{$user} = getpwnam( $user ) unless exists $users{$user};
	    print STDERR "Unknown user '$user' specifed in $manfile line $., ignoring\n" unless defined $users{$user};
	    $groups{$group} = getgrnam( $group ) unless exists $groups{$group};
	    print STDERR "Unknown group '$group' specifed in $manfile line $., ignoring\n" unless defined $groups{$group};
	    next;
	}

	my( $file, $perm, $desc );
	# Directory specifier - not in traditional MANIFEST
	# Treat as file for setting permissions
	unless( ($file, $perm, $desc) = /^##D\s+(\S+)\s+(\d+)(?:\s+(.*))?$/ ) {
	    # Strip comments, blank lines and leading/trailing spaces
	    s/#.*$//;
	    s/^\s+//;
	    s/\s+$//;
	    next unless length;

	    if( /^!include\s+(.*)$/ ) {
# !include seems to have ../ (sometimes) + package name (huh?)/
# Not sure what to do...For now, at least we can skip these.
#		$perms = { %$perms,
#			   %{ getperms( (fileparse( $manfile ))[1] . $1 ) },
#			 };
#		my $incfile = $1;
#		$incfile =~ s!^(?:\.\./)?\w+/!!;
#		$perms = { %$perms,
#			   %{ getperms( "$rootdir/$incfile" ) },
#			 };
#		print STDERR "Processing continues in $manfile\n" if $verbose;
		next;
	    }

	    ($file, $perm, $desc) = split( /\s+/, $_, 3 );
	}

	# Record filename, mode, security context, and owner

	next unless( $file );

        # Handle generic wiki directory substitution
        # This allows maintaining a single MANIFEST for both wikis
        # In the released MANIFEST, this is a nop

        if( $file =~ m,($Wikiname|$OtherWikiname), ) {
            printf STDERR "Not generic:   MANIFEST.master line %3u $file: \"$1\", should be \"wiki\"\n", $.;
        }
        $file =~ s!/wiki/!/$Wikiname/!g;

	if( defined $perm ) { 
	    $perm = oct( $perm ) if $perm =~ /^0/;
	} else {
	    # apply defaults - documented in BuildContrib
	    if( -d "$rootdir/$file" ) {
		$perm = 0775;
	    } elsif( $file =~ /\.pm$/ ) {
		$perm = 0444;
	    } elsif( $file =~ /\.pl$/ ) {
		$perm = 0554;
	    } elsif( $file =~ m!^data/.*\.txt$! ) {
		$perm = 0664;
	    } elsif( $file =~ m!^pub/! ) {
		$perm = 0664;
	    } elsif( $file =~ m!^bin/! ) {
		$perm = 0555;
	    } else {
		$perm = 0444;
	    }
	}

        # Ship everything but LOCAL_ONLY in a developers kit.  Othewise
        # ship unless tagged DEVELOP_ONLY or OTHERWIKI_ONLY or includes OtherWiki in path
	@{$perms->{$file}}{'mode','sctxu','sctxt','user','group', 'ship'} = ($perm,$sctxu,$sctxt,$users{$user},$groups{$group},
                          !(defined $desc && $desc =~ /\bLOCAL_ONLY\b/) && ( $opt_d ||
                            !(defined $desc && $desc =~ /\b(?:DEVELOP_ONLY|\U$otherwikiname\E_ONLY)\b/ ||
                              $file =~ m!/$OtherWikiname/!)
                                                                               ) );
    }
    close $fh or die "Error closing: $manfile:$!\n";

    return $perms;
}

# Set permissions for a file

sub setperms {
    my $root = shift;
    my $filename = shift;

    return 0 unless exists $perms->{$filename};

    my $file = File::Spec->catfile( $root,$filename );

    # Ignore optional files

    return 0 unless( -e $file );

    my( $user, $group, $mode, $sctxu, $sctxt, $ship ) = @{$perms->{$filename}}{'user','group','mode','sctxu', 'sctxt', 'ship' };

    if( defined $user || defined $group ) {
	$user = -1 unless( defined $user );
	$group = -1 unless( defined $group );

	if( $verbose ) {
	    my( $curu, $curg ) =  (stat($file))[4,5];
	    # (-l $file? (lstat($file))[4,5] : (stat($file))[4,5]);
	    printf "%s %s.%s -> %s.%s\n", $file, $curu, $curg, ($user == -1? '*' : $user), ($group == -1? '*' : $group) if( ($user != -1 && $user != $curu) || ($group != -1 && $group != $curg) );
	}
	unless( $opt_n ) {
	    if( -l $file ) {
		lchown $user,$group, $file or warn "lchown $file: $!\n";
	    }
	    chown $user,$group, $file or warn "chown $file: $!\n";
	}
    }

    if( defined $mode && !$permissiveOK ) {
	# Handle any permission mapping and masking

	if( -d $file ) {
            if( exists $dirPermMap{$filename} ) {
                $mode = $dirPermMap{$filename};
            } elsif( exists $dirPermMap{$mode} ) {
                $mode = $dirPermMap{$mode};
                $mode &= ~$dirUmask;
            } else {
                $mode &= ~$dirUmask;
            }
	} else {
            if( exists $filePermMap{$filename} ) {
                $mode = $filePermMap{$filename};
            } elsif( exists $filePermMap{$mode} ) {
                $mode = $filePermMap{$mode};
                $mode &= ~$fileUmask;
            } else {
                $mode &= ~$fileUmask;
            }
	}

	if( $verbose ) {
	    my $curperm = (stat( $file ))[2] & 07777;
	    printf "$file %03lo -> %03lo\n", $curperm, $mode if( $mode != $curperm );
	}

	unless( $opt_n ) {
	    chmod $mode, $file or warn "chmod $file:$!\n";
	}
    }

    if( $sctxt && $selinux ) {
	# Type and range from mapped type
	my @sctx = split( ':', $sctxt,2 );
	my $sctx = "-t $sctx[0]" if( $sctx[0] );
	$sctx = "$sctx -l $sctx[1]" if( $sctx[1] );
	# User if specified
	$sctx = "-u $sctxu $sctx" if( $sctxu );
	die "Bad security context mapping for $file: $sctxt\n" unless( defined $sctx );
	if( $verbose ) {
	    # Note that this doesn't account for aliases, so will be noisy if new and old are aliased.
	    # Also note that stat is an external command, so verbosity isn't cheap.
	    my @cursec = split( ':', `stat -c '%C' $file` );
	    my @newsec = @cursec;
	    $newsec[0] = $sctxu if( $sctxu );
	    # Role never touched (a file is an object everywhere...)
	    $newsec[2] = $sctx[0] if( $sctx[0] );
	    $newsec[3] = $sctx[1] if( $sctx[1] );
	    my $csec = join(':', @cursec); chomp $csec;
	    my $nsec = join(':', @newsec); chomp $nsec;
	    printf "$file %s -> %s (%s)\n", $csec, $nsec, $sctx if($nsec ne $csec);
	}
	# At this time, there is no known perl library/module for chcon; must use system...
	unless( $opt_n ) {
	    if( -l $file ) {
		system( "chcon -h $sctx $file" ) == 0 or warn "chcon -h $file failed\n";
	    }
	    system( "chcon $sctx $file" ) == 0 or warn "chcon $file failed\n";
	}
    }
}

# Generate documentation

sub gendoc {
    return 1 unless( checkwiki );

    # Read MANIFEST and build a list of interesting files

    my @sourceFiles;
    my $perms;
    {
        local $selinux;
        $perms = getperms( "$wikilib/Plugins/TasksPlugin/MANIFEST.master" );
        @sourceFiles = grep { -f $_ && !/\.map(?:\.|$)/ && !/(?:\.txt|README|MANIFEST|DEPENDENCIES|\.spec)$/ }
          map { File::Spec->catfile( $rootdir,$_ ) } keys %$perms;
    }

    # Extract each POD chunk, look for (or generate) a doc sequence tag, and store text in appropriate slot

    my %doc;
    foreach my $file (@sourceFiles) {
        open( my $fh, '<', $file ) or die "Can't open $file: $!\n";
        my( undef, undef, $fk ) = File::Spec->splitpath( $file );
        $fk =~ s/\..*$//;

        local $/;
        my $n = 0;
        while( my $text = <$fh>) {
            while( $text =~ s/\A.*?^=pod$(.*?)^=cut$//ms ) {
                my $doc = $1;
                $doc =~ s/\A\s+//ms;
                $doc =~ s/\s+\z/\n/ms;
                $doc =~ s/^---\+/---++/gms;
                if( $doc =~ s/<!--\s+?DS\s*?(\w+)\s+?-->//ms ) {
                    $doc{$1} = [ $fk, $doc ];
                } else {
                    my $ds = sprintf( "$fk%05u", $n += 100 );
                    $doc{$ds} = [$fk, "<!-- $ds -->\n" . $doc ];
                }
            }
        }
        close $fh;
    }

    # Output document in chunk order, adding a heading for each module

    my %f;
    foreach my $chunk (sort keys %doc) {
        my $doc = $doc{$chunk};
        print "---+ $doc->[0]\n" unless( $f{$doc->[0]}++ );
        print $doc->[1];
    }

    return 0;
}

# Generate kit

sub genkit {
    return 1 unless( checkwiki );

    my $svnroot = $_[0] || 'TasksPlugin';
    my $tarfile = $_[1] || ($opt_d? 'TasksPluginDevel.tgz' : 'TasksPlugin.tgz');

    # Print to STDERR so archive can be written to STDOUT

    unless( -d $svnroot ) {
        print STDERR "Development files should be in $svnroot: not found\n";
          return 1;
    }

    # Read MANIFEST.master and build a list of files

    my @kitFiles;
    my $perms;
    {
        local $selinux;
        $perms = getperms( "$wikilib/Plugins/TasksPlugin/MANIFEST.master" );
        @kitFiles = grep { $perms->{$_}{ship} } keys %$perms;
    }
    my @notShipped = grep { !$perms->{$_}{ship} } keys %$perms;

    # Make sure all files and directories exist

    my @missingFiles = grep { !-e  File::Spec->catfile( $svnroot, $_ ) } @kitFiles;

    foreach my $missing (@missingFiles) {
        print STDERR "Missing file:  MANIFEST.master contains $missing: not found\n";
    }

    # Look for files that should be in MANIFEST, but aren't.

    my @extraFiles;
    require File::Find;

    File::Find::find( {
                       no_chdir => 1,
                       wanted =>
        sub {
                my $file = $_;
                $file =~ s!^$svnroot/!!;
                return if( $perms->{$file} );

                # Ignore RCS file if it belongs to a listed file
                return if( $file =~ /^(.*),v$/ && $perms->{$1} );

                # Not in MANIFEST, check for valid excuses
                my $fn = basename( $file );

                # Ignore dot files, editor backups and editor tempfiles
                return if( $fn =~ m/^\./  || $fn =~ m/~$/ || $fn =~ /^#.*#$/);

                # Ignore (system) dirs that aren't ours.
                return if( -d $_ && $file !~ m!/Tasks! );

                # Ignore links that are created at install
                return if( -l $_ && $file =~ m!^(?:lib/$Wikiname/Tasks/Daemon_(?:bin|init))$! );

                # Ignore the master MANIFEST file
                return if( $file eq "$MANIFEST.master" );

                # No excuse, file doesn't belong or MANIFEST needs updating
                push @extraFiles, $file;
                print STDERR "Stranded file: MANIFEST.master omits    $file\n";
                return;
            },
                      }, $svnroot );

    if( $verbose && @notShipped ) {
        foreach my $f (@notShipped) {
            print "Not shipping:  $f\n";
        }
    }
    printf STDERR "%u files in MANIFEST.master, %u missing, %u unlisted, %u not shipped\n",
      scalar(@kitFiles) + scalar(@notShipped), scalar(@missingFiles), scalar(@extraFiles), scalar(@notShipped);

    if( @missingFiles + @extraFiles ) {
        print STDERR "Archive will not be created\n";
        return 1;
    }

    if( $opt_M ) {
        printf STDERR ( "Generating local MANIFEST\n" );
        # This is doing things the hard way, but it's a good excuse to validate the environment.
    } else {
        printf STDERR ( "Preparing %sarchive\n", ($opt_d? "developer's " : '') );
    }

    require Archive::Tar;
    Archive::Tar->import;

    my $tar = Archive::Tar->new;
    foreach my $file (sort @kitFiles) {
        # MANIFEST is special
        my $isMANIFEST = $file eq $MANIFEST;
        next if( $opt_M && !$isMANIFEST );
        my $fp = "$svnroot/$file";
        unless( -l $fp || $isMANIFEST ) {
            $tar->add_files( $fp );
            $tar->rename( $fp, $file );
            $fp .= ",v";
            if( $opt_d && -e $fp ) {
                $tar->add_files( $fp );
                $tar->rename( $fp, "$file,v" );
            }
            next;
        }
        # Archive::Tar doesn't handle following symlinks, although it is documented to do so (FOLLOW_SYMLINK is broken
        # as of 1.78).  So we must read the file by hand and provide the data and the correct attributes.
        # Links are generally a bad idea, but are used with SeLinux policy files because they live elsewhere.
        # And this file, because it is identical in both Wiki kits.
        #
        # Since we have the data in-hand, we produce the kit's MANIFEST on the fly.
        # There are 3 levels of MANIFEST.  MANIFEST.master is the master copy, including local policies and wiki-independent.
        # From this, we can create the developer's kit version (-d), also called MANIFEST.master, and the MANIFEST for the
        # local developer's system. (-M)
        # From either, we can produce the release kit version for either wiki.

        $fp .= '.master' if( $isMANIFEST );
        local $/;
        open( my $fh, '<', $fp ) or die "open $fp: $!\n";
        binmode $fh unless( $isMANIFEST );
        my $data = <$fh>;
        my @stat = stat( $fh ) or die "stat $fp: $!\n";
        close $fh;

        if( $isMANIFEST ) {
            # Remove MASTER_ONLY lines from all copies
            $data =~ s/^.*?\bMASTER_ONLY\b.*?$//gm;

            if( $opt_M ) {
                # Make local MANIFEST
                # Convert /wiki/, remove other_WIKI lines, and remove this_WIKI and LOCAL_ONLY tags
                $data =~ s!/wiki/!/$Wikiname/!gm;
                $data =~ s/^.*?\b\U$otherwikiname\E_ONLY\b.*?$//gm;
                $data =~ s/(?:\s+|\b)(?:LOCAL_ONLY|\U$wikiname\E_ONLY)\b//gm;
            } else {
                # Make manifest for kit
                # Remove LOCAL_ONLY lines, even from Developer's kits
                $data =~ s/^.*?\bLOCAL_ONLY\b.*?$//gm;

                if( $opt_d ) {
                    # Developer gets a "master", except for the LOCAL_ONLY lines
                    $file .= '.master';
                } else {
                    # Convert /wiki/ to /TWiki/ or /Foswiki/ as appropriate
                    # Remove DEVELOP_ONLY /other_WIKI lines from MANIFEST stored in archive
                    # Remove any thiswiki_ONLY tags (but leave line)
                    $data =~ s!/wiki/!/$Wikiname/!gm;
                    $data =~ s/^.*?\b(?:DEVELOP_ONLY|\U$otherwikiname\E_ONLY)\b.*?$//gm;
                    $data =~ s/(?:\s+|\b)\U$wikiname\E_ONLY\b//gm;
                }
            }
            # Compress any resulting double blank lines to singles.
            1 while( $data =~ s/\n\n\n/\n\n/gms );
            $stat[7] = length $data;

            if( $opt_M ) {
                $fp = "$svnroot/$file";
                if( -e $fp ) {
                    my $seq = 1;
                    $seq++ while( -e "$fp.$seq~" );
                    rename( $fp, "$fp.$seq~" ) or die "rename $fp => $fp.$seq~: $!\n";
                    print "Existing $fp renamed to $fp.$seq~\n";
                }
                open( my $fh, '>', $fp ) or die "open $fp $!\n";
                print $fh $data or die "write $fp: $!\n";
                close $fh or die "close $fp: $!\n";
                print "$fp written\n";
                return 0;
            }
        }
        my %opts = (
#                     name => '',
                     size => $stat[7],
                     mtime => $stat[9],
                     mode => $stat[2] & 0777,
                     uid => $stat[4],
                     gid => $stat[5],
#                     linkname => '',
                     uname => scalar getpwuid($stat[4]),
                     gname => scalar getgrgid($stat[5]),
#                     devmajor => 0,
#                     devminor => 0,
#                     prefix => '',
                      type => Archive::Tar::Constant::FILE(),
                   );

        $tar->add_data( $file, $data, \%opts );

        $fp .= ",v";
        next unless( $opt_d && -e $fp );

        unless( -l $fp ) {
            $tar->add_files( $fp );
            $tar->rename( $fp, "$file,v" );
            next;
        }

        open( $fh, '<', $fp ) or die "open $fp: $!\n";
        binmode $fh unless( $isMANIFEST );
        $data = <$fh>;
        @stat = stat( $fh ) or die "stat $fp: $!\n";
        close $fh;
        %opts = (
#                    name => '',
                     size => $stat[7],
                     mtime => $stat[9],
                     mode => $stat[2] & 0777,
                     uid => $stat[4],
                     gid => $stat[5],
#                    linkname => '',
                     uname => scalar getpwuid($stat[4]),
                     gname => scalar getgrgid($stat[5]),
#                    devmajor => 0,
#                    devminor => 0,
#                    prefix => '',
                     type => Archive::Tar::Constant::FILE(),
                );

        $tar->add_data( "$file,v", $data, \%opts );
    } # each file

    if( $opt_n ) {
        print STDERR "Archive was not written\n";
        return 0;
    }
    print STDERR "Writing archive $tarfile\n";
    $tar->write( $tarfile, COMPRESS_GZIP() ) and return 0;

    print STDERR "Error(s) writing archive $tarfile\n";
    return 1;
}

# Display (copyright and) license

sub license {
    if( !-t STDOUT || $opt_q) {
        print "$COPYRIGHT\n";
    }

    require Fcntl;
    Fcntl->import (qw/SEEK_SET/);

    my $start = tell( DATA );
    while(<DATA>) {
        print;
    }
    seek( DATA, $start, SEEK_SET() );

   return 0;
}

sub HELP_MESSAGE {
    my( $ofh, ) = @_;

    my $pname = $FindBin::Script;
    $Wikiname ||= "*Wiki";
    $wikiname ||= "*wiki";

    print $ofh <<"USAGE" ;
$pname (un)installation for $Wikiname tasking framework

Usage:
  $pname options command

Options:
  --help                print usage summary
  --version             print version
  --license -L          Display license
  --quiet -q            Don't display copyright at startup
  --verbose -v          Detail messages for all actions
  --force -f            Remove existing symlinks that conflict
  --test -n             Don\'t make any changes
  --bindir -b dir       specify location of $Wikiname bin directory
                        typically <webdocroot>/$wikiname/bin
  --toolsdir -t dir     specify location of $Wikiname tools directory
                        typically <webdocroot>/$wikiname/tools (Foswiki
                        can get this automagically from config file)
  --startdir -s dir     specify location of system startup directory
                        typically /etc/init.d, or '-' if autostart 
                        is not desired.
  --mapfile -m mapfile  Use mapfile to translate MANIFEST permissions to installed.
                        MANIFEST permissions are generic and generally overly permissive.
                        The mapfile enables you to specify a different site policy, and
                        allows the generic permissions to be adapted to specific distributions' requirements.
                        Default is lib/MANIFEST.map.LocalSite.<hostname>, or
                        lib/MANIFEST.map.LocalSite, or
                        lib/$Wikiname/Plugins/TasksPlugin/MANIFEST.map.<distribution-name>.<version> or
                        lib/$Wikiname/Plugins/TasksPlugin/MANIFEST.map.<distribution-name> or
                        lib/MANIFEST.map.<distribution-name>.<version>, or
                        lib/MANIFEST.map.<distribution-name>, or
                        hardwired defaults (SeLinux requires file)
  --permissive -p       Leave permissive permissions as specified in MANIFEST
  --file-umask -u 0nnn  Restrict file permissions using this umask (default: 007)
  --directory-umask     Restrict directory permissions umask (default: 006)
    -U 0nnn
  --selinux -Z          Set SeLinux security context on files specified in MANIFEST
                        Default if SeLinux detected.
  --no-selinux -z       Do not set SeLinux security contexts even if SeLinux is detected.

Commands:
   install              Install symbolic links and set permissions.
   uninstall            Remove symbolic links
   license              Display license
   gendoc               Produce draft documentation page from source
                        files (developer use)
   genkit               Generate kit .tgz file
                        (optional args: svnroot .tgz name)
                        Defaulting to TasksPlugin and TasksPlugin.tgz.
                        Validates and obeys MANIFEST.  
                        Use -d to build a developer's kit.  
                        -v for details.  Run from svn root directory.
                         e.g. TasksPlugin/tools/Tasks/Install.pl -b \\
                              core/bin -t core/tools -s /etc/init.d \\
                              -v genkit TasksPlugin TasksPlugin.tgz

                         Use -M to create a local MANIFEST
                         (developer only).
USAGE
    return;
}

__DATA__

This is an original work by Timothe Litt.

This program is free software; you can redistribute it and/or
modify it under the terms of the GNU General Public License
as published by the Free Software Foundation; either version 3
of the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details, published at
http://www.gnu.org/copyleft/gpl.html
