/*
 * jQuery Tabpane plugin 1.0
 *
 * Copyright (c) 2008 Michael Daum http://michaeldaumconsulting.com
 *
 * Dual licensed under the MIT and GPL licenses:
 *   http://www.opensource.org/licenses/mit-license.php
 *   http://www.gnu.org/licenses/gpl.html
 *
 * Revision: $Id$
 *
 */
(function($) {

  /***************************************************************************
   * plugin definition 
   */
  $.fn.tabpane = function(options) {
    writeDebug("called tabpane()");
   
    // build main options before element iteration
    var opts = $.extend({}, $.fn.tabpane.defaults, options);
   
    // iterate and reformat each matched element
    return this.each(function() {
 
      // build element specific options. 
      var thisOpt = $.extend({}, opts, $(this).data());

      // create tab group
      var $tabContainer = $(this);
      var $tabGroup = $('<ul class="jqTabGroup"></ul>').prependTo($tabContainer);

      // get all headings and create tabs
      var isFirstTab = 1;
      var currentTabId;
      $(this).children(".jqTab").each(function() {
        var title = $('h2', this).eq(0).remove().text();
        $tabGroup.append('<li'+(isFirstTab?' class="current"':'')+'><a href="javascript:void(0)" data="'+this.id+'">'+title+'</a></li>');
        if (isFirstTab) {
          isFirstTab = 0;
          currentTabId = this.id;
          $(this).addClass("current");
        } else {
          writeDebug("hiding "+this.id);
          $(this).removeClass("current");
        }
      });
      $(".jqTabGroup li > a", this).click(function() {
        $(this).blur();
        var newTabId = $(this).attr('data');
        if (newTabId != currentTabId) {
          writeDebug("switch from "+currentTabId+" to "+newTabId);

          var $currentTab = $("#"+currentTabId);
          var $newTab  = $("#"+newTabId);
          var data = $newTab.data();

          // before click handler
          if (typeof(data.beforeHandler) != "undefined") {
            var command = "{ var oldTab = '"+currentTabId+"'; var newTab = '"+newTabId+"'; "+data.beforeHandler+";}";
            writeDebug("exec "+command);
            //eval(command);
          }

          $(this).parent().parent().children("li").removeClass("current"); 
          $(this).parent().addClass("current"); 

          $currentTab.removeClass("current");
          $newTab.addClass("current");

          // after click handler
          if (typeof(data.afterHandler) != "undefined") {
            var command = "{ var oldTab = '"+currentTabId+"'; var newTab = '"+newTabId+"'; "+data.afterHandler+";}";
            writeDebug("exec "+command);
            eval(command);
          }

          currentTabId = newTabId;
        }
        return false;
      });
      $(this).css("display", "block"); // show() does not work in some browsers :(
    });
  };

  /***************************************************************************
   * private function for debugging using the firebug console
   */
  function writeDebug(msg) {
    if ($.fn.tabpane.defaults.debug) {
      if (window.console && window.console.log) {
        window.console.log("DEBUG: TabPane - "+msg);
      } else {
        alert(msg);
      }
    }
  };
 
  /***************************************************************************
   * plugin defaults
   */
  $.fn.tabpane.defaults = {
    debug: false
  };
})(jQuery);
