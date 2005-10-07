# Support functionality for the TWiki Collaboration Platform, http://TWiki.org/
#
# A script to help people upgrade an existing TWiki to a new version
#  (don't laugh - we're expecting applause, not laughter!)
#
# Jul 2004 - written by Martin Gregory, martin@gregories.net
# Changes copyright (C) 2005 Crawford Currie http://c-dot.co.uk
# Changes copyright (C) 2005 Sven Dowideit http://www.home.org.au


package TWiki::Upgrade::UpgradeToDakar;

=begin twiki

---+ UpgradeTwiki

Create an upgraded twiki installation from an existing one
and a new distribution.

This script expects '.' to be the root of a TWiki distribution when it is called.

=cut

use strict;

use TWiki::Upgrade::TWikiCfg;
use TWiki::Upgrade::UpdateTopics;
use File::Copy;
use Text::Diff;
use File::Find;

sub doAllDakarUpgrades {
my ($setlibPath, $targetDir) = @_;

print "
This script will help you upgrade an existing 'Cairo' (TWiki2004090*) or Dakar 
pre-release installation to the latest 'Dakar' release. If you need to upgrade 
an earlier release, you should upgrade to 'Cairo' first.

The script works by examining the differences between a new 'Dakar'
distribution and an existing 'Cairo' installation, and creating a
new 'Dakar' installation that reflects your local customisations as
closely as possible.

Checklist:
   - This script should be run in the directory where you unpacked the
     new 'Dakar' distribution.
   - The first argument to the script is the path to your esiting TWiki 
     installation's setlib.cfg
   - The second argument to the script is the path to a target directory
     where it will create the new installation
     (_not_ the same as where you unpacked the new distribution, nor
      where your existing TWiki installation is)
   - You need enough disk space available to the target directory to
     copy your _entire_ existing TWiki installation, including data
     and pub directories.

Notes:
   - The target directory does _not_ have to be web-accessible.
   - The paths specified in the configuration for your _existing_
     installation will be used in the target directory.
   - Once you are done, you can rename or move the target directory as you
     want.
   - I will not touch any files in your existing TWiki installation
     or in the distribution. Only the target directory will be
     written to.

Hit <enter> to continue:";

<STDIN>;

unless( -d "bin" && -d "lib" && -d "pub" && -d "templates" ) {
    die "The current directory should be the root of the new distribution. That means that all the normal TWiki directories should be here: bin, lib, pub, templates etc.\nThe current directory doesn't look like a TWiki distribution.";
}
print"
Here's what's about to happen:

1) I'm going to create a new TWiki in $targetDir based on this new distribution
";

$targetDir =~ s|/$||;  # avoid ugly double slashes.

mkdir $targetDir, 0755 or die "Couldn't create the target directory ($targetDir): $!\n";

print "2) I'm going to create new config files to match the configuration of
   your existing installation.
3) I'm going to take a copy of your existing topics and attachments and merge 
   them in with new versions from the release.
4) I'm going to tell you what you need to do next!

";

# Now, should have finished asking the user questions...

print "Creating the $targetDir directory structure...\n";

opendir(HERE , ".");

foreach my $file (readdir(HERE)) {
    next if ($file =~ /^\./);
    next if ($file =~ /~$/);
    next if ($file =~ /.zip$/);
    next if ($file eq "data"); # UpgradeTopics will copy the data as appropriate.
    next if ($file eq "pub"); # UpgradeTopics will copy the data as appropriate.

    print "$file\n";
    system("cp -R $file $targetDir");
}

my ($oldDataDir, $oldPubDir) = TWiki::Upgrade::TWikiCfg::UpgradeTWikiConfig($setlibPath, $targetDir);   # dies on error, without doing damage

print "\n\nMerging your existing twiki ($targetDir) with new release twiki ...\n";

# set up .htaccess, if appropriate
if (-f "$setlibPath/.htaccess") {
    if (copy("$setlibPath/.htaccess", "$targetDir/bin/.htaccess")) {
        print "
Note: I copied your existing .htaccess into $targetDir/bin.

The significant differences between the new template for .htacess
and your previous one are:

";
        print join "\n", grep( /^[+-][^#]/ , split( /\r?\n/, diff("$targetDir/bin/.htaccess", "./bin/.htaccess.txt")));

        print "
You may need to apply some of these differences to the new .htaccess
that I created... that's up to you (I'm not going to mess with
security settings at all!)

Hit <enter> to continue:";
        <STDIN>;
    } else {
	warn "
I couldn't copy in your existing .htaccess file from $setlibPath to $targetDir/bin: $!\n";
    }
} else {
    warn "
Couldn't see a .htaccess in $setlibPath ... so I didn't try to help in that respect\n";
}

# now let's try to get their scriptSuffix right for them 
# (Is this a good idea, I wonder?  Can't see why not...)

if ($TWiki::scriptSuffix) {
    print "
Applying your '\$scriptSuffix' ($TWiki::scriptSuffix) to the scripts in $targetDir/bin...
";

    opendir(BINDIR, "$targetDir/bin") or 
	warn "Ooops - couldn't open $targetDir/bin for reading... that's certainly strange! ($!)\n";

    foreach my $f (readdir BINDIR)
    {
        next if ($f =~ m|\.|);  # scripts should not have dots, other things should!

        print "$f ";
        rename "$targetDir/bin/$f", "$targetDir/bin/$f$TWiki::scriptSuffix"
          or warn "Oops, couldn't rename $setlibPath/$f to $setlibPath/$f$TWiki::scriptSuffix : $!\n";
    }
}

    return ($oldDataDir, $oldPubDir);
}

sub RemainingSteps {
my ($targetDir) = @_;
print "
OK, I'm finished.
Now you need to

1.  Check the files listed above (if any) who's patches were rejected.

    For these files, you'll want to check the .rej file (in the same
    directory as the file) and see whether there are changes in there
    that you need to make manually.

2.  Check the files listed above that have 'no common versions' - in
    those cases, your new install will still work, but you need to be
    aware the topic file that is in place is your _old_ one... no
    changes from the new release have been included. You will have to
    merge in the new version manually.

3.  Check the new LocalLib.cfg and LocalSite.cfg to make sure they
    correctly reflect any local customisations you previously did in 
    setlib.cfg and TWiki.cfg.

4.  Setup authentication for the new TWiki

    If you are using htaccess, then check the diffs above make sense.
    If you are using some other method, you'll need to figure out
    what you need to do (sorry!)

5.  Set the permissions appropriately for the new TWiki.

    I have given pub and data global read and write access, so your
    new TWiki will work, but you *SHOULD* configure tighter security.

6.  Re-install plugins you were using

7.  Copy over any custom templates you put in the original templates
    directory

8.  Archive your old installation

9.  Move the newly created twiki directory ($targetDir) to the place
    where your previous version was.

10. Rearrange sub-directories the way you like them, if needed.
    (some sites have bin in a very different place to the rest, for
     example)

11. Use your browser to check the whole thing: visit the 'configure'
    script, which I am guessing is at:

    $TWiki::defaultUrlHost$TWiki::scriptUrlPath/configure$TWiki::scriptSuffix

    make sure there are no unwarranted warnings,

    and finally: visit TWikiPreferences, which I'm guessing is at:

    $TWiki::defaultUrlHost$TWiki::scriptUrlPath/view$TWiki::scriptSuffix/TWiki/TWikiPreferences

    It should be working.

12. Enjoy!
";
}

1;
