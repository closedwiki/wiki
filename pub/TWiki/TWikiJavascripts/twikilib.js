// TWiki namespace
var twiki;
if (!twiki) twiki = {};

twiki.getMetaTag = function(inKey) {
    if (twiki.metaTags == null || twiki.metaTags.length == 0) {
        // Do this the brute-force way because of the problem
        // seen sporadically on Bugs web where the DOM appears complete, but
        // the META tags are not all found by getElementsByTagName
        var head = document.getElementsByTagName("META");
        head = head[0].parentNode.childNodes;
        twiki.metaTags = new Array();
        for (var i = 0; i < head.length; i++) {
            if (head[i].tagName != null &&
                head[i].tagName.toUpperCase() == 'META') {
                twiki.metaTags[head[i].name] = head[i].content;
            }
        }
    }
    return twiki.metaTags[inKey]; 
};
