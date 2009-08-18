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

##########################################################################
#
# This work was created  by TWIKI.NET (http://www.twiki.net)
# Contact sales@twiki.net for any information
#
##########################################################################


package TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::XLSX;
use base 'TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase';
__PACKAGE__->register_handler("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", ".xlsx");

use Text::Iconv;
use Spreadsheet::XLSX;
use Encode;


sub stringForFile {
    my ($self, $file) = @_;

    my $converter = Text::Iconv->new("utf-8", "windows-1251");
    my $book = Spreadsheet::XLSX->new ($file, $converter);
    return unless $book;

    my $text = '';

    foreach my $sheet (@{$book -> {Worksheet}}) {

        $text .= sprintf("%s\n",$sheet->{Name});

        $sheet -> {MaxRow} ||= $sheet -> {MinRow};

         foreach my $row ($sheet -> {MinRow} .. $sheet -> {MaxRow}) {

                $sheet -> {MaxCol} ||= $sheet -> {MinCol};

                foreach my $col ($sheet -> {MinCol} ..  $sheet -> {MaxCol}) {

                        my $cell = $sheet -> {Cells} [$row] [$col];

                        if ($cell) {
                           $text .= sprintf("%s\n", $cell -> {Val});
                        }

                }

        }

 }



    $text = encode("iso-8859-15", $text);
    return $text;
}

1;
