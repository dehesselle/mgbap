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

#---------------------------------------------------------- adjust icon location

# consolidate icons below 'share/icons' and link to 'share/gimp/<version>/icons'
# TODO: is there a better way?
ln -s ../../../icons/Adwaita "$GIMP_APP_SHR_DIR"/gimp/*/icons
mv "$GIMP_APP_SHR_DIR"/gimp/*/icons/hicolor/scalable \
   "$GIMP_APP_SHR_DIR"/icons/hicolor
rm -rf "$GIMP_APP_SHR_DIR"/gimp/*/icons/hicolor
ln -s ../../../icons/hicolor "$GIMP_APP_SHR_DIR"/gimp/*/icons

#----------------------------------------------------- adjust library link paths

# Add rpath to main binary.
lib_clear_rpath "$GIMP_APP_EXE_DIR"/gimp
lib_add_rpath @executable_path/../Resources/lib "$GIMP_APP_EXE_DIR"/gimp

# Point binaries GIMP_APP_BIN_DIR towards libraries in GIMP_APP_LIB_DIR.
lib_change_paths @executable_path/../lib "$GIMP_APP_LIB_DIR" \
  "$GIMP_APP_BIN_DIR"/gegl \
  "$GIMP_APP_BIN_DIR"/gimp*

# Libraries in GIMP_APP_LIB_DIR can reference each other directly.
lib_change_siblings "$GIMP_APP_LIB_DIR"
lib_change_paths @loader_path "$GIMP_APP_LIB_DIR" \
  "$GIMP_APP_LIB_DIR"/libgs.dylib.9.50   # corner case: non-dylib suffix

# Point GTK modules towards GIMP_APP_LIB_DIR using @loader_path.
lib_change_paths @loader_path/../../.. "$GIMP_APP_LIB_DIR" \
  "$GIMP_APP_LIB_DIR"/gtk-3.0/3.0.0/immodules/*.so \
  "$GIMP_APP_LIB_DIR"/gtk-3.0/3.0.0/printbackends/*.so \
  "$GIMP_APP_LIB_DIR"/gdk-pixbuf-2.0/2.10.0/loaders/*.so \
  "$GIMP_APP_LIB_DIR"/gimp/2.99/modules/*.so

# Point GIO modules towards GIMP_APP_LIB_DIR using @loader_path.
lib_change_paths @loader_path/../.. "$GIMP_APP_LIB_DIR" \
  "$GIMP_APP_LIB_DIR"/gio/modules/*.so

# Point GEGL and babl modules towards GIMP_APP_LIB_DIR using @loader_path.
lib_change_paths @loader_path/.. "$GIMP_APP_LIB_DIR" \
  "$GIMP_APP_LIB_DIR"/babl-0.1/*.dylib \
  "$GIMP_APP_LIB_DIR"/gegl-0.4/*.dylib

# Point plugins towards GIMP_APP_LIB_DIR using @loader_path.
while IFS= read -r -d "" binary; do
  if [[ "$(file "$binary")" != *Python* ]]; then
    lib_change_paths @executable_path/../../../.. "$GIMP_APP_LIB_DIR" "$binary"
    lib_add_rpath @executable_path/../../../.. "$binary"
  fi
done < <(find "$GIMP_APP_LIB_DIR"/gimp/2.99/plug-ins -type f -print0)

#------------------------------------------------------ use rpath in cache files

sed -i '' \
  's/@executable_path\/..\/Resources\/lib/@rpath/g' \
  "$GIMP_APP_LIB_DIR"/gtk-3.0/3.0.0/immodules.cache
sed -i '' \
  's/@executable_path\/..\/Resources\/lib/@rpath/g' \
  "$GIMP_APP_LIB_DIR"/gdk-pixbuf-2.0/2.10.0/loaders.cache

#------------------------------------------------------------- modify Info.plist

/usr/libexec/PlistBuddy \
  -c "Set CFBundleShortVersionString '$(gimp_get_version)'" \
  "$GIMP_APP_CON_DIR"/Info.plist

# TODO: needs to be auto-incremented build number
/usr/libexec/PlistBuddy \
  -c "Set CFBundleVersion '1'" \
  "$GIMP_APP_CON_DIR"/Info.plist

# update minimum system version according to deployment target
/usr/libexec/PlistBuddy \
  -c "Add LSMinimumSystemVersion string '$SYS_SDK_VER'" \
  "$GIMP_APP_CON_DIR"/Info.plist

# add some metadata to make CI identifiable
if $CI_GITLAB; then
  for var in PROJECT_NAME PROJECT_URL COMMIT_BRANCH COMMIT_SHA COMMIT_SHORT_SHA\
             JOB_ID JOB_URL JOB_NAME PIPELINE_ID PIPELINE_URL; do
    # use awk to create camel case strings (e.g. PROJECT_NAME to ProjectName)
    /usr/libexec/PlistBuddy -c "Add CI$(\
      echo $var | awk -F _ '{
        for (i=1; i<=NF; i++)
        printf "%s", toupper(substr($i,1,1)) tolower(substr($i,2))
      }'
    ) string $(eval echo \$CI_$var)" "$GIMP_APP_CON_DIR"/Info.plist
  done
fi

#------------------------------------------------------- add Python and packages

# Install externally built Python framework.
gimp_install_python

# Add rpath to main binaries.
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
gimp_pipinstall_pygobject

# Configure Python interpreter.
mkdir "$GIMP_APP_LIB_DIR"/gimp/2.99/interpreters
cat <<EOF > "$GIMP_APP_LIB_DIR/gimp/2.99/interpreters/pygimp.interp"
python=python3.9
python3=python3.9
/usr/bin/python=python3.9
:Python:E::py::python3.9:
EOF

#-------------------------------------------------------- copy XDG email wrapper

cp "$SELF_DIR"/xdg-email "$GIMP_APP_BIN_DIR"

#-------------------------------------------------- add fontconfig configuration

# Our customized version loses all the non-macOS paths and sets a cache
# directory below '$HOME/Library/Caches/dehesselle.GIMP'.

cp "$SELF_DIR"/fonts.conf "$GIMP_APP_ETC_DIR"/fonts

#-------------------------------- use rpath for GObject introspection repository

for gir in "$GIMP_APP_SHR_DIR"/gir-1.0/*.gir; do
  sed "s/@executable_path\/..\/Resources\/lib/@rpath/g" "$gir" > "$TMP_DIR/$(basename "$gir")"
done

mv "$TMP_DIR"/*.gir "$GIMP_APP_SHR_DIR"/gir-1.0

# compile *.gir into *.typelib files
for gir in "$GIMP_APP_SHR_DIR"/gir-1.0/*.gir; do
  jhbuild run g-ir-compiler \
    -o "$GIMP_APP_LIB_DIR/girepository-1.0/$(basename -s .gir "$gir")".typelib \
    "$gir"
done