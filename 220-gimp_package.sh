#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2021 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# Package GIMP as application bundle.

### shellcheck #################################################################

# Nothing here.

### dependencies ###############################################################

# shellcheck disable=SC1090 # can't point to a single source here
for script in "$(dirname "${BASH_SOURCE[0]}")"/0??-*.sh; do
  source "$script";
done

### variables ##################################################################

# Nothing here.

### functions ##################################################################

# Nothing here.

### main #######################################################################

error_trace_enable

#----------------------------------------------------- create application bundle

# TODO: investigate why this is necessary
if [ ! -f "$LIB_DIR"/charset.alias ]; then
  cp /usr/lib/charset.alias "$LIB_DIR"
fi

(
  export ARTIFACT_DIR
  jhbuild run gtk-mac-bundler gimp.bundle
)

# TODO: is there a better way?
ln -s ../../../icons/Adwaita "$GIMP_APP_SHR_DIR"/gimp/*/icons
mv "$GIMP_APP_SHR_DIR"/gimp/*/icons/hicolor/scalable \
   "$GIMP_APP_SHR_DIR"/icons/hicolor
rm -rf "$GIMP_APP_SHR_DIR"/gimp/*/icons/hicolor
ln -s ../../../icons/hicolor "$GIMP_APP_SHR_DIR"/gimp/*/icons

#------------------------------------------------------------- modify Info.plist

/usr/libexec/PlistBuddy \
  -c "Set CFBundleShortVersionString '$(gimp_get_version)'" \
  "$GIMP_APP_CON_DIR"/Info.plist

# TODO: needs to be auto-incremented build number
/usr/libexec/PlistBuddy \
  -c "Set CFBundleVersion '1'" \
  "$GIMP_APP_CON_DIR"/Info.plist

#------------------------------------------------------- add Python and packages

# Install externally built Python framework.
gimp_install_python

# Add rpath to find libraries.
lib_add_rpath @executable_path/../../../../../Resources/lib \
  "$GIMP_APP_FRA_DIR"/Python.framework/Versions/Current/bin/\
python"$GIMP_PYTHON_VER"
lib_add_rpath @executable_path/../../../../../../../../Resources/lib \
  "$GIMP_APP_FRA_DIR"/Python.framework/Versions/Current/Resources/\
Python.app/Contents/MacOS/Python

# Exteract the externally built wheels if present. Wheels in TMP_DIR
# will take precedence over the ones in PKG_DIR.
if [ -f "$PKG_DIR"/wheels.tar.xz ]; then
  tar -C "$TMP_DIR" -xf "$PKG_DIR"/wheels.tar.xz
else
  echo_w "not using externally built wheels"
fi

# Install wheels.
#gimp_pipinstall_pygobject
