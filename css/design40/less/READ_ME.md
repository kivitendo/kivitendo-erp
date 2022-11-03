# About this less stuff

## What is LESS?
Read this excellent short german overview: http://www.lesscss.de<br>
It is recommended to install lessc/node-less server-side.
LESS contains mainly CSS/LESS statements, and yes!, also pure and
valid CSS-Code is also accepted and compiled. The compiler (lessc) creates
pure and valid css code with your LESS and CSS code.

## How to create a style.css for kivitendo
First set the cursor of your terminal to <code>/css/less/</code> (<code>cd /css/less</code>)<br>
Use following command: <code>lessc style.less ../style.css</code><br>
For minifiying the output css:  <code>lessc -x style.less ../style.css</code><br>
Then a new <code>/css/style.css</code> is created except if errors occur.

## Developing kivitendo CSS (not customizing)
Read style.less.<br>
This is the control center for the whole less stuff.<br>
Variables can be set or changed in variables.less.<br>
Variables are efficacious in the other less files.

## Overriding original stuff
There are several overriding LESS files. Some of the files are for
customizing the original kivitendo LESS stuff.

 * <b>jquery-ui-overrides.less</b> (overrides original jquery css in jquery.less)
 * <b>main-overrides</b> (overrides a lot of kivitendo less/css stuff)
 * <b>custom-variables.less</b> (overrides variables in variable.less)
 * <b>custom.less</b> (overrides all the original kivitendo LESS stuff)

Overriding is useful for occurences of standard elements in a special
context. For example: a standard table occurs in a toggle panel or in other
control panels.

## jQuery and overriding jQuery-CSS
The jQuery LESS stuff contains the original jQuery CSS stuff (pure CSS).
Overriding the jQuery stuff (you can call it customizing for kivitendo) is
the best way to preserve full functionality of the jQuery JS. It is intended
just to change colors, font-sizes & -families etc. with the override-file
(jquery-overrides.less).

If there's a new jQuery-Version just paste the whole CSS code into the
corresponding LESS file. That's (almost) all, folks.

## Customizing kivitendo CSS (not developing)
For customisation do not touch the original (developers) LESS files.<br>
Therefore it is recommended to edit only these two files:

 * <b>custom-variables.less</b> (overrides variables in variable.less)
 * <b>custom.less</b> (overrides in the end all the original kivitendo LESS stuff)

These files can be empty if you do not want to customize the kivitendo CSS
stuff. The original custom files contains only comments and deactivated example
code.

Customization only with these two files gives you comfort in your GIT
habit.

