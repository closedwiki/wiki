# Support functionality for the TWiki Collaboration Platform, http://TWiki.org/
#
#
# Jul 2004 - written by Martin "GreenAsJade" Gregory, martin@gregories.net

package TWiki::Upgrade::TWikiCfg;

use strict; 

use vars '$twikiLibPath';   # read from setlib.cfg
use vars '$localPerlLibPath';   # read from setlib.cfg
use vars '@storeSettings';  # read from TWiki.cfg

use Data::Dumper;
use File::Copy;
use Carp;
use Cwd;

=pod

---+ UNPUBLISHED package UpgradeTWikiConfig

Create an upgraded twiki installation configuration file from an existing one
and a new distribution.

Writes TWiki.cfg.new by default.

Dialogs with the user on STDIN/STDOUT.

=cut

sub UpgradeTWikiConfig {

    my $existingConfigInfo = shift or die "UpgradeTWikiConfig not passed any arguments!\n";
    my $targetDir = (shift or '.');
    my $newConfigFile = "$targetDir/lib/LocalSite.cfg";
    my $twikiCfgFile;

    if (-f "$existingConfigInfo/setlib.cfg") {
        my ($setlibPath) = $existingConfigInfo;

        # Find out from there what $twikiLibPath is
        my $dir = Cwd::cwd();
        chdir($setlibPath);
        require "$setlibPath/setlib.cfg";
        $twikiLibPath = $setlibPath.$twikiLibPath unless
          $twikiLibPath =~ m#^/#;
        chdir($dir);
        unshift(@INC, $twikiLibPath);

        print "Now generating new LocalLib.cfg from settings in old setlib.cfg...\n\n";
        my $newLibFile = "$targetDir/bin/LocalLib.cfg";
        open(NEW_CONFIG, ">$newLibFile") or die "Couldn't open $newLibFile to write it: $!\n";
        print NEW_CONFIG "# This is LocalLib.cfg. It contains the basic paths for your local\n";
        print NEW_CONFIG "# TWiki site.\n";
        print NEW_CONFIG "\$twikiLibPath = '$twikiLibPath';";
        close(NEW_CONFIG);

        if ($twikiLibPath =~ m|^[~/]|) {
            # absolute path in $twikiLibPath
            $twikiCfgFile = "$twikiLibPath/TWiki.cfg";
        } else {
            # relative path in $twikiLibPath
            $twikiCfgFile = "$existingConfigInfo/$twikiLibPath/TWiki.cfg";
        }
    } elsif (-f "$existingConfigInfo/TWiki.cfg") {
        $twikiCfgFile = "$existingConfigInfo/TWiki.cfg";
    } else {
        die "UpgradeTwikiConfig couldn't find either setlib.cfg or TWiki.cfg at $existingConfigInfo: seems like a bug, someone needs to check it's arguments!\n";
    }

    # No need to upgrade if LocalSite.cfg is already good
    eval 'use TWiki';
    if ( !$@ && defined &TWiki::new && -f "$twikiLibPath/TWiki/Client.pm" ) {
        print STDERR "$twikiLibPath is a Dakar TWiki\n";
        use vars qw(%cfg);
	%cfg = ();
	copy("$twikiLibPath/LocalSite.cfg","$targetDir/lib/LocalSite.cfg");
        foreach my $var qw( DataDir DefaultUrlHost PubUrlPath
                            PubDir TemplateDir ScriptUrlPath LocalesDir ) {
            die "$twikiLibPath points to a non-functional TWiki"
              unless $TWiki::cfg{$var};
        }
        do 'LocalSite.cfg';
	%TWiki::cfg = (%TWiki::cfg,%cfg);
        return( $TWiki::cfg{DataDir}, $TWiki::cfg{PubDir} );
    } else {
        print STDERR "$twikiLibPath is a Cairo TWiki\n";
        require TWiki::Upgrade::Cairo2DakarCfg;

        TWiki::requireConfig($twikiCfgFile);

        # and now we have the old definitions...
        # ...  write those out where we can, or new defaults where we can't

        return TWiki::upgradeConfig($twikiCfgFile, $newConfigFile);
    }
}

1;
