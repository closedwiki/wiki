#
# TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2004 Wind River Systems Inc.
#
# For licensing info read license.txt file in the TWiki root.
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
use strict;

use URI::Escape;

=begin text

---
---++ package TWiki::Mailer::Change
Object that represents a change to a topic.

=cut

package TWiki::Mailer::Change;

=begin text

---+++ sub new($web)
| =$web= | Web name |
| =$topic= | Topic name |
| =$author= | String author of change |
| =$time= | String time of change |
| =$rev= | String revision identifier |
| =$summary= | String summary of the change |
Construct a new change object.

=cut

sub new {
    my ( $class, $web, $topic, $author, $time, $rev, $summary ) = @_;

    my $this = bless( {}, $class );

    $this->{WEB} = $web;
    $this->{TOPIC} = $topic;
    $this->{AUTHOR} = $author;
    $this->{TIME} = $time;
    $this->{REVISION} = $rev;
    $this->{SUMMARY} = $summary;

    return $this;
}


=begin text

---+++ sub expandHTML($session, $html) -> string
| =$html= | Template to expand keys within |
Expand an HTML template using the values in this change. The following
keys are expanded: %<nop>TOPICNAME%, %<nop>AUTHOR%, %<nop>TIME%,
%<nop>REVISION%, %<nop>TEXTHEAD%.

Returns the expanded template.

=cut

sub expandHTML {
    my ( $this, $session, $html ) = @_;

    $html =~ s/%TOPICNAME%/$this->{TOPIC}/go;
    $html =~ s/%AUTHOR%/$this->{AUTHOR}/geo;
    $html =~ s/%TIME%/$this->{TIME}/go;
    $html =~ s/%REVISION%/$this->{REVISION}/go;
    $html = $session->{renderer}->getRenderedVersion( $html );
    $html =~ s/%TEXTHEAD%/$this->{SUMMARY}/go;

    return $html;
}

=begin text

---+++ sub expandPlain() -> string
Generate a plaintext version of this change.

=cut

sub expandPlain {
    my ( $this, $session, $web ) = @_;

    # URL-encode topic names for use of I18N topic names in plain text
    my $scriptUrl =
      $session->getScriptUrl
          ( URI::Escape::uri_escape( $web ),
            URI::Escape::uri_escape( $this->{TOPIC}),
            "view" );
    return "- $this->{TOPIC} ($this->{AUTHOR})\n  $scriptUrl\n";
}

1;
