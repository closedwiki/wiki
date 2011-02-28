;(function($){function load(settings,root,child,container){function createNode(parent){var current=$("<li/>").attr("id",this.id||"").html("<span>"+this.text+"</span>").appendTo(parent);if(this.classes){current.children("span").addClass(this.classes);}
if(this.expanded){current.addClass("open");}
if(this.hasChildren||this.children&&this.children.length){var branch=$("<ul/>").appendTo(current);if(this.hasChildren){current.addClass("hasChildren");createNode.call({classes:"placeholder",text:"&nbsp;",children:[]},branch);}
if(this.children&&this.children.length){$.each(this.children,createNode,[branch])}}}
$.ajax($.extend(true,{url:settings.url,dataType:"json",data:{root:root},success:function(response){child.empty();$.each(response,createNode,[child]);$(container).treeview({add:child});}},settings.ajax));}
var proxied=$.fn.treeview;$.fn.treeview=function(settings){if(!settings.url){return proxied.apply(this,arguments);}
var container=this;if(!container.children().size())
load(settings,"source",this,container);var userToggle=settings.toggle;return proxied.call(this,$.extend({},settings,{collapsed:true,toggle:function(){var $this=$(this);if($this.hasClass("hasChildren")){var childList=$this.removeClass("hasChildren").find("ul");load(settings,this.id,childList,container);}
if(userToggle){userToggle.apply(this,arguments);}}}));};})(jQuery);;
