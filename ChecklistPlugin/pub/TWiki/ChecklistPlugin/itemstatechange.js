var clpStateChangeObjectArray = new Array(); // queue
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
	document.getElementsByTagName('body')[0].style.cursor="auto";
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

			if (oldHref==newHref) continue;

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

			clpChangeDivText(realId, divTxt);
			

		}
	} else {
		document.write(responseText);
	}
	clpHandleNextObject(self);
}
function clpDoIt() {
	if (!this.clpInit()) {
		document.submit(url);
		return;
	}
	document.getElementsByTagName('body')[0].style.cursor="wait";
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
function clpChangeDivText(id, text) {
	var e = document.getElementById("CLP_TT_"+id);
	if (e) {
		while (e.hasChildNodes()) e.removeChild(e.firstChild); 
		e.appendChild(document.createTextNode(text));
	}
	e = document.getElementById("CLP_A_"+id);
	if (e) e.style.cursor="wait";
	
}
var clpSubmitItemStateChangeMutex = 0;
function submitItemStateChange(url) {
	while (clpSubmitItemStateChangeMutex>0) { alert("You click to fast for me"); }
	clpSubmitItemStateChangeMutex++;
	var newStateChangeObject = new ClpStateChangeObject(url);
	clpStateChangeObjectArray.push(newStateChangeObject);
	clpChangeDivText(clpGetIdFromUrl(url),"State is changing ... please wait ...");
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
function clpTooltipShow(tooltipId, parentId, posX, posY) {
	var it = document.getElementById(tooltipId);
    
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
	img.style.cursor='move';
}

function clpTooltipHide(id) {
	var it = document.getElementById(id); 
	if (it) it.style.visibility = 'hidden'; 
}

