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
use TWiki;

use URI::Escape;

=begin text

---
---+ package TWiki::Contrib::MailerContrib::Change
Object that represents a change to a topic.

=cut

package TWiki::Contrib::MailerContrib::Change;

=begin text

---++ ClassMethod new($web)
   * =$web= - Web name
   * =$topic= - Topic name
   * =$author= - String author of change
   * =$time= - String time of change
   * =$rev= - String revision identifier (of _new_ revision)
Construct a new change object.

=cut

sub new {
    my ( $class, $session, $web, $topic, $author, $time, $rev ) = @_;

    my $this = bless( {}, $class );

    $this->{SESSION} = $session;
    $this->{WEB} = $web;
    $this->{TOPIC} = $topic;
    my $user = $session->{users}->findUser( $author, undef, 1 );
    $this->{AUTHOR} = $user ? $user->wikiName() : $author;
    $this->{TIME} = TWiki::Time::formatTime( $time );
    $this->{REVISION} = $rev;

    # SMELL: this should use TWiki::Merge to show _what_
    # the changes were
    my( $meta, $text ) =
      $session->{store}->readTopic( undef, $web, $topic );
    $this->{SUMMARY} =
      $session->{renderer}->makeTopicSummary( $text, $topic, $web );

    return $this;
}


=begin text

---++ ObjectMethod expandHTML($html) -> string
   * =$html= - Template to expand keys within
Expand an HTML template using the values in this change. The following
keys are expanded: %<nop>TOPICNAME%, %<nop>AUTHOR%, %<nop>TIME%,
%<nop>REVISION%, %<nop>TEXTHEAD%.

Returns the expanded template.

=cut

sub expandHTML {
    my ( $this, $html ) = @_;

    $html =~ s/%TOPICNAME%/$this->{TOPIC}/go;
    $html =~ s/%AUTHOR%/$this->{AUTHOR}/geo;
    $html =~ s/%TIME%/$this->{TIME}/go;
    $html =~ s/%REVISION%/$this->{REVISION}/go;
    $html = $this->{SESSION}->{renderer}->getRenderedVersion( $html );
    $html =~ s/%TEXTHEAD%/$this->{SUMMARY}/go;

    return $html;
}

=begin text

---++ ObjectMethod expandPlain() -> string
Generate a plaintext version of this change.

=cut

sub expandPlain {
    my ( $this, $web ) = @_;

    # URL-encode topic names for use of I18N topic names in plain text
    my $scriptUrl =
      $this->{SESSION}->getScriptUrl
        ( URI::Escape::uri_escape( $web ),
          URI::Escape::uri_escape( $this->{TOPIC}),
          "view" );
    return "- $this->{TOPIC} ($this->{AUTHOR})\n  $scriptUrl\n";
}

1;
