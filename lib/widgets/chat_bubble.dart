import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/chat_message.dart';
import '../utils/theme.dart';
import '../utils/helpers.dart';

class ChatBubble extends StatefulWidget {
  final ChatMessage message;
  final VoidCallback? onRetry;
  final VoidCallback? onCopy;
  final VoidCallback? onDelete;

  const ChatBubble({
    super.key,
    required this.message,
    this.onRetry,
    this.onCopy,
    this.onDelete,
  });

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  bool _showActions = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 50.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
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
          offset: Offset(
            widget.message.isUser ? -_slideAnimation.value : _slideAnimation.value,
            0,
          ),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Container(
              margin: const EdgeInsets.symmetric(
                vertical: 4,
                horizontal: 16,
              ),
              child: Column(
                crossAxisAlignment: widget.message.isUser
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  // Message bubble
                  GestureDetector(
                    onLongPress: () {
                      setState(() {
                        _showActions = !_showActions;
                      });
                      HapticFeedback.lightImpact();
                    },
                    child: Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                      ),
                      child: widget.message.isUser
                          ? _buildUserMessage(theme, isDark)
                          : _buildBotMessage(theme, isDark),
                    ),
                  ),
                  
                  // Timestamp
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      AppHelpers.formatTime(widget.message.timestamp),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  
                  // Actions
                  if (_showActions) ...[
                    const SizedBox(height: 8),
                    _buildActionButtons(theme),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildUserMessage(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.primaryColor, Color(0xFF1976D2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20).copyWith(
          bottomRight: const Radius.circular(5),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: Text(
        widget.message.message,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildBotMessage(ThemeData theme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bot message
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? theme.colorScheme.surface
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20).copyWith(
              bottomLeft: const Radius.circular(5),
            ),
            border: Border.all(
              color: Colors.grey.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // AI label
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: AppTheme.secondaryColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'AI Assistant',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppTheme.secondaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 8),
              
              // Message content
              if (widget.message.isTyping) ...[
                _buildTypingIndicator(theme),
              ] else if (widget.message.hasError) ...[
                _buildErrorMessage(theme),
              ] else ...[
                Text(
                  widget.message.reply ?? 'ไม่มีการตอบกลับ',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.4,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTypingIndicator(ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ...List.generate(3, (index) {
          return Container(
            margin: EdgeInsets.only(right: index < 2 ? 4 : 0),
            child: _TypingDot(
              delay: Duration(milliseconds: index * 200),
            ),
          );
        }),
        const SizedBox(width: 8),
        Text(
          'กำลังพิมพ์...',
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage(ThemeData theme) {
    return Row(
      children: [
        Icon(
          Icons.error_outline,
          color: AppTheme.errorColor,
          size: 16,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'เกิดข้อผิดพลาดในการส่งข้อความ',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppTheme.errorColor,
            ),
          ),
        ),
        if (widget.onRetry != null) ...[
          const SizedBox(width: 8),
          TextButton(
            onPressed: widget.onRetry,
            child: Text(
              'ลองใหม่',
              style: TextStyle(
                color: AppTheme.errorColor,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionButtons(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.onCopy != null) ...[
            _ActionButton(
              icon: Icons.copy,
              label: 'คัดลอก',
              onPressed: () {
                final textToCopy = widget.message.isUser
                    ? widget.message.message
                    : widget.message.reply ?? '';
                Clipboard.setData(ClipboardData(text: textToCopy));
                AppHelpers.showSnackBar(context, 'คัดลอกข้อความแล้ว');
                setState(() => _showActions = false);
              },
            ),
          ],
          
          if (widget.message.hasError && widget.onRetry != null) ...[
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.refresh,
              label: 'ลองใหม่',
              onPressed: () {
                widget.onRetry?.call();
                setState(() => _showActions = false);
              },
            ),
          ],
          
          if (widget.onDelete != null) ...[
            const SizedBox(width: 8),
            _ActionButton(
              icon: Icons.delete_outline,
              label: 'ลบ',
              color: AppTheme.errorColor,
              onPressed: () {
                widget.onDelete?.call();
                setState(() => _showActions = false);
              },
            ),
          ],
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final Color? color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final buttonColor = color ?? theme.colorScheme.primary;

    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 16,
        color: buttonColor,
      ),
      label: Text(
        label,
        style: TextStyle(
          color: buttonColor,
          fontSize: 12,
        ),
      ),
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}

class _TypingDot extends StatefulWidget {
  final Duration delay;

  const _TypingDot({required this.delay});

  @override
  State<_TypingDot> createState() => _TypingDotState();
}

class _TypingDotState extends State<_TypingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _animation = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));

    // Start animation after delay
    Future.delayed(widget.delay, () {
      if (mounted) {
        _controller.repeat(reverse: true);
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor,
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}

// Welcome message widget
class WelcomeChatBubble extends StatelessWidget {
  const WelcomeChatBubble({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.symmetric(
        vertical: 8,
        horizontal: 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.secondaryColor, Color(0xFF388E3C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.secondaryColor.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.smart_toy,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Smart Home AI Assistant',
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                Text(
                  'สวัสดีครับ! ผมคือ AI Assistant สำหรับระบบ Smart Home ของคุณ\n\nคุณสามารถสอบถามเกี่ยวกับ:\n• สถานะอุปกรณ์ต่างๆ\n• ข้อมูล sensors\n• การควบคุมไฟและพัดลม\n• คำแนะนำการใช้งาน',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 4),
          
          Text(
            AppHelpers.formatTime(DateTime.now()),
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
