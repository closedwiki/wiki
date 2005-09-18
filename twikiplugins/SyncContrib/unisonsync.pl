#! perl -w
use strict;
use Data::Dumper;

my $configFile = 'unisonsync.cfg';
require $configFile;

print Dumper($UnisonSync::options);
die "No options hashref set" unless ($UnisonSync::options); 

syncTWikiInstall($UnisonSync::options, @ARGV);

sub syncTWikiInstall {
	my ($options, @args) = @_;
	my $accounts = $options->{accounts};
	
	my @accountNames;
	
	if (@args) {
	   @accountNames = @args;
	} else {
	   @accountNames = @{$options->{syncAccounts}};
	}

	print "Syncing Accounts ".join(',', @accountNames)."\n";
#	print Dumper($accounts);

	foreach my $accountName (@accountNames) {
		my $account = $accounts->{$accountName};
		if (!defined $account) {
			die "No such account '$accountName' - aborting\n";
		}
		print "Options: for $accountName:\n".Dumper($account)."\n" if ($account->{debug} > 1);
		print "Syncing $accountName\n" if ($account->{debug} > 0);
	    writePlinkLauncherScript($options, $account->{serverSite}, $account->{serverAccount}, $account->{clientServerPrivateKey});
	    my @webs = @{$account->{webs}};
	    foreach my $web (@webs) {
	    	print "\n... Syncing data \n" if ($account->{debug} > 1);
	    	syncFileSet($account, $options, $options->{dataDir}.'/'.$web);
	    	print "\n... Syncing pub\n" if ($account->{debug} > 1);
	    	syncFileSet($account, $options, $options->{pubDir}.'/'.$web);
	    }
		deletePlinkLauncherScript($options, $account);
	}
}


sub syncFileSet {
   my ($account, $options, $dir) = @_;
   my $cmd = getSyncFileSetCommand($account, $options, $dir);
   print $cmd."\n" if ($account->{debug} > 1);
   print `$cmd`;
}

sub getSyncFileSetCommand {
    my ($account, $options, $dir) = @_;    
    my $clientFileSet = $account->{clientRoot}.'/'.$dir;
	my $serverSpec = $options->{protocol}.'://'.$account->{serverSite}.'/';
    my $serverFileSet = $serverSpec.$account->{serverRoot}.'/'.$dir;
    my @unisonClientArgs = ("-batch", "-sshcmd", $options->{plinkTempLauncherScriptFile}, $account->{unisonOptions});
    my @cmd = ($options->{clientUnisonExecutable}, $clientFileSet, $serverFileSet, @unisonClientArgs);

	return join(' ',@cmd);
}


sub plinkLauncherScriptContents {
	my ($options, $serverSite, $serverAccount, $clientServerPrivateKey) = @_;
   return "\@\"$options->{plinkExecutable}\" $serverSite -i \"$clientServerPrivateKey\" -l $serverAccount -ssh $options->{serverUnisonExecutable} -server -contactquietly";
}

=pod
Writes a launcher file specific to the machine you are contacting but independent
of the twiki installations on that machine.

@"c:\program files\putty\plink.exe" mrjc.com -i "c:\Documents and Settings\Marti
n Cleaver\PuttyPrivateKey.ppk" -l mrjc -ssh unison -server -contactquietly
=cut

sub writePlinkLauncherScript {
	my ($options, $serverSite, $serverAccount, $clientServerPrivateKey) = @_;
    open( FILE, ">$options->{plinkTempLauncherScriptFile}" );
    print FILE plinkLauncherScriptContents($options, $serverSite, $serverAccount, $clientServerPrivateKey);
    close(FILE);    
}

sub deletePlinkLauncherScript {
	my ($options, $account) = @_;
    unlink $options->{plinkTempLauncherScriptFile} unless ($account->{debug} > 2);
}

