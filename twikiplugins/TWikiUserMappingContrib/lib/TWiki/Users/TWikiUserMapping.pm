# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 Sven Dowideit, SvenDowideit@home.org.au
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
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

---+ package TWiki::Users::TWikiUserMapping

User mapping is the process by which TWiki maps from a username (a login name) to a wikiname and back. It is also where groups are maintained.

By default TWiki maintains user topics and group topics in the %MAINWEB% that
define users and group. These topics are
   * !TWikiUsers - stores a mapping from usernames to TWiki names
   * !WikiName - for each user, stores info about the user
   * !GroupNameGroup - for each group, a topic ending with "Group" stores a list of users who are part of that group.

Many sites will want to override this behaviour, for example to get users and groups from a corporate database.

This class implements the basic TWiki behaviour using topics to store users,
but is also designed to be subclassed so that other services can be used.

Subclasses should be named 'XxxxUserMapping' so that configure can find them.

*All* methods in this class should be implemented by subclasses.

=cut

package TWiki::Users::TWikiUserMapping;

use strict;
use Assert;
use Error qw( :try );
use TWiki::Time;
use TWiki::ListIterator;

=pod

---++ ClassMethod new ($session, $impl)

Constructs a new user mapping handler of this type, referring to $session
for any required TWiki services.

=cut

sub new {
    my( $class, $session ) = @_;

    my $this = bless( {}, $class );
    $this->{session} = $session;
    $this->{mapping_id} = 'TWikiUserMapping_';

    my $implPasswordManager = $TWiki::cfg{PasswordManager};
    $implPasswordManager = 'TWiki::Users::Password'
      if( $implPasswordManager eq 'none' );
    eval "use $implPasswordManager";
    die "Password Manager: $@" if $@;
    $this->{passwords} = $implPasswordManager->new( $session );

    #$this->{U2L} = {};
    $this->{L2U} = {};
    $this->{U2W} = {};
    $this->{W2U} = {};

    return $this;
}

=begin twiki

---++ ObjectMethod finish()
Break circular references.

=cut

# Note to developers; please undef *all* fields in the object explicitly,
# whether they are references or not. That way this method is "golden
# documentation" of the live fields in the object.
sub finish {
    my $this = shift;
    $this->{passwords}->finish() if $this->{passwords};
    undef $this->{L2U};
    undef $this->{U2W};
    undef $this->{W2U};
    undef $this->{mapping_id};
    undef $this->{passwords};
    undef $this->{session};
}

=pod

---++ ObjectMethod loginTemplateName () -> templateFile

allows UserMappings to come with customised login screens - that should preffereably only over-ride the UI function

=cut

sub loginTemplateName {
    return 'login';
}

=pod

---++ ObjectMethod supportsRegistration () -> false
return 1 if the UserMapper supports registration (ie can create new users)

=cut

sub supportsRegistration {
    return 1;
}


=pod

---++ ObjectMethod handlesUser ( $cUID, $login, $wikiname) 

Called by the TWiki::User object to determine which loaded mapping to use for a given user (must be fast)
in the BaseUserMapping case, we know all the users we deal specialise in.

=cut

sub handlesUser {
	my ($this, $cUID, $login, $wikiname) = @_;

    #if ( $user_id =~ /^($this->{mapping_id})/ || ($this->{mapping_id} eq 'TWikiUserMapping_'));
	#TODO: should really see if there is a mapping_id on the front and bail if we don't grok it..
	return 1;
}


=pod

---++ ObjectMethod login2canonical ($login) -> cUID

Convert a login name to the corresponding canonical user name. The
canonical name can be any string of 7-bit alphanumeric and underscore
characters, and must correspond 1:1 to the login name.
(undef on failure)

=cut

sub login2canonical {
    my( $this, $login ) = @_;

    use bytes;
    # use bytes to ignore character encoding
    $login =~ s/([^a-zA-Z0-9])/'_'.sprintf('%02d', ord($1))/ge;
    no bytes;
    $login = $this->{mapping_id}.$login;
   
    return $login;
}

=pod

---++ ObjectMethod canonical2login ($cUID) -> login

converts an internal cUID to that user's login
(undef on failure)

=cut

sub canonical2login {
    my( $this, $user ) = @_;
    ASSERT($user) if DEBUG;
	ASSERT($this->{mapping_id}) if DEBUG;
    $user =~ s/$this->{mapping_id}//;
   
    use bytes;
    # use bytes to ignore character encoding
    $user =~ s/_(\d\d)/chr($1)/ge;
    no bytes;
    return $user;
}


=pod

---++ ClassMethod addUser ($login, $wikiname, $password, $emails) -> cUID

no registration, this is a read only user mapping
throws an Error::Simple 

Add a user to the persistant mapping that maps from usernames to wikinames
and vice-versa. The default implementation uses a special topic called
"TWikiUsers" in the users web. Subclasses will provide other implementations
(usually stubs if they have other ways of mapping usernames to wikinames).
Names must be acceptable to $TWiki::cfg{NameFilter}
$login must *always* be specified. $wikiname may be undef, in which case
the user mapper should make one up.
This function must return a *canonical user id* that it uses to uniquely
identify the user. This can be the login name, or the wikiname if they
are all guaranteed unigue, or some other string consisting only of 7-bit
alphanumerics and underscores.
if you fail to create a new user (for eg your Mapper has read only access), 
            throw Error::Simple(
               'Failed to add user: '.$ph->error());

=cut

sub addUser {
    my ( $this, $login, $wikiname, $password, $emails ) = @_;

    ASSERT($login) if DEBUG;

    # SMELL: really ought to be smarter about this e.g. make a wikiword
    $wikiname ||= $login;

    if( $this->{passwords}->fetchPass( $login )) {
        # They exist; their password must match
        unless( $this->{passwords}->checkPassword( $login, $password )) {
            throw Error::Simple(
                'New password did not match existing password for this user');
        }
        # User exists, and the password was good.
    } else {
        # add a new user

        unless( defined( $password )) {
            $password = TWiki::Users::randomPassword();
        }

        unless( $this->{passwords}->setPassword( $login, $password )) {
            throw Error::Simple(
                'Failed to add user: '.$this->{passwords}->error());
        }
    }

    my $store = $this->{session}->{store};
    my( $meta, $text );

    if( $store->topicExists( $TWiki::cfg{UsersWebName},
                             $TWiki::cfg{UsersTopicName} )) {
        ( $meta, $text ) = $store->readTopic(
            undef, $TWiki::cfg{UsersWebName}, $TWiki::cfg{UsersTopicName} );
    } else {
        ( $meta, $text ) = $store->readTopic(
            undef, $TWiki::cfg{SystemWebName}, 'TWikiUsersTemplate' );
    }

    my $result = '';
    my $entry = "   * $wikiname - ";
    $entry .= $login . " - " if $login;
    my $today = TWiki::Time::formatTime(time(), $TWiki::cfg{DefaultDateFormat}, 'gmtime');

    # add to the mapping caches
    my $user = _cacheUser( $this, $wikiname, $login );

    # add name alphabetically to list
    foreach my $line ( split( /\r?\n/, $text) ) {
        # TODO: I18N fix here once basic auth problem with 8-bit user names is
        # solved
        if ( $entry ) {
            my ( $web, $name, $odate ) = ( '', '', '' );
            if ( $line =~ /^\s+\*\s($TWiki::regex{webNameRegex}\.)?($TWiki::regex{wikiWordRegex})\s*(?:-\s*\w+\s*)?-\s*(.*)/ ) {
                $web = $1 || $TWiki::cfg{UsersWebName};
                $name = $2;
                $odate = $3;
            } elsif ( $line =~ /^\s+\*\s([A-Z]) - / ) {
                #	* A - <a name="A">- - - -</a>^M
                $name = $1;
            }
            if( $name && ( $wikiname le $name ) ) {
                # found alphabetical position
                if( $wikiname eq $name ) {
                    # adjusting existing user - keep original registration date
                    $entry .= $odate;
                } else {
                    $entry .= $today."\n".$line;
                }
                # don't adjust if unchanged
                return $user if( $entry eq $line );
                $line = $entry;
                $entry = '';
            }
        }

        $result .= $line."\n";
    }
    if( $entry ) {
        # brand new file - add to end
        $result .= "$entry$today\n";
    }
    $store->saveTopic( 
    			#TODO: why is this Admin and not the RegoAgent??
    			$this->{session}->{users}->getCanonicalUserID($TWiki::cfg{AdminUserLogin}),
                       $TWiki::cfg{UsersWebName},
                       $TWiki::cfg{UsersTopicName},
                       $result, $meta );

    $this->setEmails( $user, $emails );

    return $user;
}


=pod

---++ ObjectMethod removeUser( $user ) -> $boolean

Delete the users entry. Removes the user from the password
manager and user mapping manager. Does *not* remove their personal
topics, which may still be linked.

=cut

sub removeUser {
    my( $this, $user ) = @_;
	$this->ASSERT_IS_CANONICAL_USER_ID($user) if DEBUG;
    my $ln = $this->getLoginName( $user );
    $this->{passwords}->removeUser($ln);
    # SMELL: currently a nop, needs someone to implement it
}


=pod

---++ ObjectMethod getWikiName ($cUID) -> wikiname

# Map a canonical user name to a wikiname

=cut

sub getWikiName {
    my ($this, $cUID) = @_;
	
    #ASSERT($cUID =~ /^$this->{mapping_id}/) if DEBUG;

	
	my $wikiname;
#    $cUID =~ s/^$this->{mapping_id}//;
    if( $TWiki::cfg{Register}{AllowLoginName} ) {
        _loadMapping( $this );
        $wikiname = $this->{U2W}->{$cUID}
    } else {
        # If the mapping isn't enabled there's no point in loading it
    }
	$wikiname = $wikiname || canonical2login( $this, $cUID );
#print STDERR "--------------------------------------cUID : $cUID => $wikiname\n";	
    return $wikiname;
 
}

=pod

---++ ObjectMethod getLoginName ($cUID) -> login

Map a canonical user name to a login name

=cut

sub getLoginName {
    my ($this, $user) = @_;
    return canonical2login( $this, $user );
}

=pod

---++ ObjectMethod lookupLoginName ($login) - cUID

PROTECTED
Map a login name to the corresponding canonical user name. This is used for
lookups, and should be as fast as possible. Returns undef if no such user
exists. Called by TWiki::Users

=cut

sub lookupLoginName {
    my ($this, $login) = @_;

    _loadMapping( $this );
    return $this->{L2U}->{$login};
}


=pod

---++ ObjectMethod userExists($cUID) -> $boolean

Determine if the user already exists or not. Whether a user exists
or not is determined by the password manager.

=cut

sub userExists {
    my( $this, $cUID ) = @_;
	$this->ASSERT_IS_CANONICAL_USER_ID($cUID) if DEBUG;

    # Do this to avoid a password manager lookup
    return 1 if $cUID eq $this->{session}->{user};

    my $loginName = $this->canonical2login( $cUID );

    if( $loginName eq $TWiki::cfg{DefaultUserLogin} ) {
        return $loginName;
    }

    # TWiki allows *groups* to log in
    if( $this->isGroup( $loginName )) {
        return $loginName;
    }

    # Look them up in the password manager (can be slow).
    if( $this->{passwords}->fetchPass( $loginName )) {
        return $loginName;
    }

    return undef;
}

=pod

---++ ObjectMethod eachUser () -> listIterator of cUIDs

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

=cut

sub eachUser {
    my( $this ) = @_;

    _loadMapping( $this );
    my @list = keys(%{$this->{U2W}});
    my $iter = new TWiki::ListIterator( \@list );
    $iter->{filter} = sub {  #don't claim users that are handled by the basemapping
                    my $cUID = $_[0] || '';
                    my $login = $this->{session}->{users}->getLoginName($cUID);
                    my $wikiname =  $this->{session}->{users}->getWikiName($cUID);
                    #print STDERR "**** $cUID  $login  $wikiname \n";
                    return !($TWiki::Plugins::SESSION->{users}->{basemapping}->handlesUser ( undef, $login, $wikiname) ); 
    }; 
    return $iter;
}


my %expanding;

=pod

---++ ObjectMethod eachGroupMember ($group) ->  listIterator of cUIDs

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

=cut

sub eachGroupMember {
    my $this = shift;
    my $group = shift;
    my $store = $this->{session}->{store};
    my $users = $this->{session}->{users};

    my $members = [];

    if( !$expanding{$group} &&
          $store->topicExists( $TWiki::cfg{UsersWebName}, $group )) {

        $expanding{$group} = 1;
        my $text =
          $store->readTopicRaw( undef,
                                $TWiki::cfg{UsersWebName}, $group,
                                undef );

        foreach( split( /\r?\n/, $text ) ) {
            if( /$TWiki::regex{setRegex}GROUP\s*=\s*(.+)$/ ) {
                next unless( $1 eq 'Set' );
                # Note: if there are multiple GROUP assignments in the
                # topic, only the last will be taken.
                my $f = $2;
                $members = _expandUserList( $this, $f );
            }
        }
        delete $expanding{$group};
    }

    return new TWiki::ListIterator( $members );
}


=pod

---++ ObjectMethod isGroup ($user) -> boolean
TODO: what is $user - wikiname, UID ??
Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

=cut

sub isGroup {
    my ($this, $user) = @_;

    # Groups have the same username as wikiname as canonical name
    return 1 if $user eq $TWiki::cfg{SuperAdminGroup};

    return $user =~ /Group$/;
}

=pod

---++ ObjectMethod eachGroup () -> ListIterator of groupnames

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

=cut

sub eachGroup {
    my ( $this ) = @_;
    _getListOfGroups( $this );
    return new TWiki::ListIterator( \@{$this->{groupsList}} );
}


=pod

---++ ObjectMethod eachMembership ($cUID) -> ListIterator of groups this user is in

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

=cut

sub eachMembership {
    my ($this, $user) = @_;
    my @groups = ();

    _getListOfGroups( $this );
    my $it = new TWiki::ListIterator( \@{$this->{groupsList}} );
    $it->{filter} = sub {
        $this->isInGroup($user, $_[0]);
    };
    return $it;
}

=pod

---++ ObjectMethod isAdmin( $user ) -> $boolean

True if the user is an admin
   * is $TWiki::cfg{SuperAdminGroup}
   * is a member of the $TWiki::cfg{SuperAdminGroup}

=cut

sub isAdmin {
    my( $this, $user ) = @_;
    my $isAdmin = 0;
	$this->ASSERT_IS_CANONICAL_USER_ID($user) if DEBUG;
#TODO: this might not apply now that we have BaseUserMapping - test
    if ($user eq $TWiki::cfg{SuperAdminGroup}) {
        $isAdmin = 1;
    } else {
        my $sag = $TWiki::cfg{SuperAdminGroup};
        $isAdmin = $this->isInGroup( $user, $sag );
    }

    return $isAdmin;
}


=pod

---++ ObjectMethod isInGroup ($user, $group, $scanning) -> bool

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

=cut

sub isInGroup {
    my( $this, $user, $group, $scanning ) = @_;
    ASSERT($user) if DEBUG;

    my @users;
    my $it = $this->eachGroupMember($group);
    while ($it->hasNext()) {
        my $u = $it->next();
        next if $scanning->{$u};
        $scanning->{$u} = 1;
        return 1 if $u eq $user;
        if( $this->isGroup($u) ) {
            return 1 if $this->isInGroup( $user, $u, $scanning);
        }
    }
    return 0;
}

=pod

---++ ObjectMethod findUserByEmail( $email ) -> \@users
   * =$email= - email address to look up
Return a list of canonical user names for the users that have this email
registered with the password manager or the user mapping manager.

The password manager is asked first for whether it maps emails.
If it doesn't, then the user mapping manager is asked instead.

=cut

sub findUserByEmail {
    my( $this, $email ) = @_;
    ASSERT($email) if DEBUG;
    my @users;
    if( $this->{passwords}->isManagingEmails()) {
        my $logins = $this->{passwords}->findLoginByEmail( $email );
        if (defined $logins) {
            foreach my $l ( @$logins ) {
                $l = $this->lookupLoginName( $l );
                push( @users, $l ) if $l;
            }
        }
    } else {
        # if the password manager didn't want to provide the service, ask
        # the user mapping manager
        unless( $this->{_MAP_OF_EMAILS} ) {
            $this->{_MAP_OF_EMAILS} = {};
            my $it = $this->eachUser();
            while( $it->hasNext() ) {
                my $uo = $it->next();
                map { push( @{$this->{_MAP_OF_EMAILS}->{$_}}, $uo); }
                  $this->getEmails( $uo );
            }
        }
        push( @users, $this->{_MAP_OF_EMAILS}->{$email});
    }
    return \@users;
}

=pod

---++ ObjectMethod getEmails($user) -> @emailAddress

If this is a user, return their email addresses. If it is a group,
return the addresses of everyone in the group.

The password manager and user mapping manager are both consulted for emails
for each user (where they are actually found is implementation defined).

Duplicates are removed from the list.

=cut

sub getEmails {
    my( $this, $user ) = @_;
	$this->ASSERT_IS_CANONICAL_USER_ID($user) if DEBUG;

    my %emails;
    if ( $this->isGroup($user) ) {
        my $it = $this->eachGroupMember( $user );
        while( $it->hasNext() ) {
            foreach ($this->getEmails( $it->next())) {
                $emails{$_} = 1;
            }
        }
    } else {
        if ($this->{passwords}->isManagingEmails()) {
            # get emails from the password manager
            foreach ($this->{passwords}->getEmails( $this->getLoginName( $user ))) {
                $emails{$_} = 1;
            }
        } else {
            # And any on offer from the user mapping manager
            foreach ($this->mapper_getEmails( $user )) {
                $emails{$_} = 1;
            }
        }
    }

    return keys %emails;
}

=pod

---++ ObjectMethod setEmails($user, @emails) -> boolean

Set the email address(es) for the given user.
The password manager is tried first, and if it doesn't want to know the
user mapping manager is tried.

=cut

sub setEmails {
    my $this = shift;
    my $user = shift;
	$this->ASSERT_IS_CANONICAL_USER_ID($user) if DEBUG;

    if( $this->{passwords}->isManagingEmails()) {
        $this->{passwords}->setEmails( $this->getLoginName( $user ), @_ );
    } else {
        $this->mapper_setEmails( $user, @_ );
    }
}


=pod

---++ ObjectMethod mapper_getEmails ($user)

Only used if passwordManager->isManagingEmails= = =false
(The emails are stored in the user topics.

=cut

sub mapper_getEmails {
    my( $this, $user ) = @_;
    
    my ($meta, $text) =
      $this->{session}->{store}->readTopic(
          undef, $TWiki::cfg{UsersWebName},
          $this->{session}->{users}->getWikiName($user) );

    my @addresses;

    # Try the form first
    my $entry = $meta->get('FIELD', 'Email');
    if ($entry) {
        push( @addresses, split( /;/, $entry->{value} ) );
    } else {
        # Now try the topic text
        foreach my $l (split ( /\r?\n/, $text  )) {
            if ($l =~ /^\s+\*\s+E-?mail:\s*(.*)$/mi) {
                push @addresses, split( /;/, $1 );
            }
        }
    }

    return @addresses;
}


=pod

---++ ClassMethod mapper_setEmails ($user, @emails)

Only used if =passwordManager->isManagingEmails= = =false=.
(emails are stored in user topics

=cut

sub mapper_setEmails {
    my $this = shift;
    my $user = shift;

    my $mails = join( ';', @_ );

    $user = $this->{session}->{users}->getWikiName( $user );

    my ($meta, $text) =
      $this->{session}->{store}->readTopic(
          undef, $TWiki::cfg{UsersWebName},
          $user);

    if ($meta->get('FORM')) {
        # use the form if there is one
        $meta->putKeyed( 'FIELD',
                         { name => 'Email',
                           value => $mails,
                           title => 'Email',
                           attributes=> 'h' } );
    } else {
        # otherwise use the topic text
        unless( $text =~ s/^(\s+\*\s+E-?mail:\s*).*$/$1$mails/mi ) {
            $text .= "\n   * Email: $mails\n";
        }
    }

    $this->{session}->{store}->saveTopic(
        $user, $TWiki::cfg{UsersWebName}, $user, $text, $meta );
}


=pod

---++ ObjectMethod findUserByWikiName ($wikiname) -> list of cUIDs associated with that wikiname

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details. The $skipExistanceCheck parameter
is private to this module, and blocks the standard existence check
to avoid reading .htpasswd when checking group memberships).

=cut

sub findUserByWikiName {
    my( $this, $wn, $skipExistanceCheck ) = @_;
    my @users = ();

    if( $this->isGroup( $wn )) {
        push( @users, $wn);
    } elsif( $TWiki::cfg{Register}{AllowLoginName} ) {
        # Add additional mappings defined in TWikiUsers
        _loadMapping( $this );
        if( $this->{W2U}->{$wn} ) {
            push( @users, $this->{W2U}->{$wn} );
        } else {
            # Bloody compatibility!
            # The wikiname is always a registered user for the purposes of this
            # mapping. We have to do this because TWiki defines access controls
            # in terms of mapped users, and if a wikiname is *missing* from the
            # mapping there is "no such user".
            push( @users, login2canonical( $this, $wn ));
        }
    } else {
        # The wikiname is also the login name, so we can just convert
        # it directly to a cUID
        my $cUID = login2canonical( $this, $wn );
        if( $skipExistanceCheck || $this->userExists( $cUID )) {
            push( @users, login2canonical( $this, $wn ));
        }
    }
    return \@users;
}

=pod

---++ ObjectMethod checkPassword( $userName, $passwordU ) -> $boolean

Finds if the password is valid for the given user.

Returns 1 on success, undef on failure.

=cut

sub checkPassword {
    my( $this, $userName, $pw ) = @_;
	$this->ASSERT_IS_USER_LOGIN_ID($userName) if DEBUG;
    return $this->{passwords}->checkPassword(
        $userName, $pw);
}

=pod

---++ ObjectMethod setPassword( $user, $newPassU, $oldPassU ) -> $boolean

If the $oldPassU matches matches the user's password, then it will
replace it with $newPassU.

If $oldPassU is not correct and not 1, will return 0.

If $oldPassU is 1, will force the change irrespective of
the existing password, adding the user if necessary.

Otherwise returns 1 on success, undef on failure.

=cut

sub setPassword {
    my( $this, $user, $newPassU, $oldPassU ) = @_;
	$this->ASSERT_IS_CANONICAL_USER_ID($user) if DEBUG;
    return $this->{passwords}->setPassword(
        $this->getLoginName( $user ), $newPassU, $oldPassU);
}

=pod

---++ ObjectMethod passwordError( ) -> $string

returns a string indicating the error that happened in the password handlers
TODO: these delayed error's should be replaced with Exceptions.

returns undef if no error

=cut

sub passwordError {
    my( $this ) = @_;
    return $this->{passwords}->error();
}

=pod

---++ ObjectMethod ASSERT_IS_CANONICAL_USER_ID( $user_id ) -> $boolean

used for debugging to ensure we are actually passing a canonical_id

=cut

sub ASSERT_IS_CANONICAL_USER_ID {
    my( $this, $user_id ) = @_;
#print STDERR "ASSERT_IS_CANONICAL_USER_ID($user_id)";
#    ASSERT($user_id =~/^UID$(\s+)UID$/) if DEBUG;
#    ASSERT( $user_id =~/^$this->{mapping_id}/e );	#refine with more specific regex

}

=pod

---++ ObjectMethod ASSERT_IS_USER_LOGIN_ID( $user_login ) -> $boolean

used for debugging to ensure we are actually passing a user login

=cut

sub ASSERT_IS_USER_LOGIN_ID {
    my( $this, $user_login ) = @_;
    
}


=pod

---++ ObjectMethod ASSERT_IS_USER_DISPLAY_NAME( $user_display ) -> $boolean

used for debugging to ensure we are actually passing a user display_name (commonly a WikiWord Name)

=cut

sub ASSERT_IS_USER_DISPLAY_NAME {
    my( $this, $user_display ) = @_;
    
}



=pod

---++ ObjectMethod _cacheUser ($wikiname, $login)

Construct the user management object

=cut

# PRIVATE
sub _cacheUser {
    my($this, $wikiname, $login) = @_;
    ASSERT($wikiname) if DEBUG;

    $login ||= $wikiname;

    my $user = login2canonical( $this, $login );

    #$this->{U2L}->{$user}     = $login;
    $this->{U2W}->{$user}     = $wikiname;
    $this->{L2U}->{$login}    = $user;
    $this->{W2U}->{$wikiname} = $user;

    return $user;
}


=pod

---++ ClassMethod new ($session, $impl)

Construct the user management object

=cut

# PRIVATE callback for search function to collate results
sub _collateGroups {
    my $ref = shift;
    my $group = shift;
    return unless $group;
    push (@{$ref->{list}}, $group);
}


=pod

---++ ClassMethod new ($session, $impl)

Construct the user management object

=cut

# PRIVATE get a list of groups defined in this TWiki
sub _getListOfGroups {
    my $this = shift;
    ASSERT(ref($this) eq 'TWiki::Users::TWikiUserMapping') if DEBUG;

    unless( $this->{groupsList} ) {
        my $users = $this->{session}->{users};
        $this->{groupsList} = [];

        $this->{session}->search->searchWeb
          (
              _callback     => \&_collateGroups,
              _cbdata       =>  { list => $this->{groupsList},
                                  users => $users },
              inline        => 1,
              search        => "Set GROUP =",
              web           => $TWiki::cfg{UsersWebName},
              topic         => "*Group",
              type          => 'regex',
              nosummary     => 'on',
              nosearch      => 'on',
              noheader      => 'on',
              nototal       => 'on',
              noempty       => 'on',
              format	     => '$topic',
              separator     => '',
             );
    }
    return $this->{groupsList};
}

=pod

---++ ClassMethod _loadMapping ($session, $impl)
Build hash to translate between username (e.g. jsmith)
and WikiName (e.g. Main.JaneSmith).
PRIVATE subclasses should *not* implement this.


=cut

sub _loadMapping {
    my $this = shift;
    return if $this->{CACHED};
    $this->{CACHED} = 1;

    #mapping from login to WikiName is done in the TWikiUserTopic
    #TODO: should only really do this mapping IF the use is in the password file.
    if ($TWiki::cfg{Register}{AllowLoginName} eq 1) {
        my $store = $this->{session}->{store};
        if( $store->topicExists($TWiki::cfg{UsersWebName},
                                $TWiki::cfg{UsersTopicName} )) {
            my $text = $store->readTopicRaw( undef,
                                          $TWiki::cfg{UsersWebName},
                                          $TWiki::cfg{UsersTopicName},
                                          undef );
            # Get the WikiNames and userids, and build hashes in both directions
            # This matches:
            #   * TWikiGuest - guest - 10 Mar 2005
            #   * TWikiGuest - 10 Mar 2005
            $text =~ s/^\s*\* (?:$TWiki::regex{webNameRegex}\.)?($TWiki::regex{wikiWordRegex})\s*(?:-\s*(\S+)\s*)?-.*$/_cacheUser( $this, $1, $2)/gome;
        }
    } else {
        #loginnames _are_ WikiNames so ask the Password handler for list of users
        my $iter = $this->{passwords}->fetchUsers();
#        $it->{process} = sub { return $_[0] + 1 };
        while ($iter->hasNext()) {
            my $login = $iter->next();
            _cacheUser($this, $login, $login);
        }
    }
}


=pod

---++ ClassMethod new ($session, $impl)

Construct the user management object

=cut

# Get a list of *canonical user ids* from a text string containing a
# list of user *wiki* names and *group ids*.
sub _expandUserList {
    my( $this, $names ) = @_;

    $names ||= '';
    # comma delimited list of users or groups
    # i.e.: "%MAINWEB%.UserA, UserB, Main.UserC  # something else"
    $names =~ s/(<[^>]*>)//go;     # Remove HTML tags

    my @l;
    foreach my $ident ( split( /[\,\s]+/, $names )) {
        $ident =~ s/^.*\.//;       # Dump the web specifier
        next unless $ident;
        if( $this->isGroup( $ident )) {
            my $it = $this->eachGroupMember( $ident );
            while( $it->hasNext() ) {
                push( @l, $it->next() );
            }
        } else {
            push( @l, @{$this->findUserByWikiName( $ident, 1 )} );
        }
    }
    return \@l;
}

1;
