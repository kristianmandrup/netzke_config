# NetzkeConfig

This task helps configure a Netzke app with Netzke submodules and optionally ExtJS for Netzke development and debugging.
  
## Install ## 

<code>gem install netzke_config</code>

## Usage ## 

*Use all defaults*

<code>$ netzke_config</code>

Retrieves and places *netzke* modules in <code>~/netzke/modules</code>.

*Specify location of modules*

<code>$ netzke_config ../my/place</code>

Retrieves and places *netzke* modules in <code>../my/place</code>.

Create symbolic link to extjs library

<code>$ netzke_config --overwrite-all --extjs ~/code/ext-3.2.1/</code>

## Copyright ##

2010 Kristian Mandrup

