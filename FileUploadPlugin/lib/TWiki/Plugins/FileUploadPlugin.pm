#Copyright (C) 2007, Edgar Klerks

#This program is free software; you can redistribute it and/or
#modify it under the terms of the GNU General Public License
#as published by the Free Software Foundation; either version 2
#of the License, or (at your option) any later version.

#This program is distributed in the hope that it will be useful,
#but WITHOUT ANY WARRANTY; without even the implied warranty of
#MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#GNU General Public License for more details.

#You should have received a copy of the GNU General Public License
#along with this program; if not, write to the Free Software
#Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.


package TWiki::Plugins::FileUploadPlugin;



use strict;


use vars qw( $VERSION $RELEASE $SHORTDESCRIPTION $debug $pluginName $NO_PREFS_IN_TOPIC $core);

$VERSION = '$Rev: 12345';
$RELEASE = 'Geertje';
$NO_PREFS_IN_TOPIC = '1';
$SHORTDESCRIPTION = 'Makes TWikiForms capable handling files'; 
$pluginName = 'FileUploadPlugin'; 


sub load_core
{
	eval {require TWiki::Plugins::FileUploadPlugin::Core };
	$core = new TWiki::Plugins::FileUploadPlugin::Core;
	TWiki::Func::writeWarning("$pluginName: Can't load required modules ($@)"), if $@;
	$core->set_debug($debug);
	$core->set_tempdir(TWiki::Func::getWorkArea($pluginName));
	return $core;

}

sub initPlugin {
	my( $topic, $web, $user, $installWeb ) = @_;

# check for Plugins.pm versions
	if( $TWiki::Plugins::VERSION < 1.026 ) {
		TWiki::Func::writeWarning( "Version mismatch between $pluginName and Plugins.pm" );
		return 0;
	}
	$debug = 0;
	return 1;

}

# Hier doorzoeken we de text op form fields en als we er een hebben gevonden en verderop zit er 
# een input type="file" in, dan doen we het form enctype="multipart/form-data" maken.


sub postRenderingHandler { 
	
	$_[0] =~ s/\<form/\<form enctype="multipart\/form-data"/;

}


# Als we een input file vinden, zetten we de tag even goed.

sub renderFormFieldForEditHandler {

	my $type = $_[1];

	if(lc($type) eq "file")
	{	
		$core = &load_core();
		return $core->render_file_tag(@_);

	}

}


# Hier handelen we de download af
# Er is iets heeeeel vreemds aan de hand
sub afterSaveHandler
{

	# On demand loading
	$core = &load_core();

	# Are we saving an attachment?
	return, unless $core->after_save_proceed();	
	
	# Here we loop over all fields of the form
	my @fields = $_[4]->find ("FIELD");

	foreach my $field ( @fields)
	{
		my $name= $field->{"name"};
		my $query = TWiki::Func::getCgiQuery();
		my $filename = $query->param($name);
		my $upload_handle = $query->upload($name);
	
		# If there is an upload handle, we can upload it.
		if(defined($upload_handle)){	
			$core->upload_file(@_, $field, $filename, $upload_handle);
		}
	}
	return;
}

1;
