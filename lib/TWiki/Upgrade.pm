#
# this will become the Upgrade class - for now its just a few common functions
# Changes copyright (C) 2005 Sven Dowideit http://www.home.org.au


use strict;

package TWiki::Upgrade;

use File::Copy;

# new(, 
sub new {
	my( $class, $outputDir ) = @_;
    my $this = bless( {}, $class );
    $this->{outputDir} = $outputDir;
    $this->{logFileName} = '/UpgradeTwiki.log';
	return $this;
}

sub writeToLog {
	my $this = shift;
	#TODO: move this stuff into the base upgrade class
	open(UPGRADELOG, '>>'.$this->{outputDir}.$this->{logFileName}) || die "unable to open ".$this->{outputDir}.$this->{logFileName};
	print UPGRADELOG @_;
	close(UPGRADELOG);
}
sub writeToScreen {
	my $this = shift;
	print @_;
}
sub writeToLogAndScreen {
	my $this = shift;
	$this->writeToScreen(@_);
	$this->writeToLog(@_);
}

sub copyInitialFiles {
	my $this = shift;
	my $sourceDir = shift;
		
	$this->writeToLogAndScreen("Creating the ".$this->{outputDir}." directory structure from $sourceDir...\n");
	opendir(HERE , $sourceDir);

	foreach my $file (readdir(HERE)) {
    	next if ($file =~ /^\./);
    	next if ($file =~ /~$/);
		next if ($file =~ /.zip$/);
		next if ($file eq 'twikiplugins');  #lets skip it for speed while testing
		next if ($file eq "data"); # UpgradeTopics will copy the data as appropriate.
	    next if ($file eq "pub"); # UpgradeTopics will copy the data as appropriate.

    	$this->writeToLogAndScreen("$file\n");
    	system("cp -R $file ".$this->{outputDir});
	}
}

1;
