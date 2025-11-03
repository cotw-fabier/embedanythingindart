## Responsive design for plugin example apps

- **LayoutBuilder**: Use to make layout decisions based on available space
- **MediaQuery**: Access screen size, orientation, padding via `MediaQuery.of(context)`
- **Flexible Layouts**: Use `Expanded` and `Flexible` in `Row`/`Column` for overflow-safe layouts
- **Wrap Widget**: Use `Wrap` for content that should flow to next line
- **SafeArea**: Wrap content to avoid system UI intrusions (notches, status bars)
- **Platform Conventions**: Respect platform UI conventions when appropriate
- **Orientation Support**: Handle both portrait and landscape orientations
- **SingleChildScrollView**: Use for content that might overflow on smaller screens
- **Test Small Screens**: Ensure content doesn't overflow on smallest supported screen size

## Example

```dart
class ResponsiveDemo extends StatelessWidget {
  const ResponsiveDemo({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 600;

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: isWide
              ? Row(children: _buildContent())
              : Column(children: _buildContent()),
        ),
      ),
    );
  }

  List<Widget> _buildContent() => [
    const Expanded(child: DemoCard()),
    const Expanded(child: DemoCard()),
  ];
}
```

## References

- [Adaptive and Responsive Design](https://docs.flutter.dev/ui/adaptive-responsive)
- [Creating Responsive Apps](https://docs.flutter.dev/ui/layout/responsive/adaptive-responsive)
