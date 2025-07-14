# Environment Configuration

The DahuaNVR app supports configurable default values for the login screen through build-time configuration.

## Configuration Values

The following values can be configured in `DahuaNVR/Info.plist`:

- `DEFAULT_SERVER_URL`: Default server URL for the login screen
- `DEFAULT_USERNAME`: Default username for the login screen  
- `DEFAULT_PASSWORD`: Default password for the login screen (Debug builds only)

## Current Configuration

```xml
<key>DEFAULT_SERVER_URL</key>
<string>http://cam.lab</string>
<key>DEFAULT_USERNAME</key>
<string>admin</string>
<key>DEFAULT_PASSWORD</key>
<string>Minhmeo75321@</string>
```

## Build Behavior

- **Debug builds**: Uses configured values from Info.plist, with fallbacks to hardcoded values
- **Release builds**: Uses configured values from Info.plist, but password defaults to empty string for security

## How to Change Values

1. Open `DahuaNVR/Info.plist`
2. Update the desired configuration keys
3. Build the app - new values will be used automatically

## Security Notes

- The password is only pre-filled in Debug builds for development convenience
- In Release builds, the password field will always start empty regardless of the Info.plist value
- Consider using different Info.plist configurations for different environments if needed