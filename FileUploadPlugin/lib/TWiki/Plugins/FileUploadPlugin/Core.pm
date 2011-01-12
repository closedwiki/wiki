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



# Veel gebruikte functies.
# class Core

package TWiki::Plugins::FileUploadPlugin::Core;

use strict;

sub new {
	my $self = {
	# Private
		_debug => 'undef',
		_tmpdir => 'undef',
	};
	bless $self;
	return $self;
}

sub render_file_tag
{
	my ($self, $name, $type, $size, $value, $atrributes, $possiblevalues) = @_;
	my $tag = '<input title="file" type="file" name="'.$name.'" size="'.$size.'" />';
	return $tag;
}
sub set_debug
{
	my ($self, $debug) = @_;
	$self->{_debug} = $debug;
}


sub set_tempdir
{
	my ($self, $tmpdir) = @_;
	$self->{_tmpdir} = $tmpdir;
}

# Can the afterSaveHandler proceed, in case of an attachment, this is not the case.
sub after_save_proceed
{
	# Are we saving an attachment? If we are, we shouldn't let afterSave handler proceed, otherwise we get stuck in the loop saveAttachment -> afterSave -> saveA...
	my $attachment_flag = TWiki::Func::getSessionValue('file_upload_attachment');
	if(defined($attachment_flag) and $attachment_flag == 1)
	{
		TWiki::Func::setSessionValue('file_upload_attachment', 0);
		return 0;
	}
	return 1;

}
# Upload the file, check if the file is valid.
sub upload_file
{	

	my ($self, $text, $topic, $web, $error, $meta, $field, $filename, $upload_handle ) = @_;

	my $debug = $self->{_debug};
	my $tmpdir = $self->{_tmpdir};
	my $buffer;
	my $hook = $TWiki::cfg{Plugins}{FileUploadPlugin}{AttachmentHook} ;

	# File names of the pub en temp filename
	if ($filename =~ /^(.*)$/) { $filename = $1; }
	my $tmpfile = "$tmpdir\/$filename";

	# Copy a binary file to somewhere safe
	open (OUTFILE,">$tmpfile");
	while (read($upload_handle,$buffer,1024)) 
	{
		print OUTFILE $buffer;
	}

	my $filesize = (stat OUTFILE)[7];

	# Check whether the file is valid. If not return.
	if(not $self->file_check($web, $topic, $field, $filesize, $filename))
	{
		return;
	}
	close(OUTFILE);
	close($upload_handle);

	# Check mimetype against extension.
	if(not $self->mime_check($field, $web, $topic, $tmpfile, \$filename))
	{
		return;	
	}
	TWiki::Func::writeDebug("filename: $filename");
	# Attach to page. We should set file_upload_attachment to tell
	# the afterSave handler it should return.
	TWiki::Func::setSessionValue('file_upload_attachment', 1);

	# Execute user defined hook, before attaching the file
	
	if(defined($hook))
	{
		my $ret = &$hook($tmpfile, \$filename, \$web, \$topic);

		# If we got something back, the user defined checks failed.
		if(defined($ret))
		{
			return $self->woops("Error attaching file", $ret, $web, $topic);
		}

	}
	TWiki::Func::saveAttachment( $web, $topic, $filename,
		{
			file => $tmpfile,
			comment => '',
			hide => 0,
			filedate => time(),
			filesize => $filesize
		} );
	TWiki::Func::setSessionValue('file_upload_attachment',0);
	# Cleanup the file. We don't need it anymore.
	unlink $tmpfile;

}

# get the parameters and check wether the file is valid according the parameters

sub file_check
{
	my ($self, $web, $topic, $field, $filesize, $filename) = @_;
	my $name = $field->{'name'};
	my $attr = $field->{'attributes'};
	my ($size, $pattern, $modifier);
	my $header =  'File upload failed' ;

	# It should be quite easy to write a parser for the general case,
	# but I only have two options at the moment.
	
	# Extract the maximal allowed filesize.
	if ($attr =~ /(maxsize\{)([0-9]+)([GKM]?)(\})/g)
	{
		if( $3 eq "K")
		{
			$size = $2 * 1024;
		} elsif ($3 eq "M")
		{
			$size = $2 * 1024 * 1024;
		} elsif ($3 eq "G")
		{
			$size = $2 * 1024 * 1024 * 1024;
		} else
		{
			$size = $2;
		}
	}

	# Extract the regular expression from the pattern parameter

	if ($attr =~ /(pattern\{)\/([\w\W]+)\/([imsx]{0,4}?)\}/g)
	{
		$pattern = $2;
		$modifier = $3;
	}
	elsif ($attr =~ /(pattern\{)([\w\W]+)\}/g)
	{
		$pattern = $2;
	}

	#Here I filter the pattern, before compiling. Because you can use the (?{ operator, to do some harm, so I filter it out. Otherwise a person could type this:
	# pattern{/Test(?{ print 'Do some evil'})/i} and then you would be fucked.
	# Computers obey immediately if you say something like that. It is like russian roulette, but without the fun of NOT being hit. This time...
	#
	# I always wondered, are the russians that bad in playing roulette?
	#
	# Well to the point, I tested this quitte thorough and couldn't come up with a way to fuck this up.
	
	$pattern =~ s/\(\?{[\w\W]+\}\)//g;
	
	eval(qq|\$pattern = qr/$pattern/$modifier|);
	
	#
	if(not $filename =~ $pattern)
	{
		return $self->woops($header, "File $filename does not match the pattern.", $web, $topic);
	}

	if($filesize > $size)
	{		
		return 	$self->woops($header, "File $filename is too big.", $web, $topic);
	}

	return 1;
}

sub mime_check
{
	my ($self, $field, $web, $topic, $file, $name) = @_;

	# Get parameters
	my $option = $self->get_opts($field, "mime_check");
	return 1, unless defined($option);

	# Get the file extension and the filename in case we want to change the extension
	$$name =~ /([\w\W]+)\.([\w\W]+)/g;

	my $extension = $2;
	my $filename = $1;

	# If we can't find an extension, let the file fail. We always expect an extension,
	# so the user can see, what he/she is downloading.
	return 0, unless defined($extension);


	# $action = 0, means delete when extension doesn't match filetype
	# $action = 1, means rename "                                   "
	#
	# Default is delete

	my $action;
	# If we don't have an extension, we are done checking.

	return 1, unless $extension;

	if($option =~ /rename/i)
	{
		$action = 1;	
	} elsif ($option =~ /delete/i ) {
		$action = 0;
	} else {
		$action = 0;
	}

	# On demand loading, getting mime type from data 
	eval{use File::MMagic};

	my $m;
	if(defined($TWiki::cfg{Plugins}{FileUploadPlugin}{MagicFile}))
	{
		$m = File::MMagic->new($TWiki::cfg{Plugins}{FileUploadPlugin}{MagicFile});
	} else { 

		$m = File::MMagic->new();
	}

	unless($m)
	{
		TWiki::Func::writeWarning("FileUploadPlugin::Core::mime_check -- Please select an suitable magic file.");
		die;
	}

	my $mime = $m->checktype_filename($file);


	# If no mimetype avaible fail.
	# user can modify this behaviour, later. 

	return $self->woops("Mime Check", "Mimetype couldn't be determined", $web, $topic) , unless $mime;

	# On demand loading, if we have found a mimetype, we try to find the corresponding extension

	eval { use File::MimeInfo};
	my $extensions =  join " ", File::MimeInfo::extensions($mime);


	# If we can find our extension, things are fine, otherwise we have to take some action
	# which depends on $action. When 1, we rename the file. When 0 we delete the file, or exactly
	# we don't attach it and delete it from disk.

	if((index $extensions, $extension) != -1)
	{
		return 1;
	}

	if($action)
	{
		# Determine new extension name
		my @extension = File::MimeInfo::extensions($mime);
		$$name = "$filename." . pop @extension;

		return 1;
	}


	# Woops, extension and mimetype don't match. We better notify the user.
	$self->woops("Mime Check", "Mimetype and extension do not match, please rename your file to match the mimetype: $mime. (Hint: one of the following extensions is valid: $extensions).", $web, $topic);

	return 0;

}	
	

sub get_opts
{
	my ($self, $field, $opt) = @_;
	# options are case insensitive
	my $attr = $field->{'attributes'};
	$opt = qr/$opt/i;
	if($attr =~ /$opt\{([\w\W]+)\}/)
	{
		return $1;
	}
	return;
}


sub woops
{

	my ($self, $header, $message, $web, $topic) = @_;
	my @err;
	eval{use Error qw( :try )};
	throw TWiki::OopsException("generic",
		def => "",
		web => $web, 
		topic =>$topic, 
		params => [$header, $message, "", ""]);

	return 0;
}
1;
