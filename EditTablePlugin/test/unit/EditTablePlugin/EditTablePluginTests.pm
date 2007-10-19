use strict;

# tests for basic formatting

package EditTablePluginTests;

use base qw( TWikiFnTestCase );

use strict;
use TWiki::UI::Save;
use Error qw( :try );
use TWiki::Plugins::EditTablePlugin;
use TWiki::Plugins::EditTablePlugin::Core;

sub new {
    my $self = shift()->SUPER::new( 'EditTableFunctions', @_ );
    return $self;
}

sub set_up {
    my $this = shift;

    $this->SUPER::set_up();

    #    $this->{sup} = $this->{twiki}->getScriptUrl(0, 'view');
    $TWiki::cfg{AntiSpam}{RobotsAreWelcome} = 1;
    $TWiki::cfg{AllowInlineScript} = 0;
    $ENV{SCRIPT_NAME} = '';    #  required by fake sort URLs in expected text
}

# This formats the text up to immediately before <nop>s are removed, so we
# can see the nops.
sub do_testHtmlOutput {
    my ( $this, $expected, $actual, $doRender ) = @_;
    my $session   = $this->{twiki};
    my $webName   = $this->{test_web};
    my $topicName = $this->{test_topic};

    if ($doRender) {
        $actual =
          TWiki::Func::expandCommonVariables( $actual, $webName, $topicName );
        $actual =
          $session->renderer->getRenderedVersion( $actual, $webName,
            $topicName );
    }
    $this->assert_html_equals( $expected, $actual );
}

=pod

=cut

sub test_viewSimple {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      TWiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlTWikiWeb =
      TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath() . '/TWiki';

    $this->{twiki}->{store}
      ->saveTopic( $this->{twiki}->{user}, $webName, $topicName, "XXX" );

    my $raw_tag  = 'SOMETHING %EDITTABLE{}%';
    my $expected = <<END;
SOMETHING <a name="edittable1"></a>
<div class="editTable"><form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input class="twikiInputField" type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<input type="hidden" name="etrows" value="0" />
<input class="editTableEditImageButton" type="image" src="$pubUrlTWikiWeb/EditTablePlugin/edittable.gif" alt="Edit this table" /></form>
</div><!-- /editTable -->
END
    my $result =
      $this->{twiki}->handleCommonTags( $raw_tag, $webName, $topicName );

    $this->do_testHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_viewEditButton {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      TWiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlTWikiWeb =
      TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath() . '/TWiki';

    $this->{twiki}->{store}
      ->saveTopic( $this->{twiki}->{user}, $webName, $topicName, "XXX" );

    my $raw_tag  = '%EDITTABLE{editbutton="Edit me"}%';
    my $expected = <<END;
<a name="edittable1"></a>
<div class="editTable"><form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input class="twikiInputField" type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<input type="hidden" name="etrows" value="0" />
<input class="twikiButton editTableEditButton" type="submit" value="Edit me" /></form>
</div><!-- /editTable -->
END
    my $result =
      $this->{twiki}->handleCommonTags( $raw_tag, $webName, $topicName );

    $this->do_testHtmlOutput( $expected, $result, 0 );
}

=pod

=cut

sub test_editSimple {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      TWiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlTWikiWeb =
      TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath() . '/TWiki';

    my $query = new CGI(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    my $text = <<INPUT;
SOMETHING %EDITTABLE{}%
INPUT

    my $twiki = new TWiki( undef, $query );
    $TWiki::Plugins::SESSION = $twiki;
    my $result =
      TWiki::Func::expandCommonVariables( $text, $topicName, $webName, undef );

    my $expected = <<EXPECTED;
SOMETHING <a name="edittable1"></a>
<div class="editTable"><form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input class="twikiInputField" type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<input type="hidden" name="etrows" value="0" />
<input class="editTableEditImageButton" type="image" src="$pubUrlTWikiWeb/EditTablePlugin/edittable.gif" alt="Edit this table" /></form>
</div><!-- /editTable -->
EXPECTED

    $this->do_testHtmlOutput( $expected, $result, 0 );
    $twiki->finish();
}

=pod

=cut

sub test_editFormat {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      TWiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlTWikiWeb = TWiki::Func::getPubUrlPath() . '/TWiki';

    my $input = <<INPUT;
SOMETHING %EDITTABLE{format="| row, -1 | text, 10, init | textarea, 3x10, init | select, 3, option 1, option 2, option 3 | radio, 3, A, B, C, D, E | checkbox, 3, A, B, C, D, E | label, 0, LABEL | date,11,,%d %b %Y |"}%
INPUT

    my $query = new CGI(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");

    my $twiki = new TWiki( undef, $query );
    $TWiki::Plugins::SESSION = $twiki;

    my $result =
      TWiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web}, undef );

    my $expected = <<EXPECTED;
SOMETHING <noautolink>
<a name="edittable1"></a>
<div class="editTable editTableEdit"><form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input class="twikiInputField" type="hidden" name="ettablenr" value="1" />
|<div class="et_rowlabel">0<input type="hidden" name="etcell1x1" value="0" /></div> |<input class="twikiInputField editTableInput" type="text" name="etcell1x2" size="10" value="--EditTableEncodeStart--.i.n.i.t--EditTableEncodeEnd--" /> |<textarea class="twikiTextarea editTableTextarea" rows="3" cols="10" name="etcell1x3">--EditTableEncodeStart--.i.n.i.t--EditTableEncodeEnd--</textarea> |<select class="twikiSelect" name="etcell1x4" size="3"> <option selected="selected">option 1</option> <option>option 2</option> <option>option 3</option></select> |<table class="editTableInnerTable"><tr><td valign="top"> <input type="radio" name="etcell1x5" value="A" /> A <br /> <input type="radio" name="etcell1x5" value="B" /> B </td><td valign="top"> <input type="radio" name="etcell1x5" value="C" /> C <br /> <input type="radio" name="etcell1x5" value="D" /> D </td><td valign="top"> <input type="radio" name="etcell1x5" value="E" /> E <br /></td></tr></table> |<table class="editTableInnerTable"><tr><td valign="top"> <input type="checkbox" name="etcell1x6x2" value="A" checked="checked" /> A <br /> <input type="checkbox" name="etcell1x6x3" value="B" checked="checked" /> B </td><td valign="top"> <input type="checkbox" name="etcell1x6x4" value="C" checked="checked" /> C <br /> <input type="checkbox" name="etcell1x6x5" value="D" checked="checked" /> D </td><td valign="top"> <input type="checkbox" name="etcell1x6x6" value="E" checked="checked" /> E <br /></td></tr></table> <input type="hidden" name="etcell1x6" value="Chkbx: etcell1x6x2 etcell1x6x3 etcell1x6x4 etcell1x6x5 etcell1x6x6" /> |LABEL<input type="hidden" name="etcell1x7" value="--EditTableEncodeStart--.L.A.B.E.L--EditTableEncodeEnd--" /> |<input type="text" name="etcell1x8"  size="11" class="twikiInputField editTableInput" id="idetcell1x8" /><span class="twikiMakeVisible"><input type="image" name="calendar" src="$pubUrlTWikiWeb/JSCalendarContrib/img.gif" align="middle" alt="Calendar" onclick="return showCalendar('idetcell1x8','%d %b %Y')" class="editTableCalendarButton" /></span> |
<input type="hidden" name="etrows" value="1" />
<input type="submit" name="etsave" id="etsave" value="Save table" class="twikiSubmit" />
<input type="submit" name="etqsave" id="etqsave" value="Quiet save" class="twikiButton" />
<input type="submit" name="etaddrow" id="etaddrow" value="Add row" class="twikiButton" />
<input type="submit" name="etdelrow" id="etdelrow" value="Delete last row" class="twikiButton" />
<input type="submit" name="etcancel" id="etcancel" value="Cancel" class="twikiButton twikiButtonCancel" />
</form>
</div><!-- /editTable --></noautolink>
EXPECTED
    $this->do_testHtmlOutput( lc $expected, lc $result, 0 );
    $twiki->finish();
}

sub test_editAddRow {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      TWiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlTWikiWeb =
      TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath() . '/TWiki';

    my $input = <<INPUT;
%EDITTABLE{format="| row, -1 | text, 10, init|"}%
| 0 | init |
INPUT

    my $query = new CGI(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );

    $query->path_info("/$webName/$topicName");

    my $twiki = new TWiki( undef, $query );
    $TWiki::Plugins::SESSION = $twiki;

    my $result =
      TWiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web}, undef );

    my $expected = <<EXPECTED;
<noautolink>
<a name="edittable1"></a>
<div class="editTable editTableEdit"><form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input class="twikiInputField" type="hidden" name="ettablenr" value="1" />
|<div class="et_rowlabel">0<input type="hidden" name="etcell1x1" value="0" /></div> |<input class="twikiInputField editTableInput" type="text" name="etcell1x2" size="10" value="--EditTableEncodeStart--.i.n.i.t--EditTableEncodeEnd--" /> |
<input type="hidden" name="etrows" value="1" />
<input type="submit" name="etsave" id="etsave" value="Save table" class="twikiSubmit" />
<input type="submit" name="etqsave" id="etqsave" value="Quiet save" class="twikiButton" />
<input type="submit" name="etaddrow" id="etaddrow" value="Add row" class="twikiButton" />
<input type="submit" name="etdelrow" id="etdelrow" value="Delete last row" class="twikiButton" />
<input type="submit" name="etcancel" id="etcancel" value="Cancel" class="twikiButton twikiButtonCancel" />
</form>
</div><!-- /editTable --></noautolink>
EXPECTED
    $this->do_testHtmlOutput( $expected, $result, 0 );

    # Add 2 rows
    $query = new CGI(
        {
            etedit    => ['on'],
            etaddrow  => ['1'],
            etrows    => ['3'],
            ettablenr => ['1'],
            etcell1x2 => ['test1'],
            etcell2x2 => ['test2'],
            etcell3x2 => ['test3'],
        }
    );

    $query->path_info("/$webName/$topicName");

    $twiki = new TWiki( undef, $query );
    $TWiki::Plugins::SESSION = $twiki;

    $result =
      TWiki::Func::expandCommonVariables( $input, $this->{test_topic},
        $this->{test_web}, undef );

    $expected = <<EXPECTED;
<noautolink>
<a name="edittable1"></a>
<div class="editTable editTableEdit"><form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input class="twikiInputField" type="hidden" name="ettablenr" value="1" />
<nop>
<nop>
<nop>
<nop>
<table cellspacing="0" id="default" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
		<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol"> <div class="et_rowlabel">0<input type="hidden" name="etcell1x1" value="0" /></div> </td>
		<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLastCol"> <input class="twikiInputField editTableInput" type="text" name="etcell1x2" size="10" value="test1" /> </td>
	</tr>
	<tr class="twikiTableOdd twikiTableRowdataBgSorted1 twikiTableRowdataBg1">
		<td bgcolor="#edf4f9" valign="top" class="twikiTableCol0 twikiFirstCol"> <div class="et_rowlabel">1<input type="hidden" name="etcell2x1" value="1" /></div> </td>
		<td bgcolor="#edf4f9" valign="top" class="twikiTableCol1 twikiLastCol"> <input class="twikiInputField editTableInput" type="text" name="etcell2x2" size="10" value="test2" /> </td>
	</tr>
	<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
		<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol"> <div class="et_rowlabel">2<input type="hidden" name="etcell3x1" value="2" /></div> </td>

		<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLastCol"> <input class="twikiInputField editTableInput" type="text" name="etcell3x2" size="10" value="test3" /> </td>
	</tr>
	<tr class="twikiTableOdd twikiTableRowdataBgSorted1 twikiTableRowdataBg1">
		<td bgcolor="#edf4f9" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> <div class="et_rowlabel">3<input type="hidden" name="etcell4x1" value="3" /></div> </td>
		<td bgcolor="#edf4f9" valign="top" class="twikiTableCol1 twikiLastCol twikiLast"> <input class="twikiInputField editTableInput" type="text" name="etcell4x2" size="10" value="init" /> </td>
	</tr></table>
<input type="hidden" name="etrows" value="4" />
<input type="submit" name="etsave" id="etsave" value="Save table" class="twikiSubmit" />
<input type="submit" name="etqsave" id="etqsave" value="Quiet save" class="twikiButton" />
<input type="submit" name="etaddrow" id="etaddrow" value="Add row" class="twikiButton" />
<input type="submit" name="etdelrow" id="etdelrow" value="Delete last row" class="twikiButton" />
<input type="submit" name="etcancel" id="etcancel" value="Cancel" class="twikiButton twikiButtonCancel" />
</form>
</div><!-- /editTable --></noautolink>
EXPECTED
    $this->do_testHtmlOutput( $expected, $result, 1 );

    $query = new CGI(
        {
            etsave    => ['on'],
            etrows    => ['3'],
            ettablenr => ['1'],
            etcell1x2 => ['test1'],
            etcell2x2 => ['test2'],
            etcell3x2 => ['test3'],
        }
    );
    $query->path_info("/$webName/$topicName");

    TWiki::Func::saveTopic( $this->{test_web}, $this->{test_topic}, undef,
        $input );

    $twiki = new TWiki( undef, $query );
    $TWiki::Plugins::SESSION = $twiki;

    my ( $saveResult, $ecode ) = $this->capture(
        sub {
            print TWiki::Func::expandCommonVariables( $input,
                $this->{test_topic}, $this->{test_web}, undef );
        }
    );
    $this->assert( $saveResult =~ /Status: 302/ );

    my ( $meta, $newtext ) = TWiki::Func::readTopic( $webName, $topicName );

    $expected = <<NEWEXPECTED;
%EDITTABLE{format="| row, -1 | text, 10, init|"}%
|  | test1 |
|  | test2 |
|  | test3 |
NEWEXPECTED
    $this->assert_str_equals( $expected, $newtext, 0 );

    $twiki->finish();
}

=pod

Test select dropdown box

=cut

sub test_SelectBox {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      TWiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlTWikiWeb =
      TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath() . '/TWiki';

    my $query = new CGI(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );
    $query->path_info("/$webName/$topicName");

    my $text = <<INPUT;
%EDITTABLE{format="|select, 1, a, b, c, d|select,1,a,b,c,d|select,1 ,a , b, c, d|select, 1 , a , b , c , d |" }%
| c | c | c | c |
INPUT

    my $twiki = new TWiki( undef, $query );
    $TWiki::Plugins::SESSION = $twiki;
    my $result =
      TWiki::Func::expandCommonVariables( $text, $topicName, $webName, undef );

    my $expected = <<END;
<noautolink>
<a name="edittable1"></a>
<div class="editTable editTableEdit"><form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input class="twikiInputField" type="hidden" name="ettablenr" value="1" />
<nop>
<table cellspacing="0" id="default" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
		<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> <select class="twikiSelect" name="etcell1x1" size="1"> <option>a</option> <option>b</option> <option selected="selected">c</option> <option>d</option></select> </td>
		<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLast"> <select class="twikiSelect" name="etcell1x2" size="1"> <option>a</option> <option>b</option> <option selected="selected">c</option> <option>d</option></select> </td>
		<td bgcolor="#ffffff" valign="top" class="twikiTableCol2 twikiLast"> <select class="twikiSelect" name="etcell1x3" size="1 "> <option>a </option> <option>b</option> <option selected="selected">c</option> <option>d</option></select> </td>
		<td bgcolor="#ffffff" valign="top" class="twikiTableCol3 twikiLastCol twikiLast"> <select class="twikiSelect" name="etcell1x4" size="1 "> <option>a </option> <option>b </option> <option selected="selected">c </option> <option>d</option></select> </td>
	</tr></table>
<input type="hidden" name="etrows" value="1" />
<input type="submit" name="etsave" id="etsave" value="Save table" class="twikiSubmit" />
<input type="submit" name="etqsave" id="etqsave" value="Quiet save" class="twikiButton" />
<input type="submit" name="etaddrow" id="etaddrow" value="Add row" class="twikiButton" />
<input type="submit" name="etdelrow" id="etdelrow" value="Delete last row" class="twikiButton" />
<input type="submit" name="etcancel" id="etcancel" value="Cancel" class="twikiButton twikiButtonCancel" />
</form>
</div><!-- /editTable --></noautolink>
END

    $this->do_testHtmlOutput( $expected, $result, 1 );
    $twiki->finish();
}

=pod

Test select dropdown box

=cut

sub test_VariableExpansionInCheckboxAndRadioButtons {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      TWiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlTWikiWeb =
      TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath() . '/TWiki';

    my $query = new CGI(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );
    $query->path_info("/$webName/$topicName");

    my $text = <<INPUT;
%EDITTABLE{format="| radio, 1, :skull:, :cool: | checkbox, 1, :skull:, :cool: |"}%
INPUT

    my $twiki = new TWiki( undef, $query );
    $TWiki::Plugins::SESSION = $twiki;
    my $result =
      TWiki::Func::expandCommonVariables( $text, $topicName, $webName, undef );

    my $expected = <<END;
<noautolink>
<a name="edittable1"></a>

<div class="editTable editTableEdit"><form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input class="twikiInputField" type="hidden" name="ettablenr" value="1" />
<nop>
<table cellspacing="0" id="default" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
		<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> <table class="editTableInnerTable"><tr><td valign="top"> <input type="radio" name="etcell1x1" value=":skull:" /> <img src="$pubUrlTWikiWeb/SmiliesPlugin/skull.gif" alt="skull" title="skull" border="0" /> <br /> <input type="radio" name="etcell1x1" value=":cool:" /> <img src="$pubUrlTWikiWeb/SmiliesPlugin/cool.gif" alt="cool!" title="cool!" border="0" /> </td></tr></table> </td>
		<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLastCol twikiLast"> <table class="editTableInnerTable"><tr><td valign="top"> <input type="checkbox" name="etcell1x2x2" value=":skull:" checked="checked" /> <img src="$pubUrlTWikiWeb/SmiliesPlugin/skull.gif" alt="skull" title="skull" border="0" /> <br /> <input type="checkbox" name="etcell1x2x3" value=":cool:" checked="checked" /> <img src="$pubUrlTWikiWeb/SmiliesPlugin/cool.gif" alt="cool!" title="cool!" border="0" /> </td></tr></table><input type="hidden" name="etcell1x2" value="Chkbx: etcell1x2x2 etcell1x2x3" /> </td>
	</tr></table>
<input type="hidden" name="etrows" value="1" />
<input type="submit" name="etsave" id="etsave" value="Save table" class="twikiSubmit" />
<input type="submit" name="etqsave" id="etqsave" value="Quiet save" class="twikiButton" />
<input type="submit" name="etaddrow" id="etaddrow" value="Add row" class="twikiButton" />
<input type="submit" name="etdelrow" id="etdelrow" value="Delete last row" class="twikiButton" />
<input type="submit" name="etcancel" id="etcancel" value="Cancel" class="twikiButton twikiButtonCancel" />
</form>
</div><!-- /editTable --></noautolink>
END

    $this->do_testHtmlOutput( $expected, $result, 1 );
    $twiki->finish();
}

=pod

Test variable placeholders like $percnt and $nop

=cut

sub test_VariablePlaveholdersView {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      TWiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $viewUrl = TWiki::Func::getScriptUrlPath()
      . "/view/$webName/$topicName"
      ;    # heck, how can I do this otherwise? I need the relative path
    my $pubUrlTWikiWeb =
      TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath() . '/TWiki';

    my $text = <<INPUT;
%EDITTABLE{format="| text, 30, \$percntY\$percnt | text, 30, %TOPIC% | text, 30, %\$nopTOPIC% |"}%
| \$percntY\$percnt | $topicName | %\$nopTOPIC% |
INPUT

    my $result =
      TWiki::Func::expandCommonVariables( $text, $topicName, $webName, undef );

    my $expected = <<END;
<a name="edittable1"></a>
<div class="editTable"><form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input class="twikiInputField" type="hidden" name="ettablenr" value="1" />
<input type="hidden" name="etedit" value="on" />
<nop>
<table cellspacing="0" id="default" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
		<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> <img src="%PUBURLPATH%/%SYSTEMWEB%/TWikiDocGraphics/choice-yes.gif" alt="DONE" title="DONE" width="16" height="16" border="0" /> </td>
		<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLast"> <a href="$viewUrl" class="twikiCurrentTopicLink twikiLink">$topicName</a> </td>
		<td bgcolor="#ffffff" valign="top" class="twikiTableCol2 twikiLastCol twikiLast"> <a href="$viewUrl" class="twikiCurrentTopicLink twikiLink">$topicName</a> </td>
	</tr></table>
<input type="hidden" name="etrows" value="1" />
<input class="editTableEditImageButton" type="image" src="$pubUrlTWikiWeb/EditTablePlugin/edittable.gif" alt="Edit this table" /></form>
</div><!-- /editTable -->
END

    $expected =~ s/%PUBURLPATH%/$TWiki::cfg{PubUrlPath}/e;
    $expected =~ s/%SYSTEMWEB%/TWiki/g;

    $this->do_testHtmlOutput( $expected, $result, 1 );
}

sub test_VariablePlaveholdersEdit {
    my $this = shift;

    my $topicName = $this->{test_topic};
    my $webName   = $this->{test_web};
    my $viewUrlAuth =
      TWiki::Func::getScriptUrl( $webName, $topicName, 'viewauth' );
    my $pubUrlTWikiWeb =
      TWiki::Func::getUrlHost() . TWiki::Func::getPubUrlPath() . '/TWiki';
    my $userName = $this->{users_web} . '.' . 'TWikiGuest';

    my $text = <<INPUT;
%EDITTABLE{format="| text, 30, \$percntY\$percnt | text, 30, %HOMETOPIC% | text, 30, %\$nopHOMETOPIC% |"}%
INPUT

    my $query = new CGI(
        {
            etedit    => ['on'],
            ettablenr => ['1'],
        }
    );
    $query->path_info("/$webName/$topicName");

    my $twiki = new TWiki( undef, $query );
    $TWiki::Plugins::SESSION = $twiki;
    my $result =
      TWiki::Func::expandCommonVariables( $text, $topicName, $webName, undef );

    my $expected = <<END;
<noautolink>
<a name="edittable1"></a>
<div class="editTable editTableEdit"><form name="edittable1" action="$viewUrlAuth#edittable1" method="post">
<input class="twikiInputField" type="hidden" name="ettablenr" value="1" />
<nop>
<table cellspacing="0" id="default" cellpadding="0" class="twikiTable" rules="rows" border="1">
	<tr class="twikiTableEven twikiTableRowdataBgSorted0 twikiTableRowdataBg0">
		<td bgcolor="#ffffff" valign="top" class="twikiTableCol0 twikiFirstCol twikiLast"> <input class="twikiInputField editTableInput" type="text" name="etcell1x1" size="30" value="\$percntY\$percnt" /> </td>
		<td bgcolor="#ffffff" valign="top" class="twikiTableCol1 twikiLast"> <input class="twikiInputField editTableInput" type="text" name="etcell1x2" size="30" value="WebHome" /> </td>
		<td bgcolor="#ffffff" valign="top" class="twikiTableCol2 twikiLastCol twikiLast"> <input class="twikiInputField editTableInput" type="text" name="etcell1x3" size="30" value="%\$nopHOMETOPIC%" /> </td>
	</tr></table>
<input type="hidden" name="etrows" value="1" />
<input type="submit" name="etsave" id="etsave" value="Save table" class="twikiSubmit" />
<input type="submit" name="etqsave" id="etqsave" value="Quiet save" class="twikiButton" />
<input type="submit" name="etaddrow" id="etaddrow" value="Add row" class="twikiButton" />
<input type="submit" name="etdelrow" id="etdelrow" value="Delete last row" class="twikiButton" />
<input type="submit" name="etcancel" id="etcancel" value="Cancel" class="twikiButton twikiButtonCancel" />
</form>
</div><!-- /editTable --></noautolink>
END

    $this->do_testHtmlOutput( $expected, $result, 1 );

    $twiki->finish();
}

1;
