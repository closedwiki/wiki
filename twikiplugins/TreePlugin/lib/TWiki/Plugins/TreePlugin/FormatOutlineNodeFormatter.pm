#
# Copyright (C) XXXXXX 2001 - All rights reserved
#
# TWiki extension XXXXX
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
#

package TWiki::Plugins::TreePlugin::FormatOutlineNodeFormatter;
use base qw(TWiki::Plugins::TreePlugin::OutlineNodeFormatter);

use TWiki::Plugins::TreePlugin::FormatHelper qw(spaceTopic loopReplaceRefData);


# class to format the nodes in a tree in a formatted outline
#

# Constructor
sub new {
    my ($class, $format) = @_;
    my $this = {};
    bless($this, $class);
    $this->data("format", $format);
    return $this;
}

###########

# let subclasses overwrite if they want
sub formatLevel { return $_[1] + 1 ;} # humans start counting at 1

# let subclasses overwrite if they want
sub formatCount { return $_[1] + 1;} # humans start counting at 1

sub formatNode {
	my ($this, $node, $count, $level) = @_;	
	my $res = $this->data("format");
	return $node->name() unless ($res);

	# default if there's no format to do
#	return $this->SUPER::formatNode($this, $node, $count, $level)
#		unless ($res);
		
	# special substituions
	
	$res =~ s/\$topic/$node->name()/geo;
	$res =~ s/\$spacetopic/&TWiki::Plugins::TreePlugin::FormatHelper::spaceTopic($node->name())/ge;
	$res =~ s/\$outnum/$this->formatOutNum($node)/geo;
	$res =~ s/\$count/$this->formatCount($count)/geo;
	$res =~ s/\$level/$this->formatLevel($level)/geo;

	# node data substitutions
	$res = &TWiki::Plugins::TreePlugin::FormatHelper::loopReplaceRefData(
		$res, $node, qw(modTime author web));
	# formatter data substitutions
	$res = &TWiki::Plugins::TreePlugin::FormatHelper::loopReplaceRefData(
		$res, $this, qw(url));
	
#	$res =~ s/\$modTime/$node->data("modTime")/ge;
#	$res =~ s/\$author/$node->data("author")/ge;
#	$res =~ s/\$url/$this->data("url")/ge;
#	$res =~ s/\$web/$node->data("web")/ge;
	
	# only do this if we are in full substituiton mode
	if ( $this->data("fullSubs") ) {
		$res = &TWiki::Plugins::TreePlugin::FormatHelper::loopReplaceRefData(
			$res, $node, qw(text summary));

#		$res =~ s/\$summary/$node->data("summary")/ge;
#		$res =~ s/\$text/$node->data("text")/ge;
	
		# some meta substitutions go here
	}	
	return $res;
}

sub formatBranch {
	my ($this, $node, $childrenText, $count, $level) = @_;
	my $res = $this->data("branchformat");	

	# default if there's no format to do, let superclass handle
#	return $this->SUPER::formatBranch($this, $node, $childrenText, $count, $level)
#		unless ($res);

	# there's a bug with the above do this for now ??
	return $this->formatNode($node, $count, $level).$childrenText unless ($res);
	
	$res =~ s/\$level/$this->formatLevel($level)/geo;
	$res =~ s/\$parent/$this->formatNode($node, $count, $level)/geo;
	$res =~ s/\$children/$childrenText/geo;
	return $res;
}

1;