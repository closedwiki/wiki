# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006 Michael Daum http://wikiring.com
# Portions Copyright (C) 2006 Spanlink Communications
# Copyright (C) 2007-2011 TWiki:TWiki.TWikiContributor
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
use TWiki::Contrib::LdapContrib;

sub DEBUG { 0; } # toggle me

###############################################################################
sub writeDebug {
  # comment me in/out
  &TWiki::Func::writeDebug('- LdapNgPlugin - '.$_[0]);
  #print STDERR 'LdapNgPlugin - '.$_[0]."\n";
}

###############################################################################
sub handleLdap {
  my ($session, $params, $topic, $web) = @_;

  writeDebug("called handleLdap($web, $topic)") if DEBUG;

  my $query = &TWiki::Func::getCgiQuery();

  # get args
  my $theFilter = $params->{'filter'} || $params->{_DEFAULT} || '';
  my $theBase = $params->{'base'} || $TWiki::cfg{Ldap}{Base} || '';
  my $theScope = $params->{scope} || 'sub';
  my $theFormat = $params->{format} || '$dn';
  my $theHeader = $params->{header} || ''; 
  my $theFooter = $params->{footer} || '';
  my $theSep = TWiki::Func::decodeFormatTokens(
      $params->{sep} || $params->{separator} || '$n');
  my $theSort = $params->{sort} || '';
  my $theReverse = TWiki::Func::isTrue($params->{reverse}, 0);
  my $theLimit = $params->{limit} || 0;
  my $theSkip = $params->{skip} || 0;
  my $theHideNull = TWiki::Func::isTrue($params->{hidenull}, 0);
  my $theClear = $params->{clear} || '';
  my $theRefresh = TWiki::Func::isTrue($query->param('refresh'), 0);
  my $theIfNull = $params->{ifnull};
  $theIfNull = '' unless ( defined($theIfNull) );
  my $theRequired = $params->{required};
  $theRequired = '' unless ( defined($theRequired) );


  # fix args
  $theSkip =~ s/[^\d]//go;
  $theLimit =~ s/[^\d]//go;
  my @theSort = split(/[\s,]+/, $theSort);
  $theBase = $1.','.$TWiki::cfg{Ldap}{Base} if $theBase =~ /^\((.*)\)$/;
  #writeDebug("base=$theBase") if DEBUG;
  writeDebug("format=$theFormat") if DEBUG;

  my $ldap;
  if ( $TWiki::cfg{Plugins}{LdapNgPlugin}{UseDefaultServer} ) {
    $ldap = &TWiki::Contrib::LdapContrib::getLdapContrib($session);
  }
  else {
    my $theHost = $params->{'host'} || $TWiki::cfg{Ldap}{Host} || 'localhost';
    my $thePort = $params->{'port'} || $TWiki::cfg{Ldap}{Port} || '389';
    my $theVersion = $params->{version} || $TWiki::cfg{Ldap}{Version} || 3;
    my $theSSL = $params->{ssl} || $TWiki::cfg{Ldap}{SSL} || 0;
    # new connection
    $ldap = new TWiki::Contrib::LdapContrib(
      $session,
      base=>$theBase,
      host=>$theHost,
      port=>$thePort,
      version=>$theVersion,
      ssl=>$theSSL,
    );
  }

  my (@entries, $count);
  # calling helper if exists
  my $helperResult;
  my $entriesSet;
  if ( my $helper = $TWiki::cfg{Plugins}{LdapNgPlugin}{Helper} ) {
    eval "require $helper";
    if ( $@ ) {
      return inlineError($@);
    }
    else {
      $helperResult = $helper->lookupHelper(
        $ldap, $theFilter,
        {
          scope   => $theScope,
          skip    => $theSkip,
          limit   => $theLimit,
          sort    => \@theSort,
          reverse => $theReverse,
        }
      );
      if ( ref $helperResult ) {
        return $theIfNull if ( @$helperResult == 0 && $theHideNull );
        $count = @entries = @$helperResult;
        $entriesSet = 1;
      }
      else {
        if ( $helperResult =~ /^=(.*)$/ ) {
          return inlineError($1);
        }
        else {
          $theFilter = $helperResult;
        }
      }
    }
  }
  # search 
  unless ( $entriesSet ) {
    my $search = $ldap->search(
      filter=>$theFilter, 
      base=>$theBase, 
      scope=>$theScope, 
      limit=>$theReverse ? 0 : $theLimit
    );
    unless (defined $search) {
      return &inlineError('ERROR: '.$ldap->getError());
    }

    $count = $search->count();
    return $theIfNull if ($count <= $theSkip) && $theHideNull;

    @entries = $search->sorted(@theSort);
  }
  # format
  @entries = reverse @entries if $theReverse;
  my @results;
  my @reqs;
  @reqs = grep { $_ ne '' } split(/[,\s]+/, $theRequired);
  my $index = 0;
  foreach my $entry (@entries) {
    $index++;
    next if $index <= $theSkip;
    my %data;
    $data{dn} = $entry->dn();
    $data{index} = $index;
    $data{count} = $count;
    foreach my $attr ($entry->attributes()) {
      if ( $TWiki::cfg{Plugins}{LdapNgPlugin}{CacheBlob} &&
           $attr =~ /jpegPhoto/
      ) {
	$data{$attr} = $ldap->cacheBlob($entry, $attr, $theRefresh);
      } else {
	$data{$attr} = $entry->get_value($attr, asref=>1);
      }
    }
    my $ok = 1;
    for my $i ( @reqs ) {
        unless ( defined $data{$i} ) {
            $ok = 0;
            last;
        }
    }
    next unless ( $ok );
    push(@results, expandVars($theFormat, %data));
    last if $index == $theLimit;
  }
  $ldap->finish()
      unless ( $TWiki::cfg{Plugins}{LdapNgPlugin}{UseDefaultServer} );
  my $result = @results ? join($theSep, @results) : $theIfNull;

  $theHeader = expandVars($theHeader,count=>$count) if $theHeader;
  $theFooter = expandVars($theFooter,count=>$count) if $theFooter;

  #$result = $session->UTF82SiteCharSet($result) || $result;
  unless ( $TWiki::cfg{Site}{CharSet} =~ /^utf-?8$/i ) {
    if ( $] >= 5.008 ) {
      require Encode;
      import Encode qw(:fallbacks);
      my $charEncoding = Encode::resolve_alias( $TWiki::cfg{Site}{CharSet} );
      if( not $charEncoding ) {
        TWiki::Func::writeWarning( 'Conversion to "'.$TWiki::cfg{Site}{CharSet}.
                  '" not supported, or name not recognised - check '.
                  '"perldoc Encode::Supported"' );
      }
      else {
        $result = Encode::encode( $charEncoding, $result, &FB_PERLQQ() );
      }
    }
    else {
      require Unicode::MapUTF8;
      $result = Unicode::MapUTF8::from_utf8(-string => $result,
                                        -charset => $TWiki::cfg{Site}{CharSet});
    }
  }
  if ($theClear) {
    $theClear =~ s/\$/\\\$/g;
    my $regex = join('|',split(/[\s,]+/,$theClear));
    $result =~ s/$regex//g;
  }

  $result = $theHeader . $result . $theFooter;

  writeDebug("done handleLdap()") if DEBUG;
  writeDebug("result=$result") if DEBUG;

  return $result;
}

###############################################################################
sub handleLdapUsers {
  my ($session, $params, $topic, $web) = @_;

  writeDebug("called handleLdapUsers($web, $topic)") if DEBUG;

  my $ldap = TWiki::Contrib::LdapContrib::getLdapContrib($session);
  my $theHeader = $params->{header} || ''; 
  my $theFormat = $params->{format} || '   1 $displayName';
  my $theFooter = $params->{footer} || '';
  my $theSep = $params->{sep} || '$n';
  my $theLimit = $params->{limit} || 0;
  my $theSkip = $params->{skip} || 0;
  my $theInclude = $params->{include};
  my $theExclude = $params->{exclude};
  my $theHideUnknownUsers = $params->{hideunknown} || 'on';
  $theHideUnknownUsers = ($theHideUnknownUsers eq 'on')?1:0;

  my $mainWeb = TWiki::Func::getMainWebname();
  my $wikiNames = $ldap->getAllWikiNames();
  my $result = '';
  $theSkip =~ s/[^\d]//go;
  $theLimit =~ s/[^\d]//go;

  my $index = 0;
  foreach my $wikiName (sort @$wikiNames) {
    next if $theExclude && $wikiName =~ /$theExclude/;
    next if $theInclude && $wikiName !~ /$theInclude/;
    $index++;
    next if $index <= $theSkip;
    my $loginName = $ldap->getLoginOfWikiName($wikiName);
    my $emailAddrs = $ldap->getEmails($loginName);
    my $displayName;
    if (TWiki::Func::topicExists($mainWeb, $wikiName)) {
      $displayName = "[[$mainWeb.$wikiName][$wikiName]]";
    } else {
      next if $theHideUnknownUsers;
      $displayName ="<nop>$wikiName";
    }
    my $line;
    $line = $theSep if $result;
    $line .= $theFormat;
    $line = expandVars($line,
      index=>$index,
      wikiName=>$wikiName,
      displayName=>$displayName,
      loginName=>$loginName,
      emails=>$emailAddrs);
    $result .= $line;
    last if $index == $theLimit;
  }

  return expandVars($theHeader).$result.expandVars($theFooter);
}

###############################################################################
sub inlineError {
  return "<div class=\"twikiAlert\">$_[0]</div>";
}

###############################################################################
sub expandVars {
  my ($format, %data) = @_;

  #writeDebug("called expandVars($format, '".join(',',keys %data).")") if DEBUG;

  foreach my $key (keys %data) {
    my $value = $data{$key};
    next unless $value;
    $value = join(', ', sort @$value) if ref($value) eq 'ARRAY';

    # Format list values using the '$' delimiter in multiple lines; see rfc4517
    $value =~ s/([^\\])\$/$1<br \/>/go; 
    $value =~ s/\\\$/\$/go;
    $value =~ s/\\\\/\\/go;

    $format =~ s/\$$key\b/$value/gi;
    #writeDebug("$key=$value") if DEBUG;
  }

  $format =~ s/\n/<br \/>/go; # multi-line values, e.g. for postalAddress

  $format = TWiki::Func::decodeFormatTokens($format);

  #writeDebug("done expandVars()") if DEBUG;
  return $format;
}

1;
