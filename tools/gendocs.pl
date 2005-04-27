#!/usr/bin/perl -w
# Copyright (C) 2005 Crawford Currie - all rights reserved
# Generate TWiki code documentation topics in the current
# checkout area
# This script must be run from the 'tools' directory.
use strict;
use File::Find;
use Cwd;
use Getopt::Long;
use Pod::Usage;

my $Config;

my $root;

BEGIN {

    $Config = {
#
	smells => 1,
# 
	verbose => 0,
	debug => 0,
	help => 0,
	man => 0,
    };
    
    my $result = GetOptions( $Config,
			     'smells!',
# miscellaneous/generic options
			     'agent=s', 'help', 'man', 'debug', 'verbose|v',
			     );
    pod2usage( 1 ) if $Config->{help};
    pod2usage({ -exitval => 1, -verbose => 2 }) if $Config->{man};
    print STDERR Dumper( $Config ) if $Config->{debug};
    

    $root = Cwd::abs_path( '..' );

    unshift @INC, "$root/bin";
    do 'setlib.cfg';
};

use TWiki;

my $twiki = new TWiki("/TWiki", "BuildUser", "WebHome", "/save/TWiki");
my $user = $twiki->{users}->findUser("admin", "TWikiAdminGroup");
my @index;
my $smells = 0;

find( \&eachfile, ( $root ));

my $i = "---+ TWiki Source Code Packages\n";
$i .= "Wherever you see a smell, your help is needed to get rid of it!\n";
$i .= join("\n", sort @index);
if ( $Config->{smells} ) {
    $i .= "\n\n There were a total of *$smells* smells\n";
}
my $meta = new TWiki::Meta($twiki, "TWiki", "SourceCode");
print $twiki->{store}->saveTopic( $user, "TWiki", "SourceCode",
                                  $i,
                                  $meta,
                                  { dontlog => 1, minor => 1,
                                    comment => "created by build" } );

1;

sub eachfile {
    my $dir = $File::Find::dir;
    if( $dir =~ m!/\.! ||
        $dir =~ m!/test! ||
        $dir =~ m!/Plugins! ||
        $dir =~ m!/Upgrade! ||
        $dir =~ m!/Contrib! ) {
        ($File::Find::prune = 1);
        return;
    }

    my $file = $_;

    my $pmfile = $File::Find::name;
    $pmfile =~ s/\0//g;
    return unless -f $pmfile;

    return unless ( $file =~ /\.pm$/ );

    my $count = `egrep -c '^=pod' $pmfile`;
    return unless $count > 0;

    my $package = $dir;
    $package =~ s!.*/lib/?!!;
    $package =~ s!/!::!g;
    $package .= "::$file";
    $package =~ s/\.pm$//;
    $package =~ s/^:://;

    $file =~ s/^(.)/uc($1)/e;
    my $topic = "$dir$file";
    $topic =~ s!.*/lib/?!!;
    $topic =~ s/\.(.)/"Dot".uc($1)/ge;
    $topic =~ s!/(.)!uc($1)!ge;
    $topic =~ s/^(.)/uc($1)/e;

    open(PMFILE, "<$pmfile") or die "Failed to open $pmfile";
    my $text = "";
    my $inPod = 0;
    my $extends = "";
    my $addTo = \$text;
    my $packageSpec = "";
    my $packageName = "";
    my %spec;
    my $line;

    while( $line = <PMFILE>) {
        if( $line =~ /^=(begin|pod)/) {
            $inPod = 1;
        } elsif ($line =~ /^=cut/) {
            $addTo = \$text;
            $inPod = 0;
        } elsif ($inPod) {
            return if (!$Config->{smells} && $line =~ /^---\+\s+UNPUBLISHED/);
            if( $line =~ /---\++\s*(?:UNPUBLISHED\s*)?package\s*(.*)$/) {
                $packageName = $1;
                $packageName =~ s/\s+//g;
                $packageSpec = "";
                $addTo = \$packageSpec;
            } elsif( $line =~ /---\++\s+(Object|Class|Static)Method\s*(\w+)(.*)$/) {
                my $type = $1;
                my $name = $2;
                my $params = $3;
                $params =~ s/\s+//g;
                $params =~ s/->/ -> /g;
                $spec{$name} =
                  "---++ ${type}Method *$name* <tt>$params</tt>\n";
                $addTo = \$spec{$name};
                $text .= "!!!$name!!!\n";
            } else {
                $$addTo .= $line;
            }
        } else {
            if( $line =~ /\@($package\:\:)?ISA\s*=\s*qw\(\s*(.*)\s*\)/ ) {
                my $e = $2;
                if( $e =~ /^TWiki/ ) {
                    my $p = $e;
                    $p =~ s/:://g;
                    $p .= "DotPm";
                    $e = "[[$p][$e]]";
                }
                $extends = "\n*extends* <tt>$e</tt>\n";
            }
        }
    }
    close(PMFILE);

    my $howSmelly = "";
    if ( $Config->{smells} ) {
        $howSmelly = `egrep -c '(SMELL|FIXME|TODO)' $pmfile`;
        chomp($howSmelly);
        $smells += $howSmelly;
        if( $howSmelly) {
            $howSmelly = "\n\nThis package has smell factor of *$howSmelly*\n";
        } else {
            $howSmelly = "\n\nThis package doesn't smell\n";
        }
    }
    my $meta = new TWiki::Meta($twiki, "TWiki", $topic);
    $Config->{debug} && print STDERR "$pmfile -> $topic\n";
    push(@index, "---++ [[$topic][$packageName]] \n$packageSpec$howSmelly");
    $text = "---+ Package =$packageName=$extends\n$packageSpec\n%TOC%$text";
    foreach my $method ( sort keys %spec ) {
        $text =~ s/!!!$method!!!/$spec{$method}/;
    }


    print $twiki->{store}->saveTopic( $user, "TWiki", $topic, $text,
                              $meta,
                              { dontlog => 1, minor => 1,
                                comment => "created by build" } );
}

__DATA__
=head1 NAME

gendocs.pl - 

=head1 SYNOPSIS

gendocs.pl [options] 

Copyright (C) 2005 Crawford Currie.  All Rights Reserved.

 Options:
   -smells
   -verbose
   -debug
   -help			this documentation
   -man				full docs

=head1 OPTIONS

=over 8

=item B<-smells>

=back

=head1 DESCRIPTION

B<gendocs.pl> ...

=head2 SEE ALSO

	http://twiki.org/cgi-bin/view/Codev/...

=cut
