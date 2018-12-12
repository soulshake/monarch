/*
 * OpenSocial jQuery autoHeight 1.0.0
 * http://code.google.com/p/opensocial-jquery/
 *
 * Copyright(C) 2009 Nakajiman Software Inc.
 * http://nakajiman.lrlab.to/
 *
 * Dual licensed under the MIT and GPL licenses:
 * http://www.opensource.org/licenses/mit-license.php
 * http://www.gnu.org/licenses/gpl.html
 */
function doIframe() {
        o = document.getElementsByTagName('frame');
        for (i = 0; i < o.length; i++) {
                if (/\bautoHeight\b/.test(o[i].className)) {
                        setHeight(o[i]);
                        addEvent(o[i], 'load', doIframe);
                }
        }
//      alert('Before calling parent from MonarchForms.pm');
        parent.parent.doIframe();
}

function setHeight(e) {
        if (e.contentDocument) {
                // All monarch cgis are of height 150
//alert(e.contentDocument.body.offsetHeight);

                if (e.contentDocument.body.offsetHeight <= 150) {
                        e.height = 2000;
                } else {
                        e.height = e.contentDocument.body.offsetHeight + 35;
                }
        } else {
                e.height = e.contentWindow.document.body.scrollHeight;
        }
}

function addEvent(obj, evType, fn) {
        if (obj.addEventListener) {
                obj.addEventListener(evType, fn, false);
                return true;
        } else if (obj.attachEvent) {
                var r = obj.attachEvent("on" + evType, fn);
                return r;
        } else {
                return false;
        }
}

if (document.getElementById && document.createTextNode) {
        addEvent(window, 'load', doIframe);
}