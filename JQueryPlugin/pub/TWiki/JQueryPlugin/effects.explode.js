(function($){$.effects.explode=function(o){return this.queue(function(){var rows=o.options.pieces?Math.round(Math.sqrt(o.options.pieces)):3;var cells=o.options.pieces?Math.round(Math.sqrt(o.options.pieces)):3;o.options.mode=o.options.mode=='toggle'?($(this).is(':visible')?'hide':'show'):o.options.mode;var el=$(this).show().css('visibility','hidden');var offset=el.offset();offset.top-=parseInt(el.css("marginTop"))||0;offset.left-=parseInt(el.css("marginLeft"))||0;var width=el.outerWidth(true);var height=el.outerHeight(true);for(var i=0;i<rows;i++){for(var j=0;j<cells;j++){el
.clone()
.appendTo('body')
.wrap('<div></div>')
.css({position:'absolute',visibility:'visible',left:-j*(width/cells),top:-i*(height/rows)})
.parent()
.addClass('effects-explode')
.css({position:'absolute',overflow:'hidden',width:width/cells,height:height/rows,left:offset.left+j*(width/cells)+(o.options.mode=='show'?(j-Math.floor(cells/2))*(width/cells):0),top:offset.top+i*(height/rows)+(o.options.mode=='show'?(i-Math.floor(rows/2))*(height/rows):0),opacity:o.options.mode=='show'?0:1}).animate({left:offset.left+j*(width/cells)+(o.options.mode=='show'?0:(j-Math.floor(cells/2))*(width/cells)),top:offset.top+i*(height/rows)+(o.options.mode=='show'?0:(i-Math.floor(rows/2))*(height/rows)),opacity:o.options.mode=='show'?1:0},o.duration||500);}}
setTimeout(function(){o.options.mode=='show'?el.css({visibility:'visible'}):el.css({visibility:'visible'}).hide();if(o.callback)o.callback.apply(el[0]);el.dequeue();$('.effects-explode').remove();},o.duration||500);});};})(jQuery);;
