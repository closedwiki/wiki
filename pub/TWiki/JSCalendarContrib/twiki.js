// Reuses the same "calendar" object for all date-type fields on the page
function jscal_selected(cal, date) {
  cal.sel.value = date;
  if (cal.dateClicked)
    cal.callCloseHandler();
}
function jscal_close(cal) {
  cal.hide();
  calendar = null;
}
function showCalendar(id, format) {
  var el = document.getElementById(id);
  if (calendar != null) {
    calendar.hide();
  } else {
    var cal = new Calendar(true, null, jscal_selected, jscal_close);
    cal.showsTime = false;
    cal.showsOtherMonths = true;
    calendar = cal;
    cal.setRange(1900, 2070);
    cal.create();
  }
  calendar.setDateFormat(format);
  calendar.parseDate(el.value);
  calendar.sel = el;
  calendar.showAtElement(el, "Br");
  return false;
}
