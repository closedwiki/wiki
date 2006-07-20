
GoogleAjaxSearch  = {};

GoogleAjaxSearch.createSearchControl = function (inQueryString) {
	
	// Create a search control
	var searchControl = new GSearchControl();

	// Set options
	var options = new GsearcherOptions();
	
	// put results in twisty
	options.setExpandMode(GSearchControl.EXPAND_MODE_OPEN);

	// open links in same window
	searchControl.setLinkTarget(GSearch.LINK_TARGET_SELF);

	// site restricted web search
	var siteSearch = new GwebSearch();
	siteSearch.setSiteRestriction(GoogleAjaxSearch.getSearchSite());
	searchControl.addSearcher(siteSearch, options);

	// tell the searcher to draw itself and tell it where to attach
	var elem = document.getElementById("googleAjaxSearchControl");

	// assume a HTML element with id = googleAjaxSearchInputElement
	var inputElement = document.getElementById("googleAjaxSearchInputElement");
	var drawOptions = new GdrawOptions();
	drawOptions.setInput(inputElement);
	drawOptions.setDrawMode(GSearchControl.DRAW_MODE_LINEAR);
	searchControl.draw(elem, drawOptions);

	// execute an inital search
	// check if a search query parameter with key "googleAjaxQuery" has been passed
	var searchParam = GoogleAjaxSearch.getUrlParam();
	var searchString = (searchParam != "") ? searchParam : "";
	if (searchString == "" && inQueryString != undefined) searchString = inQueryString;
	searchControl.execute(searchString);
}

addLoadEvent(GoogleAjaxSearch.createSearchControl);