function startKupu() {
    // initialize the editor, initKupu groks 1 arg, a reference to the iframe
    var frame = document.getElementById('kupu-editor');
    var kupu = initKupu(frame);

    // this makes the editor's content_changed attribute set according to changes
    // in a textarea or input (registering onchange, see saveOnPart() for more
    // details)
    kupu.registerContentChanger(document.getElementById('kupu-editor-textarea'));

    // Note: no registration of saveOnPart

    // and now we can initialize...
    kupu.initialize();

    return kupu;
};
