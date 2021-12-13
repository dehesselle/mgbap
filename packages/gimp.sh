# SPDX-FileCopyrightText: 2021 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# This file contains everything related to GIMP.

### shellcheck #################################################################

# shellcheck shell=bash # no shebang as this file is intended to be sourced
# shellcheck disable=SC2034 # multipe vars only used outside this script

### dependencies ###############################################################

# Nothing here.

### variables ##################################################################

#---------------------------------------- Python runtime to be bundled with GIMP

# GIMP will be bundled with its own (customized) Python 3 runtime to make
# the core extensions work out-of-the-box. This is independent from whatever
# Python is running JHBuild or getting built as a dependency.

GIMP_PYTHON_VER_MAJOR=3
GIMP_PYTHON_VER_MINOR=9
GIMP_PYTHON_VER=$GIMP_PYTHON_VER_MAJOR.$GIMP_PYTHON_VER_MINOR
GIMP_PYTHON_URL="https://gitlab.com/api/v4/projects/26780227/packages/generic/\
python_macos/4/python_${GIMP_PYTHON_VER/./}_$(uname -p)_gimp.tar.xz"

#--------------------------------------- Python packages to be bundled with GIMP

# https://pypi.org/project/pycairo/
# https://pypi.org/project/PyGObject/
GIMP_PYTHON_PKG_PYGOBJECT="\
  PyGObject==3.42.0\
  pycairo==1.20.1\
"

#------------------------------------------- application bundle directory layout

GIMP_APP_DIR=$ARTIFACT_DIR/GIMP.app

GIMP_APP_CON_DIR=$GIMP_APP_DIR/Contents
GIMP_APP_RES_DIR=$GIMP_APP_CON_DIR/Resources
GIMP_APP_FRA_DIR=$GIMP_APP_CON_DIR/Frameworks
GIMP_APP_BIN_DIR=$GIMP_APP_RES_DIR/bin
GIMP_APP_ETC_DIR=$GIMP_APP_RES_DIR/etc
GIMP_APP_EXE_DIR=$GIMP_APP_CON_DIR/MacOS
GIMP_APP_LIB_DIR=$GIMP_APP_RES_DIR/lib
GIMP_APP_SHR_DIR=$GIMP_APP_RES_DIR/share
GIMP_APP_SPK_DIR=$GIMP_APP_LIB_DIR/python$GIMP_PYTHON_VER/site-packages

### functions ##################################################################

function gimp_get_version
{
  xmllint --xpath "string(//moduleset/autotools[@id='gimp']/branch/@version)" \
    "$SELF_DIR"/jhbuild/gtk-osx-gimp.modules
}

function gimp_pipinstall
{
  local packages=$1     # list of packages or function name gimp_pipinstall_*
  local options=$2      # optional

  # resolve function name into list of packages
  if [[ $packages = ${FUNCNAME[0]}* ]]; then
    packages=$(tr "[:lower:]" "[:upper:]" <<< "${packages/${FUNCNAME[0]}_/}")
    packages=$(eval echo \$GIMP_PYTHON_PKG_"$packages")
  fi

  # turn package names into filenames of our wheels
  local wheels
  for package in $packages; do
    package=$(eval echo "${package%==*}"*.whl)
    # If present in TMP_DIR, use that. This is how the externally built
    # packages can be fed into this.
    if [ -f "$TMP_DIR/$package" ]; then
      wheels="$wheels $TMP_DIR/$package"
    else
      wheels="$wheels $PKG_DIR/$package"
    fi
  done

  local path_original=$PATH
  export PATH=$GIMP_APP_FRA_DIR/Python.framework/Versions/Current/bin:$PATH

  # shellcheck disable=SC2086 # we need word splitting here
  pip$GIMP_PYTHON_VER_MAJOR install \
    --prefix "$GIMP_APP_RES_DIR" \
    --ignore-installed \
    $options \
    $wheels

  export PATH=$path_original
}

function gimp_pipinstall_pygobject
{
  gimp_pipinstall "${FUNCNAME[0]}"

  lib_change_paths \
    @loader_path/../../.. \
    "$GIMP_APP_LIB_DIR" \
    "$GIMP_APP_SPK_DIR"/gi/_gi.cpython-"${GIMP_PYTHON_VER/./}"-darwin.so \
    "$GIMP_APP_SPK_DIR"/gi/_gi_cairo.cpython-"${GIMP_PYTHON_VER/./}"-darwin.so \
    "$GIMP_APP_SPK_DIR"/cairo/_cairo.cpython-"${GIMP_PYTHON_VER/./}"-darwin.so
}

function gimp_download_python
{
  curl -o "$PKG_DIR"/"$(basename "${GIMP_PYTHON_URL%\?*}")" -L "$GIMP_PYTHON_URL"
}

function gimp_install_python
{
  mkdir "$GIMP_APP_FRA_DIR"
  tar -C "$GIMP_APP_FRA_DIR" -xf "$PKG_DIR"/"$(basename "${GIMP_PYTHON_URL%\?*}")"

  # link it to GIMP_APP_BIN_DIR so it'll be in PATH for the app
  mkdir -p "$GIMP_APP_BIN_DIR"
  # shellcheck disable=SC2086 # it's an integer
  ln -sf ../../Frameworks/Python.framework/Versions/Current/bin/\
python$GIMP_PYTHON_VER_MAJOR "$GIMP_APP_BIN_DIR"

  # create '.pth' file inside Framework to include our site-packages directory
  # shellcheck disable=SC2086 # it's an integer
  echo "../../../../../../../Resources/lib/python$GIMP_PYTHON_VER/site-packages"\
    > "$GIMP_APP_FRA_DIR"/Python.framework/Versions/Current/lib/\
python$GIMP_PYTHON_VER/site-packages/gimp.pth
}

function gimp_build_wheels
{
  jhbuild run pip3 install wheel
  for pkg in ${!GIMP_PYTHON_PKG_*}; do
    # shellcheck disable=SC2046 # we need word splitting here
    jhbuild run pip3 wheel --no-binary :all: $(eval echo \$"$pkg") -w "$PKG_DIR"
  done
}

### main #######################################################################

# Nothing here.