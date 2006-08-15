// (c)opyright 2006 MichaelDaum@WikiRing.com
function writeEmailAddrs(addrs, linkText, id) {
  var elem = document.getElementById(id);
  if (elem) {
    if (elem.firstChild) {
      elem.removeChild(elem.firstChild);
    }

    var anchor = document.createElement("a");
    elem.appendChild(anchor);

    anchor.href = 'mailto:';

    for (var i = 0; i < addrs.length; i++) {
      anchor.href += addrs[i][1] + '@' + addrs[i][0] + '.' + addrs[i][2];
      if (i < addrs.length-1) {
	anchor.href += ', ';
      }
    }

    if (linkText == '') {
      for (var i = 0; i < addrs.length; i++) {
	linkText += addrs[i][1] + '@' + addrs[i][0] + '.' + addrs[i][2] + ' ';
      }
    }
    var anchorText = document.createTextNode(linkText);
    anchor.appendChild(anchorText);
  }
}

addLoadEvent(initObfuscator);
