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
//TODO: change it to re-size dependant on the number of lines in the textarea.. with minimum

//create the TWiki.InlineEditPlugin.TextArea Class constructor
TWiki.InlineEditPlugin.TextArea = function(topicSectionObject) {
    this.topicSectionObject = topicSectionObject;
}
//register this inline editor component with the main factory
TWiki.InlineEditPlugin.TextArea.register = function() {
    if ( typeof( TWiki.InlineEditPlugin.editors ) == "undefined" ) {
        TWiki.InlineEditPlugin.editors = [];
    }
    TWiki.InlineEditPlugin.editors.push('TWiki.InlineEditPlugin.TextArea');
}
//returns true if the section can be edited by this editor
TWiki.InlineEditPlugin.TextArea.appliesToSection = function(topicSectionObject) {
    return true;    //TextArea is the fallback editor
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//TWiki.InlineEditPlugin.TextArea CLASS functions
TWiki.InlineEditPlugin.TextArea.prototype.getSaveData = function() {
    var serialzationObj = {};

    serialzationObj.topicSection = this.topicSectionObject.editDivSection.elements.namedItem("text").topicSection;
    serialzationObj.value = this.topicSectionObject.editDivSection.elements.namedItem("text").value;
    if (this.topicSectionObject.newSection) {
        //make a real section of it
        serialzationObj.value = "\n\n"+serialzationObj.value+"\n\n";
    }
    return serialzationObj.toJSONString();

//TODO: recode as object so each editor sends the object it thinks it should
    if (this.topicSectionObject.newSection) {
        //make a real section of it
        this.topicSectionObject.editDivSection.elements.namedItem("text").value = "\n\n"+this.topicSectionObject.editDivSection.elements.namedItem("text").value+"\n\n";
    }
    return this.topicSectionObject.editDivSection.elements.namedItem("text").toJSONString(1);
}

TWiki.InlineEditPlugin.TextArea.prototype.createEditSection = function() {
        var newForm = document.createElement('FORM');
        newForm.topicSectionObject = this.topicSectionObject;
        newForm.name = "componenteditpluginform";
        newForm.method = "post";
        newForm.action = this.topicSectionObject.HTMLdiv.parentNode.action;

        var numberOfLines = this.topicSectionObject.TMLdiv.innerHTML.split("\n").length;
        if (numberOfLines < 4) {numberOfLines = 4};
        if (numberOfLines > 12) {numberOfLines = 12};

        var defaultNumberOfCols = 40;
        var defaultNumberOfRows = countLines(this.topicSectionObject.TMLdiv.innerHTML, defaultNumberOfCols);
        if (defaultNumberOfRows < 4) {defaultNumberOfRows = 4};
        if (defaultNumberOfRows > 12) {defaultNumberOfRows = 12};
        var innerHTML = '<textarea id="componentedittextarea" name="text" onkeyup="TWiki.InlineEditPlugin.TextArea.TextAreaResize(this)"  rows="'+defaultNumberOfRows+'" cols="'+defaultNumberOfCols+'" >'+this.topicSectionObject.TMLdiv.innerHTML+'</textarea>';

        newForm.innerHTML = innerHTML;
        newForm.elements.namedItem("text").topicSection =this.topicSectionObject.topicSection;

        //TODO: ***************************************make sure we're using this everwhere we should
        if (( typeof( getComputedStyle ) != "undefined" )) {
            //forks for firefox
            var s = getComputedStyle(this.topicSectionObject.HTMLdiv, "");
//            topicSectionObject.editDivSection.elements.namedItem("text").style.height = s.height;
            newForm.elements.namedItem("text").style.width = s.width;
        } else {
            //IE
//            topicSectionObject.editDivSection.elements.namedItem("text").style.height = topicSectionObject.HTMLdiv.offsetHeight;
            newForm.elements.namedItem("text").style.width = this.topicSectionObject.HTMLdiv.offsetWidth;
        }
        TWiki.InlineEditPlugin.TextArea.TextAreaResize(newForm.elements.namedItem("text"));
    return newForm;
}

TWiki.InlineEditPlugin.TextArea.TextAreaResize = function(tg) {
    tg.rows = Math.max(1, tg.rows);
    tg.cols = Math.max(20, tg.cols);

    //resize the textarea to fit the text - assume that width is fixed.
    var letterCount = tg.value.length;
    var neededRows = countLines(tg.value, tg.cols)+1;
    if (tg.rows >= neededRows) {
        return;
    }

    tg.rows = Math.min(neededRows, 60);
}

