# Fonts

The Userpilot SDK allows you to use system and custom fonts for rendering experiences, ensuring consistency across your app's UI. The SDK supports dynamic fonts with features like weight adjustment, symbolic traits, and text scaling for Dynamic Type compatibility.

## Overview

The SDK provides a utility to load fonts from multiple sources, including system fonts and custom fonts stored in the app's bundle. This ensures that your selected fonts are applied correctly, even with varying font styles or weights.

## Implementation Details

### Font Retrieval Logic

The UIFont extension in the SDK uses the following order to retrieve fonts:

1. **Default System Fonts**: Default iOS fonts, such as Default, Serif, Rounded, and Monospaced.
2. **Custom Fonts in Bundle**: A matching `.ttf` or `.otf` file in the app's main bundle that the host app has already registered. The SDK looks for the configured name with `-Regular`, `-Bold`, `-Italic`, or `-BoldItalic` according to the requested traits.
3. **System Fallback**: The system font with the requested symbolic traits.

If a custom font is unavailable, the SDK gracefully falls back to a system font that matches the specified style and weight.


### Font Weight Handling

The SDK interprets symbolic traits such as bold or italic to create the desired font weight. A helper method, systemFont(for:fontWeight:size:), ensures the appropriate weight is applied to system fonts when no custom font is available.

### Dynamic Type Support
For a configured font name, `UIFontMetrics` scales the resolved font using size-based styles: `.caption1` at 15 points or less, `.title1` at 20 points or more, and `.body` between them. Without a configured name, the existing fallback returns the unscaled system font.

### Missing Custom Fonts

The active lookup falls back silently when a custom font file or registration is missing. Register custom fonts in the host app before presenting an experience; lookup does not register them automatically.
