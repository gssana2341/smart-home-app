import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/network_service.dart';
import '../utils/theme.dart';

class NetworkStatusWidget extends StatelessWidget {
  final bool showDetails;
  final VoidCallback? onTap;

  const NetworkStatusWidget({
    super.key,
    this.showDetails = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkService>(
      builder: (context, networkService, child) {
        final isConnected = networkService.isConnected;
        final networkType = networkService.currentNetworkType;
        final statusMessage = networkService.getNetworkStatusMessage();
        final networkIcon = networkService.getNetworkIcon();

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _getStatusColor(networkType, isConnected).withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _getStatusColor(networkType, isConnected).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  networkIcon,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(width: 6),
                if (showDetails) ...[
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        statusMessage,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: _getStatusColor(networkType, isConnected),
                        ),
                      ),
                      if (networkService.isWifiConnected && networkService.isMobileConnected)
                        Text(
                          'WiFi + Mobile',
                          style: TextStyle(
                            fontSize: 10,
                            color: _getStatusColor(networkType, isConnected).withOpacity(0.7),
                          ),
                        ),
                    ],
                  ),
                ] else ...[
                  Text(
                    statusMessage,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: _getStatusColor(networkType, isConnected),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getStatusColor(NetworkType networkType, bool isConnected) {
    if (!isConnected) {
      return Colors.red;
    }

    switch (networkType) {
      case NetworkType.wifi:
        return Colors.green;
      case NetworkType.mobile:
        return Colors.orange;
      case NetworkType.ethernet:
        return Colors.blue;
      case NetworkType.none:
        return Colors.red;
      case NetworkType.unknown:
        return Colors.grey;
    }
  }
}

class NetworkStatusIndicator extends StatelessWidget {
  const NetworkStatusIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkService>(
      builder: (context, networkService, child) {
        final isConnected = networkService.isConnected;
        final networkType = networkService.currentNetworkType;

        return Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getIndicatorColor(networkType, isConnected),
            boxShadow: [
              BoxShadow(
                color: _getIndicatorColor(networkType, isConnected).withOpacity(0.3),
                blurRadius: 4,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getIndicatorColor(NetworkType networkType, bool isConnected) {
    if (!isConnected) {
      return Colors.red;
    }

    switch (networkType) {
      case NetworkType.wifi:
        return Colors.green;
      case NetworkType.mobile:
        return Colors.orange;
      case NetworkType.ethernet:
        return Colors.blue;
      case NetworkType.none:
        return Colors.red;
      case NetworkType.unknown:
        return Colors.grey;
    }
  }
}

class NetworkInfoDialog extends StatelessWidget {
  const NetworkInfoDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<NetworkService>(
      builder: (context, networkService, child) {
        return AlertDialog(
          title: Row(
            children: [
              Text(networkService.getNetworkIcon()),
              const SizedBox(width: 8),
              const Text('ข้อมูลเครือข่าย'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoRow('สถานะ', networkService.getNetworkStatusMessage()),
              _buildInfoRow('ประเภท', _getNetworkTypeText(networkService.currentNetworkType)),
              _buildInfoRow('WiFi', networkService.isWifiConnected ? 'เชื่อมต่อ' : 'ไม่เชื่อมต่อ'),
              _buildInfoRow('เน็ตมือถือ', networkService.isMobileConnected ? 'เชื่อมต่อ' : 'ไม่เชื่อมต่อ'),
              _buildInfoRow('Ethernet', networkService.isEthernetConnected ? 'เชื่อมต่อ' : 'ไม่เชื่อมต่อ'),
              _buildInfoRow('เหมาะสำหรับ Real-time', networkService.isNetworkSuitableForRealtime() ? 'ใช่' : 'ไม่'),
              _buildInfoRow('เหมาะสำหรับการใช้งานพื้นฐาน', networkService.isNetworkSuitableForBasic() ? 'ใช่' : 'ไม่'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ปิด'),
            ),
            ElevatedButton(
              onPressed: () async {
                await networkService._checkInternetConnectivity();
                if (context.mounted) {
                  Navigator.of(context).pop();
                }
              },
              child: const Text('ทดสอบใหม่'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _getNetworkTypeText(NetworkType type) {
    switch (type) {
      case NetworkType.wifi:
        return 'WiFi';
      case NetworkType.mobile:
        return 'เน็ตมือถือ';
      case NetworkType.ethernet:
        return 'Ethernet';
      case NetworkType.none:
        return 'ไม่มีการเชื่อมต่อ';
      case NetworkType.unknown:
        return 'ไม่ทราบประเภท';
    }
  }
}
