<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:html="http://www.w3.org/1999/xhtml"
    xmlns:svg="http://www.w3.org/2000/svg"
    xmlns="http://www.mozilla.org/keymaster/gatekeeper/there.is.only.xul">
<xsl:output media-type="application/vnd.mozilla.xul+xml"/>
<xsl:template match="/">
  <xsl:choose>
    <xsl:when test="system-property('xsl:vendor')='Transformiix'">

      <xsl:apply-templates/>
    </xsl:when>
    <xsl:otherwise>
      <xsl:apply-templates mode="html"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>

<xsl:template match="doc" mode="html">
  <html xmlns="http://www.w3.org/1999/xhtml">
    <head>
      <meta http-equiv="refresh" content="2;url=menuv3.pl?action=display"/>
    </head>
    <body>
Ihr Browser unterstuetzt kein XUL!<br/>
wenn die automatische weiterleitung nicht funktioniert klicken sie <a href="menuv3.pl?action=display">hier</a>
    </body>
  </html>
</xsl:template>

<!-- main document structure -->
<!-- ******************************************************************* -->
<xsl:template match="doc">
<xsl:processing-instruction name="xml-stylesheet">href="xslt/style1.css" type="text/css"</xsl:processing-instruction>
  <xsl:variable name="callback"><xsl:value-of select='/doc/callback'/></xsl:variable>
  <xsl:variable name="title">
      LX-Office Version <xsl:value-of select='/doc/version'/>
      - <xsl:value-of select='/doc/name'/>
      - <xsl:value-of select='/doc/db'/>
    </xsl:variable>
   <!-- <xsl:call-template name="style"/>-->
  <window title="{$title}">
  <html:title/>
    <xsl:call-template name="script"/>
    <toolbox>
      <xsl:apply-templates select="menu"/>
      <xsl:apply-templates select="favorites"/>
    </toolbox>
    <hbox flex="1">
      <vbox id="sidebar" style="overflow:hidden">

        <xsl:apply-templates mode="tree" select="menu"/>

        <xsl:call-template name="ArtikelSuche"/>
        <!--<iframe src="xslt/trans.xml" flex="1" id="uhr"/>-->
      </vbox>
      <splitter state="open" collapse="before" resizeafter="farthest"><grippy/></splitter>
          <html:iframe id="main_window" src="{$callback}" flex="1" style="border:0px"/>
    </hbox>
  </window>
</xsl:template>
<!-- ******************************************************************* -->


<!-- the top menu -->
<!-- ******************************************************************* -->
<xsl:template match="menu"><menubar id="sample-menubar" flex="1"><xsl:apply-templates/></menubar></xsl:template>
<!-- ******************************************************************* -->


<!-- favorites toolbar -->
<!-- ******************************************************************* -->
<xsl:template match="favorites">
  <toolbar id="favoriten" >
    <xsl:call-template name="specialbuttons"/>
    <toolbarseparator/>
    <xsl:for-each select="link">
      <xsl:variable name="name" select="@name"/>
      <xsl:choose>
        <xsl:when test="/*//item[@id=$name]/item">
          <toolbarbutton type="menu" label="{$name}" tooltiptext="A simple popup" link="{/*//item[@id=$name]/@link}" oncommand="openLink(event)">
            <image src="image/icons/24x24/{/*//item[@id=$name]/@id}.png" width="24" height="24" />
            <menupopup id="file-popup">
              <xsl:apply-templates select="/*//item[@id=$name]/*"/>
            </menupopup>
          </toolbarbutton>
        </xsl:when>
        <xsl:otherwise>
          <toolbarbutton label="{$name}" tooltiptext="A simple popup" link="{/*//item[@id=$name]/@link}" oncommand="openLink(event)" lxid="{/*//item[@id=$name]/@id}">
            <image src="image/icons/24x24/{/*//item[@id=$name]/@id}.png" width="24" height="24" />
          </toolbarbutton>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:for-each>
    <toolbarspring flex="1"/>
    <xsl:call-template name="searchbox"/>

  </toolbar>
</xsl:template>
<!-- ******************************************************************* -->


<!-- template for the top menu items
*********************************************************************************  -->
<xsl:template match="item">
 <xsl:choose>
  <xsl:when test="item">
   <menu id="{@name}_menu" label="{@name}" class="menu-iconic" image="image/icons/16x16/{@id}.png">
    <menupopup id="file-popup">
     <xsl:apply-templates/>
    </menupopup>
   </menu>
  </xsl:when>
  <xsl:otherwise>
   <menuitem target="{@target}" link="{@link}" label="{@name}" oncommand="openLink(event)" class="menuitem-iconic" image="image/icons/16x16/{@id}.png" lxid="{@id}" onclick="openLinkNewTab(event)"/>
  </xsl:otherwise>
 </xsl:choose>
</xsl:template>
<!-- ***************************************************************************  -->


<!-- templates for the treeview
**********************************************************************************   -->
<xsl:template match="menu" mode="tree">
<toolbar>
<label value="Hauptmenue"/>
</toolbar>
  <tree flex="1" onselect="openTreeLink(event)" style="margin:0px;" hidecolumnpicker="true">
    <treecols>
        <treecol hideheader="true" id="menuepunkt"  primary="true" flex="1" />
    </treecols>
    <treechildren>
      <xsl:apply-templates mode="tree"/>
    </treechildren>
  </tree>
</xsl:template>

<xsl:template match="item" mode="tree">
  <xsl:choose>
    <xsl:when test="item">
        <treeitem container="true" open="false">
          <treerow>
            <treecell label="{@name}" src="image/icons/16x16/{@id}.png"/>
          </treerow>
          <treechildren>
            <xsl:apply-templates mode="tree"/>
          </treechildren>
        </treeitem>
    </xsl:when>
    <xsl:otherwise>
    <treeitem link="{@link}">
      <treerow>
        <treecell label="{@name}" src="image/icons/16x16/{@id}.png"/>
      </treerow>
    </treeitem>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
<!-- ***************************************************************************  -->


<!-- template fuer die uhr
********************************************************************************  -->
<xsl:template name="uhr">

</xsl:template>
<!-- ***************************************************************************  -->


<!-- scripts
********************************************************************************  -->
<xsl:template name="script">
  <html:script type="text/ecmascript">

  function openLink(event)
    {
    var path=event.target.getAttribute("link")
    if(event.target.getAttribute("target")=="_top")
      {
        window.location=path
      }
      else
      {
        var bf=document.getElementsByTagNameNS("http://www.w3.org/1999/xhtml","iframe").item(0)
        bf.setAttribute("src",path)
      }
    }

  function openLinkNewTab(event)
    {
    if(event.button!=1) return
    var path=event.target.getAttribute("link")
    if(event.target.getAttribute("target")=="_top")
      {
        window.location=path
      }
      else
      {
window.open(path,"_new","")

      }
    }


  function openLinkNewWindow(event)
    {
      var path=event.target.getAttribute("link")
      window.open(path,"_blank","")
    }

  function openTreeLink(event)
    {
      var tree=event.target
      var selIndex=tree.currentIndex
      var item=tree.view.getItemAtIndex(selIndex)
      var link=item.getAttribute("link")
      if(link) document.getElementById("main_window").setAttribute("src",link)
    }

  function updateClock()
    {
      var d= new Date()
      var sec=d.getSeconds()
      var min=d.getMinutes()
      var std=(d.getHours() % 12 ) + min/60
      document.getElementById("std").setAttribute("transform","rotate("+std*30+",20,20)")
      document.getElementById("min").setAttribute("transform","rotate("+min*6+",20,20)")
      document.getElementById("sec").setAttribute("transform","rotate("+sec*6+",20,20)")
    }

  function PrintW()
    {
      document.getElementById("main_window").contentWindow.print()
    }

  function doSearch(){
  var t=document.getElementById("searchboxtext").value
  document.getElementById("desc").value=t
  document.getElementById("sb").click()

  }
  function checkEnter(event){
  if(event.keyCode==13) doSearch()
  }
  //setInterval("updateClock()",1000)
  function MyGoBack(){
document.getElementById("main_window").contentWindow.history.back()
}
  function MyGoForward(){
document.getElementById("main_window").contentWindow.history.forward()
}
  </html:script>
</xsl:template>
<!-- ***************************************************************************  -->

<!-- special buttons ( logout , print, open new window )
The tooltips, like tooltiptext="Neues Fenster", do not appear in my Firefox/Prism browsers. Why?
https://developer.mozilla.org/en/XUL_Tutorial/Popup_Menus
https://developer.mozilla.org/en/XUL/Attribute/tooltiptext
****************************************************************************  -->
<xsl:template name="specialbuttons">
    <toolbarbutton image="image/icons/24x24/Batch Printing.png" oncommand="PrintW(event)" tooltiptext="Drucken"/>
    <toolbarbutton image="image/icons/24x24/Neues Fenster.png" tooltiptext="Neues Fenster" link="menuXML.pl?action=display" target="_top" oncommand="openLinkNewWindow(event)"/>
    <toolbarbutton image="image/icons/24x24/Program--Logout.png" link="{/*//item[@id='Program--Logout']/@link}" target="_top" oncommand="openLink(event)" tooltiptext="Abmelden"/>
  <toolbarseparator/>
    <toolbarbutton image="image/icons/24x24/leftarrow_24.png" tooltiptext="Schritt zurück" oncommand="MyGoBack()"/>
    <toolbarbutton image="image/icons/24x24/rightarrow_24.png" tooltiptext="Schritt vor" oncommand="MyGoForward()"/>
</xsl:template>
<!-- ***************************************************************************  -->


<!-- searchbox
****************************************************************************  -->
<xsl:template name="searchbox">
<vbox style="padding-top:2px">
  <hbox>
    <textbox style="font-size:11px;margin-right:0px" width="200px" id="searchboxtext" onkeypress="checkEnter(event)"/> 
    <toolbarbutton type="toolbar" width="20" height="20" style="padding:5px !important" image="image/icons/16x16/CRM--Schnellsuche.png" flex="0" oncommand="doSearch()"/>
</hbox>

</vbox>
</xsl:template>
<!-- ***************************************************************************  -->


<!-- hidden form for article search
****************************************************************************  -->
<xsl:template name="ArtikelSuche">
  <form id="aform" method="post" action="ic.pl" xmlns="http://www.w3.org/1999/xhtml" target="main_window" style="font-family:arial;font-size:12px;display:none">
  <input name="partnumber" size="20"/>
  <input name="description" flex="1" id="desc"/>
  <input name="partsgroup" size="20"/>
  <input name="make" size="20"/>
  <input class="submit" type="submit" name="action" value="Weiter" id="sb"/>
  <div style="display:none" >
  <input class="submit" type="submit" name="action" value="Top 100"/>
    <input type="hidden" name="serialnumber" size="20"/>
    <input type="hidden" name="ean" size="20"/>
    <input type="hidden" name="searchitems" value="part"/>
    <input type="hidden" name="title" value="Waren"/>
    <input type="hidden" name="revers" value="0"/>
    <input type="hidden" name="lastsort" value=""/>
    <input type="hidden" name="model" size="20"/>
    <input type="hidden" name="drawing" size="20"/>
    <input type="hidden" name="microfiche" size="20"/>
    <input  name="itemstatus" class="radio" type="radio" value="active" checked="true"/>
    <input name="itemstatus" class="radio" type="radio" value="onhand"/>
    <input  name="itemstatus" class="radio" type="radio" value="short"/>
    <input  name="itemstatus" class="radio" type="radio" value="obsolete"/>
    <input  name="itemstatus" class="radio" type="radio" value="orphaned"/>
    <input  name="bought" class="checkbox" type="checkbox" value="1"/>
    <input  name="sold" class="checkbox" type="checkbox" value="1"/>
    <input  name="onorder" class="checkbox" type="checkbox" value="1"/>
    <input  name="ordered" class="checkbox" type="checkbox" value="1"/>
    <input  name="rfq" class="checkbox" type="checkbox" value="1"/>Anfrage
    <input  name="quoted" class="checkbox" type="checkbox" value="1"/>Angeboten
    <input type="hidden" name="transdatefrom" id="transdatefrom" size="11" title="dd.mm.yy"/>
    <input  type="button" name="transdatefrom" id="trigger1" value="?"/>
    <input name="transdateto" id="transdateto" size="11" title="dd.mm.yy"/>
    <input type="button" name="transdateto" id="trigger2" value="?"/>
    <input name="l_partnumber" class="checkbox" type="checkbox" value="Y" checked="true"/>Artikelnummer
    <input name="l_description" class="checkbox" type="checkbox" value="Y" checked="true"/>Artikelbeschreibung
    <input name="l_serialnumber" class="checkbox" type="checkbox" value="Y"/>Seriennummer
    <input name="l_unit" class="checkbox" type="checkbox" value="Y" checked="true"/>Maszeinheit
    <input name="l_listprice" class="checkbox" type="checkbox" value="Y"/>Listenpreis
    <input name="l_sellprice" class="checkbox" type="checkbox" value="Y" checked="true"/>Verkaufspreis
    <input name="l_lastcost" class="checkbox" type="checkbox" value="Y" checked="true"/>Einkaufspreis
    <input name="l_linetotal" class="checkbox" type="checkbox" value="Y" checked="true"/>Zeilensumme
    <input name="l_priceupdate" class="checkbox" type="checkbox" value="Y"/>Erneuert am
    <input name="l_bin" class="checkbox" type="checkbox" value="Y"/>Lagerplatz
    <input name="l_rop" class="checkbox" type="checkbox" value="Y"/>Mindestlagerbestand
    <input name="l_weight" class="checkbox" type="checkbox" value="Y"/>Gewicht
    <input name="l_image" class="checkbox" type="checkbox" value="Y"/>Grafik
    <input name="l_drawing" class="checkbox" type="checkbox" value="Y"/>Zeichnung
    <input name="l_microfiche" class="checkbox" type="checkbox" value="Y"/>Mikrofilm
    <input name="l_partsgroup" class="checkbox" type="checkbox" value="Y"/>Warengruppe
    <input name="l_subtotal" class="checkbox" type="checkbox" value="Y"/>Zwischensumme
    <input name="l_soldtotal" class="checkbox" type="checkbox" value="Y"/>Verkaufte Anzahl
    <input name="l_deliverydate" class="checkbox" type="checkbox" value="Y"/>Lieferdatum
    <input type="hidden" name="nextsub" value="generate_report"/>
    <input type="hidden" name="revers" value="0"/>
    <input type="hidden" name="lastsort" value=""/>
    <input type="hidden" name="sort" value="description"/>
    <input type="hidden" name="ndxs_counter" value="0"/>
  </div>
  </form>
</xsl:template>
<!-- ***************************************************************************  -->
</xsl:stylesheet>
