# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Michael Daum http://wikiring.com
# Portions Copyright (C) 2006 Spanlink Communications
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

package TWiki::Plugins::LdapNgPlugin::Core;

use strict;
use vars qw($ldap);

use TWiki::Contrib::LdapContrib;

###############################################################################
sub writeDebug {
  # comment me in/out
  #&TWiki::Func::writeDebug('- LdapNgPlugin - '.$_[0]);
}

###############################################################################
sub handleLdap {
  my ($web, $topic, $args) = @_;

  writeDebug("called handleLdap($web, $topic, $args)");

  # get args
  my $theFilter = &TWiki::Func::extractNameValuePair($args) ||
		  &TWiki::Func::extractNameValuePair($args, 'filter') || '';
  my $theBase = &TWiki::Func::extractNameValuePair($args, 'base') || $TWiki::cfg{Ldap}{Base} || '';
  my $theHost = &TWiki::Func::extractNameValuePair($args, 'host') || $TWiki::cfg{Ldap}{Host} || 'localhost';
  my $thePort = &TWiki::Func::extractNameValuePair($args, 'host') || $TWiki::cfg{Ldap}{Port} || '389';
  my $theVersion = &TWiki::Func::extractNameValuePair($args, 'version') || $TWiki::cfg{Ldap}{Version} || 3;
  my $theSSL = &TWiki::Func::extractNameValuePair($args, 'ssl') || $TWiki::cfg{Ldap}{SSL} || 0;
  my $theScope = &TWiki::Func::extractNameValuePair($args, 'scope') || 'sub';
  my $theFormat = &TWiki::Func::extractNameValuePair($args, 'format') || '$dn';
  my $theHeader = &TWiki::Func::extractNameValuePair($args, 'header') || '';
  my $theFooter = &TWiki::Func::extractNameValuePair($args, 'footer') || '';
  my $theSep = &TWiki::Func::extractNameValuePair($args, 'sep') || '$n';
  my $theSort = &TWiki::Func::extractNameValuePair($args, 'sort') || '';
  my $theReverse = &TWiki::Func::extractNameValuePair($args, 'reverse') || 'off';
  my $theLimit = &TWiki::Func::extractNameValuePair($args, 'limit') || 0;
  my $theSkip = &TWiki::Func::extractNameValuePair($args, 'skip') || 0;
  my $theHideNull = &TWiki::Func::extractNameValuePair($args, 'hidenull') || 'off';

  my $query = &TWiki::Func::getCgiQuery();
  my $theRefresh = $query->param('refresh') || 0;
  $theRefresh = ($theRefresh eq 'on')?1:0;

  # fix args
  $theSkip =~ s/[^\d]//go;
  $theLimit =~ s/[^\d]//go;
  my @theSort = split(/[\s,]+/, $theSort);
  $theBase = $1.','.$TWiki::cfg{Ldap}{Base} if $theBase =~ /^\((.*)\)$/;
  #writeDebug("base=$theBase");

  # new connection
  $ldap->disconnect() if $ldap;
  $ldap = new TWiki::Contrib::LdapContrib(
    base=>$theBase,
    host=>$theHost,
    port=>$thePort,
    version=>$theVersion,
    ssl=>$theSSL,
  );

  # search 
  my $search = $ldap->search($theFilter, $theBase, $theScope, 
    ($theReverse eq 'on')?0:$theLimit);
  unless (defined $search) {
    return &inlineError('ERROR: '.$ldap->getError());
  }

  my $count = $search->count();
  return '' if ($count <= $theSkip) && $theHideNull eq 'on';

  # format
  my $result = '';
  my @entries = $search->sorted(@theSort);
  @entries = reverse @entries if $theReverse eq 'on';
  my $index = 0;
  foreach my $entry (@entries) {
    $index++;
    next if $index <= $theSkip;
    my %data;
    $data{dn} = $entry->dn();
    $data{index} = $index;
    $data{count} = $count;
    foreach my $attr ($entry->attributes()) {
      if ($attr =~ /jpegPhoto/) { # TODO make blobs configurable 
	$data{$attr} = $ldap->cacheBlob($entry, $attr, $theRefresh);
      } else {
	$data{$attr} = $entry->get_value($attr, asref=>1);
      }
    }
    my $text = '';
    $text .= $theSep if $result;
    $text .= $theFormat;
    $text = expandVars($text, %data);
    $result .= $text;
    last if $index == $theLimit;
  }
  $theHeader = expandVars($theHeader.$theSep,count=>$count) if $theHeader;
  $theFooter = expandVars($theSep.$theFooter,count=>$count) if $theFooter;

  $result = &TWiki::Func::expandCommonVariables("$theHeader$result$theFooter", 
    $topic, $web);

  # cleanup leftovers
  $result =~ s/\$[\S]+\b//go;

  writeDebug("done handleLdap()");
  #writeDebug("result=$result");

  return $result;
}

###############################################################################
sub afterCommonTagsHandler {
  $ldap->disconnect() if $ldap;
}

###############################################################################
sub inlineError {
  return "<div class=\"twikiAlert\">$_[0]</div>";
}

###############################################################################
sub expandVars {
  my ($format, %data) = @_;

  #writeDebug("called expandVars($format, '".join(',',keys %data));

  foreach my $key (keys %data) {
    my $value = $data{$key};
    if ($data{$key} =~ /^ARRAY/) {
      $value = join(', ', sort @$value);
    }
    $format =~ s/\$$key/$value/g;
    #writeDebug("$key=$value");
  }

  $format =~ s/\$n/\n/go;
  $format =~ s/\$quot/\"/go;
  $format =~ s/\$percnt/\%/go;
  $format =~ s/\$dollar/\$/go;
  $format =~ s/\\/\//go;

  #writeDebug("done expandVars()");
  return $format;
}

1;
