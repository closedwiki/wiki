# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 Aleksandar Erkalovic, aerkalov@gmail.com
# Copyright (C) 2008-2011 TWiki Contributors
# All Rights Reserved. TWiki Contributors are listed in the
# AUTHORS file in the root of this distribution.
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
# For licensing info read LICENSE file in the TWiki root.

package TWiki::Plugins::CopyrightPlugin;

use strict;

use TWiki::Func;
use List::Compare::Functional qw( get_unique );

use vars qw(
  $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName
  $NO_PREFS_IN_TOPIC $usersPreferences $topicsPreferences
);

$VERSION = '$Rev$';
$RELEASE = '2011-03-05';

$SHORTDESCRIPTION = 'List copyright information based on topic authors';
$NO_PREFS_IN_TOPIC = 0;

$pluginName = 'CopyrightPlugin';

#=======================================================
sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }

    $usersPreferences  = TWiki::Func::getPreferencesValue( "COPYRIGHTPLUGIN_USERSEXCLUDE" ) || '';
    $topicsPreferences = TWiki::Func::getPreferencesValue( "COPYRIGHTPLUGIN_TOPICSEXCLUDE") || '';

    TWiki::Func::registerTagHandler( 'AUTHORS', \&_AUTHORSTAG );

    # Plugin correctly initialized
    return 1;
}

#=======================================================
sub _getMetaInfo {
  my ($meta, $key) = @_;

  my $authordata = $meta->get("FIELD", $key);

  if(defined $authordata) {
    my %author_data = %$authordata;

    return $author_data{"value"};
  }

  return undef;
}

#=======================================================
sub _getAuthorFullName {
  my ($authorName) = @_;

  my ($authorMeta, $authorText)  = TWiki::Func::readTopic("Main", $authorName);

  if(defined _getMetaInfo($authorMeta, "FirstName") && defined _getMetaInfo($authorMeta, "LastName")) {
    return _getMetaInfo($authorMeta, "FirstName"). "  "._getMetaInfo($authorMeta, "LastName");
  }

  return $authorName;
}

#=======================================================
sub _getReferencesTo {
 my ($theWeb, $theTopic) = @_;

 my ($pageMeta, $pageText) = TWiki::Func::readTopic($theWeb, $theTopic);

 if($pageText =~ /%INCLUDE\{(.+)\.(.+)}%/) {
     return ($1, $2);
 }

 return ($theWeb, $theTopic);
}

#=======================================================
sub _AUTHORSTAG {
    my($session, $params, $theTopic, $theWeb) = @_;

    my @usersExclude  = split( /, */, $usersPreferences );
    my @topicsExclude = split( /, */, $topicsPreferences );
   
    my @topics;
    my %fullTopics;

    my $showInfo    = $params->{show} || "full";
    my $out = "";
    
    if(defined $params->{topics}) {
        @topics = split(/,/,$params->{topics}); 
    } elsif(defined $params->{toc}) {
        if(TWiki::Func::topicExists($theWeb, "_index")) {
           if(TWiki::Func::attachmentExists($theWeb, "_index", "TOC.txt")) {
	            my $attdata = TWiki::Func::readAttachment($theWeb, "_index", "TOC.txt");
		    my @lines = split /\n/, $attdata;
		    for(my $i = 0; $i < (@lines/3); $i++) {
		       if($lines[$i*3] eq "1") {
		           push @topics, $lines[$i*3+1];
		           $fullTopics{$lines[$i*3+1]} = $lines[$i*3+2];
		       }
		    }
           }
	}
    } else {
        @topics = TWiki::Func::getTopicList($theWeb);
    }

    my @topicList = get_unique({lists => [\@topics, \@topicsExclude]});

    foreach  my $topicName (sort { $a cmp $b } @topicList) {
      my %authorsDictionary;
      my $webName = $theWeb;

      if($topicName =~ /(.+)\:(.+)/) {
         $webName   = $1;
         $topicName = $2;
      }

      my ($realWeb, $realTopic) = _getReferencesTo($webName, $topicName);

      my $maxRevision = $params->{rev} || (&TWiki::Func::getRevisionInfo($realWeb, $realTopic))[2];
      $maxRevision =~ s/^\d\.(\d*)$/$1/;

      my $author;

      for (my $revision = $maxRevision; $revision > 0; $revision--) {
	my @lines = TWiki::Func::getRevisionInfo($realWeb, $realTopic, $revision);
	
	for (my $lineIndex = 0; $lineIndex < $#lines; $lineIndex += 4) {
	  my $date = &TWiki::Func::formatTime($lines[$lineIndex+0], '$year');
	
	  $author            = $lines[$lineIndex+1];
	  my $revisionNumber = $lines[$lineIndex+2];
	  my $comment        = $lines[$lineIndex+3];		

	  ## do i want to ignore specific user maybe?
	
	  if(exists $authorsDictionary{$author}) {
	    $authorsDictionary{"$author"}->{"$date"} = 1;
	  } else {
	    $authorsDictionary{"$author"} = {"$date" => 1};
	  }
	}
      }

      my @al = sort { $a cmp $b } keys %authorsDictionary;

      my @authorsList = get_unique([\@al, \@usersExclude]);

      if($showInfo eq "full") {
          if(exists $fullTopics{$topicName}) {
	     $out .= "<i>".$fullTopics{$topicName}."</i><br />";
	  } else {
              $out .= "<i>$topicName</i><br />";
	  } 
      } 

      my @sorted = sort { $a <=> $b } keys %{$authorsDictionary{$author}}; 

      if($showInfo ne "modifiers") {
          $out .= "&copy; "._getAuthorFullName($author)." ".join(", ", @sorted);
      }

      if($showInfo ne "holder") {
          my $outModification = "";

          foreach $a (@authorsList) {
    	      if($a ne $author) {
	          my @sorted = sort { $a <=> $b } keys %{$authorsDictionary{$a}}; 
	
	          $outModification .= _getAuthorFullName($a)." ";
	          $outModification .= join(", ", @sorted);
	          $outModification .= "<br />";
	      }
          }

          if($outModification ne "") {
	      if($showInfo ne "modifiers") {
                  $out .= "<br />Modifications:<br />";
          }
              $out .= $outModification;
          }
      
          $out .= "<hr />";
      }
    }

    return $out;
}

#=======================================================
1;
