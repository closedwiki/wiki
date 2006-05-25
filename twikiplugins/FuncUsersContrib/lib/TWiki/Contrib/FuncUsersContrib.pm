use TWiki::Plugins;
use strict;

# Copyright (C) Crawford Currie 2006
# An emergency module to make up for defisciences in the TWiki::Func API
# These methods are designed to be added to TWiki::Func; though the Users object
# should probably implement them.

package TWiki::Contrib::FuncUsersContrib;

use vars qw( $VERSION );
my( $web, $topic, $rev ) = @_;

$VERSION = '1.000';

=pod

---++ getListOfUsers() -> \@list
Get a list of the registered users *not* including groups. The returned
list is a list of TWiki::User objects.


To get a combined list of users and groups, you can do this:
<verbatim>
@usersandgroups = ( @{TWiki::Func::getListOfUsers()}, TWiki::Func::getListOfGroups() );
</verbatim>

=cut

sub getListOfUsers {
    my $session = $TWiki::Plugins::SESSION;
    my $users = $session->{users};

    #if we have the UserMapping changes (post 4.0.2)
    return $session->{users}->getAllUsers() if (defined ($session->{users}->getAllUsers));

    $users->lookupLoginName('guest'); # load the cache

    unless( $users->{_LIST_OF_REGISTERED_USERS} ) {
        my @list =
            grep { $_ }
              map {
                  my( $w, $t ) = TWiki::Func::normalizeWebTopicName(
                      $TWiki::cfg{UsersWebName}, $_);
                  $users->findUser( $t, "$w.$t");
              } values %{$users->{U2W}};
        $users->{_LIST_OF_REGISTERED_USERS} = \@list;
    }
    return $users->{_LIST_OF_REGISTERED_USERS};
}

sub _collateGroups {
    my $ref = shift;
    my $group = shift;
    return unless $group;
    my $groupObject = $ref->{users}->findUser( $group );
    push (@{$ref->{list}}, $groupObject) if $groupObject;
}

=pod

---++ getListOfGroups() -> \@list
Get a list of groups. The returned list is a list of TWiki::User objects.

=cut

sub getListOfGroups {
    my $session = $TWiki::Plugins::SESSION;
    my $users = $session->{users};

    #if we have the UserMapping changes (post 4.0.2)
    return $session->{users}->getAllGroups() if (defined ($session->{users}->getAllGroups));

    #This code assumes we are using TWiki topic based Group mapping
    unless( $users->{_LIST_OF_GROUPS} ) {
        my @list;
        $session->{search}->searchWeb(
            _callback     => \&_collateGroups,
            _cbdata       =>  { list => \@list, users => $users },
            inline        => 1,
            search        => "Set GROUP =",
            web           => 'all',
            topic         => "*Group",
            type          => 'regex',
            nosummary     => 'on',
            nosearch      => 'on',
            noheader      => 'on',
            nototal       => 'on',
            noempty       => 'on',
            format	     => "\$web.\$topic",
            separator     => '',
           );
        $users->{_LIST_OF_GROUPS} = \@list;
    }

    return $users->{_LIST_OF_GROUPS};
}

=pod

---++ lookupUser( %spec ) -> \$user
Find the TWiki::User object for a named user.
   * =%spec= - the identifying marks of the user. The following options are supported:
      * =wikiname= - the wikiname of the user (web name optional, also supports %MAINWEB%)
      * =login= - login name of the user
      * =email= - email address of the user **returns an array of users**
For example,
<verbatim>
my @pa = TWiki::Func::lookupUser( email => "pa@addams.org" );
my $ma = TWiki::Func::lookupUser( wikiname => "%MAINWEB%.MorticiaAddams" );
</verbatim>


=cut

sub lookupUser {
    my( %opts ) = @_;
    my $user;
    my $users = $TWiki::Plugins::SESSION->{users};

    if( $opts{wikiname} ) {
        if( $user = $users->findUser($opts{wikiname},$opts{wikiname},1)) {
            return $user;
        }
    }

    if( $opts{login} ) {
        if( $user = $users->findUser($opts{login},$opts{login},1)) {
            return $user;
        }
    }

    if( $opts{email} ) {
        #if we have the UserMapping changes (post 4.0.3)
        if (defined ($users->findUserByEmail)) {
            return $users->findUserByEmail();
        } else {
            # SMELL: there is no way in TWiki to map from an email back to a user, so
        	# we have to cheat. We do this as follows:
            unless( $users->{_MAP_OF_EMAILS} ) {
        	    $users->lookupLoginName('guest'); # load the cache
                #SMELL: this will not work for non-topic based users
            	foreach my $wn ( keys %{$users->{W2U}} ) {
                    my $ou = $users->findUser( $users->{W2U}{$wn}, $wn, 1 );
                    map { push( @{$users->{_MAP_OF_EMAILS}->{$_}}, $ou); } $ou->emails();

            	}
            }
        }
        return $users->{_MAP_OF_EMAILS}->{$opts{email}};
    }

    return undef;
}

=pod

---++ getACLs( \@modes, $web, $topic ) -> \%acls
Get the Access Control Lists controlling which registered users *and groups* are allowed to access the topic (web).
   * =\@modes= - list of access modes you are interested in; e.g. [ "VIEW","CHANGE" ]
   * =$web= - the web
   * =$topic= - if =undef=  then the setting is taken as a web setting e.g. WEBVIEW. Otherwise it is taken as a topic setting e.g. TOPICCHANGE

=\%acls= is a hash indexed by *user name* (web.wikiname). This maps to a hash indexed by *access mode* e.g. =VIEW=, =CHANGE= etc. This in turn maps to a boolean; 0 for access denied, non-zero for access permitted.
<verbatim>
my $acls = TWiki::Func::getACLs( [ 'VIEW', 'CHANGE', 'RENAME' ], $web, $topic );
foreach my $user ( keys %$acls ) {
    if( $acls->{$user}->{VIEW} ) {
        print STDERR "$user can view $web.$topic\n";
    }
}
</verbatim>
The =\%acls= object may safely be written to e.g. for subsequent use with =setACLs=.

__Note__ topic ACLs are *not* the final permissions used to control access to a topic. Web level restrictions may apply that prevent certain access modes for individual topics.

=cut

sub getACLs {
    my( $modes, $web, $topic ) = @_;

    my $context = 'TOPIC';
    unless( $topic ) {
        $context = 'WEB';
        $topic = $TWiki::cfg{WebPrefsTopicName};
    }

    my @knownusers = map { $_->webDotWikiName() }
      ( @{getListOfUsers()}, @{getListOfGroups()} );

    my %acls;

    # By default, allow all to access all
    foreach my $user ( @knownusers ) {
        foreach my $mode ( @$modes ) {
            $acls{$user}->{$mode} = 1;
        }
    }

    my( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );
    my $modeRE = join('|', map { uc( $_ ) } @$modes );
    while( $text =~ s/^(?:   |\t)+\* Set (ALLOW|DENY)$context($modeRE) = *(.*)$//m ) {
        my $perm = $1;
        my $mode = $2;
        my @lusers =
          grep { $_ }
            map {
                my( $w, $t ) = TWiki::Func::normalizeWebTopicName(
                    $TWiki::cfg{UsersWebName}, $_);
                lookupUser( wikiname => "$w.$t");
            } split( /[ ,]+/, $3 || '' );

        # expand groups
        my @users;
        while( scalar( @lusers )) {
            my $user = pop( @lusers );
            if( $user->isGroup()) {
                # expand groups and add individual users
                my $group = $user->groupMembers();
                push( @lusers, @$group ) if $group;
            }
            push( @users, $user->webDotWikiName() );
        }

        if( $perm eq 'ALLOW' ) {
            # If ALLOW, only users in the ALLOW list are permitted, so change
            # the default for all other users to 0.
            foreach my $user ( @knownusers ) {
                $acls{$user}->{$mode} = 0;
            }
            foreach my $user ( @users ) {
                $acls{$user}->{$mode} = 1;
            }
        } else {
            foreach my $user ( @users ) {
                $acls{$user}->{$mode} = 0;
            }
        }
    }

    return \%acls;
}

=pod

---++ setACLs( \@modes, $web, $topic, \%acls, $nosearchall )
Set the access controls on the named topic.
   * =\@modes= - list of access modes you want to set; e.g. [ "VIEW","CHANGE" ]
   * =$web= - the web
   * =$topic= - if =undef=, then this is the ACL for the web. otherwise it's for the topic.
   * =\%acls= - must be a hash indexed by *user object*. This maps to a hash indexed by *access mode* e.g. =VIEW=, =CHANGE= etc. This in turn maps to a boolean value; 1 for allowed, and 0 for denied. See =getACLs= for an example of this kind of object.

Access modes used in \%acls that do not appear in \@modes are simply ignored.

If there are any errors, then an =Error::Simple= will be thrown.

=cut

sub setACLs {
    my( $modes, $acls, $web, $topic ) = @_;

    my $context = 'TOPIC';
    unless( $topic ) {
        $context = 'WEB';
        $topic = $TWiki::cfg{WebPrefsTopicName};
    }

    my( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );

    my @knownusers = map { $_->webDotWikiName() }
      ( @{getListOfUsers()}, @{getListOfGroups()} );

    $text .= "\n" unless $text =~ /\n$/s;

    foreach my $op ( @$modes ) {
        my @allowed = grep { $acls->{$_}->{$op} } @knownusers;
        my @denied = grep { !$acls->{$_}->{$op} } @knownusers;
        $text =~ s/^(   |\t)+\* Set (ALLOW|DENY)$context$op =.*$//gm;
        if( scalar( @denied )) {
            # Work out the access modes
            my $line;
            if( scalar( @denied ) <= scalar( @allowed )) {
                $line = "   * Set DENY$context$op = ".join(' ', @denied)."\n";
            } else {
                $line = "   * Set ALLOW$context$op = ".join(' ', @allowed)."\n";
            }
            $text .= $line;
        }
    }

    # If there is an access control violation this will throw.
    TWiki::Func::saveTopic( $web, $topic,
                            $meta, $text, { minor => 1 } );
}

=pod

---++ isAdmin() -> $boolean

Find out if the currently logged-in user is an admin or not.

=cut

sub isAdmin {
    return $TWiki::Plugins::SESSION->{user}->isAdmin();
}

=pod

---++ isInGroup( $group ) -> $boolean

Find out if the currently logged-in user is in the named group. e.g.
<verbatim>
if( TWiki::Func::isInGroup( "PopGroup" )) {
    ...
}
</verbatim>

=cut

sub isInGroup {
    my $group = shift;

    return $TWiki::Plugins::SESSION->{user}->isInList( $group );
}


1;
