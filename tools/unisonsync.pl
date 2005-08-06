#! perl -w
use strict;

my $plinkExecutable = 'c:\\program files\\putty\plink.exe';
my $clientUnisonExecutable = 'c:\\moreprgs\\unison\\unison-2.9.1-win-text.exe';
my $clientRoot = 'c:/moreprgs/indigoperl/apache/TWiki';
my $serverRoot = '/home/mrjc/cairotwiki.mrjc.com/twiki';
my $serverUnisonExecutable = 'unison';
my $serverAccount = 'mrjc';
my $clientServerPrivateKey = "c:\\Documents and Settings\\Martin Cleaver\\PuttyPrivateKey.ppk";

my $dataDir = 'data';
my $pubDir = 'pub';

my $web = 'Sandbox';

my $protocol = 'ssh';
my $serverSite = 'mrjc.com';

my $plinkTempLauncherScriptFile = 'c:\\temp\\plinkLauncher.bat';

main('Sandbox');

sub main {
	my $web = shift;
	my $fileSet = $clientRoot;
    writePlinkLauncherScript();
    syncFileSet($dataDir.'/'.$web);
    syncFileSet($pubDir.'/'.$web);
	deletePlinkLauncherScript();
}

sub syncFileSet {
   my $fileSet = shift;
   my $cmd = getSyncFileSetCommand($fileSet);
   print $cmd;
   print `$cmd`;
}

sub getSyncFileSetCommand {
    my $fileSet = shift;
    my $clientFileSet = $clientRoot.'/'.$fileSet;
	my $serverSpec = $protocol.'://'.$serverSite.'/';
    my $serverFileSet = $serverSpec.$serverRoot.'/'.$fileSet;
    my @unisonClientArgs = ("-batch", "-sshcmd", $plinkTempLauncherScriptFile);
    my @cmd = ($clientUnisonExecutable, $clientFileSet, $serverFileSet, @unisonClientArgs);

	return join(' ',@cmd);
}


sub plinkLauncherScriptContents {
   return "\@\"$plinkExecutable\" $serverSite -i \"$clientServerPrivateKey\" -l $serverAccount -ssh $serverUnisonExecutable -server -contactquietly";
}

sub writePlinkLauncherScript {
    open( FILE, ">$plinkTempLauncherScriptFile" );
    print FILE plinkLauncherScriptContents();
    close(FILE);    
}

sub deletePlinkLauncherScript {
    unlink $plinkTempLauncherScriptFile;
}

