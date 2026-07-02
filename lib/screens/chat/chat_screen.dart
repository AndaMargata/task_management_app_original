import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../models/chat_message.dart';
import '../../services/storage_service.dart';
import '../../utils/responsive.dart';
import '../common/full_screen_image_viewer.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final String otherUserName;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.otherUserName,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _messageFocusNode = FocusNode();
  final _imagePicker = ImagePicker();
  int _previousMessageCount = 0;
  ChatViewmodel? _chatVm;

  bool _isUploading = false;
  double _uploadProgress = 0;

  final _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _chatVm = context.read<ChatViewmodel>();
        _chatVm!.openConversation(widget.conversationId);
      }
    });
  }

  @override
  void dispose() {
    _chatVm?.closeConversation();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    context.read<ChatViewmodel>().sendMessage(text);
    _messageController.clear();
    _messageFocusNode.requestFocus();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final file = await _imagePicker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1920,
    );
    if (file == null) return;
    await _uploadAndSend(File(file.path), MessageType.image, '.jpg');
  }

  Future<void> _pickVideo(ImageSource source) async {
    final file = await _imagePicker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 3),
    );
    if (file == null) return;
    await _uploadAndSend(File(file.path), MessageType.video, '.mp4');
  }

  Future<void> _uploadAndSend(File file, String type, String ext) async {
    final chatVm = context.read<ChatViewmodel>();
    final userId = chatVm.currentUserId;
    if (userId == null) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0;
    });

    try {
      final url = await StorageService.uploadFile(
        file: file,
        folder: 'chat_media',
        userId: userId,
        ext: ext,
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );

      if (mounted) {
        setState(() => _isUploading = false);
      }

      if (url != null && mounted) {
        await chatVm.sendMessage('', type: type, mediaUrl: url);
      }
    } catch (e) {
      debugPrint('Chat upload error: $e');
      if (mounted) {
        setState(() => _isUploading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send media: $e')),
        );
      }
    }
  }

  void _showAttachmentOptions() {
    final cs = Theme.of(context).colorScheme;
    final r = Responsive(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(r.s(20))),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(r.s(24), r.s(12), r.s(24), r.s(16)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text('Share Media',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: cs.onSurface,
                  )),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _AttachOption(
                    icon: Icons.photo_library_rounded,
                    label: 'Gallery',
                    color: Colors.purple,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.gallery);
                    },
                  ),
                  _AttachOption(
                    icon: Icons.camera_alt_rounded,
                    label: 'Camera',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickImage(ImageSource.camera);
                    },
                  ),
                  _AttachOption(
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(ctx);
                      _pickVideo(ImageSource.gallery);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startRecording() async {
    try {
      if (!await _audioRecorder.hasPermission()) return;

      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordDuration = Duration.zero;
      });

      _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() => _recordDuration += const Duration(seconds: 1));
      });
    } catch (e) {
      debugPrint('Start recording error: $e');
    }
  }

  Future<void> _stopAndSendRecording() async {
    _recordTimer?.cancel();
    try {
      final path = await _audioRecorder.stop();
      setState(() => _isRecording = false);

      if (path == null) return;
      final file = File(path);
      if (!await file.exists()) return;

      final seconds = _recordDuration.inSeconds;
      if (!mounted) return;
      final chatVm = context.read<ChatViewmodel>();
      final userId = chatVm.currentUserId;
      if (userId == null) return;

      setState(() {
        _isUploading = true;
        _uploadProgress = 0;
      });

      final url = await StorageService.uploadFile(
        file: file,
        folder: 'chat_media',
        userId: userId,
        ext: '.m4a',
        onProgress: (p) {
          if (mounted) setState(() => _uploadProgress = p);
        },
      );

      if (mounted) setState(() => _isUploading = false);

      if (url != null) {
        await chatVm.sendMessage('',
            type: MessageType.audio, mediaUrl: url, mediaDuration: seconds);
      }
    } catch (e) {
      debugPrint('Stop recording error: $e');
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    try {
      await _audioRecorder.stop();
    } catch (_) {}
    if (mounted) setState(() => _isRecording = false);
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final chatVm = context.watch<ChatViewmodel>();
    final currentUserId = chatVm.currentUserId;
    final messages = chatVm.currentMessages;
    final cs = Theme.of(context).colorScheme;
    final initial = widget.otherUserName.isNotEmpty
        ? widget.otherUserName[0].toUpperCase()
        : '?';
    final r = Responsive(context);

    if (messages.length > _previousMessageCount) {
      _previousMessageCount = messages.length;
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: cs.surface,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: r.s(18),
              backgroundColor: cs.primary,
              foregroundColor: cs.onPrimary,
              child: Text(initial,
                  style: TextStyle(
                      fontSize: r.fs(15), fontWeight: FontWeight.w600)),
            ),
            SizedBox(width: r.s(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.otherUserName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: r.fs(16), fontWeight: FontWeight.w600)),
                  Text('Online',
                      style: TextStyle(
                          fontSize: r.fs(12), color: cs.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
              height: 1,
              color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
      ),
      body: Container(
        color: cs.surfaceContainerLowest,
        child: Column(
          children: [
            if (_isUploading)
              LinearProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null,
                minHeight: 3,
                backgroundColor: cs.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation(cs.primary),
              ),

            Expanded(
              child: messages.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: cs.primaryContainer.withValues(alpha: 0.3),
                            ),
                            child: Icon(Icons.chat_outlined,
                                size: 40,
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.4)),
                          ),
                          const SizedBox(height: 12),
                          Text('Say hello!',
                              style:
                                  TextStyle(color: cs.onSurfaceVariant)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      controller: _scrollController,
                      reverse: true,
                      padding: EdgeInsets.symmetric(
                          horizontal: r.s(14), vertical: r.s(10)),
                      itemCount: messages.length,
                      itemBuilder: (context, index) {
                        final msg =
                            messages[messages.length - 1 - index];
                        final isMine = msg.senderId == currentUserId;

                        Widget? dateSep;
                        if (index == messages.length - 1 ||
                            _differentDay(
                                msg,
                                messages[messages.length -
                                    2 -
                                    index])) {
                          dateSep = _dateSeparator(context, msg, cs);
                        }

                        return Column(
                          children: [
                            ?dateSep,
                            _MessageBubble(message: msg, isMine: isMine),
                          ],
                        );
                      },
                    ),
            ),

            _buildInputBar(cs),
          ],
        ),
      ),
    );
  }

  bool _differentDay(ChatMessage a, ChatMessage b) {
    if (a.timestamp == null || b.timestamp == null) return false;
    return a.timestamp!.day != b.timestamp!.day ||
        a.timestamp!.month != b.timestamp!.month ||
        a.timestamp!.year != b.timestamp!.year;
  }

  Widget _dateSeparator(
      BuildContext context, ChatMessage msg, ColorScheme cs) {
    final t = msg.timestamp;
    final label = t != null
        ? '${t.day}/${t.month}/${t.year}'
        : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: cs.outlineVariant.withValues(alpha: 0.3))),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(label,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
          ),
          Expanded(child: Divider(color: cs.outlineVariant.withValues(alpha: 0.3))),
        ],
      ),
    );
  }

  Widget _buildInputBar(ColorScheme cs) {
    if (_isRecording) {
      return Container(
        padding: EdgeInsets.fromLTRB(
            14, 10, 10, MediaQuery.of(context).padding.bottom + 10),
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1.0),
              duration: const Duration(milliseconds: 600),
              builder: (_, v, child) => Opacity(opacity: v, child: child),
              onEnd: () {},
              child: Container(
                width: 10, height: 10,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _formatDuration(_recordDuration),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: cs.error,
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: _cancelRecording,
              child: Text('Cancel',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary,
              ),
              child: IconButton(
                onPressed: _stopAndSendRecording,
                icon: const Icon(Icons.send_rounded, size: 20),
                color: cs.onPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: EdgeInsets.fromLTRB(
          8, 10, 10, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: _isUploading ? null : _showAttachmentOptions,
            icon: Icon(Icons.add_circle_outline_rounded,
                size: 26, color: cs.primary),
            tooltip: 'Attach media',
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Type a message...',
                  border: InputBorder.none,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary,
            ),
            child: IconButton(
              onPressed: _isUploading
                  ? null
                  : () {
                      if (_messageController.text.trim().isNotEmpty) {
                        _sendMessage();
                      } else {
                        _startRecording();
                      }
                    },
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Icon(
                  _messageController.text.trim().isNotEmpty
                      ? Icons.send_rounded
                      : Icons.mic_rounded,
                  key: ValueKey(_messageController.text.trim().isNotEmpty),
                  size: 20,
                ),
              ),
              color: cs.onPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = Responsive(context);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: r.s(56), height: r.s(56),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: r.icon(26)),
          ),
          SizedBox(height: r.s(6)),
          Text(label,
              style: TextStyle(
                fontSize: r.fs(12),
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              )),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool isMine;
  const _MessageBubble({required this.message, required this.isMine});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final alignment =
        isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final bgColor = isMine ? cs.primary : cs.surfaceContainerHighest;
    final textColor = isMine ? cs.onPrimary : cs.onSurface;

    final radius = BorderRadius.only(
      topLeft: const Radius.circular(18),
      topRight: const Radius.circular(18),
      bottomLeft: Radius.circular(isMine ? 18 : 4),
      bottomRight: Radius.circular(isMine ? 4 : 18),
    );

    Widget content;
    switch (message.type) {
      case MessageType.image:
        content = _imageBubble(context, cs, radius);
        break;
      case MessageType.video:
        content = _videoBubble(context, cs, radius);
        break;
      case MessageType.audio:
        content = _audioBubble(context, cs, bgColor, textColor, radius);
        break;
      default:
        content = Container(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(color: bgColor, borderRadius: radius),
          child: Text(message.text,
              style: TextStyle(color: textColor, height: 1.3)),
        );
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            content,
            if (message.timestamp != null)
              Padding(
                padding: const EdgeInsets.only(top: 3, left: 6, right: 6),
                child: Text(
                  _formatTime(message.timestamp!),
                  style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _imageBubble(
      BuildContext context, ColorScheme cs, BorderRadius radius) {
    final screenW = MediaQuery.of(context).size.width;
    final maxW = screenW * 0.65;
    return GestureDetector(
      onTap: () {
        if (message.mediaUrl != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => FullScreenImageViewer(
              imageUrl: message.mediaUrl!,
            ),
          ));
        }
      },
      child: ClipRRect(
        borderRadius: radius,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: 280),
          child: message.mediaUrl != null && message.mediaUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: message.mediaUrl!,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: 200,
                    height: 150,
                    color: cs.surfaceContainerHighest,
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: 200,
                    height: 100,
                    color: cs.errorContainer,
                    child: Icon(Icons.broken_image_rounded,
                        color: cs.onErrorContainer),
                  ),
                )
              : Container(
                  width: 200,
                  height: 100,
                  color: cs.surfaceContainerHighest,
                  child: const Icon(Icons.image_not_supported_rounded),
                ),
        ),
      ),
    );
  }

  Widget _videoBubble(
      BuildContext context, ColorScheme cs, BorderRadius radius) {
    return GestureDetector(
      onTap: () {
        if (message.mediaUrl != null) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => _VideoPlayerScreen(url: message.mediaUrl!),
          ));
        }
      },
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.65,
        ),
        height: 180,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: radius,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            ClipRRect(
              borderRadius: radius,
              child: Container(color: Colors.black54),
            ),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withValues(alpha: 0.85),
              ),
              child: Icon(Icons.play_arrow_rounded,
                  color: cs.onPrimary, size: 32),
            ),
            Positioned(
              bottom: 8,
              left: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.videocam_rounded,
                        size: 14, color: Colors.white70),
                    SizedBox(width: 4),
                    Text('Video',
                        style:
                            TextStyle(color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _audioBubble(BuildContext context, ColorScheme cs, Color bgColor,
      Color textColor, BorderRadius radius) {
    final dur = message.mediaDuration ?? 0;
    final m = (dur ~/ 60).toString().padLeft(2, '0');
    final s = (dur % 60).toString().padLeft(2, '0');
    return Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.65,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: bgColor, borderRadius: radius),
      child: _AudioPlaybackWidget(
        url: message.mediaUrl ?? '',
        durationLabel: '$m:$s',
        textColor: textColor,
        accentColor: isMine ? cs.onPrimary : cs.primary,
      ),
    );
  }

  String _formatTime(DateTime t) {
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }
}

class _AudioPlaybackWidget extends StatefulWidget {
  final String url;
  final String durationLabel;
  final Color textColor;
  final Color accentColor;

  const _AudioPlaybackWidget({
    required this.url,
    required this.durationLabel,
    required this.textColor,
    required this.accentColor,
  });

  @override
  State<_AudioPlaybackWidget> createState() => _AudioPlaybackWidgetState();
}

class _AudioPlaybackWidgetState extends State<_AudioPlaybackWidget> {
  final _player = AudioPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
    _player.onDurationChanged.listen((d) {
      if (mounted) setState(() => _duration = d);
    });
    _player.onPositionChanged.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlay() async {
    if (_isPlaying) {
      await _player.pause();
    } else {
      if (_position >= _duration && _duration > Duration.zero) {
        await _player.seek(Duration.zero);
      }
      await _player.play(UrlSource(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        _duration.inMilliseconds > 0
            ? _position.inMilliseconds / _duration.inMilliseconds
            : 0.0;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _togglePlay,
          child: Icon(
            _isPlaying
                ? Icons.pause_circle_filled_rounded
                : Icons.play_circle_filled_rounded,
            size: 36,
            color: widget.accentColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: widget.textColor.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation(widget.accentColor),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isPlaying
                    ? _fmtDur(_position)
                    : widget.durationLabel,
                style: TextStyle(
                  fontSize: 11,
                  color: widget.textColor.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmtDur(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _VideoPlayerScreen extends StatefulWidget {
  final String url;
  const _VideoPlayerScreen({required this.url});

  @override
  State<_VideoPlayerScreen> createState() => _VideoPlayerScreenState();
}

class _VideoPlayerScreenState extends State<_VideoPlayerScreen> {
  late VideoPlayerController _controller;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _controller.play();
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
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black.withValues(alpha: 0.6),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: _initialized
            ? AspectRatio(
                aspectRatio: _controller.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play();
                        });
                      },
                      child: AnimatedOpacity(
                        opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.black54,
                          ),
                          child: const Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 48),
                        ),
                      ),
                    ),
                  ],
                ),
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
