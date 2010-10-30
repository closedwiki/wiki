/*
ColorPicker - Copyright (c) 2004, 2005 Norman Timmler (inlet media e.K., Hamburg, Germany)
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the distribution.
3. The name of the author may not be used to endorse or promote products
   derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

cp_spacer_image = cp_basepath + 'spacer.gif';

cp_hexValues = Array('0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f');
cp_currentColor = '';
cp_parentInputElement = null;
cp_colorpickerbox_x = 0;
cp_colorpickerbox_y = 0;

document.onmousemove = function(evt) {
  cp_colorpickerbox_x = document.all ? event.clientX : document.layers ? evt.x : evt.clientX;
  cp_colorpickerbox_y = document.all ? event.clientY : document.layers ? evt.y : evt.clientY;
}

document.writeln("<style type=\"text/css\">");
document.writeln("#cp_colorpickerbox {position: absolute; top: 0px; left: 0px; visibility: hidden; border: 1px solid #000000; padding: 10px; \\width: 313px; w\\idth: 291px; \\height: 185px; he\\ight: 165px; background-color: #FFFFFF;z-index: 2000; }");
document.writeln("#cp_colorbox {position: absolute; overflow: hidden; \\border: 0px; b\\order: 1px solid #000000; top: 35px; left: 160px; font-size: 40px;}");
document.writeln("#cp_colorbox img {border: 0px; width: 128px; height: 15px;}");
document.writeln("#cp_spectrumbox {position: absolute; overflow: hidden; \\border: 0px; b\\order: 1px solid #000000; font-size: 40px;}");
document.writeln("#cp_spectrumbox img {border: 0px; width: 3px; height: 15px;}");
document.writeln("#cp_satbrightbox {position: absolute; overflow: hidden; \\border: 0px; b\\order: 1px solid #000000; top: 35px; left: 10px;}");
document.writeln("#cp_satbrightbox img {border: 0px; width: 8px; height: 8px;}");
document.writeln("#cp_hexvaluebox {position: absolute; border: 0px solid #000000; top: 70px; left: 160px; font-size: 15px;}");
document.writeln("#cp_hexvaluebox input {border: 1px solid #000000; width: 100px; font-family: font-size: 15px;}");
document.writeln("#cp_controlbox {position: absolute; border: 0px solid #000000; top: 120px;left: 210px;}");
document.writeln("#cp_controlbox input {border: 1px solid #000000; width: 78px; height: 18px; font-family: font-size: 10px; background-color: #FFFFFF;}");
document.writeln("</style>");

document.writeln("<div id=\"cp_colorpickerbox\">");
document.writeln("    <div id=\"cp_spectrumbox\">&nbsp;</div>");
document.writeln("    <div id=\"cp_satbrightbox\">&nbsp;</div>");
document.writeln("    <div id=\"cp_colorbox\"><img src=\"/images/spacer.gif\" /></div>");
document.writeln("    <div id=\"cp_hexvaluebox\">#<input type=\"text\" value=\"\" /></div>");
document.writeln("    <div id=\"cp_controlbox\"><input type=\"submit\" value=\"OK\" onclick=\"cp_ok();return false;\" /><br /><br /><input type=\"submit\" value=\"Cancel\" onclick=\"cp_hide();return false;\" /></div>");
document.writeln("</div>");

function cp_showSatBrightBox(col) {
  element = cp_getElementById('cp_satbrightbox');
  html = '';

  s = 16; // steps
  colEnd = Array();

  col[0] = 256 - col[0];
  col[1] = 256 - col[1];
  col[2] = 256 - col[2];


  // calculating row end points
  for (j = 0; j < 3; j++) {
    colEnd[j] = Array();
    for (i = s; i > -1; i--) {
      colEnd[j][i] =  i * Math.round(col[j] / s);
    }
  }

  hexStr = '';
  for (k = s; k > -1; k--) {
    for (i = s; i > -1; i--) {
      for (j = 0; j < 3; j++) {
        dif = 256 - colEnd[j][k];
        quot = (dif != 0) ? Math.round(dif / s) : 0;
        hexStr += cp_toHex(i * quot);
      }
      html += "<span style=\"background-color:#" +
        hexStr + ";\"><a href=\"#\" onclick=\"cp_showColorBox('" +
        hexStr + "');return false;\"><img src=\"" + cp_spacer_image + "\"/></a></span>";
      hexStr = '';
    }
    html += "<br />";
  }

  element.innerHTML = html;
}

function cp_showSpectrumBox() {
  element = cp_getElementById('cp_spectrumbox');
  html = '';

  d = 1; // direction
  c = 0; // count
  v = 0; // value
  s = 16; // steps
  col = Array(256, 0, 0); // color array [0] red, [1] green, [2] blue
  ind = 1; // index
  cel = 256; //ceiling

  while (c < (6 * 256)) {
    html += "<span style=\"background-color:#" + cp_toHex(col[0]) + cp_toHex(col[1]) + cp_toHex(col[2]) +
      "\"><a href=\"#\" onclick=\"cp_showSatBrightBox(Array(" +
      col[0] + "," + col[1] + "," + col[2] + "));return false;\"><img src=\"" + cp_spacer_image + "\" /></a></span>";

    c += s;
    v += (s * d);
    col[ind] = v;

    if (v == cel) {
      ind -= 1;
      if (ind == -1) ind = 2;
      d = d * -1;
    }

    if (v == 0) {
      ind += 2;
      if (ind == 3) ind = 0;
      d = d * -1;
    }
  }
  element.innerHTML = html;

  cp_showSatBrightBox(col);
}


function cp_toHex(num) {
  if (num > 0) num -= 1;
  base = num / 16;
  rem = num % 16;
  base = base - (rem / 16);
  return cp_hexValues[base] + cp_hexValues[rem];
}

function cp_showColorBox(hexStr){
  colorbox = cp_getElementById('cp_colorbox');
  colorboxhtml = "<span style=\"background-color:#" + hexStr + "\"><img src=\"" + cp_spacer_image + "\" /></span>";
  colorbox.innerHTML = colorboxhtml;

  hexvaluebox = cp_getElementById('cp_hexvaluebox');
  hexvalueboxhtml = "#<input type=\"text\" value=\"" + hexStr + "\" />";
  hexvaluebox.innerHTML = hexvalueboxhtml;

  cp_currentColor = hexStr;
}

function cp_show(parentInputElement) {
  cp_showSpectrumBox();


  parentInputElement = cp_getElementById(parentInputElement);

  element = cp_getElementById('cp_colorpickerbox');
  
  tmp = getAbsolutePos(parentInputElement);
  tmp.y += 20;

  element.style.left =  tmp.x+"px";
  element.style.top =  tmp.y+"px";
  element.style.visibility = 'visible';
  
  cp_parentInputElement = parentInputElement;

  return false;
}

function cp_ok() {
  cp_parentInputElement.value = "#" + cp_currentColor;
  cp_parentInputElement.style.background = "#" + cp_currentColor;
  cp_hide();
}

function cp_hide() {
  element = cp_getElementById('cp_colorpickerbox');
  element.style.visibility = 'hidden';
}

function cp_getElementById(e, f) {
  if (document.getElementById) {
    return document.getElementById(e);
  }
  if(document.all) {
     return document.all[e];
  }
}

function getAbsolutePos (el) {
        var SL = 0, ST = 0;
        var is_div = /^div$/i.test(el.tagName);
        if (is_div && el.scrollLeft)
                SL = el.scrollLeft;
        if (is_div && el.scrollTop)
                ST = el.scrollTop;
        var r = { x: el.offsetLeft - SL, y: el.offsetTop - ST };
        if (el.offsetParent) {
                var tmp = this.getAbsolutePos(el.offsetParent);
                r.x += tmp.x;
                r.y += tmp.y;
        }
        return r;
};

