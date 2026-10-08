# Yippy
macOS open source clipboard manager

This fork of [mattDavo/Yippy](https://github.com/mattDavo/Yippy) adds native Apple silicon support and lets you paste individual entries as plain text without changing your paste preferences.

![screenshot](images/screenshot.jpg)

Upstream website: <a href="https://yippy.mattdavo.com" target="_blank">yippy.mattdavo.com</a>

Upstream development blog: <a href="https://yippy.mattdavo.com/blog" target="_blank">yippy.mattdavo.com/blog</a>

Upstream releases: <a href="https://github.com/mattDavo/Yippy/releases" target="_blank">github.com/mattDavo/Yippy/releases</a>

## Installation
This fork has no public release yet. Installation instructions will accompany the first release.

## Developing Yippy
See the [development guide](docs/development.md) for build and test commands.

### Contributions
All contributions are welcome, whether they are pull requests, bug reports, feature requests or general feedback.

### Project Structure
There are 3 different schemes:
- Yippy
- Yippy Beta
- Yippy XCTest

__Yippy__ is used for running and archiving a production build of Yippy. __Yippy Beta__ is used for development and archiving a beta release. __Yippy XCTest__ is used exclusively for running the unit and UI tests.

### Using `create-installer.sh`
First install <a href="https://github.com/andreyvit/create-dmg" target="_blank">create-dmg</a>. Then place `X.app` in the same folder as `create-installer.sh`. Execute script:
```
./create-installer.sh X
```

You will find the installer disk image `X.dmg` in the same folder.

### TODO
- [ ] Support more types of pasteboard items
- [ ] Allow setting preferences for keyboard shortcuts
    - [x] Customize toggle hotkey
- [ ] Automatic updates (maybe use Sparkle?)
- [ ] Create a bug reporter, if places in code are reached that should not be possible create a unique error and a prompt to report the bug.
- [ ] Don’t let any of the app be used until access is granted
- [x] Toggle for attributed text
- [x] Launch at login
- [x] Convert history storage to storing each piece of data into a file organised by directory of indexes
- [ ] Favourites
- [x] Search (https://github.com/krisk/fuse-swift)
- [x] Max history length
- [ ] Cell height cache improvements. Will improve window size changes and launch time.
    - [ ] Find a cheap way to clear the cell height cache
    - [ ] Store cell heights on disk
