# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#
# As per the GPL, removal of this notice is prohibited.

=begin twiki

---+ package TWiki::Attach

A singleton object of this class is used to deal with attachments to topics.

=cut

package TWiki::Attach;

use strict;
use Assert;

use TWiki::Attrs;
use TWiki::Store;
use TWiki::User;
use TWiki::Prefs;
use TWiki::Meta;
use TWiki::Time;

=pod

---++ ClassMethod new( $session )
Constructor

=cut

sub new {
    my ( $class, $session ) = @_;
    my $this = bless( {}, $class );
    ASSERT(ref($session) eq 'TWiki') if DEBUG;
    $this->{session} = $session;
    return $this;
}

=pod

---++ ObjectMethod renderMetaData (  $web, $topic, $meta, $args, $isTopRev  ) -> $text

Generate a table of attachments suitable for the bottom of a topic
view, using templates for the header, footer and each row.
   * =$web= the web
   * =$topic= the topic
   * =$meta= meta-data hash for the topic
   * =$args= hash of attachment arguments
   * =$isTopRev= if this topic is being rendered at the most recent revision

=cut

sub renderMetaData {
    my( $this, $web, $topic, $meta, $attrs, $isTopTopicRev ) = @_;
    ASSERT(ref($this) eq 'TWiki::Attach') if DEBUG;

    $attrs = new TWiki::Attrs( $attrs );
    my $showAll = $attrs->{all};
    my $showAttr = $showAll ? 'h' : '';
	my $a = ( $showAttr ) ? ':A' : '';
    my $title = $attrs->{title} || '';

	my @attachments = $meta->find( 'FILEATTACHMENT' );
    return '' unless @attachments;

	my $rows = '';
	my $row = $this->_getTemplate("ATTACH:files:row$a");
    foreach my $attachment ( @attachments ) {
        my $attrAttr = $attachment->{attr};

        if( ! $attrAttr || ( $showAttr && $attrAttr =~ /^[$showAttr]*$/ )) {
            $rows .= $this->_formatRow( $web, $topic,
                                 $attachment,
                                 $isTopTopicRev,
                                 $row );
        }
    }

    my $text = '';

    if( $showAll || $rows ne '' ) {
        my $header = $this->_getTemplate("ATTACH:files:header$a");
        my $footer = $this->_getTemplate("ATTACH:files:footer$a");

        $text = "$header$rows$footer";
    }
    return "$title$text";
}

# PRIVATE get a template, reading the attachment tables template
# if not already defined.
sub _getTemplate {
    my ( $this, $template ) = @_;
    my $templates = $this->{session}->{templates};
    $templates->readTemplate('attachtables') unless
        $templates->haveTemplate( $template );

    return $templates->expandTemplate( $template );
}

=pod

---++ ObjectMethod formatVersions ( $web, $topic, $attrs ) -> $text

Generate a version history table for a single attachment
   * =$web= - the web
   * =$topic= - the topic
   * =$attrs= - Hash of meta-data attributes

=cut

sub formatVersions {
    my( $this, $web, $topic, %attrs ) = @_;
    ASSERT(ref($this) eq 'TWiki::Attach') if DEBUG;

    my $store = $this->{session}->{store};
    my $latestRev =
      $store->getRevisionNumber( $web, $topic, $attrs{name} );

    my $header = $this->_getTemplate('ATTACH:versions:header');
    my $footer = $this->_getTemplate('ATTACH:versions:footer');
    my $row    = $this->_getTemplate('ATTACH:versions:row');

    my $rows ='';

    for( my $rev = $latestRev; $rev >= 1; $rev-- ) {
        # SMELL: should get revision info from meta
        my( $date, $user, $minorRev, $comment ) =
          $store->getRevisionInfo( $web, $topic, $rev, $attrs{name} );
        $user = $user->webDotWikiName() if( $user );

        $rows .= $this->_formatRow( $web, $topic,
                             {
                              name    => $attrs{name},
                              version => $rev,
                              date    => $date,
                              user    => $user,
                              comment => $comment,
                              attr    => $attrs{attr},
                              size    => $attrs{size}
                             },
                             ( $rev == $latestRev),
                             $row );
    }

    return "$header$rows$footer";
}

#Format a single row in an attachment table by expanding a template.
#| =$web= | the web |
#| =$topic= | the topic |
#| =$info= | hash containing fields name, user (user (not wikiname) who uploaded this revision), date (date of _this revision_ of the attachment), command and version  (the required revision; required to be a full (major.minor) revision number) |
#| =$topRev= | boolean indicating if this revision is the most recent revision |
#| =$tmpl= | The template of a row |
sub _formatRow {
    my ( $this, $web, $topic, $info, $topRev, $tmpl ) = @_;

    my $row = $tmpl;

    $row =~ s/%A_(\w+)%/$this->_expandAttrs($1,$web,$topic,$info,$topRev)/ge;
    $row =~ s/\0/%/g;

    return $row;
}

sub _expandAttrs {
    my ( $this, $attr, $web, $topic, $info, $topRev ) = @_;
    my $file = $info->{name};

    if ( $attr eq 'REV' ) {
        return $info->{version};
    }
    elsif ( $attr eq 'ICON' ) {
        my $fileIcon = $this->{session}->{renderer}->filenameToIcon( $file );
        return $fileIcon;
    }
    elsif ( $attr eq 'EXT' ) {
	$file =~ m/\.(.*)$/;
        my $fileExtension = $1;
        return $fileExtension;
    }
    elsif ( $attr eq 'URL' ) {
        my $url;

        if ( $topRev ) {
            # I18N: To support attachments via UTF-8 URLs to attachment
            # directories/files that use non-UTF-8 character sets, go
            # through viewfile.
            # If using %PUBURL%, must URL-encode explicitly to site
            # character set.
            $url = TWiki::nativeUrlEncode( "%PUBURLPATH%/$web/$topic/$file" );
        } else {
            $url = $this->{session}->getScriptUrl
              ( $web, $topic, 'viewfile',
                rev => $info->{version}, filename => $file );
        }
        return $url;
    }
    elsif ( $attr eq 'SIZE' ) {
        my $attrSize = $info->{size};
        $attrSize = 100 if( $attrSize < 100 );
        return sprintf( "%1.1f&nbsp;K", $attrSize / 1024 );
    }
    elsif ( $attr eq 'COMMENT' ) {
        my $comment = $info->{comment};
        if ( $comment) {
            $comment =~ s/\|/&#124;/g;
        } else {
            $comment = "&nbsp;";
        }
        return $comment;
    }
    elsif ( $attr eq 'ATTRS' ) {
        return $info->{attr} or "&nbsp;";
    }
    elsif ( $attr eq 'FILE' ) {
        return $file;
    }
    elsif ( $attr eq 'DATE' ) {
        return TWiki::Time::formatTime( $info->{date} );
    }
    elsif ( $attr eq 'USER' ) {
        return $info->{user};
    }
    else {
        return "\0A_$attr\0";
    }
}

=pod

---++ ObjectMethod getAttachmentLink( $user, $web, $topic, $name, $meta ) -> $html

   * =$user= - User doing the reading
   * =$web= - Name of the web
   * =$topic= - Name of the topic
   * =$name= - Name of the attachment
   * =$meta= - Meta object that contains the meta info

Build a link to the attachment, suitable for insertion in the topic.

=cut

sub getAttachmentLink {
    my ( $this, $user, $web, $topic, $attName, $meta ) = @_;
    ASSERT(ref($this) eq 'TWiki::Attach') if DEBUG;

    my $att = $meta->get( 'FILEATTACHMENT', $attName );
    my $fileComment = $att->{comment};
    $fileComment = $attName unless ( $fileComment );

    my $fileLink = '';
    my $imgSize = '';
    my $prefs = $this->{session}->{prefs};
    my $store = $this->{session}->{store};

    if( $attName =~ /\.(gif|jpg|jpeg|png)$/i ) {
        # inline image

        # The pixel size calculation is done for performance reasons
        # Some browsers wait with rendering a page until the size of
        # embedded images is known, e.g. after all images of a page are
        # downloaded. When you upload an image to TWiki and checkmark
        # the link checkbox, TWiki will generate the width and height
        # img parameters, speeding up the page rendering.
        my $stream =  $store->getAttachmentStream( $user, $web, $topic, $attName );
        my( $nx, $ny ) = &_imgsize( $stream, $attName );
        my @attrs;

        if( $nx > 0 && $ny > 0 ) {
            push( @attrs, width=>$nx, height=>$ny );
            $imgSize = "width='$nx' height='$ny'";
        }
        $fileLink = $prefs->getPreferencesValue( 'ATTACHEDIMAGEFORMAT' );
        unless( $fileLink ) {
            push( @attrs, src=>"%ATTACHURLPATH%/$attName" );
            push( @attrs, alt=>$attName );
            return "\t* $fileComment: ".CGI::br().CGI::img({ @attrs });
        }
    } else {
        # normal attached file
        $fileLink = $prefs->getPreferencesValue( 'ATTACHEDFILELINKFORMAT' );
        unless( $fileLink ) {
            return "\t* [[%ATTACHURL%/$attName][$attName]]: $fileComment";
        }
    }

    $fileLink =~ s/^      /\t\t/go;
    $fileLink =~ s/^   /\t/go;
    $fileLink =~ s/\$name/$attName/g;
    $fileLink =~ s/\$comment/$fileComment/g;
    $fileLink =~ s/\$size/$imgSize/g;
    $fileLink =~ s/\\t/\t/go;
    $fileLink =~ s/\\n/\n/go;
    $fileLink =~ s/([^\n])$/$1\n/;

    return $fileLink;
}

# code fragment to extract pixel size from images
# taken from http://www.tardis.ed.ac.uk/~ark/wwwis/
# subroutines: _imgsize, _gifsize, _OLDgifsize, _gif_blockskip,
#              _NEWgifsize, _jpegsize
#
sub _imgsize {
    my( $file, $att ) = @_;
    my( $x, $y) = ( 0, 0 );

    $file = TWiki::Sandbox::normalizeFileName( $file );
    if( defined( $file ) ) {
        # for crappy MS OSes - Win/Dos/NT use is NOT SUPPORTED
        binmode( $file );
        my $s;
        return ( 0, 0 ) unless ( read( $file, $s, 4 ) == 4 );
        seek( $file, 0, 0 );
        if ( $s eq 'GIF8' ) {
            #  GIF 47 49 46 38
            ( $x, $y ) = _gifsize( $file );
        } else {
            my ( $a, $b, $c, $d ) = unpack( 'C4', $s );
            if ( $a == 0x89 && $b == 0x50 &&
                 $c == 0x4E && $d == 0x47 ) {
                #  PNG 89 50 4e 47
                ( $x, $y ) = _pngsize( $file );
            } elsif ( $a == 0xFF && $b == 0xD8 &&
                      $c == 0xFF && $d == 0xE0 ) {
                #  JPG ff d8 ff e0
                ( $x, $y ) = _jpegsize( $file );
            }
        }
        close( $file );
    }
    return( $x, $y );
}

sub _gifsize
{
    my( $GIF ) = @_;
    if( 0 ) {
        return &_NEWgifsize( $GIF );
    } else {
        return &_OLDgifsize( $GIF );
    }
}

sub _OLDgifsize {
    my( $GIF ) = @_;
    my( $type, $a, $b, $c, $d, $s ) = ( 0, 0, 0, 0, 0, 0 );

    if( defined( $GIF )              &&
        read( $GIF, $type, 6 )       &&
        $type =~ /GIF8[7,9]a/        &&
        read( $GIF, $s, 4 ) == 4     ) {
        ( $a, $b, $c, $d ) = unpack( 'C'x4, $s );
        return( $b<<8|$a, $d<<8|$c );
    }
    return( 0, 0 );
}

# part of _NEWgifsize
sub _gif_blockskip {
    my ( $GIF, $skip, $type ) = @_;
    my ( $s ) = 0;
    my ( $dummy ) = '';

    read( $GIF, $dummy, $skip );       # Skip header (if any)
    while( 1 ) {
        if( eof( $GIF ) ) {
            #warn "Invalid/Corrupted GIF (at EOF in GIF $type)\n";
            return '';
        }
        read( $GIF, $s, 1 );             # Block size
        last if ord( $s ) == 0;          # Block terminator
        read( $GIF, $dummy, ord( $s ) ); # Skip data
    }
}

# this code by "Daniel V. Klein" <dvk@lonewolf.com>
sub _NEWgifsize {
    my( $GIF ) = @_;
    my( $cmapsize, $a, $b, $c, $d, $e ) = 0;
    my( $type, $s ) = ( 0, 0 );
    my( $x, $y ) = ( 0, 0 );
    my( $dummy ) = '';

    return( $x,$y ) if( !defined $GIF );

    read( $GIF, $type, 6 );
    if( $type !~ /GIF8[7,9]a/ || read( $GIF, $s, 7 ) != 7 ) {
        #warn "Invalid/Corrupted GIF (bad header)\n";
        return( $x, $y );
    }
    ( $e ) = unpack( "x4 C", $s );
    if( $e & 0x80 ) {
        $cmapsize = 3 * 2**(($e & 0x07) + 1);
        if( !read( $GIF, $dummy, $cmapsize ) ) {
            #warn "Invalid/Corrupted GIF (global color map too small?)\n";
            return( $x, $y );
        }
    }
  FINDIMAGE:
    while( 1 ) {
        if( eof( $GIF ) ) {
            #warn "Invalid/Corrupted GIF (at EOF w/o Image Descriptors)\n";
            return( $x, $y );
        }
        read( $GIF, $s, 1 );
        ( $e ) = unpack( 'C', $s );
        if( $e == 0x2c ) {           # Image Descriptor (GIF87a, GIF89a 20.c.i)
            if( read( $GIF, $s, 8 ) != 8 ) {
                #warn "Invalid/Corrupted GIF (missing image header?)\n";
                return( $x, $y );
            }
            ( $a, $b, $c, $d ) = unpack( "x4 C4", $s );
            $x = $b<<8|$a;
            $y = $d<<8|$c;
            return( $x, $y );
        }
        if( $type eq 'GIF89a' ) {
            if( $e == 0x21 ) {         # Extension Introducer (GIF89a 23.c.i)
                read( $GIF, $s, 1 );
                ( $e ) = unpack( 'C', $s );
                if( $e == 0xF9 ) {       # Graphic Control Extension (GIF89a 23.c.ii)
                    read( $GIF, $dummy, 6 );        # Skip it
                    next FINDIMAGE;       # Look again for Image Descriptor
                } elsif( $e == 0xFE ) {  # Comment Extension (GIF89a 24.c.ii)
                    &_gif_blockskip( $GIF, 0, 'Comment' );
                    next FINDIMAGE;       # Look again for Image Descriptor
                } elsif( $e == 0x01 ) {  # Plain Text Label (GIF89a 25.c.ii)
                    &_gif_blockskip( $GIF, 12, 'text data' );
                    next FINDIMAGE;       # Look again for Image Descriptor
                } elsif( $e == 0xFF ) {  # Application Extension Label (GIF89a 26.c.ii)
                    &_gif_blockskip( $GIF, 11, 'application data' );
                    next FINDIMAGE;       # Look again for Image Descriptor
                } else {
                    #printf STDERR "Invalid/Corrupted GIF (Unknown extension %#x)\n", $e;
                    return( $x, $y );
                }
            } else {
                #printf STDERR "Invalid/Corrupted GIF (Unknown code %#x)\n", $e;
                return( $x, $y );
            }
        } else {
            #warn "Invalid/Corrupted GIF (missing GIF87a Image Descriptor)\n";
            return( $x, $y );
        }
    }
}

# _jpegsize : gets the width and height (in pixels) of a jpeg file
# Andrew Tong, werdna@ugcs.caltech.edu           February 14, 1995
# modified slightly by alex@ed.ac.uk
sub _jpegsize {
    my( $JPEG ) = @_;
    my( $done ) = 0;
    my( $c1, $c2, $ch, $s, $length, $dummy ) = ( 0, 0, 0, 0, 0, 0 );
    my( $a, $b, $c, $d );

    if( defined( $JPEG )             &&
        read( $JPEG, $c1, 1 )        &&
        read( $JPEG, $c2, 1 )        &&
        ord( $c1 ) == 0xFF           &&
        ord( $c2 ) == 0xD8           ) {
        while ( ord( $ch ) != 0xDA && !$done ) {
            # Find next marker (JPEG markers begin with 0xFF)
            # This can hang the program!!
            while( ord( $ch ) != 0xFF ) {
                return( 0, 0 ) unless read( $JPEG, $ch, 1 );
            }
            # JPEG markers can be padded with unlimited 0xFF's
            while( ord( $ch ) == 0xFF ) {
                return( 0, 0 ) unless read( $JPEG, $ch, 1 );
            }
            # Now, $ch contains the value of the marker.
            if( ( ord( $ch ) >= 0xC0 ) && ( ord( $ch ) <= 0xC3 ) ) {
                return( 0, 0 ) unless read( $JPEG, $dummy, 3 );
                return( 0, 0 ) unless read( $JPEG, $s, 4 );
                ( $a, $b, $c, $d ) = unpack( 'C'x4, $s );
                return( $c<<8|$d, $a<<8|$b );
            } else {
                # We **MUST** skip variables, since FF's within variable
                # names are NOT valid JPEG markers
                return( 0, 0 ) unless read( $JPEG, $s, 2 );
                ( $c1, $c2 ) = unpack( 'C'x2, $s );
                $length = $c1<<8|$c2;
                last if( !defined( $length ) || $length < 2 );
                read( $JPEG, $dummy, $length-2 );
            }
        }
    }
    return( 0, 0 );
}

#  _pngsize : gets the width & height (in pixels) of a png file
#  source: http://www.la-grange.net/2000/05/04-png.html
sub _pngsize {
    my ($PNG) = @_;
    my ($head) = '';
    my($a, $b, $c, $d, $e, $f, $g, $h)=0;
    if( defined($PNG)                              &&
       read( $PNG, $head, 8 ) == 8                 &&
       $head eq "\x89\x50\x4e\x47\x0d\x0a\x1a\x0a" &&
       read($PNG, $head, 4) == 4                   &&
       read($PNG, $head, 4) == 4                   &&
       $head eq 'IHDR'                             &&
       read($PNG, $head, 8) == 8 ){
        ($a,$b,$c,$d,$e,$f,$g,$h)=unpack('C'x8,$head);
        return ($a<<24|$b<<16|$c<<8|$d, $e<<24|$f<<16|$g<<8|$h);
    }
    return (0,0);
}

#Get file attachment attributes for old html
#format.
sub _getOldAttachAttr {
    my( $this, $atext ) = @_;
    my $fileName='';
	my $filePath='';
	my $fileSize='';
	my $fileDate='';
	my $fileUser='';
	my $fileComment='';
    my $before='';
	my $item='';
	my $after='';

    ( $before, $fileName, $after ) = split( /<(?:\/)*TwkFileName>/, $atext );
    if( ! $fileName ) { $fileName = ''; }
    if( $fileName ) {
        ( $before, $filePath,    $after ) = split( /<(?:\/)*TwkFilePath>/, $atext );
        if( ! $filePath ) { $filePath = ''; }
        $filePath =~ s/<TwkData value="(.*)">//go;
        if( $1 ) { $filePath = $1; } else { $filePath = ''; }
        $filePath =~ s/\%NOP\%//goi;   # delete placeholder that prevents WikiLinks
        ( $before, $fileSize,    $after ) = split( /<(?:\/)*TwkFileSize>/, $atext );
        if( ! $fileSize ) { $fileSize = '0'; }
        ( $before, $fileDate,    $after ) = split( /<(?:\/)*TwkFileDate>/, $atext );
        if( ! $fileDate ) { 
            $fileDate = '';
        } else {
            $fileDate =~ s/&nbsp;/ /go;
            $fileDate = TWiki::Time::parseTime( $fileDate );
        }
        ( $before, $fileUser,    $after ) = split( /<(?:\/)*TwkFileUser>/, $atext );
        if( ! $fileUser ) { 
            $fileUser = ''; 
        } else {
            my $u = $this->{session}->{users}->findUser( $fileUser );
            $fileUser = $u->login() if $u;
        }
        $fileUser =~ s/ //go;
        ( $before, $fileComment, $after ) = split( /<(?:\/)*TwkFileComment>/, $atext );
        if( ! $fileComment ) { $fileComment = ''; }
    }

    return ( $fileName, $filePath, $fileSize, $fileDate, $fileUser, $fileComment );
}

=pod

---++ ObjectMethod migrateToFileAttachmentMacro (  $meta, $text  ) -> $text

Migrate old HTML format

=cut

sub migrateToFileAttachmentMacro {
    my ( $this, $meta, $text ) = @_;
    ASSERT(ref($this) eq 'TWiki::Attach') if DEBUG;
    ASSERT(ref($meta) eq 'TWiki::Meta') if DEBUG;

    my ( $before, $atext, $after ) = split( /<!--TWikiAttachment-->/, $text );
    $text = $before || '';
    $text .= $after if( $after );
    $atext  = '' if( ! $atext  );

    if( $atext =~ /<TwkNextItem>/ ) {
        my $line = '';
        foreach $line ( split( /<TwkNextItem>/, $atext ) ) {
            my( $fileName, $filePath, $fileSize, $fileDate, $fileUser, $fileComment ) =
              $this->_getOldAttachAttr( $line );

            if( $fileName ) {
                $meta->put( 'FILEATTACHMENT',
                            {
                             name    => $fileName,
                             version => '',
                             path    => $filePath,
                             size    => $fileSize,
                             date    => $fileDate,
                             user    => $fileUser,
                             comment => $fileComment,
                             attr    => ''
                            });
            }
        }
    } else {
        # Format of macro that came before META:ATTACHMENT
        my $line = '';
        foreach $line ( split( /\n/, $atext ) ) {
            if( $line =~ /%FILEATTACHMENT{\s"([^"]*)"([^}]*)}%/ ) {
                my $name = $1;
                my $values = new TWiki::Attrs( $2 );
                $values->{name} = $name;
                $meta->put( 'FILEATTACHMENT', $values );
            }
        }
    }

    return $text;
}

=pod

---++ ObjectMethod upgradeFrom1v0beta (  $meta  ) -> $text

CODE_SMELL: Is this really necessary? upgradeFrom1v0beta?

=cut

sub upgradeFrom1v0beta {
    my( $this, $meta ) = @_;
    ASSERT(ref($this) eq 'TWiki::Attach') if DEBUG;

    my @attach = $meta->find( 'FILEATTACHMENT' );
    foreach my $att ( @attach ) {
        my $date = $att->{date};
        if( $date =~ /-/ ) {
            $date =~ s/&nbsp;/ /go;
            $date = TWiki::Time::parseTime( $date );
        }
        $att->{date} = $date;
        my $u = $this->{session}->{users}->findUser( $att->{user} );
        $att->{user} = $u->login() if $u;
    }
}

1;
