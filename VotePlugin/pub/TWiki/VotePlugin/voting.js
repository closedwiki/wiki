function VotePlugin_clicked(formID, valID, index) {
    var el = document.getElementById(formID + '_' + valID);
    el.value = index;
    var form = document.getElementById(formID);
    form.submit();
}
