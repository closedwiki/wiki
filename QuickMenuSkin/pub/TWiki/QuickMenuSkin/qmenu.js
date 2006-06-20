/***********************************
QuickMenu Class v0.9

A more simplified version of XWebMenu:
Jeremy McPeak http://www.wdonline.com/dhtml/xwebmenu/

(c) 2006  Vernon Lyon  vlyon@hotmail.com
***********************************/

var QuickMenu = {
  Set : {
    ShowOnHover : 1
  },
  User : {
  },
  Timer : null,
  ShownMenu : null,
  MenuButn : function (menu, parent, text, action, tip) {
    if (text) {
      this.Button = document.createElement("SPAN");
      this.Button.className = "qmenu-menu";
      this.Button.appendChild(document.createTextNode(text));
      parent.appendChild(this.Button);
    } else {
      this.Button = parent;
      if (!this.Button.className) this.Button.className = "qmenu-menu-free";
    }
    this.Button.Menu = menu;
    this.Button.MenuBar = parent;
    if (parent.ShowOnHover == null) parent.ShowOnHover = QuickMenu.Set.ShowOnHover;
    this.Button.defaultClass = this.Button.className;
    if (tip) this.Button.title = tip;

  // Dot for IE
    if (QuickMenu.User.Ie) {
      this.Button.Dot = document.createElement("SPAN");
      this.Button.Dot.appendChild(document.createTextNode(" "));
      this.Button.appendChild(this.Button.Dot);
      this.Button.Dot.style.left = "0px";
      this.Button.Dot.style.backgroundColor = "#315ea3";
      this.Button.Dot.style.visibility = "hidden";
      this.Button.Dot.style.position = "absolute";
      this.Button.Dot.style.width = "1px";
      this.Button.Dot.style.height = "1px";
      this.Button.Dot.style.fontSize = "0px";
    }

    if (action) {
      if (action.substring(0,3) == "js:") {
        this.Button.Action = action.substring(3);
      } else {
        this.Button.Link = action;
      }
    }

    this.MouseOver = function () {
      if (this.Menu.Shown) {
        clearTimeout(QuickMenu.Timer);
        QuickMenu.Timer = null;
        return;
      }
      if (this.MenuBar.ShowOnHover ||
          (QuickMenu.ShownMenu && (QuickMenu.ShownMenu.MenuBar == this.Menu.MenuBar))) {
        clearTimeout(QuickMenu.Timer);
        QuickMenu.HideAll();
        if (this.Menu.Items.length) {
          this.className = "qmenu-menu-click";
          if (this.Dot) {
            this.Dot.style.top = (this.offsetHeight - 1) + "px";
            this.Dot.style.visibility = "visible";
          }
          this.Menu.Show();
        } else {
          this.className = "qmenu-menu-over";
        }
      } else {
        this.className = "qmenu-menu-over";
      }
    }

    this.MouseOut = function () {
      if (this.className == "qmenu-menu-over") this.className = this.defaultClass;
      if (!QuickMenu.Timer && this.Menu.Shown)
        QuickMenu.Timer = setTimeout("QuickMenu.HideAll()", 1000);
    }

    this.MouseClick = function () {
      if (this.Link) {
        window.location = this.Link;
      } else if (this.Action) {
        eval (this.Action);
      } else if (this.Menu.Shown && !this.MenuBar.ShowOnHover) {
        this.Menu.Hide();
        if (this.Dot) this.Dot.style.visibility = "hidden";
        this.className = "qmenu-menu-over";
      } else {
        QuickMenu.HideAll();
        this.className = "qmenu-menu-click";
        if (this.Dot) {
          this.Dot.style.top = (this.offsetHeight - 1) + "px";
          this.Dot.style.visibility = "visible";
        }
        this.Menu.Show();
      }
    }

    this.Button.onmouseover = this.MouseOver;
    this.Button.onmouseout = this.MouseOut;
    this.Button.onclick = this.MouseClick;
  },
  Menu : function (parent, text, action, tip) {
    this.Items = [];
    this.OuterDiv = document.createElement("DIV");
    this.OuterDiv.className = "qmenu-menulist-outer";
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
    if (action == ":") {
      this.Parent = parent;
      this.MenuBar = parent.Parent.MenuBar;
      pos = findAbsPos(this.Parent.TRow);
      this.OuterDiv.style.left = pos.x + this.Parent.TRow.offsetWidth + "px";
      this.OuterDiv.style.top = pos.y - 1 + "px";
    } else {
      this.Parent = new QuickMenu.MenuButn(this, parent, text, action, tip);
      this.MenuBar = parent;
      pos = findAbsPos(this.Parent.Button);
      this.OuterDiv.style.left = pos.x + "px";
      this.OuterDiv.style.top = pos.y + this.Parent.Button.offsetHeight - 1 + "px";
    }

    this.Table.appendChild(this.TBody);
    this.Container.appendChild(this.Table);
    this.InnerDiv.appendChild(this.Container);
    this.OuterDiv.appendChild(this.Shadow);
    this.OuterDiv.appendChild(this.InnerDiv);
    document.body.appendChild(this.OuterDiv);
  },
  MenuItem : function (menu, text, action, icon, tip) {
    this.Parent = menu;
    this.TRow = document.createElement("TR");
    this.TRow.className = "qmenu-menuitem";
    this.TRow.ParentMenu = menu;

    this.LeftCell = document.createElement("TD");
    if (text) {
      if (action) {
        if (action.substring(0,3) == "js:") {
          this.TRow.Action = action.substring(3);
        } else if (action.substring(0,1) == ":") {
          this.TRow.Menu = menu[action.substring(1)] = new QuickMenu.Menu(this, "", ":");
        } else {
          this.TRow.Link = action;
        }
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
      this.RightCell.className = "qmenu-menuitem-" + (this.TRow.Menu ? "arrow" : "right");
      this.RightCell.appendChild(document.createTextNode(" "));
      if (tip) this.TRow.title = tip;
      this.TRow.appendChild(this.LeftCell);
      this.TRow.appendChild(this.MiddleCell);
      this.TRow.appendChild(this.RightCell);

      this.MouseOver = function () {
        clearTimeout(QuickMenu.Timer);
        QuickMenu.Timer = null;
        if (this.cells[0].className == "qmenu-menuitem-left-over") return;
        while (QuickMenu.ShownMenu != this.ParentMenu) QuickMenu.ShownMenu.Hide();
        this.cells[0].className = "qmenu-menuitem-left-over";
        this.cells[1].className = "qmenu-menuitem-middle-over";
        if (this.Menu) {
          this.cells[2].className = "qmenu-menuitem-arrow-over";
          this.Menu.Show();
        } else {
          this.cells[2].className = "qmenu-menuitem-right-over";
        }
      }
      this.MouseOut = function () {
        if (!this.Menu) {
          this.cells[0].className = "qmenu-menuitem-left";
          this.cells[1].className = "qmenu-menuitem-middle";
          this.cells[2].className = "qmenu-menuitem-right";
        }
        if (!QuickMenu.Timer && QuickMenu.ShownMenu)
          QuickMenu.Timer = setTimeout("QuickMenu.HideAll()", 1000);
      }
      this.MouseClick = function () {
        if (!this.Menu) QuickMenu.HideAll();
        if (this.Link) {
          window.location = this.Link;
        } else if (this.Action) {
          eval (this.Action);
        }
      }
      this.TRow.onmouseover = this.MouseOver;
      this.TRow.onmouseout = this.MouseOut;
      this.TRow.onclick = this.MouseClick;
    } else {
      this.Separator = document.createElement("TD");
      this.Separator.className = "qmenu-menuitem-separator";
      this.Separator.colSpan = 2;
      this.Separator.appendChild(document.createElement("DIV"));
      this.TRow.appendChild(this.LeftCell);
      this.TRow.appendChild(this.Separator);
    }
    menu.TBody.appendChild(this.TRow);
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
  var i = this.Items.length;
  this.Items[i] = new QuickMenu.MenuItem(this, text, action, icon, tip);
};

QuickMenu.Menu.prototype.Hide = function () {
  this.Shadow.style.visibility = "hidden";
  this.OuterDiv.style.visibility = "hidden";
  this.Shown = false;
  if (this.Parent.Button) {
    QuickMenu.ShownMenu = null;
  } else {
    this.Parent.LeftCell.className = "qmenu-menuitem-left";
    this.Parent.MiddleCell.className = "qmenu-menuitem-middle";
    this.Parent.RightCell.className = "qmenu-menuitem-" + (this.Parent.TRow.Menu ? "arrow" : "right");
    QuickMenu.ShownMenu = this.Parent.Parent;
  }
};

QuickMenu.Menu.prototype.Show = function () {
  QuickMenu.ShownMenu = this;
  if (this.Parent.Button) {
    pos = findAbsPos(this.Parent.Button);
    this.OuterDiv.style.left = pos.x + "px";
    this.OuterDiv.style.top = pos.y + this.Parent.Button.offsetHeight - 1 + "px";
  } else {
    pos = findAbsPos(this.Parent.TRow);
    this.OuterDiv.style.left = pos.x + this.Parent.TRow.offsetWidth + "px";
    this.OuterDiv.style.top = pos.y - 1 + "px";
  }
  this.OuterDiv.style.visibility = "visible";
  this.Shadow.style.width = this.OuterDiv.offsetWidth + "px";
  this.Shadow.style.height = this.OuterDiv.offsetHeight + "px";
  this.Shadow.style.visibility = "visible";
  this.Shown = true;
};

QuickMenu.User.v = navigator.userAgent.toLowerCase();
QuickMenu.User.Dom = document.getElementById ? 1 : 0;
QuickMenu.User.Ie = (QuickMenu.User.v.indexOf("msie 6") > -1 && QuickMenu.User.Dom) ? 1 : 0;
QuickMenu.User.Gecko = (QuickMenu.User.v.indexOf("gecko") > -1 && QuickMenu.User.Dom) ? 1 : 0;
QuickMenu.User.Safari = (QuickMenu.User.v.indexOf("safari") > -1 && QuickMenu.User.Dom) ? 1 : 0;
QuickMenu.User.Moz = (QuickMenu.User.Gecko && parseInt(navigator.productSub) > 20020512) ? 1 : 0;
QuickMenu.User.Dhtml = (QuickMenu.User.Ie || QuickMenu.User.Moz) ? 1 : 0;
