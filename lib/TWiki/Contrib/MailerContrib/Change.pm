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

=pod

---
---+ package TWiki::Contrib::MailerContrib::Change
Object that represents a change to a topic.

=cut

package TWiki::Contrib::MailerContrib::Change;

use TWiki;

use URI::Escape;
use Assert;

=pod

---++ ClassMethod new($web)
   * =$web= - Web name
   * =$topic= - Topic name
   * =$author= - String author of change
   * =$time= - String time of change
   * =$rev= - Revision identifier
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
    $this->{TIME} = $time;
    ASSERT($rev) if DEBUG;
    # rev at this change
    $this->{CURR_REV} = $rev;
    # previous rev
    $this->{BASE_REV} = $rev - 1;

    return $this;
}

=pod

---++ ObjectMethod merge($change)
   * =$change= - Change record to merge
Merge another change record with this one, so that the combined
record is a reflection of both changes.

=cut

sub merge {
    my( $this, $other ) = @_;
    ASSERT(ref($this) eq "TWiki::Contrib::MailerContrib::Change" );
    ASSERT(ref($other) eq "TWiki::Contrib::MailerContrib::Change" );

    if( $other->{CURR_REV} > $this->{CURR_REV} ) {
        $this->{CURR_REV} = $other->{CURR_REV};
        $this->{AUTHOR} = $other->{AUTHOR};
        $this->{TIME} = $other->{TIME};
    }

    $this->{BASE_REV} = $other->{BASE_REV}
      if($other->{BASE_REV} < $this->{BASE_REV});
}

=pod

---++ ObjectMethod expandHTML($html) -> string
   * =$html= - Template to expand keys within
Expand an HTML template using the values in this change. The following
keys are expanded: %<nop>TOPICNAME%, %<nop>AUTHOR%, %<nop>TIME%,
%<nop>REVISION%, %<nop>TEXTHEAD%.

Returns the expanded template.

=cut

sub expandHTML {
    my ( $this, $html ) = @_;

    unless( defined $this->{HTML_SUMMARY} ) {
        $this->{HTML_SUMMARY} =
          $this->{SESSION}->{renderer}->summariseChanges
            ( undef, $this->{WEB}, $this->{TOPIC}, $this->{BASE_REV},
              $this->{CURR_REV}, 1 );
    }

    $html =~ s/%TOPICNAME%/$this->{TOPIC}/go;
    $html =~ s/%AUTHOR%/$this->{AUTHOR}/geo;
    my $tim =  TWiki::Time::formatTime( $this->{TIME} );
    $html =~ s/%TIME%/$tim/go;
    my $frev = "";
    if( $this->{CURR_REV} ) {
        if( $this->{CURR_REV} > 1 ) {
            $frev = "r$this->{BASE_REV}-&gt;r$this->{CURR_REV}";
        } else {
            # new _since the last notification_
            $frev = "<b>NEW</b>";
        }
    }
    $html =~ s/%REVISION%/$frev/go;
    $html = $this->{SESSION}->{renderer}->getRenderedVersion( $html );
    $html =~ s/%TEXTHEAD%/$this->{HTML_SUMMARY}/go;

    return $html;
}

=pod

---++ ObjectMethod expandPlain() -> string
Generate a plaintext version of this change.

=cut

sub expandPlain {
    my ( $this, $web ) = @_;

    unless( defined $this->{TEXT_SUMMARY} ) {
        $this->{TEXT_SUMMARY} =
          $this->{SESSION}->{renderer}->summariseChanges
            ( undef, $this->{WEB}, $this->{TOPIC}, $this->{BASE_REV},
              $this->{CURR_REV}, 0 );
    }

    # URL-encode topic names for use of I18N topic names in plain text
    my $scriptUrl =
      $this->{SESSION}->getScriptUrl
        ( URI::Escape::uri_escape( $web ),
          URI::Escape::uri_escape( $this->{TOPIC}),
          "view" );
    my $tim =  TWiki::Time::formatTime( $this->{TIME} );
    my $expansion = "- ".$this->{TOPIC}." (".$this->{AUTHOR}.", $tim) r";
    $expansion .= $this->{BASE_REV}."->r".$this->{CURR_REV};
    $expansion .= "\n$scriptUrl\n$this->{TEXT_SUMMARY}\n";
    return $expansion;
}

sub _summarise {
    my( $this, $tml ) = @_;

}

1;
