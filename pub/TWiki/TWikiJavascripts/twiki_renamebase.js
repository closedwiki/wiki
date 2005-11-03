function checkAll(theCheck) {
	// find button element index
	var i, j = 0;
	for (i = 0; i < pageElem.length; ++i) {
		if (document.rename.elements[i].name.match("referring_topics")) {
			document.rename.elements[i].checked = theCheck;
		}
	}
}