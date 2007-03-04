
	var MAX_RESULTS = 12;
	function showResults() {
		var userTopics = new Array("Main.PersonalInfoDemoUser");
		var names = new Array("John Doe");
		var phoneNumbers = new Array("111");
		//
		var output = "";
		var resultCount = 0;
		var query = document.getElementById("personalInfoSearchBox").value.toLowerCase();
		if (query.length != 0) {
			var regex = new RegExp("\\b" + query, "gi");
			output = "<table cellpadding=\u00270\u0027 cellspacing=\u00270\u0027>";
			var i = 0;
			while ( i < names.length && resultCount < MAX_RESULTS) {
				var linkLabel = "";
				if (names[i].match(regex)) {
					linkLabel = names[i];
				}
				if (linkLabel != "") {
					output += "<tr>";
					output += "<td><a href=\u0027http://arthurs-snelle-powerbook.local/~webserver/twiki/bin/view/" + userTopics[i] + "\u0027>" + linkLabel + "</a></td>";
					output += "<td>" + phoneNumbers[i] + "</td>";
					output += "</tr>";
					resultCount++;
				}
				i++;
			}
			output += "</table>";
		}
		if (query.length > 0 && resultCount == 0) {
			output = "";
		}
		document.getElementById("personalInfoSearchResults").innerHTML = output;
	}
// 