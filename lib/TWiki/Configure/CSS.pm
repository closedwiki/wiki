use strict;

package TWiki::Configure::CSS;

use vars qw( $css );

sub css {
    local $/ = undef;
    return <DATA>;
}

1;
__DATA__
/* 
Basic layout derived from http://www.positioniseverything.net/articles/pie-maker/pagemaker_form.php.
I've changed many so things that I won't put a full copyright notice. However all hacks (and comments!) are far beyond my knowledge and this deserves full credits:

Original copyright notice:
Parts of these notes are
(c) Big John @ www.positioniseverything.net and (c) Paul O'Brien @ www.pmob.co.uk, all of whom contributed significantly to the design of
the css and html code.

Reworked for TWiki: (c) Arthur Clemens @ visiblearea.com
*/

html, body {
	margin:0; /*** Do NOT set anything other than a left margin for the page
as this will break the design ***/
	padding:0;
	border:0;
/* \*/
	height:100%;
/* Last height declaration hidden from Mac IE 5.x */
}
body {
	background:#fff;
	min-width:100%; /*** This is needed for moz. Otherwise, the header and patternBottomBar will
slide off the left side of the page if the screen width is narrower than the design.
Not seen by IE. Left Col + Right Col + Center Col + Both Inner Borders + Both Outer Borders ***/
	text-align:center; /*** IE/Win (not IE/MAC) alignment of page ***/
}
.clear {
	clear:both;
	/*** these next attributes are designed to keep the div
	height to 0 pixels high, critical for Safari and Netscape 7 ***/
	height:0px;
	overflow:hidden;
	line-height:1%;
	font-size:0px;
}

#patternWrapper {
	height:100%; /*** moz uses this to make full height design. As this #patternWrapper is inside the #patternPage which is 100% height, moz will not inherit heights further into the design inside this container, which you should be able to do with use of the min-height style. Instead, Mozilla ignores the height:100% or min-height:100% from this point inwards to the center of the design - a nasty bug.
If you change this to height:100% moz won't expand the design if content grows.
Aaaghhh. I pulled my hair out over this for days. ***/
/* \*/
	height:100%;
/* Last height declaration hidden from Mac IE 5.x */
/*** Fixes height for non moz browsers, to full height ***/
}
#patternWrapp\65	r{ /*** for Opera and Moz (and some others will see it, but NOT Safari) ***/
	height:auto; /*** For moz to stop it fixing height to 100% ***/
}
/* \*/
* html #patternWrapper{
	height:100%;
}

#patternPage {
	margin-left:auto; /*** Mozilla/Opera/Mac IE 5.x alignment of page ***/
	margin-right:auto; /*** Mozilla/Opera/Mac IE 5.x alignment of page ***/
	text-align:left; /*** IE Win re-alignment of page if page is centered ***/
	position:relative;
	width:100%; /*** Needed for Moz/Opera to keep page from sliding to left side of
page when it calculates auto margins above. Can't use min-width. Note that putting
width in #patternPage shows it to IE and causes problems, so IE needs a hack
to remove this width. Left Col + Right Col + Center Col + Both Inner Border + Both Outer Borders ***/
/* \*/
	height:100%;
/* Last height declaration hidden from Mac IE 5.x */
/*** Needed for Moz to give full height design if page content is
too small to fill the page ***/
}
/* Last style with height declaration hidden from Mac IE 5.x */
/*** Fixes height for IE, back to full height,
from esc tab hack moz min-height solution ***/
#patternOuter {
	z-index:1; /*** Critical value for Moz/Opera Background Column colors fudge to work ***/
	position:relative; /*** IE needs this or the contents won't show outside the parent container. ***/

	height:100%;
/* Last height declaration hidden from Mac IE 5.x */
/*** Needed for full height inner borders in Win IE ***/
}

#patternFloatWrap {
	width:100%;
	float:left;
	display:inline;
}

#patternLeftBar {
	/* Left bar width is defined in viewleftbar.pattern.tmpl */
	float:left;
	display:inline;
	position:relative; /* IE needs this or the contents won't show
outside the parent container. */
	overflow:hidden;
}
#patternLeftBarContents {
	left:-1px;
	position:relative;
	/* for margins and paddings use style.css */
}
#patternMain {
	width:100%;
	float:right;
	display:inline;
}
#patternTopBar {
	/* Top bar height is defined in viewtopbar.pattern.tmpl */
	z-index:1; /*** Critical value for Moz/Opera Background Column colors fudge to work ***/
	position:absolute;
	top:0px;
	width:100%;
}
#patternTopBarContents {
	height:1%; /* or Win IE won't display a background */
	/* for margins/paddings use style.css */
}
#patternBottomBar {
	z-index:1; /* Critical value for Moz/Opera Background Column colors fudge to work */
	clear:both;
	width:100%;
}

/* Pages that are not view */

.patternNoViewPage #patternOuter {
	/* no left bar, margin at both sides */
	margin-left:4%;
	margin-right:4%;
}

/* edit.pattern.tmpl */

.patternEditPage #patternOuter,
.patternPreviewPage #patternOuter {
	margin-left:0;
	margin-right:0;
}

.twikiLeft {
	float:left;
	position:relative;
}
.twikiRight {
	position:relative;
	float:right;
	display:inline;
	margin:0;
}
.twikiClear {
	/* to clean up floats */
	margin:0;
	padding:0;
	height:0;
	line-height:0px;
	clear:both;
	display:block;
}
.twikiHidden {
	display:none;
}
.twikiLast,
.patternTopic .twikiLast {
	border-bottom:0px;
}

/*	-----------------------------------------------------------
	STYLE
	Appearance: margins, padding, fonts, borders
	-----------------------------------------------------------	*/
	

/*	---------------------------------------------------------------------------------------
	CONSTANTS
	
	Sizes
	----------------------------------------
	S1 line-height																	1.4em
	S2 somewhat smaller font size													94%
	S3 small font size, twikiSmall													font-size:86%; line-height:110%;
	S4 horizontal bar padding (h2, patternTop)										5px
	S5 form and attachment padding													20px
	S6 left margin left bar															1em

	---------------------------------------------------------------------------------------	*/

/* GENERAL HTML ELEMENTS */

html body {
	font-size:104%; /* to change the site's font size, change #patternPage below */
	voice-family:"\"}\""; 
	voice-family:inherit;
	font-size:small;
}
html>body { /* Mozilla */
	font-size:small;	
}
p {
	margin:1em 0 0 0;
}
table {
	border-collapse:separate;
}
th {
	line-height:1.15em;
}
strong, b {
	font-weight:bold;
}
hr {
	height:1px;
	border:none;
}

/* put overflow pre in a scroll area */
pre {
    width:100%;
    margin:1em 0; /* Win IE tries to make this bigger otherwise */
}
html>body pre { /* hide from IE */
	/*\*/ overflow:auto !important; /* */ overflow:scroll; width:auto; /* for Mac Safari */
}
/* IE behavior for pre is defined in twiki.pattern.tmpl in conditional comment */
ol li, ul li {
	line-height:1.4em; /*S1*/
}
	
/* Text */
h1, h2, h3, h4, h5, h6 {
	line-height:104%;
	padding:0em;
	margin:1em 0 .1em 0;
	font-weight:normal;
}
h1 {
	margin:0 0 .5em 0;
}
h1 { font-size:210%; }
h2 { font-size:160%; }
h3 { font-size:135%; }
h4 { font-size:122%; }
h5 { font-size:110%; }
h6 { font-size:95%; }
h2, h3, h4, h5, h6 {
	display:block;
	/* give header a background color for easy scanning:*/
	padding:.1em 5px;
	margin:1em -5px .35em -5px;
	border-width:0 0 1px 0;
	border-style:solid;
	height:auto;	
}
h1.patternTemplateTitle {
	font-size:175%;
	text-align:center;
}
h2.patternTemplateTitle {
	text-align:center;
}
/* Links */
/* somehow the twikiNewLink style have to be before the general link styles */
.twikiNewLink {
	border-width:0 0 1px 0;
	border-style:solid;
}
.twikiNewLink a {
	text-decoration:none;
	margin-left:1px;
}
.twikiNewLink a sup {
	text-align:center;
	padding:0 2px;
	vertical-align:baseline;
	font-size:100%;
	text-decoration:none;
}
.twikiNewLink a:link sup,
.twikiNewLink a:visited sup {
	border-width:1px;
	border-style:solid;
	text-decoration:none;
}
.twikiNewLink a:hover sup {
	text-decoration:none;
}

:link:focus,
:visited:focus,
:link,
:visited,
:link:active,
:visited:active {
	text-decoration:underline;
}
:link:hover,
:visited:hover {
	text-decoration:none;
}
img {
	vertical-align:text-bottom;
	border:0;
}

/* Form elements */
form { 
	display:inline;
	margin:0em;
	padding:0em;
}
textarea,
input,
select {
	vertical-align:middle;
	border-width:1px;
	border-style:solid;
}
textarea {
	padding:1px;
}
input,
select option {
	padding:1px;
}
.twikiSubmit,
.twikiButton,
.twikiCheckbox {
	border-width:1px;
	border-style:solid;
	padding:.15em .25em;
	font-size:94%;
	font-weight:bold;
	vertical-align:middle;
}
.twikiCheckbox,
.twikiRadioButton {
	margin:0 .3em 0 0;
	border:0;
}
.twikiInputField {
	border-width:1px;
	border-style:solid;
	padding:.15em .25em;
	font-size:94%; /*S2*/
}
.patternFormButton {
	border:0;
	margin:0 0 0 2px;
}
textarea {
	font-size:100%;
}

/* LAYOUT ELEMENTS */
/* for specific layout sub-elements see further down */

#patternPage {
	font-family:arial, "Lucida Grande", verdana, sans-serif;
	line-height:1.4em; /*S1*/
	/* change font size here */
	font-size:105%;
}
#patternTopBar {
	border-width:0 0 1px 0;
	border-style:solid;
	overflow:hidden;
}
#patternTopBarContents {
	padding:0 1.5em 0 1em;
}
#patternBottomBar {
	border-width:1px 0 0 0;
	border-style:solid;
}
#patternBottomBarContents {
	padding:1em;
	font-size:86%; line-height:110%; /*S3*/
	text-align:center;
}
#patternMainContents {
	padding:0 1.5em 3em 3em;
}
#patternLeftBarContents {
	margin:0 1em 1em 1em;
}

/*	-----------------------------------------------------------
	Plugin elements
	-----------------------------------------------------------	*/

/* EditTablePlugin */
.editTable .twikiTable {
	margin:0 0 2px 0;
}
.editTableInput,
.editTableTextarea {
	font-family:monospace;
}
.editTableEditImageButton {
	border:none;
}

/* TablePlugin */
.twikiTable {
}
.twikiTable td,
.twikiTable th {
}
.twikiTable th {
    padding:4px;
}
.twikiTable td {
    padding:2px 4px;
}
.twikiTable th a:link,
.twikiTable th a:visited,
.twikiTable th a font {
	text-decoration:none;
}
.twikiTable th a:hover,
.twikiTable th a:hover font {
	text-decoration:none;
	border-width:0 0 1px 0;
	border-style:solid;
}

/* TablePlugin - sorting of table columns */
th.twikiSortedAscendingCol a:link,
th.twikiSortedAscendingCol a:link font,
th.twikiSortedAscendingCol a:visited,
th.twikiSortedAscendingCol a:visited font {
	border-width:1px 0 0 0;
	border-style:solid;	
}
th.twikiSortedDescendingCol a:link,
th.twikiSortedDescendingCol a:link font,
th.twikiSortedDescendingCol a:visited,
th.twikiSortedDescendingCol a:visited font {
	border-width:0 0 1px 0;
	border-style:solid;
}
th.twikiSortedAscendingCol a:hover,
th.twikiSortedAscendingCol a:hover font {
	border-width:0 0 1px 0;
	border-style:solid;
	text-decoration:none;
}
th.twikiSortedDescendingCol a:hover,
th.twikiSortedDescendingCol a:hover font {
	border-width:1px 0 0 0;
	border-style:solid;
	text-decoration:none;
}

.twikiEditForm {
	margin:0 0 .5em 0;
}
.twikiEditForm .twikiFormTable {
	text-align:center;
}

/* TipsContrib */
.tipsOfTheDayContents .tipsOfTheDayTitle {
	font-weight:bold;
}
.patternTopic .tipsOfTheDayHeader {
	display:block;
	padding:3px 5px;
}
.patternTopic .tipsOfTheDayText {
	padding:0 5px 5px 5px;
}
.patternTopic .tipsOfTheDayText a:link,
.patternTopic .tipsOfTheDayText a:visited {
	text-decoration:none;
}
/* TipsContrib - in left bar */
#patternLeftBar .tipsOfTheDayHeader img {
	/* hide lamp icon */
	display:none;
}
#patternLeftBar .tipsOfTheDayContents {
	padding:.25em .25em .5em .25em;
	height:1%; /* or Win IE won't display a background */
	overflow:hidden;
}
#patternLeftBar .tipsOfTheDayHeader {
	display:block;
	font-weight:normal;
}

/* TwistyContrib */
a:link.twistyTrigger,
a:visited.twistyTrigger {
	text-decoration:none;
}
a:link .twistyLinkLabel,
a:visited .twistyLinkLabel {
	text-decoration:underline;
}

/*	-----------------------------------------------------------
	TWiki styles
	-----------------------------------------------------------	*/

#twikiLogin {
	width:40em;
	margin:0 auto;
	text-align:center;
}
#twikiLogin .twikiFormSteps {
	border-width:5px;
}
.twikiAttachments,
.twikiForm {
	margin:1em 0;
	padding:1px; /* fixes disappearing borders because of overflow:auto; in twikiForm */
}
.twikiForm h1,
.twikiForm h2,
.twikiForm h3,
.twikiForm h4,
.twikiForm h5,
.twikiForm h6 {
	margin-top:0;
}
.patternContent .twikiAttachments,
.patternContent .twikiForm {
	/* form or attachment table inside topic area */
	font-size:94%; /*S2*/
	padding:.5em 20px; /*S5*/ /* top:use less padding for the toggle link; bottom:use less space in case the table is folded in  */
	border-width:1px 0 0 0;
	border-style:solid;
	margin:0;
}
.twikiAttachments table,
table.twikiFormTable {
	margin:5px 0 10px 0; /* bottom:create extra space in case the table is folded out */
	border-collapse:collapse;
	padding:0px;
	border-spacing:0px;
	empty-cells:show;
	border-style:solid;
	border-width:1px;
}
.twikiAttachments table {
	line-height:1.4em; /*S1*/
	width:auto;
	voice-family:"\"}\""; /* hide the following for Explorer 5.x */
	voice-family:inherit;
	width:100%;
}
.twikiAttachments td, 
.twikiAttachments th {
	border-style:solid;
	border-width:1px;
}
.twikiAttachments th,
table.twikiFormTable th.twikiFormTableHRow {
	padding:3px 6px;
	height:2.5em;
	vertical-align:middle;
}
table.twikiFormTable th.twikiFormTableHRow {
	text-align:center;
}
.twikiEditForm .twikiFormTable th,
.twikiEditForm .twikiFormTable td {
	padding:.25em .5em;
	vertical-align:middle;
	border-width:0 0 1px 0;
	border-style:solid;
}
.twikiAttachments th a:link,
.twikiAttachments th a:visited {
	text-decoration:none;
}
/* don't show any of those ugly sort icons */
.twikiAttachments th img,
.twikiAttachments th a:link img,
.twikiAttachments th a:visited img {
	display:none;
}
.twikiAttachments td,
table.twikiFormTable td {
	padding:3px 6px;
	height:1.4em; /*S1*/
	text-align:left;
	vertical-align:top;
}
.twikiAttachments td {
	/* don't show column lines in attachment listing */
	border-width:0 0 1px 0;
}
.twikiAttachments th.twikiFirstCol,
.twikiAttachments td.twikiFirstCol {
	/* make more width for the icon column */
	width:26px;
	text-align:center;
}
.twikiAttachments caption {
	display:none;
}
table.twikiFormTable th.twikiFormTableHRow a:link,
table.twikiFormTable th.twikiFormTableHRow a:visited {
	text-decoration:none;
}

.twikiFormSteps {
	text-align:left;
	padding:.25em 0 0 0;
	border-width:1px 0;
	border-style:solid;
}
.twikiFormStep {
	line-height:140%;
	padding:1em 20px; /*S5*/
	border-width:0 0 1px 0;
	border-style:solid;
}
.twikiFormStep h3,
.twikiFormStep h4 {
	font-size:115%;
	border:none;
	margin:0;
	padding:0;
}
.twikiFormStep h3 {
	font-weight:bold;
}
.twikiFormStep h4 {
	font-weight:normal;
}
.twikiFormStep p {
	margin:.3em 0;
}

.twikiToc {
	margin:1em 0;
	padding:.3em 0 .6em 0;
}
.twikiToc ul {
	list-style:none;
	padding:0 0 0 .5em;
	margin:0em;
}
.twikiToc li {
	margin-left:1em;
	padding-left:1em;
	background-repeat:no-repeat;
	background-position:0 .5em;
}
.twikiToc .twikiTocTitle {
	margin:0em;
	padding:0em;
	font-weight:bold;
}

.twikiSmall {
	font-size:86%; line-height:110%; /*S3*/
}
.twikiSmallish {
	font-size:94%; /*S2*/
}
.twikiNew { }
.twikiSummary {
	font-size:86%; line-height:110%; /*S3*/
}
.twikiEmulatedLink {
	text-decoration:underline;
}
.twikiPageForm table {
	border-width:1px;
	border-style:solid;
}
.twikiPageForm table {
	width:100%;
	margin:0 0 2em 0;
}
.twikiPageForm th,
.twikiPageForm td {
	border:0;
	padding:.15em 1em;
}
.twikiPageForm td {}
.twikiPageForm td.first {
	padding-top:1em;
}
.twikiBroadcastMessage {
	padding:.25em .5em;
	margin:0 0 1em 0;
}
.twikiHelp {
	padding:1em;
	margin:0 0 1em 0;
	border-width:1px 0;
	border-style:solid;
}
.twikiHelp ul,
.twikiHelp li {
	margin:0;
}
.twikiHelp ul {
	padding-left:2em;
}
.twikiAccessKey {
	text-decoration:none;
	border-width:0 0 1px 0;
	border-style:solid;
}
a:hover .twikiAccessKey {
	text-decoration:none;
	border:none;
}
.twikiWebIndent {
	margin:0 0 0 1em;
}

a.twikiLinkInHeaderRight {
	float:right;
	display:block;
	margin:0 0 0 5px;
}

/*	-----------------------------------------------------------
	Pattern skin specific elements
	-----------------------------------------------------------	*/

.patternTopic {
	margin:1em 0 2em 0;
}
#patternLeftBarContents {
	font-size:94%; /*S2*/
	padding:0 0 .5em 0;
}
#patternLeftBarContents a img {
	margin:1px 0 0 0;
}
#patternLeftBarContents a:link,
#patternLeftBarContents a:visited {
	text-decoration:none;
}
#patternLeftBarContents ul {
	padding:0;
	margin:.5em 0 1em 0;
	list-style:none;
}
#patternLeftBarContents li {
	width:100%;
	margin:0 1.1em 0 0;
	overflow:hidden;
}
#patternLeftBarContents .patternWebIndicator {
	margin:0 -1em; /*S6*/
	padding:.55em 1em; /*S6*/
	line-height:1.4em;
	text-align:center;
}
#patternLeftBarContents .patternWebIndicator a:link,
#patternLeftBarContents .patternWebIndicator a:visited {
	text-decoration:none;
}
#patternLeftBarContents .patternLeftBarPersonal {
	margin:0 -1em; /*S6*/
	padding:.55em 1em; /*S6*/
	width:100%;
	border-width:0 0 1px 0;
	border-style:solid;
}
#patternLeftBarContents .patternLeftBarPersonal ul {
	margin:0;
	padding:0;
}
#patternLeftBarContents .patternLeftBarPersonal li {
	padding-left:1em;
	background-repeat:no-repeat;
}
#patternLeftBarContents .patternLeftBarPersonal a:hover {
	text-decoration:none;
}


.patternTop {
	font-size:94%; /*S2*/
}
/* Button tool bar */
.patternToolBar {
	margin:.4em 0 0 0;
	padding:0 .5em 0 0;
	height:1%; /* for Win IE */
}
.patternToolBarButtons {
	float:right;
}
.patternToolBarButtons .twikiSeparator {
	display:none;
}
.patternToolBar .patternButton {
	float:left;
}
.patternToolBar .patternButton s,
.patternToolBar .patternButton strike,
.patternToolBar .patternButton a:link,
.patternToolBar .patternButton a:visited {
	display:block;
	margin:0 0 -1px 4px;
	border-width:1px;
	border-style:solid;
	/* relative + z-index removed due to buggy Win/IE redrawing problems */
	/*
	position:relative;
	z-index:0;
	*/
	padding:.15em .45em;
}
.patternToolBar .patternButton a:link,
.patternToolBar .patternButton a:visited {
	text-decoration:none;
}
.patternToolBar .patternButton s,
.patternToolBar .patternButton strike {
	text-decoration:none;
}
.patternToolBar .patternButton a:hover {
	text-decoration:none;
	/*z-index:3;*/
}
.patternToolBarBottom {
	position:relative;
	border-width:1px 0 0 0;
	border-style:solid;
	z-index:2;
	clear:both;
}
.patternMetaMenu input,
.patternMetaMenu select,
.patternMetaMenu select option {
	font-size:.86em; /* use em instead of % for consistent size */
	margin:0;
	width:8em;
}
.patternMetaMenu select option {
	padding:1px 0 0 0;
}
.patternMetaMenu ul {
    padding:0;
    margin:0;
   	list-style:none;
}
.patternMetaMenu ul li {
    padding:0 .1em 0 .1em;
	display:inline;
}

/* breadcrumb */
.patternHomePath {
	font-size:94%; /*S2*/
	margin:.3em 0;
}
.patternHomePath a:link,
.patternHomePath a:visited {
	text-decoration:none;
}
.patternRevInfo {
	margin:0 0 0 .15em;
	font-size:94%;
}

.patternTopicAction {
	line-height:1.5em;
	padding:.4em 20px; /*S5*/
	border-width:1px 0;
	border-style:solid;
}
.patternViewPage .patternTopicAction {
	font-size:94%; /*S2*/
}
.patternActionButtons a:link,
.patternActionButtons a:visited {
	padding:1px 1px 2px 1px;
}
.patternTopicAction .patternActionButtons a:link,
.patternTopicAction .patternActionButtons a:visited {
	text-decoration:none;
}
.patternTopicAction .patternSaveOptions {
	margin-bottom:.5em;
}
.patternTopicAction .patternSaveOptions .patternSaveOptionsContents {
	padding:.2em 0;
}
.patternMoved {
	font-size:94%; /*S2*/
	margin:1em 0;
}
.patternMoved i,
.patternMoved em {
	font-style:normal;
}

/* WebSearch, WebSearchAdvanced */
table#twikiSearchTable {
	background:none;
	border-bottom:0;
} 
table#twikiSearchTable th,
table#twikiSearchTable td {
	padding:.5em;
	border-width:0 0 1px 0;
	border-style:solid;
} 
table#twikiSearchTable th {
	width:20%;
	text-align:right;
}
table#twikiSearchTable td {
	width:80%;
}
table#twikiSearchTable td.first {
	padding:1em;
}

/*	-----------------------------------------------------------
	Search results
	styles and overridden styles used in search.pattern.tmpl
	-----------------------------------------------------------	*/

.patternSearchResults {
	/* no longer used in search.pattern.tmpl, but remains in rename templates */
	margin:0 0 1em 0;
}
.patternSearchResults blockquote {
	margin:1em 0 1em 5em;
}
h3.patternSearchResultsHeader,
h4.patternSearchResultsHeader {
	display:block;
	border-width:0 0 1px 0;
	border-style:solid;
	height:1%; /* or WIN/IE wont draw the backgound */
	font-weight:bold;
}
.patternSearchResults h3 {
	font-size:115%; /* same as twikiFormStep */
	margin:0;
	padding:.5em 20px;
	font-weight:bold;
}
h4.patternSearchResultsHeader {
	font-size:100%;
	padding-top:.3em;
	padding-bottom:.3em;
	font-weight:normal;
}
.patternSearchResult .twikiTopRow {
	padding-top:.2em;
}
.patternSearchResult .twikiBottomRow {
	padding-bottom:.25em;
	border-width:0 0 1px 0;
	border-style:solid;
}
.patternSearchResult .twikiAlert {
	font-weight:bold;
}
.patternSearchResult .twikiSummary .twikiAlert {
	font-weight:normal;
}
.patternSearchResult .twikiNew {
	border-width:1px;
	border-style:solid;
	font-size:85%; /*S3*/
	padding:0 1px;
	font-weight:bold;
}
.patternSearchResults .twikiHelp {
	display:block;
	width:auto;
	padding:.1em 5px;
	margin:1em -5px .35em -5px;
}
.patternSearchResult .twikiSRAuthor {
	width:15%;
	text-align:left;
}
.patternSearchResult .twikiSRRev {
	width:30%;
	text-align:left;
}
.patternSearchResultCount {
	margin:1em 0 3em 0;
}
.patternSearched {
}

/* Search results in book view format */

.patternBookView {
	border-width:0 0 2px 2px;
	border-style:solid;
	/* border color in cssdynamic.pattern.tmpl */
	margin:.5em 0 1.5em -5px;
	padding:0 0 0 5px;
}
.patternBookView .twikiTopRow {
	padding:.25em 5px .15em 5px; /*S4*/
	margin:1em -5px .15em -5px; /*S4*/
}
.patternBookView .twikiBottomRow {
	font-size:100%;
	padding:1em 0 1em 0;
	width:auto;
	border:none;
}

/* pages that are not view */

.patternNoViewPage #patternMainContents {
	padding-top:1.5em;
}


/* oopsmore.pattern.tmpl */

table.patternDiffOptions {
	margin:.5em 0;
	border:none;
}
table.patternDiffOptions td {
	border:none;
	text-align:center;
}
table.patternDiffOptions img {
	padding:0 10px;
	border-width:1px;
	border-style:solid;
}

/* edit.pattern.tmpl */

.patternEditPage .twikiForm h1,
.patternEditPage .twikiForm h2,
.patternEditPage .twikiForm h3 {
	/* same as twikiFormStep */
	font-size:120%;
	font-weight:bold;
}	
.twikiEditboxStyleMono {
	font-family:"Courier New", courier, monaco, monospace;
}
.twikiEditboxStyleProportional {
	font-family:"Lucida Grande", verdana, arial, sans-serif;
}
.twikiChangeFormButtonHolder {
	margin:.5em 0;
	float:right;
}
.twikiChangeFormButton .twikiButton,
.twikiChangeFormButtonHolder .twikiButton {
	padding:0em;
	margin:0em;
	border:none;
	text-decoration:underline;
	font-weight:normal;
}
.patternFormHolder { /* constrains the textarea */
	width:100%;
}
.patternSigLine {
	margin:.25em 0 .5em 0;
	padding:0 .5em 0 0;
}
.patternAccessKeyInfo {
	margin:1em 0 .5em 0;
	padding:.25em .5em;
	border-width:1px 0;
	border-style:solid;
}
.patternAccessKeyInfo a:link,
.patternAccessKeyInfo a:visited {
	text-decoration:underline;
}
.patternAccessKeyInfo a:hover {
	text-decoration:none;
}


/* preview.pattern.tmpl */

.patternPreviewArea {
	border-width:1px;
	border-style:solid;
	margin:0em -.5em 2em -.5em;
	padding:.5em;
}

/* attach.pattern.tmpl */

.patternAttachPage .twikiAttachments table {
	width:auto;
}
.patternAttachPage .patternTopicAction {
	margin-top:-1px;
}
.patternAttachPage .twikiAttachments {
	margin-top:0;
}
.patternAttachForm {
	margin:0 0 3.5em 0;
}
.patternMoveAttachment {
	margin:.5em 0 0 0;
	text-align:right;
}

/* rdiff.pattern.tmpl */

.patternDiff {
	/* same as patternBookView */
	border-width:0 0 2px 2px;
	border-style:solid;
	margin:.5em 0 1.5em -5px;
	padding:0 0 0 5px;
}
.patternDiffPage .patternRevInfo ul {
	padding:0;
	margin:2em 0 0 0;
	list-style:none;
}
.patternDiffPage .twikiDiffTable {
	margin:2em 0;
}
.patternDiffPage .twikiDiffTable th,
.patternDiffPage .twikiDiffTable td {
	padding:.2em;
}
tr.twikiDiffDebug td {
	border-width:1px;
	border-style:solid;
}
.patternDiffPage td.twikiDiffDebugLeft {
	border-bottom:none;
}
.twikiDiffLineNumberHeader {
	padding:.3em 0;
}

/*	-----------------------------------------------------------
	COLOR
	Appearance: text colors, background colors, border colors
	-----------------------------------------------------------	*/
	
/*	---------------------------------------------------------------------------------------
	CONSTANTS
	
	Text colors
	----------------------------------------
	T1 text color																	#000
	T2 link color																	#06c
	T3 link hover text color														#FBF7E8
	T4 link action button color (red) (same as BG2)									#D6000F
	T5 header color																	#a00
	T6 code text, left bar text														#7A4707
	T7 muted (dark gray) text														#666
	T8 grayed out text																#8E9195
	T9 alert 																		#f00
	T10 green 'new'																	#049804
	T11 dark gray																	#333
	
	Background colors
	----------------------------------------
	BG1	white; attachment, form table background									#fff
	BG2 link hover background color (red)  											#D6000F 
	BG3	light gray																	#efefef
	BG4 active form field (not implemented yet)										#ffc
	BG5 info background very light blue	(placeholder for background image)			#ECF4FB
	BG6	patternTopicAction light yellow (same as T3)								#FBF7E8
	BG7 header background (very light yellow)										#FDFAF1
	BG8 accent on sorted table column												#ccc
	BG9 light yellow; attachment, form background									#FEFBF3
	BG10 light green 'new'															#ECFADC
	BG11 dark gray; diff header background (same as T8)								#8E9195
	BG12 dark yellow, submit button													#FED764
	BG13 light blue: form steps														#F6FAFD
	BG14 lighter blue: left bar														#F9FCFE
	
	Border colors
	----------------------------------------
	BO1	light gray																	#efefef
	BO2 submit button border blue ('active')										#88B6CF
	BO3	info light blue border														#D5E6F3
	BO4 border color beige, header h2 bottom border									#E2DCC8
	BO5 header h3..h6 bottom border	(75% of BO4)									#E9E4D2
	BO6 darker gray																	#aaa
	BO7 neutral gray border															#ccc
	BO8 light neutral gray															#ddd
	BO9 alert border																#f00
	BO10 dark gray (same as BG11)													#8E9195

	---------------------------------------------------------------------------------------	*/

/* LAYOUT ELEMENTS */

#patternTopBar{
	background-color:#fff;
	border-color:#ccc;
}
#patternMain { /* don't set a background here; use patternOuter */ }
#patternOuter {
	background-color:#fff; /*** Sets background of center col***/
	border-color:#ccc;
}
#patternLeftBar, #patternLeftBarContents { /* don't set a background here; use patternWrapper */ }
#patternWrapper {
	background-color:#F6FAFD; /*BG13*/
}
#patternBottomBar {
	background-color:#fff;
	border-color:#ccc;
}
#patternBottomBarContents,
#patternBottomBarContents a:link,
#patternBottomBarContents a:visited {
	color:#8E9195;	/*T8*/
}

/* GENERAL HTML ELEMENTS */

html body {
	background-color:#fff; /*BG1*/
	color:#000; /*T1*/
}
/* be kind to netscape 4 that doesn't understand inheritance */
body, p, li, ul, ol, dl, dt, dd, acronym, h1, h2, h3, h4, h5, h6 {
	background-color:transparent;
}
hr {
	color:#ccc; /*BO7*/
	background-color:#ccc; /*BO7*/
}
pre, code, tt {
	color:#7A4707; /*T6*/
}
h1, h2, h3, h4, h5, h6 {
	color:#a00; /*T5*/
}
h1 a:link,
h1 a:visited {
	color:#a00; /*T5*/
}
h1 a:hover {
	color:#FBF7E8; /*T3*/
}
h2 {
	background-color:#FDFAF1;
	border-color:#E2DCC8; /*BO4*/
}
h3, h4, h5, h6 {
	border-color:#E9E4D2; /*BO5*/
}
/* to override old Render.pm coded font color style */
.twikiNewLink font {
	color:inherit;
}
.twikiNewLink a:link sup,
.twikiNewLink a:visited sup {
	color:#666; /*T7*/
	border-color:#ddd; /*BO8*/
}
.twikiNewLink a:hover sup {
	background-color:#D6000F; /*BG2*/
	color:#FBF7E8; /*C3*/
	border-color:#D6000F; /*BG2*/ /* (part of bg) */
}
.twikiNewLink {
	border-color:#ddd; /*BO8*/
}
:link:focus,
:visited:focus,
:link,
:visited,
:link:active,
:visited:active {
	color:#06c; /*T2*/;
	background-color:transparent;
}
:link:hover,
:visited:hover {
	color:#FBF7E8; /*C3*/
	background-color:#D6000F; /*BG2*/
}
:link:hover img,
:visited:hover img {
	background:#fff; /*BG1*/
}

.patternTopic a:visited {
	color:#666; /*T7*/
}
.patternTopic a:hover {
	color:#FBF7E8; /*C3*/
}

/* Form elements */

textarea,
input,
select {
	border-color:#aaa; /*BO6*/
}
.twikiSubmit,
.twikiButton {
	border-color:#ddd #aaa #aaa #ddd;
	color:#333;
	background-color:#fff; /*BG1*/
}
.twikiSubmit:active,
.twikiButton:active {
	border-color:#999 #ccc #ccc #999;
	color:#000;
}
.twikiInputField,
.twikiSelect {
	border-color:#aaa #ddd #ddd #aaa;
	color:#000;
	background-color:#fff; /*BG1*/
}

/*	-----------------------------------------------------------
	Plugin elements
	-----------------------------------------------------------	*/

/* TablePlugin */
.twikiTable,
.twikiTable td,
.twikiTable th {
	border-color:#ccc; /*BO8*/
}
.twikiTable th a:link,
.twikiTable th a:visited,
.twikiTable th a font {
	color:#06c; /*T2*/
}
.twikiTable th a:hover,
.twikiTable th a:hover font {
	background-color:transparent;
	color:#D6000F; /*T4*/
	border-color:#D6000F; /*T4*/
}

/* TablePlugin - sorting of table columns */
.patternTopic th.twikiSortedAscendingCol,
.patternTopic th.twikiSortedDescendingCol {
	background-color:#ccc; /*BG8*/
}
th.twikiSortedAscendingCol a:link,
th.twikiSortedAscendingCol a:link font,
th.twikiSortedAscendingCol a:visited,
th.twikiSortedAscendingCol a:visited font,
th.twikiSortedDescendingCol a:link,
th.twikiSortedDescendingCol a:link font,
th.twikiSortedDescendingCol a:visited,
th.twikiSortedDescendingCol a:visited font {
	border-color:#666; /*T7*/
}
th.twikiSortedAscendingCol a:hover,
th.twikiSortedAscendingCol a:hover font,
th.twikiSortedDescendingCol a:hover,
th.twikiSortedDescendingCol a:hover font {
	border-color:#D6000F; /*T4*/
}

/* TwistyContrib */
.twistyPlaceholder {
	color:#8E9195; /*T8*/
}
a:hover.twistyTrigger {
	color:#FBF7E8; /*T3*/
}

/* TipsContrib */
.tipsOfTheDay {
	background-color:#ECF4FB; /*BG5*/
}
.patternTopic .tipsOfTheDayHeader {
	color:#333; /*T11*/
}
/* TipsContrib - in left bar */
#patternLeftBar .tipsOfTheDay a:link,
#patternLeftBar .tipsOfTheDay a:visited {
	color:#a00; /*T5*/
}
#patternLeftBar .tipsOfTheDay a:hover {
	color:#FBF7E8; /*T3*/
}

/*	-----------------------------------------------------------
	TWiki styles
	-----------------------------------------------------------	*/

.twikiGrayText {
	color:#8E9195; /*T8*/
}
.twikiGrayText a:link,
.twikiGrayText a:visited {
	color:#8E9195; /*T8*/
}
.twikiGrayText a:hover {
	color:#FBF7E8; /*C3*/
}

table.twikiFormTable th.twikiFormTableHRow,
table.twikiFormTable td.twikiFormTableRow {
	color:#666; /*T7*/
}
.twikiEditForm {
	color:#000; /*T1*/
}
.twikiEditForm .twikiFormTable th,
.twikiEditForm .twikiFormTable td {
	border-color:#ddd; /*BO8*/
}
.twikiEditForm .twikiFormTable td  {
	background-color:#F6F8FC;
}
.twikiEditForm .twikiFormTable th {
	background-color:#ECF4FB; /*BG5*/
}
.patternContent .twikiAttachments,
.patternContent .twikiForm {
	background-color:#FEFBF3; /*BG9*/
	border-color:#E2DCC8; /*BO4*/
}
.twikiAttachments table,
table.twikiFormTable {
	border-color:#ccc; /*BO7*/
	background-color:#fff; /*BG1*/
}
.twikiAttachments table {
	background-color:#fff; /*BG1*/
}
.twikiAttachments td, 
.twikiAttachments th {
	border-color:#ccc;
}
.twikiAttachments th/*,
table.twikiFormTable th.twikiFormTableHRow*/ {
	background-color:#fff; /*BG1*/
}
.twikiAttachments td {
	background-color:#fff; /*BG1*/
}
.twikiAttachments th a:link,
.twikiAttachments th a:visited,
table.twikiFormTable th.twikiFormTableHRow a:link,
table.twikiFormTable th.twikiFormTableHRow a:visited {
	color:#06c; /*T2*/
}
.twikiAttachments th font,
table.twikiFormTable th.twikiFormTableHRow font {
	color:#06c; /*T2*/
}
.twikiAttachments th a:hover,
table.twikiFormTable th.twikiFormTableHRow a:hover {
	border-color:#06c; /*T2*/
	background-color:transparent;
}
.twikiAttachments th.twikiSortedAscendingCol,
.twikiAttachments th.twikiSortedDescendingCol {
	background-color:#efefef; /*BG3*/
}
.twikiFormSteps {
	background-color:#F6FAFD; /*BG13*/
	border-color:#E2DCC8;
}
.twikiFormStep {
	border-color:#E2DCC8;
}
.twikiFormStep h3,
.twikiFormStep h4 {
	background-color:transparent;
}
.twikiToc .twikiTocTitle {
	color:#666; /*T7*/
}
.twikiBroadcastMessage {
	background-color:yellow;
}
.twikiBroadcastMessage b,
.twikiBroadcastMessage strong {
	color:#f00; /*T9*/
}
.twikiAlert,
.twikiAlert code {
	color:#f00; /*T9*/
}
.twikiEmulatedLink {
	color:#06c; /*T2*/
}
.twikiPageForm table {
	border-color:#ddd; /*BO8*/
	background:#fff; /*BG1*/
}
.twikiPageForm hr {
	border-color:#efefef; /*BO1*/
	background-color:#efefef; /*BO1*/
	color:#efefef; /*BO1*/
}
.twikiHelp {
	background-color:#ECF4FB; /*BG5*/
	border-color:#D5E6F3; /*BO3*/
}
.twikiAccessKey {
	color:inherit;
	border-color:#8E9195; /*T8*/
}
a:link .twikiAccessKey,
a:visited .twikiAccessKey,
a:hover .twikiAccessKey {
	color:inherit;
}


/*	-----------------------------------------------------------
	Pattern skin specific elements
	-----------------------------------------------------------	*/
#patternPage {
	background-color:#fff; /*BG1*/
}
/* Left bar */
#patternLeftBarContents {
	color:#666; /*T7*/
}
#patternLeftBarContents .patternWebIndicator {
	color:#000; /*T1*/
}
#patternLeftBarContents .patternWebIndicator a:link,
#patternLeftBarContents .patternWebIndicator a:visited {
	color:#000; /*T1*/
}
#patternLeftBarContents .patternWebIndicator a:hover {
	color:#FBF7E8; /*T3*/
}
#patternLeftBarContents hr {
	color:#E2DCC8; /*BO4*/
	background-color:#E2DCC8; /*BO4*/
}
#patternLeftBarContents a:link,
#patternLeftBarContents a:visited {
	color:#7A4707; /*T6*/
}
#patternLeftBarContents a:hover {
	color:#FBF7E8; /*C3*/
}
#patternLeftBarContents b,
#patternLeftBarContents strong {
	color:#333; /*T11*/
}
#patternLeftBarContents .patternChangeLanguage {
	color:#8E9195; /*T8*/
}
#patternLeftBarContents .patternLeftBarPersonal {
	border-color:#D9EAF6;
}
#patternLeftBarContents .patternLeftBarPersonal a:link,
#patternLeftBarContents .patternLeftBarPersonal a:visited {
	color:#06c; /*T2*/;
}
#patternLeftBarContents .patternLeftBarPersonal a:hover {
	color:#FBF7E8; /*C3*/
	background-color:#D6000F; /*BG2*/
}

.patternSeparator {
	font-family:monospace;
}
.patternTopicAction {
	color:#666; /*T7*/
	border-color:#E2DCC8; /*BO4*/
	background-color:#FBF7E8;
}
.patternTopicAction .twikiSeparator {
	color:#aaa;
}
.patternActionButtons a:link,
.patternActionButtons a:visited {
	color:#D6000F; /*T4*/
}
.patternActionButtons a:hover {
	color:#FBF7E8; /*C3*/
}
.patternTopicAction .twikiAccessKey {
	border-color:#C75305;
}
.patternTopicAction label {
	color:#000; /*T1*/
}
.patternHelpCol {
	color:#8E9195; /*T8*/
}
.patternFormFieldDefaultColor {
	/* input fields default text color (no user input) */
	color:#8E9195; /*T8*/
}

.patternToolBar .patternButton s,
.patternToolBar .patternButton strike,
.patternToolBar .patternButton a:link,
.patternToolBar .patternButton a:visited {
	border-color:#E2DCC8; /*BO4*/
	background-color:#fff; /*BG1*/
}
.patternToolBar .patternButton a:link,
.patternToolBar .patternButton a:visited {
	color:#666; /*T7*/
}
.patternToolBar .patternButton s,
.patternToolBar .patternButton strike {
	color:#ccc;
	border-color:#e0e0e0;
	background-color:#fff; /*BG1*/
}
.patternToolBar .patternButton a:hover {
	background-color:#D6000F; /*BG2*/
	color:#FBF7E8; /*C3*/
	border-color:#D6000F; /*T4*/
}
.patternToolBar .patternButton img {
	background-color:transparent;
}	
.patternToolBarBottom {
	border-color:#E2DCC8; /*BO4*/
}
.patternToolBar a:link .twikiAccessKey,
.patternToolBar a:visited .twikiAccessKey {
	color:inherit;
	border-color:#666; /*T7*/
}
.patternToolBar a:hover .twikiAccessKey {
	background-color:transparent;
	color:inherit;
}

.patternRevInfo,
.patternRevInfo a:link,
.patternRevInfo a:visited {
	color:#8E9195; /*T8*/
}
.patternRevInfo a:hover {
	color:#FBF7E8; /*C3*/
}

.patternMoved,
.patternMoved a:link,
.patternMoved a:visited {
	color:#8E9195; /*T8*/
}
.patternMoved a:hover {
	color:#FBF7E8; /*T3*/
}

/* WebSearch, WebSearchAdvanced */
table#twikiSearchTable th,
table#twikiSearchTable td {
	background-color:#fff; /*BG1*/
	border-color:#ddd; /*BO8*/
} 
table#twikiSearchTable th {
	color:#8E9195; /*T8*/
}
table#twikiSearchTable td.first {
	background-color:#efefef; /*BG3*/
}

/*	-----------------------------------------------------------
	Search results
	styles and overridden styles used in search.pattern.tmpl
	-----------------------------------------------------------	*/

h3.patternSearchResultsHeader,
h4.patternSearchResultsHeader {
	background-color:#FEFBF3; /*BG9*/
	border-color:#ccc; /*BO7*/
}
h4.patternSearchResultsHeader {
	color:#000;
}
.patternNoViewPage h4.patternSearchResultsHeader {
	color:#a00; /*T5*/
}
.patternSearchResult .twikiBottomRow {
	border-color:#ddd; /*BO8*/
}
.patternSearchResult .twikiAlert {
	color:#f00; /*T9*/
}
.patternSearchResult .twikiSummary .twikiAlert {
	color:#900; /*C5*/
}
.patternSearchResult .twikiNew {
	background-color:#ECFADC; /*BG10*/
	border-color:#049804; /*T10*/
	color:#049804; /*T10*/
}
.patternViewPage .patternSearchResultsBegin {
	border-color:#ddd; /*BO8*/
}

/* Search results in book view format */

.patternBookView .twikiTopRow {
	background-color:transparent; /* set to WEBBGCOLOR in css.pattern.tmpl */
	color:#666; /*T7*/
}
.patternBookView .twikiBottomRow {
	border-color:#ddd; /*BO8*/
}
.patternBookView .patternSearchResultCount {
	color:#8E9195; /*T8*/
}

/* oopsmore.pattern.tmpl */

table.patternDiffOptions img {
	border-color:#ccc; /*BO7*/
}

/* edit.pattern.tmpl */

.patternEditPage textarea#topic {
	background-color:#fff; /*BG1*/
}
.twikiChangeFormButton .twikiButton,
.twikiChangeFormButtonHolder .twikiButton {
	color:#06c; /*T2*/
	background:none;
}
.patternSig input {
	color:#8E9195; /*T8*/
	background-color:#fff; /*BG1*/
}
.patternAccessKeyInfo {
	color:#666; /*T7*/
	background-color:#ECF4FB; /*BG5*/
	border-color:#D5E6F3; /*BO3*/
}
.patternAccessKeyInfo a:link,
.patternAccessKeyInfo a:visited {
	color:#06c; /*T2*/
}
.patternAccessKeyInfo a:hover {
	color:#FBF7E8; /*T3*/
}

/* preview.pattern.tmpl */

.patternPreviewArea {
	border-color:#f00; /*BO9*/
	background-color:#fff; /*BG1*/
}

/* rdiff.pattern.tmpl */

.patternDiff {
	border-color:#ccc;
}
.patternDiff h4.patternSearchResultsHeader {
	background-color:#ccc;
}
tr.twikiDiffDebug td {
	border-color:#ddd; /*BO8*/
}
.patternDiffPage .twikiDiffTable th {
	background-color:#eee;
}
tr.twikiDiffDebug .twikiDiffChangedText,
tr.twikiDiffDebug .twikiDiffChangedText {
	background:#99ff99; /* green */
}
/* Deleted */
tr.twikiDiffDebug .twikiDiffDeletedMarker,
tr.twikiDiffDebug .twikiDiffDeletedText {
	background-color:#f99;
}
/* Added */
tr.twikiDiffDebug .twikiDiffAddedMarker,
tr.twikiDiffDebug .twikiDiffAddedText {
	background-color:#ccf;
}
/* Unchanged */
tr.twikiDiffDebug .twikiDiffUnchangedText {
	color:#8E9195; /*T8*/
}
/* Headers */
.twikiDiffChangedHeader,
.twikiDiffDeletedHeader,
.twikiDiffAddedHeader {
	background-color:#ccc;
}
/* Unchanged */
.twikiDiffUnchangedTextContents { }
.twikiDiffLineNumberHeader {
	background-color:#eee;
}


/* CONFIGURE SPECIFIC */

#twikiPassword,
#twikiPasswordChange {
	width:40em;
	margin:1em auto;
	text-align:center;
}
#twikiPassword .twikiFormSteps,
#twikiPasswordChange .twikiFormSteps {
	border-width:5px;
}

ul {
    margin-top:0;
    margin-bottom:0;
}
.logo {
    margin:1em 0 1.5em 0;
}
.formElem {
    background-color:#F3EDE7;
    margin:0.5em 0;
    padding:0.5em 1em;
}
.blockLinkAttribute {
    margin-left:0.35em;
}
.blockLinkAttribute a:link,
.blockLinkAttribute a:visited {
	text-decoration:none;
}
a.blockLink {
    display:block;
    padding:0.25em 1em;
    border-bottom:1px solid #aaa;
    text-decoration:none;
}
a:link.blockLink,
a:visited.blockLink {
    text-decoration:none; 
}
a:link:hover.blockLink {
    text-decoration:none;   
}
a:link.blockLinkOff,
a:visited.blockLinkOff {
    background-color:#F3EDE7;
    color:#333;
    font-weight:normal;
}
a:link.blockLinkOn,
a:visited.blockLinkOn {
    background-color:#b4d5ff;
    color:#333;
    font-weight:bold;
}
a.blockLink:hover {
    background-color:#1559B3;
    color:white;
}
div.explanation {
    background-color:#ECF4FB;
    padding:0.5em 1em;
    margin:0.5em 0;
}
div.specialRemark {
    background-color:#fff;
    border:1px solid #ccc;
    margin:0.5em;
    padding:0.5em 1em;
}
div.options {
    margin:1em 0;
}
div.options div.optionHeader {
    padding:0.25em 1em;
    background-color:#666;
    color:white;
    font-weight:bold;
}
div.options div.optionHeader a {
    color:#bbb;
    text-decoration:underline;
}
div.options div.optionHeader a:link:hover,
div.options div.optionHeader a:visited:hover {
    color:#b4d5ff; /* King's blue */
    background-color:#666;
    text-decoration:underline;
}
div.options .twikiSmall {
    margin-left:0.5em;
    color:#bbb;
}
div.foldableBlock {
    border-bottom:1px solid #ccc;
    border-left:1px solid #ddd;
    border-right:1px solid #ddd;
    height:auto;
    width:auto;
    overflow:auto;
    padding:0.25em 0 0.5em 0;
}
.foldableBlockOpen {
    display:block;
}
.foldableBlockClosed {
    display:block;
}
div.foldableBlock table {
    margin-bottom:1em;
}
div.foldableBlock td {
    padding:0.15em 1em;
    border-top:1px solid #ddd;
}
.info {
    color:#666; /*T7*/ /* gray */
    background-color:#ECF4FB;
    margin-bottom:0.25em;
    padding:0.25em 0;
}
.warn {
    color:#f60; /* orange */
    background-color:#FFE8D9; /* light orange */
    border-bottom:1px solid #f60;
}
a.info,
a.warn,
a.error {
	text-decoration:none;
}
.error {
    color:#f00; /*T9*/ /*red*/
    background-color:#FFD9D9; /* pink */
    border-bottom:1px solid #f00;
}
.mandatory,
.mandatory input {
    color:green;
    background-color:#ECFADC;
    font-weight: bold;
}
.mandatory {
    border-bottom:1px solid green;
}
.mandatory input {
    font-weight:normal;
}
.docdata {
    padding-top: 1ex;
    vertical-align: top;
}
.keydata {
    font-weight: bold;
    background-color:#FOFOFO;
    vertical-align: top;
}
.subHead {
    font-weight: bold;
    font-style: italic;
}
.firstCol {
    width: 30%;
    font-weight: bold;
    vertical-align: top;
}
.secondCol {
}
.hiddenRow {
    display:none;
}

.expertsOnly {
 background-color:#fde;
 padding: 3pt;
}

.expertsOnly h6 {
 font-weight: bold;
 color:#f00;
}
