/*
   Copyright (C) 2005 ILOG http://www.ilog.fr
   and TWiki Contributors. All Rights Reserved. TWiki Contributors
   are listed in the AUTHORS file in the root of this distribution.
   NOTE: Please extend that file, not this notice.

   Portions Copyright (c) 2003-2004 Kupu Contributors. All rights reserved.

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.
  
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  
   As per the GPL, removal of this notice is prohibited.
*/

/*
 * TWiki-specific customisation of kupuinit.js
 */

function initKupu(iframe) {

    // first we create a logger
    var l = new PlainLogger('kupu-toolbox-debuglog', 20);
    
    // now some config values
    var conf = loadDictFromXML(document, 'kupuconfig');
    
    // the we create the document, hand it over the id of the iframe
    var doc = new KupuDocument(iframe);
    
    // now we can create the controller
    var kupu = new KupuEditor(doc, conf, l);

    var contextmenu = new ContextMenu();
    kupu.setContextMenu(contextmenu);

    // now we can create a UI object which we can use from the UI
    var ui = new KupuUI('kupu-tb-styles');

    // the ui must be registered to the editor like a tool so it can be notified
    // of state changes
    kupu.registerTool('ui', ui); // XXX Should this be a different method?

    // function that returns a function to execute a button command
    var execCommand = function(cmd) {
        return function(button, editor) {
            editor.execCommand(cmd);
        };
    };

    var boldchecker = ParentWithStyleChecker(new Array('b', 'strong'),
					     'font-weight', 'bold');
    var boldbutton = new KupuStateButton('kupu-bold-button', 
                                         execCommand('bold'),
                                         boldchecker,
                                         'kupu-bold',
                                         'kupu-bold-pressed');
    kupu.registerTool('boldbutton', boldbutton);

    var italicschecker = ParentWithStyleChecker(new Array('i', 'em'),
						'font-style', 'italic');
    var italicsbutton = new KupuStateButton('kupu-italic-button', 
                                           execCommand('italic'),
                                           italicschecker, 
                                           'kupu-italic', 
                                           'kupu-italic-pressed');
    kupu.registerTool('italicsbutton', italicsbutton);

    var codechecker = ParentWithStyleChecker(new Array('tt', 'code'),
						'font-family', 'monospaced');
    var codebutton = new KupuStateButton('twiki-code-button', 
                                         function (button,editor) {
                                           TWikiToggleTag(button, editor,
                                                          'code');
                                         },
                                         codechecker,
                                         'twiki-code-button', 
                                         'twiki-code-button-pressed');
    kupu.registerTool('codebutton', codebutton);

    var verbbutton = new TWikiVerbatimTool('twiki-verbatim-button');
    kupu.registerTool('verbbutton', verbbutton);

    // Icons tool
    var twikiiconstool = new TWikiIconsTool('twiki-icons-button', 
                                            'twiki-icons');
    kupu.registerTool('twikiicons', twikiiconstool);

    var twikinoptool = new TWikiNOPTool('twiki-nop-button');
    kupu.registerTool('twikinop', twikinoptool);

    var outdentbutton = new KupuButton('kupu-outdent-button', execCommand('outdent'));
    kupu.registerTool('outdentbutton', outdentbutton);

    var indentbutton = new KupuButton('kupu-indent-button', execCommand('indent'));
    kupu.registerTool('indentbutton', indentbutton);

    var undobutton = new KupuButton('kupu-undo-button', execCommand('undo'));
    kupu.registerTool('undobutton', undobutton);

    var redobutton = new KupuButton('kupu-redo-button', execCommand('redo'));
    kupu.registerTool('redobutton', redobutton);

    var removelinkbutton =
      new KupuRemoveElementButton('kupu-removelink-button',
                                  'a',
                                  'kupu-removelink');
    kupu.registerTool('removelinkbutton', removelinkbutton);

    // add some tools
    var colorchoosertool = new ColorchooserTool('kupu-forecolor-button',
                                                'kupu-hilitecolor-button',
                                                'kupu-colorchooser');
    kupu.registerTool('colorchooser', colorchoosertool);

    var listtool = new ListTool('kupu-list-ul-addbutton',
                                'kupu-list-ol-addbutton',
                                'kupu-ulstyles', 'kupu-olstyles');
    kupu.registerTool('listtool', listtool);
    
    var definitionlisttool = new DefinitionListTool('kupu-list-dl-addbutton');
    kupu.registerTool('definitionlisttool', definitionlisttool);
    
    // shows the path to the current element in the status bar
    var showpathtool = new ShowPathTool();
    kupu.registerTool('showpathtool', showpathtool);

    var sourceedittool = new SourceEditTool('kupu-source-button',
                                            'kupu-editor-textarea');
    kupu.registerTool('sourceedittool', sourceedittool);

    // Save button
    var savebutton = document.getElementById('kupu-save-button');
    function submitForm() {
      // can't use the TWikiHandleSubmit handler, because it doesn't
      // get called when submit() is used.
      var form = document.getElementById('twiki-main-form');
      // use prepareForm to create the 'text' field
      kupu.prepareForm(form, 'text');
      form.submit();
    };
    addEventHandler(savebutton, 'click', submitForm, kupu);

    var cancelbutton = document.getElementById('twiki-cancel-button');
    function cancelEdit() {
      var url = conf.cancel;
      window.document.location = conf.cancel;
    }
    addEventHandler(cancelbutton, 'click', cancelEdit, kupu);

    // Tools with Drawers...

    var drawertool = new DrawerTool();
    kupu.registerTool('drawertool', drawertool);

    // Function that returns function to open a drawer
    var opendrawer = function(drawerid) {
        return function(button, editor) {
            drawertool.openDrawer(drawerid);
        };
    };

    // Link drawer
    var linktool = new LinkTool();
    kupu.registerTool('linktool', linktool);

    var linkdrawerbutton = new KupuButton('kupu-linkdrawer-button',
                                          opendrawer('linkdrawer'));
    kupu.registerTool('linkdrawerbutton', linkdrawerbutton);

    var linkdrawer = new LinkDrawer('kupu-linkdrawer', linktool);
    drawertool.registerDrawer('linkdrawer', linkdrawer);

    // Table drawer
    var tabletool = new TableTool();
    kupu.registerTool('tabletool', tabletool);

    var tabledrawerbutton = new KupuButton('kupu-tabledrawer-button',
                                           opendrawer('tabledrawer'));
    kupu.registerTool('tabledrawerbutton', tabledrawerbutton);

    var tabledrawer = new TableDrawer('kupu-tabledrawer', tabletool);
    drawertool.registerDrawer('tabledrawer', tabledrawer);

    // WikiWord drawer
    var wikiwordtool = new TWikiWikiWordTool(linktool);
    kupu.registerTool('wikiwordtool', wikiwordtool);

    var wikiworddrawerbutton = new KupuButton('twiki-wikiworddrawer-button',
                                              opendrawer('wikiworddrawer'));
    kupu.registerTool('wikiworddrawerbutton', wikiworddrawerbutton);

    var wikiworddrawer = new TWikiPickListDrawer('twiki-wikiworddrawer',
                                                 'twiki-wikiword-select',
                                                 wikiwordtool);
    drawertool.registerDrawer('wikiworddrawer', wikiworddrawer);

    // Variables drawer
    var twikivartool = new TWikiVarTool();
    kupu.registerTool('twikivartool', twikivartool);

    var twikivardrawerbutton = new KupuButton('twiki-vardrawer-button',
                                              opendrawer('twikivardrawer'));
    kupu.registerTool('twikivardrawerbutton', twikivardrawerbutton);

    var twikivardrawer = new TWikiPickListDrawer('twiki-vardrawer',
                                                 'twiki-var-select',
                                                 twikivartool);
    drawertool.registerDrawer('twikivardrawer', twikivardrawer);

    // Attachments drawer
    var insertAttLinkTool = new TWikiInsertAttachmentTool();
    kupu.registerTool('insertattlink', insertAttLinkTool);

    var insertAttButton = new KupuButton('twiki-insert-attachment',
                                         opendrawer('insertAttDrawer'));
    kupu.registerTool('insertAttButton', insertAttButton);

    var insertAttDrawer = new TWikiPickListDrawer('twiki-insertatt-drawer',
                                               'twiki-insertatt-select',
                                               insertAttLinkTool);
    drawertool.registerDrawer('insertAttDrawer', insertAttDrawer);

    // New attachment drawer
    var newAttButton = new KupuButton('twiki-attach-button',
                                      opendrawer('newAttDrawer'));
    kupu.registerTool('newAttButton', newAttButton);

    var newAttDrawer =
      new TWikiNewAttachmentDrawer('twiki-new-attachment-drawer',
                                   'twiki-upload-form',
                                   'twiki-insertatt-select');
    drawertool.registerDrawer('newAttDrawer', newAttDrawer);

    /* Note: the XHTML filter is disabled, so that any non-XHTML
     * tags imported from the source are passed back out of the
     * editor. The expectationis that the post-processing will
     * deal with any unrecognised tags. */

    return kupu;
};
