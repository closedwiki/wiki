package TWiki::Contrib::CommandSet::Plugin::Develop;

use TWiki::Contrib::TWikiShellContrib::DirHandling;
use TWiki::Contrib::TWikiShellContrib::Help qw{assembleHelp};

use File::Copy;

my $doco = {
   "SMRY" => "Prepares the file of a Plugin/Contrib for development",
   "SYNOPSIS" =>" plugin develop <Plugin/Contrib> - Copies the files for the Plugin/Contrib into the twiki root for development",
   "DESCRIPTION" =>
" This command will copy all the related files for a Plugin/Contrib
 from the \${TWIKIROOT}/twikiplugins directory to the proper place 
 under the \${TWIKIROOT} directory, while creating a manifest file 
 with all the files copied.
 This is an alternative to the =mklinks -copy=  command, with the
 added value that it creates a manifest file that can be used by 
 the Package CommandSet or the BuildContrib based =build.pl= 
 script to create a release version.

",
   "EXAMPLE" =>
" twikishell plugin develop TWikiShellContrib

    Will copy all the files from twikiplugins/TWihiShellContrib to
    their proper place and create the TWikiShellContrib.MF file 
    under \${TWIKIROOT}.   
"};


sub help {
   my $shell=shift;
   my $config=shift;
   return assembleHelp($doco,"SYNOPSIS","DESCRIPTION","EXAMPLE");
}


sub smry {
    return $doco->{'SMRY'};
}



sub run {
    my $shell=shift;
    my $config=shift;
    my $plugin=shift;
    my $pluginsDir=$config->{TWIKI}{root}."/twikiplugins";
    my @files=_processDir($shell,$pluginsDir."/".$plugin,$config->{TWIKI}{root},'');

    $shell->printVerbose('Generating Manifest file');

    open MANIFEST,">$config->{TWIKI}{root}/$plugin.MF";
    foreach my $file (@files) {
        $file =~ s/$config->{TWIKI}{root}\///;
        print MANIFEST $file."\n";
    }

    close MANIFEST;
}


sub _processDir {
   my ($shell,$srcDir,$targetDir,$currentDir)=@_;
   
   my $currentSrcDir=$srcDir;
   my $currentTargetDir=$targetDir;
   
   if ($currentDir) {
     $currentSrcDir.="/".$currentDir ;
     $currentTargetDir.="/".$currentDir;
   }
   
   my @files;
   my @entries = dirEntries($currentSrcDir);
   foreach my $entry (@entries) {
      next if ($entry =~ /^\.+$/ || $entry =~ /\.svn/);
      my $src= "$currentSrcDir/$entry";
      $shell->printVeryVerbose("Processing $src\n");    
      
      if (-d $src) {
         push (@files,_processDir($shell,$currentSrcDir,$currentTargetDir,$entry));
      } elsif (-f $src) {
         if (-f $currentTargetDir.'/'.$entry) {
            unlink  $currentTargetDir.'/'.$entry;
         }

         makepath($currentTargetDir.'/'.$entry);
         $shell->printVerbose('copying '.$entry.' to '. $currentTargetDir."\n");
         my $targetEntry=$currentTargetDir.'/'.$entry;
         copy($src, $targetEntry) || warn "Warning: Failed to copy $from to $to: $!";
         
         push (@files,$targetEntry);
      } else {                                 
         warn "Somethign Happened with $src\n";
      }
   }
   return @files;
}

1;
    
