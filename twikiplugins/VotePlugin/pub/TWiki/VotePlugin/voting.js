function VotePlugin_clicked(formID, valID, index, submitOnPick, px) {
    var el = document.getElementById(formID + '_' + valID);
    el.value = index;
    var mypick = document.getElementById(valID+"_rated");
    if (mypick != null) {
        mypick.style.width = (px * index) + "px";
    }
    if (submitOnPick) {
        var form = document.getElementById(formID);
        form.submit();
    }
}
