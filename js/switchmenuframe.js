/* This is used in bin/mozilla/kopf.pl to switch the HTML sidemenu on/off
   2010, Sven Donath, lxo@dexo.de  */

var vSwitch_Menu = 1;

function Switch_Menu(framesize)
{
	if (vSwitch_Menu)
	{
		vSwitch_Menu=false;
                parent.document.getElementById('menuframe').setAttribute('cols','30,*')
	}
	else
	{
		vSwitch_Menu=true;
				framesize = framesize + ',*';
                parent.document.getElementById('menuframe').setAttribute('cols',framesize);
    }
	return;
}
