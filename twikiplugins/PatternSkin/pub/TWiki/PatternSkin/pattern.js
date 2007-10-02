var Pattern = {

	searchResultsCount:0,
	metaTags:[],
	
	createTwikiActionFormStepSign:function(el) {
		var sign = '&#9658;';
		var newEl = twiki.HTML.insertBeforeElement(
			el,
			'span',
			sign
		);
		newEl.className = 'twikiActionFormStepSign';
	},
	
	launchWindow:function(inWeb, inTopic) {
		var scriptUrl = Pattern.getMetaTag('SCRIPTURLPATH');
		return twiki.Window.openPopup(scriptUrl + "/",
			{ web:inWeb,
			  topic:inTopic,
			  template:"viewplain"
			} );
	},
	
	getMetaTag:function(inKey) {
		if (!Pattern.metaTags || Pattern.metaTags.length == 0) {
			Pattern.metaTags = document.getElementsByTagName("META");
		}
		for (var i in Pattern.metaTags) { 
			if (Pattern.metaTags[i].name == inKey) { 
				return Pattern.metaTags[i].content; 
   			}
   		}
		return null; 
	},
	
	/**
	Creates a attachment counter in the attachment table twisty.
	*/
	setAttachmentCount:function(inTableElement) {		
		var count = inTableElement.getElementsByTagName("tr").length - 1;
		var countStr = " " + "<span class='patternAttachmentCount'>" + " ("  + count + ")" + "<\/span>";
		var showElem = document.getElementById('topicattachmentslistshow');
		if (showElem != undefined) {
			var labelElem = showElem.getElementsByTagName('a')[0].getElementsByTagName('span')[0];
			labelElem.innerHTML += countStr;
		}
		var hideElem = document.getElementById('topicattachmentslisthide');
		if (hideElem != undefined) {
			var labelElem = hideElem.getElementsByTagName('a')[0].getElementsByTagName('span')[0];
			labelElem.innerHTML += countStr;
		}
	},
	
	addSearchResultsCounter:function(el) {
		var count = twiki.HTML.getHtmlOfElement(el);
		Pattern.searchResultsCount += parseInt(count);
	},
	
	displayTotalSearchResultsCount:function(el) {
		// write result count
		if (Pattern.searchResultsCount >= 10) {
			var text = " " + TEXT_NUM_TOPICS + " <b>" + Pattern.searchResultsCount + " <\/b>";
			twiki.HTML.setHtmlOfElement(el, text);			
		}		
	},
	
	displayModifySearchLink:function() {
		var linkContainer = document.getElementById('twikiModifySearchContainer');
		if (linkContainer != null) {
			if (Pattern.searchResultsCount > 0) {
				var linkText=' <a href="#" onclick="location.hash=\'twikiSearchForm\'; return false;"><span class="twikiLinkLabel twikiSmallish">' + TEXT_MODIFY_SEARCH + '</span></a>';
					twiki.HTML.setHtmlOfElement(linkContainer, linkText);
			}
		}
	}
}

var patternRules = {
	'.twikiFormStep h3' : function(el) {
		Pattern.createTwikiActionFormStepSign(el);
	},
	'#jumpFormField' : function(el) {
		twiki.Form.initBeforeFocusText(el,TEXT_JUMP);
		el.onfocus = function() {
			twiki.Form.clearBeforeFocusText(this);
		}
		el.onblur = function() {
			twiki.Form.restoreBeforeFocusText(this);
		}
	},
	'#quickSearchBox' : function(el) {
		twiki.Form.initBeforeFocusText(el,TEXT_SEARCH);
		el.onfocus = function() {
			twiki.Form.clearBeforeFocusText(this);
		}
		el.onblur = function() {
			twiki.Form.restoreBeforeFocusText(this);
		}
	},
	'#tabletwikiAttachmentsTable' : function(el) {
		Pattern.setAttachmentCount(el);
	},
	'body.patternEditPage' : function(el) {
		twiki.Event.addLoadEvent(initForm, false); // call after Behaviour
	},
	'body.patternLoginPage' : function(el) {
		var initForm = function() {
			document.loginform.username.focus();
		}
		twiki.Event.addLoadEvent(initForm, true);
	},
	'.twikiSearchResultCount' : function(el) {
		Pattern.addSearchResultsCounter(el);
	},
	'#twikiNumberOfResultsContainer' : function(el) {
		Pattern.displayTotalSearchResultsCount(el);
	},
	'#twikiWebSearchForm':function(el) {
		Pattern.displayModifySearchLink();
	}
};
Behaviour.register(patternRules);

function launchWindow(inWeb, inTopic) {
	Pattern.launchWindow(inWeb, inTopic);
}

var TEXT_JUMP = Pattern.getMetaTag('TEXT_JUMP');
var TEXT_SEARCH = Pattern.getMetaTag('TEXT_SEARCH');
var TEXT_NUM_TOPICS = Pattern.getMetaTag('TEXT_NUM_TOPICS');
var TEXT_MODIFY_SEARCH = Pattern.getMetaTag('TEXT_MODIFY_SEARCH');
