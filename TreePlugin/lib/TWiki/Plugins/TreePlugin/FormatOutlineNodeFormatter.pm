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


use TWiki::Func;

# class to format the nodes in a tree in a formatted outline
#

# Constructor
sub new {
    my ($class, $format) = @_;
    my $this = {};
    bless($this, $class);
    $this->data("format", $format);

#Twiki:Func::writeDebug("foramt: ".$);

    return $this;
}

###########

# let subclasses override if they want
sub formatLevel { return $_[1] + 1 ;} # humans start counting at 1

# let subclasses override if they want
sub formatCount { return $_[1] ;}

sub formatNode {
	my ($this, $node, $count, $level) = @_;	
	my $res = $this->data("format");

	my $nodeLinkName = '[[' . $node->name() . ']]';
	return $nodeLinkName unless ($res);
		
	# special substituions

        # Make linkable non-wiki-word names
	my $spaceTopicLinkName = '[[' . &TWiki::Plugins::TreePlugin::FormatHelper::spaceTopic($node->name()) . ']]';
	$res =~ s/\$topic/$nodeLinkName/geo;
	$res =~ s/\$spacetopic/$spaceTopicLinkName/ge;

	$res =~ s/\$outnum/$this->formatOutNum($node)/geo;
	$res =~ s/\$count/$this->formatCount($count)/geo;
	$res =~ s/\$level/$this->formatLevel($level)/geo;
	$res =~ s/\$n/\n/go;
	
	# node data substitutions
	$res = &TWiki::Plugins::TreePlugin::FormatHelper::loopReplaceRefData(
		$res, $node, qw(modTime author web));

	# formatter data substitutions
	$res = &TWiki::Plugins::TreePlugin::FormatHelper::loopReplaceRefData(
		$res, $this, qw(url));
	
	# only do this if we are in full substituiton mode
	if ( $this->data("fullSubs") ) {
		$res = &TWiki::Plugins::TreePlugin::FormatHelper::loopReplaceRefData(
			$res, $node, qw(text summary));
			
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
