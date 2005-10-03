#! perl -w
use strict;
use Data::Dumper;
use File::Path;

# (C) Martin Cleaver 2005
# This may be distributed in the same terms as Perl itself.

# Although protocol is a config option, the script assumes ssh

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


	foreach my $accountName (@accountNames) {
		my $account = $accounts->{$accountName};
		
		if (!defined $account) {
			$accounts->{$accountName} = {report=>''};
			report($accounts->{$accountName}, "No such account '$accountName' - skipping\n");
			next;
		}

		# Add to the structure a record of the account (user specifies it on the outside of the hash)
		$account->{accountName}	= $accountName;

		report($account, "Options: for $accountName:\n".Dumper($account)."\n") if ($account->{debug});
		report($account, "Syncing $accountName\n") if ($account->{debug});
		
	    writePlinkLauncherScript($options, $account->{serverSite}, $account->{serverAccount}, $account->{clientServerPrivateKey});
	    my @webs = @{$account->{webs}};
	    foreach my $web (@webs) {
			syncDir($account, $options, $options->{dataDir}, $web);
			syncDir($account, $options, $options->{pubDir}, $web);
	    }
		deletePlinkLauncherScript($options, $account->{serverSite}, $account);
	}

	print "\n-----\n";
	foreach my $accountName (@accountNames) {
		my $account = $accounts->{$accountName};	
		print $account->{report};
	}
}

sub report {
   my ($account, $text) = @_;
   $account->{report} .= $text;
   print $text;
}


sub syncDir {
	my ($account, $options, $dir, $web) = @_;
	report($account, "Sync report\n\nAccount:".$account->{accountName}."\nWeb: $web\nDir: $dir\n");

# TODO: test you can set this to '' and have that override separation of webs.
	unless ($account->{clientParentWeb}) {
		$account->{clientParentWeb} = $account->{accountName};
	}
	
    my $optionalClientParentSlash = optionalParentSlash($account->{clientParentWeb});
    my $optionalServerParentSlash = optionalParentSlash($account->{serverParentWeb});

	# SMELL - should not repeat this clientDirAbs
    my $clientDir = $dir.'/'.$optionalClientParentSlash.$web;
    my $clientDirAbs = $account->{clientRoot}.'/'.$clientDir;
    unless (-d $clientDirAbs) {
    	report($account, "Made directory $clientDirAbs\nWARNING: this is a new parent web - you will have to copy in the _default web content so that TWiki can show it properly\n");
    	mkpath $clientDirAbs || report($account, "ERROR: could not make $clientDirAbs\n");
    }
    my $serverDir = $dir.'/'.$optionalServerParentSlash.$web;
	report($account, "\n... Syncing $dir \n") if ($account->{debug} > 1);
	syncFileSet($account, $options, $clientDir, $serverDir);
}

sub syncFileSet {
   my ($account, $options, $clientDir, $serverDir) = @_;

   my $cmd = getSyncFileSetCommand($account, $options, $clientDir, $serverDir);
   report($account, $cmd."\n") if ($account->{debug} > 1);
   unless($account->{dryrun}) {
	   report($account, `$cmd`);
   } else {
   	   report($account, "dry run, so not executing\n");
   	   report($account, "(turn debug >= 2 to see cmd that would be executed)\n") unless ($account->{debug})
   }
}

sub optionalParentSlash {
   my ($optionalParent) = @_;
    if ($optionalParent) {
    	$optionalParent .= '/';
    } else {
    	$optionalParent = '';
    }  
    return $optionalParent;
}

sub getSyncFileSetCommand {
    my ($account, $options, $clientDir, $serverDir) = @_;    

	my @optionalSshCmd = ();
	my $optionalServerSpec = '';
	if ($account->{serverSite}) {
	   $optionalServerSpec = $options->{protocol}.'://'.$account->{serverSite}.'/';
	   @optionalSshCmd = ("-sshcmd", $options->{plinkTempLauncherScriptFile});
	}

    my $clientFileSet = $account->{clientRoot}.'/'.$clientDir;
    my $serverFileSet = $optionalServerSpec.$account->{serverRoot}.'/'.$serverDir;

    my @unisonArgs = ("-batch", @optionalSshCmd, $account->{unisonOptions});
    my @cmd = ($options->{clientUnisonExecutable}, $clientFileSet, $serverFileSet, @unisonArgs);

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
	if ($serverSite) {
	    open( FILE, ">$options->{plinkTempLauncherScriptFile}" );
    	print FILE plinkLauncherScriptContents($options, $serverSite, $serverAccount, $clientServerPrivateKey);
	    close(FILE);    
	}
}

sub deletePlinkLauncherScript {
	my ($options, $serverSite, $account) = @_;
	if ($serverSite) {
	    unlink $options->{plinkTempLauncherScriptFile} unless ($account->{debug} > 2);
	}
}

