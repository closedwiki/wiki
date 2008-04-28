// to please pattern skin < 4.2
function initTextAreaHeight () { }
function handleKeyDown () { }
var paneTop = -1;
var bottomBarHeight = -1;
var $tab;
function fixHeightOfPane() {
  if (typeof($tab) == 'undefined') {
    $tab = $(".jqTab:first .jqTabContents");
  }

  if (paneTop < 0) {
    var paneOffset = $tab.offset({
      scroll:false,
      border:true,
      padding:true,
      margin:true
    });
    if (typeof(paneOffset) == 'undefined') {
      return;
    }
    paneTop = paneOffset.top;
  }
  if (bottomBarHeight < 0) {
    bottomBarHeight = $(".natEditBottomBar").height();
  }

  var windowHeight = $(window).height();
  if (!windowHeight) {
    windowHeight = window.innerHeight; // woops, jquery, whats up, i.e. for konqueror
  }
  //alert ("windowHeight="+windowHeight);

  var height = windowHeight-paneTop-bottomBarHeight-70;

  var newTabSelector;
  if (typeof(newTab) == 'undefined') {
    newTabSelector = ".jqTab:visible";
  } else {
    newTabSelector = "#"+newTab;
  }

  // add new height to those containers, that don't have an natEditAutoMaxExpand element
  $(newTabSelector+" .jqTabContents").filter(function(index) { 
    return $(".natEditAutoMaxExpand", this).length == 0; 
  }).each(function() {
    $(this).height(height);
  });


  // add a slight timeout not to DoS IE 
  // before enabling handler again
  setTimeout(function() { 
    $(window).one("resize", fixHeightOfPane);
  }, 20);
}
