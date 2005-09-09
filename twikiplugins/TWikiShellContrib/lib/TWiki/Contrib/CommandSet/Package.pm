package TWiki::Contrib::CommandSet::Package;

use TWiki::Contrib::TWikiShellContrib::Common;
use TWiki::Contrib::TWikiShellContrib::DirHandling;
use TWiki::Contrib::TWikiShellContrib::Help;
use TWiki::Contrib::TWikiShellContrib::Zip;
use TWiki::Contrib::BuildContrib::BaseBuild;

use File::Copy;

my $doco = {
   "SMRY" => "Package a set of files for distribution",
   "SYNOPSIS" =>" package <TWikiApp> - Package a set of files for distribution",
   "DESCRIPTION" =>
"package will look in the twiki root for a manifest file 
called <TWikiApp>.MF, and use it's content to generate
the file <TWikiApp>.zip

The <TWikiApp>.MF file contains the list of files to be included, 
each one listed with the path relative to the twiki root 
installation. The wildcard * can be used to specify all the 
files in a directory.

The <TWikiApp>.MF and <TWikiApp>.DEP files are included automatically
in the package.
",
   "EXAMPLE" =>
"twikishell package TWikiShellContrib

    Will package all the files listed in TWikiShellContrib.MF 
    in a zip file for distribution.
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
   my ($shell,$config,$project)=@_;
   print "Packaging $project\n";
   my $tmpDir="$project.tmp.".time();
   my $srcDir=$config->{TWIKI}{root};
   mkdir($tmpDir);

   my $manifestFile=$srcDir.'/'.$project.'.MF';
   print $manifestFile."\n";

   my ($files,$otherModules)=readManifest($srcDir,'',$manifestFile);
   
   return unless $files;
#    my @toZip=map {$srcDir.'/'.$_->{name}} @{$files};
   foreach my $fileData (@{$files}) {
      my $file=$fileData->{name};

      if ($file =~ /(.*)\/\*/) {
         handleDir($srcDir,$tmpDir,$1);
      } else {
         handleFile($srcDir,$tmpDir,$file);
      }
   }
   handleFile($srcDir,$tmpDir,"$project.MF");
   handleFile($srcDir,$tmpDir,"$project.DEP"); #TODO: Handle Dependencies
  push @toZip, $srcDir.'/'."$project.MF";
  push @toZip, $srcDir.'/'."$project.DEP";
  #zip($config,$srcDir.'/'.$project.'.zip',@toZip);
#    sys_action('zip -r -q '.$srcDir.'/'.$project.'.zip *');
#   cd($srcDir);
#    sys_action('rm -rf '.$tmpDir);

}

sub handleFile {
   my ($srcDir,$tmpDir,$file)=@_;
   return if (!$file);
   print "processing $file\n";

   my $targetFile="$tmpDir/$file";
   makepath($targetFile);

   copy("$srcDir/$file",$targetFile);
}

sub handleDir {
   my ($srcDir,$tmpDir,$dir)=@_;
   print "processing $dir\n";
   if( opendir( DIR, "$srcDir/$dir" ) ) {
#       foreach my $file (grep {/\.(txt|pm)/} readdir DIR ) {
       foreach my $file (readdir DIR ) {
         if (-f "$srcDir/$dir/$file") {
            handleFile($srcDir,$tmpDir,"$dir/$file");
         } elsif (-d "$srcDir/$dir/$file" && $file ne '.' && $file ne '..') {
            handleDir($srcDir,$tmpDir,"$dir/$file");
         }
         
      }
   }
}

sub readFile {
   my $file=shift;
   print "->$file\n";
   open INBASE,"<$file";
   my @lines=<INBASE>;
   close INBASE;
   return @lines;
}

1;
