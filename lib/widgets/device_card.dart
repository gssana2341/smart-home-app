import 'package:flutter/material.dart';
import '../models/device_status.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';

class DeviceCard extends StatefulWidget {
  final String title;
  final String deviceType;
  final bool isOnline;
  final bool isOn;
  final IconData icon;
  final VoidCallback? onTap;
  final VoidCallback? onToggle;
  final Color? customColor;
  final String? subtitle;
  final bool showToggle;
  final bool isLoading;

  const DeviceCard({
    super.key,
    required this.title,
    required this.deviceType,
    required this.isOnline,
    required this.isOn,
    required this.icon,
    this.onTap,
    this.onToggle,
    this.customColor,
    this.subtitle,
    this.showToggle = true,
    this.isLoading = false,
  });

  @override
  State<DeviceCard> createState() => _DeviceCardState();
}

class _DeviceCardState extends State<DeviceCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color get _primaryColor {
    if (widget.customColor != null) return widget.customColor!;
    
    switch (widget.deviceType.toLowerCase()) {
      case 'light':
        return widget.isOn ? Colors.amber : Colors.grey;
      case 'fan':
        return widget.isOn ? Colors.blue : Colors.grey;
      default:
        return widget.isOn ? AppTheme.primaryColor : Colors.grey;
    }
  }

  Color get _cardColor {
    if (!widget.isOnline) return Colors.grey.shade200;
    return widget.isOn ? _primaryColor.withOpacity(0.1) : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Card(
              elevation: widget.isOnline ? 4 : 2,
              color: isDark 
                  ? (widget.isOn ? _primaryColor.withOpacity(0.2) : theme.cardColor)
                  : _cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: widget.isOnline 
                      ? _primaryColor.withOpacity(0.3)
                      : Colors.grey.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: InkWell(
                onTap: widget.isLoading ? null : widget.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header with icon and status
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: widget.isOnline 
                                  ? _primaryColor.withOpacity(0.2)
                                  : Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              widget.icon,
                              size: 28,
                              color: widget.isOnline 
                                  ? _primaryColor
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: widget.isOnline 
                                        ? null 
                                        : Colors.grey,
                                  ),
                                ),
                                if (widget.subtitle != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.subtitle!,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          // Online/Offline indicator
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: AppHelpers.getStatusColor(widget.isOnline),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Status and control
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'สถานะ',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8, 
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: widget.isOnline
                                            ? (widget.isOn 
                                                ? AppTheme.successColor
                                                : Colors.grey)
                                            : Colors.red,
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        widget.isOnline
                                            ? AppHelpers.getDeviceStatus(widget.isOn)
                                            : 'ไม่เชื่อมต่อ',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          // Toggle switch
                          if (widget.showToggle && widget.isOnline) ...[
                            const SizedBox(width: 12),
                            Column(
                              children: [
                                if (widget.isLoading) ...[
                                  const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ] else ...[
                                  Switch(
                                    value: widget.isOn,
                                    onChanged: widget.onToggle != null 
                                        ? (value) => widget.onToggle!()
                                        : null,
                                    activeColor: _primaryColor,
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// Light Device Card
class LightDeviceCard extends StatelessWidget {
  final DeviceStatus deviceStatus;
  final VoidCallback? onToggle;
  final bool isLoading;

  const LightDeviceCard({
    super.key,
    required this.deviceStatus,
    this.onToggle,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return DeviceCard(
      title: 'ไฟห้อง',
      deviceType: 'light',
      icon: Icons.lightbulb_outline,
      isOnline: deviceStatus.online,
      isOn: deviceStatus.relay1,
      onToggle: onToggle,
      isLoading: isLoading,
      subtitle: deviceStatus.online 
          ? 'พร้อมใช้งาน' 
          : 'ไม่เชื่อมต่อ - ${AppHelpers.formatDateTimeShort(deviceStatus.lastSeen)}',
      customColor: Colors.amber,
    );
  }
}

// Fan Device Card
class FanDeviceCard extends StatelessWidget {
  final DeviceStatus deviceStatus;
  final VoidCallback? onToggle;
  final bool isLoading;

  const FanDeviceCard({
    super.key,
    required this.deviceStatus,
    this.onToggle,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return DeviceCard(
      title: 'พัดลม',
      deviceType: 'fan',
      icon: Icons.air,
      isOnline: deviceStatus.online,
      isOn: deviceStatus.relay2,
      onToggle: onToggle,
      isLoading: isLoading,
      subtitle: deviceStatus.online 
          ? 'พร้อมใช้งาน' 
          : 'ไม่เชื่อมต่อ - ${AppHelpers.formatDateTimeShort(deviceStatus.lastSeen)}',
      customColor: Colors.blue,
    );
  }
}

// Air Conditioner Device Card
class AirConditionerDeviceCard extends StatelessWidget {
  final DeviceStatus deviceStatus;
  final VoidCallback? onToggle;
  final bool isLoading;

  const AirConditionerDeviceCard({
    super.key,
    required this.deviceStatus,
    this.onToggle,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return DeviceCard(
      title: 'แอร์',
      deviceType: 'air_conditioner',
      icon: Icons.ac_unit,
      isOnline: deviceStatus.online,
      isOn: deviceStatus.relay3,
      onToggle: onToggle,
      isLoading: isLoading,
      subtitle: deviceStatus.online 
          ? 'พร้อมใช้งาน' 
          : 'ไม่เชื่อมต่อ - ${AppHelpers.formatDateTimeShort(deviceStatus.lastSeen)}',
      customColor: Colors.cyan,
    );
  }
}

// Water Pump Device Card
class WaterPumpDeviceCard extends StatelessWidget {
  final DeviceStatus deviceStatus;
  final VoidCallback? onToggle;
  final bool isLoading;

  const WaterPumpDeviceCard({
    super.key,
    required this.deviceStatus,
    this.onToggle,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return DeviceCard(
      title: 'ปั๊มน้ำ',
      deviceType: 'water_pump',
      icon: Icons.water,
      isOnline: deviceStatus.online,
      isOn: deviceStatus.relay4,
      onToggle: onToggle,
      isLoading: isLoading,
      subtitle: deviceStatus.online 
          ? 'พร้อมใช้งาน' 
          : 'ไม่เชื่อมต่อ - ${AppHelpers.formatDateTimeShort(deviceStatus.lastSeen)}',
      customColor: Colors.blue[600],
    );
  }
}

// Heater Device Card
class HeaterDeviceCard extends StatelessWidget {
  final DeviceStatus deviceStatus;
  final VoidCallback? onToggle;
  final bool isLoading;

  const HeaterDeviceCard({
    super.key,
    required this.deviceStatus,
    this.onToggle,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return DeviceCard(
      title: 'ฮีทเตอร์',
      deviceType: 'heater',
      icon: Icons.local_fire_department,
      isOnline: deviceStatus.online,
      isOn: deviceStatus.relay5,
      onToggle: onToggle,
      isLoading: isLoading,
      subtitle: deviceStatus.online 
          ? 'พร้อมใช้งาน' 
          : 'ไม่เชื่อมต่อ - ${AppHelpers.formatDateTimeShort(deviceStatus.lastSeen)}',
      customColor: Colors.orange,
    );
  }
}

// Extra Device Card
class ExtraDeviceCard extends StatelessWidget {
  final DeviceStatus deviceStatus;
  final VoidCallback? onToggle;
  final bool isLoading;

  const ExtraDeviceCard({
    super.key,
    required this.deviceStatus,
    this.onToggle,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return DeviceCard(
      title: 'อุปกรณ์เพิ่มเติม',
      deviceType: 'extra_device',
      icon: Icons.device_hub,
      isOnline: deviceStatus.online,
      isOn: deviceStatus.relay6,
      onToggle: onToggle,
      isLoading: isLoading,
      subtitle: deviceStatus.online 
          ? 'พร้อมใช้งาน' 
          : 'ไม่เชื่อมต่อ - ${AppHelpers.formatDateTimeShort(deviceStatus.lastSeen)}',
      customColor: Colors.purple,
    );
  }
}