#
# Copyright (C) Motorola 2002 - All rights reserved
#
# TWiki extension that adds tags for action tracking
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

use TWiki; # required for unpublished constants!

# Action tracker configuration.
# This configuration is defined to import variables and functions that are not
# accessible through the Func module but are defined in TWiki, and other
# standard variables used by the action tracker (such as $rlogCmd).
# They are defined here so that if they subsequently disappear
# from TWiki:: the action tracker can easily be reconfigured.
{ package TWiki::Plugins::ActionTrackerPlugin::ActionTrackerConfig;

  use vars qw( $rlogCmd $cmdQuote $egrepCmd $securityFilter $notifyTopicname );

  # RCS log command
  $rlogCmd	  = "/usr/bin/rlog -d'%DATE%' %FILENAME%";
  # Command quote ' for unix, \" for Windows. Copy from TWiki.cfg
  $cmdQuote         = "'";
  # Unix egrep command. Copy from TWiki.cfg
  $egrepCmd         = $TWiki::egrepCmd;
  # Regex security filter. Copy from TWiki.cfg
  $securityFilter   = "[\\\*\?\~\^\$\@\%\`\"\'\&\;\|\<\>\x00-\x1F]";
  # Name of topic for email notifications. Copy from TWiki.cfg
  $notifyTopicname  = "WebNotify";
}

1;
