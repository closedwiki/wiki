// Code from http://www.brainjar.com/
// License GPL 2
// Extended by Crawford Currie Copyright (C) 2007 http://c-dot.co.uk
//-----------------------------------------------------------------------------
// sortTable(id, col, rev)
//
//  tblEl - an element anywhere in the table
//  col - Index of the column to sort, 0 = first column, 1 = second column,
//        etc.
//  rev - If true, the column is sorted in reverse (descending) order
//        initially.
//
// Automatically detects and sorts data types; numbers and dates

function sortTable(tblEl, col, rev) {
    
    // Get the table or table section to sort.
    // Search up to find the containing table
    while (tblEl != null &&
           tblEl.tagName != "TABLE") {
        tblEl = tblEl.parentNode;
    }

    if (tblEl == null) {
        return;
    }

    for (var i = 0; i < tblEl.childNodes.length; i++) {
        if (tblEl.childNodes[i].tagName == "TBODY") {
            tblEl = tblEl.childNodes[i];
            break;
        }
    }

    // The first time this function is called for a given table, set up an
    // array of reverse sort flags.
    if (tblEl.reverseSort == null) {
        tblEl.reverseSort = new Array();
        // Also, assume the team name column is initially sorted.
        tblEl.lastColumn = 1;
    }
    
    // If this column has not been sorted before, set the initial sort direction.
    if (tblEl.reverseSort[col] == null)
        tblEl.reverseSort[col] = rev;
    
    // If this column was the last one sorted, reverse its sort direction.
    if (col == tblEl.lastColumn)
        tblEl.reverseSort[col] = !tblEl.reverseSort[col];
    
    // Remember this column as the last one sorted.
    tblEl.lastColumn = col;
    
    // Set the table display style to "none" - necessary for Netscape 6 
    // browsers.
    var oldDsply = tblEl.style.display;
    tblEl.style.display = "none";
    
    // Sort the rows based on the content of the specified column using a
    // selection sort.
    
    var tmpEl;
    var i, j;
    var minVal, minIdx;
    var testVal;
    var cmp;
    
    for (i = 0; i < tblEl.rows.length - 1; i++) {
        
        // Assume the current row has the minimum value.
        minIdx = i;
        minVal = getTextValue(tblEl.rows[i].cells[col]);
        
        // Search the rows that follow the current one for a smaller value.
        for (j = i + 1; j < tblEl.rows.length; j++) {
            testVal = getTextValue(tblEl.rows[j].cells[col]);
            cmp = compareValues(minVal, testVal);
            // Negate the comparison result if the reverse sort flag is set.
            if (tblEl.reverseSort[col])
                cmp = -cmp;
            // If this row has a smaller value than the current minimum,
            // remember its position and update the current minimum value.
            if (cmp > 0) {
                minIdx = j;
                minVal = testVal;
            }
        }
        
        // By now, we have the row with the smallest value. Remove it from the
        // table and insert it before the current row.
        if (minIdx > i) {
            tmpEl = tblEl.removeChild(tblEl.rows[minIdx]);
            tblEl.insertBefore(tmpEl, tblEl.rows[i]);
        }
    }
    
    // Make it look pretty.
    makePretty(tblEl, col);
    
    // Restore the table's display style.
    tblEl.style.display = oldDsply;
    
    return false;
}

//-----------------------------------------------------------------------------
// Functions to get and compare values during a sort.
//-----------------------------------------------------------------------------

// This code is necessary for browsers that don't reflect the DOM constants
// (like IE).
if (document.ELEMENT_NODE == null) {
    document.ELEMENT_NODE = 1;
    document.TEXT_NODE = 3;
}

function getTextValue(el) {
    
    if (!el)
        return '';

    var i;
    var s;
    
    // Find and concatenate the values of all text nodes contained within the
    // element.
    s = "";
    for (i = 0; i < el.childNodes.length; i++)
        if (el.childNodes[i].nodeType == document.TEXT_NODE)
            s += el.childNodes[i].nodeValue;
        else if (el.childNodes[i].nodeType == document.ELEMENT_NODE &&
                 el.childNodes[i].tagName == "BR")
            s += " ";
        else
            // Use recursion to get text within sub-elements.
            s += getTextValue(el.childNodes[i]);
    
    return normalizeString(s);
}

var months = new Array();
months["jan"] = 0;
months["feb"] = 1;
months["mar"] = 2;
months["apr"] = 3;
months["may"] = 4;
months["jun"] = 5;
months["jul"] = 6;
months["aug"] = 7;
months["sep"] = 8;
months["oct"] = 9;
months["nov"] = 10;
months["dec"] = 11;

// "31 Dec 2003 - 23:59",
// "31-Dec-2003 - 23:59",
// "31/Dec/2003 - 23:59",
// "31/Dec/03 - 23:59",
var TWIKIDATE = new RegExp(
    "^\\s*([0-3]?[0-9])[-\\s/]*" +
    "(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)" +
    "[-\\s/]*([0-9]{2}[0-9]{2}?)" +
    "(\\s*(-\\s*)?([0-9]{2}):([0-9]{2}))?", "i");
var RFC8601 = new RegExp(
    "([0-9]{4})(-([0-9]{2})(-([0-9]{2})" +
    "(T([0-9]{2}):([0-9]{2})(:([0-9]{2})(\.([0-9]+))?)?" +
    "(Z|(([-+])([0-9]{2}):([0-9]{2})))?)?)?)?");

// Convert date/time to epoch seconds. Return 0 if a valid date
// wasn't found.
function s2d(s) {
    // TWiki date/time
    var d = s.match(TWIKIDATE);
    if (d != null) {
        var nd = new Date();
        nd.setDate(Number(d[1]));
        nd.setMonth(months[d[2].toLowerCase()]);
        if (d[3].length == 2) {
            var year = d[3];
            // I'll be dead by the time this fails :-)
            if (year > 59)
                year += 1900;
            else
                year += 2000;
            nd.setYear(year);
        } else
            nd.setYear(d[3]);
        if (d[6] != null && d[6].length)
            nd.setHours(d[6]);
        if (d[7] != null && d[7].length)
            nd.setMinutes(d[7]);
        return nd.getTime();
    }

    // RFC8601 date/time
    // (Paul Sowden, http://delete.me.uk/2005/03/iso8601.html)
    var d = s.match(RFC8601);
    if (d == null)
        return 0;

    var offset = 0;
    var date = new Date(d[1], 0, 1);

    if (d[3])  date.setMonth(d[3] - 1);
    if (d[5])  date.setDate(d[5]);
    if (d[7])  date.setHours(d[7]);
    if (d[8])  date.setMinutes(d[8]);
    if (d[10]) date.setSeconds(d[10]);
    if (d[12]) date.setMilliseconds(Number("0." + d[12]) * 1000);
    if (d[14]) {
        offset = (Number(d[16]) * 60) + Number(d[17]);
        offset *= ((d[15] == '-') ? 1 : -1);
    }

    offset -= date.getTimezoneOffset();
    time = (Number(date) + (offset * 60 * 1000));
    return time;
}

function compareValues(v1, v2) {
    // if the values are both dates, convert them to epoch seconds
    var d1 = s2d(v1);
    if (d1) {
        var d2 = s2d(v2);
        if (d2) {
            v1 = d1;
            v2 = d2;
        }
    } else {
        // If the values are numeric, convert them to floats.
        var f1 = parseFloat(v1);
        if (!isNaN(f1)) {
            var f2 = parseFloat(v2);
            if (!isNaN(f2)) {
                v1 = f1;
                v2 = f2;
            }
        }
    }
    
    // Compare the two values.
    if (v1 == v2)
        return 0;
    if (v1 > v2)
        return 1;
    return -1;
}

// Regular expressions for normalizing white space.
var whtSpEnds = new RegExp("^\\s*|\\s*$", "g");
var whtSpMult = new RegExp("\\s\\s+", "g");

function normalizeString(s) {
    
    s = s.replace(whtSpMult, " ");  // Collapse any multiple whites space.
    s = s.replace(whtSpEnds, "");   // Remove leading or trailing white space.
    
    return s;
}

//-----------------------------------------------------------------------------
// Functions to update the table appearance after a sort.
//-----------------------------------------------------------------------------

// Style class names.
var rowClsNm = "alternateRow";
var colClsNm = "sortedColumn";

// Regular expressions for setting class names.
var rowTest = new RegExp(rowClsNm, "gi");
var colTest = new RegExp(colClsNm, "gi");

function makePretty(tblEl, col) {
    
    var i, j;
    var rowEl, cellEl;
    
    // Set style classes on each row to alternate their appearance.
    for (i = 0; i < tblEl.rows.length; i++) {
        rowEl = tblEl.rows[i];
        rowEl.className = rowEl.className.replace(rowTest, "");
        if (i % 2 != 0)
            rowEl.className += " " + rowClsNm;
        rowEl.className = normalizeString(rowEl.className);
        // Set style classes on each column (other than the name column) to
        // highlight the one that was sorted.
        for (j = 2; j < tblEl.rows[i].cells.length; j++) {
            cellEl = rowEl.cells[j];
            cellEl.className = cellEl.className.replace(colTest, "");
            if (j == col)
                cellEl.className += " " + colClsNm;
            cellEl.className = normalizeString(cellEl.className);
        }
    }
    
    // Find the table header and highlight the column that was sorted.
    var el = tblEl.parentNode.tHead;
    if (el) {
        rowEl = el.rows[el.rows.length - 1];
        // Set style classes for each column as above.
        for (i = 2; i < rowEl.cells.length; i++) {
            cellEl = rowEl.cells[i];
            cellEl.className = cellEl.className.replace(colTest, "");
            // Highlight the header of the sorted column.
            if (i == col)
                cellEl.className += " " + colClsNm;
            cellEl.className = normalizeString(cellEl.className);
        }
    }
}

function setRanks(tblEl, col, rev) {
    
    // Determine whether to start at the top row of the table and go down or
    // at the bottom row and work up. This is based on the current sort
    // direction of the column and its reversed flag.
    
    var i    = 0;
    var incr = 1;
    if (tblEl.reverseSort[col])
        rev = !rev;
    if (rev) {
        incr = -1;
        i = tblEl.rows.length - 1;
    }
    
    // Now go through each row in that direction and assign it a rank by
    // counting 1, 2, 3...
    
    var count   = 1;
    var rank    = count;
    var curVal;
    var lastVal = null;
    
    // Note that this loop is skipped if the table was sorted on the name
    // column.
    while (col > 1 && i >= 0 && i < tblEl.rows.length) {
        
        // Get the value of the sort column in this row.
        curVal = getTextValue(tblEl.rows[i].cells[col]);
        
        // On rows after the first, compare the sort value of this row to the
        // previous one. If they differ, update the rank to match the current row
        // count. (If they are the same, this row will get the same rank as the
        // previous one.)
        if (lastVal != null && compareValues(curVal, lastVal) != 0)
            rank = count;
        // Set the rank for this row.
        tblEl.rows[i].rank = rank;
        
        // Save the sort value of the current row for the next time around and bump
        // the row counter and index.
        lastVal = curVal;
        count++;
        i += incr;
    }
    
    // Now go through each row (from top to bottom) and display its rank. Note
    // that when two or more rows are tied, the rank is shown on the first of
    // those rows only.
    
    var rowEl, cellEl;
    var lastRank = 0;
    
    // Go through the rows from top to bottom.
    for (i = 0; i < tblEl.rows.length; i++) {
        rowEl = tblEl.rows[i];
        cellEl = rowEl.cells[0];
        // Delete anything currently in the rank column.
        while (cellEl.lastChild != null)
            cellEl.removeChild(cellEl.lastChild);
        // If this row's rank is different from the previous one, Insert a new text
        // node with that rank.
        if (col > 1 && rowEl.rank != lastRank) {
            cellEl.appendChild(document.createTextNode(rowEl.rank));
            lastRank = rowEl.rank;
        }
    }
}
