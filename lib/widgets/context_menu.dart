import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A customizable context menu that appears at the position where the user right-clicks or long-presses
class ContextMenu extends StatelessWidget {
  final Offset position;
  final List<ContextMenuItem> menuItems;
  final double maxWidth;
  final double itemHeight;
  final Color? backgroundColor;
  final BorderRadius? borderRadius;
  final EdgeInsets padding;

  const ContextMenu({
    super.key,
    required this.position,
    required this.menuItems,
    this.maxWidth = 200,
    this.itemHeight = 45,
    this.backgroundColor,
    this.borderRadius,
    this.padding = const EdgeInsets.symmetric(vertical: 8.0),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final safeArea = MediaQuery.of(context).size;
    final defaultBgColor = theme.cardColor.withOpacity(0.95);

    // Calculate position to ensure menu stays within screen bounds
    final double xPosition =
        position.dx + maxWidth > safeArea.width
            ? position.dx - maxWidth
            : position.dx;

    // Calculate available height and adjust y position if needed
    final totalMenuHeight = menuItems.length * itemHeight + padding.vertical;
    final double yPosition =
        position.dy + totalMenuHeight > safeArea.height
            ? position.dy - totalMenuHeight
            : position.dy;

    return Stack(
      children: [
        // Invisible fullscreen touch detector to close menu on outside tap
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),

        // The menu itself
        Positioned(
          left: xPosition,
          top: yPosition,
          child: Material(
            elevation: 8,
            shadowColor: Colors.black38,
            color: backgroundColor ?? defaultBgColor,
            borderRadius: borderRadius ?? BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicWidth(
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: 150, maxWidth: maxWidth),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: padding,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _buildMenuItems(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildMenuItems(BuildContext context) {
    final List<Widget> items = [];

    for (int i = 0; i < menuItems.length; i++) {
      // Add menu item
      items.add(_buildMenuItem(context, menuItems[i]));

      // Add divider if not the last item and divider is requested
      if (i < menuItems.length - 1 && menuItems[i].addDivider) {
        items.add(const Divider(height: 1, thickness: 1));
      }
    }

    return items;
  }

  Widget _buildMenuItem(BuildContext context, ContextMenuItem item) {
    final bool isEnabled = item.isEnabled;
    final Color textColor =
        isEnabled
            ? item.textColor ?? Theme.of(context).textTheme.bodyMedium!.color!
            : Theme.of(context).disabledColor;

    return InkWell(
      onTap:
          isEnabled
              ? () {
                // Close the menu first
                Navigator.of(context).pop();
                // Then execute the action
                item.onPressed?.call();
                // Provide haptic feedback
                HapticFeedback.lightImpact();
              }
              : null,
      child: Container(
        height: itemHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            if (item.icon != null) ...[
              Icon(
                item.icon,
                size: 20,
                color:
                    isEnabled
                        ? item.iconColor ?? textColor
                        : Theme.of(context).disabledColor,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                item.title,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: item.isBold ? FontWeight.bold : FontWeight.normal,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (item.trailingIcon != null) ...[
              const SizedBox(width: 8),
              Icon(
                item.trailingIcon,
                size: 16,
                color:
                    isEnabled
                        ? item.iconColor ?? textColor
                        : Theme.of(context).disabledColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Individual item in the context menu
class ContextMenuItem {
  final String title;
  final IconData? icon;
  final IconData? trailingIcon;
  final VoidCallback? onPressed;
  final bool isEnabled;
  final bool addDivider;
  final bool isBold;
  final Color? textColor;
  final Color? iconColor;

  const ContextMenuItem({
    required this.title,
    this.icon,
    this.trailingIcon,
    this.onPressed,
    this.isEnabled = true,
    this.addDivider = false,
    this.isBold = false,
    this.textColor,
    this.iconColor,
  });
}

/// Shows a context menu at the specified position
Future<void> showContextMenu({
  required BuildContext context,
  required Offset position,
  required List<ContextMenuItem> menuItems,
  Color? backgroundColor,
  BorderRadius? borderRadius,
  double? maxWidth,
}) async {
  // Show a dialog containing our context menu
  return showDialog(
    context: context,
    barrierColor: Colors.transparent,
    builder:
        (context) => ContextMenu(
          position: position,
          menuItems: menuItems,
          backgroundColor: backgroundColor,
          borderRadius: borderRadius,
          maxWidth: maxWidth ?? 200,
        ),
  );
}
