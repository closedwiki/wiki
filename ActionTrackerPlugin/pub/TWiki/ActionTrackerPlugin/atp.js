function atp_update(url, field, value) {
    if (window.XMLHttpRequest){
        var xml = new XMLHttpRequest();
    }else{
        var xml = new ActiveXObject("MSXML2.XMLHTTP.3.0");
    }
    url += ";field="+field;
    url += ";value="+value;
    xml.open("GET", url, true);
    xml.onreadystatechange = function() {
        if (xml.readyState == 4) {
            if (xml.status >= 400) {
                // Something went wrong!
                if (xml.responseText) {
                    alert(xml.responseText);
                }
            }
        }
    }
    xml.send(null);
}
