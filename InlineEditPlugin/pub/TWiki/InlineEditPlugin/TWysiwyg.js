/*==============================================================================
This Wikiwyg mode supports a DesignMode wysiwyg editor with toolbar buttons

COPYRIGHT:

    Copyright (c) 2005 Socialtext Corporation 
    655 High Street
    Palo Alto, CA 94301 U.S.A.
    All rights reserved.

Wikiwyg is free software. 

This library is free software; you can redistribute it and/or modify it
under the terms of the GNU Lesser General Public License as published by
the Free Software Foundation; either version 2.1 of the License, or (at
your option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser
General Public License for more details.

    http://www.gnu.org/copyleft/lesser.txt

 =============================================================================*/

proto = new Subclass('Wikiwyg.TWysiwyg', 'Wikiwyg.Wysiwyg');

proto.classtype = 'twysiwyg';
proto.modeDescription = 'TWysiwyg';


proto.config = {
    useParentStyles: true,
    useStyleMedia: 'wikiwyg',
    iframeId: null,
    iframeObject: null,
    disabledToolbarButtons: [],
    editHeightMinimum: 150,
    editHeightAdjustment: 1.3,
    clearRegex: null
};
    
proto.initializeObject = function() {
    this._inner_html = null;
    this.edit_iframe = this.get_edit_iframe();
    this.div = this.edit_iframe;
    this.set_design_mode_early();
}

proto.set_design_mode_early = function() { // Se IE, below
    // Unneeded for Gecko
}

proto.fromHtml = function(html) {
    //this.set_inner_html(html);
    // if html is empty, get it from server
    if (!this._inner_html) {

//	var twiki_topic_url = '/cgi-bin/UltiWiki/bin/view/Main/WebHome?skin=kupu';
	var twiki_topic_url = "http://localhost/cgi-bin/UltiWiki/bin/rest/MiniEditPlugin/getTopic?show=Main.WebHome";

                        var xmlhttp=false;
                        /*@cc_on @*/
                        /*@if (@_jscript_version >= 5)
                        // JScript gives us Conditional compilation, we can cope with old IE versions.
                        // and security blocked creation of the objects.
                        try {
                            xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");
                        } catch (e) {
                        try {
                            xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
                        } catch (E) {
                            xmlhttp = false;
                        }
                        }
                        @end @*/
                        if (!xmlhttp && typeof XMLHttpRequest!='undefined') {
                            xmlhttp = new XMLHttpRequest();
                        }

			xmlhttp.open('GET', twiki_topic_url,true);
			xmlhttp.parentObj = this;
				xmlhttp.onreadystatechange=function() {
				if (xmlhttp.readyState==4) {
					xmlhttp.parentObj._inner_html =  xmlhttp.responseText;
					xmlhttp.parentObj.wikiwyg.html =  xmlhttp.responseText;
    					xmlhttp.parentObj.set_inner_html(xmlhttp.parentObj.wikiwyg.html);
				}
			}
			xmlhttp.send(null)
	
    } else {
    	this.set_inner_html(html);
    }
}

proto.toHtml = function(func) {
    func(this.get_inner_html())
}

// This is needed to work around the broken IMGs in Firefox design mode.
// Works harmlessly on IE, too.
// TODO - IMG URLs that don't match /^\//
proto.fix_up_relative_imgs = function() {
    var base = location.href.replace(/(.*?:\/\/.*?\/).*/, '$1');
    var imgs = this.get_edit_document().getElementsByTagName('img');
    for (var ii = 0; ii < imgs.length; ++ii)
        imgs[ii].src = imgs[ii].src.replace(/^\//, base);
}

proto.enableThis = function() {
    this.superfunc('enableThis').call(this);
    this.edit_iframe.style.border = '1px black solid';
    this.edit_iframe.width = '100%';
    this.setHeightOf(this.edit_iframe);
    this.fix_up_relative_imgs();
    this.get_edit_document().designMode = 'on';
    this.apply_stylesheets();
    this.enable_keybindings();
    this.clear_inner_html();
}

proto.clear_inner_html = function() {
    var inner_html = this.get_inner_html();
    var clear = this.config.clearRegex;
    if (clear && inner_html.match(clear))
        this.set_inner_html('');
}

proto.get_keybinding_area = function() {
    return this.get_edit_document();
}

proto.get_edit_iframe = function() {
    var iframe;
    if (this.config.iframeId) {
        iframe = document.getElementById(this.config.iframeId);
        iframe.iframe_hack = true;
    }
    else if (this.config.iframeObject) {
        iframe = this.config.iframeObject;
        iframe.iframe_hack = true;
    }
    else {
        // XXX in IE need to wait a little while for iframe to load up
        iframe = document.createElement('iframe');
    }
    return iframe;
}

proto.get_edit_window = function() { // See IE, below
    return this.edit_iframe.contentWindow;
}

proto.get_edit_document = function() { // See IE, below
    return this.get_edit_window().document;
}

proto.get_inner_html = function() {
    return this.get_edit_document().body.innerHTML;
}
proto.set_inner_html = function(html) {
    this.get_edit_document().body.innerHTML = html;
}

proto.apply_stylesheets = function(styles) {
    var styles = document.styleSheets;
    var head   = this.get_edit_document().getElementsByTagName("head")[0];

    for (var i = 0; i < styles.length; i++) {
        var style = styles[i];

        if (style.href == location.href)
            this.apply_inline_stylesheet(style, head);
        else
            if (this.should_link_stylesheet(style))
                this.apply_linked_stylesheet(style, head);
    }
}

proto.apply_inline_stylesheet = function(style, head) {
    // TODO: figure this out
}

proto.should_link_stylesheet = function(style, head) {
        var media = style.media;
        var config = this.config;
        var media_text = media.mediaText ? media.mediaText : media;
        var use_parent =
             ((!media_text || media_text == 'screen') &&
             config.useParentStyles);
        var use_style = (media_text && (media_text == config.useStyleMedia));
        if (!use_parent && !use_style) // TODO: simplify
            return false;
        else
            return true;
}

proto.apply_linked_stylesheet = function(style, head) {
    var link = Wikiwyg.createElementWithAttrs(
        'link', {
            href:  style.href,
            type:  style.type,
            media: 'screen',
            rel:   'STYLESHEET'
        }, this.get_edit_document()
    );
    head.appendChild(link);
}

proto.process_command = function(command) {
    if (this['do_' + command])
        this['do_' + command](command);
    if (! Wikiwyg.is_ie)
        this.get_edit_window().focus();
}

proto.exec_command = function(command, option) {
    this.get_edit_document().execCommand(command, false, option);
}

proto.format_command = function(command) {
    this.exec_command('formatblock', '<' + command + '>');
}

proto.do_bold = proto.exec_command;
proto.do_italic = proto.exec_command;
proto.do_underline = proto.exec_command;
proto.do_strike = function() {
    this.exec_command('strikethrough');
}
proto.do_hr = function() {
    this.exec_command('inserthorizontalrule');
}
proto.do_ordered = function() {
    this.exec_command('insertorderedlist');
}
proto.do_unordered = function() {
    this.exec_command('insertunorderedlist');
}
proto.do_indent = proto.exec_command;
proto.do_outdent = proto.exec_command;

proto.do_h1 = proto.format_command;
proto.do_h2 = proto.format_command;
proto.do_h3 = proto.format_command;
proto.do_h4 = proto.format_command;
proto.do_h5 = proto.format_command;
proto.do_h6 = proto.format_command;
proto.do_pre = proto.format_command;
proto.do_p = proto.format_command;

proto.do_table = function() {
    var html =
        '<table><tbody>' +
        '<tr><td>A</td>' +
            '<td>B</td>' +
            '<td>C</td></tr>' +
        '<tr><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>' +
        '<tr><td>&nbsp;</td><td>&nbsp;</td><td>&nbsp;</td></tr>' +
        '</tbody></table>';
    this.insert_table(html);
}

proto.insert_table = function(html) { // See IE
    this.get_edit_window().focus();
    this.exec_command('inserthtml', html);
}

proto.do_unlink = proto.exec_command;

proto.do_link = function() {
    var selection = this.get_link_selection_text();
    if (! selection) return;
    var url;
    var match = selection.match(/(.*?)\b((?:http|https|ftp|irc):\/\/\S+)(.*)/);
    if (match) {
        if (match[1] || match[3]) return null;
        url = match[2];
    }
    else {
        url = '?' + escape(selection); 
    }
    this.exec_command('createlink', url);
}

proto.get_selection_text = function() { // See IE, below
    return this.get_edit_window().getSelection().toString();
}

proto.get_link_selection_text = function() {
    var selection = this.get_selection_text();
    if (! selection) {
        alert("Please select the text you would like to turn into a link.");
        return;
    }
    return selection;
}

/*==============================================================================
Support for Internet Explorer in Wikiwyg.Wysiwyg
 =============================================================================*/
if (Wikiwyg.is_ie) {

proto.set_design_mode_early = function(wikiwyg) {
    // XXX - need to know if iframe is ready yet...
    this.get_edit_document().designMode = 'on';
}

proto.get_edit_window = function() {
    return this.edit_iframe;
}

proto.get_edit_document = function() {
    return this.edit_iframe.contentWindow.document;
}

proto.get_selection_text = function() {
    var selection = this.get_edit_document().selection;
    if (selection != null)
        return selection.createRange().htmlText;
    return '';
}

proto.insert_table = function(html) {
    var doc = this.get_edit_document();
    var range = this.get_edit_document().selection.createRange();
    if (range.boundingTop == 2 && range.boundingLeft == 2)
        return;
    range.pasteHTML(html);
    range.collapse(false);
    range.select();
}

// Use IE's design mode default key bindings for now.
proto.enable_keybindings = function() {}

} // end of global if
