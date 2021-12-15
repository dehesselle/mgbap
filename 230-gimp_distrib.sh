#!/usr/bin/env bash
#
# SPDX-FileCopyrightText: 2021 René de Hesselle <dehesselle@web.de>
#
# SPDX-License-Identifier: GPL-2.0-or-later

### description ################################################################

# Create a disk image for distribution.

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

# Create background for development snapshots. This is not meant for
# official releases, those will be repackaged eventually (they also need
# to be signed and notarized).
LD_LIBRARY_PATH=$LIB_DIR convert -size 560x400 xc:transparent \
  -font Andale-Mono -pointsize 64 -fill black \
  -draw "text 20,60 'GIMP'" \
  -draw "text 20,120 '$(gimp_get_version)'" \
  -draw "text 20,180 '*unofficial*'" \
  "$SRC_DIR"/gimp_dmg.png

# Create the disk image.
dmgbuild_run "$ARTIFACT_DIR"/GIMP.dmg
