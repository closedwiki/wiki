// Override of initKupu for TWiki editing

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

    // add the buttons to the toolbar
    var savebuttonfunc = function(button, editor) {editor.saveDocument()};
    var savebutton = new KupuButton('kupu-save-button', savebuttonfunc);
    kupu.registerTool('savebutton', savebutton);

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

    var underlinechecker = ParentWithStyleChecker(new Array('u'));
    var underlinebutton = new KupuStateButton('kupu-underline-button', 
                                              execCommand('underline'),
                                              underlinechecker,
                                              'kupu-underline', 
                                              'kupu-underline-pressed');
    kupu.registerTool('underlinebutton', underlinebutton);

    // Icons tool
    var twikiiconstool = new TWikiIconsTool('twiki-icons-button', 
                                            'twiki-icons');
    kupu.registerTool('twikiicons', twikiiconstool);

    var outdentbutton = new KupuButton('kupu-outdent-button', execCommand('outdent'));
    kupu.registerTool('outdentbutton', outdentbutton);

    var indentbutton = new KupuButton('kupu-indent-button', execCommand('indent'));
    kupu.registerTool('indentbutton', indentbutton);

    var undobutton = new KupuButton('kupu-undo-button', execCommand('undo'));
    kupu.registerTool('undobutton', undobutton);

    var redobutton = new KupuButton('kupu-redo-button', execCommand('redo'));
    kupu.registerTool('redobutton', redobutton);

    var removelinkbutton = new KupuRemoveElementButton('kupu-removelink-button',
						       'a',
						       'kupu-removelink');
    kupu.registerTool('removelinkbutton', removelinkbutton);

    // add some tools
    // XXX would it be better to pass along elements instead of ids?
    var colorchoosertool = new ColorchooserTool('kupu-forecolor-button',
                                                'kupu-forecolor-button',
                                                'kupu-colorchooser');
    kupu.registerTool('colorchooser', colorchoosertool);

    var listtool = new ListTool('kupu-list-ul-addbutton',
                                'kupu-list-ol-addbutton',
                                'kupu-ulstyles', 'kupu-olstyles');
    kupu.registerTool('listtool', listtool);
    
    var definitionlisttool = new DefinitionListTool('kupu-list-dl-addbutton');
    kupu.registerTool('definitionlisttool', definitionlisttool);
    
    var zoom = new KupuZoomTool('kupu-zoom-button');
    kupu.registerTool('zoomtool', zoom);

    var showpathtool = new ShowPathTool();
    kupu.registerTool('showpathtool', showpathtool);

    var newAttachmentTool = new TWikiNewAttachmentTool('twiki-attach-button');
    kupu.registerTool('newattachmenttool', newAttachmentTool);

    var sourceedittool = new SourceEditTool('kupu-source-button',
                                            'kupu-editor-textarea');
    kupu.registerTool('sourceedittool', sourceedittool);

    // register some cleanup filter
    // remove tags that aren't in the XHTML DTD
    var nonxhtmltagfilter = new NonXHTMLTagFilter();
    kupu.registerFilter(nonxhtmltagfilter);

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
    /*
    var tableUI = new TableToolBox('kupu-toolbox-addtable', 
        'kupu-toolbox-edittable', 'kupu-table-newrows', 'kupu-table-newcols',
        'kupu-table-makeheader', 'kupu-table-classchooser', 'kupu-table-alignchooser',
        'kupu-table-addtable-button', 'kupu-table-addrow-button', 'kupu-table-delrow-button', 
        'kupu-table-addcolumn-button', 'kupu-table-delcolumn-button', 
        'kupu-table-fix-button', 'kupu-table-fixall-button', 'kupu-toolbox-tables',
        'kupu-toolbox', 'kupu-toolbox-active'
        );
    tabletool.registerToolBox('tabletoolbox', tableUI);
    */

    var tabledrawerbutton = new KupuButton('kupu-tabledrawer-button',
                                           opendrawer('tabledrawer'));
    kupu.registerTool('tabledrawerbutton', tabledrawerbutton);

    var tabledrawer = new TableDrawer('kupu-tabledrawer', tabletool);
    drawertool.registerDrawer('tabledrawer', tabledrawer);

    // WikiWord drawer
    var wikiwordtool = new TWikiWikiWordTool();
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
    var twikiattachmenttool = new TWikiInsertAttachmentTool();
    kupu.registerTool('attachmentlisttool', twikiattachmenttool);

    var attachdrawerbutton = new KupuButton('twiki-attachdrawer-button',
                                            opendrawer('attachdrawer'));
    kupu.registerTool('attachdrawerbutton', attachdrawerbutton);

    var attachdrawer = new TWikiPickListDrawer('twiki-attachdrawer',
                                               'twiki-attach-select',
                                               twikiattachmenttool);
    drawertool.registerDrawer('attachdrawer', attachdrawer);

    return kupu;
};
