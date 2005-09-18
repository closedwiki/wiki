#!/usr/bin/perl -w

# Support functionality for the TWiki Collaboration Platform, http://TWiki.org/
#
# A script to help people upgrade an existing TWiki to a new version
#  (don't laugh - we're expecting applause, not laughter!)
#
# Jul 2004 - written by Martin Gregory, martin@gregories.net
# Changes copyright (C) 2005 Crawford Currie http://c-dot.co.uk
#

package TWiki::Upgrade::UpgradeToCairo;

use strict;

use TWiki::Upgrade::TWikiCfg;
use TWiki::Upgrade::UpdateTopics;
use File::Copy;
use Text::Diff;
use File::Find;

sub doAllCairoUpgrades {
my ($newCfgFile, $oldCfgFile, $targetDir) = @_;


print "Checklist: 
\t- This script should be run in the directory where you unpacked the new distribtion
\t- The argument to this script is the target directory where it will create a whole new installation 
\t  (_not_ the same as where you unpacked the new distribution, nor where your existing twiki installation is)
\t- You need enough disk space to copy your existing twiki installation to the target directory.
\t- The target directory does not have to be web-accessible.
";

# not sure if a relative path will be safe... better safe than sorry...
$targetDir =~ m|^[/~]| or die "Usage: $0 <full path to target directory for new wiki build>\n"; 
$targetDir =~ s|/$||;  # avoid ugly double slashes.

print "
That means that there should be all the normal TWiki directories here: bin, lib, pub, templates etc. right here.

Here's what's about to happen:

1) I'm going to create a new TWiki in $targetDir based on this new distribution
2) I'm going to update the config files to match the existing TWiki config
3) I'm going to merge the new TWiki data files from the release with all your existing information 
4) I'm going to tell you what you need to do next!
";

my ($configPath, $setlibPath, $libPath);

if ( $oldCfgFile =~ /(.*)setlib.cfg/ ) {
    $libPath = "";
    $setlibPath = $1;
    $configPath = $1;
} elsif ( $oldCfgFile =~ /(.*)TWiki.cfg/ ) {
    $libPath = $1;
    $configPath = $1;

    print "OK - found TWiki.cfg.  Now I need you to tell me where the existing TWiki bin directory is:\n";

    # this will only be used to find .htaccess at this point.   
    # should also be used to fix up bin scripts with $scriptSuffix: TBD!
    do
    {
		chomp ($setlibPath = <STDIN>) ;
    }
    until ((-d $setlibPath) ? 1 :
	   (print("Hmmm -  $setlibPath doesn't even look like a directory!... please check and try again\n"), 0)
	   );
}

# Now, should have finished asking the user questions...

print "First, creating $targetDir structures...\n";

opendir(HERE , ".");
mkdir $targetDir or die "Couldn't create the target directory ($targetDir): $!\n";

my $file;
foreach $file (readdir(HERE))
{
    next if ($file eq '.');
    next if ($file eq '..');
    next if ($file =~ /.zip$/);
    next if ($file =~ /^data$/); # UpgradeTopics will copy the data as appropriate.

    print "$file\n";
    system("cp -R $file $targetDir");
}

print "Preparing to write new format configuration files for you...\n\n";
TWiki::Upgrade::TWikiCfg::UpgradeTWikiConfig($configPath, $targetDir);   # dies on error, without doing damage

print "\n\nMerging your existing twiki data ($TWikiCfg::dataDir) with new release twiki data...\n";
my $baseDir = `pwd`;
chomp ($baseDir);

#TODO I think I want to do this last
#TODO TWiki::Upgrade::UpdateTopics::UpdateTopics($TWikiCfg::dataDir, "$baseDir/data", "$targetDir/data"); # dies on error, without doing damage
#make sure we're in the right place still
#TODO chdir($baseDir);
#TODO print "OK - the merge process completed successfully...\n";
# fix up permissions ... get them to a working state, if not ideal seurity-wise!
# (we tell the user to check the permissions later anyhow)
#TODO print "Now I'm giving write access to pub & data in the newly set up TWiki, so your web server can access them...\n";
#TODO find( sub {chmod 0777, $File::Find::name;} , "$targetDir/pub", "$targetDir/data");

# set up .htaccess, if appropriate
if (-f "$setlibPath/.htaccess")
{
    if (copy("$setlibPath/.htaccess", "$targetDir/bin/.htaccess"))
    {
	print "
I copied in your existing .htaccess into $targetDir/bin.

\tThe significant differences between the new template for .htacess and your previous one are:

";
	print join "\n", grep( /^[+-][^#]/ , split( /\r?\n/, diff("$targetDir/bin/.htaccess", "./bin/.htaccess.txt")));

	print "
You may need to apply some of these differences to the new .htaccess that I created... that's up to you.
(I'm not gonna mess with security settings at all!)

";

    }
    else
    {
	warn "
I couldn't copy in your existing .htaccess file from $setlibPath to $targetDir/bin: $!\n";
    }
}
else
{
    warn "
Couldn't see a .htaccess in $setlibPath ... so I didn't try to help in that respect\n";
}

# now let's try to get their scriptSuffix right for them 
# (Is this a good idea, I wonder?  Can't see why not...)

if ($TWikiCfg::scriptSuffix)
{
    print "
Applying your '\$scriptSuffix' ($TWikiCfg::scriptSuffix) to the scripts in $targetDir/bin...
";

    opendir(BINDIR, "$targetDir/bin") or 
	warn "Ooops - couldn't open $targetDir/bin for reading... that's certainly strange! ($!)\n";

    foreach my $f (readdir BINDIR)
    {
	next if ($f =~ m|\.|);  # scripts should not have dots, other things should!

	print "$f ";
	rename "$targetDir/bin/$f", "$targetDir/bin/$f$TWikiCfg::scriptSuffix"
	    or warn "Oops, couldn't rename $setlibPath/$f to $setlibPath/$f$TWikiCfg::scriptSuffix : $!\n";
    }
    print "\ndone\n";
}

# Also, for Cairo, we have to do the pattern skin additions 
# (etc, as mentioned in the UpgradeGuide, manual upgrade section)

print "Putting in default WebLeftBar and WebAdvancedSearch...\n";

if (-f "data/TWiki/WebLeftBarExample.txt")
{
    if (opendir(DATADIR, "$targetDir/data"))
    {
	foreach my $web (readdir DATADIR)
	{
	    next if ($web =~ m|^\.|); # don't hit '.' , '..'  .  Any other diretories starting with '.' are suss also.
	    next if (!-d "$targetDir/data/$web");

	    print "$web\n";
	    
	    if (!-f "$targetDir/data/$web/WebLeftBar.txt")
	    {
		copy("data/TWiki/WebLeftBarExample.txt", "$targetDir/data/$web/WebLeftBar.txt")
		    or warn "Couldn't put the default WebLeftBar.txt (from data/TWiki/WebLeftBarExample.txt) into $targetDir/data/$web/WebLeftBar.txt: $!\n";
	    }
	    else
	    {
		print "(already has one)\n";
	    }

	    if (!-f "$targetDir/data/$web/WebSearchAdvanced.txt")
	    {
		open(WSA, ">$targetDir/data/$web/WebSearchAdvanced.txt");
		print WSA '%INCLUDE{"%TWIKIWEB%.WebSearchAdvanced"}%'."\n";
		close WSA;
	    }
	}
    }
    else
    {
	warn "Hmmm - was going to add default WebLeftBar topics for you, but couldn't open $targetDir/data: $!  !\n";
    }
}
else
{
    warn "Hmmm - I was going to give all your webs a default WebLeftBar topic, but TWiki.WebLeftBarExample doesn't seem to be present in your distribution folders.  Your new twiki will still work, but check the 'UpgradeGuide' topic at twiki.org for information that might help explain this problem.\n"
}

# At last!

print "
Congratulations... you made it this far!

";

print "

Now: you need to 

 - Check the files listed above (if any) who's patches were rejected.

   For these files, you'll want to check the .rej file (in the same directory as the file)
   and see whether there are changes in there that you need to make manually.

 - Check the files list above that have 'no common versions' - in those cases, your
   new install will still work, but you need to be aware the topic file that is in 
   place is your old one... no changes from the new release have been included.

 - Check if you modified your old version of setlib.cfg: if you did,
    then you need to do the same to the new one (which you will find in ./bin).

   (There are only two reasons I can think of why you might have done that:
     1) You wanted to workaround the Apache2 hang bug or 
     2) You needed to point to a local perl library for some reason.  )

 - Setup authentication for the new TWiki

    If you are using htaccess, then check the diffs above make sense.
    If you are using some other method, you'll need to figure out what you need to do (sorry!)

 - Set the permissions appropriately for the new TWiki.

   I have given pub and data global read and write access, so your new TWiki
   will work, but you might want tighter controls.

 - If you are one of the few people who modified \@storeSettings, then you need to 
   look in TWiki.cfg and see if you need to make changes (I installed new the default ones)

   If you don't know what this means, it probably doesn't apply to you.

 - Re-install plugins you were using

 - Copy over custom templates you put in the original templates directory

 - anything else I haven't thought of

 - Archive your old installation 

 - Move the newly created twiki directory ($targetDir) to the place where your previous version was.

 - Rearrange sub-directories the way you like them, if needed.
   (some sites have bin in a very different place to the rest, for example)

 - Use your browser to check the whole thing: visit the 'testenv' script, which I am guessing is at:

      $TWikiCfg::defaultUrlHost$TWikiCfg::scriptUrlPath/testenv$TWikiCfg::scriptSuffix

   make sure there are no unwarranted warnings, 

   and finally: visit TWikiPreferences, which I'm guessing is at:

      $TWikiCfg::defaultUrlHost$TWikiCfg::scriptUrlPath/view$TWikiCfg::scriptSuffix/TWiki/TWikiPreferences

   ... it should be working, and you can edit the new WIKIWEBMASTER setting!

Goodluck... :-)
";

}


1;
