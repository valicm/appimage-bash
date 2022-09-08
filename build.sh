#!/bin/bash
# MIT License
#
# Copyright (c) 2022 Valentino Međimorec
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
set -e

###############################################################################
# Simplistic script to use with GitHub Actions or standalone                  #
# to build AppImage packages.                                                 #
#                                                                             #
# Standalone usage (require specific properties on app.desktop file )         #
# Always build                          -> bash build.sh                      #
# Check version and build if needed     -> bash build.sh verify               #
# Check AppImage version only           -> bash build.sh verify version-only  #
###############################################################################

# Determine if we're running inside GitHub actions.
GITHUB_RUNNING_ACTION=$GITHUB_ACTIONS

if [ "$GITHUB_RUNNING_ACTION" == false ]; then
  INPUT_VERSION_CHECK=$1
  INPUT_VERSION_ONLY=$2

  if [ -z "$1" ]; then
    INPUT_VERSION_CHECK='force'
  fi

  if [ -z "$2" ]; then
    INPUT_VERSION_ONLY='update'
  fi
fi

# Get GitHub user and repo.
GH_USER="$(echo "$GITHUB_REPOSITORY" | grep -o ".*/" | head -c-2)"
GH_REPO="$(echo "$GITHUB_REPOSITORY" | grep -o "/.*" | cut -c2-)"

echo "==> Setup default variables"
# Setup defaults.
APP_DIRECTORY="AppDir"
BIN_DIRECTORY=$APP_DIRECTORY/usr/bin
rm -rf AppDir

mkdir $BIN_DIRECTORY -p
mkdir -p $APP_DIRECTORY/usr/share/icons/hicolor/{128x128,256x256,512x512}/apps/

# Extract variables from desktop file.
APP_FILENAME=app.desktop
APP_SHORT_NAME=$(sed -n 's/^Name=//p' $APP_FILENAME | head -1)
APP_ICON=$(sed -n 's/^Icon=//p' $APP_FILENAME | head -1)
APP_EXEC=$(sed -n 's/^Exec=//p' $APP_FILENAME | head -1 | cut -d " " -f 1)
APP_NAME=$(sed -n 's/^GenericName=//p' $APP_FILENAME)
APP_DOWNLOAD_URL=$(sed -n 's/^VersionUrl=//p' $APP_FILENAME)
APP_VERSION_FILE=$(sed -n 's/^VersionFile=//p' $APP_FILENAME)
APP_VERSION_BASH=$(sed -n 's/^VersionBash=//p' $APP_FILENAME)
APP_VERSION_ICON=$(sed -n 's/^VersionIcon=//p' $APP_FILENAME)
APP_DEPLOY=$(sed -n 's/^VersionDirectory=//p' $APP_FILENAME)

# For GitHub actions use inputs.
if [ "$GITHUB_RUNNING_ACTION" == true ]
then
  APP_DOWNLOAD_URL=${INPUT_VERSION_URL}
  APP_VERSION_FILE=${INPUT_VERSION_FILE}
  APP_VERSION_BASH=${INPUT_VERSION_BASH}
  APP_VERSION_ICON=${INPUT_VERSION_ICON}
  APP_DEPLOY=${INPUT_VERSION_DIRECTORY}
fi

if [ -z "$APP_DEPLOY" ]; then
  APP_DEPLOY=$BIN_DIRECTORY
else
  APP_DEPLOY=$APP_DIRECTORY/$APP_DEPLOY
  mkdir -p $APP_DEPLOY
fi

if [ -z "$APP_NAME" ]; then
  APP_NAME=$APP_SHORT_NAME
fi

echo "==> Download $APP_SHORT_NAME"
wget -O "$APP_SHORT_NAME".tar.gz "$APP_DOWNLOAD_URL"

echo "==> Extract $APP_SHORT_NAME"
tar -xzvf "$APP_SHORT_NAME".tar.gz --strip-components=1 -C $APP_DEPLOY && rm -r *.tar.gz

echo "==> Check Version $APP_SHORT_NAME"
PACKAGE=$(cat "$APP_DEPLOY"/"$APP_VERSION_FILE")

# Default search for version inside version file, otherwise run specified bash.
if [ -z "$APP_VERSION_BASH" ]; then
  VERSION=$(sed -n 's/^version=//p' $APP_DEPLOY/"$APP_VERSION_FILE")
else
  VERSION=$(echo "$PACKAGE" | $APP_VERSION_BASH)
fi

if [ "$GITHUB_RUNNING_ACTION" == true ]; then
  # If we check only for version here.
  if [ "$INPUT_VERSION_CHECK" == "verify" ]; then
    RELEASE_VERSION=$(gh api -H "Accept: application/vnd.github+json" /repos/"$GH_USER"/"$GH_REPO"/releases/latest | jq -r ".name" | sed 's/'"$APP_NAME"' AppImage //g')

    if [ "$VERSION" = "$RELEASE_VERSION" ]; then
      echo "::set-output name=app_update_needed::false"
      echo "APP_UPDATE_NEEDED=false" >>"$GITHUB_ENV"
      # Always exit here.
      echo "No update needed. Exiting."
      exit 0
    else
      echo "::set-output name=app_update_needed::true"
        echo "Update required."
      echo "APP_UPDATE_NEEDED=true" >>"$GITHUB_ENV"
    fi

    # Exit if there is separate logic for checking version and building AppImage.
    if [ "$INPUT_VERSION_ONLY" == "version-only" ]; then
      # If we need to check version only, return 0 as success.
      echo "Exiting, explicitly requested"
      exit 0
    fi
  else
    echo "APP_UPDATE_NEEDED=true" >>"$GITHUB_ENV"
  fi
fi

echo "==> Check binary $APP_SHORT_NAME"
if [ -f "$BIN_DIRECTORY/$APP_EXEC" ]; then
  echo "Binary exists."
else
  echo "Creating symlink - binary does not exist."
  cd $APP_DIRECTORY
  BIN_PATH=$(find . -type f -name "$APP_EXEC")
  cd ../
  ln -s ../../"$BIN_PATH" $BIN_DIRECTORY/"$APP_EXEC"
fi

echo "==> Fetch default AppRun binary"
wget -O $APP_DIRECTORY/AppRun https://raw.githubusercontent.com/AppImage/AppImageKit/master/resources/AppRun
chmod +x $APP_DIRECTORY/AppRun

echo "==> Setup icons and desktop for $APP_SHORT_NAME AppImage"
# Add defaults which we need for proper app image. Desktop files, icons.
cp $APP_FILENAME $APP_DIRECTORY/"$APP_SHORT_NAME".desktop
sed -i '/VersionUrl/d' $APP_DIRECTORY/"$APP_SHORT_NAME".desktop
sed -i '/VersionFile/d' $APP_DIRECTORY/"$APP_SHORT_NAME".desktop
sed -i '/VersionBash/d' $APP_DIRECTORY/"$APP_SHORT_NAME".desktop
sed -i '/VersionIcon/d' $APP_DIRECTORY/"$APP_SHORT_NAME".desktop
sed -i '/VersionDirectory/d' $APP_DIRECTORY/"$APP_SHORT_NAME".desktop

ICON_PATH=$(find $APP_DEPLOY -type f -name "$APP_VERSION_ICON")
ICON_EXTENSION="${ICON_PATH#*.}"

# Handle svg differently.
if [ "$ICON_EXTENSION" == "svg" ];
then
  cp "$ICON_PATH" $APP_DIRECTORY/"$APP_ICON"."$ICON_EXTENSION"
  cp "$ICON_PATH" $APP_DIRECTORY/usr/share/icons/hicolor/512x512/apps/"$APP_SHORT_NAME"."$ICON_EXTENSION"
  cp "$ICON_PATH" $APP_DIRECTORY/usr/share/icons/hicolor/256x256/apps/"$APP_SHORT_NAME"."$ICON_EXTENSION"
  cp "$ICON_PATH" $APP_DIRECTORY/usr/share/icons/hicolor/128x128/apps/"$APP_SHORT_NAME"."$ICON_EXTENSION"
else
  cp "$ICON_PATH" $APP_DIRECTORY/"$APP_ICON"."$ICON_EXTENSION"
  convert "$ICON_PATH" -resize 512x512 $APP_DIRECTORY/usr/share/icons/hicolor/512x512/apps/"$APP_SHORT_NAME"."$ICON_EXTENSION"
  convert "$ICON_PATH" -resize 256x256 $APP_DIRECTORY/usr/share/icons/hicolor/256x256/apps/"$APP_SHORT_NAME"."$ICON_EXTENSION"
  convert "$ICON_PATH" -resize 128x128 $APP_DIRECTORY/usr/share/icons/hicolor/128x128/apps/"$APP_SHORT_NAME"."$ICON_EXTENSION"
fi

echo "==> Build $APP_SHORT_NAME AppImage"
# Fetch AppImageTool.
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x *.AppImage

if [ "$GITHUB_RUNNING_ACTION" == true ]; then
  ARCH=x86_64 ./appimagetool-x86_64.AppImage --comp gzip "$APP_DIRECTORY" -n -u "gh-releases-zsync|$GH_USER|$GH_REPO|latest|$APP_SHORT_NAME*.AppImage.zsync"
  echo "APP_NAME=$APP_NAME" >> "$GITHUB_ENV"
  echo "APP_SHORT_NAME=$APP_SHORT_NAME" >> "$GITHUB_ENV"
  echo "APP_VERSION=$VERSION" >> "$GITHUB_ENV"
else
  ARCH=x86_64 ./appimagetool-x86_64.AppImage --comp gzip "$APP_DIRECTORY" -n
fi

mkdir dist
mv "$APP_SHORT_NAME"*.AppImage* dist/.
