# Fonts

The Userpilot SDK allows you to use system and custom fonts for rendering experiences, ensuring consistency across your app's UI. The SDK supports dynamic fonts with features like weight adjustment, symbolic traits, and text scaling for Dynamic Type compatibility.

## Overview

The SDK provides a utility to load fonts from multiple sources, including system fonts and custom fonts stored in the app's bundle. This ensures that your selected fonts are applied correctly, even with varying font styles or weights.

## Implementation Details

### Font Retrieval Logic

Font Retrieval Logic
The UIFont extension in the SDK uses the following order to retrieve fonts:

1. **Default System Fonts**: Default iOS fonts, such as Default, Serif, Rounded, and Monospaced.
2. **Custom Fonts in Bundle**: Fonts registered in the app's main.bundle.
3. **System Fonts**: Default iOS fonts, such as SF Pro, Helvetica, and others.

If a custom font is unavailable, the SDK gracefully falls back to a system font that matches the specified style and weight.


### Font Weight Handling

The SDK interprets symbolic traits such as bold or italic to create the desired font weight. A helper method, systemFont(for:fontWeight:size:), ensures the appropriate weight is applied to system fonts when no custom font is available.

### Dynamic Type Support
The UIFontMetrics utility scales fonts dynamically based on text styles like .body or .title1. This ensures accessibility and consistent typography across different devices and user settings.

### Error Logging

If a requested font cannot be found, an error message is logged to help debug issues during SDK development or integration:

```plaintext
Font "fontName" not found!
```
