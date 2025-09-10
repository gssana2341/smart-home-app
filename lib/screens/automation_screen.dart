import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/automation_service.dart';
import '../models/automation_rule.dart';
import '../models/automation_condition.dart';
import '../models/automation_action.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';
import '../widgets/automation_rule_card.dart';
import 'create_automation_rule_screen.dart';

class AutomationScreen extends StatefulWidget {
  const AutomationScreen({super.key});

  @override
  State<AutomationScreen> createState() => _AutomationScreenState();
}

class _AutomationScreenState extends State<AutomationScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ออโตเมชั่น'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            onPressed: () => _showHelpDialog(context),
            icon: const Icon(Icons.help_outline),
            tooltip: 'วิธีสร้างกฎ',
          ),
          IconButton(
            onPressed: () => _showManagementDialog(context, Provider.of<AutomationService>(context, listen: false)),
            icon: const Icon(Icons.settings),
            tooltip: 'จัดการกฎ',
          ),
        ],
      ),
      body: Consumer<AutomationService>(
        builder: (context, automationService, child) {
          final rules = automationService.rules;
          final isMonitoring = automationService.isMonitoring;

          return RefreshIndicator(
            onRefresh: () async {
              // Refresh automation data
              setState(() {});
            },
            child: rules.isEmpty
                ? _buildEmptyState(theme)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: rules.length,
                    itemBuilder: (context, index) {
                      final rule = rules[index];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AutomationRuleCard(
                          rule: rule,
                          onToggle: () => _toggleRule(automationService, rule),
                          onEdit: () => _editRule(context, rule),
                          onDelete: () => _deleteRule(automationService, rule),
                        ),
                      );
                    },
                  ),
          );
        },
      ),
    );
  }


  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Simple icon
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.smart_toy_outlined,
                size: 80,
                color: AppTheme.primaryColor,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'ยังไม่มีกฎอัตโนมัติ',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'กดปุ่ม ? ด้านบนเพื่อดูวิธีสร้างกฎ',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.help_outline,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('วิธีสร้างกฎอัตโนมัติ'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpStep('1', 'ไปที่หน้า Dashboard'),
            _buildHelpStep('2', 'กดปุ่ม robot icon ในการ์ดอุปกรณ์'),
            _buildHelpStep('3', 'ตั้งค่าเงื่อนไขและบันทึก'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'สร้างกฎเสร็จแล้วมาจัดการที่นี่',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpStep(String number, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showMonitoringDialog(BuildContext context, AutomationService automationService) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('การตรวจสอบอัตโนมัติ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              automationService.isMonitoring
                  ? 'ระบบกำลังตรวจสอบกฎอัตโนมัติทุก 5 วินาที'
                  : 'ระบบหยุดตรวจสอบกฎอัตโนมัติ',
            ),
            const SizedBox(height: 16),
            Text(
              'กฎที่เปิดใช้งาน: ${automationService.getEnabledRules().length}',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              'กฎทั้งหมด: ${automationService.rules.length}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          ElevatedButton(
            onPressed: () {
              if (automationService.isMonitoring) {
                automationService.stopMonitoring();
              } else {
                automationService.startMonitoring();
              }
              Navigator.pop(context);
            },
            child: Text(
              automationService.isMonitoring ? 'หยุด' : 'เริ่ม',
            ),
          ),
        ],
      ),
    );
  }

  void _showManagementDialog(BuildContext context, AutomationService automationService) {
    final theme = Theme.of(context);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.settings,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('จัดการกฎอัตโนมัติ'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Stats
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildMiniStatCard('ทั้งหมด', '${automationService.rules.length}', Icons.rule, theme),
                      _buildMiniStatCard('เปิด', '${automationService.getEnabledRules().length}', Icons.check_circle, theme),
                      _buildMiniStatCard('ปิด', '${automationService.getDisabledRules().length}', Icons.pause_circle, theme),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '💡 วิธีใช้งาน:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildInstructionItem('🔄', 'กดปุ่มในกฎเพื่อเปิด/ปิด'),
            _buildInstructionItem('✏️', 'กดปุ่มแก้ไขเพื่อแก้ไขกฎ'),
            _buildInstructionItem('🗑️', 'กดปุ่มลบเพื่อลบกฎ'),
            _buildInstructionItem('➕', 'สร้างกฎใหม่ผ่านหน้า Dashboard'),
            _buildInstructionItem('⚡', 'กฎซ้ำกันจะใช้กฎที่มีความสำคัญสูงสุด'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showConflictingRulesDialog(context, automationService);
            },
            icon: const Icon(Icons.warning),
            label: const Text('ดูกฎซ้ำกัน'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showBulkActionsDialog(context, automationService);
            },
            icon: const Icon(Icons.playlist_play),
            label: const Text('จัดการหลายกฎ'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStatCard(String label, String value, IconData icon, ThemeData theme) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 16,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryColor,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildInstructionItem(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _showConflictingRulesDialog(BuildContext context, AutomationService automationService) {
    // Group rules by device type
    final rulesByDevice = <String, List<AutomationRule>>{};
    
    for (final rule in automationService.rules) {
      if (rule.actions.isNotEmpty) {
        final deviceType = rule.actions.first.deviceType;
        if (!rulesByDevice.containsKey(deviceType)) {
          rulesByDevice[deviceType] = [];
        }
        rulesByDevice[deviceType]!.add(rule);
      }
    }
    
    // Find devices with multiple rules
    final conflictingDevices = rulesByDevice.entries
        .where((entry) => entry.value.length > 1)
        .toList();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.warningColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.warning,
                color: AppTheme.warningColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text('กฎซ้ำกัน (${conflictingDevices.length} อุปกรณ์)'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (conflictingDevices.isEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: AppTheme.successColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ไม่มีกฎซ้ำกัน',
                        style: TextStyle(
                          color: AppTheme.successColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              Text(
                'อุปกรณ์ที่มีกฎซ้ำกัน:',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              ...conflictingDevices.map((entry) {
                final deviceType = entry.key;
                final rules = entry.value;
                
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getDeviceTypeName(deviceType),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${rules.length} กฎ',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      ...rules.map((rule) => Padding(
                        padding: const EdgeInsets.only(left: 8, top: 2),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: rule.isEnabled 
                                    ? AppTheme.successColor 
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                rule.name,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: rule.isEnabled 
                                      ? Colors.black87 
                                      : Colors.grey[600],
                                ),
                              ),
                            ),
                            if (rules.indexOf(rule) == 0)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6, 
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'สูงสุด',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppTheme.primaryColor,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ระบบจะใช้กฎที่มีความสำคัญสูงสุดเท่านั้น',
                        style: TextStyle(
                          color: AppTheme.primaryColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ปิด'),
          ),
        ],
      ),
    );
  }

  String _getDeviceTypeName(String deviceType) {
    switch (deviceType) {
      case 'light':
        return 'ไฟ';
      case 'fan':
        return 'พัดลม';
      case 'air_conditioner':
        return 'แอร์';
      case 'water_pump':
        return 'ปั๊มน้ำ';
      case 'heater':
        return 'ฮีทเตอร์';
      case 'extra_device':
        return 'อุปกรณ์เพิ่มเติม';
      default:
        return deviceType;
    }
  }

  void _showBulkActionsDialog(BuildContext context, AutomationService automationService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('จัดการหลายกฎ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow, color: AppTheme.successColor),
              title: const Text('เปิดกฎทั้งหมด'),
              subtitle: const Text('เปิดใช้งานกฎอัตโนมัติทั้งหมด'),
              onTap: () {
                automationService.enableAllRules();
                Navigator.pop(context);
                AppHelpers.showSnackBar(context, 'เปิดกฎทั้งหมดแล้ว');
              },
            ),
            ListTile(
              leading: const Icon(Icons.pause, color: AppTheme.warningColor),
              title: const Text('ปิดกฎทั้งหมด'),
              subtitle: const Text('ปิดใช้งานกฎอัตโนมัติทั้งหมด'),
              onTap: () {
                automationService.disableAllRules();
                Navigator.pop(context);
                AppHelpers.showSnackBar(context, 'ปิดกฎทั้งหมดแล้ว');
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: AppTheme.errorColor),
              title: const Text('ลบกฎทั้งหมด'),
              subtitle: const Text('ลบกฎอัตโนมัติทั้งหมด (ไม่สามารถย้อนกลับได้)'),
              onTap: () {
                Navigator.pop(context);
                _showDeleteAllConfirmDialog(context, automationService);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
        ],
      ),
    );
  }

  void _showDeleteAllConfirmDialog(BuildContext context, AutomationService automationService) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('คุณต้องการลบกฎอัตโนมัติทั้งหมดหรือไม่?\nการกระทำนี้ไม่สามารถย้อนกลับได้'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              automationService.deleteAllRules();
              Navigator.pop(context);
              AppHelpers.showSnackBar(context, 'ลบกฎทั้งหมดแล้ว', isError: true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('ลบทั้งหมด'),
          ),
        ],
      ),
    );
  }

  void _toggleRule(AutomationService automationService, AutomationRule rule) {
    automationService.toggleRule(rule.id);
    AppHelpers.showSnackBar(
      context,
      '${rule.isEnabled ? 'ปิด' : 'เปิด'}กฎ: ${rule.name}',
    );
  }

  void _editRule(BuildContext context, AutomationRule rule) {
    // ใช้ Quick Automation Dialog เหมือนในหน้า Dashboard
    showDialog(
      context: context,
      builder: (context) => _QuickEditAutomationDialog(
        rule: rule,
        onSave: (updatedRule) {
          final automationService = Provider.of<AutomationService>(context, listen: false);
          automationService.updateRule(updatedRule);
          AppHelpers.showSnackBar(context, 'แก้ไขกฎ: ${updatedRule.name}');
        },
      ),
    );
  }

  void _deleteRule(AutomationService automationService, AutomationRule rule) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบกฎอัตโนมัติ'),
        content: Text('คุณต้องการลบกฎ "${rule.name}" หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              automationService.deleteRule(rule.id);
              Navigator.pop(context);
              AppHelpers.showSnackBar(
                context,
                'ลบกฎ: ${rule.name}',
                isError: true,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('ลบ'),
          ),
        ],
      ),
    );
  }
}

// Quick Edit Automation Dialog Widget
class _QuickEditAutomationDialog extends StatefulWidget {
  final AutomationRule rule;
  final Function(AutomationRule) onSave;

  const _QuickEditAutomationDialog({
    required this.rule,
    required this.onSave,
  });

  @override
  State<_QuickEditAutomationDialog> createState() => _QuickEditAutomationDialogState();
}

class _QuickEditAutomationDialogState extends State<_QuickEditAutomationDialog> {
  late String _conditionType;
  late String _operator;
  late double _value;
  late String _action;
  late bool _isEnabled;
  late String _name;
  late String _description;

  @override
  void initState() {
    super.initState();
    // Initialize with existing rule values
    final condition = widget.rule.conditions.isNotEmpty ? widget.rule.conditions.first : null;
    final action = widget.rule.actions.isNotEmpty ? widget.rule.actions.first : null;
    
    _conditionType = condition?.sensorType ?? 'temperature';
    _operator = condition?.operator ?? '>';
    _value = condition?.value ?? 25.0;
    _action = action?.action ?? 'turn_on';
    _isEnabled = widget.rule.isEnabled;
    _name = widget.rule.name;
    _description = widget.rule.description;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.edit, color: AppTheme.primaryColor),
          const SizedBox(width: 8),
          const Text('แก้ไขกฎอัตโนมัติ'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Rule name
            Text(
              'ชื่อกฎ',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _name,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                _name = value;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Rule description
            Text(
              'คำอธิบาย',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: _description,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                _description = value;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Condition type
            Text(
              'เงื่อนไข',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _conditionType,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'temperature', child: Text('อุณหภูมิ')),
                DropdownMenuItem(value: 'humidity', child: Text('ความชื้น')),
                DropdownMenuItem(value: 'gas', child: Text('ก๊าซ')),
                DropdownMenuItem(value: 'time', child: Text('เวลา')),
              ],
              onChanged: (value) {
                setState(() {
                  _conditionType = value ?? 'temperature';
                  // Reset operator and value when condition type changes
                  if (_conditionType == 'time') {
                    _operator = 'after';
                    _value = 18.0; // 18:00
                  } else if (_conditionType == 'temperature') {
                    _operator = '>';
                    _value = 25.0;
                  } else if (_conditionType == 'humidity') {
                    _operator = '>';
                    _value = 50.0;
                  } else if (_conditionType == 'gas') {
                    _operator = '>';
                    _value = 300.0;
                  }
                });
              },
            ),
            
            const SizedBox(height: 12),
            
            // Operator and value
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _operator,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: _getOperatorItems(),
                    onChanged: (value) {
                      setState(() {
                        _operator = value ?? '>';
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    key: ValueKey('${_conditionType}_${_value}'),
                    initialValue: _value.toString(),
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      isDense: true,
                      suffixText: _getUnitText(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (value) {
                      _value = double.tryParse(value) ?? 0.0;
                    },
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Action
            Text(
              'การกระทำ',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _action,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'turn_on', child: Text('เปิด')),
                DropdownMenuItem(value: 'turn_off', child: Text('ปิด')),
              ],
              onChanged: (value) {
                setState(() {
                  _action = value ?? 'turn_on';
                });
              },
            ),
            
            const SizedBox(height: 16),
            
            // Enable switch
            SwitchListTile(
              title: const Text('เปิดใช้งาน'),
              value: _isEnabled,
              onChanged: (value) {
                setState(() {
                  _isEnabled = value;
                });
              },
              activeColor: AppTheme.primaryColor,
              contentPadding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: _saveRule,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('บันทึก'),
        ),
      ],
    );
  }

  List<DropdownMenuItem<String>> _getOperatorItems() {
    if (_conditionType == 'time') {
      return const [
        DropdownMenuItem(value: 'after', child: Text('หลัง')),
        DropdownMenuItem(value: 'before', child: Text('ก่อน')),
      ];
    }
    
    return const [
      DropdownMenuItem(value: '>', child: Text('มากกว่า')),
      DropdownMenuItem(value: '<', child: Text('น้อยกว่า')),
      DropdownMenuItem(value: '>=', child: Text('มากกว่าหรือเท่ากับ')),
      DropdownMenuItem(value: '<=', child: Text('น้อยกว่าหรือเท่ากับ')),
    ];
  }

  String _getUnitText() {
    switch (_conditionType) {
      case 'temperature':
        return '°C';
      case 'humidity':
        return '%';
      case 'gas':
        return '';
      case 'time':
        return ':00';
      default:
        return '';
    }
  }

  void _saveRule() async {
    try {
      // Create updated condition
      final condition = AutomationCondition(
        sensorType: _conditionType,
        operator: _operator,
        value: _value,
        timeCondition: _conditionType == 'time' ? _operator : null,
        description: _conditionType == 'time' ? '${_value.toInt()}:00' : null,
      );
      
      // Create updated action
      final action = AutomationAction(
        deviceType: widget.rule.actions.isNotEmpty ? widget.rule.actions.first.deviceType : 'light',
        action: _action,
      );
      
      // Create updated rule
      final updatedRule = widget.rule.copyWith(
        name: _name,
        description: _description,
        conditions: [condition],
        actions: [action],
        isEnabled: _isEnabled,
      );
      
      widget.onSave(updatedRule);
      
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        AppHelpers.showSnackBar(
          context,
          'เกิดข้อผิดพลาด: $e',
          isError: true,
        );
      }
    }
  }
}
