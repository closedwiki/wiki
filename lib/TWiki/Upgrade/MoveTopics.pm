

package TWiki::Upgrade::MoveTopics;

use strict; 

sub moveTopics {
my ( $session ) = @_;

	if (! $session->{store}->webExists('TWikiConfiguration') ) {
		my $opts =
		{
			WEBBGCOLOR => '',
			SITEMAPWHAT => 'TWiki System Configuration',
			SITEMAPUSETO => 'configure the TWiki installation',
			NOSEARCHALL => '',
		};
		$opts->{SITEMAPLIST} = "on" if( $opts->{SITEMAPWHAT} );
	    my $err = $session->{store}->createWeb( 'TWikiConfiguration', '_default', $opts);
	}
	if (! $session->{store}->webExists('TWikiDocumentation') ) {
		my $opts =
		{
			WEBBGCOLOR => '',
			SITEMAPWHAT => 'TWiki System Documentation',
			SITEMAPUSETO => 'TWiki System Documentation',
			NOSEARCHALL => '',
		};
		$opts->{SITEMAPLIST} = "on" if( $opts->{SITEMAPWHAT} );
	    my $err = $session->{store}->createWeb( 'TWikiDocumentation', '_default', $opts );
	}
	if (! $session->{store}->webExists('Users') ) {
		my $opts =
		{
			WEBBGCOLOR => '',
			SITEMAPWHAT => 'Users',
			SITEMAPUSETO => 'Users',
			NOSEARCHALL => '',
		};
		$opts->{SITEMAPLIST} = "on" if( $opts->{SITEMAPWHAT} );
	    my $err = $session->{store}->createWeb( 'Users', '_default', $opts );
	}

	my %moveTopicsHash;

	$moveTopicsHash{"TWiki.ATasteOfTWiki"} = "TWikiDocumentation.ATasteOfTWiki";
	$moveTopicsHash{"TWiki.ATasteOfTWikiTemplate"} = "TWikiDocumentation.ATasteOfTWikiTemplate";
	$moveTopicsHash{"TWiki.AccessKeys"} = "TWikiDocumentation.AccessKeys";
	$moveTopicsHash{"TWiki.BookView"} = "TWikiDocumentation.BookView";
	$moveTopicsHash{"TWiki.BumpyWord"} = "TWikiDocumentation.BumpyWord";
	$moveTopicsHash{"TWiki.DeleteOrRenameATopic"} = "TWikiDocumentation.DeleteOrRenameATopic";
	$moveTopicsHash{"TWiki.DeleteOrRenameAnAttachment"} = "TWikiDocumentation.DeleteOrRenameAnAttachment";
	$moveTopicsHash{"TWiki.DontNotify"} = "TWikiDocumentation.DontNotify";
	$moveTopicsHash{"TWiki.DragonSkinSiteMap"} = "TWikiDocumentation.DragonSkinSiteMap";
	$moveTopicsHash{"TWiki.EditDoesNotIncreaseTheRevision"} = "TWikiDocumentation.EditDoesNotIncreaseTheRevision";
	$moveTopicsHash{"TWiki.FileAttachment"} = "TWikiDocumentation.FileAttachment";
	$moveTopicsHash{"TWiki.FileAttribute"} = "TWikiDocumentation.FileAttribute";
	$moveTopicsHash{"TWiki.GoBox"} = "TWikiDocumentation.GoBox";
	$moveTopicsHash{"TWiki.GoodStyle"} = "TWikiDocumentation.GoodStyle";
	$moveTopicsHash{"TWiki.HiddenAttachment"} = "TWikiDocumentation.HiddenAttachment";
	$moveTopicsHash{"TWiki.HowToLogOff"} = "TWikiDocumentation.HowToLogOff";
	$moveTopicsHash{"TWiki.IncludeTopicsAndWebPages"} = "TWikiDocumentation.IncludeTopicsAndWebPages";
	$moveTopicsHash{"TWiki.MainFeatures"} = "TWikiDocumentation.MainFeatures";
	$moveTopicsHash{"TWiki.ManagingTopics"} = "TWikiDocumentation.ManagingTopics";
	$moveTopicsHash{"TWiki.MoveTopic"} = "TWikiDocumentation.MoveTopic";
	$moveTopicsHash{"TWiki.PeterThoeny"} = "TWikiDocumentation.PeterThoeny";
	$moveTopicsHash{"TWiki.RegularExpression"} = "TWikiDocumentation.RegularExpression";
	$moveTopicsHash{"TWiki.QuietSave"} = "TWikiDocumentation.QuietSave";
	$moveTopicsHash{"TWiki.SimultaneousEdits"} = "TWikiDocumentation.SimultaneousEdits";
	$moveTopicsHash{"TWiki.SearchHelp"} = "TWikiDocumentation.SearchHelp";
	$moveTopicsHash{"TWiki.SearchDoesNotWork"} = "TWikiDocumentation.SearchDoesNotWork";
	$moveTopicsHash{"TWiki.SiteUsageStatistics"} = "TWikiDocumentation.SiteUsageStatistics";
	$moveTopicsHash{"TWiki.StartingPoints"} = "TWikiDocumentation.StartingPoints";
	$moveTopicsHash{"TWiki.TWikiDownload"} = "TWikiDocumentation.TWikiDownload";
	$moveTopicsHash{"TWiki.TWikiFAQ"} = "TWikiDocumentation.TWikiFAQ";
	$moveTopicsHash{"TWiki.WhatIsWikiWiki"} = "TWikiDocumentation.WhatIsWikiWiki";
	$moveTopicsHash{"TWiki.WikiCulture"} = "TWikiDocumentation.WikiCulture";
	$moveTopicsHash{"TWiki.TWikiGlossary"} = "TWikiDocumentation.TWikiGlossary";
	$moveTopicsHash{"TWiki.TWikiShorthand"} = "TWikiDocumentation.TWikiShorthand";
	$moveTopicsHash{"TWiki.TWikiSite"} = "TWikiDocumentation.TWikiSite";
	$moveTopicsHash{"TWiki.TWikiTopics"} = "TWikiDocumentation.TWikiTopics";
	$moveTopicsHash{"TWiki.TWikiTutorial"} = "TWikiDocumentation.TWikiTutorial";
	$moveTopicsHash{"TWiki.TextEditor"} = "TWikiDocumentation.TextEditor";
	$moveTopicsHash{"TWiki.TextFormattingFAQ"} = "TWikiDocumentation.TextFormattingFAQ";
	$moveTopicsHash{"TWiki.TextFormattingRules"} = "TWikiDocumentation.TextFormattingRules";
	$moveTopicsHash{"TWiki.TimBernersLee"} = "TWikiDocumentation.TimBernersLee";
	$moveTopicsHash{"TWiki.UnlockTopic"} = "TWikiDocumentation.UnlockTopic";
	$moveTopicsHash{"TWiki.WabiSabi"} = "TWikiDocumentation.WabiSabi";
	$moveTopicsHash{"TWiki.WebChangesAlert"} = "TWikiDocumentation.WebChangesAlert";
	$moveTopicsHash{"TWiki.WelcomeGuest"} = "TWikiDocumentation.WelcomeGuest";
	$moveTopicsHash{"TWiki.WhatIsWikiWiki"} = "TWikiDocumentation.WhatIsWikiWiki";
	$moveTopicsHash{"TWiki.WikiCulture"} = "TWikiDocumentation.WikiCulture";
	$moveTopicsHash{"TWiki.WikiName"} = "TWikiDocumentation.WikiName";
	$moveTopicsHash{"TWiki.WikiNotation"} = "TWikiDocumentation.WikiNotation";
	$moveTopicsHash{"TWiki.WikiReferences"} = "TWikiDocumentation.WikiReferences";
	$moveTopicsHash{"TWiki.WikiSyntax"} = "TWikiDocumentation.WikiSyntax";
	$moveTopicsHash{"TWiki.WikiSyntaxSummary"} = "TWikiDocumentation.WikiSyntaxSummary";
	$moveTopicsHash{"TWiki.WikiTopic"} = "TWikiDocumentation.WikiTopic";
	$moveTopicsHash{"TWiki.WikiWikiClones"} = "TWikiDocumentation.WikiWikiClones";
	$moveTopicsHash{"TWiki.WikiWord"} = "TWikiDocumentation.WikiWord";
	$moveTopicsHash{"TWiki.ClassMethod"} = "TWikiDocumentation.ClassMethod";
	$moveTopicsHash{"TWiki.LoginAndLogout"} = "TWikiDocumentation.LoginAndLogout";
	$moveTopicsHash{"TWiki.ObjectMethod"} = "TWikiDocumentation.ObjectMethod";
	$moveTopicsHash{"TWiki.StaticMethod"} = "TWikiDocumentation.StaticMethod";

#actual active topics
	$moveTopicsHash{"TWiki.AdminTools"} = "TWikiConfiguration.AdminTools";
	$moveTopicsHash{"TWiki.BulkRegistration"} = "TWikiConfiguration.BulkRegistration";
	$moveTopicsHash{"TWiki.BulkResetPassword"} = "TWikiConfiguration.BulkResetPassword";
	$moveTopicsHash{"TWiki.LoginName"} = "TWikiConfiguration.LoginName";
	$moveTopicsHash{"TWiki.RegistrationApprovals"} = "TWikiConfiguration.RegistrationApprovals";
	$moveTopicsHash{"TWiki.TestFixturePlugin"} = "TWikiConfiguration.TestFixturePlugin";
	$moveTopicsHash{"TWiki.UserForm"} = "TWikiConfiguration.UserForm";
	$moveTopicsHash{"TWiki.WebLeftBarWebsList"} = "TWikiConfiguration.WebLeftBarWebsList";

	$moveTopicsHash{"TWiki.ChangePassword"} = "TWikiConfiguration.ChangePassword";
	$moveTopicsHash{"TWiki.ClassicSkin"} = "TWikiConfiguration.ClassicSkin";
	$moveTopicsHash{"TWiki.CommentPlugin"} = "TWikiConfiguration.CommentPlugin";
	$moveTopicsHash{"TWiki.CommentsTmpl"} = "TWikiConfiguration.CommentsTmpl";
	$moveTopicsHash{"TWiki.DefaultPlugin"} = "TWikiConfiguration.DefaultPlugin";
	$moveTopicsHash{"TWiki.DragonSkin"} = "TWikiConfiguration.DragonSkin";
	$moveTopicsHash{"TWiki.DragonSkinCustomize"} = "TWikiConfiguration.DragonSkinCustomize";
	$moveTopicsHash{"TWiki.DragonSkinInstall"} = "TWikiConfiguration.DragonSkinInstall";
	$moveTopicsHash{"TWiki.EditTablePlugin"} = "TWikiConfiguration.EditTablePlugin";
	$moveTopicsHash{"TWiki.EmptyPlugin"} = "TWikiConfiguration.EmptyPlugin";
	$moveTopicsHash{"TWiki.InstallPassword"} = "TWikiConfiguration.InstallPassword";
	$moveTopicsHash{"TWiki.InstalledPlugins"} = "TWikiConfiguration.InstalledPlugins";
	$moveTopicsHash{"TWiki.InterWikis"} = "TWikiConfiguration.InterWikis";
	$moveTopicsHash{"TWiki.InterwikiPlugin"} = "TWikiConfiguration.InterwikiPlugin";
	$moveTopicsHash{"TWiki.NewUserTemplate"} = "TWikiConfiguration.NewUserTemplate";
	$moveTopicsHash{"TWiki.PatternSkin"} = "TWikiConfiguration.PatternSkin";
	$moveTopicsHash{"TWiki.PatternSkinCss"} = "TWikiConfiguration.PatternSkinCss";
	$moveTopicsHash{"TWiki.PatternSkinCustomization"} = "TWikiConfiguration.PatternSkinCustomization";
	$moveTopicsHash{"TWiki.PatternSkinPalette"} = "TWikiConfiguration.PatternSkinPalette";
	$moveTopicsHash{"TWiki.PlainSkin"} = "TWikiConfiguration.PlainSkin";
	$moveTopicsHash{"TWiki.PrintSkin"} = "TWikiConfiguration.PrintSkin";
	$moveTopicsHash{"TWiki.RenderListPlugin"} = "TWikiConfiguration.RenderListPlugin";
	$moveTopicsHash{"TWiki.ResetPassword"} = "TWikiConfiguration.ResetPassword";
	$moveTopicsHash{"TWiki.SiteMap"} = "TWikiConfiguration.SiteMap";
	$moveTopicsHash{"TWiki.SlideShowPlugin"} = "TWikiConfiguration.SlideShowPlugin";
	$moveTopicsHash{"TWiki.SmiliesPlugin"} = "TWikiConfiguration.SmiliesPlugin";
	$moveTopicsHash{"TWiki.SpreadSheetPlugin"} = "TWikiConfiguration.SpreadSheetPlugin";
	$moveTopicsHash{"TWiki.TWikiConfigs"} = "TWikiConfiguration.TWikiConfigs";
	$moveTopicsHash{"TWiki.TWikiFaqTemplate"} = "TWikiConfiguration.TWikiFaqTemplate";
	$moveTopicsHash{"TWiki.TWikiForms"} = "TWikiConfiguration.TWikiForms";
	$moveTopicsHash{"TWiki.TWikiLogos"} = "TWikiConfiguration.TWikiLogos";
	$moveTopicsHash{"TWiki.TWikiPreferences"} = "TWikiConfiguration.TWikiPreferences";
	$moveTopicsHash{"TWiki.TWikiRegistration"} = "TWikiConfiguration.TWikiRegistration";
	$moveTopicsHash{"TWiki.TWikiRegistrationIntranet"} = "TWikiConfiguration.TWikiRegistrationIntranet";
	$moveTopicsHash{"TWiki.TWikiRegistrationPub"} = "TWikiConfiguration.TWikiRegistrationPub";
	$moveTopicsHash{"TWiki.TWikiSkinBrowser"} = "TWikiConfiguration.TWikiSkinBrowser";
	$moveTopicsHash{"TWiki.TWikiVariables"} = "TWikiConfiguration.TWikiVariables";
	$moveTopicsHash{"TWiki.TWikiVariablesAtoM"} = "TWikiConfiguration.TWikiVariablesAtoM";
	$moveTopicsHash{"TWiki.TWikiVariablesNtoZ"} = "TWikiConfiguration.TWikiVariablesNtoZ";
	$moveTopicsHash{"TWiki.TWikiWebsTable"} = "TWikiConfiguration.TWikiWebsTable";
	$moveTopicsHash{"TWiki.TablePlugin"} = "TWikiConfiguration.TablePlugin";
	$moveTopicsHash{"TWiki.UserTemplates"} = "TWikiConfiguration.UserTemplates";
	$moveTopicsHash{"TWiki.WebBottomBar"} = "TWikiConfiguration.WebBottomBar";
	$moveTopicsHash{"TWiki.WebChanges"} = "TWikiConfiguration.WebChanges";
	$moveTopicsHash{"TWiki.WebHome"} = "TWikiConfiguration.WebHome";
	$moveTopicsHash{"TWiki.WebIndex"} = "TWikiConfiguration.WebIndex";
	$moveTopicsHash{"TWiki.WebLeftBar"} = "TWikiConfiguration.WebLeftBar";
	$moveTopicsHash{"TWiki.WebLeftBarPersonalTemplate"} = "TWikiConfiguration.WebLeftBarPersonalTemplate";
	$moveTopicsHash{"TWiki.WebNotify"} = "TWikiConfiguration.WebNotify";
	$moveTopicsHash{"TWiki.WebPreferences"} = "TWikiConfiguration.WebPreferences";
	$moveTopicsHash{"TWiki.WebRss"} = "TWikiConfiguration.WebRss";
	$moveTopicsHash{"TWiki.WebSearch"} = "TWikiConfiguration.WebSearch";
	$moveTopicsHash{"TWiki.WebSearchAdvanced"} = "TWikiConfiguration.WebSearchAdvanced";
	$moveTopicsHash{"TWiki.WebSiteTools"} = "TWikiConfiguration.WebSiteTools";
	$moveTopicsHash{"TWiki.WebStatistics"} = "TWikiConfiguration.WebStatistics";
	$moveTopicsHash{"TWiki.WebTopBar"} = "TWikiConfiguration.WebTopBar";
	$moveTopicsHash{"TWiki.WebTopicEditTemplate"} = "TWikiConfiguration.WebTopicEditTemplate";
	$moveTopicsHash{"TWiki.WebTopicList"} = "TWikiConfiguration.WebTopicList";
	$moveTopicsHash{"TWiki.WebTopicNonWikiTemplate"} = "TWikiConfiguration.WebTopicNonWikiTemplate";
	$moveTopicsHash{"TWiki.WebTopicViewTemplate"} = "TWikiConfiguration.WebTopicViewTemplate";
	$moveTopicsHash{"TWiki.YouAreHere"} = "TWikiConfiguration.YouAreHere";

	$moveTopicsHash{"TWiki.AdminSkillsAssumptions"} = "TWikiConfiguration.AdminSkillsAssumptions";
	$moveTopicsHash{"TWiki.AppendixEncodeURLsWithUTF8"} = "TWikiConfiguration.AppendixEncodeURLsWithUTF";
	$moveTopicsHash{"TWiki.AppendixFileSystem"} = "TWikiConfiguration.AppendixFileSystem";
	$moveTopicsHash{"TWiki.ExampleTopicTemplate"} = "TWikiConfiguration.ExampleTopicTemplate";
	$moveTopicsHash{"TWiki.FormattedSearch"} = "TWikiConfiguration.FormattedSearch";
	$moveTopicsHash{"TWiki.GnuGeneralPublicLicense"} = "TWikiConfiguration.GnuGeneralPublicLicense";
	$moveTopicsHash{"TWiki.InstantEnhancements"} = "TWikiConfiguration.InstantEnhancements";
	$moveTopicsHash{"TWiki.ManagingUsers"} = "TWikiConfiguration.ManagingUsers";
	$moveTopicsHash{"TWiki.ManagingWebs"} = "TWikiConfiguration.ManagingWebs";
	$moveTopicsHash{"TWiki.MetaDataDefinition"} = "TWikiConfiguration.MetaDataDefinition";
	$moveTopicsHash{"TWiki.MetaDataRendering"} = "TWikiConfiguration.MetaDataRendering";
	$moveTopicsHash{"TWiki.PreviewBackground"} = "TWikiConfiguration.PreviewBackground";
	$moveTopicsHash{"TWiki.StandardColors"} = "TWikiConfiguration.StandardColors";
	$moveTopicsHash{"TWiki.TWikiAccessControl"} = "TWikiConfiguration.TWikiAccessControl";
	$moveTopicsHash{"TWiki.TWikiAdminCookBook"} = "TWikiConfiguration.TWikiAdminCookBook";
	$moveTopicsHash{"TWiki.TWikiCategoryTable"} = "TWikiConfiguration.TWikiCategoryTable";
	$moveTopicsHash{"TWiki.TWikiContributor"} = "TWikiConfiguration.TWikiContributor";
	$moveTopicsHash{"TWiki.TWikiCss"} = "TWikiConfiguration.TWikiCss";
	$moveTopicsHash{"TWiki.TWikiDocGraphics"} = "TWikiConfiguration.TWikiDocGraphics";
	$moveTopicsHash{"TWiki.TWikiDocumentation"} = "TWikiConfiguration.TWikiDocumentation";
	$moveTopicsHash{"TWiki.TWikiEnhancementRequests"} = "TWikiConfiguration.TWikiEnhancementRequests";
	$moveTopicsHash{"TWiki.TWikiFuncModule"} = "TWikiConfiguration.TWikiFuncModule";
	$moveTopicsHash{"TWiki.TWikiHistory"} = "TWikiConfiguration.TWikiHistory";
	$moveTopicsHash{"TWiki.TWikiInstallationGuide"} = "TWikiConfiguration.TWikiInstallationGuide";
	$moveTopicsHash{"TWiki.TWikiMetaData"} = "TWikiConfiguration.TWikiMetaData";
	$moveTopicsHash{"TWiki.TWikiPlannedFeatures"} = "TWikiConfiguration.TWikiPlannedFeatures";
	$moveTopicsHash{"TWiki.TWikiPlugins"} = "TWikiConfiguration.TWikiPlugins";
	$moveTopicsHash{"TWiki.TWikiSiteTools"} = "TWikiConfiguration.TWikiSiteTools";
	$moveTopicsHash{"TWiki.TWikiSkins"} = "TWikiConfiguration.TWikiSkins";
	$moveTopicsHash{"TWiki.TWikiSystemRequirements"} = "TWikiConfiguration.TWikiSystemRequirements";
	$moveTopicsHash{"TWiki.TWikiTemplates"} = "TWikiConfiguration.TWikiTemplates";
	$moveTopicsHash{"TWiki.TWikiUpgradeGuide"} = "TWikiConfiguration.TWikiUpgradeGuide";
	$moveTopicsHash{"TWiki.TWikiUpgradeTo01Dec2000"} = "TWikiConfiguration.TWikiUpgradeTo01Dec2000";
	$moveTopicsHash{"TWiki.TWikiUpgradeTo01Dec2001"} = "TWikiConfiguration.TWikiUpgradeTo01Dec2001";
	$moveTopicsHash{"TWiki.TWikiUpgradeTo01Feb2003"} = "TWikiConfiguration.TWikiUpgradeTo01Feb2003";
	$moveTopicsHash{"TWiki.TWikiUpgradeTo01May2000"} = "TWikiConfiguration.TWikiUpgradeTo01May2000";
	$moveTopicsHash{"TWiki.TWikiUserAuthentication"} = "TWikiConfiguration.TWikiUserAuthentication";
	$moveTopicsHash{"TWiki.TWikiUsernameVsLoginUsername"} = "TWikiConfiguration.TWikiUsernameVsLoginUsername";
	$moveTopicsHash{"TWiki.TemplateWeb"} = "TWikiConfiguration.TemplateWeb";
	$moveTopicsHash{"TWiki.WebLeftBarCookbook"} = "TWikiConfiguration.WebLeftBarCookbook";
	$moveTopicsHash{"TWiki.WebLeftBarExample"} = "TWikiConfiguration.WebLeftBarExample";
	$moveTopicsHash{"TWiki.WebRssBase"} = "TWikiConfiguration.WebRssBase";
	$moveTopicsHash{"TWiki.WindowsInstallCookbook"} = "TWikiConfiguration.WindowsInstallCookbook";
	$moveTopicsHash{"TWiki.WindowsInstallSummary"} = "TWikiConfiguration.WindowsInstallSummary";

	$moveTopicsHash{"Main.FileAttachment"} = "Trash.FileAttachment";
	$moveTopicsHash{"Main.FirstName"} = "Users.FirstName";
	$moveTopicsHash{"Main.LastName"} = "Users.LastName";
	$moveTopicsHash{"Main.LondonOffice"} = "Users.LondonOffice";
	$moveTopicsHash{"Main.NobodyGroup"} = "Users.NobodyGroup";
	$moveTopicsHash{"Main.OfficeLocations"} = "Users.OfficeLocations";
	$moveTopicsHash{"Main.PeterThoeny"} = "Users.PeterThoeny";
	$moveTopicsHash{"Main.SanJoseOffice"} = "Users.SanJoseOffice";
	$moveTopicsHash{"Main.TWikiAdminGroup"} = "Users.TWikiAdminGroup";
	$moveTopicsHash{"Main.TWikiGroupTemplate"} = "Users.TWikiGroupTemplate";
	$moveTopicsHash{"Main.TWikiGroups"} = "Users.TWikiGroups";
	$moveTopicsHash{"Main.TWikiGuest"} = "Users.TWikiGuest";
	$moveTopicsHash{"Main.TWikiPreferences"} = "Trash.TWikiPreferences";
	$moveTopicsHash{"Main.TWikiUsers"} = "Users.TWikiUsers";
	$moveTopicsHash{"Main.TWikiVariables"} = "Trash.TWikiVariables";
	$moveTopicsHash{"Main.TokyoOffice"} = "Users.TokyoOffice";
	$moveTopicsHash{"Main.UserForm"} = "Users.UserForm";
	$moveTopicsHash{"Main.UserList"} = "Users.UserList";
	$moveTopicsHash{"Main.UserListByDateJoined"} = "Users.UserListByDateJoined";
	$moveTopicsHash{"Main.UserListByLocation"} = "Users.UserListByLocation";
	$moveTopicsHash{"Main.UserListByOrganization"} = "Users.UserListByOrganization";
	$moveTopicsHash{"Main.UserListHeader"} = "Users.UserListHeader";

	my $key;
	foreach $key (keys %moveTopicsHash) {
		moveTopic( $session , $key, $moveTopicsHash{$key});
	}

}

sub moveTopic {
	my ( $session, $from, $to) = @_;

	my ($oldWeb, $oldTopic) = $session->normalizeWebTopicName("", $from);
	my ($newWeb, $newTopic) = $session->normalizeWebTopicName("", $to);

    my $renameError =
	 $session->{store}->renameTopic( $oldWeb, $oldTopic, $newWeb,
					$newTopic, 1, $session->{user} );
	my $refs = $session->{store}->getReferingTopics($oldWeb, $oldTopic, $newWeb);
    my $problems =
	  $session->{store}->updateReferringPages( $oldWeb, $oldTopic,
						   $session->{user},
						   $newWeb, $newTopic, @{$refs} );

}


1;
