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

#------------------------------------------- application bundle directory layout

GIMP_APP_DIR=$ARTIFACT_DIR/GIMP.app

GIMP_APP_CON_DIR=$GIMP_APP_DIR/Contents
GIMP_APP_RES_DIR=$GIMP_APP_CON_DIR/Resources
GIMP_APP_BIN_DIR=$GIMP_APP_RES_DIR/bin
GIMP_APP_ETC_DIR=$GIMP_APP_RES_DIR/etc
GIMP_APP_EXE_DIR=$GIMP_APP_CON_DIR/MacOS
GIMP_APP_LIB_DIR=$GIMP_APP_RES_DIR/lib
GIMP_APP_SHR_DIR=$GIMP_APP_RES_DIR/share

### functions ##################################################################

function gimp_get_version
{
  xmllint --xpath "string(//moduleset/autotools[@id='gimp']/branch/@version)" \
    "$SELF_DIR"/jhbuild/gtk-osx-gimp.modules
}

### main #######################################################################

# Nothing here.