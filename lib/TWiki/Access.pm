# Module of TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2004 Peter Thoeny, peter@thoeny.com
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
#
# Notes:
# - Latest version at http://twiki.org/
# - Installation instructions in $dataDir/TWiki/TWikiDocumentation.txt
# - Customize variables in wikicfg.pm when installing TWiki.
# - Optionally change wikicfg.pm for custom extensions of rendering rules.
# - Upgrading TWiki is easy as long as you only customize wikicfg.pm.
# - Check web server error logs for errors, i.e. % tail /var/log/httpd/error_log

=begin twiki

---+ TWiki::Access Package

This package manages access control to view and change topics. Plugins
should only use the equivalent interface in TWiki::Func.

=cut

package TWiki::Access;

use strict;

# hash (indexed on group name) of hashes (indexed on users)
use vars qw( %allGroups );

=pod

---++ initializeAccess()
Basic module initialization, called from TWiki::initialize

=cut

sub initializeAccess
{
    %allGroups = ();
}

=pod

---++ sub permissionsSet (  $web  )

Are there any security restrictions for this Web
(ignoring settings on individual pages).

=cut

sub permissionsSet
{
    my( $web ) = @_;

    my $permSet = 0;

    my @types = qw/ALLOW DENY/;
    my @actions = qw/CHANGE VIEW RENAME/;

    OUT: foreach my $type ( @types ) {
        foreach my $action ( @actions ) {
            my $pref = $type . "WEB" . $action;
            my $prefValue = TWiki::Prefs::getPreferencesValue( $pref, $web ) || "";
            if( $prefValue !~ /^\s*$/ ) {
                $permSet = 1;
                last OUT;
            }
        }
    }

    return $permSet;
}

=pod

---++ checkAccessPermission( $action, $user, $text, $topic, $web ) ==> $ok
| Description:          | Check if user is allowed to access topic |
| Parameter: =$action=  | "VIEW", "CHANGE", "CREATE", etc. |
| Parameter: =$user=    | Remote WikiName, e.g. "Main.PeterThoeny" |
| Parameter: =$text=    | If empty: Read "$theWebName.$theTopicName" to check permissions |
| Parameter: =$topic=   | Topic name to check, e.g. "SomeTopic" |
| Parameter: =$web=     | Web, e.g. "Know" |
| Return:    =$ok=      | 1 if OK to access, 0 if no permission |

=cut

sub checkAccessPermission
{
    my( $theAccessType, $theUserName,
        $theTopicText, $theTopicName, $theWebName ) = @_;

    # super admin is always allowed
    if ( $TWiki::doSuperAdminGroup && $TWiki::superAdminGroup ) {
        if ( userIsInGroup( $theUserName, $TWiki::superAdminGroup )) {
            return 1;
        }
    }

    $theAccessType = uc( $theAccessType );  # upper case
    if( ! $theWebName ) {
        $theWebName = $TWiki::webName;
    }
    if( ! $theTopicText ) {
        # text not supplied as parameter, so read topic. The
        # read is "Raw" just to hint to store that we want the
        # data _fast_.
        $theTopicText = TWiki::Store::readTopicRaw( $theWebName, $theTopicName, undef, 1 );
    }

    my $allowText;
    my $denyText;

    # extract the * Set (ALLOWTOPIC|DENYTOPIC)$theAccessType =
    # from the topic text
    foreach( split( /\n/, $theTopicText ) ) {
        if( /^\s+\*\sSet\s(ALLOWTOPIC|DENYTOPIC)$theAccessType\s*\=\s*(.*)/ ) {
            my ( $how, $set ) = ( $1, $2 );
            # Note: an empty value is a valid value!
            if( defined( $set )) {
                if( $how eq "DENYTOPIC" ) {
                    $denyText = $set;
                } else {
                    $allowText = $set;
                }
            }
        }
    }

    # DENYTOPIC overrides DENYWEB, even if it is empty
    unless( defined( $denyText )) {
        $denyText =
          TWiki::Prefs::getPreferencesValue( "DENYWEB$theAccessType",
                                             $theWebName );
    }

    if( defined( $denyText )) {
        my %deny = _parseUserList( $denyText, 1 );
        return 0 if $deny{$theUserName};
    }

    if( defined( $allowText )) {
    	my %allow = _parseUserList( $allowText, 1 );
        return 0 unless $allow{$theUserName};
    } else {
        # ALLOWTOPIC overrides ALLOWWEB, even if it is empty
        $allowText =
          TWiki::Prefs::getPreferencesValue( "ALLOWWEB$theAccessType",
                                             $theWebName );

        if( defined( $allowText ) && $allowText =~ /\S/ ) {
            my %allow = _parseUserList( $allowText, 1 );
            return 0 unless $allow{$theUserName};
        }
    }

    return 1;
}

# =========================
=pod

---++ getListOfGroups(  ) ==> @listOfGroups
| Description:        | get a list of groups definedin this TWiki |
| Return:    =@listOfGroups=    | list of all the groups |

=cut

sub getListOfGroups
{
    my $text =
      TWiki::Search::searchWeb
          (
           #_callback      => undef,
           inline          => 1,
           "search"        => "Set GROUP =",
           "web"           => "all",
           "topic"         => "*Group",
           "type"          => "regex",
           "nosummary"     => "on",
           "nosearch"      => "on",
           "noheader"      => "on",
           "nototal"       => "on",
           "noempty"       => "on",
           "format"	 => "\$web.\$topic",
          );

    my ( @list ) =  split ( /\n/, $text );	
    return @list;
}

# =========================
=pod

---++ getGroupsUserIsIn( $user ) ==> @listOfGroups
| Description:        | get a list of groups a user is in |
| Parameter: =$user=  | Remote WikiName, e.g. "Main.PeterThoeny" |
| Return:    =@listOfGroups=    | list os all the WikiNames for a group |

=cut

sub getGroupsUserIsIn
{
    my( $theUserName ) = @_;

    my $userTopic = _getWebTopicName( $TWiki::mainWebname, $theUserName );
    my @grpMembers = ();
    my @listOfGroups = getListOfGroups();
    my $group;

    foreach $group ( @listOfGroups) {
        if ( userIsInGroup ( $userTopic, $group )) {
	    	push ( @grpMembers, $group );
		}
    }

    return @grpMembers;
}

# =========================
=pod

---++ userIsInGroup( $user, $group ) ==> $ok
Check if user is a member of a group. If a topic which is
not a group is specified, checks if it is the users topic.
| Parameter: =$user=  | Remote WikiName, e.g. "Main.PeterThoeny" |
| Parameter: =$group= | Group name, e.g. "Main.EngineeringGroup" |
| Return:    =$ok=    | 1 user is in group, 0 if not |

=cut

sub userIsInGroup
{
    my( $theUserName, $theGroupTopicName ) = @_;

    my $usrTopic = _getWebTopicName( $TWiki::mainWebname, $theUserName );
    my $grpTopic = _getWebTopicName( $TWiki::mainWebname, $theGroupTopicName );
    my @grpMembers = ();

    if( $grpTopic !~ /.*Group$/ ) {
        # not a group, so compare user to user
        return ( $grpTopic eq $usrTopic );
    }
    unless ( exists $allGroups{$grpTopic} ) {
        getUsersOfGroup( $grpTopic );
    }

    return 0 unless exists( $allGroups{$grpTopic} );

    return $allGroups{$grpTopic}{$usrTopic};
}

=pod

---++ getUsersOfGroup( $group ) ==> @users
Get all members of a group; groups are expanded recursively
Return list of users, e.g. ( "Main.JohnSmith", "Main.JaneMiller" )
| =$group=  | Group topic name, e.g. "Main.EngineeringGroup" |
| =$processedGroups= | Internal use only; pass undef |

=cut

sub getUsersOfGroup
{
    my( $theGroupTopicName, $processedGroups ) = @_;

    my @resultList = ();
    # extract web and topic name
    my $topic = $theGroupTopicName;
    my $web = $TWiki::mainWebname;
    $topic =~ /^([^\.]*)\.(.*)$/;
    if( $2 ) {
        $web = $1;
        $topic = $2;
    }

    if( $topic !~ /.*Group$/ ) {
        # return user, is not a group
        return ( "$web.$topic" );
    }

    # check if group topic is already processed
    if( !defined( $processedGroups )) {
        $processedGroups = {};
    } elsif( $processedGroups->{"$web.$topic"} ) {
        return ();
    }
    $processedGroups->{"$web.$topic"} = 1;

    my $text = TWiki::Store::readTopicRaw( $web, $topic, undef, 1 );

    # SMELL: what the blazes is this? Comment it out, and
    # see what breaks.... DFP rules.
    # reset variables, defensive coding needed for recursion
    #(my $baz = "foo") =~ s/foo//;

    # extract users
    my $user = "";
    my %glist;
    foreach( split( /\n/, $text ) ) {
        if( /^\s+\*\sSet\sGROUP\s*\=\s*(.+)$/ ) {
            # Note: if there are multiple GROUP assignments in the
            # topic, the last will be taken.
            %glist = _parseUserList( $1, 0 );
        }
    }
    foreach ( keys %glist ) {
        if( /.*Group$/ ) {
            # $user is actually a group
            my $group = $_;
            if( ( %allGroups ) && ( exists $allGroups{ $group } ) ) {
                # already known, so add to list
                push( @resultList, keys %{$allGroups{$group}} );
            } else {
                # call recursively
                push( @resultList,
                      map { $allGroups{$group}{$_} = 1; }
                      getUsersOfGroup( $group, $processedGroups ));
            }
        } else {
            # add user to list
            push( @resultList, $_ );
        }
    }
    return @resultList;
}

sub _getWebTopicName
{
    my( $theWebName, $theTopicName ) = @_;
    # SMELL: this is a hack, isn't it? What should really be going on here?
    $theTopicName =~ s/%MAINWEB%/$theWebName/go;
    $theTopicName =~ s/%TWIKIWEB%/$theWebName/go;
    if( $theTopicName =~ /[\.]/ ) {
        $theWebName = "";  # to suppress warning
    } else {
        $theTopicName = "$theWebName\.$theTopicName";
    }
    return $theTopicName;
}

# Get a hash indexed by the users in a list. If expand is
# true, recursively expand groups defined in the list to create
# a flat has of users.
sub _parseUserList
{
    my( $theItems, $expand ) = @_;
    # comma delimited list of users or groups
    # i.e.: "%MAINWEB%.UserA, UserB, Main.UserC  # something else"
    $theItems =~ s/(<[^>]*>)//go;     # Remove HTML tags
    # TODO: i18n fix for user name
    $theItems =~ s/\s*([a-zA-Z0-9_\.\,\s\%]*)\s*(.*)/$1/go; # Limit list
    my %list;
    foreach( split( /[\,\s]+/, $theItems )) {
        my $e = _getWebTopicName( $TWiki::mainWebname, $_ );
        if ( $expand ) {
            map { $list{$_} = 1; } getUsersOfGroup( $e );
        } else {
            $list{$e} = 1;
        }
    }
    return %list;
}

# =========================

1;

# EOF
