fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios set_privacy

```sh
[bundle exec] fastlane ios set_privacy
```

Publish app data usage declaration (no data collected)

### ios build

```sh
[bundle exec] fastlane ios build
```

Build for App Store distribution

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight for internal testing

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Upload screenshots to App Store Connect

### ios upload

```sh
[bundle exec] fastlane ios upload
```

Upload binary and metadata to App Store Connect (no review)

### ios testflight

```sh
[bundle exec] fastlane ios testflight
```

Upload existing IPA to TestFlight and add internal tester

### ios submit

```sh
[bundle exec] fastlane ios submit
```

Submit current build for App Store review

### ios release

```sh
[bundle exec] fastlane ios release
```

Full release: build → TestFlight → metadata → submit

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
