#!/bin/sh
java -cp ../../../../../applet.classes com.ccsoft.edit.images.StaticImages > NewStaticImages.java
mv NewStaticImages.java StaticImages.java
