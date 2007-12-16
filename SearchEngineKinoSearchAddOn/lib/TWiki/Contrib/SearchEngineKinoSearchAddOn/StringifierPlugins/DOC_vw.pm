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

package TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::DOC_vw;
use base 'TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase';
use File::Temp qw/tmpnam/;

# Only if vw exists, I register myself.
if (__PACKAGE__->_programExists("wvHtml")){
    __PACKAGE__->register_handler("application/word", ".doc");}

sub stringForFile {
    my ($self, $file) = @_;
    my $tmp_file = tmpnam();
    my $in;
    my $text = '';

    my $cmd = "wvHtml $file $tmp_file >/dev/null 2>&1";
    system($cmd);

    $text = TWiki::Contrib::SearchEngineKinoSearchAddOn::Stringifier->stringFor($tmp_file);
    unlink($tmp_file);

    return $text;
}

1;
