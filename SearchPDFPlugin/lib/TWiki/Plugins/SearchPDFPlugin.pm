# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2000-2003 Andrea Sterbini, a.sterbini@flashnet.it
# Copyright (C) 2001-2006 Peter Thoeny, peter@thoeny.org
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
# For licensing info read LICENSE file in the TWiki root.

=pod

---+ package SearchPDFPlugin

This is an empty TWiki plugin. It is a fully defined plugin, but is
disabled by default in a TWiki installation. Use it as a template
for your own plugins; see TWiki.TWikiPlugins for details.

__NOTE:__ To interact with TWiki use ONLY the official API functions
in the TWiki::Func module. Do not reference any functions or
variables elsewhere in TWiki, as these are subject to change
without prior warning, and your plugin may suddenly stop
working.

For increased performance, all handlers except initPlugin are
disabled below. *To enable a handler* remove the leading DISABLE_ from
the function name. For efficiency and clarity, you should comment out or
delete the whole of handlers you don't use before you release your
plugin (or you can put __END__ on a line of it's own and move dead
code below that line; Perl ignores anything after __END__).

__NOTE:__ When developing a plugin it is important to remember that
TWiki is tolerant of plugins that do not compile. In this case,
the failure will be silent but the plugin will not be available.
See %TWIKIWEB%.TWikiPlugins#FAILEDPLUGINS for error messages.

__NOTE:__ Defining deprecated handlers will cause the handlers to be 
listed in %TWIKIWEB%.TWikiPlugins#FAILEDPLUGINS. See
%TWIKIWEB%.TWikiPlugins#Handlig_deprecated_functions
for information on regarding deprecated handlers that are defined for
compatibility with older TWiki versions.

__NOTE:__ When writing handlers, keep in mind that these may be invoked
on included topics. For example, if a plugin generates links to the current
topic, these need to be generated before the afterCommonTagsHandler is run,
as at that point in the rendering loop we have lost the information that we
the text had been included from another topic.

=cut

# change the package name and $pluginName!!!
package TWiki::Plugins::SearchPDFPlugin;

# Always use strict to enforce variable scoping
use strict;

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package.
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $suser $sweb $pluginName $NO_PREFS_IN_TOPIC );

# This should always be $Rev: 12445$ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 12445$';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = 'Dakar';

# Short description of this plugin
# One line description, is shown in the %TWIKIWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION = 'Extacts text from PDF attachments and embeds it in topic';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use preferences
# stored in the plugin topic. This default is required for compatibility with
# older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, use $TWiki::cfg entries set in LocalSite.cfg, or
# if you want the users to be able to change settings, then use standard TWiki
# preferences that can be defined in your Main.TWikiPreferences and overridden
# at the web and topic level.
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'SearchPDFPlugin';

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
    # $TWiki::cfg{Plugins}{EmptyPlugin}{ExampleSetting} = 1;
    # Then recover it like this. Always provide a default in case the
    # setting is not defined in LocalSite.cfg
    my $pdftotextprogram = $TWiki::cfg{Plugins}{SearchPDFPlugin}{PDFtoTextProgram} || 'c:/xpdf/pdftotext.exe %PDFFILE% -';

    $debug = $TWiki::cfg{Plugins}{SearchPDFPlugin}{Debug} || 0;
	
    $suser = $user;

    $sweb = $web;

    # Plugin correctly initialized
    return 1;
}

=pod

---++ afterRenameHandler( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment )

   * =$oldWeb= - name of old web
   * =$oldTopic= - name of old topic (empty string if web rename)
   * =$oldAttachment= - name of old attachment (empty string if web or topic rename)
   * =$newWeb= - name of new web
   * =$newTopic= - name of new topic (empty string if web rename)
   * =$newAttachment= - name of new attachment (empty string if web or topic rename)

This handler is called just after the rename/move/delete action of a web, topic or attachment.

__Since:__ TWiki::Plugins::VERSION = '1.110'

=cut

sub afterRenameHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::afterRenameHandler( " .
                             "$_[0].$_[1] $_[2] -> $_[3].$_[4] $_[5] )" ) if $debug;

	my ( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment ) = @_;

	# Check to see if attachment was a PDF, variable is blank if no attachment changes

	if ( $oldAttachment =~ m\pdf$\ ) {

		# remove META tag from topic

		$oldWeb = $sweb;

    		my ( $meta, $text ) = &TWiki::Func::readTopic( $oldWeb, $oldTopic );			

		# Remove file attachment data from old topic

     		my $fileAttachment = $meta->get( 'ATTACH', $oldAttachment );

     		$meta->remove( 'ATTACH', $oldAttachment );
        		
		TWiki::Func::saveTopic( $oldWeb, $oldTopic, $meta, $text );

	}

}

=pod

---++ afterAttachmentSaveHandler(\%attrHash, $topic, $web, $error )
   * =\%attrHash= - reference to hash of attachment attribute values
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string generated during the save process
This handler is called just after the save action. The attributes hash
will include at least the following attributes:
   * =attachment= => the attachment name
   * =comment= - the comment
   * =user= - the user's TWiki user object

__Since:__ TWiki::Plugins::VERSION = '1.023'

=cut

sub afterAttachmentSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ###   my( $attrHashRef, $topic, $web ) = @_;
    TWiki::Func::writeDebug( "- ${pluginName}::afterAttachmentSaveHandler( $_[2].$_[1] )" ) if $debug;

	my $Attachment = $_[0]->{attachment};

	if ( $Attachment =~ m\pdf$\ ) {

		# write update line to workarea file
		my $filetext = TWiki::Func::readFile( TWiki::Func::getWorkArea(${pluginName}) . "/SearchPDF.txt" );
		
		TWiki::Func::writeDebug( "- ${pluginName}::afterAttachmentSaveHandler( " . TWiki::Func::getWorkArea(${pluginName}) . "/SearchPDF.txt )" ) if $debug;
		
		$filetext .= "$_[2],,,$_[1],,,$Attachment\n";

		TWiki::Func::saveFile( TWiki::Func::getWorkArea(${pluginName}) . "/SearchPDF.txt", $filetext );

	}
}

=pod



---++ afterSaveHandler($text, $topic, $web, $error, $meta )
   * =$text= - the text of the topic _excluding meta-data tags_
     (see beforeSaveHandler)
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$error= - any error string returned by the save.
   * =$meta= - the metadata of the saved topic, represented by a TWiki::Meta object 

This handler is called each time a topic is saved.

__NOTE:__ meta-data is embedded in $text (using %META: tags)

__Since:__ TWiki::Plugins::VERSION = '1.020'

=cut

sub IndexPDF {
    # no input variables

    TWiki::Func::writeDebug( "- ${pluginName}::IndexPDF" ) if $debug;

	my $filetext = TWiki::Func::readFile( TWiki::Func::getWorkArea(${pluginName}) . "/SearchPDF.txt" );

	foreach (split( /\n/, $filetext)) {
		my( $web, $topic, $file) = split( /,,,/, $_);

		TWiki::Func::writeDebug( "- ${pluginName}::IndexPDF( $web $topic $file) " ) if $debug;


	}



#	my $meta = $_[4];

#	my $changed = 0;

#	my @Attachments = $meta->find( 'FILEATTACHMENT' );

#	my $Attachment;

#	foreach $Attachment(@Attachments) {

		# Was attachment an PDF?
	
#		my $Attachfile = $Attachment->{attachment};
    		
#		if ( $Attachfile =~ m\pdf$\ ) {

			# look for attach text in meta data

#			my $attachtext = $meta->get( 'ATTACH', $Attachfile ) || '';

			# if no attachtext then generate it

#			if ( $attachtext eq '' ) {

				# run pdftotext program
#				$attachtext = 'Test text';


				# clean up text (remove spaces and change to lowercase letters and numbers only)


				# write meta data to topic file


 #               		$meta->putKeyed( 'ATTACH',
  #                          {
   #                          name    => $Attachfile,
    #                         value    => $attachtext
     #                       });

#				$changed = 1;

#			}
		
#		}

#	}

#	Twiki::Func::SaveTopic( $_[2], $_[1], $meta, $_[0] ) 	if ($changed == 1);

}

=pod


1;
