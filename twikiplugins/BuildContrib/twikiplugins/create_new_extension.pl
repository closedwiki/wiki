#! /usr/bin/perl -w
# Script for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 TWikiContributors. All righrts reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
use strict;

sub usage {
    print STDERR <<HERE;
This script will generate a new extension in a directory under
the twikiplugins directory, suitable for building using the
BuildContrib. Stubs for all required files will be generated.

You must be cd'ed to the twikiplugins directory, and you must
pass the name of your extension - which must end in Skin, Plugin,
Contrib, AddOn or TWikiApp - to the script. The extension directory
must not already exist.
HERE
}

use File::Path;

# For each key in %def, the corresponding %$..% string will be expanded
# in all output files. So %$MODULE% will expand to the name of the module.
# %$...% keys not found will be left unexpanded.
my %def;
$def{MODULE} = $ARGV[0];
usage(), exit 1 unless $def{MODULE};
usage(), exit 1 if -d $def{MODULE};

$def{MODULE} =~ /^.*?(Skin|Plugin|Contrib|AddOn|TWikiApp)$/;
$def{TYPE} = $1;
usage(), exit 1 unless $def{TYPE};

$def{STUBS} = $def{TYPE} eq 'Plugin' ? 'Plugins' : 'Contrib';

# Templates for all required files are in this script, after __DATA__
$/ = undef;
my @DATA = split(/<<<< (.*?) >>>>/, <DATA>);
shift @DATA;
my %data = @DATA;
my $stubPath = "$def{MODULE}/lib/TWiki/$def{STUBS}";
if ($def{TYPE} eq 'Plugin') {
    writeFile($stubPath, "$def{MODULE}.pm",
              getFile("EmptyPlugin/lib/TWiki/Plugins/EmptyPlugin.pm"));
} else {
    writeFile($stubPath, "$def{MODULE}.pm",
              $data{PM}.($data{"PM_$def{TYPE}"} || ''));
}
my $modPath = "$stubPath/$def{MODULE}";
writeFile($modPath, "build.pl", $data{"build.pl"});
writeFile($modPath, "DEPENDENCIES", $data{DEPENDENCIES});
writeFile($modPath, "MANIFEST", $data{MANIFEST});

writeFile("$def{MODULE}/lib/TWiki", "$def{MODULE}.txt",
          ($data{"TXT_$def{TYPE}"} || $data{TXT}));

sub expandVars {
    my $content = shift;
    $content =~ s/%\$(\w+)%/expandVar($1)/ge;
    return $content;
}

sub expandVar {
    my $var = shift;
    return '%$'.$var.'%' unless defined $def{$var};
    return $def{$var};
}

sub writeFile {
    my ($path, $file, $content ) = @_;
    print "Writing $path/$file\n";
    unless (-d $path) {
        File::Path::mkpath("./$path") || die "Failed to mkdir $path: $!";
    }
    open(F, ">$path/$file") || die "Failed to create $path/$file: $!";
    print F expandVars($content);
    close(F);
}

sub getFile {
    my $file = shift;
    local $/ = undef;
    open(F, "<$file") || die "Failed to open $file: $!";
    my $content = <F>;
    close(F);
    return $content;
}

__DATA__
<<<< build.pl >>>>
#!/usr/bin/perl -w
BEGIN {
    unshift @INC, split( /:/, $ENV{TWIKI_LIBS} );
}
use TWiki::Contrib::Build;

# Create the build object
$build = new TWiki::Contrib::Build('%$MODULE%');

# Build the target on the command line, or the default target
$build->build(\$build->{target});

<<<< DEPENDENCIES >>>>
# Dependencies for %$MODULE%
# Example:
# Time::ParseDate,>=2003.0211,cpan,Required.
# TWiki::Plugins,>=1.15,perl,TWiki 4.1 release.

<<<< MANIFEST >>>>
# Release manifest for %$MODULE%
data/TWiki/%$MODULE%.txt 0644 Documentation
lib/TWiki/%$STUBS%/%$MODULE%.pm 0644 Perl module

<<<< PM >>>>
# %$TYPE% for TWiki Collaboration Platform, http://TWiki.org/
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html

package TWiki::%$STUBS%::%$MODULE%;

use strict;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION );

$VERSION = '$Rev$';
$RELEASE = '';
$SHORTDESCRIPTION = '';

<<<< TXT >>>>
---+!! %$MODULE%

---++ Usage

---++ Installation Instructions

%$INSTALL_INSTRUCTIONS%

---++ %$TYPE% Info

|  %$TYPE% Author: | |
|  %$TYPE% Version: | %$VERSION% |
|  Change History: | <!-- versions below in reverse order -->&nbsp; |
|  Dependencies: | |
%$DEPENDENCIES%
|  TWiki:Plugins/Benchmark: | %TWIKIWEB%.GoodStyle nn%, %TWIKIWEB%.FormattedSearch nn%, %$MODULE% nn% |
|  %$TYPE% Home: | http://TWiki.org/cgi-bin/view/Plugins/%$MODULE% |
|  Feedback: | http://TWiki.org/cgi-bin/view/Plugins/%$MODULE%Dev |
|  Appraisal: | http://TWiki.org/cgi-bin/view/Plugins/%$MODULE%Appraisal |

<!-- Do _not_ attempt to edit this topic; it is auto-generated. Please add comments/questions/remarks to the Dev topic instead. -->

<<<< TXT_Plugin >>>>
---+!! %$MODULE%
%TOC%

---++ Usage

---++ Settings
<!--
One line description, is shown in the %TWIKIWEB%.TextFormattingRules.
Required if this extension is to be installed in TWiki < 4.1
    * Set SHORTDESCRIPTION = 
-->

---++ Installation Instructions

%$INSTALL_INSTRUCTIONS%

---++ %$TYPE% Info

|  %$TYPE% Author: | |
|  %$TYPE% Version: | %$VERSION% |
|  Change History: | <!-- versions below in reverse order -->&nbsp; |
|  Dependencies: | |
%$DEPENDENCIES%
|  TWiki:Plugins/Benchmark: | %TWIKIWEB%.GoodStyle nn%, %TWIKIWEB%.FormattedSearch nn%, %$MODULE% nn% |
|  %$TYPE% Home: | http://TWiki.org/cgi-bin/view/Plugins/%$MODULE% |
|  Feedback: | http://TWiki.org/cgi-bin/view/Plugins/%$MODULE%Dev |
|  Appraisal: | http://TWiki.org/cgi-bin/view/Plugins/%$MODULE%Appraisal |

<!-- Do _not_ attempt to edit this topic; it is auto-generated. Please add comments/questions/remarks to the Dev topic instead. -->
