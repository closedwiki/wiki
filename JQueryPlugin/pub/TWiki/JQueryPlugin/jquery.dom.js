$.create=function(){if(arguments.length==0){return[];}
var first_arg=arguments[0];if(first_arg==null){first_arg="";}
if(first_arg.constructor==String){if(arguments.length>1){var second_arg=arguments[1];if(second_arg.constructor==String){var elt=document.createTextNode(first_arg);var elts=[];elts.push(elt);var siblings=$.create.apply(null,Array.prototype.slice.call(arguments,1));elts=elts.concat(siblings);return elts;}else{var elt=document.createElement(first_arg);var attributes=arguments[1];for(var attr in attributes){$(elt).attr(attr,attributes[attr]);}
var children=arguments[2];children=$.create.apply(null,children);$(elt).append(children);if(arguments.length>3){var siblings=$.create.apply(null,Array.prototype.slice.call(arguments,3));return[elt].concat(siblings);}
return elt;}}else{return document.createTextNode(first_arg);}}else{var elts=[];elts.push(first_arg);var siblings=$.create.apply(null,(Array.prototype.slice.call(arguments,1)));elts=elts.concat(siblings);return elts;}};
