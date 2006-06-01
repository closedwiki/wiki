/*
# Plugin for TWiki Collaboration Platform, http://TWiki.org/
#
# Copyright (C) 2005 Sven Dowideit SvenDowideit@wikiring.com
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
*/

// not editor object created..
initialiseInlineEditDiv = function(topicSectionObject) {
    return;
}

//TODO: change it to re-size dependant on the number of lines in the textarea.. with minimum


//Called by inlineEdit generic functions
//please define in such a way that it initiates edit mode on the specifed section
function gotoEditMode(topicSectionObject) {
    topicSectionObject.modified = 1;    //TODO: make sure there really is a change..

    if ( typeof( topicSectionObject.editDivSection ) == "undefined" ) {
        var newForm = document.createElement('FORM');
        newForm.topicSectionObject = topicSectionObject;
        newForm.name = "componenteditpluginform";
        newForm.method = "post";
        newForm.action = topicSectionObject.HTMLdiv.parentNode.action;

        var numberOfLines = topicSectionObject.TMLdiv.innerHTML.split("\n").length;
        if (numberOfLines < 4) {numberOfLines = 4};
        if (numberOfLines > 12) {numberOfLines = 12};

        var innerHTML = '<textarea id="componentedittextarea" name="text" width="99%" rows="'+numberOfLines+'">COMPONENTEDITPLUGINTML</textarea>';

        newForm.innerHTML = innerHTML;
        newForm.elements.namedItem("text").value = topicSectionObject.TMLdiv.innerHTML;
        newForm.elements.namedItem("text").topicSection =topicSectionObject.topicSection;
        topicSectionObject.HTMLdiv.parentNode.insertBefore(newForm, topicSectionObject.HTMLdiv);
        topicSectionObject.editDivSection = newForm;//TODO:this is supposed to be a div element

        //TODO: ***************************************make sure we're using this everwhere we should
        if (( typeof( getComputedStyle ) != "undefined" )) {
            //forks for firefox
            var s = getComputedStyle(topicSectionObject.HTMLdiv, "");
//            topicSectionObject.editDivSection.elements.namedItem("text").style.height = s.height;
            topicSectionObject.editDivSection.elements.namedItem("text").style.width = s.width;
        } else {
            //IE
//            topicSectionObject.editDivSection.elements.namedItem("text").style.height = topicSectionObject.HTMLdiv.offsetHeight;
            topicSectionObject.editDivSection.elements.namedItem("text").style.width = topicSectionObject.HTMLdiv.offsetWidth;
        }
    }

    topicSectionObject.editDivSection.style.display='inline';
    topicSectionObject.HTMLdiv.style.display='none';
}

hideEdit = function(topicSectionObject) {
    topicSectionObject.editDivSection.style.display='none';
    topicSectionObject.HTMLdiv.style.display='inline';
}

getSaveData = function(topicSectionObject) {
    var serialzationObj = {};

    serialzationObj.topicSection = topicSectionObject.editDivSection.elements.namedItem("text").topicSection;
    serialzationObj.value = topicSectionObject.editDivSection.elements.namedItem("text").value;
    if (topicSectionObject.newSection) {
        //make a real section of it
        serialzationObj.value = "\n\n"+serialzationObj.value+"\n\n";
    }
    return serialzationObj.toJSONString();

//TODO: recode as object so each editor sends the object it thinks it should
    if (topicSectionObject.newSection) {
        //make a real section of it
        topicSectionObject.editDivSection.elements.namedItem("text").value = "\n\n"+topicSectionObject.editDivSection.elements.namedItem("text").value+"\n\n";
    }
    return topicSectionObject.editDivSection.elements.namedItem("text").toJSONString(1);
}