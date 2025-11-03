## Accessibility standards for plugin example apps

- **Color Contrast**: Ensure text has minimum 4.5:1 contrast ratio against background
- **Semantic Labels**: Use `Semantics` widget or `semanticsLabel` to describe interactive elements
- **Screen Reader Testing**: Test with TalkBack (Android) and VoiceOver (iOS) to verify usability
- **Dynamic Text Scaling**: Ensure UI remains usable when users increase system font size
- **Touch Targets**: Make interactive elements at least 48x48 dp for adequate touch target size
- **Semantic Widgets**: Use semantic widgets (`ElevatedButton`, `TextButton`) over generic `GestureDetector`
- **Alternative Text**: Provide `semanticsLabel` for images and icons
- **Form Labels**: Use `InputDecoration.labelText` for proper screen reader support
- **Avoid Color-Only**: Don't rely solely on color; use text labels or icons too
- **Exclude Decorative**: Use `excludeSemantics: true` for purely decorative elements

## Basic Example

```dart
Semantics(
  label: 'Initiate database operation',
  button: true,
  child: ElevatedButton(
    onPressed: _runOperation,
    child: const Text('Run'),
  ),
)
```

## References

- [Flutter Accessibility](https://docs.flutter.dev/ui/accessibility-and-localization/accessibility)
- [WCAG Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
