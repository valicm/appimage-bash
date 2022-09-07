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

# Flag if we want to use this script to check for version.
APP_VERSION_ONLY=$1

if [ -z "$1" ]
  then
    APP_VERSION_ONLY=0;
fi

# Get GitHub user and repo.
GH_USER="$( echo "$GITHUB_REPOSITORY" | grep -o ".*/" | head -c-2 )"
GH_REPO="$( echo "$GITHUB_REPOSITORY" | grep -o "/.*" | cut -c2- )"

echo "==> Setup default variables"
# Setup defaults.
APP_DIRECTORY="AppDir"
BIN_DIRECTORY=$APP_DIRECTORY/usr/bin
rm -rf AppDir

mkdir $BIN_DIRECTORY -p
mkdir -p $APP_DIRECTORY/usr/share/icons/hicolor/{128x128,256x256,512x512}/apps/

# Extract variables from desktop file.
APP_FILENAME=app.desktop
APP_SHORT_NAME=$(sed -n 's/^Name=//p' $APP_FILENAME)
APP_ICON=$(sed -n 's/^Icon=//p' $APP_FILENAME)
APP_DOWNLOAD_URL=$(sed -n 's/^VersionUrl=//p' $APP_FILENAME)
APP_VERSION_FILE=$(sed -n 's/^VersionFile=//p' $APP_FILENAME)
APP_VERSION_BASH=$(sed -n 's/^VersionBash=//p' $APP_FILENAME)
APP_EXEC=$(sed -n 's/^Exec=//p' $APP_FILENAME | cut -d " " -f 1)
APP_DEPLOY=$(sed -n 's/^VersionDirectory=//p' $APP_FILENAME)
APP_NAME=$(sed -n 's/^Name=//p' $APP_FILENAME)

if [ -z "$APP_DEPLOY" ]; then
    APP_DEPLOY=$BIN_DIRECTORY
fi

APP_VERSION_ICON=$(sed -n 's/^VersionIcon=//p' $APP_FILENAME)

echo "==> Download $APP_SHORT_NAME"
wget -O "$APP_SHORT_NAME".tar.gz "$APP_DOWNLOAD_URL"

echo "==> Extract $APP_SHORT_NAME"
tar -xzvf "$APP_SHORT_NAME".tar.gz --strip-components=1 -C $APP_DEPLOY && rm -r *.tar.gz

echo "==> Check Version $APP_SHORT_NAME"
PACKAGE=$(cat $APP_DEPLOY/"$APP_VERSION_FILE")
VERSION=$(echo "$PACKAGE" | $APP_VERSION_BASH)

echo "APP_VERSION=$VERSION" >> "$GITHUB_ENV"

# If we check only for version stop here.
if [ "$APP_VERSION_ONLY" == 1 ]
  then
    RELEASE_VERSION=$(gh api -H "Accept: application/vnd.github+json" /repos/"$GH_USER"/"$GH_REPO"/releases/latest | jq -r  ".name" | sed 's/'"$APP_NAME"' AppImage //g')

    if [ "$VERSION" = "$RELEASE_VERSION" ]; then
        echo "::set-output name=create::false"
    else
        echo "::set-output name=create::true"
    fi

    # If we need to check version only, return 0 as success.
    return 0
fi

echo "==> Check binary $APP_SHORT_NAME"
if [ -f "$BIN_DIRECTORY/$APP_EXEC" ]; then
    echo "Binary exists."
else
    echo "Creating symlink does not exist."
    BIN_PATH=$(find $APP_DEPLOY -type f -name "$APP_EXEC")
    ln -s "$BIN_PATH" $BIN_DIRECTORY/"$APP_EXEC"
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

cp "$ICON_PATH" $APP_DIRECTORY/"$APP_ICON"."$ICON_EXTENSION"
convert "$ICON_PATH" -resize 512x512 $APP_DIRECTORY/usr/share/icons/hicolor/512x512/apps/"$APP_SHORT_NAME"."$ICON_EXTENSION"
convert "$ICON_PATH" -resize 256x256 $APP_DIRECTORY/usr/share/icons/hicolor/256x256/apps/"$APP_SHORT_NAME"."$ICON_EXTENSION"
convert "$ICON_PATH" -resize 128x128 $APP_DIRECTORY/usr/share/icons/hicolor/128x128/apps/"$APP_SHORT_NAME"."$ICON_EXTENSION"

echo "==> Build $APP_SHORT_NAME AppImage"
# Fetch AppImageTool.
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x *.AppImage
ARCH=x86_64 ./appimagetool-x86_64.AppImage --comp gzip "$APP_DIRECTORY" -n -u "gh-releases-zsync|$GH_USER|$GH_REPO|latest|$APP_SHORT_NAME*.AppImage.zsync"
mkdir dist
mv "$APP_SHORT_NAME"*.AppImage* dist/.
