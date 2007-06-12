var pISearch = {};
var userData = new Array({name:"Abdel Rufus",phone:"532",topic:"Main/AbdelSeamari",pictureName:"1313215_eed15b0dca_b_d.jpg"}, {name:"Giovanni Babucci",phone:"573",topic:"Main/AldoBabucci",pictureName:"158501673_5d14967316_b.jpg"}, {name:"Alex Maduro",phone:"591",topic:"Main/AlexHoogeveen",pictureName:"124088711_64631b5dff_b.jpg"}, {name:"Alissa Riviera",phone:"930",topic:"Main/AlissaVanSlooten",pictureName:"368334804_2d2fe10879.jpg"}, {name:"Anika Juste",phone:"564",topic:"Main/AnikaJonker",pictureName:"312092095_142ac3669b_o.jpg"}, {name:"Anne-Marijn Nagtzaam",phone:"998",topic:"Main/AnneMarijnBogers",pictureName:"6325515_77ae218a5a.jpg"}, {name:"Babet van der Velden",phone:"",topic:"Main/AnnekeVanDerVeen",pictureName:"21335732_a9f6933594.jpg"}, {name:"Daan Kuppersberg",phone:"986",topic:"Main/AnnemarieDeBont",pictureName:"204755191_95612bf8a5.jpg"}, {name:"Maaike Blank",phone:"513",topic:"Main/AnnemiekeBlank",pictureName:"411446329_0a7f971b54_b.jpg"}, {name:"Deirdre Caldo",phone:"949",topic:"Main/AnnemiekeDeering",pictureName:"165867812_4b478d82b7_b.jpg"}, {name:"Shelly Tame",phone:"547",topic:"Main/AnoesjkaKolijn",pictureName:"80990871_02d2435b2a.jpg"}, {name:"Ary de Friance",phone:"526",topic:"Main/ArieDeBonth",pictureName:"226489384_8faddac393.jpg"}, {name:"Arjan Occidence",phone:"538",topic:"Main/ArjanKoole",pictureName:"226489383_750616008a.jpg"}, {name:"Arjan Mouthaen",phone:"938",topic:"Main/ArjanWulder",pictureName:"243903783_e3581ec202_b.jpg"}, {name:"Tom Valente",phone:"568",topic:"Main/ArjenBultje",pictureName:"243910247_43ba7c2b45_b.jpg"}, {name:"John Doe",phone:"222",topic:"Main/PersonalInfoDemoUser",pictureName:"tiger.jpg"});
var MAX_RESULTS;
if (MAX_RESULTS == undefined) MAX_RESULTS = 12;
pISearch.initSearch = function() {}
pISearch.startSearch = function() {}
pISearch.endSearch = function(inOutput) {
	var outputElem = document.getElementById("personalInfoSearchResults");
	if (outputElem) outputElem.innerHTML = inOutput;
}
pISearch.processResult = function(inName, inUserData) {
	var url = "http://arthurs-snelle-powerbook.local/~webserver/twiki/bin/view/" + inUserData.topic;
	var phone = inUserData.phone;
	var output = "";
	output += "<tr>";
	output += "<td><a href=\u0027" + url + "\u0027>" + inName + "</a></td>";
	output += "<td>" + phone + "</td>";
	output += "</tr>";
	return output;
}
pISearch.processZeroResults = function() {}
pISearch.withinBounds = function(inCount) {
	if (MAX_RESULTS == -1) return true;
	return inCount < MAX_RESULTS;
}
pISearch.outputHtmlStart = function() {
	return "<table cellpadding=\u00270\u0027 cellspacing=\u00270\u0027>";
}
pISearch.outputHtmlEnd = function() {
	return "</table>";
}
pISearch.showResults = function() {
	var output = "";
	var resultCount = 0;
	var query = document.getElementById("personalInfoSearchBox").value.toLowerCase();
	if (query.length != 0) {
		var regex = new RegExp("\\b" + query, "gi");
		pISearch.startSearch();
		output = pISearch.outputHtmlStart();
		var i = 0;
		while ( i < userData.length && pISearch.withinBounds(resultCount)) {
			var name = userData[i].name;
			if (name.match(regex)) {
				output += pISearch.processResult(name, userData[i]);
				resultCount++;
			}
			i++;
		}
		output += pISearch.outputHtmlEnd();
		
	} else {
		pISearch.processZeroResults();
	}
	if (query.length > 0 && resultCount == 0) {
		output = "";
	}
	pISearch.endSearch(output);
}