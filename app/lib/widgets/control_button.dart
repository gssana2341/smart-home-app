import 'package:flutter/material.dart';
import '../utils/theme.dart';

class ControlButton extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool isOn;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback? onPressed;
  final Color? primaryColor;
  final Color? secondaryColor;
  final bool showStatus;
  final String? subtitle;
  final double? width;
  final double? height;

  const ControlButton({
    super.key,
    required this.title,
    required this.icon,
    required this.isOn,
    this.isEnabled = true,
    this.isLoading = false,
    this.onPressed,
    this.primaryColor,
    this.secondaryColor,
    this.showStatus = true,
    this.subtitle,
    this.width,
    this.height,
  });

  @override
  State<ControlButton> createState() => _ControlButtonState();
}

class _ControlButtonState extends State<ControlButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 0.1,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color get _primaryColor {
    return widget.primaryColor ?? AppTheme.primaryColor;
  }

  Color get _secondaryColor {
    return widget.secondaryColor ?? AppTheme.secondaryColor;
  }

  Color get _buttonColor {
    if (!widget.isEnabled) return Colors.grey.shade300;
    return widget.isOn ? _primaryColor : Colors.grey.shade200;
  }

  Color get _textColor {
    if (!widget.isEnabled) return Colors.grey.shade600;
    return widget.isOn ? Colors.white : Colors.grey.shade700;
  }

  Color get _iconColor {
    if (!widget.isEnabled) return Colors.grey.shade600;
    return widget.isOn ? Colors.white : _primaryColor;
  }

  void _handleTap() async {
    if (!widget.isEnabled || widget.isLoading) return;

    await _animationController.forward();
    await _animationController.reverse();
    
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Transform.rotate(
            angle: _rotationAnimation.value,
            child: GestureDetector(
              onTap: _handleTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: widget.width,
                height: widget.height ?? 120,
                decoration: BoxDecoration(
                  color: _buttonColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.isOn 
                          ? _primaryColor.withOpacity(0.3)
                          : Colors.grey.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: widget.isOn 
                        ? _primaryColor.withOpacity(0.5)
                        : Colors.grey.withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Background gradient
                    if (widget.isOn) ...[
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              _primaryColor.withOpacity(0.8),
                              _primaryColor,
                            ],
                          ),
                        ),
                      ),
                    ],
                    
                    // Content
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Loading indicator or icon
                          if (widget.isLoading) ...[
                            SizedBox(
                              width: 32,
                              height: 32,
                              child: CircularProgressIndicator(
                                strokeWidth: 3,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  _iconColor,
                                ),
                              ),
                            ),
                          ] else ...[
                            Icon(
                              widget.icon,
                              size: 32,
                              color: _iconColor,
                            ),
                          ],
                          
                          const SizedBox(height: 8),
                          
                          // Title
                          Text(
                            widget.title,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _textColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          
                          // Subtitle
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: _textColor.withOpacity(0.8),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          
                          // Status
                          if (widget.showStatus) ...[
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: widget.isOn 
                                    ? Colors.white.withOpacity(0.2)
                                    : _primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                widget.isOn ? 'เปิด' : 'ปิด',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: widget.isOn 
                                      ? Colors.white
                                      : _primaryColor,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Light Control Button
class LightControlButton extends StatelessWidget {
  final bool isOn;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback? onPressed;

  const LightControlButton({
    super.key,
    required this.isOn,
    this.isEnabled = true,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ControlButton(
      title: 'ไฟห้อง',
      icon: Icons.lightbulb_outline,
      isOn: isOn,
      isEnabled: isEnabled,
      isLoading: isLoading,
      onPressed: onPressed,
      primaryColor: Colors.amber,
      subtitle: isOn ? 'กำลังเปิด' : 'กำลังปิด',
    );
  }
}

// Fan Control Button
class FanControlButton extends StatelessWidget {
  final bool isOn;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback? onPressed;

  const FanControlButton({
    super.key,
    required this.isOn,
    this.isEnabled = true,
    this.isLoading = false,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ControlButton(
      title: 'พัดลม',
      icon: Icons.air,
      isOn: isOn,
      isEnabled: isEnabled,
      isLoading: isLoading,
      onPressed: onPressed,
      primaryColor: Colors.blue,
      subtitle: isOn ? 'กำลังเปิด' : 'กำลังปิด',
    );
  }
}

// Action Control Button
class ActionControlButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final bool isLoading;
  final String? subtitle;

  const ActionControlButton({
    super.key,
    required this.title,
    required this.icon,
    this.onPressed,
    this.color,
    this.isLoading = false,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return ControlButton(
      title: title,
      icon: icon,
      isOn: false,
      isEnabled: !isLoading,
      isLoading: isLoading,
      onPressed: onPressed,
      primaryColor: color ?? AppTheme.accentColor,
      showStatus: false,
      subtitle: subtitle,
    );
  }
}

// Quick Action Buttons Row
class QuickActionButtons extends StatelessWidget {
  final VoidCallback? onRefresh;
  final VoidCallback? onSettings;
  final VoidCallback? onReset;
  final bool isLoading;

  const QuickActionButtons({
    super.key,
    this.onRefresh,
    this.onSettings,
    this.onReset,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ActionControlButton(
            title: 'รีเฟรช',
            icon: Icons.refresh,
            onPressed: onRefresh,
            color: AppTheme.primaryColor,
            isLoading: isLoading,
            subtitle: 'อัปเดตข้อมูล',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ActionControlButton(
            title: 'ตั้งค่า',
            icon: Icons.settings,
            onPressed: onSettings,
            color: AppTheme.secondaryColor,
            subtitle: 'การตั้งค่า',
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ActionControlButton(
            title: 'รีเซ็ต',
            icon: Icons.restart_alt,
            onPressed: onReset,
            color: AppTheme.errorColor,
            subtitle: 'รีเซ็ตระบบ',
          ),
        ),
      ],
    );
  }
}
