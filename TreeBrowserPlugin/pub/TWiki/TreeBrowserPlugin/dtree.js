/*--------------------------------------------------|
| dTree 2.05 | www.destroydrop.com/javascript/tree/ |
|---------------------------------------------------|
| Copyright (c) 2002-2003 Geir Landrö               |
| Copyright (c) 2006-2007 Stéphane Lenclud          |
|                                                   |
|                                                   |
| This script can be used freely as long as all     |
| copyright messages are intact.                    |
|                                                   |
| Updated: 17.04.2003                               |
| Updated: 04 Sep 2005 Thomas Weigert               |
|--------------------------------------------------*/

// Node object
function Node(id, pid, name, url, title, target, icon, iconOpen, open) {
	this.id = id;
	this.pid = pid; //parent id
	this.name = name;
	this.url = url;
	this.title = title;
	this.target = target;
	this.icon = icon;
	this.iconOpen = iconOpen;
	this._io = open || false; //SL: meens "is open".
	this._is = false; //SL: meens "is select"? Not used in by TreeBrowserPlugin.
	this._ls = false; 
	this._hc = false; //SL: meens "have children". 
	this._ai = 0;
	this._p;
};

// Tree object
function dTree(objName) {
	this.config = {
		target	: null,
		folderLinks : true,
		useSelection : true,
		useCookies : true,
		useLines : true,
		usePlusMinus : true,
        noIndent : false,
        noRoot : false,
		useIcons : true,
		useStatusText : false,
		closeSameLevel	: false,
		inOrder	: false,
		iconPath : '',
		shared : false,
        style : 'dtree',
        autoToggle : false //Clicking on a node itself will open/close that node
	}
	this.icon = {
	  root : 'base.gif',
	  folder : 'folder.gif',
	  folderOpen : 'folderopen.gif',
	  node	: 'page.gif',
	  empty	: 'empty.gif',
	  line	: 'line.gif',
	  join	: 'join.gif',
	  joinBottom : 'joinbottom.gif',
	  plus	: 'plus.gif',
	  plusBottom : 'plusbottom.gif',
	  minus : 'minus.gif',
	  minusBottom : 'minusbottom.gif',
	  nlPlus : 'nolines_plus.gif',
	  nlMinus : 'nolines_minus.gif'
	};
	this.obj = objName;
	this.aNodes = [];
	this.aIndent = [];
	this.root = new Node(-1);
	this.selectedNode = null;
	this.selectedFound = false;
	this.completed = false;
	this.level = -1; //The current depth of the tree, -1==Not rendering, 0==root  
};

// Must be called if iconPath was changed
dTree.prototype.updateIconPath = function() {
	this.icon = {
	  root : this.config.iconPath + 'base.gif',
	  folder : this.config.iconPath + 'folder.gif',
	  folderOpen : this.config.iconPath + 'folderopen.gif',
	  node	: this.config.iconPath + 'page.gif',
	  empty	: this.config.iconPath + 'empty.gif',
	  line	: this.config.iconPath + 'line.gif',
	  join	: this.config.iconPath + 'join.gif',
	  joinBottom : this.config.iconPath + 'joinbottom.gif',
	  plus	: this.config.iconPath + 'plus.gif',
	  plusBottom : this.config.iconPath + 'plusbottom.gif',
	  minus : this.config.iconPath + 'minus.gif',
	  minusBottom : this.config.iconPath + 'minusbottom.gif',
	  nlPlus : this.config.iconPath + 'nolines_plus.gif',
	  nlMinus : this.config.iconPath + 'nolines_minus.gif'
	};
};

// Adds a new node to the node array
dTree.prototype.add = function(id, pid, name, url, title, target, icon, iconOpen, open) {
	this.aNodes[this.aNodes.length] = new Node(id, pid, name, url, title, target, icon, iconOpen, open);
};

// Open/close all nodes
dTree.prototype.openAll = function() {
	this.oAll(true);
};

dTree.prototype.closeAll = function() {
	this.oAll(false);
};

// Outputs the tree to the page
dTree.prototype.toString = function() {
	var str = '<div class="'+ this.getClassTree() + '">\n';
	if (document.getElementById) {
		if (this.config.useCookies) this.selectedNode = this.getSelected();
      //SL: add the root node
		str += this.addNode(this.root);
	} else str += 'Browser not supported.';
	str += '</div>';
	if (!this.selectedFound) this.selectedNode = null;
	this.completed = true;
	return str;
};

// Creates the tree structure
dTree.prototype.addNode = function(pNode) {
	var str = '';
	var n=0;
   this.level++; //increment level
	if (this.config.inOrder) n = pNode._ai;
   //SL: for each children
	for (n; n<this.aNodes.length; n++) {	
		if (this.aNodes[n].pid == pNode.id) { //SL: what's that magic?
			var cn = this.aNodes[n];
			cn._p = pNode;
			cn._ai = n;
			this.setCS(cn);
			if (!cn.target && this.config.target) cn.target = this.config.target;
			if (cn._hc && !cn._io && this.config.useCookies) cn._io = this.isOpen(cn.id);
			if (!this.config.folderLinks && cn._hc) cn.url = null;
			if (this.config.useSelection && cn.id == this.selectedNode && !this.selectedFound) {
					cn._is = true;
					this.selectedNode = n;
					this.selectedFound = true;
			}
         //SL: render this node
			str += this.node(cn, n);
			if (cn._ls) break;
		}
	}
   this.level--; //decrement level
	return str;
};

// Creates the node icon, url and text
dTree.prototype.node = function(node, nodeId) {
   var isRoot = (this.root.id == node.pid)?true:false; //Check if we are dealing with the tree root
	//Set icons according to config and properties
	if (this.config.useIcons) {
		if (!node.icon) node.icon = (this.root.id == node.pid) ? this.icon.root : ((node._hc) ? this.icon.folder : this.icon.node);
		if (!node.iconOpen) node.iconOpen = (node._hc) ? this.icon.folderOpen : this.icon.node;
		if (isRoot) {
			node.icon = this.icon.root;
			node.iconOpen = this.icon.root;
		}
	}
	var str = '';
	//SL: Render node icon and text unless it's the root of the tree and noroot specified
	if (!isRoot || (isRoot && !this.config.noRoot))	{
      var myClass='';
      var onClick='';  
      //SL: Set the node class: 
      //If the node has children then it's either opened or closed
      //If the node has no children then it's a leaf
        if (node._hc) {
            (node._io ? myClass = this.getClassNodeOpened() : myClass = this.getClassNodeClosed());
            if (this.config.autoToggle){ onClick='onclick="javascript: ' + this.obj + '.o(' + nodeId + ');"'}; //alert(\'debug\');  
        }
        else {myClass = this.getClassLeaf();}
        if (isRoot) {myClass += ' ' + this.getClassRoot();}
		str += '<div id="n' + this.obj + nodeId + '" class="'+ myClass +'" '+ onClick + '>' + this.indent(node, nodeId);
		if (this.config.useIcons) str += '<img id="i' + this.obj + nodeId + '" src="' + ((node._io) ? node.iconOpen : node.icon) + '" alt="" />';
		//str += (node.name + this.level); //Debug level
      str += node.name;
		str += '</div>';
	}
	
   //SL: If the node has children
	if (node._hc) {
      //SL: Display that group of children if this node is root or this node is open.   
      str += '<div id="d' + this.obj + nodeId + '" class="'+ this.getClassChildren() + ' ' + this.getClassLevel() + '" style="display:' + ((isRoot || node._io) ? 'block' : 'none') + ';">';
		str += this.addNode(node);
		str += '</div>';
	}
	this.aIndent.pop();
	return str;
};

// Adds the empty and line icons
dTree.prototype.indent = function(node, nodeId) {
   var str = '';
   if (this.config.noIndent) return str;
	if (this.root.id != node.pid) {
		for (var n=0; n<this.aIndent.length; n++)
			str += '<img src="' + ( (this.aIndent[n] == 1 && this.config.useLines) ? this.icon.line : this.icon.empty ) + '" alt="" />';
		(node._ls) ? this.aIndent.push(0) : this.aIndent.push(1);
		if (node._hc) {
         if (!this.config.usePlusMinus) 
            { //Just indent without + or - icon      
            str += '<img src="' + ( (this.aIndent[n] == 1 && this.config.useLines) ? this.icon.line : this.icon.empty ) + '" alt="" />';
            return str;
            }
			str += '<a href="javascript: ' + this.obj + '.o(' + nodeId + ');"><img id="j' + this.obj + nodeId + '" src="';
			if (!this.config.useLines) str += (node._io) ? this.icon.nlMinus : this.icon.nlPlus;
			else str += ( (node._io) ? ((node._ls && this.config.useLines) ? this.icon.minusBottom : this.icon.minus) : ((node._ls && this.config.useLines) ? this.icon.plusBottom : this.icon.plus ) );
			str += '" alt="" /></a>';
		} else str += '<img src="' + ( (this.config.useLines) ? ((node._ls) ? this.icon.joinBottom : this.icon.join ) : this.icon.empty) + '" alt="" />';
	}
	return str;
};

// Checks if a node has any children and if it is the last sibling
dTree.prototype.setCS = function(node) {
	var lastId;
	for (var n=0; n<this.aNodes.length; n++) {
		if (this.aNodes[n].pid == node.id) node._hc = true;
		if (this.aNodes[n].pid == node.pid) lastId = this.aNodes[n].id;
	}
	if (lastId==node.id) node._ls = true;
};

// Returns the selected node
dTree.prototype.getSelected = function() {
	var sn = this.getCookie('cs' + this.obj);
	return (sn) ? sn : null;
};

// Highlights the selected node
dTree.prototype.s = function(id) {
	if (!this.config.useSelection) return;
	var cn = this.aNodes[id];
	if (cn._hc && !this.config.folderLinks) return;
	if (this.selectedNode != id) {
		if (this.selectedNode || this.selectedNode==0) {
			eOld = document.getElementById("s" + this.obj + this.selectedNode);
			eOld.className = "node";
		}
		eNew = document.getElementById("s" + this.obj + id);
		eNew.className = "nodeSel";
		this.selectedNode = id;
		if (this.config.useCookies) this.setCookie('cs' + this.obj, cn.id);
	}
};

// Toggle Open or close
dTree.prototype.o = function(id) {
	var cn = this.aNodes[id];
	this.nodeStatus(!cn._io, id, cn._ls);
	cn._io = !cn._io;
	if (this.config.closeSameLevel) this.closeLevel(cn);
	if (this.config.useCookies) this.updateCookie();
};

// Open or close all nodes
dTree.prototype.oAll = function(status) {
	for (var n=0; n<this.aNodes.length; n++) {
		if (this.aNodes[n]._hc && this.aNodes[n].pid != this.root.id) {
			this.nodeStatus(status, n, this.aNodes[n]._ls)
			this.aNodes[n]._io = status;
		}
	}
	if (this.config.useCookies) this.updateCookie();
};

// Opens the tree to a specific node
dTree.prototype.openTo = function(nId, bSelect, bFirst) {
	if (!bFirst) {
		for (var n=0; n<this.aNodes.length; n++) {
			if (this.aNodes[n].id == nId) {
				nId=n;
				break;
			}
		}
	}
	var cn=this.aNodes[nId];
	if (cn.pid==this.root.id || !cn._p) return;
	cn._io = true;
	cn._is = bSelect;
	if (this.completed && cn._hc) this.nodeStatus(true, cn._ai, cn._ls);
	if (this.completed && bSelect) this.s(cn._ai);
	else if (bSelect) this._sn=cn._ai;
	this.openTo(cn._p._ai, false, true);
};

// Closes all nodes on the same level as certain node
dTree.prototype.closeLevel = function(node) {
	for (var n=0; n<this.aNodes.length; n++) {
		if (this.aNodes[n].pid == node.pid && this.aNodes[n].id != node.id && this.aNodes[n]._hc) {
			this.nodeStatus(false, n, this.aNodes[n]._ls);
			this.aNodes[n]._io = false;
			this.closeAllChildren(this.aNodes[n]);
		}
	}
}// Closes all children of a node
dTree.prototype.closeAllChildren = function(node) {
	for (var n=0; n<this.aNodes.length; n++) {
		if (this.aNodes[n].pid == node.id && this.aNodes[n]._hc) {
			if (this.aNodes[n]._io) this.nodeStatus(false, n, this.aNodes[n]._ls);
			this.aNodes[n]._io = false;
			this.closeAllChildren(this.aNodes[n]);		
		}
	}
}// Change the status of a node(open or closed)
dTree.prototype.nodeStatus = function(status, id, bottom) {
	eDiv	= document.getElementById('d' + this.obj + id);
   var eJoin;
   if (this.config.usePlusMinus) 
	  eJoin	= document.getElementById('j' + this.obj + id);
	if (this.config.useIcons) {
		eIcon	= document.getElementById('i' + this.obj + id);
		eIcon.src = (status) ? this.aNodes[id].iconOpen : this.aNodes[id].icon;
	}
   if (this.config.usePlusMinus) 
	eJoin.src = (this.config.useLines)?
	((status)?((bottom)?this.icon.minusBottom:this.icon.minus):((bottom)?this.icon.plusBottom:this.icon.plus)):
	((status)?this.icon.nlMinus:this.icon.nlPlus);
	eDiv.style.display = (status) ? 'block': 'none';
   //SL: Change the class of the node div
   var eNodeDiv = document.getElementById('n' + this.obj + id);
   eNodeDiv.className = (status) ? this.getClassNodeOpened() : this.getClassNodeClosed();
   if (this.root.id == this.aNodes[id].pid) { eNodeDiv.className += ' ' + this.getClassRoot(); } //Add root class to the root 
};

// [Cookie] Clears a cookie
dTree.prototype.clearCookie = function() {
	var now = new Date();
	var yesterday = new Date(now.getTime() - 1000 * 60 * 60 * 24);
	this.setCookie('co'+this.obj, 'cookieValue', yesterday);
	this.setCookie('cs'+this.obj, 'cookieValue', yesterday);
};

// [Cookie] Sets value in a cookie
dTree.prototype.setCookie = function(cookieName, cookieValue, expires, path, domain, secure) {
	document.cookie =
		escape(cookieName) + '=' + escape(cookieValue)
		+ (expires ? '; expires=' + expires.toGMTString() : '')
	        + ((this.config.shared) ? '; path=/' : (path ? '; path=' + path : ''))
		+ (domain ? '; domain=' + domain : '')
		+ (secure ? '; secure' : '');
};

// [Cookie] Gets a value from a cookie
dTree.prototype.getCookie = function(cookieName) {
	var cookieValue = '';
	var posName = document.cookie.indexOf(escape(cookieName) + '=');
	if (posName != -1) {
		var posValue = posName + (escape(cookieName) + '=').length;
		var endPos = document.cookie.indexOf(';', posValue);
		if (endPos != -1) cookieValue = unescape(document.cookie.substring(posValue, endPos));
		else cookieValue = unescape(document.cookie.substring(posValue));
	}
	return (cookieValue);
};

// [Cookie] Returns ids of open nodes as a string
dTree.prototype.updateCookie = function() {
	var str = '';
	for (var n=0; n<this.aNodes.length; n++) {
		if (this.aNodes[n]._io && this.aNodes[n].pid != this.root.id) {
			if (str) str += '.';
			str += this.aNodes[n].id;
		}
	}
	this.setCookie('co' + this.obj, str);
};

// [Cookie] Checks if a node id is in a cookie
dTree.prototype.isOpen = function(id) {
	var aOpen = this.getCookie('co' + this.obj).split('.');
	for (var n=0; n<aOpen.length; n++)
		if (aOpen[n] == id) return true;
	return false;
};

//SL: The getClass functions are used to get the CSS class

dTree.prototype.getClassTree = function() {
    return this.config.style;
}

dTree.prototype.getClassLeaf = function() {
    return this.config.style + 'Leaf';
}

dTree.prototype.getClassNodeOpened = function() {
    return this.config.style + 'NodeOpened';
}

dTree.prototype.getClassNodeClosed = function() {
    return this.config.style + 'NodeClosed';
}

dTree.prototype.getClassChildren = function() {
    return this.config.style + 'Children';
}

dTree.prototype.getClassLevel = function() {
    return this.config.style + 'Level' + this.level;
}

dTree.prototype.getClassRoot = function() {
    return this.config.style + 'Root';
}


// If Push and pop is not implemented by the browser
if (!Array.prototype.push) {
	Array.prototype.push = function array_push() {
		for(var i=0;i<arguments.length;i++)
			this[this.length]=arguments[i];
		return this.length;
	}
};
if (!Array.prototype.pop) {
	Array.prototype.pop = function array_pop() {
		lastElement = this[this.length-1];
		this.length = Math.max(this.length-1,0);
		return lastElement;
	}
};
