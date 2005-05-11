// Override of initKupu for TWiki editing

function initKupu(iframe) {

    // first we create a logger
    var l = new PlainLogger('kupu-toolbox-debuglog', 5);
    
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

    //var subscriptchecker = ParentWithStyleChecker(new Array('sub'));
    //var subscriptbutton = new KupuStateButton('kupu-subscript-button',
    //                                          execCommand('subscript'),
    //                                          subscriptchecker,
    //                                          'kupu-subscript',
    //                                          'kupu-subscript-pressed');
    //kupu.registerTool('subscriptbutton', subscriptbutton);

    //var superscriptchecker = ParentWithStyleChecker(new Array('super', 'sup'));
    //var superscriptbutton = new KupuStateButton('kupu-superscript-button', 
    //                                            execCommand('superscript'),
    //                                            superscriptchecker,
    //                                            'kupu-superscript', 
    //                                            'kupu-superscript-pressed');
    //kupu.registerTool('superscriptbutton', superscriptbutton);

    var justifyleftbutton = new KupuButton('kupu-justifyleft-button',
                                           execCommand('justifyleft'));
    // TWiki: kupu.registerTool('justifyleftbutton', justifyleftbutton);

    var justifycenterbutton = new KupuButton('kupu-justifycenter-button',
                                             execCommand('justifycenter'));
    // TWiki: kupu.registerTool('justifycenterbutton', justifycenterbutton);

    var justifyrightbutton = new KupuButton('kupu-justifyright-button',
                                            execCommand('justifyright'));
    // TWiki: kupu.registerTool('justifyrightbutton', justifyrightbutton);

    var outdentbutton = new KupuButton('kupu-outdent-button', execCommand('outdent'));
    kupu.registerTool('outdentbutton', outdentbutton);

    var indentbutton = new KupuButton('kupu-indent-button', execCommand('indent'));
    kupu.registerTool('indentbutton', indentbutton);

    var undobutton = new KupuButton('kupu-undo-button', execCommand('undo'));
    kupu.registerTool('undobutton', undobutton);

    var redobutton = new KupuButton('kupu-redo-button', execCommand('redo'));
    kupu.registerTool('redobutton', redobutton);

    //var removeimagebutton = new KupuRemoveElementButton('kupu-removeimage-button',
	//						'img',
	//						'kupu-removeimage');
    //kupu.registerTool('removeimagebutton', removeimagebutton);
    var removelinkbutton = new KupuRemoveElementButton('kupu-removelink-button',
						       'a',
						       'kupu-removelink');
    kupu.registerTool('removelinkbutton', removelinkbutton);

    // add some tools
    // XXX would it be better to pass along elements instead of ids?
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
    
    // TWIKI: There is no properties UI
    //var proptool = new PropertyTool('kupu-properties-title', 'kupu-properties-description');
    //kupu.registerTool('proptool', proptool);

    var linktool = new LinkTool();
    kupu.registerTool('linktool', linktool);
    var linkUI = new LinkToolBox("kupu-link-input", "kupu-link-button", 'kupu-toolbox-links', 'kupu-toolbox', 'kupu-toolbox-active');
    linktool.registerToolBox('linktoolbox', linkUI);

    var zoom = new KupuZoomTool('kupu-zoom-button');
    kupu.registerTool('zoomtool', zoom);

    var imagetool = new ImageTool();
    kupu.registerTool('imagetool', imagetool);
    var imageUI = new ImageToolBox('kupu-image-input', 'kupu-image-addbutton', 
                                        'kupu-image-float-select', 'kupu-toolbox-images', 
                                          'kupu-toolbox', 'kupu-toolbox-active');
    // TWIKI: there is no image toolbox
    // imagetool.registerToolBox('imagetoolbox', imageUI);

    var tabletool = new TableTool();
    kupu.registerTool('tabletool', tabletool);
    var tableUI = new TableToolBox('kupu-toolbox-addtable', 
        'kupu-toolbox-edittable', 'kupu-table-newrows', 'kupu-table-newcols',
        'kupu-table-makeheader', 'kupu-table-classchooser', 'kupu-table-alignchooser',
        'kupu-table-addtable-button', 'kupu-table-addrow-button', 'kupu-table-delrow-button', 
        'kupu-table-addcolumn-button', 'kupu-table-delcolumn-button', 
        'kupu-table-fix-button', 'kupu-table-fixall-button', 'kupu-toolbox-tables',
        'kupu-toolbox', 'kupu-toolbox-active'
        );
    tabletool.registerToolBox('tabletoolbox', tableUI);

    var showpathtool = new ShowPathTool();
    kupu.registerTool('showpathtool', showpathtool);

    var sourceedittool = new SourceEditTool('kupu-source-button',
                                            'kupu-editor-textarea');
    kupu.registerTool('sourceedittool', sourceedittool);

    // Drawers...

    // Function that returns function to open a drawer
    var opendrawer = function(drawerid) {
        return function(button, editor) {
            drawertool.openDrawer(drawerid);
        };
    };

    //var imagelibdrawerbutton = new KupuButton('kupu-imagelibdrawer-button',
    //                                          opendrawer('imagelibdrawer'));
    //kupu.registerTool('imagelibdrawerbutton', imagelibdrawerbutton);

    var linklibdrawerbutton = new KupuButton('kupu-linklibdrawer-button',
                                             opendrawer('linklibdrawer'));
    kupu.registerTool('linklibdrawerbutton', linklibdrawerbutton);

    var linkdrawerbutton = new KupuButton('kupu-linkdrawer-button',
                                          opendrawer('linkdrawer'));
    kupu.registerTool('linkdrawerbutton', linkdrawerbutton);

    var tabledrawerbutton = new KupuButton('kupu-tabledrawer-button',
                                           opendrawer('tabledrawer'));
    kupu.registerTool('tabledrawerbutton', tabledrawerbutton);

    // create some drawers, drawers are some sort of popups that appear when a 
    // toolbar button is clicked
    var drawertool = new DrawerTool();
    kupu.registerTool('drawertool', drawertool);

    try {
        var linklibdrawer = new LinkLibraryDrawer(linktool, 
                                                  conf['link_xsl_uri'],
                                                  conf['link_libraries_uri'],
                                                  conf['link_images_uri']);
        drawertool.registerDrawer('linklibdrawer', linklibdrawer);

        var imagelibdrawer = new ImageLibraryDrawer(imagetool, 
                                                    conf['image_xsl_uri'],
                                                    conf['image_libraries_uri'],
                                                    conf['search_images_uri']);
        drawertool.registerDrawer('imagelibdrawer', imagelibdrawer);
    } catch(e) {
        alert('There was a problem initializing the drawers. Most likely the ' +
                'XSLT or XML files aren\'t available. If this is not the ' +
                'Kupu demo version, check your files or the service that ' +
                'provide them (error: ' + (e.message || e.toString()) + ').');
    };

    var linkdrawer = new LinkDrawer('kupu-linkdrawer', linktool);
    drawertool.registerDrawer('linkdrawer', linkdrawer);

    var tabledrawer = new TableDrawer('kupu-tabledrawer', tabletool);
    drawertool.registerDrawer('tabledrawer', tabledrawer);

    //var cleanupexpressions = new CleanupExpressionsTool(
    //        'kupucleanupexpressionselect', 'kupucleanupexpressionbutton');
    //kupu.registerTool('cleanupexpressions', cleanupexpressions);

    // register some cleanup filter
    // remove tags that aren't in the XHTML DTD
    var nonxhtmltagfilter = new NonXHTMLTagFilter();
    kupu.registerFilter(nonxhtmltagfilter);

    // TWiki specific tools

    var twikiiconstool = new TWikiIconsTool('twiki-icons-button', 
                                             'twiki-icons');
    kupu.registerTool('twikiicons', twikiiconstool);

    var twikivartool = new TWikiVarTool();
    kupu.registerTool('twikivartool', twikivartool);
    var twikivarUI = new TWikiVarUI('twiki-var-select', 'twiki-var-button', 
                                    'kupu-toolbox', 'kupu-toolbox-active');
    twikivartool.registerToolBox('twikivarUI', twikivarUI);

    var wikiwordtool = new TWikiWikiWordTool();
    kupu.registerTool('wikiwordtool', wikiwordtool);

    var wikiwordUI = new TWikiWikiWordUI('wiki-word-select', 'wiki-word-button');
    wikiwordtool.registerToolBox('wikiwordUI', wikiwordUI);

    var attachtool = new TWikiAttachTool();
    kupu.registerTool('attachtool', attachtool);

    var attachUI = new TWikiAttachUI('twiki-attach-file', 'twiki-attach-button');
    attachtool.registerToolBox('attachUI', attachUI);

    return kupu;
};
