package TWiki::Contrib::BuildContrib::TWikiCLI::Extension;
use strict;
use Cwd;

# Ultimately we'd like to ask the Extension to handle this command 
# itself. For now we just call build.pl

sub upload {
    return "Not implemented\n";

}

# now this really ought to be in Extension::CVS, but that directory would clash
sub cvsupdate {
    my ($extension) = @_;

    print "Doing cvs update for $extension\n\n";
    my $libFrag = getLibFragmentForExtension($extension);

   	my $dir = selectTWikiLibDir($libFrag);

	$dir;
}

sub install {
    my ($extension) = @_;

    print "Installing $extension\n\n";
    my $libFrag = getLibFragmentForExtension($extension);

    my $oldPwd = cwd();
    my $outputLog;

    my $buildDotPlDir = selectTWikiLibDir($libFrag)."/TWiki/$libFrag/";
    if ($buildDotPlDir) {
	chdir ($buildDotPlDir) || die "Couldn't cd to $buildDotPlDir - $!";
	print "From $buildDotPlDir...\n";
	foreach my $home (getHomes()) {
	    if ($home !~ m!^/!) {
		$home = $ENV{"HOME"}."/".$home;
	    }
	    print "\tInstalling to $home\n";
	    $ENV{"TWIKI_HOME"} = $home;

	    $outputLog .= `perl build.pl install`;
	}
    } else {
	print "Failed to find build.pl for $extension\n";
    }
    chdir ($oldPwd); # Not strictly necessary, but...
    return $outputLog;
}

sub getHomes {
    die "Set TWIKI_HOMES to : separated locations to install to" unless $ENV{"TWIKI_HOMES"};
    return split / /, $ENV{"TWIKI_HOMES"};
}


sub selectTWikiLibDir {
    my ($frag) = @_;
    unless ($ENV{"TWIKI_LIBS"}) {
	die "No TWIKI_LIBS set?";
    }
    my $result;
    my $lookedIn;
    foreach my $libdir (split(/:/, $ENV{TWIKI_LIBS})) {
	my $buildDotPlDir = "$libdir";
	if (-f $libDir."/TWiki/$frag/build.pl") {
	    $lookedIn .= "\tFound it\n";
	    return $libDir;
	} else {
	    $lookedIn .= "\tNot $buildDotPlDir\n";
	}
    }
    print "Didn't find it: - \n$lookedIn";
    return "";
}

sub getLibFragmentForExtension {
    my ($extension) = @_;
    my $dir;
    if ($extension =~ "Plugin") {
	$dir = "Plugins/$extension";
    } elsif ($extension =~ "AddOn") {
	$dir = "Plugins/$extension";
    } elsif ($extension =~ "Contrib") {
	$dir = "Contrib/$extension";
    }
    return $dir;

}

1;
