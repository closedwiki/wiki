$.fn.extend({shrinkUrls:function(settings){settings=$.extend({whitespace:false,trunc:'tail'},settings||{});return this.each(function(){var text=$(this).text();if((text.length>settings.size)&&(!settings.include||text.match(settings.include))&&(!settings.exclude||!text.match(settings.exclude))&&(settings.whitespace||!text.match(/\s/))){var txtlength=text.length;var firstPart="";var lastPart="";var middlePart="";switch(settings.trunc){default:case'tail':firstPart=text.substring(0,settings.size-1);break;case'head':lastPart=text.substring(txtlength-settings.size+1,txtlength);break;case'middle':firstPart=text.substring(0,settings.size/2);lastPart=text.substring(txtlength-settings.size/2+1,txtlength);break;}
var origText=text;text=firstPart+"&hellip;"+lastPart;var title=$(this).attr('title');if(title){title+=' ('+origText+')';}else{title=origText;}
$(this).html(text).attr('title',title);}});}});;
