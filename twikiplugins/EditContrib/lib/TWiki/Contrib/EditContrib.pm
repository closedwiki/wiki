# Partially derived from bin/edit and /lib/TWiki/UI/Edit.pm; omitted topic
# creation related code

package TWiki::Contrib::EditContrib;

use vars qw( $VERSION );

use strict;
use CGI::Carp qw(fatalsToBrowser);
use CGI;
use TWiki;
use TWiki::UI;

$VERSION = 1.001;

# =========================
sub handleUrlParam {
    my( $theParam ) = @_;
    return TWiki::handleUrlParam( $theParam );
}

# =========================
sub savemulti {
  my( $webName, $topic, $userName, $query, $editlink ) = @_;

  my $redirecturl = TWiki::Func::getViewUrl( $webName, $topic );

  my $nl = "\n"; # ( $query->param( 'newline' ) )?"\n":" ";

  my $saveaction = lc($query->param( 'action' ));
  if ( $saveaction eq "checkpoint" ) {
    $query->param( -name=>"dontnotify", -value=>"checked" );
    $query->param( -name=>"unlock", -value=>'0' );
    $redirecturl = $editlink;
  } elsif ( $saveaction eq "quietsave" ) {
    $query->param( -name=>"dontnotify", -value=>"checked" );
  } elsif ( $saveaction eq "cancel" ) {
    my $viewURL = TWiki::Func::getScriptUrl( $webName, $topic, "view" );
    TWiki::redirect( $query, "$viewURL?unlock=on" );
    return;
  } elsif( $saveaction eq "preview" ) {
    my $text = $query->param( 'pretxt' ) . $query->param( 'text' ) . $nl . $query->param( 'postxt' );
    if( $TWiki::Plugins::VERSION >= 1.1 ) {
        $text = TWiki::entityDecode( $text );
    } else {
        $text = TWiki::Render::decodeSpecialChars( $text );
    }
    $query->param( -name=>"text", -value=>$text);
    TWiki::UI::Preview::preview( $webName, $topic, $userName, $query );
    return;
  }

  # save called by preview
  # $query->param( -name=>"text", -value=>$query->param( 'pretxt' ) . $nl . $query->param( 'text' ) . $query->param( 'postxt' ));
  my $text = $query->param( 'pretxt' ) . $nl . $query->param( 'text' ) . $nl . $query->param( 'postxt' );

  if( $TWiki::Plugins::VERSION >= 1.1 ) {
      $text = TWiki::entityDecode( $text );
  } else {
      $text = TWiki::Render::decodeSpecialChars( $text );
  }

  my $oopsurl = TWiki::Func::saveTopicText( $webName, $topic, $text, 0, 0 );
  if ( $oopsurl ) {
      TWiki::Func::redirectCgiQuery( $query, $oopsurl );
  } else { 
      TWiki::Func::redirectCgiQuery( $query, $redirecturl );
  }
  
}

# =========================
sub passFormForEdit
{
    my( $web, $topic, $form, $meta, $query, @fieldsInfo ) = @_;

    my $mandatoryFieldsPresent = 0;

    # FIXME could do with some of this being in template
    my $text = "";
               
    TWiki::Form::fieldVars2Meta( $web, $query, $meta, "override" );
    
    foreach my $c ( @fieldsInfo ) {
        my @fieldInfo = @$c;
        my $fieldName = shift @fieldInfo;
        my $name = $fieldName;
        my $title = shift @fieldInfo;
        my $type = shift @fieldInfo;
        my $size = shift @fieldInfo;
        my $tooltip = shift @fieldInfo;
        my $attributes = shift @fieldInfo;
	$mandatoryFieldsPresent = 1 if $attributes =~ /M/;

        my %field = $meta->findOne( "FIELD", $fieldName );
        my $value = $field{"value"};
        if( ! defined( $value ) && $attributes =~ /S/ ) {
            # Allow initialisation based on a preference
            $value = &TWiki::Prefs::getPreferencesValue($fieldName);
        }
        $value = "" unless defined $value;  # allow "0" values
	my $extra = ($attributes =~ /M/) ? "<font color=\"red\">*</font>" : "";

        $tooltip =~ s/&/&amp\;/g;
        $tooltip =~ s/"/&quot\;/g;
        $tooltip =~ s/</&lt\;/g;
        $tooltip =~ s/>/&gt\;/g;

	# Generate hidden inputs for each form field
	$value =~ s/&/&amp\;/go;
	$value =~ s/"/&quot\;/go; # Make sure double quote don't kill us
	$value =~ s/</&lt\;/go;
	$value =~ s/>/&gt\;/go;
	$value = "<input type=\"hidden\" name=\"$name\" size=\"$size\" value=\"$value\" />";
        $text .= "$value\n";
    }
    
    return $text;
}

# =========================
sub quoteForXml {
    my ($text) = @_;
    $text =~ s/&/&amp\;/go;
    $text =~ s/\"/&quot;/g;
    $text =~ s/</&lt\;/go;
    $text =~ s/>/&gt\;/go;
    $text =~ s/\t/   /go;
    return $text;
}

# =========================
sub init_edit {

    my $query = shift; 

    my $thePathInfo = $query->path_info(); 
    my $theRemoteUser = $query->remote_user();
    my $theTopic = $query->param( 'topic' ) || "";
    my $theUrl = $query->url;

    my( $topic, $webName, $dummy, $userName ) = 
	&TWiki::initialize( $thePathInfo, $theRemoteUser, $theTopic, $theUrl, $query );
    $dummy = "";  # to suppress warning

    my $breakLock = $query->param( 'breaklock' ) || "";

    return unless TWiki::Func::webExists( $webName, $topic );

    # return if TWiki::UI::isMirror( $webName, $topic );

    my $topicExists  = &TWiki::Func::topicExists( $webName, $topic );

    # Read topic 
    unless( $topicExists ) {
	my $url = &TWiki::getOopsUrl( $webName, $topic, "oopsmissing" );
        print $query->redirect( $url );
        return;
    }

    # Check access controls
    my $wikiUserName = &TWiki::Func::userToWikiName( $userName );
    return unless TWiki::Func::checkAccessPermission( 'CHANGE', 
                                                      $wikiUserName, '',
                                                      $webName, $topic );

    # Check for locks
    my( $lockUser, $lockTime ) = &TWiki::Func::checkTopicEditLock( $webName, $topic );
    # if( ( ! $breakLock ) && ( $lockUser ) ) {
    #     # warn user that other person is editing this topic
    #     $lockUser = &TWiki::userToWikiName( $lockUser );
    #     use integer;
    #     $lockTime = ( $lockTime / 60 ) + 1; # convert to minutes
    #     my $editLock = $TWiki::editLockTime / 60;
    #     TWiki::UI::oops( $webName, $topic, "locked",
    #     		 $lockUser, $editLock, $lockTime );
    #     return;
    # }
    &TWiki::Func::setTopicEditLock( $webName, $topic, 1 );

    return ($query, $topic, $webName);
}

# =========================
sub edit {

    my ($query,$topic,$webName) = init_edit( @_ );
    return unless ($query);

    my ( $meta, $text ) = &TWiki::Func::readTopic( $webName, $topic );

    my $templateWeb = $webName;
    my $skin = $query->param( "skin" );
    my $theParent = $query->param( 'topicparent' ) || "";
    my $ptext = $query->param( 'text' );
    my $tmpl = "";
    my $extra = "";

    # Get edit template, standard or a different skin
    $skin = TWiki::Func::getPreferencesValue( "SKIN" ) unless ( $skin );
    $tmpl = &TWiki::Func::readTemplate( "editsection", $skin );

    # parent setting
    if( $theParent eq "none" ) {
      $meta->remove( "TOPICPARENT" );
    } elsif( $theParent ) {
      if( $theParent =~ /^([^.]+)\.([^.]+)$/ ) {
	my $parentWeb = $1;
	if( $1 eq $webName ) {
	  $theParent = $2;
	}
      }
      $meta->put( "TOPICPARENT", ( "name" => $theParent ) );
    }
    $tmpl =~ s/%TOPICPARENT%/$theParent/;

    # Handle protective encoding only for edited section below

    if( $TWiki::Plugins::VERSION >= 1.1 ) {
    } else {
    if( $TWiki::doLogTopicEdit ) {
        # write log entry
        &TWiki::Store::writeLog( "edit", "$webName.$topic", $extra );
    }
    }

    $tmpl =~ s/%CMD%//go;
    $tmpl = &TWiki::Func::expandCommonVariables( $tmpl, $topic );
    # $tmpl = &TWiki::handleMetaTags( $webName, $topic, $tmpl, $meta );
    $tmpl = &TWiki::Func::renderText( $tmpl );

    if( $TWiki::Plugins::VERSION >= 1.1 ) {

    } else {
        # Don't want to render form fields, so this after getRenderedVersion
        my %formMeta = $meta->findOne( "FORM" );
        my $form = "";
        $form = $formMeta{"name"} if( %formMeta );
        if( $form ) {
            my @fieldDefs = &TWiki::Form::getFormDef( $templateWeb, $form );
            
            if( ! @fieldDefs ) {
                TWiki::UI::oops( $webName, $topic, "noformdef" );
                  return;
              }
            my $formText = &TWiki::Contrib::EditContrib::passFormForEdit( $webName, $topic, $form, $meta, $query, @fieldDefs );
            $tmpl =~ s/%FORMFIELDS%/$formText/go;
        } elsif( TWiki::Prefs::getPreferencesValue( "WEBFORMS", $webName )) {
            # follows a hybrid html monster to let the 'choose form button' align at
            # the right of the page in all browsers
            $form = '<div style="text-align:right;"><table width="100%" border="0" cellspacing="0" cellpadding="0" class="twikiChangeFormButtonHolder"><tr><td align="right">'
                . &TWiki::Form::chooseFormButton( "Add form" )
                . '</td></tr></table></div>';
            $tmpl =~ s/%FORMFIELDS%/$form/go;
        } else {
            $tmpl =~ s/%FORMFIELDS%//go;
        }
    }
    $tmpl =~ s/%FORMTEMPLATE%//go; # Clear if not being used

    # Table

    my $width = 
       TWiki::Func::getPreferencesValue( "SECTIONEDITBOXWIDTH", $webName ) || 
       TWiki::Func::getPreferencesValue( "EDITBOXWIDTH", $webName ) || 
       60 ;
    my $height = 
       TWiki::Func::getPreferencesValue( "SECTIONEDITBOXHEIGHT", $webName ) || 
       TWiki::Func::getPreferencesValue( "EDITBOXHEIGHT", $webName ) || 
       15 ;
    my $style =
       TWiki::Func::getPreferencesValue( "SECTIONEDITBOXSTYLE", $webName ) || 
       TWiki::Func::getPreferencesValue( "EDITBOXSTYLE", $webName ) || 
       '' ;
    $tmpl =~ s/%SECTIONEDITBOXWIDTH%/$width/go;
    $tmpl =~ s/%SECTIONEDITBOXHEIGHT%/$height/go;
    $tmpl =~ s/%SECTIONEDITBOXSTYLE%/$style/go;

    return ($query, $topic, $webName, $text, $tmpl);

}

# =========================
sub finalize_edit {
    my ( $query, $topic, $webName, $pretxt, $sectxt, $postxt, $pretxtRender, $postxtRender ) = @_;
    # $_[8] is template

    if( $TWiki::Plugins::VERSION >= 1.1 ) {
        # Dakar interface
        $pretxt = &TWiki::entityEncode( $pretxt );
        $_[8] =~ s/%PRETEXTFIELD%/$pretxt/go;
        $sectxt = &TWiki::Contrib::EditContrib::quoteForXml($sectxt);

        $postxt = &TWiki::entityEncode( $postxt );
        $_[8] =~ s/%POSTEXTFIELD%/$postxt/go;

        $TWiki::Plugins::SESSION->{plugins}->beforeEditHandler( $sectxt, $topic, $webName );
    } else {
        $pretxt = &TWiki::Render::encodeSpecialChars($pretxt);
        $_[8] =~ s/%PRETEXTFIELD%/$pretxt/go;
        $sectxt = &TWiki::Contrib::EditContrib::quoteForXml($sectxt);
        $postxt = &TWiki::Render::encodeSpecialChars($postxt);
        $_[8] =~ s/%POSTEXTFIELD%/$postxt/go;
        ##AS added hook for plugins that want to do heavy stuff
        TWiki::Plugins::beforeEditHandler( $sectxt, $topic, $webName );
        ##/AS
    }

    $_[8] =~ s/%TEXT%/$sectxt/go;

    if ( $sectxt =~ /^\n/o ) {
      $_[8] =~ s/%TEXTDETAIL%/<input type="hidden" name="newline" value="t" \/>/go;
    } else {
      $_[8] =~ s/%TEXTDETAIL%//go;
    }

    # do not allow click on link before save: (mods by TedPavlic)
    my $oopsUrl = '%SCRIPTURLPATH%/oops%SCRIPTSUFFIX%/%WEB%/%TOPIC%';
    $oopsUrl = &TWiki::Func::expandCommonVariables( $oopsUrl, $topic );

    if ( $pretxtRender ) {
#      $pretxtRender = &TWiki::Contrib::EditContrib::quoteForXml($pretxtRender);
      $pretxtRender =~ s/ {3}/\t/go;
      $pretxtRender = &TWiki::Func::expandCommonVariables( $pretxtRender, $topic );
      $pretxtRender = &TWiki::Func::renderText( $pretxtRender );
      $pretxtRender =~ s@(?<=<a\s)([^>]*)(href=(?:".*?"|[^"].*?(?=[\s>])))@$1href="$oopsUrl?template=oopspreview"@goi;
      $pretxtRender =~ s@<form(?:|\s.*?)>@<form action="$oopsUrl">\n<input type="hidden" name="template" value="oopspreview">\n<input type="hidden" name="topic" value="$topic">@goi;
      $pretxtRender =~ s@(?<=<)([^\s]+?[^>]*)(onclick=(?:"location.href='.*?'"|location.href='[^']*?'(?=[\s>])))@$1onclick="location.href='$oopsUrl\?template=oopspreview'"@goi;
      $_[8] =~ s/%PRETEXT%/$pretxtRender/go;
    } else {
      $_[8] =~ s/%PRETEXT%//go;
    }
      
    if ( $postxtRender ) {
#      $postxtRender = &TWiki::Contrib::EditContrib::quoteForXml($postxtRender);
      $postxtRender =~ s/ {3}/\t/go;
      $postxtRender = &TWiki::Func::expandCommonVariables( $postxtRender, $topic );
      $postxtRender = &TWiki::Func::renderText( $postxtRender );
      $postxtRender =~ s@(?<=<a\s)([^>]*)(href=(?:".*?"|[^"].*?(?=[\s>])))@$1href="$oopsUrl?template=oopspreview"@goi;
      $postxtRender =~ s@<form(?:|\s.*?)>@<form action="$oopsUrl">\n<input type="hidden" name="template" value="oopspreview">\n<input type="hidden" name="topic" value="$topic">@goi;
      $postxtRender =~ s@(?<=<)([^\s]+?[^>]*)(onclick=(?:"location.href='.*?'"|location.href='[^']*?'(?=[\s>])))@$1onclick="location.href='$oopsUrl\?template=oopspreview'"@goi;
      $_[8] =~ s/%POSTEXT%/$postxtRender/go;
    } else {
      $_[8] =~ s/%POSTEXT%//go;
    }
    
    $_[8] =~ s|( ?) *</*nop/*>\n?|$1|gois;   # remove <nop> tags

    # TWiki::writeHeaderFull ( $query, 'edit', 'text/html', length($_[8]) );
    TWiki::Func::writeHeader( $query, length($_[8]) );

    print $_[8];

}

## Random URL:
# returns 4 random bytes in 0x01-0x1f range in %xx form
# =========================
sub randomURL
{
  my (@hc) = (qw (01 02 03 04 05 06 07 08 09 0b 0c 0d 0e 0f 10
                  11 12 13 14 15 16 17 18 19 1a 1b 1c 1d 1e 1f));
  #  srand; # needed only for perl < 5.004
  return "%$hc[rand(30)]%$hc[rand(30)]%$hc[rand(30)]%$hc[rand(30)]";
}


1;
