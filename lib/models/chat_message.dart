class ChatMessage {
  final String id;
  final String message;
  final String response;
  final DateTime timestamp;
  final bool isUser;
  final bool isError;
  final String? errorMessage;
  final bool? isSuccess;

  ChatMessage({
    required this.id,
    required this.message,
    required this.response,
    required this.timestamp,
    required this.isUser,
    this.isError = false,
    this.errorMessage,
    this.isSuccess,
  });

  /// สร้าง ChatMessage จาก JSON
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      message: json['message'] as String,
      response: json['response'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isUser: json['isUser'] as bool,
      isError: json['isError'] as bool? ?? false,
      errorMessage: json['errorMessage'] as String?,
      isSuccess: json['isSuccess'] as bool?,
    );
  }

  /// แปลง ChatMessage เป็น JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'response': response,
      'timestamp': timestamp.toIso8601String(),
      'isUser': isUser,
      'isError': isError,
      'errorMessage': errorMessage,
      'isSuccess': isSuccess,
    };
  }

  /// สร้าง ChatMessage ใหม่โดยเปลี่ยนบางฟิลด์
  ChatMessage copyWith({
    String? id,
    String? message,
    String? response,
    DateTime? timestamp,
    bool? isUser,
    bool? isError,
    String? errorMessage,
    bool? isSuccess,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      message: message ?? this.message,
      response: response ?? this.response,
      timestamp: timestamp ?? this.timestamp,
      isUser: isUser ?? this.isUser,
      isError: isError ?? this.isError,
      errorMessage: errorMessage ?? this.errorMessage,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }

  @override
  String toString() {
    return 'ChatMessage(id: $id, message: $message, response: $response, timestamp: $timestamp, isUser: $isUser, isError: $isError)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ChatMessage &&
        other.id == id &&
        other.message == message &&
        other.response == response &&
        other.timestamp == timestamp &&
        other.isUser == isUser &&
        other.isError == isError;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        message.hashCode ^
        response.hashCode ^
        timestamp.hashCode ^
        isUser.hashCode ^
        isError.hashCode;
  }
}
