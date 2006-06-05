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

//create the TWiki.InlineEditPlugin.TableEdit Class constructor
TWiki.InlineEditPlugin.TableEdit = function(topicSectionObject) {
    this.topicSectionObject = topicSectionObject;
}
//register this inline editor component with the main factory
TWiki.InlineEditPlugin.TableEdit.register = function() {
    if ( typeof( TWiki.InlineEditPlugin.editors ) == "undefined" ) {
        TWiki.InlineEditPlugin.editors = [];
    }
    TWiki.InlineEditPlugin.editors.push('TWiki.InlineEditPlugin.TableEdit');
}
//returns true if the section can be edited by this editor
TWiki.InlineEditPlugin.TableEdit.appliesToSection = function(topicSectionObject) {
//TODO: deal with \ and other special cases
//foreach line make sure it starts and ends with a |
    var lines = topicSectionObject.TMLdiv.innerHTML.split("\n");
    for (var i=0; i< lines.length;i++) {
        if ( ! lines[i].match(/^\s*\|(.*)\|\s*$/)) {
            return false;
        }
    }
    return true;
}

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//TWiki.InlineEditPlugin.TableEdit CLASS functions
TWiki.InlineEditPlugin.TableEdit.prototype.getSaveData = function() {
    var serialzationObj = {};

    serialzationObj.topicSection = this.topicSectionObject.topicSection;
    var reconstitutedTable ='|';
    var line;
    for (var i=0;i<this.topicSectionObject.editDivSection.elements.length;i++) {
        if (this.topicSectionObject.editDivSection.elements[i].name != 'text') {
            continue;
        }
        if (line == undefined) {
            line = this.topicSectionObject.editDivSection.elements[i].id;
        }
        if (this.topicSectionObject.editDivSection.elements[i].id != line) {
            reconstitutedTable = reconstitutedTable + '\n|';
            line = this.topicSectionObject.editDivSection.elements[i].id;
        }

        reconstitutedTable = reconstitutedTable + this.topicSectionObject.editDivSection.elements[i].value;
        reconstitutedTable = reconstitutedTable + '|';
        //if end of row, add new line and a new |
    }

    serialzationObj.value = reconstitutedTable;
    if (this.topicSectionObject.newSection) {
        //make a real section of it
        serialzationObj.value = "\n\n"+serialzationObj.value+"\n\n";
    }
    return serialzationObj.toJSONString();
}

TWiki.InlineEditPlugin.TableEdit.prototype.createEditSection = function() {
        var newForm = document.createElement('FORM');
        newForm.topicSectionObject = this.topicSectionObject;
        newForm.name = "componenteditpluginform";
        newForm.method = "post";
        newForm.action = this.topicSectionObject.HTMLdiv.parentNode.action;

//        var innerHTML = 'TableEdit<textarea id="componentedittextarea" name="text" width="99%" rows="'+numberOfLines+'">COMPONENTEDITPLUGINTML</textarea>';
    var innerHTML = '';
    var lines = this.topicSectionObject.TMLdiv.innerHTML.split("\n");
    var maxColumns = 0;
    for (var i=0; i< lines.length;i++) {
        innerHTML = innerHTML + '<tr>';
        innerHTML = innerHTML + '<td>'+makeFormButton('add_row', '+', 'addRow(event);', 1);
        innerHTML = innerHTML + makeFormButton('delete_row', '-', 'deleteRow(event);', 1) +'</td>';
        var cells = lines[i].split(/[|]/);
        if (cells.length > maxColumns) {
            maxColumns = cells.length;
        }
        for (var j=1; j< cells.length-1;j++) {
            innerHTML = innerHTML + '<td><textarea id="'+i+'" name="text" width="99%" >'+cells[j]+'</textarea></td>';
        }
        innerHTML = innerHTML + '</tr>';
    }
    //add colunm manipulation buttons
    var columnActions = '<tr>';
    columnActions = columnActions + '<td>'+makeFormButton('add_row', '+', 'addRow(event);', 1);
    columnActions = columnActions +'</td>';
    for (var j=1; j< maxColumns-1;j++) {
        columnActions = columnActions + '<td align="center">'+makeFormButton('add_row', '+', 'addRow(event);', 1);
        columnActions = columnActions + makeFormButton('delete_row', '-', 'deleteRow(event);', 1) +'</td>';
    }
    columnActions = columnActions + '</tr>';

    innerHTML = '<table>' + columnActions + innerHTML + '</table>';

    newForm.innerHTML = innerHTML;

    return newForm;
}