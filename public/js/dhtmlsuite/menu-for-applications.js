/************************************************************************************************************
	@fileoverview
	DHTML Suite for Applications.
	Copyright (C) 2006  Alf Magne Kalleland(post@dhtmlgoodies.com)<br>
	<br>
	This library is free software; you can redistribute it and/or<br>
	modify it under the terms of the GNU Lesser General Public<br>
	License as published by the Free Software Foundation; either<br>
	version 2.1 of the License, or (at your option) any later version.<br>
	<br>
	This library is distributed in the hope that it will be useful,<br>
	but WITHOUT ANY WARRANTY; without even the implied warranty of<br>
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU<br>
	Lesser General Public License for more details.<br>
	<br>
	You should have received a copy of the GNU Lesser General Public<br>
	License along with this library; if not, write to the Free Software<br>
	Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301  USA<br>
	<br>
	<br>
	www.dhtmlgoodies.com<br>
	Alf Magne Kalleland<br>

************************************************************************************************************/


/**
 * 
 * @package DHTMLSuite for applications
 * @copyright Copyright &copy; 2006, www.dhtmlgoodies.com
 * @author Alf Magne Kalleland <post@dhtmlgoodies.com>
 */


/************************************************************************************************************
*
* Global variables
*
************************************************************************************************************/


// {{{ DHTMLSuite.createStandardObjects()
/**
 * Create objects used by all scripts
 *
 * @public
 */


var DHTMLSuite = new Object();

var standardObjectsCreated = false;	// The classes below will check this variable, if it is false, default help objects will be created
DHTMLSuite.eventElements = new Array();	// Array of elements that has been assigned to an event handler.

DHTMLSuite.createStandardObjects = function()
{
	DHTMLSuite.clientInfoObj = new DHTMLSuite.clientInfo();	// Create browser info object
	DHTMLSuite.clientInfoObj.init();	
	if(!DHTMLSuite.configObj){	// If this object isn't allready created, create it.
		DHTMLSuite.configObj = new DHTMLSuite.config();	// Create configuration object.
		DHTMLSuite.configObj.init();
	}
	DHTMLSuite.commonObj = new DHTMLSuite.common();	// Create configuration object.
	DHTMLSuite.variableStorage = new DHTMLSuite.globalVariableStorage();;	// Create configuration object.
	DHTMLSuite.commonObj.init();
	window.onunload = function() { DHTMLSuite.commonObj.__clearGarbage(); }
	
	standardObjectsCreated = true;

	
}

    


/************************************************************************************************************
*	Configuration class used by most of the scripts
*
*	Created:			August, 19th, 2006
* 	Update log:
*
************************************************************************************************************/


/**
* @constructor
* @class Store global variables/configurations used by the classes below. Example: If you want to  
*		 change the path to the images used by the scripts, change it here. An object of this   
*		 class will always be available to the other classes. The name of this object is 
*		"DHTMLSuite.configObj".	<br><br>
*			
*		If you want to create an object of this class manually, remember to name it "DHTMLSuite.configObj"
*		This object should then be created before any other objects. This is nescessary if you want
*		the other objects to use the values you have put into the object. <br>
* @version				1.0
* @version 1.0
* @author	Alf Magne Kalleland(www.dhtmlgoodies.com)
**/
DHTMLSuite.config = function()
{
	var imagePath;	// Path to images used by the classes. 
	var cssPath;	// Path to CSS files used by the DHTML suite.		
}


DHTMLSuite.config.prototype = {
	// {{{ init()
	/**
	 *
	 * @public
	 */
	init : function()
	{
		this.imagePath = '../images_dhtmlsuite/';	// Path to images		
		this.cssPath = '../css_dhtmlsuite/';	// Path to images		
	}	
	// }}}
	,
	// {{{ setCssPath()
    /**
     * This method will save a new CSS path, i.e. where the css files of the dhtml suite are located.
     *
     * @param string newCssPath = New path to css files
     * @public
     */
    	
	setCssPath : function(newCssPath)
	{
		this.cssPath = newCssPath;
	}
	// }}}
	,
	// {{{ setImagePath()
    /**
     * This method will save a new image file path, i.e. where the image files used by the dhtml suite ar located
     *
     * @param string newImagePath = New path to image files
     * @public
     */
	setImagePath : function(newImagePath)
	{
		this.imagePath = newImagePath;
	}
	// }}}
}



DHTMLSuite.globalVariableStorage = function()
{
	var menuBar_highlightedItems;	// Array of highlighted menu bar items
	this.menuBar_highlightedItems = new Array();
	
	var arrayOfDhtmlSuiteObjects;	// Array of objects of class menuItem.
	this.arrayOfDhtmlSuiteObjects = new Array();
}

DHTMLSuite.globalVariableStorage.prototype = {
	
}


/************************************************************************************************************
*	A class with general methods used by most of the scripts
*
*	Created:			August, 19th, 2006
*	Purpose of class:	A class containing common method used by one or more of the gui classes below, 
* 						example: loadCSS. 
*						An object("DHTMLSuite.commonObj") of this  class will always be available to the other classes. 
* 	Update log:
*
************************************************************************************************************/


/**
* @constructor
* @class A class containing common method used by one or more of the gui classes below, example: loadCSS. An object("DHTMLSuite.commonObj") of this  class will always be available to the other classes. 
* @version 1.0
* @author	Alf Magne Kalleland(www.dhtmlgoodies.com)
**/

DHTMLSuite.common = function()
{
	var loadedCSSFiles;	// Array of loaded CSS files. Prevent same CSS file from being loaded twice.
	var cssCacheStatus;	// Css cache status
	var eventElements;
	
	this.cssCacheStatus = true;	// Caching of css files = on(Default)
	this.eventElements = new Array();	
}

DHTMLSuite.common.prototype = {
	
	// {{{ init()
    /**
     * This method initializes the DHTMLSuite_common object.
     *
     * @public
     */
    	
	init : function()
	{
		this.loadedCSSFiles = new Array();
	}	
	// }}}
	,
	// {{{ loadCSS()
    /**
     * This method loads a CSS file(Cascading Style Sheet) dynamically - i.e. an alternative to <link> tag in the document.
     *
     * @param string cssFileName = New path to image files
     * @public
     */
	
	loadCSS : function(cssFileName)
	{
		
		if(!this.loadedCSSFiles[cssFileName]){
			this.loadedCSSFiles[cssFileName] = true;
			var linkTag = document.createElement('LINK');
			if(!this.cssCacheStatus){
				if(cssFileName.indexOf('?')>=0)cssFileName = cssFileName + '&'; else cssFileName = cssFileName + '?';
				cssFileName = cssFileName + 'rand='+ Math.random();	// To prevent caching
			}
			linkTag.href = DHTMLSuite.configObj.cssPath + cssFileName;
			linkTag.rel = 'stylesheet';
			linkTag.media = 'screen';
			linkTag.type = 'text/css';
			document.getElementsByTagName('HEAD')[0].appendChild(linkTag);	
			
		}
	}	
	// }}}
	,
	// {{{ getTopPos()
    /**
     * This method will return the top coordinate(pixel) of an object
     *
     * @param Object inputObj = Reference to HTML element
     * @public
     */	
	getTopPos : function(inputObj)
	{		
	  var returnValue = inputObj.offsetTop;
      if (returnValue > 700) returnValue = 0;
	  while((inputObj = inputObj.offsetParent) != null){
	  	if(inputObj.tagName!='HTML'){
	  		returnValue += (inputObj.offsetTop - inputObj.scrollTop);
	  		if(document.all)returnValue+=inputObj.clientTop;
	  	}
	  } 
	  return returnValue;
	}
	// }}}	
	,	
	// {{{ setCssCacheStatus()
    /**
     * Specify if css files should be cached or not. 
     *
     *	@param Boolean cssCacheStatus = true = cache on, false = cache off
     *
     * @public
     */	
	setCssCacheStatus : function(cssCacheStatus)
	{		
	  this.cssCacheStatus = cssCacheStatus;
	}
	// }}}	
	,
	// {{{ getLeftPos()
    /**
     * This method will return the left coordinate(pixel) of an object
     *
     * @param Object inputObj = Reference to HTML element
     * @public
     */	
	getLeftPos : function(inputObj)
	{	  
	  var returnValue = inputObj.offsetLeft;
	  while((inputObj = inputObj.offsetParent) != null){
	  	if(inputObj.tagName!='HTML'){
	  		returnValue += inputObj.offsetLeft;
	  		if(document.all)returnValue+=inputObj.clientLeft;
	  	}
	  }
	  return returnValue;
	}
	// }}}
	,
	// {{{ cancelEvent()
    /**
     *
     *  This function only returns false. It is used to cancel selections and drag
     *
     * 
     * @public
     */	
    	
	cancelEvent : function()
	{
		return false;
	}
	// }}}	
	,
	// {{{ addEvent()
    /**
     *
     *  This function adds an event listener to an element on the page.
     *
     *	@param Object whichObject = Reference to HTML element(Which object to assigne the event)
     *	@param String eventType = Which type of event, example "mousemove" or "mouseup"
     *	@param functionName = Name of function to execute. 
     * 
     * @public
     */	
	addEvent : function(whichObject,eventType,functionName)
	{ 
	  if(whichObject.attachEvent){ 
	    whichObject['e'+eventType+functionName] = functionName; 
	    whichObject[eventType+functionName] = function(){whichObject['e'+eventType+functionName]( window.event );} 
	    whichObject.attachEvent( 'on'+eventType, whichObject[eventType+functionName] ); 
	  } else 
	    whichObject.addEventListener(eventType,functionName,false); 	    
	  this.__addEventElement(whichObject);
	  delete(whichObject);
	  // whichObject = null;
	} 
	// }}}	
	,	
	// {{{ removeEvent()
    /**
     *
     *  This function removes an event listener from an element on the page.
     *
     *	@param Object whichObject = Reference to HTML element(Which object to assigne the event)
     *	@param String eventType = Which type of event, example "mousemove" or "mouseup"
     *	@param functionName = Name of function to execute. 
     * 
     * @public
     */		
	removeEvent : function(whichObject,eventType,functionName)
	{ 
	  if(whichObject.detachEvent){ 
	    whichObject.detachEvent('on'+eventType, whichObject[eventType+functionName]); 
	    whichObject[eventType+functionName] = null; 
	  } else 
	    whichObject.removeEventListener(eventType,functionName,false); 
	} 
	,
	// {{{ __clearGarbage()
    /**
     *
     *  This function is used for Internet Explorer in order to clear memory when the page unloads.
     *
     * 
     * @private
     */	
    __clearGarbage : function()
    {
   		/* Example of event which causes memory leakage in IE 
   		
   		DHTMLSuite.commonObj.addEvent(expandRef,"click",function(){ window.refToMyMenuBar[index].__changeMenuBarState(this); })
   		
   		We got a circular reference.
   		
   		*/
   		
    	if(!DHTMLSuite.clientInfoObj.isMSIE)return;
   	
    	for(var no in DHTMLSuite.variableStorage.arrayOfDhtmlSuiteObjects){
    		DHTMLSuite.variableStorage.arrayOfDhtmlSuiteObjects[no] = false;    			
    	}
    	
    	for(var no=0;no<DHTMLSuite.eventElements.length;no++){
    		DHTMLSuite.eventElements[no].onclick = null;
    		DHTMLSuite.eventElements[no].onmousedown = null;
    		DHTMLSuite.eventElements[no].onmousemove = null;
    		DHTMLSuite.eventElements[no].onmouseout = null;
    		DHTMLSuite.eventElements[no].onmouseover = null;
    		DHTMLSuite.eventElements[no].onmouseup = null;
    		DHTMLSuite.eventElements[no].onfocus = null;
    		DHTMLSuite.eventElements[no].onblur = null;
    		DHTMLSuite.eventElements[no].onkeydown = null;
    		DHTMLSuite.eventElements[no].onkeypress = null;
    		DHTMLSuite.eventElements[no].onkeyup = null;
    		DHTMLSuite.eventElements[no].onselectstart = null;
    		DHTMLSuite.eventElements[no].ondragstart = null;
    		DHTMLSuite.eventElements[no].oncontextmenu = null;
    		DHTMLSuite.eventElements[no].onscroll = null;
    		
    	}
    	window.onunload = null;
    	DHTMLSuite = null;

    }		
    
    ,
	// {{{ __addEventElement()
    /**
     *
     *  Add element to garbage collection array. The script will loop through this array and remove event handlers onload in ie.
     *
     * 
     * @private
     */	    
    __addEventElement : function(el)
    {
    	DHTMLSuite.eventElements[DHTMLSuite.eventElements.length] = el;    
    }
    
    ,
	// {{{ getSrcElement()
    /**
     *
     *  Returns a reference to the element which triggered an event.
     *	@param Event e = Event object
     *
     * 
     * @private
     */	       
    getSrcElement : function(e)
    {
    	var el;
		// Dropped on which element
		if (e.target) el = e.target;
			else if (e.srcElement) el = e.srcElement;
			if (el.nodeType == 3) // defeat Safari bug
				el = el.parentNode;
		return el;	
    }		    
	
}


/************************************************************************************************************
*	Client info class
*
*	Created:			August, 18th, 2006
* 	Update log:
*
************************************************************************************************************/

/**
* @constructor
* @class Purpose of class: Provide browser information to the classes below. Instead of checking for
*		 browser versions and browser types in the classes below, they should check this
*		 easily by referncing properties in the class below. An object("DHTMLSuite.clientInfoObj") of this 
*		 class will always be accessible to the other classes. * @version 1.0
* @author	Alf Magne Kalleland(www.dhtmlgoodies.com)
**/


DHTMLSuite.clientInfo = function()
{
	var browser;			// Complete user agent information
	
	var isOpera;			// Is the browser "Opera"
	var isMSIE;				// Is the browser "Internet Explorer"	
	var isFirefox;			// Is the browser "Firefox"
	var navigatorVersion;	// Browser version
}
	
DHTMLSuite.clientInfo.prototype = {
	
	/**
	* 	Constructor
	*	Params: 		none:
	*  	return value: 	none;
	**/
	// {{{ init()
    /**
     *
	 *
     *  This method initializes the script
     *
     * 
     * @public
     */	
    	
	init : function()
	{
		this.browser = navigator.userAgent;	
		this.isOpera = (this.browser.toLowerCase().indexOf('opera')>=0)?true:false;
		this.isFirefox = (this.browser.toLowerCase().indexOf('firefox')>=0)?true:false;
		this.isMSIE = (this.browser.toLowerCase().indexOf('msie')>=0)?true:false;
		this.isSafari = (this.browser.toLowerCase().indexOf('safari')>=0)?true:false;
		this.navigatorVersion = navigator.appVersion.replace(/.*?MSIE (\d\.\d).*/g,'$1')/1;
	}	
	// }}}		
}

/************************************************************************************************************
*	DHTML menu model item class
*
*	Created:						October, 30th, 2006
*	@class Purpose of class:		Save data about a menu item.
*			
*
*
* 	Update log:
*
************************************************************************************************************/

DHTMLSuite.menuModelItem = function()
{
	var id;					// id of this menu item.
	var itemText;			// Text for this menu item
	var itemIcon;			// Icon for this menu item.
	var url;				// url when click on this menu item
	var parentId;			// id of parent element
	var separator;			// is this menu item a separator
	var jsFunction;			// Js function to call onclick
	var depth;				// Depth of this menu item.
	var hasSubs;			// Does this menu item have sub items.
	var type;				// Menu item type - possible values: "top" or "sub". 
	var helpText;			// Help text for this item - appear when you move your mouse over the item.
	var state;
	var submenuWidth;		// Width of sub menu items.
	var visible;			// Visibility of menu item.
	var frameTarget;
	
	this.state = 'regular';
}

DHTMLSuite.menuModelItem.prototype = {

	setMenuVars : function(id,itemText,itemIcon,url,parentId,helpText,jsFunction,type,submenuWidth,frameTarget)	
	{
		this.id = id;
		this.itemText = itemText;
		this.itemIcon = itemIcon;
		this.url = url;
		this.parentId = parentId;
		this.jsFunction = jsFunction;
		this.separator = false;
		this.depth = false;
		this.hasSubs = false;
		this.helpText = helpText;
		this.submenuWidth = submenuWidth;
		this.visible = true;
		this.frameTarget = frameTarget;
		if(!type){
			if(this.parentId)this.type = 'top'; else this.type='sub';
		}else this.type = type;
		

	}
	// }}}	
	,
	// {{{ setState()
    /**
     *	Update the state attribute of a menu item.
     *
     *  @param String newState New state of this item
     * @public	
     */		
	setAsSeparator : function(id,parentId)
	{
		this.id = id;
		this.parentId = parentId;
		this.separator = true;	
		this.visible = true;
		if(this.parentId)this.type = 'top'; else this.type='sub';		
	}
	// }}}	
	,
	// {{{ setState()
    /**
     *	Update the visible attribute of a menu item.
     *
     *  @param Boolean visible true = visible, false = hidden.
     * @public	
     */		
	setVisibility : function(visible)
	{
		this.visible = visible;
	}
	// }}}	
	,
	// {{{ getState()
    /**
     *	Return the state attribute of a menu item.
     *
     * @public	
     */		
	getState : function()
	{
		return this.state;
	}
	// }}}	
	,
	// {{{ setState()
    /**
     *	Update the state attribute of a menu item.
     *
     *  @param String newState New state of this item
     * @public	
     */		
	setState : function(newState)
	{
		this.state = newState;
	}
	// }}}	
	,
	// {{{ setSubMenuWidth()
    /**
     *	Specify width of direct subs of this item.
     *
     *  @param int newWidth Width of sub menu group(direct sub of this item)
     * @public	
     */		
	setSubMenuWidth : function(newWidth)
	{
		this.submenuWidth = newWidth;
	}
	// }}}	
	,
	// {{{ setIcon()
    /**
     *	Specify new menu icon
     *
     *  @param String iconPath Path to new menu icon
     * @public	
     */		
	setIcon : function(iconPath)
	{
		this.itemIcon = iconPath;
	}
	// }}}	
	,
	// {{{ setText()
    /**
     *	Specify new text for the menu item.
     *
     *  @param String newText New text for the menu item.
     * @public	
     */		
	setText : function(newText)
	{
		this.itemText = newText;
	}
}

/************************************************************************************************************
*	DHTML menu model class
*
*	Created:						October, 30th, 2006
*	@class Purpose of class:		Saves menu item data
*			
*
*	Demos of this class:			demo-menu-strip.html
*
* 	Update log:
*
************************************************************************************************************/


/**
* @constructor
* @class Purpose of class:	Organize menu items for different menu widgets. demos of menus: (<a href="../../demos/demo-menu-strip.html" target="_blank">Demo</a>)
* @version 1.0
* @author	Alf Magne Kalleland(www.dhtmlgoodies.com)
*/


DHTMLSuite.menuModel = function()
{
	var menuItems;					// Array of menuModelItem objects
	var menuItemsOrder;			// This array is needed in order to preserve the correct order of the array above. the array above is associative
									// And some browsers will loop through that array in different orders than Firefox and IE.
	var submenuType;				// Direction of menu items(one item for each depth)
	var mainMenuGroupWidth;			// Width of menu group - useful if the first group of items are listed below each other
	this.menuItems = new Array();
	this.menuItemsOrder = new Array();
	this.submenuType = new Array();
	this.submenuType[1] = 'top';
	for(var no=2;no<20;no++){
		this.submenuType[no] = 'sub';
	}		
	if(!standardObjectsCreated)DHTMLSuite.createStandardObjects();	
}

DHTMLSuite.menuModel.prototype = {
	// {{{ addItem()
    /**
     *	Add separator (special type of menu item)
     *
 	 *
     *
     *  @param int id of menu item
     *  @param string itemText = text of menu item
     *  @param string itemIcon = file name of menu icon(in front of menu text. Path will be imagePath for the DHTMLSuite + file name)
     *  @param string url = Url of menu item
     *  @param int parent id of menu item     
     *  @param String jsFunction Name of javascript function to execute. It will replace the url param. The function with this name will be called and the element triggering the action will be 
     *					sent as argument. Name of the element which triggered the menu action may also be sent as a second argument. That depends on the widget. The context menu is an example where
     *					the element triggering the context menu is sent as second argument to this function.    
     *
     * @public	
     */			
	addItem : function(id,itemText,itemIcon,url,parentId,helpText,jsFunction,type,submenuWidth)
	{
		if(!id)id = this.__getUniqueId();	// id not present - create it dynamically.
		this.menuItems[id] = new DHTMLSuite.menuModelItem();
		this.menuItems[id].setMenuVars(id,itemText,itemIcon,url,parentId,helpText,jsFunction,type,submenuWidth);
		this.menuItemsOrder[this.menuItemsOrder.length] = id;
		return this.menuItems[id];
	}
	,
	// {{{ addItemsFromMarkup()
    /**
     *	This method creates all the menuModelItem objects by reading it from existing markup on your page.
     *	Example of HTML markup:
     *<br>
		&nbsp;&nbsp;&nbsp;&nbsp;&lt;ul id="menuModel">
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;li id="50000" itemIcon="../images/disk.gif">&lt;a href="#" title="Open the file menu">File&lt;/a>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;ul width="150">
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;li id="500001" jsFunction="saveWork()" itemIcon="../images/disk.gif">&lt;a href="#" title="Save your work">Save&lt;/a>&lt;/li>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;li id="500002">&lt;a href="#">Save As&lt;/a>&lt;/li>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;li id="500004" itemType="separator">&lt;/li>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;li id="500003">&lt;a href="#">Open&lt;/a>&lt;/li>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;/ul>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;/li>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;li id="50001">&lt;a href="#">View&lt;/a>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;ul width="130">
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;li id="500011">&lt;a href="#">Source&lt;/a>&lt;/li>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;li id="500012">&lt;a href="#">Debug info&lt;/a>&lt;/li>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;li id="500013">&lt;a href="#">Layout&lt;/a>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;ul width="150">
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;li id="5000131">&lt;a href="#">CSS&lt;/a>&nbsp;&nbsp;
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;li id="5000132">&lt;a href="#">HTML&lt;/a>&nbsp;&nbsp;
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;li id="5000133">&lt;a href="#">Javascript&lt;/a>&nbsp;&nbsp;
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;/ul>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;/li>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;/ul>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;/li>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;li id="50003" itemType="separator">&lt;/li>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&lt;li id="50002">&lt;a href="#">Tools&lt;/a>&lt;/li>
		<br>&nbsp;&nbsp;&nbsp;&nbsp;&lt;/ul>&nbsp;&nbsp;     
     *
     *  @param String ulId = ID of <UL> tag on your page.
     *
     * @public	
     */		
	addItemsFromMarkup : function(ulId)
	{
		if(!document.getElementById(ulId)){
			alert('<UL> tag with id ' + ulId + ' does not exist');
			return;
		}
		var ulObj = document.getElementById(ulId);
		var liTags = ulObj.getElementsByTagName('LI');		
		for(var no=0;no<liTags.length;no++){	// Walking through all <li> tags in the <ul> tree
			
			var id = liTags[no].id.replace(/[^0-9]/gi,'');	// Get id of item.
			if(!id)id = this.__getUniqueId();
			this.menuItems[id] = new DHTMLSuite.menuModelItem();	// Creating new menuModelItem object
			this.menuItemsOrder[this.menuItemsOrder.length] = id;
			// Get the attributes for this new menu item.	
			
			var parentId = 0;	// Default parent id
			if(liTags[no].parentNode!=ulObj)parentId = liTags[no].parentNode.parentNode.id;	// parent node exists, set parentId equal to id of parent <li>.
						
			/* Checking type */
			var type = liTags[no].getAttribute('itemType');			
			if(!type)type = liTags[no].itemType;
			if(type=='separator'){	// Menu item of type "separator"
				this.menuItems[id].setAsSeparator(id,parentId);
				continue;	
			}
			if(parentId)type='sub'; else type = 'top';						
	
			var aTag = liTags[no].getElementsByTagName('A')[0];	// Get a reference to sub <a> tag
			if(!aTag){
				continue;
			}			
			if(aTag)var itemText = aTag.innerHTML;	// Item text is set to the innerHTML of the <a> tag.
			var itemIcon = liTags[no].getAttribute('itemIcon');	// Item icon is set from the itemIcon attribute of the <li> tag.
			var url = aTag.href;	// url is set to the href attribute of the <a> tag
			if(url=='#' || url.substr(url.length-1,1)=='#')url='';	// # = empty url.
      var frameTarget = aTag.target;
			
			var jsFunction = liTags[no].getAttribute('jsFunction');	// jsFunction is set from the jsFunction attribute of the <li> tag.

			var submenuWidth = false;	// Not set from the <li> tag. 
			var helpText = aTag.getAttribute('title');	
			if(!helpText)helpText = aTag.title;
			
			this.menuItems[id].setMenuVars(id,itemText,itemIcon,url,parentId,helpText,jsFunction,type,submenuWidth,frameTarget);			
		}		
		var subUls = ulObj.getElementsByTagName('UL');
		for(var no=0;no<subUls.length;no++){
			var width = subUls[no].getAttribute('width');
			if(!width)width = subUls[no].width;	
			if(width){
				var id = subUls[no].parentNode.id.replace(/[^0-9]/gi,'');
				this.setSubMenuWidth(id,width);
			}
		}		
		ulObj.style.display='none';
		
	}	
	// }}}	
	,
	// {{{ setSubMenuWidth()
    /**
     *	This method specifies the width of a sub menu group. This is a useful method in order to get a correct width in IE6 and prior.
     *
     *  @param int id = ID of parent menu item
     *  @param String newWidth = Width of sub menu items.
     * @public	
     */		
	setSubMenuWidth : function(id,newWidth)
	{
		this.menuItems[id].setSubMenuWidth(newWidth);
	}	
	,
	// {{{ setMainMenuGroupWidth()
    /**
     *	Add separator (special type of menu item)
     *
     *  @param String newWidth = Size of a menu group
     *  @param int parent id of menu item
     * @public	
     */			
	setMainMenuGroupWidth : function(newWidth)
	{
		this.mainMenuGroupWidth = newWidth;
	}
	,
	// {{{ addSeparator()
    /**
     *	Add separator (special type of menu item)
     *
     *  @param int parent id of menu item
     * @public	
     */		
	addSeparator : function(parentId)
	{
		id = this.__getUniqueId();	// Get unique id
		if(!parentId)parentId = 0;
		this.menuItems[id] = new DHTMLSuite.menuModelItem();
		this.menuItems[id].setAsSeparator(id,parentId);
		this.menuItemsOrder[this.menuItemsOrder.length] = id;
		return this.menuItems[id];
	}	
	,
	// {{{ init()
    /**
     *	Initilizes the menu model. This method should be called when all items has been added to the model.
     *
     *
     * @public	
     */		
	init : function()
	{
		this.__getDepths();	
		this.__setHasSubs();	
		
	}
	// }}}	
	,
	// {{{ setMenuItemVisibility()
    /**
     *	Save visibility of a menu item.
     * 	
     *	@param int id = Id of menu item..
     *	@param Boolean visible = Visibility of menu item.
     *
     * @public	
     */		
	setMenuItemVisibility : function(id,visible)
	{
		this.menuItems[id].setVisibility(visible);		
	}
	// }}}
	,
	// {{{ setSubMenuType()
    /**
     *	Set menu type for a specific menu depth.
     * 	
     *	@param int depth = 1 = Top menu, 2 = Sub level 1...
     *	@param String newType = New menu type(possible values: "top" or "sub")
     *
     * @private	
     */		
	setSubMenuType : function(depth,newType)
	{
		this.submenuType[depth] = newType;	
		
	}
	// }}}		
	,
	// {{{ __getDepths()
    /**
     *	Create variable for the depth of each menu item.
     * 	
     *
     * @private	
     */		
	getItems : function(parentId,returnArray)
	{
		if(!parentId)return this.menuItems;
		if(!returnArray)returnArray = new Array();
		for(var no=0;no<this.menuItemsOrder.length;no++){
			var id = this.menuItemsOrder[no];
			if(!id)continue;
			if(this.menuItems[id].parentId==parentId){
				returnArray[returnArray.length] = this.menuItems[id];
				if(this.menuItems[id].hasSubs)return this.getItems(this.menuItems[id].id,returnArray);
			}
		}
		return returnArray;
		
	}
	// }}}
	,
	// {{{ __getUniqueId()
    /**
     *	Returns a unique id for a menu item. This method is used by the addSeparator function in case an id isn't sent to the method.
     * 	
     *
     * @private	
     */	    	
	__getUniqueId : function()
	{
		var num = Math.random() + '';
		num = num.replace('.','');	
		num = '99' + num;		
		num = num /1;		
		while(this.menuItems[num]){
			num = Math.random() + '';
			num = num.replace('.','');	
			num = num /1;				
		}
		return num;
	}
	// }}}	
	,
	// {{{ __getDepths()
    /**
     *	Create variable for the depth of each menu item.
     * 	
     *
     * @private	
     */	
    __getDepths : function()
    {    	
    	for(var no=0;no<this.menuItemsOrder.length;no++){
    		var id = this.menuItemsOrder[no];
    		if(!id)continue;
    		this.menuItems[id].depth = 1;
    		if(this.menuItems[id].parentId){
    			this.menuItems[id].depth = this.menuItems[this.menuItems[id].parentId].depth+1;    
 	
    		}  
    		this.menuItems[id].type = this.submenuType[this.menuItems[id].depth];	// Save menu direction for this menu item.  		
    	}    	
    }	
    // }}}
    ,	    
    // {{{ __setHasSubs()
    /**
     *	Create variable for the depth of each menu item.
     * 	
     *
     * @private	
     */	
    __setHasSubs : function()
    {    	
    	for(var no=0;no<this.menuItemsOrder.length;no++){
    		var id = this.menuItemsOrder[no];
    		if(!id)continue;    		
    		if(this.menuItems[id].parentId){
    			this.menuItems[this.menuItems[id].parentId].hasSubs = 1;
    			
    		}    		
    	}    	
    }	
    // }}}
    ,
	// {{{ __hasSubs()
    /**
     *	Does a menu item have sub elements ?
     * 	
     *
     * @private	
     */	
	// }}}	
	__hasSubs : function(id)
	{
		for(var no=0;no<this.menuItemsOrder.length;no++){
			var id = this.menuItemsOrder[no];
			if(!id)continue;
			if(this.menuItems[id].parentId==id)return true;		
		}
		return false;	
	}
	// }}}
	,
	// {{{ __deleteChildNodes()
    /**
     *	Deleting child nodes of a specific parent id
     * 	
     *	@param int parentId
     *
     * @private	
     */	
	// }}}		
	__deleteChildNodes : function(parentId,recursive)
	{
		var itemsToDeleteFromOrderArray = new Array();
		for(var prop=0;prop<this.menuItemsOrder.length;prop++){
    		var id = this.menuItemsOrder[prop];
    		if(!id)continue;    
    					
			if(this.menuItems[id].parentId==parentId && parentId){
				this.menuItems[id] = false;
				itemsToDeleteFromOrderArray[itemsToDeleteFromOrderArray.length] = id;				
				this.__deleteChildNodes(id,true);	// Recursive call.
			}	
		}	
		
		if(!recursive){
			for(var prop=0;prop<itemsToDeleteFromOrderArray;prop++){
				if(!itemsToDeleteFromOrderArray[prop])continue;
				this.__deleteItemFromItemOrderArray(itemsToDeleteFromOrderArray[prop]);
			}
		}
		this.__setHasSubs();
	}
	// }}}
	,
	// {{{ __deleteANode()
    /**
     *	Deleting a specific node from the menu model
     * 	
     *	@param int id = Id of node to delete.
     *
     * @private	
     */	
	// }}}		
	__deleteANode : function(id)
	{
		this.menuItems[id] = false;	
		this.__deleteItemFromItemOrderArray(id);	
	}
	,
	// {{{ __deleteItemFromItemOrderArray()
    /**
     *	Deleting a specific node from the menuItemsOrder array(The array controlling the order of the menu items).
     * 	
     *	@param int id = Id of node to delete.
     *
     * @private	
     */	
	// }}}		
	__deleteItemFromItemOrderArray : function(id)
	{
		for(var no=0;no<this.menuItemsOrder.length;no++){
			var tmpId = this.menuItemsOrder[no];
			if(!tmpId)continue;
			if(this.menuItemsOrder[no]==id){
				this.menuItemsOrder.splice(no,1);
				return;
			}
		}
		
	}
	// }}}
	,	
	// {{{ __appendMenuModel()
    /**
     *	Replace the sub items of a menu item with items from a new menuModel.
     * 	
     *	@param menuModel newModel = An object of class menuModel - the items of this menu model will be appended to the existing menu items.
     *	@param Int parentId = Id of parent element of the appended items.
     *
     * @private	
     */	
	// }}}		
	__appendMenuModel : function(newModel,parentId)
	{
		if(!newModel)return;
		var items = newModel.getItems();
		for(var no=0;no<newModel.menuItemsOrder.length;no++){
			var id = newModel.menuItemsOrder[no];
			if(!id)continue;
			if(!items[id].parentId)items[id].parentId = parentId;
			this.menuItems[id] = items[id];	
			for(var no2=0;no2<this.menuItemsOrder.length;no2++){	// Check to see if this item allready exists in the menuItemsOrder array, if it does, remove it. 
				if(!this.menuItemsOrder[no2])continue;
				if(this.menuItemsOrder[no2]==items[id].id){
					this.menuItemsOrder.splice(no2,1);
				}
			}
			this.menuItemsOrder[this.menuItemsOrder.length] = items[id].id;		
		}
		this.__getDepths();		
		this.__setHasSubs();		
	}
	// }}}
}

/* Class for menu items - a view */

/************************************************************************************************************
*	DHTML menu item class
*
*	Created:						October, 21st, 2006
*	@class Purpose of class:		Creates the HTML for a single menu item.
*			
*	Css files used by this script:	menu-item.css
*
*	Demos of this class:			demo-menu-strip.html
*
* 	Update log:
*
************************************************************************************************************/

/**
* @constructor
* @class Purpose of class:	Creates the div(s) for a menu item. This class is used by the menuBar class. You can 
*	also create a menu item and add it where you want on your page. the createItem() method will return the div
*	for the item. You can use the appendChild() method to add it to your page. 
*
* @version 1.0
* @author	Alf Magne Kalleland(www.dhtmlgoodies.com)
*/


DHTMLSuite.menuItem = function()
{
	var layoutCSS;	
	var divElement;							// the <div> element created for this menu item
	var expandElement;						// Reference to the arrow div (expand sub items)
	var cssPrefix;							// Css prefix for the menu items.
	var modelItemRef;						// Reference to menuModelItem

//	this.layoutCSS = 'menu-item.css';
	this.cssPrefix = 'DHTMLSuite_';
	
	if(!standardObjectsCreated)DHTMLSuite.createStandardObjects();	
		
	
	var objectIndex;
	this.objectIndex = DHTMLSuite.variableStorage.arrayOfDhtmlSuiteObjects.length;

	
}

DHTMLSuite.menuItem.prototype = 
{
	
	/*
	*	Create a menu item.
	*
	*	@param menuModelItem menuModelItemObj = An object of class menuModelItem
	*/
	createItem : function(menuModelItemObj)
	{
//		DHTMLSuite.commonObj.loadCSS(this.layoutCSS);	// Load css
		
		DHTMLSuite.variableStorage.arrayOfDhtmlSuiteObjects[this.objectIndex] = this;
			
		this.modelItemRef = menuModelItemObj;
		this.divElement = document.createElement('DIV');	// Create main div
		this.divElement.id = 'DHTMLSuite_menuItem' + menuModelItemObj.id;	// Giving this menu item it's unque id
		this.divElement.className = this.cssPrefix + 'menuItem_' + menuModelItemObj.type + '_regular'; 
		this.divElement.onselectstart = function() { return DHTMLSuite.commonObj.cancelEvent(false,this) };
		if(menuModelItemObj.helpText){	// Add "title" attribute to the div tag if helpText is defined
			this.divElement.title = menuModelItemObj.helpText;
		}
		
		// Menu item of type "top"
		if(menuModelItemObj.type=='top'){			
			this.__createMenuElementsOfTypeTop(this.divElement);
		}

		if(menuModelItemObj.type=='sub'){
			this.__createMenuElementsOfTypeSub(this.divElement);
		}
		
		if(menuModelItemObj.separator){
			this.divElement.className = this.cssPrefix + 'menuItem_separator_' + menuModelItemObj.type;
			this.divElement.innerHTML = '<span></span>';
		}else{		
			/* Add events */
			var tmpVar = this.objectIndex/1;
			//this.divElement.onclick = function(e) { DHTMLSuite.variableStorage.arrayOfDhtmlSuiteObjects[tmpVar].__navigate(e); }
			this.divElement.onmousedown = this.__clickMenuItem;			// on mouse down effect
			this.divElement.onmouseup = this.__rolloverMenuItem;		// on mouse up effect
			this.divElement.onmouseover = this.__rolloverMenuItem;		// mouse over effect
			this.divElement.onmouseout = this.__rolloutMenuItem;		// mouse out effect.
			DHTMLSuite.commonObj.__addEventElement(this.divElement);
		}
		return this.divElement;
	}
	// }}}
	,
	// {{{ setLayoutCss()
    /**
     *	Creates the different parts of a menu item of type "top".
     *
     *  @param String newLayoutCss = Name of css file used for the menu items.
     *
     * @public	
     */		
	setLayoutCss : function(newLayoutCss)
	{
		this.layoutCSS = newLayoutCss;
		
	}
	// }}}
	,
	// {{{ __createMenuElementsOfTypeTop()
    /**
     *	Creates the different parts of a menu item of type "top".
     *
     *  @param menuModelItem menuModelItemObj = Object of type menuModelItemObj
     *  @param Object parentEl = Reference to parent element
     *
     * @private	
     */		
	__createMenuElementsOfTypeTop : function(parentEl){
		if(this.modelItemRef.itemIcon){
			var iconDiv = document.createElement('DIV');
			iconDiv.innerHTML = '<img src="' + this.modelItemRef.itemIcon + '">';
			iconDiv.id = 'menuItemIcon' + this.modelItemRef.id
			parentEl.appendChild(iconDiv);		
		}
		if(this.modelItemRef.itemText){
			var div = document.createElement('DIV');
			div.innerHTML = this.modelItemRef.itemText;	
			div.className = this.cssPrefix + 'menuItem_textContent';
			div.id = 'menuItemText' + this.modelItemRef.id;	
			parentEl.appendChild(div);
		}
		/* Create div for the arrow -> Show sub items */
		var div = document.createElement('DIV');
		div.className = this.cssPrefix + 'menuItem_top_arrowShowSub';
		div.id = 'DHTMLSuite_menuBar_arrow' + this.modelItemRef.id;
		parentEl.appendChild(div);
		this.expandElement = div;
		if(!this.modelItemRef.hasSubs)div.style.display='none';
				
	}
	// }}}
	,	
	
	// {{{ __createMenuElementsOfTypeSub()
    /**
     *	Creates the different parts of a menu item of type "sub".
     *
     *  @param menuModelItem menuModelItemObj = Object of type menuModelItemObj
     *  @param Object parentEl = Reference to parent element
     *
     * @private	
     */		
	__createMenuElementsOfTypeSub : function(parentEl){		
		if(this.modelItemRef.itemIcon){
			parentEl.style.backgroundImage = 'url(\'' + this.modelItemRef.itemIcon + '\')';	
			parentEl.style.backgroundRepeat = 'no-repeat';
			parentEl.style.backgroundPosition = 'left center';	
		}
		if(this.modelItemRef.itemText){
		  var div;
		  if( this.modelItemRef.url )
		  {
			  div = document.createElement('a');
			  div.href = this.modelItemRef.url;
			  div.target = this.modelItemRef.frameTarget;
			  div.style.display = 'block';
			}
			else
			  div = document.createElement('div');
			  
			div.className = 'DHTMLSuite_textContent';
			div.innerHTML = this.modelItemRef.itemText;	
			div.className = this.cssPrefix + 'menuItem_textContent';
			div.id = 'menuItemText' + this.modelItemRef.id;
			parentEl.appendChild(div);
		}
		
		/* Create div for the arrow -> Show sub items */
		var div = document.createElement('DIV');
		div.className = this.cssPrefix + 'menuItem_sub_arrowShowSub';
		parentEl.appendChild(div);		
		div.id = 'DHTMLSuite_menuBar_arrow' + this.modelItemRef.id;
		this.expandElement = div;
		
		if(!this.modelItemRef.hasSubs){
			div.style.display='none';	
		}else{
			div.previousSibling.style.paddingRight = '15px';
		}	
	}
	// }}}
	,
	// {{{ setCssPrefix()
    /**
     *	Set css prefix for the menu item. default is 'DHTMLSuite_'. This is useful in case you want to have different menus on a page with different layout.
     *
     *  @param String cssPrefix = New css prefix. 
     *
     * @public	
     */		
	setCssPrefix : function(cssPrefix)
	{
		this.cssPrefix = cssPrefix;
	}
	// }}}
	,
	// {{{ setMenuIcon()
    /**
     *	Replace menu icon.
     *
     *	@param String newPath - Path to new icon (false if no icon);
     *
     * @public	
     */		
	setIcon : function(newPath)
	{
		this.modelItemRef.setIcon(newPath);
		if(this.modelItemRef.type=='top'){	// Menu item is of type "top"
			var div = document.getElementById('menuItemIcon' + this.modelItemRef.id);	// Get a reference to the div where the icon is located.
			var img = div.getElementsByTagName('IMG')[0];	// Find the image
			if(!img){	// Image doesn't exists ?
				img = document.createElement('IMG');	// Create new image
				div.appendChild(img);
			}
			img.src = newPath;	// Set image path
			if(!newPath)img.parentNode.removeChild(img);	// No newPath defined, remove the image.			
		}
		if(this.modelItemRef.type=='sub'){	// Menu item is of type "sub"
			this.divElement.style.backgroundImage = 'url(\'' + newPath + '\')';		// Set backgroundImage for the main div(i.e. menu item div)	
		}		
	}
	// }}}
	,
	// {{{ setText()
    /**
     *	Replace the text of a menu item
     *
     *	@param String newText - New text for the menu item.
     *
     * @public	
     */		
	setText : function(newText)
	{
		this.modelItemRef.setText(newText);
		document.getElementById('menuItemText' + this.modelItemRef.id).innerHTML = newText;
		
		
	}
	
	// }}}
	,
	// {{{ __clickMenuItem()
    /**
     *	Effect - click on menu item
     *
     *
     * @private	
     */		
	__clickMenuItem : function()
	{
		this.className = this.className.replace('_regular','_click');
		this.className = this.className.replace('_over','_click');
	}
	// }}}	
	,	
	// {{{ __rolloverMenuItem()
    /**
     *	Roll over effect
     *
     *
     * @private	
     */		
	__rolloverMenuItem : function()
	{
		this.className = this.className.replace('_regular','_over');
		this.className = this.className.replace('_click','_over');
	}	
	// }}}
	,	
	// {{{ __rolloutMenuItem()
    /**
     *	Roll out effect
     *
     *
     * @private	
     */		
	__rolloutMenuItem : function()
	{
		this.className = this.className.replace('_over','_regular');
		
	}
	// }}}
	,	
	// {{{ setState()
    /**
     *	Set state of a menu item.
     *
     *	@param String newState = New state for the menu item
     *
     * @public	
     */		
	setState : function(newState)
	{
		this.divElement.className = this.cssPrefix + 'menuItem_' + this.modelItemRef.type + '_' + newState; 		
		this.modelItemRef.setState(newState);
	}
	// }}}
	,
	// {{{ getState()
    /**
     *	Return state of a menu item. 
     *
     *
     * @public	
     */		
	getState : function()
	{
		var state = this.modelItemRef.getState();
		if(!state){
			if(this.divElement.className.indexOf('_over')>=0)state = 'over';	
			if(this.divElement.className.indexOf('_click')>=0)state = 'click';	
			this.modelItemRef.setState(state);		
		}
		return state;
	}	
	// }}}
	,
	// {{{ __setHasSub()
    /**
     *	Update the item, i.e. show/hide the arrow if the element has subs or not. 
     *
     *
     * @private	
     */	
    __setHasSub : function(hasSubs)
    {
    	this.modelItemRef.hasSubs = hasSubs;
    	if(!hasSubs){
    		document.getElementById(this.cssPrefix +'menuBar_arrow' + this.modelItemRef.id).style.display='none';    		
    	}else{
    		document.getElementById(this.cssPrefix +'menuBar_arrow' + this.modelItemRef.id).style.display='block';
    	}    	
    }
    // }}}	
    ,
	// {{{ hide()
    /**
     *	Hide the menu item.
     *
     *
     * @public	
     */	    
    hide : function()
    {
    	this.modelItemRef.setVisibility(false);
    	this.divElement.style.display='none';    	
    }    
    ,
 	// {{{ show()
    /**
     *	Show the menu item.
     *
     *
     * @public	
     */	     
    show : function()
    {
    	this.modelItemRef.setVisibility(true);
    	this.divElement.style.display='block';    	
    }    
	// }}}
	,
	// {{{ __hideGroup()
    /**
     *	Hide the group the menu item is a part of. Example: if we're dealing with menu item 2.1, hide the group for all sub items of 2
     *
     *
     * @private	
     */			
	__hideGroup : function()
	{		
		if(this.modelItemRef.parentId){
			this.divElement.parentNode.style.visibility='hidden';	
			if(DHTMLSuite.clientInfoObj.isMSIE){
				try{
					var tmpId = this.divElement.parentNode.id.replace(/[^0-9]/gi,'');
					document.getElementById('DHTMLSuite_menuBarIframe_' + tmpId).style.visibility = 'hidden';
				}catch(e){
					// IFRAME hasn't been created.
				}	
			}
		}	

	}
	// }}}	
	,
	// {{{ __navigate()
    /**
     *	Navigate after click on a menu item.
     *
     *
     * @private	
     */		
	__navigate : function(e)
	{
		/* Check to see if the expand sub arrow is clicked. if it is, we shouldn't navigate from this click */
		if(document.all)e = event;
		if(e){
			var srcEl = DHTMLSuite.commonObj.getSrcElement(e);
			if(srcEl.id.indexOf('arrow')>=0)return;
		}
		if(this.modelItemRef.state=='disabled')return;
		if(this.modelItemRef.url){
      if (this.modelItemRef.frameTarget == 'main_window')
        window.main_window.location = this.modelItemRef.url;
      else if (this.modelItemRef.frameTarget == '_top')
        window.location = this.modelItemRef.url;
      else if (this.modelItemRef.frameTarget)
        window.open(this.modelItemRef.url);
      else
        location.href = this.modelItemRef.url;
		}
		if(this.modelItemRef.jsFunction){
			try{
				eval(this.modelItemRef.jsFunction);
			}catch(e){
				alert('Defined Javascript code for the menu item( ' + this.modelItemRef.jsFunction + ' ) cannot be executed');
			}
		}
	}
}


/************************************************************************************************************
*	DHTML menu bar class
*
*	Created:						October, 21st, 2006
*	@class Purpose of class:		Creates a top bar menu
*			
*	Css files used by this script:	menu-bar.css
*
*	Demos of this class:			demo-menu-bar.html
*
* 	Update log:
*
************************************************************************************************************/


/**
* @constructor
* @class Purpose of class:	Creates a top bar menu strip. Demos: <br>
*	<ul>
*	<li>(<a href="../../demos/demo-menu-bar-2.html" target="_blank">A menu with a detailed description on how it is created</a>)</li>
*	<li>(<a href="../../demos/demo-menu-bar.html" target="_blank">Demo with lots of menus on the same page</a>)</li>
*	<li>(<a href="../../demos/demo-menu-bar-custom-css.html" target="_blank">Two menus with different layout</a>)</li>
*	<li>(<a href="../../demos/demo-menu-bar-custom-css-file.html" target="_blank">One menu with custom layout/css.</a>)</li>
*	</ul>
*
*	<a href="../images/menu-bar-1.gif" target="_blank">Image describing the classes</a> <br><br>
*
* @version 1.0
* @author	Alf Magne Kalleland(www.dhtmlgoodies.com)
*/

DHTMLSuite.menuBar = function()
{
	var menuItemObj;
	var layoutCSS;					// Name of css file
	var menuBarBackgroundImage;		// Name of background image
	var menuItem_objects;			// Array of menu items - html elements.
	var menuBarObj;					// Reference to the main dib
	var menuBarHeight;
	var menuItems;					// Reference to objects of class menuModelItem
	var highlightedItems;			// Array of currently highlighted menu items.
	var menuBarState;				// Menu bar state - true or false - 1 = expand items on mouse over
	var activeSubItemsOnMouseOver;	// Activate sub items on mouse over	(instead of onclick)
	

	var submenuGroups;				// Array of div elements for the sub menus
	var submenuIframes;				// Array of sub menu iframes used to cover select boxes in old IE browsers.
	var createIframesForOldIeBrowsers;	// true if we want the script to create iframes in order to cover select boxes in older ie browsers.
	var targetId;					// Id of element where the menu will be inserted.
	var menuItemCssPrefix;			// Css prefix of menu items.
	var cssPrefix;					// Css prefix for the menu bar
	var menuItemLayoutCss;			// Css path for the menu items of this menu bar
	var globalObjectIndex;			// Global index of this object - used to refer to the object of this class outside
	this.cssPrefix = 'DHTMLSuite_';
	this.menuItemLayoutCss = false;	// false = use default for the menuItem class.
//	this.layoutCSS = 'menu-bar.css';
	this.menuBarBackgroundImage = 'menu_strip_bg.jpg';
	this.menuItem_objects = new Array();
	DHTMLSuite.variableStorage.menuBar_highlightedItems = new Array();
	
	this.menuBarState = false;
	
	this.menuBarObj = false;
	this.menuBarHeight = 26;
	this.submenuGroups = new Array();
	this.submenuIframes = new Array();
	this.targetId = false;
	this.activeSubItemsOnMouseOver = false;
	this.menuItemCssPrefix = false;
	this.createIframesForOldIeBrowsers = false;
	if(!standardObjectsCreated)DHTMLSuite.createStandardObjects();	
	
	
}





DHTMLSuite.menuBar.prototype = {	
	
	// {{{ init()
    /**
     *	Initilizes the script
     *
     *
     * @public	
     */					
	init : function()
	{
		
//		DHTMLSuite.commonObj.loadCSS(this.layoutCSS);	
		this.__createDivs();	// Create general divs
		this.__createMenuItems();	// Create menu items
		this.__setBasicEvents();	// Set basic events.
		window.refToThismenuBar = this;
	}
	// }}}
	,
	// {{{ setTarget()
    /**
     *	Specify where this menu bar will be inserted. the element with this id will be parent of the menu bar.
     *
     *  @param String targetId = Id of element where the menu will be inserted. 
     *
     * @public	
     */		
	setTarget : function(targetId)
	{
		this.targetId = targetId;		
		
	}	
	// }}}	
	,
	// {{{ setLayoutCss()
    /**
     *	Specify the css file for this menu bar
     *
     *  @param String layoutCSS = Name of new css file. 
     *
     * @public	
     */		
	setLayoutCss : function(layoutCSS)
	{
		this.layoutCSS = layoutCSS;		
		
	}	
	// }}}
	,	
	// {{{ setMenuItemLayoutCss()
    /**
     *	Specify the css file for the menu items
     *
     *  @param String layoutCSS = Name of new css file. 
     *
     * @public	
     */		
	setMenuItemLayoutCss : function(layoutCSS)
	{
		this.menuItemLayoutCss = layoutCSS;		
		
	}	
	// }}}
	,	
	// {{{ setCreateIframesForOldIeBrowsers()
    /**
     *	This method specifies if you want to the script to create iframes behind sub menu groups in order to cover eventual select boxes. This
     *	can be needed if you have users with older IE browsers(prior to version 7) and when there's a chance that a sub menu could appear on top
     *	of a select box.
     *
     *  @param Boolean createIframesForOldIeBrowsers = true if you want the script to create iframes to cover select boxes in older ie browsers.
     *
     * @public	
     */		
	setCreateIframesForOldIeBrowsers : function(createIframesForOldIeBrowsers)
	{
		this.createIframesForOldIeBrowsers = createIframesForOldIeBrowsers;		
		
	}	
	// }}}
	,
	// {{{ addMenuItems()
    /**
     *	Add menu items
     *
     *  @param DHTMLSuite.menuModel menuModel Object of class DHTMLSuite.menuModel which holds menu data 	
     *
     * @public	
     */			
	addMenuItems : function(menuItemObj)
	{
		this.menuItemObj = menuItemObj;	
		this.menuItems = menuItemObj.getItems();
	}
	// }}}
	,
	// {{{ setActiveSubItemsOnMouseOver()
    /**
     *	 Specify if sub menus should be activated on mouse over(i.e. no matter what the menuState property is). 	
     *
     *	@param Boolean activateSubOnMouseOver - Specify if sub menus should be activated on mouse over(i.e. no matter what the menuState property is).
     *
     * @public	
     */		
	setActiveSubItemsOnMouseOver : function(activateSubOnMouseOver)
	{
		this.activeSubItemsOnMouseOver = activateSubOnMouseOver;	
	}
	// }}}
	,
	// {{{ setMenuItemState()
    /**
     *	This method changes the state of the menu bar(expanded or collapsed). This method is called when someone clicks on the arrow at the right of menu items.
     * 	
     *	@param Number menuItemId - ID of the menu item we want to switch state for
     * 	@param String state - New state(example: "disabled")
     *
     * @public	
     */			
	setMenuItemState : function(menuItemId,state)
	{
		this.menuItem_objects[menuItemId].setState(state);
	}
	// }}}	
	,
	// {{{ setMenuItemCssPrefix()
    /**
     *	Specify prefix of css classes used for the menu items. Default css prefix is "DHTMLSuite_". If you wish have some custom styling for some of your menus, 
     *	create a separate css file and replace DHTMLSuite_ for the class names with your new prefix.  This is useful if you want to have two menus on the same page
     *	with different stylings.
     * 	
     *	@param String newCssPrefix - New css prefix for menu items.
     *
     * @public	
     */		
	setMenuItemCssPrefix : function(newCssPrefix)
	{
		this.menuItemCssPrefix = newCssPrefix;
	}
	// }}}
	,	
	// {{{ setCssPrefix()
    /**
     *	Specify prefix of css classes used for the menu bar. Default css prefix is "DHTMLSuite_" and that's the prefix of all css classes inside menu-bar.css(the default css file). 
     *	If you want some custom menu bars, create and include your own css files, replace DHTMLSuite_ in the class names with your own prefix and set the new prefix by calling
     *	this method. This is useful if you want to have two menus on the same page with different stylings.
     * 	
     *	@param String newCssPrefix - New css prefix for the menu bar classes.
     *
     * @public	
     */		
	setCssPrefix : function(newCssPrefix)
	{
		this.cssPrefix = newCssPrefix;
	}
	// }}}
	,
	// {{{ replaceSubMenus()
    /**
     *	This method replaces existing sub menu items with a new subset (To replace all menu items, pass 0 as parentId)
     *
     * 	
     *	@param Number parentId - ID of parent element ( 0 if top node) - if set, all sub elements will be deleted and replaced with the new menu model.
     *	@param menuModel newMenuModel - Reference to object of class menuModel
     *
     * @private	
     */		
	replaceMenuItems : function(parentId,newMenuModel)
	{		
		this.hideSubMenus();	// Hide all sub menus
		this.__deleteMenuItems(parentId);	// Delete old menu items.
		this.menuItemObj.__appendMenuModel(newMenuModel,parentId);	// Appending new menu items to the menu model.
		this.__clearAllMenuItems();
		this.__createMenuItems();
	}	

	// }}}	
	,
	// {{{ deleteMenuItems()
    /**
     *	This method deletes menu items from the menu dynamically
     * 	
     *	@param Number parentId - Parent id - where to append the new items.
     *	@param Boolean includeParent - Should parent element also be deleted, or only sub elements?
     *
     * @public	
     */		
	deleteMenuItems : function(parentId,includeParent)
	{
		this.hideSubMenus();	// Hide all sub menus
		this.__deleteMenuItems(parentId,includeParent);
		this.__clearAllMenuItems();
		this.__createMenuItems();		
	}
	// }}}	
	,
	// {{{ appendMenuItems()
    /**
     *	This method appends menu items to the menu dynamically
     * 	
     *	@param Number parentId - Parent id - where to append the new items.
     *	@param menuModel newMenuModel - Object of type menuModel. This menuModel will be appended as sub elements of defined parentId
     *
     * @public	
     */		
	appendMenuItems : function(parentId,newMenuModel)
	{
		this.hideSubMenus();	// Hide all sub menus
		this.menuItemObj.__appendMenuModel(newMenuModel,parentId);	// Appending new menu items to the menu model.
		this.__clearAllMenuItems();
		this.__createMenuItems();		
	}	
	// }}}	
	,
	// {{{ hideMenuItem()
    /**
     *	This method doesn't delete menu items. it hides them only.
     * 	
     *	@param Number id - Id of the item you want to hide.
     *
     * @public	
     */		
	hideMenuItem : function(id)
	{
		this.menuItem_objects[id].hide();

	}	
	// }}}	
	,
	// {{{ showMenuItem()
    /**
     *	This method shows a menu item. If the item isn't hidden, nothing is done.
     * 	
     *	@param Number id - Id of the item you want to show
     *
     * @public	
     */		
	showMenuItem : function(id)
	{
		this.menuItem_objects[id].show();
	}	
	// }}}
	,
	// {{{ setText()
    /**
     *	Replace the text for a menu item
     * 	
     *	@param Integer id - Id of menu item.
     *	@param String newText - New text for the menu item.
     *
     * @public	
     */		
	setText : function(id,newText)
	{
		this.menuItem_objects[id].setText(newText);
	}		
	// }}}
	,
	// {{{ setIcon()
    /**
     *	Replace menu icon for a menu item. 
     * 	
     *	@param Integer id - Id of menu item.
     *	@param String newPath - Path to new menu icon. Pass blank or false if you want to clear the menu item.
     *
     * @public	
     */		
	setIcon : function(id,newPath)
	{
		this.menuItem_objects[id].setIcon(newPath);
	}	
	// }}}
	,
	// {{{ __clearAllMenuItems()
    /**
     *	Delete HTML elements for all menu items.
     *
     * @private	
     */			
	__clearAllMenuItems : function()
	{
		for(var prop=0;prop<this.menuItemObj.menuItemsOrder.length;prop++){
			var id = this.menuItemObj.menuItemsOrder[prop];
			if(this.submenuGroups[id]){
				this.submenuGroups[id].parentNode.removeChild(this.submenuGroups[id]);
				this.submenuGroups[id] = false;	
			}
			if(this.submenuIframes[id]){
				this.submenuIframes[id].parentNode.removeChild(this.submenuIframes[id]);
				this.submenuIframes[id] = false;
			}	
		}
		this.menuBarObj.innerHTML = '';		
	}
	// }}}
	,
	// {{{ __deleteMenuItems()
    /**
     *	This method deletes menu items from the menu, i.e. menu model and the div elements for these items.
     * 	
     *	@param Number parentId - Parent id - where to start the delete process.
     *
     * @private	
     */		
	__deleteMenuItems : function(parentId,includeParent)
	{
		if(includeParent)this.menuItemObj.__deleteANode(parentId);
		if(!this.submenuGroups[parentId])return;	// No sub items exists.		
		this.menuItem_objects[parentId].__setHasSub(false);	// Delete existing sub menu divs.
		this.menuItemObj.__deleteChildNodes(parentId);	// Delete existing child nodes from menu model
		var groupBox = this.submenuGroups[parentId];
		groupBox.parentNode.removeChild(groupBox);	// Delete sub menu group box. 
		if(this.submenuIframes[parentId]){
			this.submenuIframes[parentId].parentNode.removeChild(this.submenuIframes[parentId]);
		}
		this.submenuGroups.splice(parentId,1);
		this.submenuIframes.splice(parentId,1);
	}
	// }}}	
	,
	// {{{ __changeMenuBarState()
    /**
     *	This method changes the state of the menu bar(expanded or collapsed). This method is called when someone clicks on the arrow at the right of menu items.
     * 	
     *	@param Object obj - Reference to element triggering the action
     *
     * @private	
     */		
	__changeMenuBarState : function(){
		var objectIndex = this.getAttribute('objectRef');
		var obj = DHTMLSuite.variableStorage.arrayOfDhtmlSuiteObjects[objectIndex];
		var parentId = this.id.replace(/[^0-9]/gi,'');		
		var state = obj.menuItem_objects[parentId].getState();
		if(state=='disabled')return;
		obj.menuBarState = !obj.menuBarState;
		if(!obj.menuBarState)obj.hideSubMenus();else{
			obj.hideSubMenus();
			obj.__expandGroup(parentId);
		}
		
	}
	// }}}		
	,
	// {{{ __createDivs()
    /**
     *	Create the main HTML elements for this menu dynamically
     * 	
     *
     * @private	
     */		
	__createDivs : function()
	{
		window.refTomenuBar = this;	// Reference to menu strip object
		
		this.menuBarObj = document.createElement('DIV');	
		this.menuBarObj.className = this.cssPrefix + 'menuBar_' + this.menuItemObj.submenuType[1];
		
		if(!document.getElementById(this.targetId)){
			alert('No target defined for the menu object');
			return;
		}
		// Appending menu bar object as a sub of defined target element.
		var target = document.getElementById(this.targetId);
		target.appendChild(this.menuBarObj);				
	}
	,
	// {{{ hideSubMenus()
    /**
     *	Deactivate all sub menus ( collapse and set state back to regular )
     *	In case you have a menu inside a scrollable container, call this method in an onscroll event for that element
     *	example document.getElementById('textContent').onscroll = menuBar.__hideSubMenus;
     * 	
     *	@param Event e - this variable is present if this method is called from an event. 
     *
     * @public	
     */		
	hideSubMenus : function(e)
	{
		if(this && this.tagName){	/* Method called from event */
			if(document.all)e = event;
			var srcEl = DHTMLSuite.commonObj.getSrcElement(e);
			if(srcEl.tagName.toLowerCase()=='img')srcEl = srcEl.parentNode;
			if(srcEl.className && srcEl.className.indexOf('arrow')>=0){
				return;
			}
		}
		for(var no=0;no<DHTMLSuite.variableStorage.menuBar_highlightedItems.length;no++){
			DHTMLSuite.variableStorage.menuBar_highlightedItems[no].setState('regular');	// Set state back to regular
			DHTMLSuite.variableStorage.menuBar_highlightedItems[no].__hideGroup();	// Hide eventual sub menus
		}	
		DHTMLSuite.variableStorage.menuBar_highlightedItems = new Array();			
	}
	
	,
	// {{{ __expandGroup()
    /**
     *	Expand a group of sub items.
     * 	@param parentId - Id of parent element
     *
     * @private	
     */			
	__expandGroup : function(parentId)
	{
	
		var groupRef = this.submenuGroups[parentId];
		var subDiv = groupRef.getElementsByTagName('DIV')[0];
		
		var numericId = subDiv.id.replace(/[^0-9]/g,'');
		
		groupRef.style.visibility='visible';	// Show menu group.
		if(this.submenuIframes[parentId])this.submenuIframes[parentId].style.visibility = 'visible';	// Show iframe if it exists.
		DHTMLSuite.variableStorage.menuBar_highlightedItems[DHTMLSuite.variableStorage.menuBar_highlightedItems.length] = this.menuItem_objects[numericId];
		this.__positionSubMenu(parentId);
		
		if(DHTMLSuite.clientInfoObj.isOpera){	/* Opera fix in order to get correct height of sub menu group */
			var subDiv = groupRef.getElementsByTagName('DIV')[0];	/* Find first menu item */
			subDiv.className = subDiv.className.replace('_over','_over');	/* By "touching" the class of the menu item, we are able to fix a layout problem in Opera */
		}
	}
	
	,
	// {{{ __activateMenuElements()
    /**
     *	Traverse up the menu items and highlight them.
     * 	
     *
     * @private	
     */			
	__activateMenuElements : function(inputObj,objectRef,firstIteration)
	{
		if(!this.menuBarState && !this.activeSubItemsOnMouseOver)return;	// Menu is not activated and it shouldn't be activated on mouse over.
		var numericId = inputObj.id.replace(/[^0-9]/g,'');	// Get a numeric reference to current menu item.
		
		var state = this.menuItem_objects[numericId].getState();	// Get state of this menu item.
		if(state=='disabled')return;	// This menu item is disabled - return from function without doing anything.		
		
		if(firstIteration && DHTMLSuite.variableStorage.menuBar_highlightedItems.length>0){
			this.hideSubMenus();	// First iteration of this function=> Hide other sub menus. 
		}	
		// What should be the state of this menu item -> If it's the one the mouse is over, state should be "over". If it's a parent element, state should be "active".
		var newState = 'over';
		if(!firstIteration)newState = 'active';	// State should be set to 'over' for the menu item the mouse is currently over.
			
		this.menuItem_objects[numericId].setState(newState);	// Switch state of menu item.
		if(this.submenuGroups[numericId]){	// Sub menu group exists. call the __expandGroup method. 
			this.__expandGroup(numericId);	// Expand sub menu group
		}
		DHTMLSuite.variableStorage.menuBar_highlightedItems[DHTMLSuite.variableStorage.menuBar_highlightedItems.length] = this.menuItem_objects[numericId];	// Save this menu item in the array of highlighted elements.
		if(objectRef.menuItems[numericId].parentId){	// A parent element exists. Call this method over again with parent element as input argument.
			this.__activateMenuElements(objectRef.menuItem_objects[objectRef.menuItems[numericId].parentId].divElement,objectRef,false);
		}
	}
	// }}}	
	,
	// {{{ __createMenuItems()
    /**
     *	Creates the HTML elements for the menu items.
     * 	
     *
     * @private	
     */		
	__createMenuItems : function()
	{
		if(!this.globalObjectIndex)this.globalObjectIndex = DHTMLSuite.variableStorage.arrayOfDhtmlSuiteObjects.length;;
		var index = this.globalObjectIndex;
		DHTMLSuite.variableStorage.arrayOfDhtmlSuiteObjects[index] = this;
	
		// Find first child of the body element. trying to insert the element before first child instead of appending it to the <body> tag, ref: problems in ie
		var firstChild = false;
		var firstChilds = document.getElementsByTagName('DIV');
		if(firstChilds.length>0)firstChild = firstChilds[0]
		
		for(var no=0;no<this.menuItemObj.menuItemsOrder.length;no++){	// Looping through menu items		
			var indexThis = this.menuItemObj.menuItemsOrder[no];				
			if(!this.menuItems[indexThis].id)continue;		
			this.menuItem_objects[this.menuItems[indexThis].id] = new DHTMLSuite.menuItem(); 
			if(this.menuItemCssPrefix)this.menuItem_objects[this.menuItems[indexThis].id].setCssPrefix(this.menuItemCssPrefix);	// Custom css prefix set
			if(this.menuItemLayoutCss)this.menuItem_objects[this.menuItems[indexThis].id].setLayoutCss(this.menuItemLayoutCss);	// Custom css file name
			
			var ref = this.menuItem_objects[this.menuItems[indexThis].id].createItem(this.menuItems[indexThis]); // Create div for this menu item.
		
			// Actiave sub elements when someone moves the mouse over the menu item - exception: not on separators.
			if(!this.menuItems[indexThis].separator)DHTMLSuite.commonObj.addEvent(ref,"mouseover",function(){ DHTMLSuite.variableStorage.arrayOfDhtmlSuiteObjects[index].__activateMenuElements(this,DHTMLSuite.variableStorage.arrayOfDhtmlSuiteObjects[index],true); });	
			
			if(this.menuItem_objects[this.menuItems[indexThis].id].expandElement){	/* Small arrow at the right of the menu item exists - expand subs */
				var expandRef = this.menuItem_objects[this.menuItems[indexThis].id].expandElement;	/* Creating reference to expand div/arrow div */
				var parentId = DHTMLSuite.variableStorage.arrayOfDhtmlSuiteObjects[index].menuItems[indexThis].parentId + '';	// Get parent id.
				var tmpId = expandRef.id.replace(/[^0-9]/gi,'');
				expandRef.setAttribute('objectRef',index);	/* saving the index of this object in the DHTMLSuite.variableStorage array as a property of the tag - We need to do this in order to avoid circular references and thus memory leakage in IE */
				expandRef.objectRef = index;
				expandRef.onclick = this.__changeMenuBarState;
			}
			var target = this.menuBarObj;	// Temporary variable - target of newly created menu item. target can be the main menu object or a sub menu group(see below where target is updated).

			if(this.menuItems[indexThis].depth==1 && this.menuItemObj.submenuType[this.menuItems[indexThis].depth]!='top' && this.menuItemObj.mainMenuGroupWidth){	/* Main menu item group width set */
				var tmpWidth = this.menuItemObj.mainMenuGroupWidth + '';
				if(tmpWidth.indexOf('%')==-1)tmpWidth = tmpWidth + 'px';
				target.style.width = tmpWidth;	
			}
		
			if(this.menuItems[indexThis].depth=='1'){	/* Top level item */
				if(this.menuItemObj.submenuType[this.menuItems[indexThis].depth]=='top'){	/* Type = "top" - menu items side by side */
					ref.style.styleFloat = 'left';				
					ref.style.cssText = 'float:left';						
				}			
			}else{
				if(!this.menuItems[indexThis].depth){
					alert('Error in menu model(depth not defined for a menu item). Remember to call the init() method for the menuModel object.');
					return;
				}
				if(!this.submenuGroups[this.menuItems[indexThis].parentId]){	// Sub menu div doesn't exist - > Create it.
					this.submenuGroups[this.menuItems[indexThis].parentId] = document.createElement('DIV');	
					this.submenuGroups[this.menuItems[indexThis].parentId].style.zIndex = 10000;
					this.submenuGroups[this.menuItems[indexThis].parentId].id = 'DHTMLSuite_menuBarSubGroup' + this.menuItems[indexThis].parentId;
					this.submenuGroups[this.menuItems[indexThis].parentId].style.visibility = 'hidden';	// Initially hidden.
					if(this.menuItemObj.submenuType[this.menuItems[indexThis].depth]=='sub')this.submenuGroups[this.menuItems[indexThis].parentId].className = this.cssPrefix + 'menuBar_sub';
					if(firstChild){
						firstChild.parentNode.insertBefore(this.submenuGroups[this.menuItems[indexThis].parentId],firstChild);
					}else{
						document.body.appendChild(this.submenuGroups[this.menuItems[indexThis].parentId]);
					}
					
					if(DHTMLSuite.clientInfoObj.isMSIE && this.createIframesForOldIeBrowsers){	// Create iframe object in order to conver select boxes in older IE browsers(windows).
						this.submenuIframes[this.menuItems[indexThis].parentId] = document.createElement('<IFRAME src="about:blank" frameborder=0>');
						this.submenuIframes[this.menuItems[indexThis].parentId].id = 'DHTMLSuite_menuBarIframe_' + this.menuItems[indexThis].parentId;
						this.submenuIframes[this.menuItems[indexThis].parentId].style.position = 'absolute';
						this.submenuIframes[this.menuItems[indexThis].parentId].style.zIndex = 9000;
						this.submenuIframes[this.menuItems[indexThis].parentId].style.visibility = 'hidden';
						if(firstChild){
							firstChild.parentNode.insertBefore(this.submenuIframes[this.menuItems[indexThis].parentId],firstChild);
						}else{
							document.body.appendChild(this.submenuIframes[this.menuItems[indexThis].parentId]);
						}						
					}
				}	
				target = this.submenuGroups[this.menuItems[indexThis].parentId];	// Change target of newly created menu item. It should be appended to the sub menu div("A group box").				
			}			
			target.appendChild(ref); // Append menu item to the document.		
			
			if(this.menuItems[indexThis].visible == false)this.hideMenuItem(this.menuItems[indexThis].id);	// Menu item hidden, call the hideMenuItem method.
			if(this.menuItems[indexThis].state != 'regular')this.menuItem_objects[this.menuItems[indexThis].id].setState(this.menuItems[indexThis].state);	// Menu item hidden, call the hideMenuItem method.

		}	
		

		this.__setSizeOfAllSubMenus();	// Set size of all sub menu groups
		this.__positionAllSubMenus();	// Position all sub menu groups.
		if(DHTMLSuite.clientInfoObj.isOpera)this.__fixLayoutOpera();	// Call a function which fixes some layout issues in Opera.		
	}
	// }}}
	,
	// {{{ __fixLayoutOpera()
    /**
     *	A method used to fix the menu layout in Opera. 
     *
     *
     * @private	
     */		
	__fixLayoutOpera : function()
	{
		for(var no=0;no<this.menuItemObj.menuItemsOrder.length;no++){
			var id = this.menuItemObj.menuItemsOrder[no];
			if(!id)continue;
			this.menuItem_objects[id].divElement.className = this.menuItem_objects[id].divElement.className.replace('_regular','_regular');	// Nothing is done but by "touching" the class of the menu items in Opera, we make them appear correctly
		}		
	}
	
	// }}}	
	,
	// {{{ __setSizeOfAllSubMenus()
    /**
     *	*	Walk through all sub menu groups and call the positioning method for each one of them.
     *
     *
     * @private	
     */		
	__setSizeOfAllSubMenus : function()
	{		
		for(var prop in this.submenuGroups){
			this.__setSizeOfSubMenus(prop);
		}			
	}	
	// }}}	
	,	
	// {{{ __positionAllSubMenus()
    /**
     *	Walk through all sub menu groups and call the positioning method for each one of them.
     *
     *
     * @private	
     */		
	__positionAllSubMenus : function()
	{
		for(var prop in this.submenuGroups){
			this.__positionSubMenu(prop);
		}	
		
	}
	// }}}	
	,
	// {{{ __positionSubMenu(parentId)
    /**
     *	Position a sub menu group
     *
     *	@param parentId  	
     *
     * @private	
     */		
	__positionSubMenu : function(parentId)
	{
		try{
			var shortRef = this.submenuGroups[parentId];	
			
			if( shortRef.style.visible == 'hidden' )
		  {
			  shortRef.style.display = 'none';
			  return;
		  }
			else
			  shortRef.style.display = 'block';
			
			var depth = this.menuItems[parentId].depth;
			var dir = this.menuItemObj.submenuType[depth];
			if(dir=='top'){			
				shortRef.style.left = DHTMLSuite.commonObj.getLeftPos(this.menuItem_objects[parentId].divElement) + 'px';
				shortRef.style.top = (DHTMLSuite.commonObj.getTopPos(this.menuItem_objects[parentId].divElement) + this.menuItem_objects[parentId].divElement.offsetHeight) + 'px';
			}else{
              var too_large = DHTMLSuite.commonObj.getLeftPos(this.menuItem_objects[parentId].divElement)
                            + this.menuItem_objects[parentId].divElement.offsetWidth
                            + shortRef.offsetWidth
                            > $('#main_menu_div').width();
              if (too_large)
                shortRef.style.left = (DHTMLSuite.commonObj.getLeftPos(this.menuItem_objects[parentId].divElement) - shortRef.offsetWidth) + 'px';
              else
				shortRef.style.left = (DHTMLSuite.commonObj.getLeftPos(this.menuItem_objects[parentId].divElement) + this.menuItem_objects[parentId].divElement.offsetWidth) + 'px';
				shortRef.style.top = (DHTMLSuite.commonObj.getTopPos(this.menuItem_objects[parentId].divElement)) + 'px';		
			}	
			
			if(DHTMLSuite.clientInfoObj.isMSIE){
				var iframeRef = this.submenuIframes[parentId]
				iframeRef.style.left = shortRef.style.left;
				iframeRef.style.top = shortRef.style.top;
				iframeRef.style.width = shortRef.clientWidth + 'px';
				iframeRef.style.height = shortRef.clientHeight + 'px';
			}
									
		}catch(e){
			
		}		
	}
	// }}}	
	,
	// {{{ __setSizeOfSubMenus(parentId)
    /**
     *	Set size of a sub menu group
     *
     *	@param parentId  	
     *
     * @private	
     */		
	__setSizeOfSubMenus : function(parentId)
	{
		try{
			var shortRef = this.submenuGroups[parentId];			
			var subWidth = Math.max(shortRef.offsetWidth,this.menuItem_objects[parentId].divElement.offsetWidth);
			if(this.menuItems[parentId].submenuWidth)subWidth = this.menuItems[parentId].submenuWidth;
			subWidth = subWidth + '';
			if(subWidth.indexOf('%')==-1)subWidth = subWidth + 'px';
			shortRef.style.width = subWidth;	
			
			if(DHTMLSuite.clientInfoObj.isMSIE){
				this.submenuIframes[parentId].style.width = shortRef.style.width;
				this.submenuIFrames[parentId].style.height = shortRef.style.height;
			}
		}catch(e){
			
		}
		
	}
	// }}}	
	,
	// {{{ __repositionMenu()
    /**
     *	Position menu items.
     * 	
     *
     * @private	
     */		
	__repositionMenu : function(inputObj)
	{
		// self.status = this;
		inputObj.menuBarObj.style.top = document.documentElement.scrollTop + 'px';
		
	}
	
	// }}}	
	,
	// {{{ __menuItemRollOver()
    /**
     *	Position menu items.
     * 	
     *
     * @private	
     */	
	__menuItemRollOver : function(inputObj)
	{
		var numericId = inputObj.id.replace(/[^0-9]/g,'');
		inputObj.className = 'DHTMLSuite_menuBar_menuItem_over_' + this.menuItems[numericId]['depth'];		
	}
	// }}}	
	,	
	// {{{ __menuItemRollOut()
    /**
     *	Position menu items.
     * 	
     *
     * @private	
     */	
	__menuItemRollOut : function(inputObj)
	{		
		var numericId = inputObj.id.replace(/[^0-9]/g,'');
		inputObj.className = 'DHTMLSuite_menuBar_menuItem_' + this.menuItems[numericId]['depth'];		
	}
	// }}}	
	,
	// {{{ __menuNavigate()
    /**
     *	Navigate by click on a menu item
     * 	
     *
     * @private	
     */	
	__menuNavigate : function(inputObj)
	{
		var numericIndex = inputObj.id.replace(/[^0-9]/g,'');
		var url = this.menuItems[numericIndex]['url'];
		if(!url)return;
		alert(this.menuItems[numericIndex]['url']);
		
	}
	// }}}	
	,
    unsetMenuBarState : function() { this.menuBarState = false },
    changeMenuBarState: function (target) {
	   var parentId = target.id.replace(/[^0-9]/gi,'');
	   this.menuBarState = !this.menuBarState;
       this.hideSubMenus();
	   if(this.menuBarState) {
	   	this.__expandGroup(parentId);
       }
    },
	// {{{ __setBasicEvents()
    /**
     *	Set basic events for the menu widget.
     * 	
     *
     * @private	
     */	
	__setBasicEvents : function()
	{
        var menu = this;
        $('div.DHTMLSuite_menuBar_sub').click(function() { menu.hideSubMenus(); menu.unsetMenuBarState() });
        $('div.DHTMLSuite_menuBar_top > div > div[objectref!="0"]').click(function() { menu.changeMenuBarState(this) });
        $('div.DHTMLSuite_menuBar_top').click(function(e) {
          if ($(e.target).attr('class') == 'DHTMLSuite_menuBar_top') { menu.hideSubMenus(); menu.unsetMenuBarState() }
        });
        $('#content').mousedown(function(){
            menu.hideSubMenus();
            menu.menuBarState = false;
        });
	}
}


