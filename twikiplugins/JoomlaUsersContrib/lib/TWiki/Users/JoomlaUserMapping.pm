# Module of TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2006, 2007 Sven Dowideit, SvenDowideit@home.org.au
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

#THIS CODE has been hacked too many times to move it between versions of TWiki
#I still have to clean the code up alot. Sven Nov 2007

=begin twiki

---+ package TWiki::Users::JoomlaUserMapping

canonical user_id == id number of jos_user table
login == username column


=cut

package TWiki::Users::JoomlaUserMapping;
use base 'TWiki::UserMapping';

use strict;
use strict;
use Assert;
use TWiki::UserMapping;
use TWiki::Users::BaseUserMapping;
use TWiki::Time;
use TWiki::ListIterator;
use DBIx::SQLEngine;
use DBD::mysql;

use Error qw( :try );

#@TWiki::Users::JoomlaUserMapping::ISA = qw( TWiki::Users::BaseUserMapping );

=pod

---++ ClassMethod new( $session ) -> $object

Constructs a new password handler of this type, referring to $session
for any required TWiki services.

=cut

sub new {
    my( $class, $session ) = @_;
	
    my $this = bless( $class->SUPER::new($session, 'JoomlaUserMapping_'), $class );
    $this->{session} = $session;

    $this->{error} = undef;
    require Digest::MD5;

	$this->{groupCache} = {};
	
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

    $this->{JoomlaDB} = undef;

	$this->SUPER::finish();
}

=begin twiki

---++ ObjectMethod handlesUser ( $cUID, $login, $wikiname) -> $boolean

Called by the TWiki::Users object to determine which loaded mapping
to use for a given user (must be fast).

=cut

sub handlesUser {
	my ($this, $cUID, $login, $wikiname) = @_;
	
    return 1 if ( defined $cUID && $cUID =~ /$this->{mapping_id}/ );
	return 1 if ($login && $this->getCanonicalUserID( $login ));
#	return 1 if ($wikiname && $this->findUserByWikiName( $wikiname ));

print STDERR "**** Joomla does not handle $cUID, $login";

	return 0;
}

=begin twiki

---++ ObjectMethod getCanonicalUserID ($login, $dontcheck) -> cUID

Convert a login name to the corresponding canonical user name. The
canonical name can be any string of 7-bit alphanumeric and underscore
characters, and must correspond 1:1 to the login name.
(undef on failure)

(if dontcheck is true, return a cUID for a nonexistant user too - used for registration)

Subclasses *must* implement this method.


=cut

sub getCanonicalUserID {
    my ($this, $login, $dontcheck) = @_;
	
	#we ignore $dontcheck as this mapper does not do registration.
	
	return login2canonical($this, $login);
}

=begin twiki

---++ ObjectMethod loginTemplateName () -> templateFile

allows UserMappings to come with customised login screens - that should preffereably only over-ride the UI function

=cut

sub loginTemplateName {
    return 'login';
}


#return 1 if the UserMapper supports registration (ie can create new users)
sub supportsRegistration {
    return; #NO, we don't
}

# Convert a login name to the corresponding canonical user name. The
# canonical name can be any string of 7-bit alphanumeric and underscore
# characters, and must correspond 1:1 to the login name.
sub login2canonical {
    my( $this, $login ) = @_;
    
	my $canonical_id = -1;
    unless ($login eq $TWiki::cfg{DefaultUserLogin}) {
        #QUESTION: is the login known valid? if so, need to ASSERT that
        #QUESTION: why not use the cache to xform if available, and only aske if.. (or is this the case..... DOCCO )
        use bytes;
        # use bytes to ignore character encoding
        #$login =~ s/([^a-zA-Z0-9])/'_'.sprintf('%02d', ord($1))/ge;
    	 my $userDataset = $this->dbSelect('select * from jos_users where username = ?', $login );
         if( exists $$userDataset[0] ) {
         	$canonical_id = $$userDataset[0]{id};
    		#TODO:ASSERT there is only one..
        }	else {
#                 throw Error::Simple(
#                    'username does not exist: '.$login);
			return;
    	}
        no bytes;
    }
    
    $canonical_id = $this->{mapping_id}.$canonical_id;
    
    return $canonical_id;
}

# See login2 canonical
sub canonical2login {
    my( $this, $user ) = @_;
    ASSERT($user) if DEBUG;

    $user =~ s/^$this->{mapping_id}//;
	return unless ( $user =~ /^\d+$/ );
	return $TWiki::cfg{DefaultUserLogin} if ($user == -1);

    my $login = $TWiki::cfg{DefaultUserLogin};
	 my $userDataset = $this->dbSelect('select username from jos_users c2l where c2l.id = ?', $user );
     if( exists $$userDataset[0] ) {
     	$login = $$userDataset[0]{username};
    }	else {
		#TODO: examine having the mapper returnthe truth, and fakeing guest in the core...
             #throw Error::Simple(
             #   'user_id does not exist: '.$user);
		#die "did you call c2l using a login?";
		return $TWiki::cfg{DefaultUserLogin};
	}	
    return $login;
}

# PRIVATE
#QUESTION: this seems to pre-suppose that login can at times validly be == wikiname
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

# PRIVATE get a list of groups defined in this TWiki
sub _getListOfGroups {
    my $this = shift;
    ASSERT(ref($this) eq 'TWiki::Users::JoomlaUserMapping') if DEBUG;

    unless( $this->{groupsList} ) {
        $this->{groupsList} = [];
            my $dataset = $this->dbSelect('select name from jos_core_acl_aro_groups' );
            for my $row (@$dataset) {
		        my $groupID = $$row{name};		
				push @{$this->{groupsList}}, $groupID;
			}
    }
    return $this->{groupsList};
}

sub addUser {
    my ( $this, $login, $wikiname ) = @_;

    throw Error::Simple(
                'JoomlaUserMapping does not allow creation of users ');
}

# Remove a user from the mapping
# Called by TWiki::Users
sub removeUser {
             throw Error::Simple(
                'JoomlaUserMapping does not allow removeal of users ');
}

# Map a canonical user name to a wikiname
sub getWikiName {
    my ($this, $user) = @_;
    $this->ASSERT_IS_CANONICAL_USER_ID($user);

#print STDERR "getWikiName($user)?";
#    $user =~ s/^$this->{mapping_id}//;
#	return $TWiki::cfg{DefaultUserWikiName} if ($user == -1);	
	return $TWiki::cfg{DefaultUserWikiName} if ($user =~ /^$this->{mapping_id}-1$/);	
	
	my $user_number = $user;
    $user_number =~ s/^$this->{mapping_id}//;
	my $name;
	my $userDataset = $this->dbSelect('select name from jos_users gwn where gwn.id = ?', $user_number );
     if( exists $$userDataset[0] ) {
     	$name = $$userDataset[0]{name};
    }	else {
		#TODO: examine having the mapper returnthe truth, and fakeing guest in the core...
             #throw Error::Simple(
             #   'user_id does not exist: '.$user);
		return $TWiki::cfg{DefaultUserWikiName};
	}	
#print STDERR "getWikiName($user) == $name";
$name =~ s/ //g;
	return $name;
}

# Map a canonical user name to a login name
sub getLoginName {
    my ($this, $user) = @_;
    return canonical2login( $this, $user );
}

# Map a login name to the corresponding canonical user name. This is used for
# lookups, and should be as fast as possible. Returns undef if no such user
# exists. Called by TWiki::Users
sub lookupLoginName {
    my ($this, $login) = @_;

    return login2canonical( $this, $login );
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub eachUser {
    my( $this ) = @_;
    ASSERT($this->isa( 'TWiki::Users::JoomlaUserMapping')) if DEBUG;
	my @list = ();
#TODO: this needs to be implemented in terms of a DB iterator that only selects partial results
	my $userDataset = $this->dbSelect('select id from jos_users' );
    for my $row (@$userDataset) {
        push @list, $this->{mapping_id}.$$row{id};		
	}
	
    return new TWiki::ListIterator( \@list );
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub eachGroupMember {
    my $this = shift;
    my $groupName = shift;	#group_name
    ASSERT($this->isa( 'TWiki::Users::JoomlaUserMapping')) if DEBUG;
    ASSERT(defined($groupName)) if DEBUG;
#    my $store = $this->{session}->{store};
#    my $users = $this->{session}->{users};

	return new TWiki::ListIterator( $this->{groupCache}{$groupName} ) if (defined($this->{groupCache}{$groupName}));
	
    my $members = [];

     #return [] if ($groupName =~ /Registered/);    #LIMIT it cos most users are resistered
	my $groupIdDataSet = $this->dbSelect(
			'select group_id from jos_core_acl_aro_groups where name = ?', $groupName );	
     if( exists $$groupIdDataSet[0] ) {
     		my $group = $$groupIdDataSet[0]{group_id};
			my $groupDataset = $this->dbSelect(
					'select aro_id from jos_core_acl_groups_aro_map where group_id = ?', $group );
		#TODO: re-write with join & map
			for my $row (@$groupDataset) {
				#get rows of users in group
				my $userDataset = $this->dbSelect('select value from jos_core_acl_aro where aro_id = ?', $$row{aro_id} );
				my $user_id = $this->{mapping_id}.$$userDataset[0]{value};	# user_id
				push @{$members}, $user_id;
			}
		
    }		
	$this->{groupCache}{$groupName} = $members;
    return new TWiki::ListIterator( $members );
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub isGroup {
    my ($this, $user) = @_;
	
	#there are no groups that can login.
	return 0;
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub eachGroup {
    my ( $this ) = @_;
    _getListOfGroups( $this );
    return new TWiki::ListIterator( \@{$this->{groupsList}} );
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub eachMembership {
    my ($this, $user) = @_;
    my @groups = ();
#TODO: reimpl using db
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

sub NONOisAdmin {
    my( $this, $user ) = @_;
    my $isAdmin = 0;
	$this->ASSERT_IS_CANONICAL_USER_ID($user) if DEBUG;

    my $sag = $TWiki::cfg{SuperAdminGroup};
    $isAdmin = $this->isInGroup( $user, $sag );

    return $isAdmin;
}

# Called from TWiki::Users. See the documentation of the corresponding
# method in that module for details.
sub isInGroup {
    my( $this, $user, $group, $scanning ) = @_;
    ASSERT($user) if DEBUG;
#TODO: reimpl using db

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

sub getEmails {
    my( $this, $cUID ) = @_;
	
    $cUID =~ s/^$this->{mapping_id}//;
	return unless ( $cUID =~ /^\d+$/ );

    if( $cUID ) {
            my $dataset = $this->dbSelect('select * from jos_users where id = ?', $cUID );
            if( exists $$dataset[0] ) {
                return ($$dataset[0]{email});
            }
            $this->{error} = 'Login invalid';
            return ;
    } else {
        $this->{error} = 'No user';
        return ;
    }

}

sub setEmails {
    my $this = shift;
    my $user = shift;
    #die unless ($user);

	return 0;
}

=pod

---++ ObjectMethod findUserByWikiName ($wikiname) -> list of cUIDs associated with that wikiname

Called from TWiki::Users. See the documentation of the corresponding
method in that module for details.

Subclasses *must* implement this method.

=cut

sub findUserByWikiName {
    my $this = shift;
    my $wikiname = shift;

    if( $wikiname ) {
            my $dataset = $this->dbSelect('select * from jos_users where name = ?', $wikiname );
            if( exists $$dataset[0] ) {
                my @userList = ();
                for my $row (@$dataset) {
                    push(@userList, $this->{session}->{users}->findUser( $$row{username} ));
                }
                return @userList;
            }
            $this->{error} = 'Login invalid';
            return 0;
    } else {
        $this->{error} = 'No user';
	    return 0;
    }
     
}

#returns an array of user objects that relate to a email address
sub findUserByEmail {
    my $this = shift;
    my $email = shift;

    if( $email ) {
            my $dataset = $this->dbSelect('select * from jos_users where email = ?', $email );
            if( exists $$dataset[0] ) {
                my @userList = ();
                for my $row (@$dataset) {
                    push(@userList, $this->{session}->{users}->findUser( $$row{username} ));
                }
                return @userList;
            }
            $this->{error} = 'Login invalid';
            return 0;
    } else {
        $this->{error} = 'No user';
        return 0;
    }
}

sub encrypt {
    my ( $this, $user, $passwd, $fresh ) = @_;

    ASSERT($this->isa( 'TWiki::Users::JoomlaUserMapping')) if DEBUG;

	my $toEncode= "$passwd";
	return Digest::MD5::md5_hex( $toEncode );
}

sub fetchPass {
    my ( $this, $user ) = @_;
    ASSERT($this->isa( 'TWiki::Users::JoomlaUserMapping')) if DEBUG;
print STDERR "fetchPass($user)";    
    

    if( $user ) {
            my $dataset = $this->dbSelect('select * from jos_users where username = ?', $user );
            #$this->{session}->writeWarning("$@$dataset");  
print STDERR "fetchpass got - ".join(', ', keys(%{$$dataset[0]}))."aa";          
            if( exists $$dataset[0] ) {
print STDERR "fetchPass($user, ".$$dataset[0]{password}.")"; 
                return $$dataset[0]{password};
            }
            $this->{error} = 'Login invalid';
            return 0;
    } else {
        $this->{error} = 'No user';
        return 0;
    }
}

sub passwd {
    my ( $this, $user, $newUserPassword, $oldUserPassword ) = @_;
    ASSERT($this->isa( 'TWiki::Users::JoomlaUserMapping')) if DEBUG;

    return 1;
}

sub deleteUser {
    my ( $this, $user ) = @_;
    ASSERT($this->isa( 'TWiki::Users::JoomlaUserMapping')) if DEBUG;

    return 1;
}

# $user == login name, not the user object
sub checkPassword {
    my ( $this, $user, $password, $encrypted) = @_;
print STDERR "checkPassword($user, $password, encrypted)";    
    
    ASSERT($this->isa( 'TWiki::Users::JoomlaUserMapping')) if DEBUG;
    my $encryptedPassword;
    if ((defined($encrypted)) && ($encrypted == 1)) {
        $encryptedPassword = $password;
    } else {
        $encryptedPassword = $this->encrypt( $user, $password );
    }

    $this->{error} = undef;

    my $pw = $this->fetchPass( $user );
    # $pw will be 0 if there is no pw

print STDERR "checkPassword( $pw && ($encryptedPassword eq $pw) )";

    return 1 if( $pw && ($encryptedPassword eq $pw) );
    # pw may validly be '', and must match an unencrypted ''. This is
    # to allow for sysadmins removing the password field in .htpasswd in
    # order to reset the password.
    return 1 if ( $pw eq '' && $password eq '' );

    $this->{error} = 'Invalid user/password';
    return 0;
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
    throw Error::Simple(
          'cannot change user passwords using JoomlaUserMapper');

    return $this->{passwords}->setPassword(
        $this->getLoginName( $user ), $newPassU, $oldPassU);
}

sub passwordError {
    my $this = shift;

    return $this->{error};
}

###############################################################################
#DB access methods


#todo: cache DB connections
sub getJoomlaDB {
    my ( $this, $user ) = @_;
    ASSERT($this->isa( 'TWiki::Users::JoomlaUserMapping')) if DEBUG;
    my ( $dbi_dsn, $dbi_user, $dbi_passwd ) = 
            ($TWiki::cfg{Plugins}{JoomlaUser}{DBI_dsn}, 
            $TWiki::cfg{Plugins}{JoomlaUser}{DBI_username}, 
            $TWiki::cfg{Plugins}{JoomlaUser}{DBI_password});

#print STDERR "DBIx::SQLEngine->new( $dbi_dsn, $dbi_user, ...)";
        	
    unless (defined($this->{JoomlaDB})) {
#        $this->{session}->writeWarning("DBIx::SQLEngine->new( $dbi_dsn, $dbi_user, ...)");
        try {
            $this->{JoomlaDB} = DBIx::SQLEngine->new( $dbi_dsn, $dbi_user, $dbi_passwd );
        } catch Error::Simple with {
            $this->{error} = $!;
            $this->{session}->writeWarning("ERROR: DBIx::SQLEngine->new( $dbi_dsn, $dbi_user, ...) : $!");
            die 'MYSQL login error ('.$dbi_dsn.', '.$dbi_user.') '.$!;
        };
    }
    return $this->{JoomlaDB};
}


#returns an ref to an array dataset of rows
#dbSelect(query, @list of params to query)
sub dbSelect {
    my $this = shift;
    my @query = @_;
    my $dataset;

#print STDERR "fetch_select( @query )";

#    $this->{session}->writeWarning("fetch_select( @query )");
    if( @query ) {
        try {
            my $db = $this->getJoomlaDB();
            $dataset = $db->fetch_select(
                sql => [ @query ]);
        } catch Error::Simple with {
            $this->{error} = $!;
print STDERR "            ERROR: fetch_select(@query) : $!";
            $this->{session}->writeWarning("ERROR: fetch_select(@query) : $!");
        };
    }
#    $this->{session}->writeWarning("fetch_select => ".@$dataset);
    return $dataset;
}

=pod

---++ ObjectMethod ASSERT_IS_CANONICAL_USER_ID( $user_id ) -> $boolean

used for debugging to ensure we are actually passing a canonical_id

=cut

sub ASSERT_IS_CANONICAL_USER_ID {
    my( $this, $user_id ) = @_;
#	print STDERR "ASSERT_IS_CANONICAL_USER_ID($user_id)";
#    ASSERT( ($user_id =~/^$this->{mapping_id}-1$/) || ($user_id =~/^$this->{mapping_id}\d+$/) );	#un-signed INT

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

---++ ObjectMethod ASSERT_IS_GROUP_DISPLAY_NAME( $group_display ) -> $boolean

used for debugging to ensure we are actually passing a group display_name (commonly a WikiWord Name)

#TODO: i fear we'll need to make a canonical_group_id too 

=cut

sub ASSERT_IS_GROUP_DISPLAY_NAME {
    my( $this, $group_display ) = @_;
    
}

1;
