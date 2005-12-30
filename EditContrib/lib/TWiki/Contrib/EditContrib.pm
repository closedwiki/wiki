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

  my $redirecturl = TWiki::getViewUrl( TWiki::Store::normalizeWebTopicName($webName, $topic));

  my $saveaction = lc($query->param( 'action' ));
  if ( $saveaction eq "checkpoint" ) {
    $query->param( -name=>"dontnotify", -value=>"checked" );
    $query->param( -name=>"unlock", -value=>'0' );
    $redirecturl = $editlink;
  } elsif ( $saveaction eq "quietsave" ) {
    $query->param( -name=>"dontnotify", -value=>"checked" );
  } elsif ( $saveaction eq "cancel" ) {
    my $viewURL = TWiki::getScriptUrl( 0, 'view', $webName, $topic,
                                       'unlock' => 'on' );
    TWiki::redirect( $query, $viewURL );
    return;
  } elsif( $saveaction eq "preview" ) {
    my $text = $query->param( 'pretxt' ) . $query->param( 'text' ) . $query->param( 'postxt' );
    $text = TWiki::Render::decodeSpecialChars( $text );
    $query->param( -name=>"text", -value=>$text);
    TWiki::UI::Preview::preview( $webName, $topic, $userName, $query );
    return;
  }

  # save called by preview
  $query->param( -name=>"text", -value=>$query->param( 'pretxt' ) . $query->param( 'text' ) . $query->param( 'postxt' ));
  if ( TWiki::UI::Save::_save( $webName, $topic, $userName, $query )) {
    TWiki::redirect( $query, $redirecturl );
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
    my $query = new CGI;

    my $thePathInfo = $query->path_info(); 
    my $theRemoteUser = $query->remote_user();
    my $theUrl = $query->url;
    my $theTopic = $query->param( 'topic' ) || "";

    my( $topic, $webName, $dummy, $userName ) = 
	&TWiki::initialize( $thePathInfo, $theRemoteUser, $theTopic, $theUrl, $query );
    $dummy = "";  # to suppress warning

    my $breakLock = $query->param( 'breaklock' ) || "";

    return unless TWiki::UI::webExists( $webName, $topic );

    return if TWiki::UI::isMirror( $webName, $topic );

    my $topicExists  = &TWiki::Store::topicExists( $webName, $topic );

    # Read topic 
    unless( $topicExists ) {
	my $url = &TWiki::getOopsUrl( $webName, $topic, "oopsmissing" );
        print $query->redirect( $url );
        return;
    }

    # Check access controls
    my $wikiUserName = &TWiki::userToWikiName( $userName );
    return unless TWiki::UI::isAccessPermitted( $webName, $topic,
                                            "change", $wikiUserName );

    # Check for locks
    my( $lockUser, $lockTime ) = &TWiki::Store::topicIsLockedBy( $webName, $topic );
    if( ( ! $breakLock ) && ( $lockUser ) ) {
        # warn user that other person is editing this topic
        $lockUser = &TWiki::userToWikiName( $lockUser );
        use integer;
        $lockTime = ( $lockTime / 60 ) + 1; # convert to minutes
        my $editLock = $TWiki::editLockTime / 60;
	TWiki::UI::oops( $webName, $topic, "locked",
			 $lockUser, $editLock, $lockTime );
        return;
    }
    &TWiki::Store::lockTopic( $topic );

    return ($query, $topic, $webName);
}

# =========================
sub edit {

    my ($query, $topic, $webName ) = init_edit( );

    return unless ($query);
    my ( $meta, $text ) = &TWiki::Store::readTopic( $webName, $topic );

    my $templateWeb = $webName;
    my $skin = $query->param( "skin" );
    my $theParent = $query->param( 'topicparent' ) || "";
    my $ptext = $query->param( 'text' );
    my $tmpl = "";
    my $extra = "";

    # Get edit template, standard or a different skin
    $skin = TWiki::Prefs::getPreferencesValue( "SKIN" ) unless ( $skin );
    $tmpl = &TWiki::Store::readTemplate( "editsection", $skin );

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

    if( $TWiki::doLogTopicEdit ) {
        # write log entry
        &TWiki::Store::writeLog( "edit", "$webName.$topic", $extra );
    }

    $tmpl =~ s/%CMD%//go;
    $tmpl = &TWiki::handleCommonTags( $tmpl, $topic );
    $tmpl = &TWiki::handleMetaTags( $webName, $topic, $tmpl, $meta );
    $tmpl = &TWiki::Func::renderText( $tmpl );

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
    
    $tmpl =~ s/%FORMTEMPLATE%//go; # Clear if not being used

    # Table

    my $width = 
       TWiki::Prefs::getPreferencesValue( "SECTIONEDITBOXWIDTH", $webName ) || 
       TWiki::Prefs::getPreferencesValue( "EDITBOXWIDTH", $webName );
    my $height = 
       TWiki::Prefs::getPreferencesValue( "SECTIONEDITBOXHEIGHT", $webName ) || 
       TWiki::Prefs::getPreferencesValue( "EDITBOXHEIGHT", $webName );
    my $style =
       TWiki::Prefs::getPreferencesValue( "SECTIONEDITBOXSTYLE", $webName ) || 
       TWiki::Prefs::getPreferencesValue( "EDITBOXSTYLE", $webName );
    $tmpl =~ s/%SECTIONEDITBOXWIDTH%/$width/go;
    $tmpl =~ s/%SECTIONEDITBOXHEIGHT%/$height/go;
    $tmpl =~ s/%SECTIONEDITBOXSTYLE%/$style/go;

    return ($query, $topic, $webName, $text, $tmpl);

}

# =========================
sub finalize_edit {
    my ( $query, $topic, $webName, $pretxt, $sectxt, $postxt, $pretxtRender, $postxtRender ) = @_;
    # $_[8] is template

    $pretxt = &TWiki::Render::encodeSpecialChars($pretxt);
    $_[8] =~ s/%PRETEXTFIELD%/$pretxt/go;
    $sectxt = &TWiki::Contrib::EditContrib::quoteForXml($sectxt);
    $postxt = &TWiki::Render::encodeSpecialChars($postxt);
    $_[8] =~ s/%POSTEXTFIELD%/$postxt/go;
    
    ##AS added hook for plugins that want to do heavy stuff
    TWiki::Plugins::beforeEditHandler( $sectxt, $topic, $webName );
    ##/AS

    $_[8] =~ s/%TEXT%/$sectxt/go;

    # do not allow click on link before save: (mods by TedPavlic)
    my $oopsUrl = '%SCRIPTURLPATH%/oops%SCRIPTSUFFIX%/%WEB%/%TOPIC%';
    $oopsUrl = &TWiki::handleCommonTags( $oopsUrl, $topic );

    if ( $pretxtRender ) {
#      $pretxtRender = &TWiki::Contrib::EditContrib::quoteForXml($pretxtRender);
      $pretxtRender =~ s/ {3}/\t/go;
      $pretxtRender = &TWiki::handleCommonTags( $pretxtRender, $topic );
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
      $postxtRender = &TWiki::handleCommonTags( $postxtRender, $topic );
      $postxtRender = &TWiki::Func::renderText( $postxtRender );
      $postxtRender =~ s@(?<=<a\s)([^>]*)(href=(?:".*?"|[^"].*?(?=[\s>])))@$1href="$oopsUrl?template=oopspreview"@goi;
      $postxtRender =~ s@<form(?:|\s.*?)>@<form action="$oopsUrl">\n<input type="hidden" name="template" value="oopspreview">\n<input type="hidden" name="topic" value="$topic">@goi;
      $postxtRender =~ s@(?<=<)([^\s]+?[^>]*)(onclick=(?:"location.href='.*?'"|location.href='[^']*?'(?=[\s>])))@$1onclick="location.href='$oopsUrl\?template=oopspreview'"@goi;
      $_[8] =~ s/%POSTEXT%/$postxtRender/go;
    } else {
      $_[8] =~ s/%POSTEXT%//go;
    }
    
    $_[8] =~ s|( ?) *</*nop/*>\n?|$1|gois;   # remove <nop> tags

    TWiki::writeHeaderFull ( $query, 'edit', 'text/html', length($_[8]) );

    print $_[8];

}



1;
