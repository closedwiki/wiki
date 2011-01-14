# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2002-2006 Peter Thoeny, peter@thoeny.org
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version. For
# more details read LICENSE in the root of this distribution.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at
# http://www.gnu.org/copyleft/gpl.html
#
# As per the GPL, removal of this notice is prohibited.
#
# This plugin replaces smilies with small smilies bitmaps

package TWiki::Plugins::RemoteFileAttachPlugin;

use strict;

use vars qw( $VERSION $RELEASE);

# This should always be $Rev: 8154 $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 8154 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

my $topic;
my $web;
my $user;
my $installWeb;
my $msg; 
my $status;
  # 0 - done nothing
  # 1 - done something, $msg is set

sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between InterwikiPlugin and Plugins.pm" );
        return 0;
    }
    
    $msg = "";
    $status = 0;
    
    # Initialization OK
    return 1;
}

sub commonTagsHandler {
  
    $_[0] =~ s/%REMOTEFILEATTACH{(.*?)}%/remotefileattach($1)/geo;  
    $_[0] =~ s/%REMOTEFILEATTACH_MSG%/$msg/geo if ($status);
   
}

sub preRenderingHandler {
  
  $_[0] =~ s/%REMOTEFILEATTACH_MSG%//go;

}

sub remotefileattach {
  # this function should always return an string
  
  my $query =  TWiki::Func::getCgiQuery( );
  if ($query && $query->{remotefileattach}) {
    # we got redirected after succesfully attaching a file,
    # we're not doing it again
    return "";
  }
  
  my $params = shift;
  
  # 
  # extract and check parameters
  #
  my %params =  TWiki::Func::extractParameters($params);
  
  # url
  # if no URL is defined, do nothing
  return "" if (!defined($params{_DEFAULT}) || $params{_DEFAULT} eq "");
  my $url = $params{_DEFAULT};
  
  # name
  $url =~ /\/([^\/?#]*)[^\/]*$/o; # default name
  # or is name given as argument?
  my $name = defined($params{name}) ? $params{name} : $1;
  
  # overwrite?
  my $overwrite = 0;
  $overwrite=1 if (defined($params{overwrite}) && $params{overwrite} =~ /^(1|yes|true|on)$/io);
    
  if ($name eq "") {
    $status = 1;
    $msg = "No name specified.";
    return "";
  }
  
  # If we don't want to overwrite, check if an attachment with this name
  # already exists. If so, don't attach.
  if (!$overwrite) {
    if (TWiki::Func::attachmentExists( $web, $topic, $name )) {
      $msg = "Attachment with name '$name' already exists"; 
      $status = 1;
      return "";
    }
  }
  
  downloadFile($url, $name);
  
  # Put temporary attachment item in meta information
  # Not very important, but nice when the redirect fails.
  my $context =  TWiki::Func::getContext();
    
  my $attrs;
  $attrs->{attachment} = $name;
  $attrs->{version} = "";
  $attrs->{user} = "";
  $attrs->{name} = $name;
  $context->{can_render_meta}->putKeyed( 'FILEATTACHMENT', $attrs );
  
  if (!$status) { 
    # no error occured and we are not already redirected
  
    $msg = "Attachment $name uploaded to topic";
    $status = 1;
  
    #
    # redirect
    #
    my $redirecturl = TWiki::Func::getViewUrl( $web, $topic );
    $redirecturl .= "?remotefileattach=1&name=$name";
    TWiki::Func::redirectCgiQuery(undef, $redirecturl, 0 );
  
  }
  
  # Error occured, or we didn't redirect.
  # Error (or success) message will be displayed by %REMOTEFILEATTACH_MSG%
  return "";

}

sub downloadFile {
  
  my ($url, $name) = @_;
  
  eval { require LWP::Simple; };
  if ($@) {
     $msg = "RemoteFileAttachPlugin: Error: Can't load required module LWP::Simple. ".
            "Please contact your administrator.";
     $status = 1;
     return;
  }

  my $content = LWP::Simple::get($url);
  if (!defined($content)) {
    $status = 1;
    $msg ="RemoteFileAttachPlugin: Error: could not download $url";
    return;
  }
  
  my $workdir =  TWiki::Func::getWorkArea("RemoteFileAttachPlugin");
  
  # We don't use TWiki::Func::saveFile to keep it working on windows
  unless ( open( FILE, ">$workdir/$name$$" ) )  {
        $msg = "RemoteFileAttachPlugin: Error: RemoteFileAttachPlugin: Can't create temporary file $name - $!. ".
               "This looks like an configuration error.";
        $status = 1;
        return;
  }
  binmode(FILE); # again, windows
  print FILE $content;
  my $filesize = (stat FILE)[7];
  close( FILE);
  
  TWiki::Func::saveAttachment( $web, $topic, $name, 
          { file => $workdir."/".$name.$$, 
            filepath => $name,
            comment => '',
            hide => 0,
            filedate => time(),
            filesize => $filesize
          } );
  
  if (!unlink($workdir."/".$name.$$)) {
    $msg = "RemoteFileAttachPlugin: Error: Could not remove temporary file: $!. ".
           "This looks like an configuration error.";
    $status = 1;
  }
  
}

1;
