/*
   Copyright (C) 2005 ILOG http://www.ilog.fr
   and TWiki Contributors. All Rights Reserved. TWiki Contributors
   are listed in the AUTHORS file in the root of this distribution.
   NOTE: Please extend that file, not this notice.

   Portions Copyright (c) 2003-2004 Kupu Contributors. All rights reserved.

   This program is free software; you can redistribute it and/or
   modify it under the terms of the GNU General Public License
   as published by the Free Software Foundation; either version 2
   of the License, or (at your option) any later version.
  
   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  
   As per the GPL, removal of this notice is prohibited.
*/

/*
 * TWiki-specific customisation of kupustart.js
 */

function startKupu() {
    // initialize the editor, initKupu groks 1 arg, a reference to the iframe
    var frame = document.getElementById('kupu-editor');
    var kupu = initKupu(frame);

    kupu.registerContentChanger(document.getElementById('kupu-editor-textarea'));

    var navigatingAway = function () {
      if (kupu.content_changed && 
          confirm('You have unsaved changes. Do you want to save before leaving the page? (OK to save, Cancel to discard your changes)')) {
        kupu.config.reload_src = 0;
        var form = document.getElementById('twiki-main-form');
        TWikiHandleSubmit();
        form.submit();
      };
    }

    if (kupu.getBrowserName() == 'IE') {
        // IE supports onbeforeunload, so let's use that
        addEventHandler(window, 'beforeunload', navigatingAway);
    } else {
        // some versions of Mozilla support onbeforeunload (starting with 1.7)
        // so let's try to register and if it fails fall back on onunload
        var re = /rv:([0-9\.]+)/
        var match = re.exec(navigator.userAgent)
        if (match[1] && parseFloat(match[1]) > 1.6) {
            addEventHandler(window, 'beforeunload', navigatingAway);
        } else {
            addEventHandler(window, 'unload', navigatingAway);
        };
    };

    // and now we can initialize...
    kupu.initialize();

    TWikiCleanForm();

    return kupu;
};
