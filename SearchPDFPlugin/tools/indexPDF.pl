#!c:/perl/bin/perl -w
#
# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Wind River Systems Inc.
# Copyright (C) 2004-2007 Peter Thoeny, peter@thoeny.org
# and TWiki Contributors.
#
# For licensing info read LICENSE file in the TWiki root.
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
# As per the GPL, removal of this notice is prohibited.

# Index PDF script. You must add the TWiki bin dir to the
# search path for this script, so it can find the rest of TWiki e.g.
# perl -I c:/twiki/bin c:/twiki/tools/indexPDF.pl

use strict;

BEGIN {
    require 'setlib.cfg';
}

use TWiki;

my $twiki = new TWiki();

# check to see if SearchPDFPlugin is enabled before running
die if ( !$TWiki::cfg{Plugins}{SearchPDFPlugin}{Enabled} );

my ( $web, $topic, $path, $file, $text, $meta, $attachtext, $exit );

my $adminuser =
  $twiki->{users}
  ->findUser( $twiki->{prefs}->getPreferencesValue("SEARCHPDFUSER"),
    $twiki->{prefs}->getPreferencesValue("SEARCHPDFUSERWEB"), 1 );

my $program =
  $TWiki::cfg{Plugins}{SearchPDFPlugin}{XPDFLocation} . ' %PDFFILE% %OUTPUT% '
  || 'c:/TWiki/xpdf-3.02-win32/pdftotext.exe %PDFFILE% %OUTPUT% ';

$program =~ tr/"//;

my $name  = $twiki->{store}->getWorkArea("SearchPDFPlugin") . "/SearchPDF.txt";
my $data  = '';
my $lease = '';
open( IN_FILE, "<$name" ) || return '';
local $/ = undef;    # set to read to EOF
$data = <IN_FILE>;
close(IN_FILE);
$data = '' unless $data;    # no undefined
my @data = split( /\n/, $data );
my $redodata = '';    #if there are problems adding text then add to redo file

foreach (@data) {

    if ( uc($_) eq "ALL" ) {

        # check for PDF in every web

        my $store = $twiki->{store};
        foreach my $aweb ( $store->getListOfWebs() ) {
            foreach my $atopic ( $store->getTopicNames($aweb) ) {

                foreach
                  my $topattach ( $store->getAttachmentList( $aweb, $atopic ) )
                {

                    if ( $topattach =~ m\pdf$\ ) {

                        push( @data, "$aweb,,,$atopic,,,$topattach" );

                    }
                }

            }
        }

    }
    else {

        ( $web, $topic, $file ) = split( /,,,/, $_ );

        # build path to pub directory that contains pdf

        # call pdftotext function

        # read meta tags from topic in data directory

        # add ATTACH meta tag

        # save meta tags to topic in data directory

        # print( "IndexPDF( $web $topic $file) \n" );

        # look for attach text in meta data

        ( $meta, $text ) = $twiki->{store}->readTopic( undef, $web, $topic );

        $attachtext = $meta->get( 'ATTACH', $file ) || '';

        # check to see if the file is being editted
        $lease = '';
        $lease = $twiki->{store}->getLease( $web, $topic );

        if ($lease) {    # file is being editted do not process
            $redodata .= "$web,,,$topic,,,$file\n";
        }
        else {
            if ( $attachtext eq '' ) {    # if no attachtext then generate it

                # run pdftotext program

                $path = $TWiki::cfg{PubDir} . "/$web/$topic/";
                ( $attachtext, $exit ) = $twiki->{sandbox}->sysCommand(
                    $program,
                    PDFFILE => $path . $file,
                    OUTPUT  => "-"
                );

                #sleep(15);

# clean up text (remove spaces and change to lowercase letters and numbers only)

# use s/// operator to replace bad characters with spaces and then multiple spaces with a single space

                $attachtext = lc($attachtext);

                $attachtext =~ tr/\n/ /;

                $attachtext =~ s/[^\w]/ /g;

                # replace white space by space
                $attachtext =~ s/\s+/ /g;

                # remove non-word characters
                #$attachtext =~ tr/a-zA-Z0-9_ //cd;

                #print $attachtext;

                # write meta data to topic file

                $meta->putKeyed(
                    'ATTACH',
                    {
                        name  => $file,
                        value => $attachtext
                    }
                );

                $twiki->{store}
                  ->saveTopic( $adminuser, $web, $topic, $text, $meta, {} );

            }

        }

    }

}

# read SearchPDFtxt file again, loop through each line to see if it has been processed in this run or not
# if the line hasn't been processed then write it back to the work space file

my $data2 = '';
open( IN_FILE, "<$name" ) || return '';
local $/ = undef;    # set to read to EOF
$data2 = <IN_FILE>;
close(IN_FILE);
$data2 = '' unless $data2;    # no undefined

my @data2 = split( /\n/, $data2 );

open( OUT_FILE, ">$name" ) || return '';

foreach (@data2) {
    if ( !$data =~ /$_/ ) {    # we haven't done that file
        print OUT_FILE "$_\n";    # save record to work space file
    }
}

# add any files that weren't processed due to lease issues
if ($redodata) {
    print OUT_FILE $redodata;
}

close(OUT_FILE);

