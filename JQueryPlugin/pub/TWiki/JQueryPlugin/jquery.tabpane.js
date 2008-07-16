(function($){$.fn.tabpane=function(options){writeDebug("called tabpane()");var opts=$.extend({},$.fn.tabpane.defaults,options);return this.each(function(){var $thisPane=$(this);var thisOpts=$.extend({},opts,$thisPane.data());var $tabContainer=$thisPane;var $tabGroup=$('<ul class="jqTabGroup"></ul>').prependTo($tabContainer);var index=1;var currentTabId;$thisPane.children(".jqTab").each(function(){var title=$('h2',this).eq(0).remove().text();$tabGroup.append('<li'+(index==thisOpts.select?' class="current"':'')+'><a href="javascript:void(0)" data="'+this.id+'">'+title+'</a></li>');if(index==thisOpts.select){currentTabId=this.id;$(this).addClass("current");}else{$(this).removeClass("current");}
index++;});switchTab(currentTabId,currentTabId,thisOpts);$(".jqTabGroup li > a",this).click(function(){$(this).blur();var newTabId=$(this).attr('data');if(newTabId!=currentTabId){$("#"+currentTabId).removeClass("current");$("#"+newTabId).addClass("current");$(this).parent().parent().children("li").removeClass("current");$(this).parent().addClass("current");switchTab(currentTabId,newTabId,thisOpts);currentTabId=newTabId;}
return false;});$thisPane.css("display","block");});};function switchTab(oldTabId,newTabId,thisOpts){writeDebug("switch from "+oldTabId+" to "+newTabId);var $newTab=$("#"+newTabId);if(!thisOpts[newTabId]){thisOpts[newTabId]=$newTab.data();}
var data=thisOpts[newTabId];if(typeof(data.beforeHandler)!="undefined"){var command="{ oldTab = '"+oldTabId+"'; newTab = '"+newTabId+"'; "+data.beforeHandler+";}";writeDebug("exec "+command);eval(command);}
if(typeof(data.url)!="undefined"){var container=data.container||'.jqTabContents';var $container=$newTab.find(container);writeDebug("loading "+data.url+" into "+container);if(typeof(data.afterLoadHandler)!="undefined"){var command="{ oldTab = '"+oldTabId+"'; newTab = '"+newTabId+"'; "+data.afterLoadHandler+";}";writeDebug("after load handler "+command);var func=new Function(command);$container.load(data.url,{},func);}else{$container.load(data.url);}
delete thisOpts[newTabId].url;}
if(typeof(data.afterHandler)!="undefined"){var command="{ oldTab = '"+oldTabId+"'; newTab = '"+newTabId+"'; "+data.afterHandler+";}";writeDebug("exec "+command);eval(command);}}
function writeDebug(msg){if($.fn.tabpane.defaults.debug){if(window.console&&window.console.log){window.console.log("DEBUG: TabPane - "+msg);}else{}}};$.fn.tabpane.defaults={debug:false,select:1};})(jQuery);;
