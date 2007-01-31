var clpStateChangeObjectArray = new Array(); // queue
var clpCursorNormalStyle = "move";
var clpCursorInProgressStyle = "wait";
var clpInProgressDivText = "State is changing ... please wait ...";
function ClpStateChangeObject(url, stateChangeRequest) {
	this.stateChangeRequest = stateChangeRequest;
	this.url = url;
	this.clpDoIt=clpDoIt;
	this.clpHandleNextObject=clpHandleNextObject;
	this.clpInit = clpInit;
	this.changes = new Array();
	this.changesNew = new Array();
}
function clpInit() {
	try { // Firefox, Opera 8.0+, Safari
		this.stateChangeRequest = new XMLHttpRequest();
	} catch (e) { // Internet Explorer
		try {
			this.stateChangeRequest = new ActiveXObject("Msxml2.XMLHTTP");
		} catch (e) {
			try {
				this.stateChangeRequest=new ActiveXObject("Microsoft.XMLHTTP");
			} catch (e) {
				alert("Your browser does not support AJAX!\nPlease disable AJAX (e.g. use attribute: useajax=\"off\") ");
			}
		}
	}
	return this.stateChangeRequest;
}
function clpStripUrl(href) {
	href.match(/submitItemStateChange.'([^']+)'/);
	return RegExp.$1;
}
function clpHandleNextObject(self) {
	clpStateChangeObjectArray.shift(); // remove myself
	while (self.changes.length>0) {
		var oldUrl = clpStripUrl(self.changes.shift());
		var newUrl = clpStripUrl(self.changesNew.shift());
		var n = clpGetStateChangeObject(oldUrl);
		if (n) n.url=newUrl;
	}
	if (clpStateChangeObjectArray.length>0) clpStateChangeObjectArray.shift().clpDoIt();
	clpSetCursorByTagName("body", "auto");
}
function clpHandleStateChange(self) {
	if (self.stateChangeRequest.readyState!=4) return;
	if (self.stateChangeRequest.status != 200) {
		document.write(self.stateChangeRequest.responseText);
		return;
	}

	var responseText = self.stateChangeRequest.responseText;

	var links = responseText.match(/<a[^>]+id="CLP_A_[^>]+>/ig);
	if (links && (links.length>0)) {
		for (var i = 0 ; i < links.length; ++i) {
			var link = links[i];
			link.match(/id="([^"]+)"/);
			var id = RegExp.$1;
			link.match(/href="([^"]+)"/);
			var href=RegExp.$1;
			var e = document.getElementById(id);
			if (!e) continue;
			var oldHref = clpStripId(e.href);
			var newHref = clpStripId(href);

			e.style.cursor=clpCursorNormalStyle;
			// if (oldHref==newHref) continue;

			self.changes.push(e.href);
			self.changesNew.push(href);

			if (e) e.href = href; 
			var realId = id.replace(/CLP_A_/i,"");
			var imgExpr = new RegExp("<img[^>]+id=\"CLP_IMG_" + realId + "\"[^>]*>","i");
			var img = "" + imgExpr.exec(responseText);
			img.match(/src="([^"]+)"/);
			var src = RegExp.$1;
			img.match(/title="([^"]+)"/);
			// var title = RegExp.$1;
			e = document.getElementById("CLP_IMG_"+realId);
			if (e) {
				e.src = src;
				// e.title = title;
				// e.alt = title;
			}

			var divExpr = new RegExp("<div[^>]+id=\"CLP_TT_"+realId+"\"[^>]*>(.*?)</div>");
			divExpr.exec(responseText);
			var divTxt = RegExp.$1;

			clpChangeDivText("CLP", realId, divTxt);
						
			var smlinks = responseText.match(/<a[^>]+id="CLP_SM_A_[^>]+>/ig);
			if (smlinks && (smlinks.length>0)) {
				for (var j=0; j<smlinks.length; ++j) {
					var smlink = smlinks[j];
					if (smlink.indexOf(realId)==-1) continue;
					smlink.match(/id="([^"]+)"/i);
					var smid = RegExp.$1;
					smlink.match(/href="([^"]+)"/);
					var smhref = RegExp.$1;
					smlink.match(/title="([^"]+)"/);
					var smtitle = RegExp.$1;
					var sme = document.getElementById(smid);
					if (sme) {
						sme.style.cursor=clpCursorNormalStyle;
						sme.href = smhref;
						// sme.title = smtitle;
					} // if
					var smttid = smid.replace(/CLP_SM_A_/,"");
					sme = document.getElementById("CLP_SM_IMG_"+smttid);
					if (sme) sme.style.cursor=clpCursorNormalStyle;
					var smDivExpr = new RegExp("<div[^>]+id=\"CLP_SM_TT_"+smttid+"\"[^>]*>(.*?)</div>");	
					smDivExpr.exec(responseText);
					var smDivTxt = RegExp.$1;
					clpChangeDivText("CLP_SM",smttid, smDivTxt);
				} // for
			} // if

		} // for 
	} else {
		document.write(responseText);
	} // if
	clpHandleNextObject(self);
}
function clpDoIt() {
	if (!this.clpInit()) {
		document.submit(url);
		return;
	}
	clpSetCursorByTagName("body", clpCursorInProgressStyle);
	var self = this;
	this.stateChangeRequest.onreadystatechange=function() {
		try {
			clpHandleStateChange(self);
		} catch (e) {
			alert("Sorry, an error occured:\n"+e+"\nPlease reload the page!");
		}
	};
	if (this.stateChangeRequest.onerror) {
		this.stateChangeRequest.onerror=function() {
			document.write(self.stateChangeRequest.responseText);
		};
	}
	this.stateChangeRequest.open("GET", this.url, true);
	this.stateChangeRequest.send(null);
}
function clpStripId(url) {
	return url.replace(/clpid=[^;]+;/i,"");
}
function clpGetStateChangeObject(url) {
	for (var i=0; i<clpStateChangeObjectArray.length; ++i) {
		if (clpStripId(clpStateChangeObjectArray[i].url)==clpStripId(url)) return clpStateChangeObjectArray[i];
	}
	return null;
}
function clpGetIdFromUrl(url) {
	// clpscn + clpsc
	url.match(/clpsc=([^\;]+)\;/);
	var clpsc = RegExp.$1;
	url.match(/clpscn=([^\;]+)\;/);
	var clpscn = RegExp.$1;
	return clpscn+clpsc;
}
function clpChangeDivText(prefix,id, text) {
	var e = document.getElementById(prefix+"_TT_"+id);
	if (e) {
		while (e.hasChildNodes()) e.removeChild(e.firstChild); 
		e.appendChild(document.createTextNode(text));
	}
	
}
function clpSetCursorByTagName(tagName, cursor) {
	var eArr = document.getElementsByTagName(tagName);
	if (eArr && eArr.length>0) eArr[0].style.cursor=cursor;
}
var clpSubmitItemStateChangeMutex = 0;
function submitItemStateChange(url) {
	while (clpSubmitItemStateChangeMutex>0) { alert("You click to fast for me"); }
	clpSubmitItemStateChangeMutex++;
	var newStateChangeObject = new ClpStateChangeObject(url);
	clpStateChangeObjectArray.push(newStateChangeObject);

	var id = clpGetIdFromUrl(url);
	var e = document.getElementById("CLP_A_"+id);
	if (e) e.style.cursor=clpCursorInProgressStyle;

	clpChangeDivText("CLP", id, clpInProgressDivText);

	if (clpStateChangeObjectArray.length==1) newStateChangeObject.clpDoIt();
	clpSubmitItemStateChangeMutex--;
}

// --- tooltips (derived from http://www.texsoft.it/index.php?c=software&m=sw.js.htmltooltip&l=it) ---
function clpTooltipFindPosX(obj) 
{
	var curleft = 0;
	if (obj.offsetParent) {
		//while (obj.offsetParent) {
			curleft += obj.offsetLeft
			obj = obj.offsetParent;
		//}
	} else if (obj.x) curleft += obj.x;
	
	return curleft;
}
function clpTooltipFindPosY(obj) 
{
	var curtop = 0;
	if (obj.offsetParent) {
		while (obj.offsetParent) {
			curtop += obj.offsetTop
			obj = obj.offsetParent;
		}
	} else if (obj.y) curtop += obj.y;
	return curtop;
}
var clpTooltipLastVisibleId = new Array();
function clpTooltipShow(tooltipId, parentId, posX, posY,closeAll) {
	var it = document.getElementById(tooltipId);

	if (closeAll) {
		while (clpTooltipLastVisibleId.length>0) {
			var lv = document.getElementById(clpTooltipLastVisibleId.shift());
			if (lv) lv.style.visibility = 'hidden';
		}
	}
	clpTooltipLastVisibleId.push(tooltipId);
    
	if (!it) return;
	//if ((it.style.top == '' || it.style.top == 0) && (it.style.left == '' || it.style.left == 0)) {
		// need to fixate default size (MSIE problem)
		// it.style.width = it.offsetWidth + 'px';
		// it.style.height = it.offsetHeight + 'px';

		var img = document.getElementById(parentId); 

		// if tooltip is too wide, shift left to be within parent 
		//if (posX + it.offsetWidth > img.offsetWidth) posX = img.offsetWidth - it.offsetWidth;
		//if (posX < 0 ) posX = 0; 

		var x = clpTooltipFindPosX(img) + posX;
		var y = clpTooltipFindPosY(img) + posY;

		it.style.left = x + 'px';
		it.style.top = y + 'px';
	//}
	it.style.visibility = 'visible'; 
	img.style.cursor=clpCursorNormalStyle;
}

function clpTooltipHide(id) {
	var it = document.getElementById(id); 
	if (it) it.style.visibility = 'hidden'; 
}

