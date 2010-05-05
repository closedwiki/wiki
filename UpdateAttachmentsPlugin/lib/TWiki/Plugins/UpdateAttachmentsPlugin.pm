# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2007 Sven Dovideit.
# Copyright (C) 2007-2010 TWiki Contributor. All Rights Reserved.
# TWiki Contributors are listed in the AUTHORS file in the root of
# this distribution.
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

=pod

---+ package TWiki::Plugins::UpdateAttachmentsPlugin

To interact with TWiki use ONLY the official API functions
in the TWiki::Func module. Do not reference any functions or
variables elsewhere in TWiki, as these are subject to change
without prior warning, and your plugin may suddenly stop
working.

For increased performance, all handlers except initPlugin are
disabled below. *To enable a handler* remove the leading DISABLE_ from
the function name. For efficiency and clarity, you should comment out or
delete the whole of handlers you don't use before you release your
plugin.

__NOTE:__ When developing a plugin it is important to remember that
TWiki is tolerant of plugins that do not compile. In this case,
the failure will be silent but the plugin will not be available.
See %SYSTEMWEB%.TWikiPlugins#FAILEDPLUGINS for error messages.

__NOTE:__ Defining deprecated handlers will cause the handlers to be 
listed in %SYSTEMWEB%.TWikiPlugins#FAILEDPLUGINS. See
%SYSTEMWEB%.TWikiPlugins#Handlig_deprecated_functions
for information on regarding deprecated handlers that are defined for
compatibility with older TWiki versions.

__NOTE:__ When writing handlers, keep in mind that these may be invoked
on included topics. For example, if a plugin generates links to the current
topic, these need to be generated before the afterCommonTagsHandler is run,
as at that point in the rendering loop we have lost the information that we
the text had been included from another topic.

=cut


package TWiki::Plugins::UpdateAttachmentsPlugin;

# Always use strict to enforce variable scoping
use strict;

use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC );

$VERSION = '$Rev$';
$RELEASE = '2010-05-04';
$SHORTDESCRIPTION = 'Add and remove attachments in batch mode';
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'UpdateAttachmentsPlugin';

=pod

---++ initPlugin($topic, $web, $user, $installWeb) -> $boolean
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$user= - the login name of the user
   * =$installWeb= - the name of the web the plugin is installed in

REQUIRED

Called to initialise the plugin. If everything is OK, should return
a non-zero value. On non-fatal failure, should write a message
using TWiki::Func::writeWarning and return 0. In this case
%FAILEDPLUGINS% will indicate which plugins failed.

In the case of a catastrophic failure that will prevent the whole
installation from working safely, this handler may use 'die', which
will be trapped and reported in the browser.

You may also call =TWiki::Func::registerTagHandler= here to register
a function to handle variables that have standard TWiki syntax - for example,
=%MYTAG{"my param" myarg="My Arg"}%. You can also override internal
TWiki variable handling functions this way, though this practice is unsupported
and highly dangerous!

__Note:__ Please align variables names with the Plugin name, e.g. if 
your Plugin is called FooBarPlugin, name variables FOOBAR and/or 
FOOBARSOMETHING. This avoids namespace issues.


=cut

sub initPlugin {
    my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $TWiki::Plugins::VERSION < 1.026 ) {
        TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
        return 0;
    }
    
    # Example code of how to get a preference value, register a variable handler
    # and register a RESTHandler. (remove code you do not need)

    # Set plugin preferences in LocalSite.cfg, like this:
    # $TWiki::cfg{Plugins}{UpdateAttachmentsPlugin}{ExampleSetting} = 1;
    # Always provide a default in case the setting is not defined in
    # LocalSite.cfg. See TWiki.TWikiPlugins for help in adding your plugin
    # configuration to the =configure= interface.
    my $setting = $TWiki::cfg{Plugins}{UpdateAttachmentsPlugin}{ExampleSetting} || 0;
    $debug = $TWiki::cfg{Plugins}{UpdateAttachmentsPlugin}{Debug} || 0;

    # register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    # This will be called whenever %EXAMPLETAG% or %EXAMPLETAG{...}% is
    # seen in the topic text.
    #TWiki::Func::registerTagHandler( 'EXAMPLETAG', \&_EXAMPLETAG );

    # Allow a sub to be called from the REST interface 
    # using the provided alias
    TWiki::Func::registerRESTHandler('update', \&restUpdate);

    # Plugin correctly initialized
    return 1;
}

=pod

---++ restExample($session) -> $text

This is an example of a sub to be called by the =rest= script. The parameter is:
   * =$session= - The TWiki object associated to this session.

Additional parameters can be recovered via de query object in the $session.

For more information, check TWiki:TWiki.TWikiScripts#rest

*Since:* TWiki::Plugins::VERSION 1.1

to update the Sandbox web
   * %SCRIPTURL{rest}%/UpdateAttachmentsPlugin/update?topic=Sandbox.WebHome
Or using a cronjob - make sure the cronjob is running as the same user as twiki's web access is
   * =./rest UpdateAttachmentsPlugin.update topic Sandbox.WebHome =


=cut

sub restUpdate {
    my $session = shift;
    my $store = $session->{store};
    my $web = $session->{webName};
  
    print STDERR "update the attachments of $web\n" if $debug;
    
    #force autoattach off, as we need to know the real META
    $TWiki::cfg{AutoAttachPubFiles} = 0;
    
    #TODO: consider the lighter weight aproach of scanning timestamps in the pub dir
    #      checking&updating only those topics that have newer timestamp pub files
    #      (it would only helps adding attachments, not removing them)
    
    my $topicsTested = 0;
    my $topicsUpdated = 0;
    my $attachmentsRemoved = 0;
    my $attachmentsIgnored = 0;
    #TODO: test user's access to web (rest already tests for web CHANGE access)
    my @topicNames = TWiki::Func::getTopicList( $web );
    foreach my $topic (@topicNames) {
        # test user's permission on this topic (do this first, eventually this check may not read the topic.. for now it will populate the cache)
        next if (!TWiki::Func::checkAccessPermission( 'CHANGE', TWiki::Func::getWikiName(), undef, $topic, $web ));

        my( $meta, $text ) = TWiki::Func::readTopic( $web, $topic );
        my @knownAttachments = $meta->find('FILEATTACHMENT');
        my @attachmentsFoundInPub = TWiki::Store::_findAttachments($store, $web, $topic, \@knownAttachments);
        
        my $changed = 0;
        
        #new or updated file
        foreach my $foundAttachment (@attachmentsFoundInPub) {
            my ( $fileName, $origName ) =
                TWiki::Sandbox::sanitizeAttachmentName( $foundAttachment->{name} );
            #ignore filenames that would need to be renamed
            if ($fileName ne $origName) {
                print STDERR "ERROR: UpdateAttachments: ignoring $origName, in $web.$topic - not a valid TWiki Attachment filename";
                $attachmentsIgnored++;
                next;
            }

            #default attachment owner to {AttachAsUser}
            if ((defined($TWiki::cfg{Plugins}{UpdateAttachmentsPlugin}{AttachAsUser})) &&
                ($TWiki::cfg{Plugins}{UpdateAttachmentsPlugin}{AttachAsUser} ne '')) {
                $foundAttachment->{user} = $TWiki::cfg{Plugins}{UpdateAttachmentsPlugin}{AttachAsUser};
                #4.2.0 falls back and works if WikiName there.
                #TODO: needs testing for the generalised usermapping case - shoudl store cUID
            }

            my $existingFile = $meta->get( 'FILEATTACHMENT', $foundAttachment->{name} );
            if ( !$existingFile ) {
                #if its not in @knownAttachments, add it
                $meta->putKeyed('FILEATTACHMENT', $foundAttachment );
                $changed = 1;
            } else {
                #if its @knownAttachments, update _if_ attr's have changed
                if (
                    (!defined($existingFile->{user})) || ($foundAttachment->{user} ne $existingFile->{user}) ||
                    (!defined($existingFile->{date})) || ($foundAttachment->{date} ne $existingFile->{date}) ||
                    (!defined($existingFile->{attr})) || ($foundAttachment->{attr} ne $existingFile->{attr}) ||
                    (!defined($existingFile->{size})) || ($foundAttachment->{size} != $existingFile->{size})
                   ){
                    $foundAttachment->{comment} = $existingFile->{comment};
                    $foundAttachment->{attr} = $existingFile->{attr};
                    #if attached by a real user, keep them.
                    if ((defined($existingFile->{user})) && (      # the default from 4.2.0 onwards
                        ($existingFile->{user} ne '') &&            
                        ($existingFile->{user} ne 'UnknownUser')    # the 4.1.2 autoattach default
                        )) {
                        $foundAttachment->{user} = $existingFile->{user};
                    }

                    $meta->putKeyed('FILEATTACHMENT', $foundAttachment );
                    $changed = 1;
                }
            }
        }
        #RemoveMissing
        if ( defined($TWiki::cfg{Plugins}{UpdateAttachmentsPlugin}{RemoveMissing}) &&
           ($TWiki::cfg{Plugins}{UpdateAttachmentsPlugin}{RemoveMissing} == 1)) {
            foreach my $knownAttachment (@knownAttachments) {
                #if not in @attachmentsFoundInPub, remove from @knownAttachments
                if (!grep(/$knownAttachment->{name}/,
                        map( {$_->{name}} @attachmentsFoundInPub)
                          ) ) {
                    $meta->remove('FILEATTACHMENT', $knownAttachment->{name} );
                    $changed = 1;
                    $attachmentsRemoved++;
                }
            }
        }

        #TODO: actually test that they are the same! (update size, date etc)
        #print STDERR "$web.$topic has ".scalar(@knownAttachments)." in meta, ".scalar(@attachmentsFoundInPub)." in pub dir\n" if $debug;
        if ($changed) {
            if ( defined($TWiki::cfg{Plugins}{UpdateAttachmentsPlugin}{UseDangerousNoHandlersSave}) &&
                ($TWiki::cfg{Plugins}{UpdateAttachmentsPlugin}{UseDangerousNoHandlersSave} == 1)) {
                #can I leave the user = undef?
                $session->{store}->_noHandlersSave( $TWiki::Plugins::SESSION->{user}, $web, $topic, $text, $meta, { comment => 'UpdateAttachments' } );
            } else {
                TWiki::Func::saveTopic( $web, $topic, $meta, $text, { comment => 'UpdateAttachments' } );
            }
            print STDERR "updating the attachments of $web.$topic\n" if $debug;
            $topicsUpdated++;
        }
        $topicsTested++;
        #TODO: $TWiki::cfg{Plugins}{UpdateAttachmentsPlugin}{BatchLimit}
    }

    print STDERR "UpdateAttachments checked $topicsTested, updated $topicsUpdated, removed $attachmentsRemoved attachments, $attachmentsIgnored ignored" if $debug;
    return "UpdateAttachments checked $topicsTested, updated $topicsUpdated, removed $attachmentsRemoved attachments, $attachmentsIgnored ignored";
}

1;
