package TWiki::Contrib::CommandSet::Plugin::Develop;
use strict;
use TWiki::Contrib::TWikiShellContrib::DirHandling;
use TWiki::Contrib::TWikiShellContrib::Help qw{assembleHelp};

use File::Copy;

use vars qw {$MANIFEST $DEPENDENCIES};

($MANIFEST,$DEPENDENCIES)=('MANIFEST','DEPENDENCIES');

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
   #TODO: Use the manifest from the plugin directory as the manifest
    my $shell=shift;
    my $config=shift;
    my $plugin=shift;
    my $pluginsDir=$config->{TWIKI}{root}."/twikiplugins";
    my @files=_processDir($shell,$pluginsDir."/".$plugin,$config->{TWIKI}{root},'',$plugin);

    #     $shell->printVerbose('Generating Manifest file');
#
#     open MANIFEST,">$config->{TWIKI}{root}/$plugin.MF";
#     foreach my $file (@files) {
#         $file =~ s/$config->{TWIKI}{root}\///;
#         print MANIFEST $file."\n";
#     }
#     close MANIFEST;
}


sub _processDir {
   my ($shell,$srcDir,$targetDir,$currentDir,$plugin)=@_;
   
   my $currentSrcDir=$srcDir;
   my $currentTargetDir=$targetDir;
   
   if ($currentDir) {
     $currentSrcDir.="/".$currentDir ;
     $currentTargetDir.="/".$currentDir;
   }
   
#    my @files;
   my @entries = dirEntries($currentSrcDir);
   foreach my $entry (@entries) {
      next if ($entry =~ /^\.+$/ || $entry =~ /\.svn/);
      
      my $src= "$currentSrcDir/$entry";

      my $targetEntry='';
      if ($entry =~ /$MANIFEST/x) {
         $targetEntry=$shell->{config}->{TWIKI}{root}.'/'.$plugin.'.MF';
      } elsif ($entry =~ /$DEPENDENCIES/x) {
         $targetEntry=$shell->{config}->{TWIKI}{root}.'/'.$plugin.'.DEP';
      } elsif ($entry =~ /^.+?(\.tar\.gz|\.zip|\.tgz|\.txt|_installer\.pl)/x) {
         next;
      } else {
         $targetEntry=$currentTargetDir.'/'.$entry;
      }

      $shell->printVeryVerbose("Processing $src\n");    
      
      if (-d $src) {
         _processDir($shell,$currentSrcDir,$currentTargetDir,$entry,$plugin);
      } elsif (-f $src) {
         if (-f $currentTargetDir.'/'.$entry) {
            unlink  $currentTargetDir.'/'.$entry;
         }
         
         makepath($currentTargetDir.'/'.$entry);
         $shell->printVerbose('copying '.$entry.' to '. $targetEntry."\n");
         
         copy($src, $targetEntry) || warn "Warning: Failed to copy $src to $currentTargetDir: $!";
         
#          push (@files,$targetEntry) unless $entry=~ /($MANIFEST|$DEPENDENCIES)/;
         
      } else {                                 
         warn "Somethign Happened with $src\n";
      } 

   }
#    return @files;
}

1;
    
