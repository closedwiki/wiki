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

package TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::PDF;
use base 'TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase';

# Only if pdftotext exists, I register myself.
if (!(system("pdftotext -v >/dev/null 2>&1")==-1)) {
    __PACKAGE__->register_handler("application/pdf", ".pdf");}
use File::Temp qw/tmpnam/;

sub stringForFile {
    my ($self, $filename) = @_;
    my $tmp_file = tmpnam();
    my $in;
    my $text = '';

    system("pdftotext", $filename, $tmp_file);

    open $in, $tmp_file;
    $text = join(" ", <$in>);

    close($in);
    unlink($tmp_file);

    return $text;
}

1;
