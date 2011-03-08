###############################################################################
# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2008 Wolf Marbach http://comcon.co.nz
#
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
#
# 
#
###############################################################################

package TWiki::Plugins::ShowAccessPlugin;


use strict;





###############################################################################
use vars qw(
        $currentWeb $currentTopic 
        $currentUser $VERSION $RELEASE $pluginName 
	$NO_PREFS_IN_TOPIC $SHORTDESCRIPTION
    );

$VERSION = '$Rev: 17676 (22 Oct 2008) $';
$RELEASE = 'v1.00';
$NO_PREFS_IN_TOPIC = 1;
$SHORTDESCRIPTION = 'Read and Show accessrights of topics';
$pluginName = 'ShowAccessPlugin';

###############################################################################
sub initPlugin {
  ($currentTopic, $currentWeb, $currentUser) = @_;

  if( $TWiki::Plugins::VERSION < 1.2 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
  }

  my $query = TWiki::Func::getCgiQuery();
  return unless $query;


  TWiki::Func::registerTagHandler('SHOWACCESS', \&handleShowaccess);
  TWiki::Func::registerTagHandler('READACCESS', \&handleReadaccess);


  return 1;
}

###############################################################################

sub handleShowaccess {

   my( $session, $params ) = @_;
  
   my $type = $params->{_DEFAULT} || $params->{type} || 'view';
   my $user = $params->{user} || $currentUser;
   my $topic = $params->{topic} || $currentTopic;
   my $web = $params->{web} || $currentWeb;

   my $result = '';

   return "%RED%Topic does not exist!%ENDCOLOR%"."\n" unless (TWiki::Func::topicExists($web,$topic));
   return "%RED%User does not exist!%ENDCOLOR%"."\n" unless (isValidUser($user));
   return "%RED%Type does not exist!%ENDCOLOR%"."\n" unless ($type eq "view" || $type eq "change");

   my ($meta, $text) = TWiki::Func::readTopic($web, $topic);

   unless (TWiki::Func::checkAccessPermission('view', $currentUser, $text, $topic, $web, $meta)){
      return "%RED%No access to view!%ENDCOLOR%\n";
   }
     
   my $hasAccessView = TWiki::Func::checkAccessPermission('view', $user, $text, $topic, $web, $meta);
   my $hasAccessChange = TWiki::Func::checkAccessPermission('change', $user, $text, $topic, $web, $meta);

   my $styleyes = '<p style="color:blue;font-weight:bold">';
   my $styleno = '<p style="color:red;font-weight:bold">';
   my $endstyle = "</p>";



   if ($type eq 'change') {
      if ($hasAccessChange && $hasAccessView) {
         $result = $styleyes."YES".$endstyle;
      } else {
         $result = $styleno."NO".$endstyle;
      }
   }
   if ($type eq 'view') {
      if ($hasAccessView) {
         $result = $styleyes."YES".$endstyle;
      } else {
         $result = $styleno."NO".$endstyle;
      }
   }
 
 
   return $result;

}

###############################################################################

sub handleReadaccess {

   my( $session, $params ) = @_;
  
   my $topic = $params->{_DEFAULT} || $params->{topic} || $currentTopic;
   my $web = $params->{web} || $currentWeb;
   my $sep = $params->{sep} || "\n<br>";


   my $access;
   my @accesslist;
   my @denylist;

   
   
   
   
   my @denytopiclist = fetchAccesslist('topic', $web, $topic,'DENYTOPICVIEW' );
   my @allowtopiclist = fetchAccesslist('topic', $web, $topic,'ALLOWTOPICVIEW' );
   my @denyweblist = fetchAccesslist('web', $web, $topic,'DENYWEBVIEW' );
   my @allowweblist = fetchAccesslist('web', $web, $topic,'ALLOWWEBVIEW' );

   if (@allowtopiclist > 0) {
      foreach my $ite (@allowtopiclist) {
         push(@accesslist, $ite) unless (grep(/$ite/, @denytopiclist));
      }
      push(@denylist, @denytopiclist);

   } elsif (@allowweblist > 0) {
      foreach my $ite (@allowweblist) {
         push(@accesslist, $ite) unless (grep(/$ite/, @denyweblist));
      }
      push(@denylist, @denyweblist);
   } else {
      push(@denylist, @denyweblist, @denytopiclist);
   }
   
   if (@accesslist) {
      $access = "Main.";
      $access .= join($sep." %USERSWEB%.", sort(@accesslist)).$sep;
   } elsif (!@denylist) {
      $access = "ALL".$sep;
   }
   if (!@accesslist && @denylist) {
      $access .= "ALL".$sep."but not: ".$sep." %USERSWEB%.".join($sep." %USERSWEB%.", sort(@denylist)).$sep;
   }

 
  return $access;

}
###############################################################################
sub fetchAccesslist {

   my ($type, $web, $topic, $var )= @_;
   
   my $string;
   my $member;
   my @list;   
   my @resultlist;
   my @grouplist;
   my $ite2;

   if ($type eq 'topic') {
      $string = $TWiki::Plugins::SESSION->{prefs}->getTopicPreferencesValue($var, $web, $topic );
   } else {
      $string = TWiki::Func::getPreferencesValue($var,$web);
   }

   $string =~ s/ //g;
   @list = split(",", $string);
   foreach my $ite (@list) {
      $member = TWiki::Func::getWikiName($ite);
      unless (grep(/$member/, @resultlist)) {
         if (TWiki::Func::isGroup($member)) {
            $ite2 = TWiki::Func::eachGroupMember($member);
            while ( $ite2->hasNext() ) {
               my $groupuser = $ite2->next();
               push (@grouplist, $groupuser) if (isValidUser($groupuser));
            }
            foreach $ite2 (@grouplist) {
               push(@resultlist, $ite2) unless (grep(/$ite2/, @resultlist)) ;
            }
         } else {
            push(@resultlist, $member) if (isValidUser($member));
         }
      }
   }

  return @resultlist;

}

###############################################################################

sub isValidUser {

   my $checkuser = $_[0];

   return 1 if ($checkuser eq $currentUser);

   $checkuser = TWiki::Func::getWikiName($checkuser);

   my $text = TWiki::Func::readTopicText($TWiki::cfg{UsersWebName},$TWiki::cfg{UsersTopicName});

   return 1 if ($text =~ /$checkuser/ );
  
   my $group = grep( /$checkuser/i , TWiki::Func::getTopicList($TWiki::cfg{UsersWebName}));

   return 1 if ($group > 0);
   
   return 0;

}

###############################################################################

1;
