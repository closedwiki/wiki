# TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 1999-2005 Peter Thoeny, peter@thoeny.com
# and TWiki Contributors. All Rights Reserved. TWiki Contributors
# are listed in the AUTHORS file in the root of this distribution.
# NOTE: Please extend that file, not this notice.
#
# Additional copyrights apply to some or all of the code in this
# file as follows:
# Based on parts of Ward Cunninghams original Wiki and JosWiki.
# Copyright (C) 1998 Markus Peter - SPiN GmbH (warpi@spin.de)
# Some changes by Dave Harris (drh@bhresearch.co.uk) incorporated
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

---+ package TWiki::UI::Save

UI delegate for save function

=cut

package TWiki::UI::Save;

use strict;
use TWiki;
use TWiki::UI;
use Error qw( :try );
use TWiki::OopsException;
use TWiki::Merge;
use TWiki::Merge3;
use Assert;

# Used by save and preview
sub buildNewTopic {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};
    my $store = $session->{store};

    TWiki::UI::checkMirror( $session, $webName, $topic );
    TWiki::UI::checkWebExists( $session, $webName, $topic, 'save' );

    my $topicExists  = $store->topicExists( $webName, $topic );

    # Prevent saving existing topic?
    my $onlyNewTopic = $query->param( 'onlynewtopic' ) || '';
    if( $onlyNewTopic && $topicExists ) {
        # Topic exists and user requested oops if it exists
        throw TWiki::OopsException( 'attention',
                                    def => 'topic_exists',
                                    web => $webName,
                                    topic => $topic );
    }

    # prevent non-Wiki names?
    my $onlyWikiName = $query->param( 'onlywikiname' ) || '';
    if( ( $onlyWikiName )
          && ( ! $topicExists )
            && ( ! TWiki::isValidTopicName( $topic ) ) ) {
        # do not allow non-wikinames, redirect to view topic
        # SMELL: this should be an oops, shouldn't it?
        $session->redirect( $session->getScriptUrl( $webName, $topic, 'view' ) );
        return 0;
    }

    my $user = $session->{user};
    TWiki::UI::checkAccess( $session, $webName, $topic,
                            'change', $user );

    my $saveOpts = {};
    $saveOpts->{minor} = 1 if $query->param( 'dontnotify' );
    my $originalrev = $query->param( 'originalrev' ); # rev edit started on

    # Populate the new meta data
    my $newMeta = new TWiki::Meta( $session, $webName, $topic );

    my ( $prevMeta, $prevText );
    my ( $templateText, $templateMeta );
    my $templatetopic = $query->param( 'templatetopic');
    if( $topicExists ) {
        ( $prevMeta, $prevText ) =
          $store->readTopic( undef, $webName, $topic, undef );
        if( $prevMeta ) {
            foreach my $k ( keys %$prevMeta ) {
                unless( $k =~ /^_/ || $k eq 'FORM' || $k eq 'TOPICPARENT' ||
                          $k eq 'FIELD' ) {
                    $newMeta->copyFrom( $prevMeta, $k );
                }
            }
        }
    } elsif ($templatetopic) {
        ( $templateMeta, $templateText ) =
          $store->readTopic( $session->{user}, $webName,
                             $templatetopic, undef );
        $templateText = '' if $query->param( 'newtopic' ); # created by edit
        $templateText =
          $session->expandVariablesOnTopicCreation( $templateText );
        foreach my $k ( keys %$templateMeta ) {
            unless( $k =~ /^_/ || $k eq 'FORM' || $k eq 'TOPICPARENT' ||
                      $k eq 'FIELD' ) {
                $newMeta->copyFrom( $templateMeta, $k );
            }
        }
        # topic creation, there is no original rev
        $originalrev = 0;
    }

    # Determine the new text
    my $newText = $query->param( 'text' );
    # HTTP uses CRLF, so remove the CRs
    $newText =~ s/\r//g if $newText;

    if( defined( $newText) ) {
        # text from the query
    } elsif( defined $templateText ) {
        $newText = $templateText;
        $originalrev = 0; # disable merge
    } elsif( defined $prevText ) {
        $newText = $prevText;
        $originalrev = 0; # disable merge
    } else {
        $newText = '';
    }

    # note: always force a new rev if the topic is empty, in case this
    # is a mistake.
    $saveOpts->{forcenewrevision} = 1
      if( $query->param( 'forcenewrevision' ) || !$newText );

    my $newParent = $query->param( 'topicparent' ) || '';
    my $mum;
    if( $newParent ) {
        if( $newParent ne 'none' ) {
            $mum = { 'name' => $newParent };
        }
    } elsif( $templateMeta ) {
        $mum = $templateMeta->get( 'TOPICPARENT' );
    } elsif( $prevMeta ) {
        $mum = $prevMeta->get( 'TOPICPARENT' );
    }
    $newMeta->put( 'TOPICPARENT', $mum ) if $mum;

    my $formName = $query->param( 'formtemplate' );
    my $formDef;
    my $copyMeta;

    if( $formName ) {
        # new form, default field values will be null
        $formName = '' if( $formName eq 'none' );
    } elsif( $templateMeta ) {
        # populate the meta-data with field values from the template
        $formName = $templateMeta->get( 'FORM' );
        $formName = $formName->{name} if $formName;;
        $copyMeta = $templateMeta;
    } elsif( $prevMeta ) {
        # populate the meta-data with field values from the existing topic
        $formName = $prevMeta->get( 'FORM' );
        $formName = $formName->{name} if $formName;;
        $copyMeta = $prevMeta;
    }

    if( $formName ) {
        $formDef = new TWiki::Form( $session, $webName, $formName );
        unless( $formDef ) {
            throw TWiki::OopsException( 'attention',
                                        def => 'no_form_def',
                                        web => $session->{webName},
                                        topic => $session->{topicName},
                                        params => [ $webName, $formName ] );
        }
        $newMeta->put( 'FORM', { name => $formName });
    }
    if( $copyMeta && $formDef ) {
        # Copy existing fields into new form, filtering on the
        # known field names so we don't copy dead data. Though we
        # really should, of course. That comes later.
        my $filter = join(
            '|',
            map { $_->{name} }
              grep { $_->{name} } @{$formDef->{fields}} );
        $newMeta->copyFrom( $copyMeta, 'FIELD', qr/^($filter)$/ );
    }
    if( $formDef ) {
        # override with values from the query
        $formDef->getFieldValuesFromQuery( $query, $newMeta, 1 );
    }

    my $merged;
    # assumes rev numbers start at 1
    if ( $originalrev ) {
        my ( $date, $author, $rev ) = $newMeta->getRevisionInfo();
        # If the last save was by me, don't merge
        if ( $rev ne $originalrev && !$author->equals( $user )) {
            # the new three-way code
            my ( $ancestorMeta, $ancestorText ) =
              $store->readTopic( undef, $webName, $topic, $originalrev );
            $newText = TWiki::Merge3::merge(
                $ancestorText, $prevText, $newText,
                $originalrev, $rev, "new",
                '\r?\n' );
            if( $formDef && $prevMeta ) {
                $newMeta->merge( $prevMeta, $formDef );
            }

            $merged = [ $originalrev, $author->stringify(), $rev ];
        }
    }

    return( $newMeta, $newText, $saveOpts, $merged );
}

# Private - do not call outside this module!
# Returns 1 if caller should redirect to view when done
# 0 otherwise (redirect has already been handled)
sub _save {
    my $session = shift;

    $session->enterContext( 'save' );

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};
    my $store = $session->{store};

    my $saveCmd = $query->param( 'cmd' ) || 0;
    if ( $saveCmd && ! $session->{user}->isAdmin()) {
        throw TWiki::OopsException( 'accessdenied', def => 'only_group',
                                    web => $webName, topic => $topic,
                                    params => $TWiki::cfg{UsersWebName}.
                                      '.'.$TWiki::cfg{SuperAdminGroup} );
    }

    my $user = $session->{user};

    if( $saveCmd eq 'delRev' ) {
        # delete top revision
        try {
            $store->delRev( $user, $webName, $topic );
        } catch Error::Simple with {
            throw TWiki::OopsException( 'attention',
                                        def => 'save_error',
                                        web => $webName,
                                        topic => $topic,
                                        params => shift->{-text} );
        };

        return 1;
    }

    if( $saveCmd eq 'repRev' ) {
        # replace top revision with the text from the query, trying to
        # make it look as much like the original as possible. The query
        # text is expected to contain %META as well as text.
        my $textQueryParam = $query->param( 'text' );
        my $meta = new TWiki::Meta( $session, $webName, $topic );
        $store->extractMetaData( $meta, \$textQueryParam );
        my $saveOpts = { timetravel => 1 };
        try {
            $store->repRev( $user, $webName, $topic,
                            $textQueryParam, $meta, $saveOpts );
        } catch Error::Simple with {
            throw TWiki::OopsException( 'attention',
                                        def => 'save_error',
                                        web => $webName,
                                        topic => $topic,
                                        params => shift->{-text} );
        };

        return 1;
    }

    my( $newMeta, $newText, $saveOpts, $merged ) =
      TWiki::UI::Save::buildNewTopic($session);

    try {
        $store->saveTopic( $user, $webName, $topic,
                           $newText, $newMeta, $saveOpts );
    } catch Error::Simple with {
        throw TWiki::OopsException( 'attention',
                                    def => 'save_error',
                                    web => $webName,
                                    topic => $topic,
                                    params => shift->{-text} );
    };

    my $lease = $store->getLease( $webName, $topic );
    # clear the lease, if (and only if) we own it
    if( $lease && $lease->{user}->equals( $user )) {
        $store->clearLease( $webName, $topic );
    }

    if( $merged ) {
        throw TWiki::OopsException( 'attention',
                                    def => 'merge_notice',
                                    web => $webName, topic => $topic,
                                    params => $merged );
    }

    return 1;
}

=pod

---++ StaticMethod save($session)

Command handler for =save= command.
This method is designed to be
invoked via the =TWiki::UI::run= method.

See TWiki.TWikiScripts for details of parameters.

Note: =cmd= has been deprecated in favour of =action=. It will be deleted at
some point.

=cut

sub save {
    my $session = shift;

    my $query = $session->{cgiQuery};
    my $webName = $session->{webName};
    my $topic = $session->{topicName};
    my $store = $session->{store};
    my $user = $session->{user};

    #
    # Allow for dynamic topic creation by replacing strings of at least
    # 10 x's XXXXXX with a next-in-sequence number.
    # http://twiki.org/cgi-bin/view/Codev/AllowDynamicTopicNameCreation
    #
    if ( $topic =~ /X{10}/ ) {
		my $n = 0;
		my $baseTopic = $topic;
		$store->clearLease( $webName, $baseTopic );
		do {
			$topic = $baseTopic;
			$topic =~ s/X{10}X*/$n/e;
			$n++;
		} while( $store->topicExists( $webName, $topic ));
        $session->{topicName} = $topic;
    }

    my $redirecturl = $session->getScriptUrl( $session->normalizeWebTopicName($webName, $topic), 'view' );

    my $saveaction = '';
    foreach my $action qw( save checkpoint quietsave cancel preview
                           addform replaceform delRev repRev ) {
        if ($query->param('action_' . $action)) {
            $saveaction = $action;
            last;
        }
    }

    # the 'action' parameter has been deprecated, though is still available
    # for compatibility with old templates.
    if( !$saveaction && $query->param( 'action' )) {
        $saveaction = lc($query->param( 'action' ));
        $session->writeWarning('Use of deprecated "action" parameter to "save". Correct your templates!');

        # handle old values for form-related actions:
        $saveaction = 'addform' if ( $saveaction eq 'add form');
        $saveaction = 'replaceform' if ( $saveaction eq 'replace form...');
    }

    my $editaction = lc($query->param( 'editaction' )) || '';

    if( $saveaction eq 'checkpoint' ) {
        $query->param( -name=>'dontnotify', -value=>'checked' );
        my $editURL = $session->getScriptUrl( $webName, $topic, 'edit' );
        $redirecturl = $editURL.'?t='.time();
        $redirecturl .= '&action='.$editaction if $editaction;
        $redirecturl .= '&skin='.$query->param('skin') if $query->param('skin');
        $redirecturl .= '&cover='.$query->param('cover') if $query->param('cover');
        my $lease = $store->getLease( $webName, $topic );
        if( $lease && $lease->{user}->equals( $user )) {
            $store->setLease( $webName, $topic, $user,
                              $TWiki::cfg{LeaseLength} );
        }

    } elsif( $saveaction eq 'quietsave' ) {
        $query->param( -name=>'dontnotify', -value=>'checked' );

    } elsif( $saveaction eq 'cancel' ) {
        my $lease = $store->getLease( $webName, $topic );
        if( $lease && $lease->{user}->equals( $user )) {
            $store->clearLease( $webName, $topic );
        }

	# redirect to a sensible place (a topic that exists)
	my $viewURL;
	# check that the page already exist before redirecting to it
	if ( $store->topicExists( $webName, $topic ) ) {
	    $viewURL = $session->getScriptUrl( $webName, $topic, 'view' ) . '?unlock=on';
	} elsif ( $query->param( 'topicparent' ) &&
		 $store->topicExists( $webName, $query->param('topicparent') ) ) { # go to parent
	    $viewURL = $session->getScriptUrl( $webName, $query->param( 'topicparent' ), 'view' );
	} else { # last resort: web home
	    $viewURL = $session->getScriptUrl( $webName, $TWiki::cfg{HomeTopicName}, 'view' );
	}
        $session->redirect( $viewURL );

        return;

    } elsif( $saveaction =~ /^(del|rep)Rev$/ ) {
        # hidden, largely undocumented functions, used by administrators for
        # reverting spammed topics. These functions constitute editing
        # history, in a Joe Stalin kind of way. The should be replaced with
        # mechanisms for hiding revisions, but are retained purely for
        # compatibility with Cairo.
        $query->param( -name => 'cmd', -value => $saveaction );

    } elsif( $saveaction eq 'addform' ||
               $saveaction eq 'replaceform' ||
                 $saveaction eq 'preview' && $query->param( 'submitChangeForm' )) {
        require TWiki::UI::ChangeForm;
        $session->writeCompletePage
          ( TWiki::UI::ChangeForm::generate( $session, $webName,
                                             $topic, $editaction ) );
        return;

    } elsif( $saveaction eq 'preview' ) {
        require TWiki::UI::Preview;
        TWiki::UI::Preview::preview( $session );
        return;
    }

    if ( _save( $session )) {
        $session->redirect( $redirecturl );
    }
}

1;
