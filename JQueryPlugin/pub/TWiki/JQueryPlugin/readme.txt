Build instructions for new jquery, jquery-ui and jquery plugin releases releases:

1. jQuery root directory: This JQueryPlugin's attachment directory, e.g.

   $JQUERY_ROOT =  $TWIKIROOT/pub/TWiki/JQueryPlugin/

2. Download the latest jquery library from http://docs.jquery.com/Downloading_jQuery
into $JQUERY_ROOT, e.g.:

   wget http://code.jquery.com/jquery-1.5.1.min.js
   wget http://code.jquery.com/jquery-1.5.1.js

3. Copy the minified jquery library to generic name:

   cp -p jquery-1.5.1.min.js jquery.js

4. Download the themes shipped with JQueryPlugin from http://jqueryui.com/download
into temporary directory $JQUERY_ROOT/tmp/. The downloaded theme package has
always the same name, regardless of the theme name. Unzip the packages in the tmp
directory, selected [A]ll to overwrite duplicate names.

5. Move jquery-ui js library from tmp to jQuery root:

   mv tmp/js/jquery-ui-1.8.10.custom.min.js .

6. Copy the minified jquery-ui library to generic name:

   cp -p jquery-ui-1.8.10.custom.min.js jquery-ui.js

7. Move jquery-ui themes from tmp to themes directory:

   mv tmp/css/* themes/

8. Copy the theme css files with version to generic name:

   mv themes/black-tie/jquery-ui-1.8.10.custom.css themes/black-tie/jquery-ui.cupertino.css
   mv themes/cupertino/jquery-ui-1.8.10.custom.css themes/cupertino/jquery-ui.cupertino.css
   # etc...

8. Move i18n files from tmp to i18n directory:

   mv tmp/development-bundle/ui/i18n/* i18n/

9. To update jquery plugins: Copy plugin to tmp directory and unpack, example: jquery.foobar.zip

   mv tmp/jquery.foobar.css .
   mv tmp/jquery.foobar.js jquery.foobar.uncompressed.js
   /var/www/tools/minifyjs jquery.foobar.uncompressed.js > jquery.foobar.js

10. Make jquery-all.css and jquery-all.js

   make clean
   make
   # this will create the targets based on Makefile rule

