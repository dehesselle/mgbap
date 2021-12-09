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

#-------------------------------------------------------- (re-) configure ccache

# This is required when using the precompiled toolset as ccache will not have
# been setup before (it happens in 110-sysprep.sh).

ccache_configure

#------------------------------------------------------- (re-) configure JHBuild

# This allows compiling Inkscape with a different setup than what the toolset
# was built with, most importantly a different SDK.

jhbuild_configure

#----------------------------------------------------- create application bundle

# TODO: investigate why this is necessary
if [ ! -f "$LIB_DIR"/charset.alias ]; then
  cp /usr/lib/charset.alias "$LIB_DIR"
fi

(
  export ARTIFACT_DIR
  jhbuild run gtk-mac-bundler gimp.bundle
)

/usr/libexec/PlistBuddy \
  -c "Set CFBundleShortVersionString '$(gmp_get_version)'" \
  "$GIMP_APP_CON_DIR"/Info.plist

# TODO: needs to be auto-incremented build number
/usr/libexec/PlistBuddy \
  -c "Set CFBundleVersion '1'" \
  "$GIMP_APP_CON_DIR"/Info.plist

# TODO: is there a better way?
ln -s ../../../icons/Adwaita "$GIMP_APP_SHR_DIR"/gimp/*/icons
mv "$GIMP_APP_SHR_DIR"/gimp/*/icons/hicolor/scalable \
   "$GIMP_APP_SHR_DIR"/icons/hicolor
rm -rf "$GIMP_APP_SHR_DIR"/gimp/*/icons/hicolor
ln -s ../../../icons/hicolor "$GIMP_APP_SHR_DIR"/gimp/*/icons

