# Plugin for TWiki Collaboration Platform, http://TWiki.org/
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

package TWiki::Plugins::AttachmentListPlugin::FileData;

use strict;

use vars qw(
  $topic $web $attachment
);

=pod

=cut

sub new {
    my ( $class, $topic, $web, $attachment ) = @_;
    my $this = {};
    $this->{'topic'}      = $topic;
    $this->{'web'}        = $web;
    $this->{'attachment'} = $attachment;
    $this->{'attachment'}->{'_AttachmentListPlugin_extension'} =
      _getExtension( $this->{'attachment'}->{name} );
    bless $this, $class;
}

sub _getExtension {
    my ($fileName) = @_;

    my @bits = ( split( /\./, $fileName ) );
    my $extension = '';
    $extension = lc $bits[$#bits] if ( scalar @bits > 1 );
    return lc $extension;
}

sub toString {
    my ($this) = @_;

    return "FileData: topic="
      . $this->{'topic'}
      . "; web="
      . $this->{'web'}
      . "; attachment.name="
      . $this->{'attachment'}->{name};
}
1;
