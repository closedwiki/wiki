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

package TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyPlugins::DOC;
use base 'TWiki::Contrib::SearchEngineKinoSearchAddOn::StringifyBase';
# Only if antiword exists, I register myself.
if (!(system("antiword -s")==-1)) {
    __PACKAGE__->register_handler("application/word", ".doc");}
use File::Temp qw/tmpnam/;

sub stringForFile {
    my ($self, $file) = @_;
    my $tmp_file = tmpnam();
    my $in;
    my $text = '';

    my $cmd = "antiword $file > $tmp_file";

    system($cmd);

    open $in, $tmp_file;
    $text = join(" ", <$in>);
    
    return $text;
}

1;
