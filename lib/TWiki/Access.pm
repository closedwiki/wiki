#
# TWiki WikiClone (see wiki.pm for $wikiversion and other info)
#
# Copyright (C) 2000 Peter Thoeny, Peter@Thoeny.com
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
#
# Notes:
# - Latest version at http://twiki.org/
# - Installation instructions in $dataDir/TWiki/TWikiDocumentation.txt
# - Customize variables in wikicfg.pm when installing TWiki.
# - Optionally change wikicfg.pm for custom extensions of rendering rules.
# - Files wiki[a-z]+.pm are included by wiki.pm
# - Upgrading TWiki is easy as long as you only customize wikicfg.pm.
# - Check web server error logs for errors, i.e. % tail /var/log/httpd/error_log

package TWiki::Access;

use strict;

use vars qw(
    %allGroups @processedGroups
);

# =========================
sub initializeAccess
{
    %allGroups = ();
    @processedGroups = ();
}

# =========================
sub checkAccessPermission
{
    my( $theAccessType, $theUserName,
        $theTopicText, $theTopicName, $theWebName ) = @_;

#AS 2001-11-04 see Codev.UnchangeableTopicBug
    if ( $TWiki::doSuperAdminGroup && 
	 $TWiki::superAdminGroup ) {
	if ( &userIsInGroup( $theUserName, $TWiki::superAdminGroup ) ) {
	    return 1;
	}
    }
#/AS

    # $theAccessType  "VIEW", "CHANGE", "CREATE", e.t.c.
    # $theUserName    Remote WikiName, i.e. "Main.PeterThoeny"
    # $theTopicText   If empty: Read "$theWebName.$theTopicName"
    # $theTopicName   Topic name to check, i.e. "SomeTopic"
    # $theWebName     Web, i.e. "Know"

    $theAccessType = uc( $theAccessType );  # upper case
    if( ! $theWebName ) {
        $theWebName = $TWiki::webName;
    }
    if( ! $theTopicText ) {
        # text not supplied as parameter, so read topic
        $theTopicText = &TWiki::Store::readWebTopic( $theWebName, $theTopicName );
    }
    ##&TWiki::writeDebug( "checkAccessPermission: Type $theAccessType, user $theUserName, topic $theTopicName" );

    # parse the " * Set (ALLOWTOPIC|DENYTOPIC)$theAccessType = " in body text
    my @denyList = ();
    my @allowList = ();
    foreach( split( /\n/, $theTopicText ) ) {
        if( /^\s+\*\sSet\s(ALLOWTOPIC|DENYTOPIC)$theAccessType\s*\=\s*(.*)/ ) {
            if( $2 ) {
                my $allowOrDeny = $1;        # "ALLOWTOPIC" or "DENYTOPIC"
                my @tmpList = map { getUsersOfGroup( $_ ) }
                              prvGetUserList( $2 );
                ##my $tmp = join( ', ', @tmpList );
                ##&TWiki::writeDebug( "  Topic $allowOrDeny$theAccessType: {$tmp}" );
                if( $allowOrDeny eq "DENYTOPIC" ) {
                    @denyList = @tmpList;
                } else {
                    @allowList = @tmpList;
                }
            }
        }
    }

    # if empty, get access permissions from preferences
    if( ! @denyList ) {
        my $tmpVal = &TWiki::Prefs::getPreferencesValue( "DENYWEB$theAccessType" );
        @denyList  = map { getUsersOfGroup( $_ ) }
                     prvGetUserList( $tmpVal );
        ##my $tmp = join( ', ', @denyList );
        ##&TWiki::writeDebug( "  Prefs DENYWEB$theAccessType: {$tmp}" );
    }
    if( ! @allowList ) {
        my $tmpVal = &TWiki::Prefs::getPreferencesValue( "ALLOWWEB$theAccessType" );
        @allowList  = map { getUsersOfGroup( $_ ) }
                      prvGetUserList( $tmpVal );
        ##my $tmp = join( ', ', @allowList );
        ##&TWiki::writeDebug( "  Prefs ALLOWWEB$theAccessType: {$tmp}" );
    }

    # access permission logic
    if( @denyList ) {
        if( grep { /^$theUserName$/ } @denyList  ) {
            # user is on deny list
            ##&TWiki::writeDebug( "  return 0, user is on deny list" );
            return 0;
        }
    }
    if( @allowList ) {
        if( grep { /^$theUserName$/ } @allowList  ) {
            # user is on allow list
            ##&TWiki::writeDebug( "  return 1, user is on allow list" );
            return 1;
        } else {
            # user is not on allow list
            ##&TWiki::writeDebug( "  return 0, user is not on allow list" );
            return 0;
        }
    }
    # allow is undefined, so grant access
    ##&TWiki::writeDebug( "  return 1, allow is undefined" );
    return 1;
}

# =========================
sub userIsInGroup
{
    my( $theUserName, $theGroupTopicName ) = @_;

    my $usrTopic = prvGetWebTopicName( $TWiki::mainWebname, $theUserName );
    my $grpTopic = prvGetWebTopicName( $TWiki::mainWebname, $theGroupTopicName );
    my @grpMembers = ();

    if( $grpTopic !~ /.*Group$/ ) {
        # not a group, so compare user to user
        push( @grpMembers, $grpTopic );
    } elsif( ( %allGroups ) && ( exists $allGroups{ $grpTopic } ) ) {
        # group is allready known
        @grpMembers = @{ $allGroups{ $grpTopic } };
    } else {
        @grpMembers = prvGetUsersOfGroup( $grpTopic, 1 );
    }

    my $isInGroup = grep { /^$usrTopic$/ } @grpMembers;
    return $isInGroup;
}

# =========================
sub getUsersOfGroup
{
    my( $theGroupTopicName ) = @_;
    return prvGetUsersOfGroup( $theGroupTopicName, 1 );
}

# =========================
sub prvGetUsersOfGroup
{
    my( $theGroupTopicName, $theFirstCall ) = @_;

    my @resultList = ();
    # extract web and topic name
    my $topic = $theGroupTopicName;
    my $web = $TWiki::mainWebname;
    $topic =~ /^([^\.]*)\.(.*)$/;
    if( $2 ) {
        $topic = $2;
        $web = $1;
    }

    if( $topic !~ /.*Group$/ ) {
        # return user, is not a group
        return ( "$web.$topic" );
    }

    # check if group topic is already processed
    if( $theFirstCall ) {
        @processedGroups = ();
    } elsif( grep { /^$web\.$topic$/ } @processedGroups ) {
        # do nothing, already processed
        return ();
    }
    push( @processedGroups, "$web\.$topic" );

    # read topic
    my $text = &TWiki::Store::readWebTopic( $web, $topic );

    # reset variables, defensive coding needed for recursion
    (my $baz = "foo") =~ s/foo//;

    # extract users
    my $user = "";
    my @glist = ();
    foreach( split( /\n/, $text ) ) {
        if( /^\s+\*\sSet\sGROUP\s*\=\s*(.*)/ ) {
            if( $1 ) {
                @glist = prvGetUserList( $1 );
            }
        }
    }
    foreach( @glist ) {
        if( /.*Group$/ ) {
            # $user is actually a group
            my $group = $_;
            if( ( %allGroups ) && ( exists $allGroups{ $group } ) ) {
                # allready known, so add to list
                push( @resultList, @{ $allGroups{ $group } } );
            } else {
                # call recursively
                my @userList = prvGetUsersOfGroup( $group, 0 );
                # add group to allGroups hash
                $allGroups{ $group } = [ @userList ];
                push( @resultList, @userList );
            }
        } else {
            # add user to list
            push( @resultList, $_ );
        }
    }
    return @resultList;
}

# =========================
sub prvGetWebTopicName
{
    my( $theWebName, $theTopicName ) = @_;
    $theTopicName =~ s/%MAINWEB%/$theWebName/go;
    $theTopicName =~ s/%TWIKIWEB%/$theWebName/go;
    if( $theTopicName =~ /[\.]/ ) {
        $theWebName = "";  # to suppress warning
    } else {
        $theTopicName = "$theWebName\.$theTopicName";
    }
    return $theTopicName;
}

# =========================
sub prvGetUserList
{
    my( $theItems ) = @_;
    # comma delimited list of users or groups
    # i.e.: "%MAINWEB%.UserA, UserB, Main.UserC  # something else"
    $theItems =~ s/(<[^>]*>)//go;     # Remove HTML tags
    $theItems =~ s/\s*([a-zA-Z0-9_\.\,\s\%]*)\s*(.*)/$1/go; # Limit list
    my @list = map { prvGetWebTopicName( $TWiki::mainWebname, $_ ) }
               split( /[\,\s]+/, $theItems );
    return @list;
}

# =========================

1;

# EOF

