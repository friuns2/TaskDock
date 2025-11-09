# TaskDock

A macOS application that replicates the Windows taskbar functionality, providing an alternative dock experience for macOS users.

## Features

- Display running applications in a taskbar-like interface
- Group similar windows and show recent active windows
- Clickable grouped windows for easy switching
- Persistent tab ordering for combined display view
- Support for multiple displays

## Building

This project requires Xcode to build. To build and run:

```bash
# Clone the repository
git clone <repository-url>
cd TaskDock

# Open in Xcode
open TaskDock.xcodeproj

# Build and run (⌘R in Xcode)
```

### Alternative build method (from command line):
```bash
# Build the project
xcodebuild -scheme TaskDock -configuration Debug build

# Run the app
open /Users/$(whoami)/Library/Developer/Xcode/DerivedData/TaskDock-*/Build/Products/Debug/TaskDock.app
```

## Requirements

- macOS (tested on recent versions)
- Xcode for development
- Private API access (may require additional entitlements)

## Usage

Launch TaskDock after building. The application will display a taskbar showing your running applications and windows. Click on grouped items to switch between windows.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## License

See LICENSE file for details.
