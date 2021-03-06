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

---+ package PerforcePlugin

This is an empty TWiki plugin. It is a fully defined plugin, but is
disabled by default in a TWiki installation. Use it as a template
for your own plugins; see TWiki.TWikiPlugins for details.

This version of the !PerforcePlugin documents the handlers supported
by revision 1.2 of the Plugins API. See the documentation of =TWiki::Func=
for more information about what this revision number means, and how a
plugin can check it.

__NOTE:__ To interact with TWiki use ONLY the official API functions
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
package TWiki::Plugins::PerforcePlugin;

# Always use strict to enforce variable scoping
use strict;

require TWiki::Func;    # The plugins API
require TWiki::Plugins; # For the API version

# $VERSION is referred to by TWiki, and is the only global variable that
# *must* exist in this package.
use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC $p4port $p4client $p4user $p4password);

# This should always be $Rev: 15942 (22 Jan 2008) $ so that TWiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 15942 (22 Jan 2008) $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '0.8';

# Short description of this plugin
# One line description, is shown in the %TWIKIWEB%.TextFormattingRules topic:
$SHORTDESCRIPTION = 'PerforcePlugin allows you to perform operation on a remote Perforce server';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use preferences
# stored in the plugin topic. This default is required for compatibility with
# older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, use $TWiki::cfg entries set in LocalSite.cfg, or
# if you want the users to be able to change settings, then use standard TWiki
# preferences that can be defined in your Main.TWikiPreferences and overridden
# at the web and topic level.
$NO_PREFS_IN_TOPIC = 1;

# Name of this Plugin, only used in this module
$pluginName = 'PerforcePlugin';

#
#TODO: use that to test if a plugin is installed. Could be useful if we want to make use of JQueryPlugin
#
#eval "require TWiki:Plugins:OtherPlugin"; if $@ { print STDERR "Not installed" }
#if ($TWiki::cfg{Plugins}{OtherPlugin}{Enabled}) { print STDERR "it's enabled" }
#


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
    # $TWiki::cfg{Plugins}{PerforcePlugin}{ExampleSetting} = 1;
    # Always provide a default in case the setting is not defined in
    # LocalSite.cfg. See TWiki.TWikiPlugins for help in adding your plugin
    # configuration to the =configure= interface.
    my $setting = $TWiki::cfg{Plugins}{PerforcePlugin}{ExampleSetting} || 0;
    $debug = $TWiki::cfg{Plugins}{PerforcePlugin}{Debug} || 0;
    
    $p4port = $TWiki::cfg{Plugins}{PerforcePlugin}{p4port} || undef;
	$p4client = $TWiki::cfg{Plugins}{PerforcePlugin}{p4client} || undef;
	$p4user = $TWiki::cfg{Plugins}{PerforcePlugin}{p4user} || undef;
	$p4password = $TWiki::cfg{Plugins}{PerforcePlugin}{p4password} || undef;
    
	unless (defined($p4password) && defined($p4port) && defined($p4client) && defined($p4user) )
		{
		TWiki::Func::writeWarning("{Plugins}{PerforcePlugin}{p4port}, {Plugins}{PerforcePlugin}{p4client}, {Plugins}{PerforcePlugin}{p4user} and {Plugins}{PerforcePlugin}{p4password} must be defined in LocalSite.cfg\n");	
		return 0;
		}
	
    # register the _EXAMPLETAG function to handle %EXAMPLETAG{...}%
    # This will be called whenever %EXAMPLETAG% or %EXAMPLETAG{...}% is
    # seen in the topic text.
    TWiki::Func::registerTagHandler( 'P4CHANGES', \&_P4CHANGES );
    TWiki::Func::registerTagHandler( 'P4CHANGESPI', \&_P4CHANGESPI );
    
    # Allow a sub to be called from the REST interface 
    # using the provided alias
    #TODO: use rest interface for ajax support
    TWiki::Func::registerRESTHandler('p4changes', \&restP4CHANGES);
    TWiki::Func::registerRESTHandler('p4changespi', \&restP4CHANGESPI);

    # Plugin correctly initialized
    return 1;
}

# The function used to handle the %EXAMPLETAG{...}% variable
# You would have one of these for each variable you want to process.

=pod

TWiki TAG specific functionality.

=cut

sub _P4CHANGES
	{
    my($session, $params, $theTopic, $theWeb) = @_;   
    
    my $ajax=$params->{ajax};
    my $label=$params->{label};
    $label='Fetch perforce changes' unless defined($label);
    my $format=$params->{format};
    my $default=$params->{_DEFAULT};
    my $footer=$params->{footer};
    my $header=$params->{header};    
    my $method=$params->{method} || 'POST';    
        
    #If asked for ajax services we don't run the actual p4 command now 	    
    if (defined $ajax)
    	{
		#Resolving some substitutions for header and footer here implies it will be done twice since it will be done again in P4Changes sub through the rest interface
		#However we must resolve things like the $quot to allow HTML and JS in footer for instance
		#TODO: Can't get the footer and header param to work properly with ajax
    	#if (defined $header)
		#	{
		#	$header=EarlyVariableSubstitution($header);			
		#	}
		
		#	
		#if (defined $footer)
			#{
			#die "FOOTER: $footer";	
			#$footer=EarlyVariableSubstitution($footer);
			##$footer=UrlEncode($footer);					
			#}		    	
	    
		#die "FOOTER: $footer";	

		my $output="";
				
		if ($method eq 'GET')
			{
		
			#URL encode the URL parameters
			$default=TWiki::urlEncode($default);
			$format=TWiki::urlEncode($format);
			$footer=TWiki::urlEncode($footer);
			$header=TWiki::urlEncode($header);
			
			$output="<input type=\"button\" value=\"$label\" onclick=\"\$('#$ajax').load('%SCRIPTURLPATH%/rest/PerforcePlugin/p4changes?header=$header&footer=$footer&topic=%WEB%.%TOPIC%&_DEFAULT=$default&format=$format', {}, function(){\$('#$ajax').show('slow');})\"/><div style=\"display: none\" id=\"$ajax\"></div>";			
			}
		else
			{							    	
	    	#By default use POST
	    	my $jsHash="{ topic:'%WEB%.%TOPIC%' , _DEFAULT: '$default' , format: '$format', header: '$header' , footer: '$footer' }";
						
			$output="<input type=\"button\" value=\"$label\" onclick=\"\$('#$ajax').load('%SCRIPTURLPATH%/rest/PerforcePlugin/p4changes', $jsHash, function(){\$('#$ajax').show('slow');})\"/><div style=\"display: none\" id=\"$ajax\"></div>";				
    		}
    		
	   	#die $output;	    		
	   	return "$output";
    	}
    
    return handleP4Changes(@_);    
    }
    
    
=pod

---++ restP4CHANGES($session) -> $text

This is an example of a sub to be called by the =rest= script. The parameter is:
   * =$session= - The TWiki object associated to this session.

Additional parameters can be recovered via de query object in the $session.

For more information, check TWiki:TWiki.TWikiScripts#rest

*Since:* TWiki::Plugins::VERSION 1.1

=cut


sub restP4CHANGES 
	{
   	my ($session) = @_;   
   	my $query = TWiki::Func::getCgiQuery();
   	
   	my %params;
   	
   	$params{'_DEFAULT'}=$query->param('_DEFAULT');
   	$params{'format'}=$query->param('format');   	
	$params{'footer'}=$query->param('footer');
   	$params{'header'}=$query->param('header');   	
    
   	#return "This is an example of a REST invocation\n\n";   	
   	#return "$params{'_DEFAULT'}\n$params{'format'}\n\n";
   	
   	my $output=handleP4Changes($session,\%params);
   	
   	$output=TWiki::Func::expandCommonVariables($output);  
   	$output=TWiki::Func::renderText($output);
   	
   	return "$output\n\n";	   		
	#return "This is an example of a REST invocation\n\n";
	}	


=pod

Gather changes pending for integration from the given branch specification

=cut

sub _P4CHANGESPI
	{
    my($session, $params, $theTopic, $theWeb) = @_;   
    
    my $ajax=$params->{ajax};
    my $label=$params->{label};
    $label='Fetch perforce changes' unless defined($label);
    my $format=$params->{format};
    my $default=$params->{_DEFAULT};
    my $footer=$params->{footer};
    my $header=$params->{header};    
    my $reverse=$params->{reverse};
    my $description=$params->{description};
    my $method=$params->{method} || 'POST';    
        
    #If asked for ajax services we don't run the actual p4 command now 	    
    if (defined $ajax)
    	{
		my $output="";
				
		if ($method eq 'GET')
			{
		
			#URL encode the URL parameters
			$default=TWiki::urlEncode($default);
			$format=TWiki::urlEncode($format);
			$footer=TWiki::urlEncode($footer);
			$header=TWiki::urlEncode($header);
			
			$output="<input type=\"button\" value=\"$label\" onclick=\"\$('#$ajax').load('%SCRIPTURLPATH%/rest/PerforcePlugin/p4changespi?reverse=$reverse&description=$description&header=$header&footer=$footer&topic=%WEB%.%TOPIC%&_DEFAULT=$default&format=$format', {}, function(){\$('#$ajax').show('slow');})\"/><div style=\"display: none\" id=\"$ajax\"></div>";			
			}
		else
			{							    	
	    	#By default use POST
	    	my $jsHash="{ topic:'%WEB%.%TOPIC%' , _DEFAULT: '$default' , format: '$format', header: '$header' , footer: '$footer', description: '$description', reverse: '$reverse' }";
						
			$output="<input type=\"button\" value=\"$label\" onclick=\"\$('#$ajax').load('%SCRIPTURLPATH%/rest/PerforcePlugin/p4changespi', $jsHash, function(){\$('#$ajax').show('slow');})\"/><div style=\"display: none\" id=\"$ajax\"></div>";				
    		}
    		
	   	#die $output;	    		
	   	return "$output";
    	}
    
    return handleP4ChangesPendingIntegration(@_);    		
	}

	
##############################################
	
=pod

---++ restP4CHANGESPI($session) -> $text

=cut


sub restP4CHANGESPI 
	{
   	my ($session) = @_;   
   	my $query = TWiki::Func::getCgiQuery();
   	
   	my %params;
   	
   	#Just pass on the following parameter
   	$params{'_DEFAULT'}=$query->param('_DEFAULT');
   	$params{'format'}=$query->param('format');   	
	$params{'footer'}=$query->param('footer');
   	$params{'header'}=$query->param('header');   	
	$params{'description'}=$query->param('description');
   	$params{'reverse'}=$query->param('reverse');   	
   	
    
   	
   	my $output=handleP4ChangesPendingIntegration($session,\%params);
   	
   	$output=TWiki::Func::expandCommonVariables($output);  
   	$output=TWiki::Func::renderText($output);
   	
   	return "$output\n\n";	   		
	#return "This is an example of a REST invocation\n\n";
	}	
	
	
#########################################################
=pod	
	
=cut

sub handleP4ChangesPendingIntegration
	{
	my($session, $params, $theTopic, $theWeb) = @_;   	
		
	my $branchName=$params->{_DEFAULT};
	my $reverse=(defined $params->{reverse} && $params->{reverse} eq 'on' ? '-r' : '');	
	my $format=$params->{format};
    my $header = $params->{header};
    my $footer = $params->{footer};    

	
	#Interpret description parameter
	my $description=$params->{description};
	if (defined $description)
		{
		if ($description eq 'long')
			{
			$description='-L';	
			}
		elsif ($description eq 'full')
			{
			$description='-l';		
			}
		else
			{
			$description = '';		
			}
		}
	
	my $cmd=PerforceBaseCmd($p4port, $p4client, $p4user, $p4password);
	my $integrateCmd="$cmd integrate $reverse -n -d -b $branchName 2>&1"; #redirect error output
	
    #BAD: untaint the cmd. See: http://gunther.web66.com/FAQS/taintmode.html
    #Basically with perl -T you can't execute a system command but that trick fixes us.
    $integrateCmd=~/^(.*)$/; $integrateCmd=$1;
    #return $integrateCmd; #debug
    
	#Run the integrate command
	my @integrateOutput=`$integrateCmd`;
	#return "$integrateCmd";	
	my @changesOutput;
	
	#Parse the integrate lines...
	#and run changes command for each of them...
	#thus collecting the changes corresponding to each integration	
	foreach my $line(@integrateOutput)
		{
		my $toFile;	
		my $fromFile;	
		my $fromVersion1; 
		my $fromVersion2; 
	
		if ($line=~/^(.+?) - .* from (.+?)#(\d+),#(\d+)$/)
			{
			$toFile=$1;	
			$fromFile=$2;	
			$fromVersion1=$3; 
			$fromVersion2=$4; 			
			}
		elsif ($line=~/^(.+?) - .* from\s+(.+?)#(\d+)$/)
			{
			$toFile=$1;	
			$fromFile=$2;	
			$fromVersion1=$3; 
			$fromVersion2=$fromVersion1; 						
			#print "NICE!\n";
			}
		else
			{
			return "ERROR: $line";
			next;
			}
		
		#print "p4 changes $fromFile#$fromVersion1,#$fromVersion2\n";			
		
		my $changesCmd="$cmd changes $description $fromFile#$fromVersion1,#$fromVersion2";				
		#BAD: untaint the cmd. See: http://gunther.web66.com/FAQS/taintmode.html
    	#Basically with perl -T you can't execute a system command but that trick fixes us.
    	$changesCmd=~/^(.*)$/; $changesCmd=$1;    	
    	
		my @newChangesOutput=`$changesCmd`;		
		push(@changesOutput,@newChangesOutput);					
		}
	
	#Parse all changes to get ride of duplicates
	if ($description eq '')	
		{
		@changesOutput=ExcludeDuplicateChangesBasicOutput(\@changesOutput);		
		}
	else
		{
		@changesOutput=ExcludeDuplicateChangesLongDescriptionOutput(\@changesOutput);	
		}
	
	my $output="";		
	
	#Format the filtered results	
	if (defined $format)
		{
		if ($description eq '')	
			{
			$output=ParseAndFormatP4ChangesBasicOutput($format,\@changesOutput);			
			}
		else
			{
			$output=ParseAndFormatP4ChangesLongDescriptionOutput($format,\@changesOutput);
			}
		}
	else
		{
		foreach my $change(@changesOutput)
			{
    		$output .= TWiki::entityEncode($change);
	    	$output .= " <br /> "; #NOTE: we have a space after and before the br element. This helps InterWiki plugin to do its job
			}			
		}
	
	#Deal with header and format		
	if (defined $header)
		{
		$header=CommonVariableSubstitution($header);	
		$output = $header.$output;	
		}
		
	if (defined $footer)
		{
		$footer=CommonVariableSubstitution($footer);		
		$output = $output.$footer;	
		}			
		
	return $output;											
	}
	
	
		
	
=pod

Core p4 changes functionality

#Here is Perforce command documentation:
# http://www.perforce.com/perforce/doc.073/manuals/cmdref/changes.html#1048020

p4 [g-opts] changes [-i -t -l -L -c client -m max -s status -u user] [file[RevRange]...]

TODO: allow setting global options 
p4user 
p4port
p4client
p4password

=cut

sub handleP4Changes 
	{
    my($session, $params, $theTopic, $theWeb) = @_;
    # $session  - a reference to the TWiki session object (if you don't know
    #             what this is, just ignore it)
    # $params=  - a reference to a TWiki::Attrs object containing parameters.
    #             This can be used as a simple hash that maps parameter names
    #             to values, with _DEFAULT being the name for the default
    #             parameter.
    # $theTopic - name of the topic in the query
    # $theWeb   - name of the web in the query
    # Return: the result of processing the variable

    # For example, %EXAMPLETAG{'hamburger' sideorder="onions"}%
    # $params->{_DEFAULT} will be 'hamburger'
    # $params->{sideorder} will be 'onions'
    
    
    #my $p4ChangesTemplate='p4 %p4port% %p4client% %p4user% %p4password% %p4cmd% %i% %t% %l% %L% %c% %m% %s% %u% %file%';
    
    #my $p4ChangesTemplate='p4 %p4port% %p4client% %p4user% %p4password% %p4cmd% %params% %file%';
    #my $p4ChangesTemplate='p4 %P4PORT% %P4CLIENT% %P4USER% %P4PASSWORD% %P4CMD% %PARAMS% %FILE%';
    #my $p4ChangesTemplate='dir %DRIVE%';
    #my $p4ChangesTemplate='p4 %DRIVE%';
    
    #$p4CmdParams{'p4cmd'}=changes
    
=pod    

	#Use that with sysCommand if ever you can get it working
    my %p4ChangesCmdParams=(
			'P4PORT' => "-p $p4port",
			'P4CLIENT' => "-c $p4client",
			'P4USER' => "-u $p4user",
			'P4PASSWORD' => "-P $p4password",
			'P4CMD' => 'changes',	
			'PARAMS' => $params->{params},			
			'FILE' => $params->{_DEFAULT}
			);


    my %p4ChangesCmdParams=(
    		'DRIVE' => "changes"
					);			
=cut
					    
    
    my $changesCmdParams=$params->{_DEFAULT};
    #TODO: $changesCmdParams parse our p4 changes options to make sure nthing malicious is in there 
        
    #my $fileSpec = $params->{_DEFAULT};
    my $format = $params->{format};    
    my $header = $params->{header};
    my $footer = $params->{footer};    
        
    #return "$header\n$format\n$footer";
    
    my $cmd=PerforceBaseCmd($p4port, $p4client, $p4user, $p4password);
    #$cmd= "$cmd changes $changesCmdParams $fileSpec";
    $cmd= "$cmd changes $changesCmdParams";
    
    
    #Validate our command line
    if ($cmd =~ /\s+-t\s*/)
    	{
		return "%RED%P4CHANGES error: -t option not supported!%ENDCOLOR%";	    	
    	}
    # -s flag is now supported
    #elsif ($cmd =~ /\s+-s\s*/)
    #	{
	#    return "%RED%P4CHANGES error: -s option not supported!%ENDCOLOR%";	
    #	}
        
    
    # 
    #BAD: untaint the cmd. See: http://gunther.web66.com/FAQS/taintmode.html
    #Basically with perl -T you can't execute a system command but that trick fixes us.
    $cmd=~/^(.*)$/; $cmd=$1;

    #execute the command    
    #return "$cmd";
    #my @changesCmdOutput=TWiki::Sandbox::sysCommand($cmd); #TODO: should be using that API instead of backticks    
    my @changesCmdOutput=`$cmd`; #I know I should not be using backticks but I can't get sysCommand to work ;)    
    #return "after execute";
    
    #my ($changesCmdOutput,$exit)=$session->TWiki::Sandbox::sysCommand('dir %DRIVE%','DRIVE' => "C:");     
    #my ($changesCmdOutput,$exit)=$session->TWiki::Sandbox::sysCommand($p4ChangesTemplate,%p4ChangesCmdParams); 
    #return $changesCmdOutput;
    #return $exit;
    #my @changesCmdOutput=split $changesCmdOutput;
    
    #Parse and format the output
    my $output="";    
    if (defined $format)
    	{
	    #return "format";	
	    if ($cmd =~ /\s+-l\s*/)	
	    	{
		    #return "Parse full description";		    	  			    	  	
	    	$output=ParseAndFormatP4ChangesLongDescriptionOutput($format,\@changesCmdOutput);
    		}
	    elsif ($cmd =~ /\s+-L\s*/)	
	    	{
		    #return "Parse 250 characters description";		    	  	
	    	$output=ParseAndFormatP4ChangesLongDescriptionOutput($format,\@changesCmdOutput);
    		}    		
    	else
    		{
	    	#return "Parse basic";	
	    	$output=ParseAndFormatP4ChangesBasicOutput($format,\@changesCmdOutput);		    		
    		}
    	}
    else
    	{
	    #return "no format";
    	#Change 69463 on 2008/02/06 by sl@sl-ti 'Some nice comments'     	
    	#No format specified, use default format. No need to parse anything
    	foreach my $change(@changesCmdOutput)
    		{
	    	$output .= TWiki::entityEncode($change);
		    $output .= " <br /> "; #NOTE: we have a space after and before the br element. This helps InterWiki plugin to do its job
    		}
		}
    
	if (defined $header)
		{
		$header=CommonVariableSubstitution($header);	
		$output = $header.$output;	
		}
		
	if (defined $footer)
		{
		$footer=CommonVariableSubstitution($footer);		
		$output = $output.$footer;	
		}		
				
		
    return $output;        
	}



=pod

---++ earlyInitPlugin()

This handler is called before any other handler, and before it has been
determined if the plugin is enabled or not. Use it with great care!

If it returns a non-null error string, the plugin will be disabled.

=cut

sub DISABLE_earlyInitPlugin {
    return undef;
}

=pod

---++ initializeUserHandler( $loginName, $url, $pathInfo )
   * =$loginName= - login name recovered from $ENV{REMOTE_USER}
   * =$url= - request url
   * =$pathInfo= - pathinfo from the CGI query
Allows a plugin to set the username. Normally TWiki gets the username
from the login manager. This handler gives you a chance to override the
login manager.

Return the *login* name.

This handler is called very early, immediately after =earlyInitPlugin=.

*Since:* TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_initializeUserHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $loginName, $url, $pathInfo ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::initializeUserHandler( $_[0], $_[1] )" ) if $debug;
}

=pod

---++ registrationHandler($web, $wikiName, $loginName )
   * =$web= - the name of the web in the current CGI query
   * =$wikiName= - users wiki name
   * =$loginName= - users login name

Called when a new user registers with this TWiki.

*Since:* TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_registrationHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $web, $wikiName, $loginName ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::registrationHandler( $_[0], $_[1] )" ) if $debug;
}

=pod

---++ commonTagsHandler($text, $topic, $web, $included, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$included= - Boolean flag indicating whether the handler is invoked on an included topic
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is called by the code that expands %<nop>TAGS% syntax in
the topic body and in form fields. It may be called many times while
a topic is being rendered.

For variables with trivial syntax it is far more efficient to use
=TWiki::Func::registerTagHandler= (see =initPlugin=).

Plugins that have to parse the entire topic content should implement
this function. Internal TWiki
variables (and any variables declared using =TWiki::Func::registerTagHandler=)
are expanded _before_, and then again _after_, this function is called
to ensure all %<nop>TAGS% are expanded.

__NOTE:__ when this handler is called, &lt;verbatim> blocks have been
removed from the text (though all other blocks such as &lt;pre> and
&lt;noautolink> are still present).

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler. Use the =$meta= object.

*Since:* $TWiki::Plugins::VERSION 1.000

=cut

sub DISABLE_commonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $meta ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::commonTagsHandler( $_[2].$_[1] )" ) if $debug;

    # do custom extension rule, like for example:
    # $_[0] =~ s/%XYZ%/&handleXyz()/ge;
    # $_[0] =~ s/%XYZ{(.*?)}%/&handleXyz($1)/ge;
}

=pod

---++ beforeCommonTagsHandler($text, $topic, $web, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is called before TWiki does any expansion of it's own
internal variables. It is designed for use by cache plugins. Note that
when this handler is called, &lt;verbatim> blocks are still present
in the text.

__NOTE__: This handler is called once for each call to
=commonTagsHandler= i.e. it may be called many times during the
rendering of a topic.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

__NOTE:__ This handler is not separately called on included topics.

=cut

sub DISABLE_beforeCommonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $meta ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeCommonTagsHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ afterCommonTagsHandler($text, $topic, $web, $meta )
   * =$text= - text to be processed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - meta-data object for the topic MAY BE =undef=
This handler is after TWiki has completed expansion of %TAGS%.
It is designed for use by cache plugins. Note that when this handler
is called, &lt;verbatim> blocks are present in the text.

__NOTE__: This handler is called once for each call to
=commonTagsHandler= i.e. it may be called many times during the
rendering of a topic.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

=cut

sub DISABLE_afterCommonTagsHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $meta ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::afterCommonTagsHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ preRenderingHandler( $text, \%map )
   * =$text= - text, with the head, verbatim and pre blocks replaced with placeholders
   * =\%removed= - reference to a hash that maps the placeholders to the removed blocks.

Handler called immediately before TWiki syntax structures (such as lists) are
processed, but after all variables have been expanded. Use this handler to 
process special syntax only recognised by your plugin.

Placeholders are text strings constructed using the tag name and a 
sequence number e.g. 'pre1', "verbatim6", "head1" etc. Placeholders are 
inserted into the text inside &lt;!--!marker!--&gt; characters so the 
text will contain &lt;!--!pre1!--&gt; for placeholder pre1.

Each removed block is represented by the block text and the parameters 
passed to the tag (usually empty) e.g. for
<verbatim>
<pre class='slobadob'>
XYZ
</pre>
the map will contain:
<pre>
$removed->{'pre1'}{text}:   XYZ
$removed->{'pre1'}{params}: class="slobadob"
</pre>
Iterating over blocks for a single tag is easy. For example, to prepend a 
line number to every line of every pre block you might use this code:
<verbatim>
foreach my $placeholder ( keys %$map ) {
    if( $placeholder =~ /^pre/i ) {
       my $n = 1;
       $map->{$placeholder}{text} =~ s/^/$n++/gem;
    }
}
</verbatim>

__NOTE__: This handler is called once for each rendered block of text i.e. 
it may be called several times during the rendering of a topic.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

Since TWiki::Plugins::VERSION = '1.026'

=cut

sub DISABLE_preRenderingHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my( $text, $pMap ) = @_;
}

=pod

---++ postRenderingHandler( $text )
   * =$text= - the text that has just been rendered. May be modified in place.

__NOTE__: This handler is called once for each rendered block of text i.e. 
it may be called several times during the rendering of a topic.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler.

Since TWiki::Plugins::VERSION = '1.026'

=cut

sub DISABLE_postRenderingHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my $text = shift;
}

=pod

---++ beforeEditHandler($text, $topic, $web )
   * =$text= - text that will be edited
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called by the edit script just before presenting the edit text
in the edit box. It is called once when the =edit= script is run.

__NOTE__: meta-data may be embedded in the text passed to this handler 
(using %META: tags)

*Since:* TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_beforeEditHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeEditHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ afterEditHandler($text, $topic, $web, $meta )
   * =$text= - text that is being previewed
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - meta-data for the topic.
This handler is called by the preview script just before presenting the text.
It is called once when the =preview= script is run.

__NOTE:__ this handler is _not_ called unless the text is previewed.

__NOTE:__ meta-data is _not_ embedded in the text passed to this
handler. Use the =$meta= object.

*Since:* $TWiki::Plugins::VERSION 1.010

=cut

sub DISABLE_afterEditHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::afterEditHandler( $_[2].$_[1] )" ) if $debug;
}

=pod

---++ beforeSaveHandler($text, $topic, $web, $meta )
   * =$text= - text _with embedded meta-data tags_
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
   * =$meta= - the metadata of the topic being saved, represented by a TWiki::Meta object.

This handler is called each time a topic is saved.

__NOTE:__ meta-data is embedded in =$text= (using %META: tags). If you modify
the =$meta= object, then it will override any changes to the meta-data
embedded in the text. Modify *either* the META in the text *or* the =$meta=
object, never both. You are recommended to modify the =$meta= object rather
than the text, as this approach is proof against changes in the embedded
text format.

*Since:* TWiki::Plugins::VERSION = '1.010'

=cut

sub DISABLE_beforeSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::beforeSaveHandler( $_[2].$_[1] )" ) if $debug;
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

*Since:* TWiki::Plugins::VERSION 1.025

=cut

sub DISABLE_afterSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $text, $topic, $web, $error, $meta ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::afterSaveHandler( $_[2].$_[1] )" ) if $debug;
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

*Since:* TWiki::Plugins::VERSION = '1.11'

=cut

sub DISABLE_afterRenameHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ### my ( $oldWeb, $oldTopic, $oldAttachment, $newWeb, $newTopic, $newAttachment ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::afterRenameHandler( " .
                             "$_[0].$_[1] $_[2] -> $_[3].$_[4] $_[5] )" ) if $debug;
}

=pod

---++ beforeAttachmentSaveHandler(\%attrHash, $topic, $web )
   * =\%attrHash= - reference to hash of attachment attribute values
   * =$topic= - the name of the topic in the current CGI query
   * =$web= - the name of the web in the current CGI query
This handler is called once when an attachment is uploaded. When this
handler is called, the attachment has *not* been recorded in the database.

The attributes hash will include at least the following attributes:
   * =attachment= => the attachment name
   * =comment= - the comment
   * =user= - the user id
   * =tmpFilename= - name of a temporary file containing the attachment data

*Since:* TWiki::Plugins::VERSION = 1.025

=cut

sub DISABLE_beforeAttachmentSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ###   my( $attrHashRef, $topic, $web ) = @_;
    TWiki::Func::writeDebug( "- ${pluginName}::beforeAttachmentSaveHandler( $_[2].$_[1] )" ) if $debug;
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
   * =user= - the user id

*Since:* TWiki::Plugins::VERSION = 1.025

=cut

sub DISABLE_afterAttachmentSaveHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    ###   my( $attrHashRef, $topic, $web ) = @_;
    TWiki::Func::writeDebug( "- ${pluginName}::afterAttachmentSaveHandler( $_[2].$_[1] )" ) if $debug;
}

=begin twiki

---++ beforeMergeHandler( $text, $currRev, $currText, $origRev, $origText, $web, $topic )
   * =$text= - the new text of the topic
   * =$currRev= - the number of the most recent rev of the topic in the store
   * =$currText= - the text of that rev
   * =$origRev= - the number of the rev that the edit started on (or undef
     if that revision was overwritten by a replace-revision save)
   * =$origText= - the text of that revision (or undef)
   * =$web= - the name of the web for the topic being saved
   * =$topic= - the name of the topic
This handler is called immediately before a merge of a topic that was edited
simultaneously by two users. It is called once on the topic text from
the =save= script. See =mergeHandler= for handling individual changes in the
topic text (and in forms).

=cut

sub DISABLE_beforeMergeHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my( $text, $currRev, $currText, $origRev, $origText, $web, $topic ) = @_;
}

=pod

---++ mergeHandler( $diff, $old, $new, \%info ) -> $text
Try to resolve a difference encountered during merge. The =differences= 
array is an array of hash references, where each hash contains the 
following fields:
   * =$diff= => one of the characters '+', '-', 'c' or ' '.
      * '+' - =new= contains text inserted in the new version
      * '-' - =old= contains text deleted from the old version
      * 'c' - =old= contains text from the old version, and =new= text
        from the version being saved
      * ' ' - =new= contains text common to both versions, or the change
        only involved whitespace
   * =$old= => text from version currently saved
   * =$new= => text from version being saved
   * =\%info= is a reference to the form field description { name, title,
     type, size, value, tooltip, attributes, referenced }. It must _not_
     be wrtten to. This parameter will be undef when merging the body
     text of the topic.

Plugins should try to resolve differences and return the merged text. 
For example, a radio button field where we have 
={ diff=>'c', old=>'Leafy', new=>'Barky' }= might be resolved as 
='Treelike'=. If the plugin cannot resolve a difference it should return 
undef.

The merge handler will be called several times during a save; once for 
each difference that needs resolution.

If any merges are left unresolved after all plugins have been given a 
chance to intercede, the following algorithm is used to decide how to 
merge the data:
   1 =new= is taken for all =radio=, =checkbox= and =select= fields to 
     resolve 'c' conflicts
   1 '+' and '-' text is always included in the the body text and text
     fields
   1 =&lt;del>conflict&lt;/del> &lt;ins>markers&lt;/ins>= are used to 
     mark 'c' merges in text fields

The merge handler is called whenever a topic is saved, and a merge is 
required to resolve concurrent edits on a topic.

*Since:* TWiki::Plugins::VERSION = 1.1

=cut

sub DISABLE_mergeHandler {
}

=pod

---++ modifyHeaderHandler( \%headers, $query )
   * =\%headers= - reference to a hash of existing header values
   * =$query= - reference to CGI query object
Lets the plugin modify the HTTP headers that will be emitted when a
page is written to the browser. \%headers= will contain the headers
proposed by the core, plus any modifications made by other plugins that also
implement this method that come earlier in the plugins list.
<verbatim>
$headers->{expires} = '+1h';
</verbatim>

Note that this is the HTTP header which is _not_ the same as the HTML
&lt;HEAD&gt; tag. The contents of the &lt;HEAD&gt; tag may be manipulated
using the =TWiki::Func::addToHEAD= method.

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub DISABLE_modifyHeaderHandler {
    my ( $headers, $query ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::modifyHeaderHandler()" ) if $debug;
}

=pod

---++ redirectCgiQueryHandler($query, $url )
   * =$query= - the CGI query
   * =$url= - the URL to redirect to

This handler can be used to replace TWiki's internal redirect function.

If this handler is defined in more than one plugin, only the handler
in the earliest plugin in the INSTALLEDPLUGINS list will be called. All
the others will be ignored.

*Since:* TWiki::Plugins::VERSION 1.010

=cut

sub DISABLE_redirectCgiQueryHandler {
    # do not uncomment, use $_[0], $_[1] instead
    ### my ( $query, $url ) = @_;

    TWiki::Func::writeDebug( "- ${pluginName}::redirectCgiQueryHandler( query, $_[1] )" ) if $debug;
}

=pod

---++ renderFormFieldForEditHandler($name, $type, $size, $value, $attributes, $possibleValues) -> $html

This handler is called before built-in types are considered. It generates 
the HTML text rendering this form field, or false, if the rendering 
should be done by the built-in type handlers.
   * =$name= - name of form field
   * =$type= - type of form field (checkbox, radio etc)
   * =$size= - size of form field
   * =$value= - value held in the form field
   * =$attributes= - attributes of form field 
   * =$possibleValues= - the values defined as options for form field, if
     any. May be a scalar (one legal value) or a ref to an array
     (several legal values)

Return HTML text that renders this field. If false, form rendering
continues by considering the built-in types.

*Since:* TWiki::Plugins::VERSION 1.1

Note that since TWiki-4.2, you can also extend the range of available
types by providing a subclass of =TWiki::Form::FieldDefinition= to implement
the new type (see =TWiki::Plugins.DatePickerPlugin= and
=TWiki::Plugins.RatingContrib= for examples). This is the preferred way to
extend the form field types.

=cut

sub DISABLE_renderFormFieldForEditHandler {
}

=pod

---++ renderWikiWordHandler($linkText, $hasExplicitLinkLabel, $web, $topic) -> $linkText
   * =$linkText= - the text for the link i.e. for =[<nop>[Link][blah blah]]=
     it's =blah blah=, for =BlahBlah= it's =BlahBlah=, and for [[Blah Blah]] it's =Blah Blah=.
   * =$hasExplicitLinkLabel= - true if the link is of the form =[<nop>[Link][blah blah]]= (false if it's ==<nop>[Blah]] or =BlahBlah=)
   * =$web=, =$topic= - specify the topic being rendered (only since TWiki 4.2)

Called during rendering, this handler allows the plugin a chance to change
the rendering of labels used for links.

Return the new link text.

*Since:* TWiki::Plugins::VERSION 1.1

=cut

sub DISABLE_renderWikiWordHandler {
    my( $linkText, $hasExplicitLinkLabel, $web, $topic ) = @_;
    return $linkText;
}

=pod

---++ completePageHandler($html, $httpHeaders)

This handler is called on the ingredients of every page that is
output by the standard TWiki scripts. It is designed primarily for use by
cache and security plugins.
   * =$html= - the body of the page (normally &lt;html>..$lt;/html>)
   * =$httpHeaders= - the HTTP headers. Note that the headers do not contain
     a =Content-length=. That will be computed and added immediately before
     the page is actually written. This is a string, which must end in \n\n.

*Since:* TWiki::Plugins::VERSION 1.2

=cut

sub DISABLE_completePageHandler {
    #my($html, $httpHeaders) = @_;
    # modify $_[0] or $_[1] if you must change the HTML or headers
}





=pod

Build p4 command global options.

=cut


sub PerforceBaseCmd
	{
	my ($aPort, $aClient, $aUser, $aPassword) = @_;	
	
	my $baseCmd="p4 ";
	
	$baseCmd .= "-p $aPort " if defined $aPort;
	$baseCmd .= "-c $aClient " if defined $aClient;
	$baseCmd .= "-u $aUser " if defined $aUser;
	$baseCmd .= "-P $aPassword " if defined $aPassword;
		
	return $baseCmd;		
	}

sub P4ChangesVariableSubstitution
	{	
	my ($format, $changelist, $year, $month, $day, $user, $client, $status, $description) = @_;
	
	#TODO: is the nop gonna be working with the n?
	#We should use CommonVariableSubstitution instead of duplicating hash values
	my %substitutions=(
			'changelist' => $changelist,
			'year' => $year,			
			'month' => $month,
			'day' => $day,			
			'user' => $user,			
			'client' => $client,
			'description' => $description,
			'date' => "$year/$month/$day",
			'status' => $status,
			'nop' => '',
			'quot' => '"',
			'percnt' => '%',
			'pipe' => '|',
			'dollar' => '$',
			'n' => "\n"			
		 	);
	
		 	
	my $formated = $format;
	#%fields=;		
	#my $formFieldRef=$self->{FormFields};		
  	while ( my ($key, $value) = each(%substitutions) )
    		{     	
       		$formated =~ s/\$$key/$value/g;
       		}	
	
    return "$formated";
	#return "$changelist, $year, $month, $day, $user, $client, $description";		       							
	
	#return "$changelist, $year, $month, $day, $user, $client, $description";		
	}


=pod

=cut
	
	
sub CommonVariableSubstitution
	{	
	my ($format) = @_;
	
	#TODO: is the nop gonna be working with the n?	
	my %substitutions=(
			'nop' => '',
			'quot' => '"',
			'percnt' => '%',
			'pipe' => '|',			
			'dollar' => '$',
			'n' => "\n"
		 	);
			 	
	my $formated = $format;
  	while ( my ($key, $value) = each(%substitutions) )
    		{     	
       		$formated =~ s/\$$key/$value/g;
       		}	
	
    return "$formated";
	}
	
=pod

=cut
		
sub EarlyVariableSubstitution
	{	
	my ($format) = @_;
	
	#TODO: is the nop gonna be working with the n?	
	my %substitutions=(
			#'nop' => '',
			'quot' => '"',
			#'#' => '%23',
			#'percnt' => '%',
			#'dollar' => '$'
		 	);
			 	
	my $formated = $format;
  	while ( my ($key, $value) = each(%substitutions) )
    		{     	
       		$formated =~ s/\$$key/$value/g;
       		}	
	
    return "$formated";
	}

=pod

=cut
		
sub UrlEncode
	{	
	my ($format) = @_;
	
	#TODO: is the nop gonna be working with the n?	
	my %substitutions=(
			#'nop' => '',
			'"' => '%22',
			'#' => '%23',
			#'percnt' => '%',
			#'dollar' => '$'
		 	);
			 	
	my $formated = $format;
  	while ( my ($key, $value) = each(%substitutions) )
    		{     	
       		$formated =~ s/$key/$value/g;
       		}	
	
    return "$formated";
	}
	
		
#
#
#
	
sub ParseAndFormatP4ChangesBasicOutput()
	{
	my $format=$_[0];	
	my $changesCmdOutputRef=$_[1];	
	my @changesCmdOutput=@$changesCmdOutputRef;	
		
	#There was a format specified  so let's just parse our results
	my $output="";
    foreach my $change(@changesCmdOutput)
    	{
	   	#Change 69463 on 2008/02/06 by sl@sl-ti 'Some nice comments'
		#Parse one change line	    	
	    	    	
	    #Without pending status 	
    	if ($change =~ /^Change\s+(\d+)\s+on\s+(\d+)\/(\d+)\/(\d+)\s+by\s+([^\s]+)@([^\s]+)\s+'(.*)'$/)
    		{	    		
	    	my $changelist=$1;			
	    	my $year=$2;
	    	my $month=$3;
	    	my $day=$4;
	    	my $user=$5;
	    	my $client=$6;
	    	my $description=TWiki::entityEncode($7);
	    	my $status='submitted'; 
	    	
	    	#my $line=$format;
	    	$output.=P4ChangesVariableSubstitution($format, $changelist, $year, $month, $day, $user, $client, $status, $description);
	    	
	    	#Perform var substitutions	    		    	
    		}
    	#With pending status 	
		elsif ($change =~ /^Change\s+(\d+)\s+on\s+(\d+)\/(\d+)\/(\d+)\s+by\s+([^\s]+)@([^\s]+)\s+\*pending\*\s+'(.*)'$/)    		
			{
	    	my $changelist=$1;			
	    	my $year=$2;
	    	my $month=$3;
	    	my $day=$4;
	    	my $user=$5;
	    	my $client=$6;
	    	my $description=TWiki::entityEncode($7);
	    	my $status='pending'; 
	    	
	    	#my $line=$format;
	    	$output.=P4ChangesVariableSubstitution($format, $changelist, $year, $month, $day, $user, $client, $status, $description);
				
				
			}
    	else
    		{
    		$output .= "Could not parse: $change";
	    	$output .= "<br />";		    		
    		}	    	     		
   		}
   		
   	return $output;
	}	    	    
	
#
#
#

sub ParseAndFormatP4ChangesLongDescriptionOutput()
	{
	my $format=$_[0];	
	my $changesCmdOutputRef=$_[1];	
	my @changesCmdOutput=@$changesCmdOutputRef;	
		
	#There was a format specified  so let's just parse our results
	my $output="";
	
   	my $changelist;			
  	my $year;
   	my $month;
   	my $day;
   	my $user;
   	my $client;
   	my $status;
   	my $description;

	
    foreach my $change(@changesCmdOutput)
    	{
	   	#Change 69463 on 2008/02/06 by sl@sl-ti 'Some nice comments'
		#Parse one change line	    	
	    	    	
	    #Without pending status
    	if ($change =~ /^Change\s+(\d+)\s+on\s+(\d+)\/(\d+)\/(\d+)\s+by\s+([^\s]+)@([^\s]+)\s*$/)
    		{
	    	if (defined $changelist)	
	    		{
		    	$output.=P4ChangesVariableSubstitution($format, $changelist, $year, $month, $day, $user, $client, $status, $description);			
	    		}
	    			    		
	    	$changelist=$1;			
	    	$year=$2;
	    	$month=$3;
	    	$day=$4;
	    	$user=$5;
	    	$client=$6;	    	
	        $description="";
	        $status="submitted";
	        
	    	#my $status='submitted'; ##TODO	    		    	
	    	#my $line=$format;	    	    
	    	#Perform var substitutions
	    		    	
    		}
		#With pending status    		
    	elsif ($change =~ /^Change\s+(\d+)\s+on\s+(\d+)\/(\d+)\/(\d+)\s+by\s+([^\s]+)@([^\s]+)\s+\*pending\*\s*$/)
    		{
	    	if (defined $changelist)	
	    		{
		    	$output.=P4ChangesVariableSubstitution($format, $changelist, $year, $month, $day, $user, $client, $status, $description);			
	    		}
	    			    		
	    	$changelist=$1;			
	    	$year=$2;
	    	$month=$3;
	    	$day=$4;
	    	$user=$5;
	    	$client=$6;
	        $description="";
	        $status="pending";
	    		
    		}
    	elsif ($change =~ /^\t(.*)/) #must be description line
    		{
	    	my $htmlDes=TWiki::entityEncode($1);	
	    	$description.="$htmlDes <br /> ";	#NOTE: we have a space after and before the br element. This helps InterWiki plugin to do its job
    		}
    	elsif ($change =~ /^$/) #drop empty lines
    		{
	    	
    		}    		
    	else
    		{
    		$output .= "Could not parse: $change";
	    	$output .= "<br />";		    		
    		}	    	     		
   		}
   	
   	#Do not forget to add the last change entry if any
   	if (defined $changelist)	
		{
		$output.=P4ChangesVariableSubstitution($format, $changelist, $year, $month, $day, $user, $client, $status, $description);			
    	}	
   			
   	return $output;
	}	   

###################################################	
	
sub ExcludeDuplicateChangesBasicOutput
	{
	my $changesCmdOutputRef=$_[0];	
	my @changesCmdOutput=@$changesCmdOutputRef;	
	
	my %changesHash=();
	my @results;
		
	#There was a format specified  so let's just parse our results
	my $output="";
    foreach my $change(@changesCmdOutput)
    	{
	   	#Change 69463 on 2008/02/06 by sl@sl-ti 'Some nice comments'
		#Parse one change line	    	
	    	    	
	    #Without pending status 	
    	if ($change =~ /^Change\s+(\d+)\s+on\s+(\d+)\/(\d+)\/(\d+)\s+by\s+([^\s]+)@([^\s]+)\s+'(.*)'$/)
    		{	    		
	    	my $changelist=$1;			
	    	
	   		unless (defined ($changesHash{$changelist}))
	   			{
		   		$changesHash{$changelist}=1;
		   		push (@results,$change); #Keep that change
	   			}
    		}
    	else
    		{
	    	die "CAN'T PARSE: $change";
    		}	    	     		
   		}
   		
   	return @results;
	}	    	    

###################################################	
	
sub ExcludeDuplicateChangesLongDescriptionOutput
	{
	my $changesCmdOutputRef=$_[0];	
	my @changesCmdOutput=@$changesCmdOutputRef;	

	my %changesHash=();
	my @results;
	
   	my $changelist;			
   	my $isDuplicate;
	
    foreach my $change(@changesCmdOutput)
    	{
	   	#Change 69463 on 2008/02/06 by sl@sl-ti 'Some nice comments'
		#Parse one change line	    	
	    	    	
	    #Without pending status
    	if ($change =~ /^Change\s+(\d+)\s+on\s+(\d+)\/(\d+)\/(\d+)\s+by\s+([^\s]+)@([^\s]+)\s*$/)
    		{    			    		
	    	$changelist=$1;			
	    	
		  	if (defined ($changesHash{$changelist}))
	   			{
		   		$isDuplicate=1;	
	   			}
	   		else
	   			{
		   		$isDuplicate=0;		
		   		$changesHash{$changelist}=1;
		   		push (@results,$change); #Keep that change		   			
	   			}	    		        	    		    	
    		}
    	elsif ($change =~ /^\t(.*)/) #must be description line
    		{
	    	unless ($isDuplicate)
	    		{
		    	push (@results,$change); #Keep that change
	    		}
    		}
    	elsif ($change =~ /^$/) #drop empty lines
    		{
	    	unless ($isDuplicate)
	    		{
				push (@results,$change); #Keep that change			    		
	    		}	    	
    		}    		
    	else
    		{
    		die "Could not parse: $change";	    	
    		}	    	     		
   		}   	
   			
   	return @results;
	}	   
	
			
	
1;
