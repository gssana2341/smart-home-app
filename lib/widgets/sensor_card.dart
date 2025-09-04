import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/sensor_data.dart';
import '../models/device_status.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';

class SensorCard extends StatefulWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;
  final String? status;
  final List<SensorData>? chartData;
  final bool showChart;
  final VoidCallback? onTap;

  const SensorCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
    this.status,
    this.chartData,
    this.showChart = false,
    this.onTap,
  });

  @override
  State<SensorCard> createState() => _SensorCardState();
}

class _SensorCardState extends State<SensorCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                onTap: widget.onTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        widget.color.withOpacity(0.1),
                        widget.color.withOpacity(0.05),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: widget.color.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              widget.icon,
                              size: 24,
                              color: widget.color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.title,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (widget.status != null) ...[
                                  const SizedBox(height: 4),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: widget.color.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      widget.status!,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: widget.color,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Value
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            widget.value,
                            style: theme.textTheme.headlineLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: widget.color,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.unit,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      
                      // Chart
                      if (widget.showChart && widget.chartData != null) ...[
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 60,
                          child: _buildMiniChart(),
                        ),
                      ],
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

  Widget _buildMiniChart() {
    if (widget.chartData == null || widget.chartData!.isEmpty) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Center(
          child: Text(
            'ไม่มีข้อมูล',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    List<FlSpot> spots = [];
    double getValue(SensorData data) {
      switch (widget.title) {
        case 'อุณหภูมิ':
          return data.temperature;
        case 'ความชื้น':
          return data.humidity;
        case 'ก๊าซ':
          return data.gasLevel.toDouble();
        default:
          return 0.0;
      }
    }

    for (int i = 0; i < widget.chartData!.length; i++) {
      spots.add(FlSpot(i.toDouble(), getValue(widget.chartData![i])));
    }

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(show: false),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: widget.color,
            barWidth: 2,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: widget.color.withOpacity(0.2),
            ),
          ),
        ],
        minX: 0,
        maxX: (spots.length - 1).toDouble(),
        minY: spots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) - 1,
        maxY: spots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) + 1,
      ),
    );
  }
}

// Temperature Sensor Card
class TemperatureSensorCard extends StatelessWidget {
  final DeviceStatus deviceStatus;
  final List<SensorData>? chartData;
  final bool showChart;
  final VoidCallback? onTap;

  const TemperatureSensorCard({
    super.key,
    required this.deviceStatus,
    this.chartData,
    this.showChart = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SensorCard(
      title: 'อุณหภูมิ',
      value: AppHelpers.formatNumber(deviceStatus.temperature),
      unit: '°C',
      icon: Icons.thermostat,
      color: AppHelpers.getTemperatureColor(deviceStatus.temperature),
      status: AppHelpers.getTemperatureStatus(deviceStatus.temperature),
      chartData: chartData,
      showChart: showChart,
      onTap: onTap,
    );
  }
}

// Humidity Sensor Card
class HumiditySensorCard extends StatelessWidget {
  final DeviceStatus deviceStatus;
  final List<SensorData>? chartData;
  final bool showChart;
  final VoidCallback? onTap;

  const HumiditySensorCard({
    super.key,
    required this.deviceStatus,
    this.chartData,
    this.showChart = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SensorCard(
      title: 'ความชื้น',
      value: AppHelpers.formatNumber(deviceStatus.humidity),
      unit: '%',
      icon: Icons.water_drop,
      color: AppHelpers.getHumidityColor(deviceStatus.humidity),
      status: AppHelpers.getHumidityStatus(deviceStatus.humidity),
      chartData: chartData,
      showChart: showChart,
      onTap: onTap,
    );
  }
}

// Gas Sensor Card
class GasSensorCard extends StatelessWidget {
  final DeviceStatus deviceStatus;
  final List<SensorData>? chartData;
  final bool showChart;
  final VoidCallback? onTap;

  const GasSensorCard({
    super.key,
    required this.deviceStatus,
    this.chartData,
    this.showChart = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SensorCard(
      title: 'ก๊าซ',
      value: deviceStatus.gasLevel.toString(),
      unit: 'ppm',
      icon: Icons.sensors,
      color: AppHelpers.getGasLevelColor(deviceStatus.gasLevel),
      status: AppHelpers.getGasLevelStatus(deviceStatus.gasLevel),
      chartData: chartData,
      showChart: showChart,
      onTap: onTap,
    );
  }
}

// Sensor Overview Card with multiple values
class SensorOverviewCard extends StatelessWidget {
  final DeviceStatus deviceStatus;
  final VoidCallback? onTap;

  const SensorOverviewCard({
    super.key,
    required this.deviceStatus,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.dashboard,
                    color: AppTheme.primaryColor,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'ภาพรวม Sensors',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: _buildSensorItem(
                      context,
                      Icons.thermostat,
                      'อุณหภูมิ',
                      AppHelpers.formatTemperature(deviceStatus.temperature),
                      AppHelpers.getTemperatureColor(deviceStatus.temperature),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSensorItem(
                      context,
                      Icons.water_drop,
                      'ความชื้น',
                      AppHelpers.formatHumidity(deviceStatus.humidity),
                      AppHelpers.getHumidityColor(deviceStatus.humidity),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSensorItem(
                      context,
                      Icons.sensors,
                      'ก๊าซ',
                      AppHelpers.formatGasLevel(deviceStatus.gasLevel),
                      AppHelpers.getGasLevelColor(deviceStatus.gasLevel),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSensorItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color color,
  ) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
