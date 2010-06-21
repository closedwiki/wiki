#!/usr/bin/perl
# This script converts a Moin wiki into TWiki placing all data into a TWiki
# web.
# Written by TaitCyrus June 2010
use strict;
use File::Copy;
use File::stat;

# Define where the Moin wiki data pages are located.
my $moinPages = "/var/www/moinwiki/data/pages";
# Define where you want to copy the TWiki'ized Moin pages.
my $TWikiHome = "/var/www/TWiki";
my $TWikiWeb  = "MOIN";
my $TWikiData = "$TWikiHome/data/$TWikiWeb";
my $TWikiPub  = "$TWikiHome/pub/$TWikiWeb";

# Get the list of all current Moin pages
opendir(SRC, $moinPages);
my @orgMoinPages = grep(! /^\./, readdir(SRC));
closedir(SRC);

my $t             = time();
my $caret         = "\1";
my $empty         = "\2";
my $left          = "\3";
my $right         = "\4";
my $firstTableRow = 1;

# For testing purposes, force the name(s) of the Moin page(s) you want to
# convert.
#@orgMoinPages = ("Parent1(2f)Parent2(2f)OurPage");

# First we attempt to convert Moin page names, which include hierarchical
# info, into TWiki page names with parent info.
my %moin2TWiki;
foreach my $fullPage (sort @orgMoinPages) {
    # Check if the page actually exists.  It might be in the moin dir tree,
    # but was moved so detect this.
    next if (! pageExists($fullPage));
    # Skip Moin internal pages
    next if ($fullPage =~ /MoinEditorBackup/);
    # Skip the self created CurrentWikiIndex file
    next if ($fullPage =~ /CurrentWikiIndex/);

    my $newFullPage = unMoinifyPageName($fullPage);
    my @parts       = split(/\//, $newFullPage);
    my $self        = pop(@parts);
    my $parent      = pop(@parts);
    $moin2TWiki{$self}{$newFullPage} = $parent;
} ## end foreach my $fullPage (sort ...)

# Define the Moin page names to TWiki page name mappings.  This attempts to
# retain the original Moin page name in TWiki.  The only exception is when
# there are duplicate Moin page names so in TWiki we prepend a pages parent
# name to the TWiki page name.
my %moin2TWikiPageMappings;
foreach my $self (sort keys %moin2TWiki) {
    my @fullPages = keys %{$moin2TWiki{$self}};
    if (@fullPages == 1) {
        my $fullPage = $fullPages[0];
        $fullPage = unMoinifyPageName($fullPage);
        my $parent = $moin2TWiki{$self}{$fullPage};
        $moin2TWikiPageMappings{$fullPage} = [$self, $parent];
    } else {
        foreach my $fullPage (@fullPages) {
            my $parent  = $moin2TWiki{$self}{$fullPage};
            my $newSelf = "${parent}_$self";
            $newSelf = "$self" if ($parent eq "");
            $fullPage = unMoinifyPageName($fullPage);
            $moin2TWikiPageMappings{$fullPage} = [$newSelf, $parent];
        }
    }
} ## end foreach my $self (sort keys...)

# Create a mapping file to help Apache map from the old names to the new
# names.  This is assuming that you want users who might have bookmarked
# Moin page names to continue to have access to the TWiki'ized pages.  So a
# possible Apache configuration might look like.
#
#     RewriteMap moinToTwiki txt:/var/www/TWiki/moin2TWikiMapping.txt
#     # If not /bin and not /pub then it doesn't appear to be a TWiki url so
#     # it is probably an old Moin url so we map to the TWiki name.
#     RewriteCond %{REQUEST_URI}  !^/bin/.*
#     RewriteCond %{REQUEST_URI}  !^/pub/.*
#     RewriteRule (.*) ${moinToTwiki:$1} [R]
#
open(MAP, ">$TWikiHome/moin2TWikiMapping.txt");
foreach my $page (sort keys %moin2TWikiPageMappings) {
    my ($map, $parent) = @{$moin2TWikiPageMappings{$page}};
    print MAP "/$page /$map\n";
}
close(MAP);

my @oldMoinIndex;
my @newTWikiIndex;
foreach my $fullPage (sort @orgMoinPages) {
    # Check if the page actually exists.  It might be in the moin dir tree,
    # but was moved so detect this.
    next if (! pageExists($fullPage));
    # Skip Moin internal pages
    next if ($fullPage =~ /MoinEditorBackup/);
    # Skip the self created CurrentWikiIndex file
    next if ($fullPage =~ /CurrentWikiIndex/);

    my ($dstPage, $parent) = convertMoinPageToTWikiPage($fullPage);

    $dstPage = unMoinifyPageName($dstPage);
    $dstPage = ucfirst($dstPage);

    # Create indexes of the old and new site so we can more easily compare
    # them.  Only useful if the site is somewhat small.
    my $oldPage = $fullPage;
    $oldPage =~ s!\(2f\)!/!g;
    $oldPage =~ s!\(2d\)!-!g;
    $oldPage =~ s!\(2e\)!.!g;
    push(@oldMoinIndex,  " * [:$oldPage:$oldPage]");
    push(@newTWikiIndex, "   * [[$dstPage][$dstPage]]");

    # Read in the Moin Wiki page
    my @data = readFile($fullPage);
    # Determine if there are any attachements referenced in the Moin page
    my @attachments = findAttachments(@data);
    # Convert the Moin Wiki page to TWiki format
    @data = moin2twiki(@data);
    # Add in the TWiki code to specify the parent
    unshift(@data, "%META:TOPICPARENT{name=\"$parent\"}%");

    # For each Moin attachment, copy the files into TWiki
    foreach my $attachment (@attachments) {
        $attachment =~ s/%20/ /g;
        my $srcFile = "$moinPages/$fullPage/attachments/$attachment";
        my $dstDir  = "$TWikiPub/$dstPage";
        if (! -d $dstDir) {
            #print "MKDIR [$dstDir]\n";
            mkdir($dstDir);
        }
        my $dstFile = "$dstDir/$attachment";
        $dstFile =~ s/ /_/g;
        if (-f $srcFile) {
            #print "copy($srcFile, $dstFile)\n";
            copy($srcFile, $dstFile);
            my $st   = stat($srcFile);
            my $size = $st->size;
            push(@data,
                "\%META:FILEATTACHMENT{name=\"$attachment\" attr=\"h\" autoattached=\"1\" comment=\"\" date=\"$t\" path=\"$attachment\" size=\"$size\" user=\"TWikiGuest\" version=\"1.1\"}\%"
            );
        }
    } ## end foreach my $attachment (@attachments)
        # Create the TWiki web page.
    my $dstFile = "$TWikiData/$dstPage.txt";
    writeFile($dstFile, @data);
} ## end foreach my $fullPage (sort ...)
# Write a TWiki index file showing all pages converted
my $dstFile = "$TWikiData/ConvertIndexWiki.txt";
writeFile($dstFile, @newTWikiIndex);

# Write a Moin wiki index file showing all Moin pages converted
$dstFile = "$moinPages/CurrentWikiIndex/revisions/00000001";
writeFile($dstFile, @oldMoinIndex);

# Check if this Moin page has been moved/exists
sub pageExists {
    my ($page) = @_;
    my $current = "$moinPages/$page/current";
    return 0 if (! -f $current);
    open(IN, $current);
    my $currentValue = <IN>;
    close(IN);
    chomp($currentValue);
    # If the revision referenced by 'current' doesn't exist, then the page
    # probably was renamed.
    if (! -f "$moinPages/$page/revisions/$currentValue") {
        return 0;
    }
    return 1;
} ## end sub pageExists

# Read in the specified Moin wiki page by reading in the latest revision
sub readFile {
    my ($page) = @_;
    # First get the latest revision ignoring what the 'current' file might
    # say.
    my $revDir = "$moinPages/$page/revisions";
    return () if (! -d $revDir);
    opendir(REV, $revDir);
    my @revs = sort grep(! /^\./, readdir(REV));
    closedir(REV);
    my $rev = pop(@revs);

    my $infile = "$moinPages/$page/revisions/$rev";
    print "READ [$infile]\n";
    open(IN, $infile) || die "Can't open '$infile': $!\n";
    my @data = <IN>;
    close(IN);
    chomp(@data);
    return @data;
} ## end sub readFile

# Write the specified data to the specified file.
sub writeFile {
    my ($dstFile, @data) = @_;
    if (-f $dstFile) {
        # If you need to improve this script and are re-running this script
        # over and over again, you don't care if $dstFile already exists or
        # not.
        #print "WARNING: already exists [$dstFile]\n";
        #return;
    }
    print "WRITE [$dstFile]\n";
    open(OUT, ">$dstFile") || die "Can't write '$dstFile': $!\n";
    foreach my $line (@data) {
        print OUT "$line\n";
    }
    close(OUT);
} ## end sub writeFile

# Look for any Moin Wiki key words indicating an attached file returning
# the attachements.
sub findAttachments {
    my (@data) = @_;
    my @attachments;
    foreach my $line (@data) {
        # Process attachments
        if ($line =~ m/attachment:(\S+)/) {
            push(@attachments, $1);
        }
        if ($line =~ m/\[\[ImageLink\((.*)\)\]\]/) {
            push(@attachments, $1);
        }
    }
    return @attachments;
}

# The main guts of this script.
# Attempts to convert Moin wiki format into TWiki format.
sub moin2twiki {
    my (@data) = @_;
    my %indents;
    my $verbatim = 0;
    # Iterate over each line in the data.  The data is inline editted.
    my @newData;
    foreach my $line (@data) {
        # Some special converts to deal with MicroSoft data having been
        # cut-n-pasted into Moin and we want to convert to regular ASCII.
        $line =~ s/\xe2\x80\x93/-/g;
        $line =~ s/\xe2\x80\x98/'/g;
        $line =~ s/\r//;
        # Handle Moin verbatim syntax {{{ ...verbatim text... }}}
        if ($line =~ m/(.*){{{(.*)/) {
            my $outsideVerbatim = $1;
            my $inVerbatim      = $2;
            $line     = moinLine2twikiLine($outsideVerbatim) . "<verbatim>$inVerbatim";
            $verbatim = 1;
            next;
        }
        if ($line =~ m/(.*)}}}(.*)/) {
            my $inVerbatim      = $1;
            my $outsideVerbatim = $2;
            $line     = "$inVerbatim<\/verbatim>" . moinLine2twikiLine($outsideVerbatim);
            $verbatim = 0;
            next;
        }
        # If inside a <verbatim> context, perform no other editing.
        if ($verbatim) {
            next;
        }
        $line = moinLine2twikiLine($line);
    } ## end foreach my $line (@data)
    return @data;
} ## end sub moin2twiki

sub moinLine2twikiLine {
    my ($line) = @_;
    # Convert the Moin wiki line indentation to TWiki indentation.
    if ($line =~ m/^(\s+)/) {
        my $indentLen   = length($1);
        my $twikiIndent = "   " x $indentLen;
        $line =~ s/^\s{$indentLen}/$twikiIndent/;
    }
    # Convert Moin syntax into TWiki syntax
    $line =~ s/(\s+\d+)\. /$1 /;                                        # numbered lists
    $line =~ s/(\s+)\. /$1* /;                                          # invisible bullets
    $line =~ s/^## page was renamed from.*//;                           # Delete comments
    $line =~ s/'''''(.*?)'''''/__$1__/g;                                # Convert bold italic
    $line =~ s/'''(.*?)'''\s/*$1* /g;                                   # Convert bold
    $line =~ s/'''(.*?)'''/${left}b$right$1${left}\/b$right/g;          # Convert bold
    $line =~ s/''(.*?)''/_$1_/g;                                        # Convert italic
    $line =~ s/__(.*?)__/${left}u$right$1${left}\/u$right/g;            # Convert underlining
    $line =~ s/--\((.*?)\)--/${left}del$right$1${left}\/del$right/g;    # Convert strike-through (1)
    $line =~ s/--(\S+)--/${left}del$right$1${left}\/del$right/g;        # Convert strike-through (1)
    $line =~ s/^= (.*) =/---+ $1/g;                                     # Convert header1
    $line =~ s/^== (.*) ==/---++ $1/g;                                  # Convert header2
    $line =~ s/^=== (.*) ===/---+++ $1/g;                               # Convert header3
    $line =~ s/^==== (.*) ====/---++++ $1/g;                            # Convert header4
    $line =~ s/^===== (.*) =====/---+++++ $1/g;                         # Convert header5
    $line =~ s/\[\[BR\]\]/\%BR\%/g;                                     # Convert <br/>
    $line =~ s/\[\[TableOfContents\(\d+\)\]\]/\%TOC\%/g;                # Convert TOC

    # Process Moin tables
    if ($line =~ m/\|\|/) {
        my $colWidths;
        ($line, $colWidths) = processTable($line);
        if ($firstTableRow) {
            # Figure out how much leading space there is and replicate
            # it on the %TABLE% line.
            $line =~ /(\s+)/;
            my $len = length($1);
            $line = " " x $len . "\%TABLE{datavalign=\"center\" tablerules=\"akk\" tablewidth=\"95%\" columnwidths=\"$colWidths\"}%\n" . $line;
        }
        $firstTableRow = 0;
    } else {
        $firstTableRow = 1;
    }
    # Process links
    if ($line =~ m/\[.*\]/) {
        $line = processLinks($line);
    }
    # Process attachments
    if ($line =~ m/attachment:(\S+)/) {
        my $attachment = $1;
        $attachment =~ s/\%20/_/g;
        $line       =~ s/attachment:(\S+)/\%ATTACHURL\%\/$attachment/g;
    }

    # Convert < and > into HTML
    $line =~ s/</&lt;/g;
    $line =~ s/>/&gt;/g;
    $line =~ s/$left/</g;
    $line =~ s/$right/>/g;
    return $line;
} ## end sub moinLine2twikiLine

# Process Moin Wiki link converting to TWiki formatted links
sub processLinks {
    my ($line) = @_;
    # Split the line into parts splitting at ']'
    my $newline  = "";
    my @parts    = split(/\]/, $line);
    my $numParts = @parts;
    foreach (my $i = 0; $i < $numParts; $i++) {
        my $part = $parts[$i];
        $part .= "]" if ($numParts == 1 || $i < $numParts - 1);
        if ($part =~ m/\[:(.*?):(.*?)\]/) {
            my $link = $1;
            my $parent;
            ($link, $parent) = convertMoinPageToTWikiPage($link);
            my $display = $2;
            $link =~ s!/!!g;
            $link =~ s! !_!g;
            # If the link contains an anchor, we tweak it to match below
            # (be a wiki word)
            $link =~ s/#(.*)/#Anchor$1/;
            $part =~ s/\[:(.*?):(.*?)\]/[[$link][$display]]/g;    # Convert links
        }
        if ($part =~ m/\["(.*)"\]/) {
            my $link = $1;
            my $parent;
            ($link, $parent) = convertMoinPageToTWikiPage($link);
            my $display = $1;
            $link =~ s/ /_/g;
            $part =~ s/\["(.*)"\]/[[$link][$display]]/g;          # Convert links
        }
        if ($part =~ m/\[(https*:\S+) (.*)\]/) {
            my $link    = $1;
            my $display = $2;
            $part =~ s/\[(https*:\S+) (.*)\]/[[$link][$display]]/g;    # Convert links
        }
        if ($part =~ m/\[attachment:(\S+) (.*)\]/) {
            my $link    = $1;
            my $display = $2;
            $link =~ s/\%20/_/g;
            $link = "\%ATTACHURL\%/$link";
            $part =~ s/\[.*?\]/[[$link][$display]]/g;                  # Convert links
        }
        if ($part =~ m/\[\[ImageLink\((.*)\)\]/) {
            my $file = $1;
            $file =~ s/ /_/g;
            $part =~ s/\[\[ImageLink\((.*)\)\]/\%ATTACHURL\%\/$file/;
        }
        if ($part =~ m/\[\[Anchor\((.*)\)\]/) {
            my $anchor = $1;
            # Make sure that the anchor is a wiki word
            $part =~ s/\[\[Anchor\((.*)\)\]/#Anchor$anchor/;
        }
        $newline .= $part;
    } ## end foreach (my $i = 0; $i < $numParts...)
    return $newline;
} ## end sub processLinks

# Process Moin Wiki tables converting to TWiki tables
my %rowspan;

sub processTable {
    my ($line) = @_;
    my @colWidths;
    # Determine what the leading spacing is
    $line =~ s/(^\s+)//;
    my $indent = $1;
    # Split the Moin table into fields
    my @orgFields = split(/\|\|/, $line);
    my @tmpFields;
    # "Fix" this table row based on any previous rowspan definitions.
    # First for any columns which are part of a rowspan we prepopulate the
    # field with the TWiki rowspan char of "^";
    foreach my $i (keys %rowspan) {
        my $rowSpan = $rowspan{$i};
        if ($rowSpan > 0) {
            $tmpFields[$i] = $caret;
            $rowspan{$i}--;
        }
    }
    # Second we take this rows data and put the data into the correct
    # columns.
    my $dstIndex = 0;
    foreach (my $srcIndex = 0; $srcIndex < @orgFields; $srcIndex++) {
        # Find the next dstIndex available to use
        while ($tmpFields[$dstIndex] ne "") {
            $dstIndex++;
        }
        $tmpFields[$dstIndex++] = $orgFields[$srcIndex];
    }
    # Now we iterate over each of the table fields.
    foreach (my $i = 1; $i < @tmpFields; $i++) {
        my $field = $tmpFields[$i];
        $field = $empty if ($field eq "");
        # See if a row span
        if ($field =~ m/\|(\d+)>/) {
            my $rowSpan = $1 - 1;
            $field =~ s/\|\d+>/>/;
            $rowspan{$i} = $rowSpan;
        }
        if ($field =~ m/<rowspan=(\d+)>/) {
            my $rowSpan = $1 - 1;
            $field =~ s/<rowspan=\d+>//;
            $rowspan{$i} = $rowSpan;
        }
        # See if a col span
        if ($field =~ m/-(\d+)>/) {
            my $colSpan = $1 - 1;
            $field =~ s/-\d+>/>/;
        }
        # Escape any single | into TWiki variable
        $field =~ s/\|/\%VBAR\%/g;
        # Escape any single ^ into TWiki variable
        $field =~ s/\^/\%CARET\%/g;

        my $leftAlign   = 0;
        my $centerAlign = 0;
        my $rightAlign  = 0;
        my $width       = "";
        my $bgcolor     = "";
        my $fgcolor     = "";
        $leftAlign   = 1 if ($field =~ m/text-align: left;/);
        $centerAlign = 1 if ($field =~ m/text-align: center;/);
        $rightAlign  = 1 if ($field =~ m/text-align: right;/);
        $leftAlign   = 1 if ($field =~ m/<\(>/);
        $centerAlign = 1 if ($field =~ m/<:>/);
        $rightAlign  = 1 if ($field =~ m/<\)>/);
        # Remove HTML tags that have no TWiki equivalents
        $field =~ s/<\s*tablewidth=.+?\s*>//g;
        $field =~ s/<\s*style=.+?\s*>//g;
        $field =~ s/<\s*table.+?\s*>//g;
        # Grab other MoinWiki tags in regular HTML tags
        if ($field =~ m/<(\d+\%)>/) {
            $width = $1;
            $field =~ s/<\d+\%>//g;
        }
        if ($field =~ m/width: (\d+%)/) {
            $width = $1;
            $field =~ s/width: (\d+%)//;
        }
        if ($field =~ m/width="(.*?)"/) {
            $width = $1;
            $field =~ s/width="(.*?)"//;
        }
        if ($field =~ m/bgcolor="(.*?)"/) {
            $bgcolor = $1;
            $field =~ s/bgcolor="(.*?)"//;
        }
        if ($field =~ m/[^g]color:\s*(\S+);/) {
            $fgcolor = $1;
            $field =~ s/[^g]color:\s*(\S+);//;
        }
        if ($field =~ m/<(#.*?)>/) {
            $bgcolor = $1;
            $field =~ s/<#.*?>//;
        }
        $colWidths[$i - 1] = $width;

        # Remove any remaining table HTML commands.  This might not be the
        # right thing to do, but for now, this is the best we can do (other
        # than convert the HTML tags into human readable text)
        $field =~ s/^<.*?>//g;

        # Escape any other HTML <> tags making them visible
        $field =~ s/<(.+?)>/&lt;$1&gt;/g;

        # If a bgcolor, set it
        if ($bgcolor ne "" && $bgcolor ne "transparent") {
            $bgcolor = "RED" if ($bgcolor =~ m/#ff0000/i);
            $bgcolor = uc($bgcolor);
            $field   = "%${bgcolor}BG%$field%ENDBG%";
        }
        # If a fgcolor, set it
        if ($fgcolor ne "" && $fgcolor ne "windowtext") {
            $fgcolor = uc($fgcolor);
            $field   = "%${fgcolor}%$field%ENDCOLOR%";
        }
        # Even though we did this above, we remove any extra spaces left
        # over after removing any <...> string.
        $field = $empty if ($field eq "");
        # Create the TWiki left, center, right alignment.
        if ($leftAlign) {
            $field = " $field  ";
        } elsif ($centerAlign) {
            $field = "  $field  ";
        } elsif ($rightAlign) {
            $field = "  $field ";
        } elsif ($field ne $empty) {
            # Strip off any leanding/trailing space
            $field =~ s/^\s+//;
            $field =~ s/\s+$//;
            $field = " $field ";
        }
        $tmpFields[$i] = $field;
    } ## end foreach (my $i = 1; $i < @tmpFields...)

    # Deal with any implicit colspans.  If a col is empty, then it is
    # assumed it is part of a col span.
    my $colSpan = 0;
    $dstIndex = 1;
    my @finalFields;
    $finalFields[0] = $tmpFields[0];
    foreach (my $i = 1; $i < @tmpFields; $i++) {
        my $field = $tmpFields[$i];
        $field =~ s/$caret/^/;
        $field =~ s/$empty//g;
        if ($field eq "") {
            $colSpan++;
        } else {
            $finalFields[$dstIndex++] = $field;
            while ($colSpan) {
                $finalFields[$dstIndex++] = "";
                $colSpan--;
            }
        }
    }
    my $colWidths = join(",", @colWidths);
    my $retLine = $indent . join("|", @finalFields) . "|";
    return ($retLine, $colWidths);
} ## end sub processTable

# Convert a Moin Wiki page name into the equivalent URL name
sub unMoinifyPageName {
    my ($page) = @_;
    $page =~ s!\(2f\)!\/!g;
    $page =~ s!\(2d\)!-!g;
    $page =~ s!\(2e\)!_!g;
    $page =~ s! !_!g;
    return $page;
}

# This routine converts a Moin Wiki page name into a TWiki parent name and
# TWiki page name.
sub convertMoinPageToTWikiPage {
    my ($page) = @_;
    my $fixedPage = unMoinifyPageName($page);
    my @ret = ($page, "");
    if (defined($moin2TWikiPageMappings{$page})) {
        @ret = @{$moin2TWikiPageMappings{$page}};
    } elsif (defined($moin2TWikiPageMappings{$fixedPage})) {
        @ret = @{$moin2TWikiPageMappings{$fixedPage}};
    }
    return @ret;
}
