#!/usr/bin/perl -w
#
# Utility for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2009-2010 TWiki:Main.AndrewJones
# Copyright (C) 2009-2010 TWiki Contributors
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.
#
# Copy this script into your data directory and it will loop through
# all topics and convert the old EasyTimelinePlugin <timeline> syntax
# to the new %TIMELINE% syntax. We cannot guarentee proper operation.
# This is a Q&D script, it does not update the topic history!
# Make a backup and test on a copy of your data first!

use File::Find::Rule;

my @subdirs = File::Find::Rule->directory->in( '.' );

foreach $dir (@subdirs){
    next if ($dir =~ m/^_|^\.|^Trash$/);
    # open dir, loop through files, open files with .txt$, search for syntax, output if found
    opendir( DIR, $dir) or die "can't opendir: $!";
    while( defined ( $filename = readdir ( DIR ) ) ) {
        if( $filename =~ /.*\.txt$/ ) {
            open INFILE, "<", "$dir/$filename" or print "$! $filename\n";
            my $file;
            while( <INFILE> ) {
                $file .= $_;
            }
            close INFILE;
            if( $file =~ s/<easytimeline>(.*?)<\/easytimeline>/%TIMELINE%\n$1%ENDTIMELINE%/mgos ) {
                open OUTFILE, ">", "$dir/$filename" or print "$! $filename\n";
                print OUTFILE $file;
                close OUTFILE;
            }
        }
    }
}
