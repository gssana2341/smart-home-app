import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/automation_service.dart';
import '../models/automation_rule.dart';
import '../models/automation_condition.dart';
import '../models/automation_action.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';

class CreateAutomationRuleScreen extends StatefulWidget {
  final AutomationRule? existingRule;

  const CreateAutomationRuleScreen({
    super.key,
    this.existingRule,
  });

  @override
  State<CreateAutomationRuleScreen> createState() => _CreateAutomationRuleScreenState();
}

class _CreateAutomationRuleScreenState extends State<CreateAutomationRuleScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  List<AutomationCondition> _conditions = [];
  List<AutomationAction> _actions = [];
  bool _isEnabled = true;
  String? _category;

  @override
  void initState() {
    super.initState();
    if (widget.existingRule != null) {
      _loadExistingRule();
    } else {
      _addDefaultCondition();
      _addDefaultAction();
    }
  }

  void _loadExistingRule() {
    final rule = widget.existingRule!;
    _nameController.text = rule.name;
    _descriptionController.text = rule.description;
    _conditions = List.from(rule.conditions);
    _actions = List.from(rule.actions);
    _isEnabled = rule.isEnabled;
    _category = rule.category;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.existingRule != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'แก้ไขกฎอัตโนมัติ' : 'สร้างกฎอัตโนมัติ'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _saveRule,
            child: Text(
              'บันทึก',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Basic Information
              _buildBasicInfoSection(theme),
              
              const SizedBox(height: 24),
              
              // Conditions
              _buildConditionsSection(theme),
              
              const SizedBox(height: 24),
              
              // Actions
              _buildActionsSection(theme),
              
              const SizedBox(height: 24),
              
              // Settings
              _buildSettingsSection(theme),
              
              const SizedBox(height: 100), // Bottom padding
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBasicInfoSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ข้อมูลพื้นฐาน',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'ชื่อกฎ',
                hintText: 'เช่น เปิดแอร์เมื่อร้อน',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'กรุณาใส่ชื่อกฎ';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'คำอธิบาย (ไม่บังคับ)',
                hintText: 'อธิบายการทำงานของกฎนี้',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            
            const SizedBox(height: 16),
            
            // Category
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'หมวดหมู่',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'temperature', child: Text('อุณหภูมิ')),
                DropdownMenuItem(value: 'humidity', child: Text('ความชื้น')),
                DropdownMenuItem(value: 'gas', child: Text('ก๊าซ')),
                DropdownMenuItem(value: 'time', child: Text('เวลา')),
                DropdownMenuItem(value: 'combined', child: Text('ผสม')),
              ],
              onChanged: (value) {
                setState(() {
                  _category = value;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionsSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'เงื่อนไข',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _addCondition,
                  icon: const Icon(Icons.add),
                  tooltip: 'เพิ่มเงื่อนไข',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_conditions.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('ไม่มีเงื่อนไข'),
                ),
              )
            else
              ..._conditions.asMap().entries.map((entry) {
                final index = entry.key;
                final condition = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildConditionCard(theme, condition, index),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildConditionCard(ThemeData theme, AutomationCondition condition, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: condition.sensorType,
                  decoration: const InputDecoration(
                    labelText: 'เซ็นเซอร์',
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
                      _conditions[index] = condition.copyWith(sensorType: value ?? '');
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: condition.operator,
                  decoration: const InputDecoration(
                    labelText: 'เงื่อนไข',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: '>', child: Text('มากกว่า')),
                    DropdownMenuItem(value: '<', child: Text('น้อยกว่า')),
                    DropdownMenuItem(value: '>=', child: Text('มากกว่าหรือเท่ากับ')),
                    DropdownMenuItem(value: '<=', child: Text('น้อยกว่าหรือเท่ากับ')),
                    DropdownMenuItem(value: '==', child: Text('เท่ากับ')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _conditions[index] = condition.copyWith(operator: value ?? '');
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: condition.value.toString(),
                  decoration: const InputDecoration(
                    labelText: 'ค่า',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final numValue = double.tryParse(value) ?? 0.0;
                    setState(() {
                      _conditions[index] = condition.copyWith(value: numValue);
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _removeCondition(index),
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'ลบเงื่อนไข',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionsSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'การกระทำ',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _addAction,
                  icon: const Icon(Icons.add),
                  tooltip: 'เพิ่มการกระทำ',
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            if (_actions.isEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text('ไม่มีการกระทำ'),
                ),
              )
            else
              ..._actions.asMap().entries.map((entry) {
                final index = entry.key;
                final action = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildActionCard(theme, action, index),
                );
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard(ThemeData theme, AutomationAction action, int index) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: action.deviceType,
                  decoration: const InputDecoration(
                    labelText: 'อุปกรณ์',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'light', child: Text('ไฟ')),
                    DropdownMenuItem(value: 'fan', child: Text('พัดลม')),
                    DropdownMenuItem(value: 'air_conditioner', child: Text('แอร์')),
                    DropdownMenuItem(value: 'water_pump', child: Text('ปั๊มน้ำ')),
                    DropdownMenuItem(value: 'heater', child: Text('ฮีทเตอร์')),
                    DropdownMenuItem(value: 'extra_device', child: Text('อุปกรณ์เพิ่มเติม')),
                    DropdownMenuItem(value: 'notification', child: Text('การแจ้งเตือน')),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _actions[index] = action.copyWith(deviceType: value ?? '');
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: action.action,
                  decoration: const InputDecoration(
                    labelText: 'การกระทำ',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _getActionItems(action.deviceType),
                  onChanged: (value) {
                    setState(() {
                      _actions[index] = action.copyWith(action: value ?? '');
                    });
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: action.delay.toString(),
                  decoration: const InputDecoration(
                    labelText: 'หน่วงเวลา (วินาที)',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (value) {
                    final delay = int.tryParse(value) ?? 0;
                    setState(() {
                      _actions[index] = action.copyWith(delay: delay);
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _removeAction(index),
                icon: const Icon(Icons.delete, color: Colors.red),
                tooltip: 'ลบการกระทำ',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'การตั้งค่า',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            
            SwitchListTile(
              title: const Text('เปิดใช้งานกฎ'),
              subtitle: const Text('กฎจะทำงานเมื่อเปิดใช้งาน'),
              value: _isEnabled,
              onChanged: (value) {
                setState(() {
                  _isEnabled = value;
                });
              },
              activeColor: AppTheme.primaryColor,
            ),
          ],
        ),
      ),
    );
  }

  List<DropdownMenuItem<String>> _getActionItems(String deviceType) {
    switch (deviceType) {
      case 'notification':
        return const [
          DropdownMenuItem(value: 'send_notification', child: Text('ส่งการแจ้งเตือน')),
        ];
      default:
        return const [
          DropdownMenuItem(value: 'turn_on', child: Text('เปิด')),
          DropdownMenuItem(value: 'turn_off', child: Text('ปิด')),
        ];
    }
  }

  void _addDefaultCondition() {
    _conditions.add(AutomationCondition(
      sensorType: 'temperature',
      operator: '>',
      value: 30.0,
    ));
  }

  void _addDefaultAction() {
    _actions.add(AutomationAction(
      deviceType: 'fan',
      action: 'turn_on',
    ));
  }

  void _addCondition() {
    setState(() {
      _conditions.add(AutomationCondition(
        sensorType: 'temperature',
        operator: '>',
        value: 0.0,
      ));
    });
  }

  void _removeCondition(int index) {
    setState(() {
      _conditions.removeAt(index);
    });
  }

  void _addAction() {
    setState(() {
      _actions.add(AutomationAction(
        deviceType: 'light',
        action: 'turn_on',
      ));
    });
  }

  void _removeAction(int index) {
    setState(() {
      _actions.removeAt(index);
    });
  }

  void _saveRule() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_conditions.isEmpty) {
      AppHelpers.showSnackBar(context, 'กรุณาเพิ่มเงื่อนไขอย่างน้อย 1 ข้อ', isError: true);
      return;
    }
    
    if (_actions.isEmpty) {
      AppHelpers.showSnackBar(context, 'กรุณาเพิ่มการกระทำอย่างน้อย 1 ข้อ', isError: true);
      return;
    }

    try {
      final automationService = Provider.of<AutomationService>(context, listen: false);
      
      final rule = AutomationRule(
        id: widget.existingRule?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        conditions: _conditions,
        actions: _actions,
        isEnabled: _isEnabled,
        createdAt: widget.existingRule?.createdAt ?? DateTime.now(),
        category: _category,
      );

      if (widget.existingRule != null) {
        await automationService.updateRule(rule);
        AppHelpers.showSnackBar(context, 'อัปเดตกฎอัตโนมัติสำเร็จ');
      } else {
        await automationService.addRule(rule);
        AppHelpers.showSnackBar(context, 'สร้างกฎอัตโนมัติสำเร็จ');
      }

      Navigator.pop(context);
    } catch (e) {
      AppHelpers.showSnackBar(context, 'เกิดข้อผิดพลาด: $e', isError: true);
    }
  }
}
