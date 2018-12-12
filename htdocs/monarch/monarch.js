// MonArch - Groundwork Monitor Architect
// monarch.js
// Release 4.6
// November 2017
// Copyright 2007-2017 GroundWork Open Source, Inc. (GroundWork)

// Control flags for list selection and sort sequence
// Sequence is on option value (first 2 chars - can be stripped off in form processing)
// It is assumed that the select list is in sort sequence initially
var singleSelect = true;  // Allows an item to be selected once only
var sortSelect = true;  // Only effective if above flag set to true
var sortPick = true;  // Will order the picklist in sort sequence

// Initialize - to be invoked on load (but in fact this is obsolete, broken, and not called from anywhere)
function initIt() {
  var selectList = document.getElementById("nonmembers");
  var selectOptions = selectList.options;
  var selectIndex = selectList.selectedIndex;
  var pickList = document.getElementById("members");
  var pickOptions = pickList.options;
  pickOptions[0] = null;  // Remove initial entry from picklist (was only used to set default width)
  if (!(selectIndex > -1)) {
    selectOptions[0].selected = true;  // Set first selected on load
    selectOptions[0].defaultSelected = true;  // In case of reset/reload
  }
  selectList.focus();  // Set focus on the selectlist
}

// Adds a selected item into the picklist
function addIt(objname) {
  var prefix = objname ? (objname + '.') : '';
  var selectList = document.getElementById(prefix + "nonmembers");
  var selectIndex = selectList.selectedIndex;
  var selectOptions = selectList.options;
  var pickList = document.getElementById(prefix + "members");
  var pickOptions = pickList.options;
  var pickOLength = pickOptions.length;
  // An item must be selected
  while (selectIndex > -1) {
    pickOptions[pickOLength] = new Option(selectList[selectIndex].text);
    pickOptions[pickOLength].value = selectList[selectIndex].value;
    // If single selection, remove the item from the select list
    if (singleSelect) {
      selectOptions[selectIndex] = null;
    }
    if (sortPick) {
      var tempText;
      var tempValue;
      // Sort the pick list
      while (pickOLength > 0 && pickOptions[pickOLength].value < pickOptions[pickOLength-1].value) {
        tempText = pickOptions[pickOLength-1].text;
        tempValue = pickOptions[pickOLength-1].value;
        pickOptions[pickOLength-1].text = pickOptions[pickOLength].text;
        pickOptions[pickOLength-1].value = pickOptions[pickOLength].value;
        pickOptions[pickOLength].text = tempText;
        pickOptions[pickOLength].value = tempValue;
        pickOLength = pickOLength - 1;
      }
    }
    selectIndex = selectList.selectedIndex;
    pickOLength = pickOptions.length;
  }
  if (selectOptions.length > 0) {
    selectOptions[0].selected = true;
  }
}

// Deletes an item from the picklist
function delIt(objname) {
  var prefix = objname ? (objname + '.') : '';
  var selectList = document.getElementById(prefix + "nonmembers");
  var selectOptions = selectList.options;
  var selectOLength = selectOptions.length;
  var pickList = document.getElementById(prefix + "members");
  var pickIndex = pickList.selectedIndex;
  var pickOptions = pickList.options;
  while (pickIndex > -1) {
    // If single selection, replace the item in the select list
    if (singleSelect) {
      selectOptions[selectOLength] = new Option(pickList[pickIndex].text);
      selectOptions[selectOLength].value = pickList[pickIndex].value;
    }
    pickOptions[pickIndex] = null;
    if (singleSelect && sortSelect) {
      var tempText;
      var tempValue;
      // Re-sort the select list
      while (selectOLength > 0 && selectOptions[selectOLength].value < selectOptions[selectOLength-1].value) {
        tempText = selectOptions[selectOLength-1].text;
        tempValue = selectOptions[selectOLength-1].value;
        selectOptions[selectOLength-1].text = selectOptions[selectOLength].text;
        selectOptions[selectOLength-1].value = selectOptions[selectOLength].value;
        selectOptions[selectOLength].text = tempText;
        selectOptions[selectOLength].value = tempValue;
        selectOLength = selectOLength - 1;
      }
    }
    pickIndex = pickList.selectedIndex;
    selectOLength = selectOptions.length;
  }
}

// Selection - invoked on submit
function selIt() {
  var selects = document.getElementsByTagName("select");
  var pattern = new RegExp("(?:^|[.])members$");
  for (var i = 0; i < selects.length; i++) {
    if (pattern.test(selects[i].id)) {
      var pickList = selects[i];
      var pickOptions = pickList.options;
      var pickOLength = pickOptions.length;
      for (var j = 0; j < pickOLength; j++) {
        pickOptions[j].selected = true;
      }
    }
  }
  return true;
}

function enableAllArgs() {
  var inputs = document.getElementsByTagName("input");
  var inh_pattern = new RegExp("^inh_ext_args_\\d+$");
  for (var i = 0; i < inputs.length; i++) {
    if (inh_pattern.test(inputs[i].id)) {
      inputs[i].disabled = false;
    }
  }
  var textareas = document.getElementsByTagName("textarea");
  var all_args_pattern = new RegExp("^(ext_)?args_\\d+$");
  for (var i = 0; i < textareas.length; i++) {
    if (all_args_pattern.test(textareas[i].id)) {
      textareas[i].disabled = false;
    }
  }
  return true;
}

//function selIt_then_validateIt() {
//	var selItResult = selIt();
//	var validateResult = ValidateForm();
//	return validateResult;
//}

// Browser Detection
isMac = (navigator.appVersion.indexOf("Mac")!=-1) ? true : false;
NS4 = (document.layers) ? true : false;
IEmac = ((document.all)&&(isMac)) ? true : false;
IE4plus = (document.all) ? true : false;
IE4 = ((document.all)&&(navigator.appVersion.indexOf("MSIE 4.")!=-1)) ? true : false;
IE5 = ((document.all)&&(navigator.appVersion.indexOf("MSIE 5.")!=-1)) ? true : false;
ver4 = (NS4 || IE4plus) ? true : false;
NS6 = (!document.layers) && (navigator.userAgent.indexOf('Netscape')!=-1)?true:false;

// Body onload utility (supports multiple onload functions)
var gSafeOnload = new Array();
function SafeAddOnload(f)
{
	if (IEmac && IE4)  // IE 4.5 blows out on testing window.onload
	{
		window.onload = SafeOnload;
		gSafeOnload[gSafeOnload.length] = f;
	}
	else if  (window.onload)
	{
		if (window.onload != SafeOnload)
		{
			gSafeOnload[0] = window.onload;
			window.onload = SafeOnload;
		}
		gSafeOnload[gSafeOnload.length] = f;
	}
	else
		window.onload = f;
}

function SafeOnload()
{
	for (var i=0;i<gSafeOnload.length;i++)
		gSafeOnload[i]();
}

//
// Main Form Functions
//

// This array holds our form values when we need to regenerate the form
var gFieldValues = new Array(1);
for (var i=0;i<gFieldValues.length;i++)
	gFieldValues[i]="";

function GetFormHTML()
{
	var htmlStr = '';
	htmlStr += '<form id="dynoform" name="dynoform" action="bldynoforms.htm" method="GET">';

	for (var i=0;i<gFieldValues.length;i++)
		htmlStr += 'Item #' + (i+1) + ' <input type="text" name="multifield" value="' + gFieldValues[i] + '"><br>';
	htmlStr += '<input type="button" value="Add Item" onClick="AddField()">';
	htmlStr += '</form>';

	return htmlStr;
}

function GetFormObj()
{
	var returnObj = null;

	if (IE4plus)
	{
		returnObj =  document.dynoform;
	}
	else if (NS4)
	{
		returnObj =  document.formlayer.document.dynoform;
	}
	else if (NS6)
	{
		returnObj =  document.getElementById("dynoform");
	}
	return returnObj;
}

function AddField()
{
	// Save previously entered data here
	var formObj = GetFormObj();
	for (var i=0;i<gFieldValues.length;i++)
	{
		if (gFieldValues.length>1)
			gFieldValues[i]= formObj.multifield[i].value;
		else
			gFieldValues[i]= formObj.multifield.value;
	}

	// Create the new field
	gFieldValues[gFieldValues.length]="";
	UpdateForm();
}

function UpdateForm()
{
	var htmlStr = GetFormHTML();
	if (IE4plus)
	{
		document.all.formlayer.innerHTML = htmlStr;
	}
	else if (NS4)
	{
		document.formlayer.document.open();
		document.formlayer.document.write(htmlStr);
		document.formlayer.document.close();
	}
	else if (NS6)
	{
		document.getElementById("formlayer").innerHTML = htmlStr;
	}
}

function IncludeForm()
{
	var htmlStr = GetFormHTML();

	if (IE4plus || NS6)
	{
		document.write('<DIV ID=formlayer name=formlayer  STYLE="position:relative; WIDTH=400px; HEIGHT=50px">' + htmlStr + '</DIV>');
	}
	else if (NS4)
	{
		// Because NS needs floating layers, we need a placeholder graphic to force anything
		// below the layer content to leave whitespace for the layer.  The position of this
		// graphic is also used in determining the position of the layer.
		document.write('<img name="formlocation" border="0" width="400" height="200" src="images/spacer.gif">');
	}
}

//
// Netscape 4.x Ineptness
//
function HandleOnload()
{
	if (NS4)
	{
		var width = document.formlocation.width;
		var height = document.formlocation.height;

		nL=new Layer(width);
		nL.name = "formlayer";
		nL.left=document.formlocation.x;
		nL.top=document.formlocation.y;
		nL.bgColor = "white";
		nL.clip.width=width;
		nL.clip.height=height;
		nL.document.open();
		nL.document.write(GetFormHTML());
		nL.document.write(GetFormHTML2());
		nL.document.close();
		nL.visibility = 'show';

		document.formlayer = nL;
	}
}

function HandleResize()
{
	location.reload();
	return false;
}

if (NS4)
{
	SafeAddOnload(HandleOnload);
	window.captureEvents(Event.RESIZE);
	window.onresize = HandleResize;
}

// Opens new browser
function MM_openBrWindow(theURL,winName,features) { //v2.0
    window.open(theURL,winName,features);
}

function HTMLencode(str) {
    var div = document.createElement('div');
    var text = document.createTextNode(str);
    div.appendChild(text);
    return div.innerHTML;
}

function erase_warning() {
    document.getElementsByTagName('body')[0].removeChild(document.getElementById('coverSheet'));
}

function show_warning(heading, warning) {
    if (document.getElementById('coverSheet')) return;
    sheet = document.getElementsByTagName('body')[0].appendChild(document.createElement('div'));
    sheet.id = 'coverSheet';
    sheet.style.height = document.documentElement.scrollHeight + 'px';
    sheet.onclick = function() { this.blur(); erase_warning(); return false; }
    mask = sheet.appendChild(document.createElement('div'));
    mask.id = 'coverMask';
    message_box = sheet.appendChild(document.createElement('div'));
    message_box.id = 'messageBox';
    message_box.style.top = '-1000px';
    banner = message_box.appendChild(document.createElement('h1'));
    banner.appendChild(document.createTextNode(heading));
    message = message_box.appendChild(document.createElement('p'));
    // Multiple sequential newlines are collapsed within innerHTML by IE8, but DELs are not.
    message.innerHTML = HTMLencode( warning.replace(/\n/g, '\x7F') ).replace(/\x7F/g, '<br>');
    button_row = message_box.appendChild(document.createElement('div'));
    button_row.style.textAlign = 'center';
    dismiss_element = document.createElement('input');
    // IE can't change an <input> type after it's been added to the DOM.
    dismiss_element.type = 'button';
    dismiss = button_row.appendChild(dismiss_element);
    dismiss.id = 'dismissButton';
    dismiss.value = '   OK   ';
    message_box.style.left = (document.documentElement.scrollWidth - message_box.offsetWidth) / 2 + 'px';
    var windowHeight = window.innerHeight ||
	document.documentElement.parentNode.clientHeight ||
	document.body.parentNode.clientHeight;
    // message_box.style.top = (windowHeight - 2 * message_box.clientHeight) / 4 + 'px';

    // Setting the focus while the box is way off the top of the page forces the entire screen
    // to scroll back, so we know where it is when we plant the message box back inside the frame.
    // That allows us to guarantee the alert box will be entirely visible.  We would prefer to
    // leave the screen/frame/page scrolling where it is, and use a "fixed" position of the alert
    // box (relative to the viewport of this frame) that stays put when the screen or frame is
    // scrolled, so the alert moves then relative to the page but stays in essentially the same
    // screen position.  But we haven't got that to work yet, and the whole setup is complicated
    // by the portal taking over screen scrolling by artificially extending the vertical size of
    // the <iframe> in which this document is embedded, so for now we live with this workaround.
    dismiss.focus();
    message_box.style.top = '100px';
}

function lowlight() {
    document.body.style.backgroundColor = '#E6E6E6';
    document.body.style.opacity = 0.6;
}   

if (true) {
    if (document.getElementById) {
	window.alert = function(warning) {
	    show_warning('Invalid Input', warning);
	}
    }
}
