class VoiceCommand {
  final String id;
  final String command;
  final String result;
  final DateTime timestamp;
  final bool isSuccess;
  final String? errorMessage;

  VoiceCommand({
    required this.id,
    required this.command,
    required this.result,
    required this.timestamp,
    required this.isSuccess,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'command': command,
      'result': result,
      'timestamp': timestamp.toIso8601String(),
      'isSuccess': isSuccess,
      'errorMessage': errorMessage,
    };
  }

  factory VoiceCommand.fromJson(Map<String, dynamic> json) {
    return VoiceCommand(
      id: json['id'],
      command: json['command'],
      result: json['result'],
      timestamp: DateTime.parse(json['timestamp']),
      isSuccess: json['isSuccess'],
      errorMessage: json['errorMessage'],
    );
  }

  VoiceCommand copyWith({
    String? id,
    String? command,
    String? result,
    DateTime? timestamp,
    bool? isSuccess,
    String? errorMessage,
  }) {
    return VoiceCommand(
      id: id ?? this.id,
      command: command ?? this.command,
      result: result ?? this.result,
      timestamp: timestamp ?? this.timestamp,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}
