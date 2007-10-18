# Plugin for TWiki Enterprise Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2002-2007 Peter Thoeny, peter@thoeny.org and
# TWiki Contributors.
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
#
# This is the EditTablePlugin used to edit tables in place.

package TWiki::Plugins::EditTablePlugin::Core;

use strict;
use Assert;

use vars qw(
  $preSp %params @format @formatExpanded
  $prefsInitialized $prefCHANGEROWS $prefEDITBUTTON
  $prefQUIETSAVE
  $nrCols $encodeStart $encodeEnd $table $query %regex
);

$preSp = '';

$regex{edit_table_plugin} = '%EDITTABLE{(.*)}%';
$regex{table_plugin}      = '%TABLE(?:{(.*?)})?%';
$regex{table_row_full}    = '^(\s*)\|.*\|\s*$';
$regex{table_row}         = '^(\s*)\|(.*)';

my $renderHack = "\n<nop>\n";

=pod

---+++ process( $doSave, $saveTableNr, $doSaveQuiet, $text, $topic, $web )

Called from commonTagsHandler. Pass over to processText in 'no Save' mode.

=cut

sub process {
    processText( 0, 0, 0, @_ );
}

=pod

---+++ processText( $doSave, $saveTableNr, $doSaveQuiet, $text, $topic, $web )

Process the text line by line.
When a EditTablePlugin table is encountered, its contents is rendered according to the view: 
   * View mode - default
   * Edit mode - when an Edit button is clicked, renders the rest of the table in edit mode
   * Save mode - when called from a Save button: calls processText again, only renders the selected table number, then saves the topic text

=cut

sub processText {

    my $doSave      = shift;
    my $saveTableNr = shift;
    my $doSaveQuiet = shift;

    $query = TWiki::Func::getCgiQuery();

    TWiki::Func::writeDebug(
        "- EditTablePlugin::commonTagsHandler( $_[2].$_[1] )")
      if $TWiki::Plugins::EditTablePlugin::debug;

    unless ($prefsInitialized) {
        $prefCHANGEROWS = TWiki::Func::getPreferencesValue('CHANGEROWS')
          || TWiki::Func::getPreferencesValue('EDITTABLEPLUGIN_CHANGEROWS')
          || 'on';
        $prefQUIETSAVE = TWiki::Func::getPreferencesValue('QUIETSAVE')
          || TWiki::Func::getPreferencesValue('EDITTABLEPLUGIN_QUIETSAVE')
          || 'on';
        $prefEDITBUTTON = TWiki::Func::getPreferencesValue('EDITBUTTON')
          || TWiki::Func::getPreferencesValue('EDITTABLEPLUGIN_EDITBUTTON')
          || 'Edit table';
        $prefsInitialized = 1;
    }

    my $theWeb   = $_[2];
    my $theTopic = $_[1];
    my $theText;
    if ($doSave) {
        $theText = TWiki::Func::readTopicText( $theWeb, $theTopic );
    }
    else {
        $theText = $_[0];
    }
    my $result = '';

    my $insidePRE   = 0;
    my $tableNr     = 0;       # current EditTable table
    my $rowNr       = 0;       # current row number; starting at 1
    my $enableForm  = 0;
    my $insideTable = 0;
    my $doEdit      = $doSave;
    my $etrows      = -1;
    my $hasTableRow = 0;       # the current line has a row with '| some text |'
    my $createdNewTable = 0;

    $theText =~
      s/\r//go;    # strip out all \r chars (may be pasted into a table cell)
    $theText =~ s/\\\n//go;    # Join lines ending in "\"
    $theText .= $renderHack
      ;    # appended stuff is a hack to handle EDITTABLE correctly if at end

    my @lines = split( /\n/, $theText );
    for (@lines) {

        # Check if we are inside <pre> or <verbatim> tags
        # if so, do not process
        m|<pre>|i       && ( $insidePRE = 1 );
        m|<verbatim>|i  && ( $insidePRE = 1 );
        m|</pre>|i      && ( $insidePRE = 0 );
        m|</verbatim>|i && ( $insidePRE = 0 );

        if ($insidePRE) {

            # no need to process, just copy the line
            $result .= "$_\n";
            next;
        }

        $hasTableRow = 0;

        my $hasEditTableTag = m/(\s*)$regex{edit_table_plugin}/go;
        if ($hasEditTableTag) {

            # this is an EDITTABLE tag
            if ($doSave) {

                # no need to process, just copy the line
                $result .= "$_\n";
            }
            else {

                # process the tag contents
s/(.*?)$regex{edit_table_plugin}/&handleEditTableTag( $theWeb, $theTopic, $1, $2 )/geo;

                # TODO: something strange has happened to the prefix
                # it is no longer used by handleEditTableTag
                # we add it here:
                $result .= $1 if $1;
            }
            $tableNr++;

            next if ( $doSave && $tableNr != $saveTableNr );

            $enableForm = 1;

            my $cgiTableNr = $query->param('ettablenr') || 0;

            $etrows = $query->param('etrows') || -1;
            if (
                ( $cgiTableNr == $tableNr )
                && (  $theWeb . '.'
                    . $theTopic eq
"$TWiki::Plugins::EditTablePlugin::web.$TWiki::Plugins::EditTablePlugin::topic"
                )
              )
            {

                if ( !$doSave && $query->param('etsave') ) {

                    # [Save table] button pressed
                    return processText( 1, $tableNr, 0, @_ );
                }
                elsif ( !$doSave && $query->param('etqsave') ) {

                    # [Quiet save] button pressed
                    return processText( 1, $tableNr, 1, @_ );

                }
                elsif ( $query->param('etcancel') ) {

                    # [Cancel] button pressed
                    doCancelEdit( $theWeb, $theTopic );
                    ASSERT(0) if DEBUG;
                    return;    # in case browser does not redirect

                }
                elsif ( $query->param('etaddrow') ) {

                    # [Add row] button pressed
                    $etrows++ if ( $etrows >= 0 );
                    $doEdit = doEnableEdit( $theWeb, $theTopic, 0 );
                    return unless ($doEdit);

                }
                elsif ( $query->param('etdelrow') ) {

                    # [Delete row] button pressed
                    $etrows--;
                    $doEdit = doEnableEdit( $theWeb, $theTopic, 0 );
                    return unless ($doEdit);

                }
                elsif ( $query->param('etedit') ) {

                    # [Edit table] button pressed
                    $doEdit = doEnableEdit( $theWeb, $theTopic, 1 );

                    # never return if locked or no permission
                    return unless ($doEdit);
                    $etrows = -1;   # make sure to get the actual number of rows
                }
            }
        }
        if (/$regex{table_plugin}/) {

            # match with a TablePlugin line
            # no need to process, just copy the line
            $result .= "$_\n";
            next;
        }
        if (m/$regex{table_row_full}/) {
            $hasTableRow = 1;
        }

        if ($enableForm) {
            if ( !$hasTableRow && !$insideTable && !$createdNewTable ) {

                # start new table
                $createdNewTable = 1;
                $result .=
                  handleTableStart( $theWeb, $theTopic, $tableNr, $doEdit )
                  if !$doSave;
                $insideTable = 1;
                $hasTableRow = 1;
                next;
            }
            if ($hasTableRow) {
                $insideTable = 1;
                $rowNr++;

                if ( $doSave
                    || ( $doEdit && $etrows >= 0 ) && ( $rowNr > $etrows ) )
                {

                    # deleted row
                    $rowNr--;
                    next;
                }
                my $isNewRow = ( $rowNr > $rowNr ) ? 1 : 0;
s/$regex{table_row}/handleTableRow( $1, $2, $tableNr, $isNewRow, $rowNr, $doEdit, $doSave, $theWeb, $theTopic )/eo;

            }
            elsif ($insideTable) {

                # end of table

                # if we are starting with an empty table, we force
                # create a row, with an optional header row
                if (   !$doSave
                    && $doEdit
                    && $etrows == -1
                    && $rowNr == 0
                    && !$query->param('etdelrow') )
                {
                    $etrows = 1;
                    $etrows++ if $params{'header'};
                }

                if ( $doEdit && $etrows >= 0 ) {
                    while ( $rowNr < $etrows ) {
                        $rowNr++;
                        my $isNewRow = ( $rowNr > $etrows ) ? 1 : 0;

                        $result .= handleTableRow(
                            '',     '',      $tableNr, $isNewRow,
                            $rowNr, $doEdit, $doSave,  $theWeb,
                            $theTopic
                        ) . "\n";
                    }
                }
                $result .= handleTableEnd( $theWeb, $rowNr, $doEdit )
                  if !$doSave;
                $insideTable     = 0;
                $enableForm      = 0;
                $doEdit          = 0;
                $rowNr           = 0;
                $createdNewTable = 0;
            }
        }    #/ if $enableForm
        $result .= "$_\n";
    }

    # clean up hack that handles EDITTABLE correctly if at end
    $result =~ s/($renderHack)+$//go;

    if ($doSave) {

        my $error = TWiki::Func::saveTopicText( $theWeb, $theTopic, $result, '',
            $doSaveQuiet );

        TWiki::Func::setTopicEditLock( $theWeb, $theTopic, 0 );   # unlock Topic
        my $url = TWiki::Func::getViewUrl( $theWeb, $theTopic );
        if ($error) {
            $url = TWiki::Func::getOopsUrl( $theWeb, $theTopic, 'oopssaveerr',
                $error );
        }
        TWiki::Func::redirectCgiQuery( $query, $url );
        return;
    }
    $_[0] = $result;
}

=pod

=cut

sub extractParams {
    my ( $theArgs, $theHashRef ) = @_;

    my $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'header' );
    $$theHashRef{'header'} = $tmp if ($tmp);

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'footer' );
    $$theHashRef{'footer'} = $tmp if ($tmp);

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'headerislabel' );
    $$theHashRef{'headerislabel'} = $tmp if ($tmp);

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'format' );
    $tmp =~ s/^\s*\|*\s*//o;
    $tmp =~ s/\s*\|*\s*$//o;
    $$theHashRef{'format'} = $tmp if ($tmp);

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'changerows' );
    $$theHashRef{'changerows'} = $tmp if ($tmp);

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'quietsave' );
    $$theHashRef{'quietsave'} = $tmp if ($tmp);

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'helptopic' );
    $$theHashRef{'helptopic'} = $tmp if ($tmp);

    $tmp = TWiki::Func::extractNameValuePair( $theArgs, 'editbutton' );
    $$theHashRef{'editbutton'} = $tmp if ($tmp);

    return;
}

=pod

=cut

sub parseFormat {
    my ( $theFormat, $theTopic, $theWeb, $doExpand ) = @_;
    $theFormat =~ s/\$nop(\(\))?//gos;         # remove filler
    $theFormat =~ s/\$quot(\(\))?/\"/gos;      # expand double quote
    $theFormat =~ s/\$percnt(\(\))?/\%/gos;    # expand percent
    $theFormat =~ s/\$dollar(\(\))?/\$/gos;    # expand dollar
    if ($doExpand) {

        # expanded form to be able to use %-vars in format
        $theFormat =~ s/<nop>//gos;
        $theFormat =
          TWiki::Func::expandCommonVariables( $theFormat, $theTopic, $theWeb );
    }
    my @aFormat = split( /\s*\|\s*/, $theFormat );
    $aFormat[0] = "text,16" unless @aFormat;

    return @aFormat;
}

=pod

=cut

sub handleEditTableTag {
    my ( $theWeb, $theTopic, $thePreSpace, $theArgs ) = @_;

    #$preSp = $thePreSpace || '';

    %params = (
        'header'        => '',
        'footer'        => '',
        'headerislabel' => "1",
        'format'        => '',
        'changerows'    => $prefCHANGEROWS,
        'quietsave'     => $prefQUIETSAVE,
        'helptopic'     => '',
        'editbutton'    => '',
    );

    my $iTopic = TWiki::Func::extractNameValuePair( $theArgs, 'include' );
    if ($iTopic) {

        # include topic to read definitions
        if ( $iTopic =~ /^([^\.]+)\.(.*)$/o ) {
            $theWeb = $1;
            $iTopic = $2;
        }
        my $text = TWiki::Func::readTopicText( $theWeb, $iTopic );
        $text =~ /$regex{edit_table_plugin}/os;
        if ($1) {
            my $args = $1;
            if (   $theWeb ne $TWiki::Plugins::EditTablePlugin::web
                || $iTopic ne $TWiki::Plugins::EditTablePlugin::topic )
            {

                # expand common vars, unless oneself to prevent recursion
                $args =
                  TWiki::Func::expandCommonVariables( $1, $iTopic, $theWeb );
            }
            extractParams( $args, \%params );
        }
    }

    extractParams( $theArgs, \%params );

    $params{'header'} = '' if ( $params{header} =~ /^(off|no)$/oi );
    $params{'header'} =~ s/^\s*\|//o;
    $params{'header'} =~ s/\|\s*$//o;
    $params{'headerislabel'} = ''
      if ( $params{headerislabel} =~ /^(off|no)$/oi );
    $params{'footer'} = '' if ( $params{footer} =~ /^(off|no)$/oi );
    $params{'footer'} =~ s/^\s*\|//o;
    $params{'footer'} =~ s/\|\s*$//o;
    $params{'changerows'} = '' if ( $params{changerows} =~ /^(off|no)$/oi );
    $params{'quietsave'}  = '' if ( $params{quietsave}  =~ /^(off|no)$/oi );

    @format         = parseFormat( $params{format}, $theTopic, $theWeb, 0 );
    @formatExpanded = parseFormat( $params{format}, $theTopic, $theWeb, 1 );
    $nrCols         = @format;

    # FIXME: No handling yet of footer

    return "$preSp";
}

=pod

=cut

sub handleTableStart {
    my ( $theWeb, $theTopic, $theTableNr, $doEdit ) = @_;
    my $viewUrl = TWiki::Func::getScriptUrl( $theWeb, $theTopic, 'viewauth' )
      . "\#edittable$theTableNr";
    my $text = '';
    if ($doEdit) {
        require TWiki::Contrib::JSCalendarContrib;
        unless ($@) {
            TWiki::Contrib::JSCalendarContrib::addHEAD('twiki');
        }
    }
    $text .= "$preSp<noautolink>\n" if $doEdit;
    $text .= "$preSp<a name=\"edittable$theTableNr\"></a>\n";
    my $cssClass = 'editTable';
    if ($doEdit) {
        $cssClass .= ' editTableEdit';
    }
    $text .= "<div class=\"" . $cssClass . "\">";
    $text .=
"$preSp<form name=\"edittable$theTableNr\" action=\"$viewUrl\" method=\"post\">\n";
    $text .=
"$preSp<input class=\"twikiInputField\" type=\"hidden\" name=\"ettablenr\" value=\"$theTableNr\" />\n";
    $text .= "$preSp<input type=\"hidden\" name=\"etedit\" value=\"on\" />\n"
      unless $doEdit;
    return $text;
}

=pod

=cut

sub handleTableEnd {
    my ( $theWeb, $theRowNr, $doEdit ) = @_;
    my $text =
      "$preSp<input type=\"hidden\" name=\"etrows\" value=\"$theRowNr\" />\n";
    if ($doEdit) {

        # Edit mode
        $text .=
"$preSp<input type=\"submit\" name=\"etsave\" id=\"etsave\" value=\"Save table\" class=\"twikiSubmit\" />\n";
        if ( $params{'quietsave'} ) {
            $text .=
"$preSp<input type=\"submit\" name=\"etqsave\" id=\"etqsave\" value=\"Quiet save\" class=\"twikiButton\" />\n";
        }
        if ( $params{'changerows'} ) {
            $text .=
"$preSp<input type=\"submit\" name=\"etaddrow\" id=\"etaddrow\" value=\"Add row\" class=\"twikiButton\" />\n";
            $text .=
"$preSp<input type=\"submit\" name=\"etdelrow\" id=\"etdelrow\" value=\"Delete last row\" class=\"twikiButton\" />\n"
              unless ( $params{'changerows'} =~ /^add$/oi );
        }
        $text .=
"$preSp<input type=\"submit\" name=\"etcancel\" id=\"etcancel\" value=\"Cancel\" class=\"twikiButton twikiButtonCancel\" />\n";

        if ( $params{'helptopic'} ) {

            # read help topic and show below the table
            if ( $params{'helptopic'} =~ /^([^\.]+)\.(.*)$/o ) {
                $theWeb = $1;
                $params{'helptopic'} = $2;
            }
            my $helpText =
              TWiki::Func::readTopicText( $theWeb, $params{'helptopic'} );

            #Strip out the meta data so it won't be displayed.
            $helpText =~ s/%META:[A-Za-z0-9]+{.*?}%//g;
            if ($helpText) {
                $helpText =~ s/.*?%STARTINCLUDE%//os;
                $helpText =~ s/%STOPINCLUDE%.*//os;
                $text .= $helpText;
            }
        }
        my $assetUrl = '%PUBURL%/%SYSTEMWEB%/EditTablePlugin';

        # table specific script
        my $tableNr = $query->param('ettablenr');
        &TWiki::Plugins::EditTablePlugin::addEditModeHeadersToHead( $tableNr,
            $assetUrl );
    }
    else {
        $params{editbutton} |= '';

        # View mode
        if ( $params{editbutton} eq "hide" ) {

            # do nothing, button assumed to be in a cell
        }
        else {

            # Add edit button to end of table
            $text .=
              $preSp . viewEditCell("editbutton, 1, $params{'editbutton'}");
        }
    }
    $text .= "$preSp</form>\n";
    $text .= "</div><!-- /editTable -->";
    $text .= "$preSp</noautolink>\n" if $doEdit;
    $text .= "\n";
    return $text;
}

=pod

=cut

sub parseEditCellFormat {
    $_[1] = TWiki::Func::extractNameValuePair( $_[0] );
    return '';
}

=pod

=cut

sub viewEditCell {
    my ($theAttr) = @_;
    $theAttr = TWiki::Func::extractNameValuePair($theAttr);
    return '' unless ( $theAttr =~ /^editbutton/ );

    $params{editbutton} = 'hide'
      unless ( $params{editbutton} );    # Hide below table edit button

    my @bits = split( /,\s*/, $theAttr );
    my $value = '';
    $value = $bits[2] if ( @bits > 2 );
    my $img = '';
    $img = $bits[3] if ( @bits > 3 );

    unless ($value) {
        $value = $prefEDITBUTTON || '';
        $img = '';
        if ( $value =~ s/(.+),\s*(.+)/$1/o ) {
            $img = $2;
            $img =~ s|%ATTACHURL%|%PUBURL%/%SYSTEMWEB%/EditTablePlugin|o;
            $img =~ s|%WEB%|%SYSTEMWEB%|o;
        }
    }
    if ($img) {
        return
"<input class=\"editTableEditImageButton\" type=\"image\" src=\"$img\" alt=\"$value\" />";
    }
    else {
        return
"<input class=\"twikiButton editTableEditButton\" type=\"submit\" value=\"$value\" />";
    }
}

=pod

=cut

sub saveEditCellFormat {
    my ( $theFormat, $theName ) = @_;
    return '' unless ($theFormat);
    $theName =~ s/cell/format/;
    return "<input type=\"hidden\" name=\"$theName\" value=\"$theFormat\" />";
}

=pod

digestedCellValue: properly handle labels whose rows may have been moved around by javascript, and therefore no longer correspond to the raw saved table text.

=cut

sub inputElement {
    my ( $theTableNr, $theRowNr, $theCol, $theName, $theValue,
        $digestedCellValue, $theWeb, $theTopic )
      = @_;

    my $rawValue = $theValue;
    my $text     = '';
    my $i        = @format - 1;
    $i = $theCol if ( $theCol < $i );
    my @bits         = split( /,\s*/, $format[$i] );
    my @bitsExpanded = split( /,\s*/, $formatExpanded[$i] );

    my $cellFormat = '';
    $theValue =~
      s/\s*%EDITCELL{(.*?)}%/&parseEditCellFormat( $1, $cellFormat )/eo;
    $theValue = '' if ( $theValue eq ' ' );
    if ($cellFormat) {
        my @aFormat = parseFormat( $cellFormat, $theTopic, $theWeb, 0 );
        @bits = split( /,\s*/, $aFormat[0] );
        @aFormat = parseFormat( $cellFormat, $theTopic, $theWeb, 1 );
        @bitsExpanded = split( /,\s*/, $aFormat[0] );
    }

    my $type = 'text';
    $type = $bits[0] if @bits > 0;

    # a table header is considered a label if read only header flag set
    $type = 'label'
      if ( ( $params{'headerislabel'} ) && ( $theValue =~ /^\s*\*.*\*\s*$/ ) );
    $type = 'label' if ( $type eq 'editbutton' );    # Hide [Edit table] button
    my $size = 0;
    $size = $bits[1] if @bits > 1;
    my $val         = '';
    my $valExpanded = '';
    my $sel         = '';
    if ( $type eq 'select' ) {
        my $expandedValue =
          TWiki::Func::expandCommonVariables( $theValue, $theTopic, $theWeb );
        $size = 1 if $size < 1;
        $text =
          "<select class=\"twikiSelect\" name=\"$theName\" size=\"$size\">";
        $i = 2;
        while ( $i < @bits ) {
            $val         = $bits[$i]         || '';
            $valExpanded = $bitsExpanded[$i] || '';
            $expandedValue =~ s/^\s+//;
            $expandedValue =~ s/\s+$//;
            $valExpanded =~ s/^\s+//;
            $valExpanded =~ s/\s+$//;
            if ( $valExpanded eq $expandedValue ) {
                $text .= " <option selected=\"selected\">$val</option>";
            }
            else {
                $text .= " <option>$val</option>";
            }
            $i++;
        }
        $text .= "</select>";
        $text .= saveEditCellFormat( $cellFormat, $theName );

    }
    elsif ( $type eq "radio" ) {
        my $expandedValue =
          &TWiki::Func::expandCommonVariables( $theValue, $theTopic, $theWeb );
        $size = 1 if $size < 1;
        my $elements = ( @bits - 2 );
        my $lines    = $elements / $size;
        $lines = ( $lines == int($lines) ) ? $lines : int( $lines + 1 );
        $text .= "<table class=\"editTableInnerTable\"><tr><td valign=\"top\">"
          if ( $lines > 1 );
        $i = 2;
        while ( $i < @bits ) {
            $val         = $bits[$i]         || "";
            $valExpanded = $bitsExpanded[$i] || "";
            $expandedValue =~ s/^\s+//;
            $expandedValue =~ s/\s+$//;
            $valExpanded =~ s/^\s+//;
            $valExpanded =~ s/\s+$//;
            $text .= " <input type=\"radio\" name=\"$theName\" value=\"$val\"";
            # make space to expand variables
            $val = " $val ";
            $val =~ s/^\s+/ /; # remove extra spaces
            $val =~ s/\s+$/ /;
            $text .= " checked=\"checked\""
              if ( $valExpanded eq $expandedValue );
            $text .= " />$val";
            if ( $lines > 1 ) {

                if ( ( $i - 1 ) % $lines ) {
                    $text .= "<br />";
                }
                elsif ( $i - 1 < $elements ) {
                    $text .= "</td><td valign=\"top\">";
                }
            }
            $i++;
        }
        $text .= "</td></tr></table>" if ( $lines > 1 );
        $text .= saveEditCellFormat( $cellFormat, $theName );

    }
    elsif ( $type eq "checkbox" ) {
        my $expandedValue =
          &TWiki::Func::expandCommonVariables( $theValue, $theTopic, $theWeb );
        $size = 1 if $size < 1;
        my $elements = ( @bits - 2 );
        my $lines    = $elements / $size;
        my $names    = "Chkbx:";
        $lines = ( $lines == int($lines) ) ? $lines : int( $lines + 1 );
        $text .= "<table class=\"editTableInnerTable\"><tr><td valign=\"top\">"
          if ( $lines > 1 );
        $i = 2;

        while ( $i < @bits ) {
            $val         = $bits[$i]         || "";
            $valExpanded = $bitsExpanded[$i] || "";
            $expandedValue =~ s/^\s+//;
            $expandedValue =~ s/\s+$//;
            $valExpanded =~ s/^\s+//;
            $valExpanded =~ s/\s+$//;
            $names .= " ${theName}x$i";
            $text .=
              " <input type=\"checkbox\" name=\"${theName}x$i\" value=\"$val\"";
            # make space to expand variables
            $val = " $val ";
            $val =~ s/^\s+/ /; # remove extra spaces
            $val =~ s/\s+$/ /;
            
            $text .= " checked=\"checked\""
              if ( $expandedValue =~ /(^|\s*,\s*)\Q$valExpanded\E(\s*,\s*|$)/ );
            $text .= " />$val";

            if ( $lines > 1 ) {
                if ( ( $i - 1 ) % $lines ) {
                    $text .= "<br />";
                }
                elsif ( $i - 1 < $elements ) {
                    $text .= "</td><td valign=\"top\">";
                }
            }
            $i++;
        }
        $text .= "</td></tr></table>" if ( $lines > 1 );
        $text .=
          "<input type=\"hidden\" name=\"$theName\" value=\"$names\" />";
        $text .= saveEditCellFormat( $cellFormat, $theName );

    }
    elsif ( $type eq 'row' ) {
        $size = $size + $theRowNr;
        $text =
            "<div class=\"et_rowlabel\">"
          . "$size<input type=\"hidden\" name=\"$theName\" value=\"$size\" />"
          . "</div>";
        $text .= saveEditCellFormat( $cellFormat, $theName );

    }
    elsif ( $type eq 'label' ) {

        # show label text as is, and add a hidden field with value
        my $isHeader = 0;
        $isHeader = 1 if ( $theValue =~ s/^\s*\*(.*)\*\s*$/$1/o );
        $text = $theValue;

        # To optimize things, only in the case where a read-only column is
        # being processed (inside of this unless() statement) do we actually
        # go out and read the original topic.  Thus the reason for the
        # following unless() so we only read the topic the first time through.
        unless ( defined $table and $digestedCellValue ) {

            # To deal with the situation where TWiki variables, like
            # %CALC%, have already been processed and end up getting saved
            # in the table that way (processed), we need to read in the
            # topic page in raw format
            my $topicContents = TWiki::Func::readTopicText(
                $TWiki::Plugins::EditTablePlugin::web,
                $TWiki::Plugins::EditTablePlugin::topic
            );
            $table = TWiki::Plugins::Table->new($topicContents);
        }
        my $cell =
            $digestedCellValue
          ? $table->getCell( $theTableNr, $theRowNr - 1, $theCol )
          : $rawValue;
        $theValue = $cell if ( defined $cell );    # original value from file
        $theValue = TWiki::Plugins::EditTablePlugin::encodeValue($theValue)
          unless ( $theValue eq '' );
        $theValue = "\*$theValue\*" if ( $isHeader and $digestedCellValue );
        $text .=
          "<input type=\"hidden\" name=\"$theName\" value=\"$theValue\" />";
        $text = "\*$text\*" if ($isHeader);

    }
    elsif ( $type eq 'textarea' ) {
        my ( $rows, $cols ) = split( /x/, $size );
        
        $rows |= 3 if !defined $rows;
        $cols |= 30 if !defined $cols;

        $theValue = TWiki::Plugins::EditTablePlugin::encodeValue($theValue)
          unless ( $theValue eq '' );
        $text .=
"<textarea class=\"twikiTextarea editTableTextarea\" rows=\"$rows\" cols=\"$cols\" name=\"$theName\">$theValue</textarea>";
        $text .= saveEditCellFormat( $cellFormat, $theName );

    }
    elsif ( $type eq 'date' ) {
        my $ifFormat = '';
        $ifFormat = $bits[3] if ( @bits > 3 );
        $ifFormat ||= $TWiki::cfg{JSCalendarContrib}{format} || '%e %B %Y';
        $size = 10 if ( !$size || $size < 1 );
        $theValue = TWiki::Plugins::EditTablePlugin::encodeValue($theValue)
          unless ( $theValue eq '' );
        $text .= CGI::textfield(
            {
                name     => $theName,
                class    => 'twikiInputField editTableInput',
                id       => 'id' . $theName,
                size     => $size,
                value    => $theValue,
                override => 1
            }
        );
        $text .= saveEditCellFormat( $cellFormat, $theName );
        eval 'use TWiki::Contrib::JSCalendarContrib';

        unless ($@) {
            $text .= '<span class="twikiMakeVisible">';
            $text .= CGI::image_button(
                -class   => 'editTableCalendarButton',
                -name    => 'calendar',
                -onclick => "return showCalendar('id$theName','$ifFormat')",
                -src     => TWiki::Func::getPubUrlPath() . '/'
                  . TWiki::Func::getTwikiWebname()
                  . '/JSCalendarContrib/img.gif',
                -alt   => 'Calendar',
                -align => 'middle'
            );
            $text .= '</span>';
        }

        $query->{'jscalendar'} = 1;

    }
    else {    #  if( $type eq 'text')
        $size = 16 if $size < 1;
        $theValue = TWiki::Plugins::EditTablePlugin::encodeValue($theValue)
          unless ( $theValue eq '' );
        $text =
"<input class=\"twikiInputField editTableInput\" type=\"text\" name=\"$theName\" size=\"$size\" value=\"$theValue\" />";
        $text .= saveEditCellFormat( $cellFormat, $theName );
    }
    return $text;
}

=pod

=cut

sub handleTableRow {
    my (
        $thePre, $theRow, $theTableNr, $isNewRow, $theRowNr,
        $doEdit, $doSave, $theWeb,     $theTopic
    ) = @_;
    $thePre |= '';
    my $text = "$thePre\|";

    if ($doEdit) {
        $theRow =~ s/\|\s*$//o;
        my $rowID = $query->param("etrow_id$theRowNr");
        if ( !defined $rowID ) { $rowID = $theRowNr; }
        my @cells = split( /\|/, $theRow );
        my $tmp = @cells;
        $nrCols = $tmp if ( $tmp > $nrCols );    # expand number of cols
        my $val         = '';
        my $cellFormat  = '';
        my $cell        = '';
        my $digested    = 0;
        my $cellDefined = 0;
        my $col         = 0;
        while ( $col < $nrCols ) {
            $col += 1;
            $cellDefined = 0;
            $val = $isNewRow ? undef : $query->param("etcell${rowID}x$col");
            if ( $val && $val =~ /^Chkbx: (etcell.*)/ ) {

      # Multiple checkboxes, val has format "Chkbx: etcell4x2x2 etcell4x2x3 ..."
                my $chkBoxeNames = $1;
                my $chkBoxVals   = "";
                foreach ( split( /\s/, $chkBoxeNames ) ) {
                    $val = $query->param($_);
                    #$chkBoxVals .= "$val," if ( defined $val );
                    if ( defined $val ) {
                        # make space to expand variables
                        $val = " $val ";
                        $val =~ s/^\s+/ /; # remove extra spaces
                        $val =~ s/\s+$/ /;
                        $chkBoxVals .= $val . ',';
                    }
                }
                $chkBoxVals =~ s/,\s*$//;
                $val = $chkBoxVals;
            }
            $cellFormat = $query->param("etformat${rowID}x$col");
            $val .= " %EDITCELL{$cellFormat}%" if ($cellFormat);
            if ( defined $val ) {

                # change any new line character sequences to <br />
                $val =~ s/[\n\r]{2,}?/%BR%/gos;

                # escape "|" to HTML entity
                $val =~ s/\|/\&\#124;/gos;
                $cellDefined = 1;

                # Expand %-vars
                $cell = $val;
            }
            elsif ( $col <= @cells ) {
                $cell = $cells[ $col - 1 ];
                $digested = 1;    # Flag that we are using non-raw cell text.
                $cellDefined = 1 if ( length($cell) > 0 );
                $cell =~ s/^\s//o;
                $cell =~ s/\s$//o;
            }
            else {
                $cell = '';
            }
            if ( ( $theRowNr <= 1 ) && ( $params{'header'} ) ) {
                unless ($cell) {
                    if ( $params{'header'} =~ /^on$/i ) {
                        if (   ( @format >= $col )
                            && ( $format[ $col - 1 ] =~ /(.*?)\,/ ) )
                        {
                            $cell = $1;
                        }
                        $cell = 'text' unless $cell;
                        $cell = "*$cell*";
                    }
                    else {
                        my @hCells = split( /\|/, $params{'header'} );
                        $cell = $hCells[ $col - 1 ] if ( @hCells >= $col );
                        $cell = "*text*" unless $cell;
                    }
                }
                $text .= "$cell\|";

            }
            elsif ($doSave) {
                $text .= " $cell \|";

            }
            else {
                if (
                       ( !$cellDefined )
                    && ( @format >= $col )
                    && ( $format[ $col - 1 ] =~
                        /^\s*(.*?)\,\s*(.*?)\,\s*(.*?)\s*$/ )
                  )
                {

                    # default value of "| text, 20, a, b, c |" cell is "a, b, c"
                    # default value of '| select, 1, a, b, c |' cell is "a"
                    $val  = $1;    # type
                    $cell = $3;
                    $cell = ''
                      unless ( defined $cell && $cell ne '' )
                      ;            # Proper handling of '0'
                    $cell =~ s/\,.*$//o
                      if ( $val eq 'select' || $val eq 'date' );
                }
                $text .=
                  inputElement( $theTableNr, $theRowNr, $col - 1,
                    "etcell${theRowNr}x$col", $cell, $digested, $theWeb,
                    $theTopic )
                  . " \|";
            }
        }
    }
    else {
        $theRow =~ s/%EDITCELL{(.*?)}%/viewEditCell($1)/geo;
        $text .= $theRow;
    }
    return $text;
}

=pod

=cut

sub doCancelEdit {
    my ( $theWeb, $theTopic ) = @_;

    TWiki::Func::writeDebug(
        "- EditTablePlugin::doCancelEdit( $theWeb, $theTopic )")
      if $TWiki::Plugins::EditTablePlugin::debug;

    TWiki::Func::setTopicEditLock( $theWeb, $theTopic, 0 );

    TWiki::Func::redirectCgiQuery( $query,
        TWiki::Func::getViewUrl( $theWeb, $theTopic ) );
}

=pod

=cut

sub doEnableEdit {
    my ( $theWeb, $theTopic, $doCheckIfLocked ) = @_;

    TWiki::Func::writeDebug(
        "- EditTablePlugin::doEnableEdit( $theWeb, $theTopic )")
      if $TWiki::Plugins::EditTablePlugin::debug;

    my $wikiUserName = TWiki::Func::getWikiName();
    if (
        !TWiki::Func::checkAccessPermission(
            'change', $wikiUserName, undef, $theTopic, $theWeb
        )
      )
    {

        # user has no permission to change the topic
        throw TWiki::OopsException(
            'accessdenied',
            def    => 'topic_access',
            web    => $theWeb,
            topic  => $theTopic,
            params => [ 'change', 'denied' ]
        );
    }

    my $breakLock = $query->param('breaklock') || '';
    unless ($breakLock) {
        my ( $oopsUrl, $lockUser ) =
          TWiki::Func::checkTopicEditLock( $theWeb, $theTopic, 'view' );
        if ($oopsUrl) {
            my $loginUser = TWiki::Func::wikiToUserName($wikiUserName);
            if ( $lockUser ne $loginUser ) {

                # warn user that other person is editing this topic
                TWiki::Func::redirectCgiQuery( $query, $oopsUrl );
                return 0;
            }
        }
    }

    # We are allowed to edit
    TWiki::Func::setTopicEditLock( $theWeb, $theTopic, 1 );

    return 1;
}

package TWiki::Plugins::Table;

use vars qw(
  %regex
);
$regex{edit_table_plugin} = '%EDITTABLE{(.*)}%';

=pod

=cut

sub new {
    my ( $class, $topicContents ) = @_;
    my $this = {};
    bless $this, $class;
    $this->_parseOutTables($topicContents);
    return $this;
}

=pod

TODO: this is currently only used for label tags, so this seams a lot of overhead for such a small thing

The guts of this routine was initially copied from SpreadSheetPlugin.pm
and were used in the ChartPlugin Table object which this was copied from,
but this has been modified to support the functionality needed by the
EditTablePlugin.  One major change is to only count and save tables
following an %EDITTABLE{.*}% tag.

This routine basically returns an array of hashes where each hash
contains the information for a single table.  Thus the first hash in the
array represents the first table found on the topic page, the second hash
in the array represents the second table found on the topic page, etc.

=cut

sub _parseOutTables {
    my ( $this, $topic ) = @_;
    my $tableNum = 1;    # Table number (only count tables with EDITTABLE tag)
    my @tableMatrix;     # Currently parsed table.

    my $inEditTable = 0; # Flag to keep track if in an EDITTABLE table
    my $insidePRE   = 0;
    my $insideTABLE = 0;
    my $line        = '';
    my @row         = ();

    foreach ( split( /\n/, $topic ) ) {

        # change state:
        m|<pre\b|i      && ( $insidePRE = 1 );
        m|<verbatim\b|i && ( $insidePRE = 1 );
        m|</pre>|i      && ( $insidePRE = 0 );
        m|</verbatim>|i && ( $insidePRE = 0 );

        if ( !$insidePRE ) {
            $inEditTable = 1 if (/$regex{edit_table_plugin}/);
            if ($inEditTable) {
                if (/^\s*\|.*\|\s*$/) {

                    # inside | table |
                    $insideTABLE = 1;
                    $line        = $_;
                    $line =~ s/^(\s*\|)(.*)\|\s*$/$2/o;    # Remove starting '|'
                    @row = split( /\|/o, $line, -1 );
                    _trim( \@row );
                    push( @tableMatrix, [@row] );

                }
                else {

                    # outside | table |
                    if ($insideTABLE) {

                        # We were inside a table and are now outside of it so
                        # save the table info into the Table object.
                        $insideTABLE = 0;
                        $inEditTable = 0;
                        if ( @tableMatrix != 0 ) {

                            # Save the table via its table number
                            $$this{"TABLE_$tableNum"} = [@tableMatrix];
                            $tableNum++;
                        }
                        undef @tableMatrix;    # reset table matrix
                    }
                }
            }
        }
    }
    $$this{NUM_TABLES} = $tableNum;
}

=pod

Trim any leading and trailing white space and/or '*'.

=cut

sub _trim {
    my ($totrim) = @_;
    for my $element (@$totrim) {
        $element =~ s/^[\s\*]+//;    # Strip of leading white/*
        $element =~ s/[\s\*]+$//;    # Strip of trailing white/*
    }
}

=pod

Return the contents of the specified cell

=cut

sub getCell {
    my ( $this, $tableNum, $row, $column ) = @_;

    my @selectedTable = $this->getTable($tableNum);
    my $value         = $selectedTable[$row][$column];
    return $value;
}

=pod

=cut

sub getTable {
    my ( $this, $tableNumber ) = @_;
    my $table = $$this{"TABLE_$tableNumber"};
    return @$table if defined($table);
    return ();
}

1;
