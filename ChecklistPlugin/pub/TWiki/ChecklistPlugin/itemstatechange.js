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
		var oldLink = self.changes.shift();
		var newLink = self.changesNew.shift();
		var oldUrl = clpStripUrl(oldLink);
		var newUrl = clpStripUrl(newLink);
		var n = clpGetStateChangeObject(oldUrl);
		if (n) n.url=newUrl;
	}
	if (clpStateChangeObjectArray.length>0) clpStateChangeObjectArray.shift().clpDoIt();
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
			if (!e) next;
			var oldHref = clpStripId(e.href);
			var newHref = clpStripId(href);
			if (oldHref!=newHref) {
				self.changes.push(e.href);
				self.changesNew.push(href);
			} else {
				continue;
			}
			if (e) e.href = href; 
			var realId = id.replace(/CLP_A_/i,"");
			var imgExpr = new RegExp("<img[^>]+id=\"CLP_IMG_" + realId + "\"[^>]*>","i");
			var img = "" + imgExpr.exec(responseText);
			img.match(/src="([^"]+)"/);
			var src = RegExp.$1;
			img.match(/alt="([^"]+)"/);
			var alt = RegExp.$1;
			e = document.getElementById("CLP_IMG_"+realId);
			if (e) {
				e.src = src;
				e.title = alt;
				e.alt = alt;
			}

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
var clpSubmitItemStateChangeMutex = 0;
function submitItemStateChange(url) {
	while (clpSubmitItemStateChangeMutex>0) { alert("You click to fast for me"); }
	clpSubmitItemStateChangeMutex++;
	var newStateChangeObject = new ClpStateChangeObject(url);
	clpStateChangeObjectArray.push(newStateChangeObject);
	if (clpStateChangeObjectArray.length==1) newStateChangeObject.clpDoIt();
	clpSubmitItemStateChangeMutex--;
}
