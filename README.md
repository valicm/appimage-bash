# Description

GitHub Action for creating AppImage releases from .tar.gz packages.
It generates AppImage file based on source .tar.gz under git tag _latest_.
- only stable version releases
- only build new release if the new version of source .tar.gz had been released

The GitHub repo needs to have app.desktop file in the root and GitHub action set.
See examples at:
- https://github.com/valicm/Postman-AppImage
- https://github.com/valicm/dbeaver-ce-appimage
- https://github.com/valicm/VSCode-AppImage
- https://github.com/valicm/PhpStorm-AppImage

It can be used as GitHub action, but bash script can be used as standalone outside of GitHub.

# GitHub Action Usage

See [action.yml](action.yml)

```yaml
    steps:
      - uses: actions/checkout@v2
      - name: Build
        id: build
        uses: valicm/appimage-bash@v1.1
        with:
          version_url: 'https://dl.pstmn.io/download/latest/linux64'
          version_file: 'app/resources/app/package.json'
          version_bash: 'jq -r  .version'
          version_icon: 'icon_128x128.png'
```

### Action Inputs
- version_url -> URL where the source .tar.gz can be downloaded
- version_file -> path to the file which contains version string of .tar.gz package
- version_icon -> name of the image file from original .tar.gz to be used as source icon
- version_bash -> bash code to search for version string inside _version_file_
- version_directory -> binary to be placed in different folder than default _usr/bin_
- version_check -> check if the version of source .tar.gz is different from the last GH release
- version_only -> executing only version check, no build performed

# Standalone usage

The bash script can be used as standalone for building AppImage packages.
It relies on app.desktop file having specific properties from where you can define
download url, icon, etc..

### app.desktop properties:
- VersionUrl
- VersionFile
- VersionIcon
- VersionBash
- VersionDirectory

Specification of these properties are same as of action inputs above.

### Standalone usage

#### Get build.sh
`wget https://raw.githubusercontent.com/valicm/appimage-bash/main/build.sh`
`chmod +x build.sh`
#### Create app.desktop
```desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=PhpStorm
Exec=phpstorm.sh %f
Icon=Phpstorm
Comment=PhpStorm
Categories=Development;IDE;
Terminal=false
StartupNotify=true
StartupWMClass=jetbrains-phpstorm

VersionUrl=https://data.services.jetbrains.com/products/download?code=PS&platform=linux
VersionFile=product-info.json
VersionBash=jq -r  .version
VersionIcon=phpstorm.svg
VersionDirectory=opt/phpstorm

```

#### Execute
`bash build.sh`

# License

The scripts and documentation in this project are released under the [MIT License](LICENSE)
