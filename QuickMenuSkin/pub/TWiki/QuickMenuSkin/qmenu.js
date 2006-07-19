/***********************************
QuickMenu Class v1.0
(c) 2006 Vernon Lyon
***********************************/

var QuickMenu = {
  Set : {
    ShowOnHover : 1,
    HideTimeout : 1000
  },
  User : {
  },
  Timer : null,
  ShownMenu : null,
  Menu : function (menubar, text, action, icon, tip) {
    if (text || icon) {
      if (!menubar.QuickMenuTR) {
        menubar.appendChild(x = document.createElement("TABLE"));
        x.cellSpacing = 0;
        x.appendChild(x = document.createElement("TBODY"));
        x.appendChild(menubar.QuickMenuTR = document.createElement("TR"));
      }
      this.Button = document.createElement("TD");
      this.Button.className = "qmenu-menu";
      menubar.QuickMenuTR.appendChild(this.Button);
      if (icon) {
        this.Icon = document.createElement("IMG");
        this.Icon.src = icon;
        this.Button.appendChild(this.Icon);
        this.Button.vAlign = "middle";
        if (text) {
          this.Icon.style.paddingRight = "3px";
        }
      }
      if (text) {
        this.Button.appendChild(document.createTextNode(text));
      }
    } else {
      this.Button = menubar;
      if (!this.Button.className) this.Button.className = "qmenu-menu-free";
    }
    this.MenuBar = this.Button.MenuBar = menubar;
    if (menubar.ShowOnHover == null) menubar.ShowOnHover = QuickMenu.Set.ShowOnHover;
    this.Button.defaultClass = this.Button.className;
    if (tip) this.Button.title = tip;

    this.Button.onmouseover = function () {
      if (this.MenuList && this.MenuList.Shown) {
        clearTimeout(QuickMenu.Timer);
        QuickMenu.Timer = null;
        return;
      }
      if (this.MenuList && (this.MenuBar.ShowOnHover ||
          (QuickMenu.ShownMenu && (QuickMenu.ShownMenu.MenuBar == this.MenuBar)))) {
        clearTimeout(QuickMenu.Timer);
        QuickMenu.HideAll();
        this.className = "qmenu-menu-click";
        if (this.Dot) {
          pos = findAbsPos(this);
          this.Dot.style.top = pos.y + this.offsetHeight - 1 + "px";
          this.Dot.style.left = pos.x + "px"
          this.Dot.style.visibility = "visible";
        }
        this.MenuList.Show();
      } else {
        if (QuickMenu.ShownMenu) {
          clearTimeout(QuickMenu.Timer);
          QuickMenu.HideAll();
        }
        this.className = "qmenu-menu-over";
      }
    }

    this.Button.onmouseout = function () {
      if (this.className == "qmenu-menu-over") this.className = this.defaultClass;
      if (this.MenuList && this.MenuList.Shown && !QuickMenu.Timer)
        QuickMenu.Timer = setTimeout("QuickMenu.HideAll()", QuickMenu.Set.HideTimeout);
    }

    this.Button.onclick = function () {
      if (this.Link) {
        window.location = this.Link;
      } else if (this.Action) {
        eval (this.Action);
      } else if (this.MenuList.Shown && !this.MenuBar.ShowOnHover) {
        this.MenuList.Hide();
        if (this.Dot) this.Dot.style.visibility = "hidden";
        this.className = "qmenu-menu-over";
      } else {
        QuickMenu.HideAll();
        this.className = "qmenu-menu-click";
        if (this.Dot) {
          pos = findAbsPos(this);
          this.Dot.style.top = pos.y + this.offsetHeight - 1 + "px";
          this.Dot.style.left = pos.x + "px"
          this.Dot.style.visibility = "visible";
        }
        this.MenuList.Show();
      }
    }

    if (action) {
      if (action.substring(0,3) == "js:") {
        this.Button.Action = action.substring(3);
      } else {
        this.Button.Link = action;
      }
      return this;
    }

    this.Button.MenuList = new QuickMenu.MenuList(this, menubar);
    this.Items = this.Button.MenuList.Items;

  // Dot for IE
    if (QuickMenu.User.Ie) {
      this.Button.Dot = document.createElement("SPAN");
      this.Button.Dot.appendChild(document.createTextNode(" "));
      this.Button.Dot.style.left = "0px";
      this.Button.Dot.style.backgroundColor = "#315ea3";
      this.Button.Dot.style.visibility = "hidden";
      this.Button.Dot.style.position = "absolute";
      this.Button.Dot.style.width = "1px";
      this.Button.Dot.style.height = "1px";
      this.Button.Dot.style.fontSize = "0px";
      this.Button.Dot.style.zIndex = 3;
      pos = findAbsPos(this.Button);
      this.Button.Dot.style.top = pos.y + this.Button.offsetHeight - 1 + "px";
      this.Button.Dot.style.left = pos.x + "px"
      document.body.appendChild(this.Button.Dot);
    }
  },
  MenuList : function (parent, menubar) {
    this.Parent = parent;
    this.MenuBar = menubar;
    this.Items = [];
    this.OuterDiv = document.createElement("DIV");
    this.OuterDiv.className = "qmenu-menulist-outer";
    this.OuterDiv.style.left = this.OuterDiv.style.top = 0;
    this.Shadow = document.createElement("DIV");
    this.Shadow.className = "qmenu-menulist-shadow";
    this.InnerDiv = document.createElement("DIV");
    this.InnerDiv.className = "qmenu-menulist";
    this.Container = document.createElement("DIV");
    this.Container.className = "qmenu-menulist-container";
    this.Table = document.createElement("TABLE");
    this.Table.className = "qmenu-menulist-table";
    this.Table.cellSpacing = 0;
    this.Table.cellPadding = 0;
    this.TBody = document.createElement("TBODY");
/*
    this.Place();
*/
    this.OuterDiv.style.left = this.OuterDiv.style.top = "0px";

    this.Table.appendChild(this.TBody);
    this.Container.appendChild(this.Table);
    this.InnerDiv.appendChild(this.Container);
    this.OuterDiv.appendChild(this.Shadow);
    this.OuterDiv.appendChild(this.InnerDiv);
    document.body.appendChild(this.OuterDiv);
  },
  MenuItem : function (parent, text, action, icon, tip) {
    this.Parent = parent;
    this.TRow = document.createElement("TR");
    this.TRow.ParentMenu = parent;

    this.LeftCell = document.createElement("TD");
    if (text) {
      if (action) {
        if (action.substring(0,3) == "js:") {
          this.TRow.Action = action.substring(3);
        } else if (action.substring(0,1) == ":") {
          this.TRow.MenuList = parent.Parent[action.substring(1)] = new QuickMenu.MenuList(this, parent.MenuBar);
        } else {
          this.TRow.Link = action;
        }

        this.TRow.onclick = function () {
          if (!this.MenuList) QuickMenu.HideAll();
          if (this.Link) {
            window.location = this.Link;
          } else if (this.Action) {
            eval (this.Action);
          }
        }
        this.TRow.className = "qmenu-menuitem";
      } else {
        this.TRow.className = "qmenu-menuitem-disabled";
      }
      this.LeftCell.className = "qmenu-menuitem-left";
      if (icon) {
        this.Icon = document.createElement("IMG");
        this.Icon.src = icon;
        this.LeftCell.appendChild(this.Icon);
        this.LeftCell.align = "left";
        this.LeftCell.vAlign = "middle";
      } else {
        this.LeftCell.appendChild(document.createTextNode(" "));
      }
      this.MiddleCell = document.createElement("TD");
      this.MiddleCell.className = "qmenu-menuitem-middle";
      this.MiddleCell.appendChild(document.createTextNode(text));
      this.RightCell = document.createElement("TD");
      this.RightCell.className = "qmenu-menuitem-" + (this.TRow.MenuList ? "arrow" : "right");
      this.RightCell.appendChild(document.createTextNode(" "));
      if (tip) this.TRow.title = tip;
      this.TRow.appendChild(this.LeftCell);
      this.TRow.appendChild(this.MiddleCell);
      this.TRow.appendChild(this.RightCell);
    } else {
      this.Separator = document.createElement("TD");
      this.Separator.className = "qmenu-menuitem-separator";
      this.Separator.colSpan = 2;
      this.Separator.appendChild(document.createElement("DIV"));
      this.TRow.className = "qmenu-menuitem";
      this.TRow.appendChild(this.LeftCell);
      this.TRow.appendChild(this.Separator);
    }

    this.TRow.onmouseover = function () {
      clearTimeout(QuickMenu.Timer);
      QuickMenu.Timer = null;
      if (!text || !action || this.cells[0].className == "qmenu-menuitem-left-over")
        return;
      while (QuickMenu.ShownMenu != this.ParentMenu) QuickMenu.ShownMenu.Hide();
      this.cells[0].className = "qmenu-menuitem-left-over";
      this.cells[1].className = "qmenu-menuitem-middle-over";
      if (this.MenuList) {
        this.cells[2].className = "qmenu-menuitem-arrow-over";
        this.MenuList.Show();
      } else {
        this.cells[2].className = "qmenu-menuitem-right-over";
      }
    }
    this.TRow.onmouseout = function () {
      if (text && !this.MenuList) {
        this.cells[0].className = "qmenu-menuitem-left";
        this.cells[1].className = "qmenu-menuitem-middle";
        this.cells[2].className = "qmenu-menuitem-right";
      }
      if (!QuickMenu.Timer && QuickMenu.ShownMenu)
        QuickMenu.Timer = setTimeout("QuickMenu.HideAll()", QuickMenu.Set.HideTimeout);
    }
    parent.TBody.appendChild(this.TRow);
  },
  HideAll : function () {
    QuickMenu.Timer = "HideAll"; // Ensure that no timer gets set while hiding
    var menu;
    while (menu = QuickMenu.ShownMenu) {
      menu.Hide();
      if (menu.Parent.Button) {
        if (menu.Parent.Button.Dot) menu.Parent.Button.Dot.style.visibility = "hidden";
        menu.Parent.Button.className = menu.Parent.Button.defaultClass;
      }
    }
    QuickMenu.Timer = null;
  }
}

function findAbsPos(obj) {
  var x, y;
  x = obj.offsetLeft;
  y = obj.offsetTop;
  if (obj.offsetParent) {
    pos = findAbsPos(obj.offsetParent);
    x += pos.x;
    y += pos.y;
  }
  return { x : x, y : y };
}

QuickMenu.Menu.prototype.Add = function (text, action, icon, tip) {
  this.Button.MenuList.Add(text, action, icon, tip);
};

QuickMenu.MenuList.prototype.Add = function (text, action, icon, tip) {
  var i = this.Items.length;
  this.Items[i] = new QuickMenu.MenuItem(this, text, action, icon, tip);
};

QuickMenu.MenuList.prototype.Hide = function () {
  this.Shadow.style.visibility = "hidden";
  this.OuterDiv.style.visibility = "hidden";
  this.Shown = false;
  if (this.Parent.Button) {
    QuickMenu.ShownMenu = null;
  } else {
    this.Parent.LeftCell.className = "qmenu-menuitem-left";
    this.Parent.MiddleCell.className = "qmenu-menuitem-middle";
    this.Parent.RightCell.className = "qmenu-menuitem-" +
      (this.Parent.TRow.MenuList ? "arrow" : "right");
    QuickMenu.ShownMenu = this.Parent.Parent;
  }
};

QuickMenu.MenuList.prototype.Place = function () {
  var h, w;
  if (document.documentElement && document.documentElement.clientWidth) {
    h = document.documentElement.clientHeight;
    w = document.documentElement.clientWidth;
  } else if (document.body && document.body.offsetWidth) {
    h = document.body.offsetHeight;
    w = document.body.offsetWidth;
  } else {
    h = innerHeight;
    w = innerWidth;
  }
  if (this.Parent.Button) {
    pos = findAbsPos(this.Parent.Button);
    max = w - this.OuterDiv.offsetWidth - (QuickMenu.User.Ie ? 5 : 3);
    if (max < 0) max = 0;
    this.OuterDiv.style.left = (pos.x > max) ?  max + "px" : pos.x + "px";
    this.OuterDiv.style.top = pos.y + this.Parent.Button.offsetHeight - 1 + "px";
  } else {
    // Find left, right & top
    var l, r, t;
    if (QuickMenu.User.Ie) {
      pos = findAbsPos(this.Parent.TRow);
      l = pos.x + 1;
      r = pos.x + this.Parent.TRow.offsetWidth - 1;
      t = pos.y;
    } else if (QuickMenu.User.Safari) {
      pos = findAbsPos(this.Parent.LeftCell);
      l = pos.x + 1;
      pos = findAbsPos(this.Parent.RightCell);
      r = pos.x + this.Parent.RightCell.offsetWidth - 1;
      pos = findAbsPos(this.Parent.MiddleCell);
      t = pos.y - 1;
    } else {
      pos = findAbsPos(this.Parent.TRow);
      l = pos.x + 2;
      r = pos.x + this.Parent.TRow.offsetWidth;
      t = pos.y;
    }
    this.OuterDiv.style.left = (r + this.OuterDiv.offsetWidth + (QuickMenu.User.Ie ? 5 : 3) > w) ? l - this.OuterDiv.offsetWidth + "px" : r + "px";
    this.OuterDiv.style.top = t - (QuickMenu.User.Ie ? 1 : 0) + "px";
  }
};

QuickMenu.MenuList.prototype.Show = function () {
  QuickMenu.ShownMenu = this;
  this.Place();
  this.OuterDiv.style.visibility = "visible";
  this.Shadow.style.width = this.OuterDiv.offsetWidth + "px";
  this.Shadow.style.height = this.OuterDiv.offsetHeight + "px";
  this.Shadow.style.visibility = "visible";
  this.Shown = true;
};

QuickMenu.User.v = navigator.userAgent.toLowerCase();
QuickMenu.User.Dom = document.getElementById ? 1 : 0;
QuickMenu.User.Ie = (QuickMenu.User.v.indexOf("msie 6") > -1 && QuickMenu.User.Dom) ? 1 : 0;
QuickMenu.User.cssCompat = (QuickMenu.User.Ie && document.compatMode == "CSS1Compat") ? 1 : 0;
QuickMenu.User.Gecko = (QuickMenu.User.v.indexOf("gecko") > -1 && QuickMenu.User.Dom) ? 1 : 0;
QuickMenu.User.Safari = (QuickMenu.User.v.indexOf("safari") > -1 && QuickMenu.User.Dom) ? 1 : 0;
QuickMenu.User.Moz = (QuickMenu.User.Gecko && parseInt(navigator.productSub) > 20020512) ? 1 : 0;
QuickMenu.User.Dhtml = (QuickMenu.User.Ie || QuickMenu.User.Moz) ? 1 : 0;
