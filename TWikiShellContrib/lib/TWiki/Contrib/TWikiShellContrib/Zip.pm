package TWiki::Contrib::TWikiShellContrib::Zip;

use Exporter;

@ISA=(Exporter);
@EXPORT=qw(checkUnzipMechanism unzip);

use strict;


sub unzip {
    my ($config,$sourceFile,$destDir)=@_;
    
    $config->printVeryVerbose("--> Inflating $sourceFile to $destDir\n");
    
    if ($config->{ZIP}{useArchiveZip}) {
        # Wrapped in eval to prevent a compilation error if Archive::Zip is not installed.
        eval("use Archive::Zip;");  
        eval {
            my $zip=Archive::Zip->new($sourceFile);
            my @members=$zip->members();
            foreach my $member (@members) {
                $zip->extractMember($member->fileName(),$destDir."/".$member->fileName());
                $config->printVeryVerbose("   --> Inflating ".$member->fileName() . "\n");
            }
        };
    } else {
        system($config->{ZIP}{unzipPath}. " $sourceFile ".$config->{ZIP}{unzipParams}." $destDir");    
    }
    print "\n"; 
}

sub checkUnzipMechanism {
    my $config=shift;
    if ($config->{ZIP}{useArchiveZip} && 
        ($config->{ZIP}{useArchiveZip} eq 0 && 
            defined $config->{ZIP}{unzipPath} && 
            defined $config->{ZIP}{unzipParams}) || 
        $config->{ZIP}{useArchiveZip} eq 1) {
        $config->printVeryVerbose("**** Zip file services installed ****\n");
        return;
    }
    
    $config->printNotQuiet("**** Configuring Zip files service ****\n");
    
    $config->printNotQuiet(" * Checking if Archive::Zip is installed .... ");
    
    eval "use Archive::Zip";
    if ($@) {
        $config->printNotQuiet("NOT INSTALLED\n");
        $config->{ZIP}{useArchiveZip}=0;
        _checkUnzipPath($config);
    } else {
        $config->printNotQuiet("INSTALLED \n");
        $config->{ZIP}{useArchiveZip}=1;
    }
    $config->save();
    $config->printNotQuiet("**** Zip files service Configured  ****\n");

}

sub _checkUnzipPath {
    my $config=shift;
    my $unzipPath =shift|| "/usr/bin/unzip"; # Reasonable Default
    
    $config->printNotQuiet(" * Searching an unzip program at $unzipPath .... ");
    
    if ($unzipPath && -f $unzipPath) {
        $config->printNotQuiet("FOUND\n");
    } else {
        $config->printNotQuiet("NOT FOUND\n");
        $unzipPath=_findUnzipPath($config);
    }    
    $config->{ZIP}{unzipPath} = $unzipPath;
    $config->{ZIP}{unzipParams} = askDirectoryParameter($config);
}

sub askDirectoryParameter
{
    my $config=shift;
    print " Please tell me the parameters to tell the unzip program \n which is target directory ---> "; 
    my $params;
    do {
        chomp ($params = <STDIN>);
    } until (($params=~ /^\-\-*[a-zA-Z]+/) ? 1 :
        (print(" Hmmm - $params don't seem a reasonable parameter ... please check and try again\n      --->"), 0) 
    );
    
    $params = $params || "-d"; # Reasonable Default for unzip
   return $params;
}

sub _findUnzipPath {
    my $config=shift;
    
    print " Please tell me the path to an unzip program\n      ---> "; 
    my $path;
    do {
        chomp ($path = <STDIN>) ;
    } until ((-f "$path") ? 1 :
        (print(" Hmmm - I can't see an unzip program at $path ... please check and try again\n      --->"), 0) 
        );
    return $path;
}

1;