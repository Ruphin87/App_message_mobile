import 'dart:async';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_routes.dart';
import '../../../core/services/download_service.dart';
import '../../../core/utils/date_formatters.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../../models/attachment_model.dart';
import '../../../models/call_model.dart';
import '../../../models/user_model.dart';
import '../../../models/message_model.dart';
import '../../../models/message_reaction_model.dart';
import '../../calls/controllers/call_controller.dart';
import '../../presence/controllers/presence_controller.dart';
import '../controllers/chat_controller.dart';

/// Élément de la liste affichée : soit un séparateur de date, soit un message.
abstract class _ChatListItem {}

class _DateSeparatorItem extends _ChatListItem {
  _DateSeparatorItem(this.date);
  final DateTime date;
}

class _MessageItem extends _ChatListItem {
  _MessageItem({
    required this.message,
    required this.isFirstInGroup,
    required this.isLastInGroup,
  });

  final MessageModel message;
  /// Premier message d'une série consécutive du même expéditeur (affiche l'avatar/queue en haut).
  final bool isFirstInGroup;
  /// Dernier message d'une série consécutive (affiche l'heure + statut + queue de bulle).
  final bool isLastInGroup;
}

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key, required this.otherUser});

  final UserModel otherUser;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _imagePicker = ImagePicker();
  final _audioRecorder = AudioRecorder();

  /// Id du dernier message déjà vu, pour détecter une vraie nouvelle
  /// réception même si la longueur de la liste ne suffit pas à le garantir
  /// (ex: premier chargement où on passe de 0 à N messages d'un coup).
  String? _lastSeenMessageId;
  bool _hasScrolledForCurrentConversation = false;
  bool _hasMessageText = false;
  bool _isRecordingVoice = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(_handleMessageTextChanged);
    Future.microtask(
      () => ref.read(chatProvider.notifier).openConversationWith(widget.otherUser.id),
    );
  }

  @override
  void dispose() {
    // On rafraîchit la liste des conversations en quittant le chat, pour que
    // le compteur de non-lus et l'aperçu du dernier message soient à jour
    // immédiatement au retour sur l'écran "Messages" (sinon l'ancien état
    // mis en cache par chatListProvider restait affiché tel quel, et un
    // message déjà lu continuait à apparaître comme non lu).
    ref.read(chatListProvider.notifier).loadConversations();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _messageController.removeListener(_handleMessageTextChanged);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleMessageTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText == _hasMessageText) return;
    setState(() => _hasMessageText = hasText);
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final target = _scrollController.position.maxScrollExtent;
    if (animated) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  /// Force le scroll en bas après que le ListView ait fini de se construire
  /// (le `maxScrollExtent` n'est fiable qu'une fois le layout terminé — un
  /// seul `addPostFrameCallback` suffit généralement, mais on enchaîne un
  /// second passage pour couvrir le cas où des images/avatars asynchrones
  /// font encore grandir la liste juste après le premier frame).
  void _scheduleScrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom(animated: animated);
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom(animated: false));
    });
  }

  Future<void> _handleSend() async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;

    _messageController.clear();
    await ref.read(chatProvider.notifier).sendMessage(text);
    _scheduleScrollToBottom();
  }

  Future<void> _startCall(CallMediaType mediaType) async {
    try {
      final call = await ref.read(callRepositoryProvider).createCall(
            receiverId: widget.otherUser.id,
            mediaType: mediaType,
          );
      if (!mounted) return;
      context.push(
        '${AppRoutes.call}/${call.id}',
        extra: CallRouteArgs(
          otherUserId: widget.otherUser.id,
          otherUserName: widget.otherUser.nom,
          otherUserPhoto: widget.otherUser.photo,
          mediaType: mediaType,
          isCaller: true,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de lancer l\'appel.')),
      );
    }
  }

  Future<void> _startVoiceRecording() async {
    if (_isRecordingVoice || ref.read(chatProvider).isSending) return;

    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Autorisez le micro pour envoyer un vocal.')),
        );
        return;
      }

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/voice_'
          '${DateTime.now().microsecondsSinceEpoch}.m4a';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 96000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() {
        _isRecordingVoice = true;
        _recordingDuration = Duration.zero;
      });
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          setState(() => _recordingDuration += const Duration(seconds: 1));
        }
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de démarrer l\'enregistrement vocal.')),
      );
    }
  }

  Future<void> _finishVoiceRecording({required bool send}) async {
    if (!_isRecordingVoice) return;

    _recordingTimer?.cancel();
    _recordingTimer = null;

    String? path;
    try {
      path = await _audioRecorder.stop();
    } catch (_) {
      path = null;
    }
    if (!mounted) return;

    setState(() {
      _isRecordingVoice = false;
      _recordingDuration = Duration.zero;
    });

    if (!send || path == null || path.isEmpty) return;

    final file = io.File(path);
    if (!await file.exists()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun vocal enregistré.')),
      );
      return;
    }

    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Le vocal enregistré est vide.')),
      );
      return;
    }

    await ref.read(chatProvider.notifier).sendAttachment(
          fileName: 'vocal_${DateTime.now().millisecondsSinceEpoch}.m4a',
          bytes: bytes,
          fileType: AttachmentType.audio,
          contentType: 'audio/mp4',
        );
    _scheduleScrollToBottom();
  }

  Future<void> _showAttachmentOptions() async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_outlined, color: AppColors.primary),
                  title: const Text('Photo'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickImage();
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.picture_as_pdf_outlined, color: AppColors.error),
                  title: const Text('Document PDF'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickFile(
                      type: AttachmentType.pdf,
                      allowedExtensions: const ['pdf'],
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.mic_none_outlined, color: AppColors.success),
                  title: const Text('Audio'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _pickFile(
                      type: AttachmentType.audio,
                      fileType: FileType.audio,
                    );
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;

    await ref.read(chatProvider.notifier).sendAttachment(
          fileName: picked.name,
          bytes: await picked.readAsBytes(),
          fileType: AttachmentType.image,
          contentType: picked.mimeType ?? _contentTypeForName(picked.name),
        );
    _scheduleScrollToBottom();
  }

  Future<void> _pickFile({
    required AttachmentType type,
    FileType fileType = FileType.custom,
    List<String>? allowedExtensions,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: fileType,
      allowedExtensions: allowedExtensions,
      withData: true,
    );
    final file = result?.files.single;
    if (file == null) return;

    final bytes = await _readPickedFileBytes(file);
    if (bytes == null || bytes.isEmpty) return;

    await ref.read(chatProvider.notifier).sendAttachment(
          fileName: file.name,
          bytes: bytes,
          fileType: type,
          contentType: _contentTypeForName(file.name),
        );
    _scheduleScrollToBottom();
  }

  Future<Uint8List?> _readPickedFileBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes;
    final path = file.path;
    if (path == null || path.isEmpty) return null;
    return io.File(path).readAsBytes();
  }

  String? _contentTypeForName(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.wav')) return 'audio/wav';
    return null;
  }

  /// Transforme la liste plate de messages en une liste d'éléments affichables
  /// (séparateurs de date + messages groupés par expéditeur consécutif),
  /// exactement comme WhatsApp organise sa conversation.
  List<_ChatListItem> _buildListItems(List<MessageModel> messages) {
    final items = <_ChatListItem>[];

    for (var i = 0; i < messages.length; i++) {
      final current = messages[i];
      final previous = i > 0 ? messages[i - 1] : null;
      final next = i < messages.length - 1 ? messages[i + 1] : null;

      final isNewDay = previous == null ||
          DateFormatters.isDifferentDay(previous.createdAt, current.createdAt);
      if (isNewDay) {
        items.add(_DateSeparatorItem(current.createdAt));
      }

      final isFirstInGroup = previous == null ||
          previous.senderId != current.senderId ||
          isNewDay;

      final isLastInGroup = next == null ||
          next.senderId != current.senderId ||
          DateFormatters.isDifferentDay(current.createdAt, next.createdAt);

      items.add(_MessageItem(
        message: current,
        isFirstInGroup: isFirstInGroup,
        isLastInGroup: isLastInGroup,
      ));
    }

    return items;
  }

  /// Affiche le menu d'actions sur un message (long-press) : réactions
  /// rapides en haut, puis Répondre / Copier / Supprimer.
  Future<void> _showMessageActions(MessageModel message, bool isMine) async {
    if (message.isDeletedForEveryone) return; // pas d'actions sur un message déjà supprimé

    final currentUserId = ref.read(currentUserIdProvider);
    HapticFeedback.mediumImpact();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          margin: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: kQuickReactionEmojis.map((emoji) {
                    return GestureDetector(
                      onTap: () {
                        if (currentUserId != null) {
                          ref.read(chatProvider.notifier).toggleReaction(
                                messageId: message.id,
                                emoji: emoji,
                                currentUserId: currentUserId,
                              );
                        }
                        Navigator.of(sheetContext).pop();
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    );
                  }).toList(),
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              ListTile(
                leading: const Icon(Icons.reply, color: AppColors.textPrimary),
                title: const Text('Répondre'),
                onTap: () {
                  ref.read(chatProvider.notifier).startReplyingTo(message);
                  Navigator.of(sheetContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined, color: AppColors.textPrimary),
                title: const Text('Copier'),
                onTap: () {
                  Clipboard.setData(ClipboardData(text: message.displayText));
                  Navigator.of(sheetContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppColors.error),
                title: const Text('Supprimer pour moi'),
                onTap: () {
                  ref.read(chatProvider.notifier).deleteMessageForMe(message.id);
                  Navigator.of(sheetContext).pop();
                },
              ),
              if (isMine)
                ListTile(
                  leading: const Icon(Icons.delete_forever_outlined, color: AppColors.error),
                  title: const Text('Supprimer pour tout le monde'),
                  onTap: () {
                    Navigator.of(sheetContext).pop();
                    _confirmDeleteForEveryone(message.id);
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmDeleteForEveryone(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer pour tout le monde ?'),
        content: const Text(
          'Ce message sera supprimé pour vous et pour votre contact. Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Supprimer', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(chatProvider.notifier).deleteMessageForEveryone(messageId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(chatProvider);
    final currentUserId = ref.watch(currentUserIdProvider);
    final isOtherUserOnline = ref.watch(isUserOnlineProvider(widget.otherUser.id));

    ref.listen(chatProvider, (previous, next) {
      if (next.error != null && next.error != previous?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!)),
        );
      }

      if (next.messages.isEmpty) return;

      final newLastId = next.messages.last.id;
      final isFirstDisplay = !_hasScrolledForCurrentConversation;
      final hasNewLastMessage = newLastId != _lastSeenMessageId;

      if (isFirstDisplay || hasNewLastMessage) {
        _lastSeenMessageId = newLastId;
        _hasScrolledForCurrentConversation = true;
        // Pas d'animation pour le tout premier affichage (on arrive direct
        // en bas, comme WhatsApp), animé pour les messages suivants.
        _scheduleScrollToBottom(animated: !isFirstDisplay);
      }
    });

    final listItems = _buildListItems(chatState.messages);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(isOtherUserOnline),
      body: Column(
        children: [
          Expanded(
            child: _buildMessageList(chatState, currentUserId, listItems),
          ),
          if (chatState.replyingTo != null) _buildReplyPreviewBar(chatState.replyingTo!),
          _buildInputBar(chatState),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isOnline) {
    return AppBar(
      backgroundColor: AppColors.surface,
      elevation: 0,
      titleSpacing: 0,
      title: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => context.push(AppRoutes.friendProfile, extra: widget.otherUser),
        child: Row(
          children: [
            UserAvatar(
              userId: widget.otherUser.id,
              photoUrl: widget.otherUser.photo,
              radius: 18,
              showOnlineBadge: true,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.otherUser.nom,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    isOnline ? 'En ligne' : 'Inactif',
                    style: TextStyle(
                      fontSize: 12,
                      color: isOnline ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          tooltip: 'Appel audio',
          icon: const Icon(Icons.call_outlined, color: AppColors.textPrimary),
          onPressed: () => _startCall(CallMediaType.audio),
        ),
        IconButton(
          tooltip: 'Appel vidéo',
          icon: const Icon(Icons.videocam_outlined, color: AppColors.textPrimary),
          onPressed: () => _startCall(CallMediaType.video),
        ),
      ],
    );
  }

  Widget _buildMessageList(
    ChatState state,
    String? currentUserId,
    List<_ChatListItem> listItems,
  ) {
    if (state.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
        ),
      );
    }

    if (listItems.isEmpty) {
      return Center(
        child: Text(
          'Aucun message.\nDémarrez la conversation !',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      itemCount: listItems.length,
      itemBuilder: (context, index) {
        final item = listItems[index];
        if (item is _DateSeparatorItem) {
          return _buildDateSeparator(item.date);
        }
        final messageItem = item as _MessageItem;
        final isMine = currentUserId != null && messageItem.message.isMine(currentUserId);
        final reactions = state.reactionsByMessageId[messageItem.message.id] ?? const [];
        final attachments = state.attachmentsByMessageId[messageItem.message.id] ?? const [];
        return _buildMessageBubble(messageItem, isMine, reactions, attachments);
      },
    );
  }

  Widget _buildDateSeparator(DateTime date) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            DateFormatters.dateSeparator(date),
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    _MessageItem item,
    bool isMine,
    List<MessageReactionModel> reactions,
    List<AttachmentModel> attachments,
  ) {
    final message = item.message;
    final isDeleted = message.isDeletedForEveryone;
    final visibleAttachments = isDeleted ? const <AttachmentModel>[] : attachments;

    // Espacement entre bulles : WhatsApp garde un espacement faible et
    // régulier, qu'on soit dans le même groupe ou pas (juste légèrement
    // plus marqué entre deux groupes différents). On laisse un peu plus de
    // place en bas si des réactions sont affichées (elles débordent
    // légèrement sous la bulle).
    final topSpacing = item.isFirstInGroup ? 6.0 : 2.0;
    final bottomSpacing = reactions.isNotEmpty ? 10.0 : 0.0;

    const radius = Radius.circular(18);
    const tightRadius = Radius.circular(4);

    final borderRadius = BorderRadius.only(
      topLeft: radius,
      topRight: radius,
      bottomLeft: !isMine && item.isLastInGroup ? tightRadius : radius,
      bottomRight: isMine && item.isLastInGroup ? tightRadius : radius,
    );

    final timeAndStatusText = DateFormatters.time(message.createdAt);

    return Padding(
      padding: EdgeInsets.only(top: topSpacing, bottom: bottomSpacing),
      child: Align(
        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
        child: GestureDetector(
          onLongPress: () => _showMessageActions(message, isMine),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
                padding: const EdgeInsets.fromLTRB(10, 6, 8, 6),
                decoration: BoxDecoration(
                  color: isMine ? AppColors.primary : AppColors.surface,
                  borderRadius: borderRadius,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 3,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (message.replyToPreview != null)
                      _buildReplyQuote(message.replyToPreview!, isMine),
                    if (visibleAttachments.isNotEmpty) ...[
                      for (final attachment in visibleAttachments)
                        _buildAttachmentPreview(attachment, isMine),
                      if (!message.displayText.startsWith('['))
                        const SizedBox(height: 4),
                    ],
                    if (message.displayText.startsWith('[') && visibleAttachments.isNotEmpty)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                timeAndStatusText,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isMine
                                      ? Colors.white.withValues(alpha: 0.75)
                                      : AppColors.textHint,
                                ),
                              ),
                              if (isMine && !isDeleted) ...[
                                const SizedBox(width: 4),
                                _buildStatusIcon(message.status),
                              ],
                            ],
                          ),
                        ),
                      ),
                    // Text.rich avec un WidgetSpan invisible en fin de texte :
                    // ça réserve exactement la place de "HH:mm ✓✓" sur la
                    // dernière ligne, pour que l'heure/coche réelle
                    // (positionnée par-dessus via Stack) ne recouvre jamais
                    // le texte, peu importe sa longueur.
                    if (!message.displayText.startsWith('[') || visibleAttachments.isEmpty)
                      Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: message.displayText,
                                    style: isDeleted
                                        ? const TextStyle(fontStyle: FontStyle.italic)
                                        : null,
                                  ),
                                  WidgetSpan(
                                    alignment: PlaceholderAlignment.middle,
                                    child: SizedBox(width: isMine ? 54 : 44, height: 14),
                                  ),
                                ],
                              ),
                              style: TextStyle(
                                color: isDeleted
                                    ? (isMine
                                        ? Colors.white.withValues(alpha: 0.7)
                                        : AppColors.textHint)
                                    : (isMine ? Colors.white : AppColors.textPrimary),
                                fontSize: 15,
                                height: 1.3,
                              ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  timeAndStatusText,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isMine
                                        ? Colors.white.withValues(alpha: 0.75)
                                        : AppColors.textHint,
                                  ),
                                ),
                                if (isMine && !isDeleted) ...[
                                  const SizedBox(width: 4),
                                  _buildStatusIcon(message.status),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (reactions.isNotEmpty)
                Positioned(
                  bottom: -10,
                  right: isMine ? 8 : null,
                  left: isMine ? null : 8,
                  child: _buildReactionBadge(reactions),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAttachmentPreview(AttachmentModel attachment, bool isMine) {
    final icon = switch (attachment.fileType) {
      AttachmentType.image => Icons.image_outlined,
      AttachmentType.pdf => Icons.picture_as_pdf_outlined,
      AttachmentType.audio => Icons.graphic_eq,
      AttachmentType.document => Icons.insert_drive_file_outlined,
    };

    if (attachment.fileType == AttachmentType.image) {
      return GestureDetector(
        onTap: () => _openAttachment(attachment.fileUrl),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.network(
                attachment.fileUrl,
                width: 220,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _buildFileTile(attachment, isMine, icon),
              ),
              Positioned(
                right: 6,
                bottom: 6,
                child: _DownloadIconButton(onPressed: () => _downloadAttachment(attachment)),
              ),
            ],
          ),
        ),
      );
    }

    if (attachment.fileType == AttachmentType.audio) {
      return _VoiceMessageBubble(attachment: attachment, isMine: isMine);
    }

    return _buildFileTile(attachment, isMine, icon);
  }

  Widget _buildFileTile(AttachmentModel attachment, bool isMine, IconData icon) {
    final foreground = isMine ? Colors.white : AppColors.textPrimary;
    final secondary = isMine ? Colors.white.withValues(alpha: 0.75) : AppColors.textSecondary;

    return InkWell(
      onTap: () => _openAttachment(attachment.fileUrl),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMine
              ? Colors.white.withValues(alpha: 0.14)
              : AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: foreground, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    attachment.fileName ?? 'Fichier',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: foreground,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (attachment.fileSize != null)
                    Text(
                      _formatFileSize(attachment.fileSize!),
                      style: TextStyle(color: secondary, fontSize: 12),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => _downloadAttachment(attachment),
              icon: Icon(Icons.download_outlined, color: foreground, size: 20),
              tooltip: 'Télécharger',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            ),
          ],
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes o';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} Ko';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} Mo';
  }

  Future<void> _openAttachment(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  /// Télécharge une pièce jointe (image, audio, document...) sur
  /// l'appareil — comme le bouton "Télécharger" de WhatsApp — et affiche
  /// le résultat dans un SnackBar.
  Future<void> _downloadAttachment(AttachmentModel attachment) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Téléchargement en cours...'), duration: Duration(seconds: 2)),
    );

    final defaultName = 'fichier_${attachment.id.substring(0, 8)}${_guessExtension(attachment)}';
    final result = await DownloadService.instance.downloadAttachment(
      url: attachment.fileUrl,
      suggestedFileName: attachment.fileName ?? defaultName,
    );

    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'Téléchargé : ${result.filePath!.split('/').last}'
              : (result.error ?? 'Téléchargement impossible'),
        ),
      ),
    );
  }

  String _guessExtension(AttachmentModel attachment) {
    switch (attachment.fileType) {
      case AttachmentType.image:
        return '.jpg';
      case AttachmentType.audio:
        return '.m4a';
      case AttachmentType.pdf:
        return '.pdf';
      case AttachmentType.document:
        return '';
    }
  }

  /// Aperçu compact du message cité, affiché en haut de la bulle de réponse
  /// — façon WhatsApp/Messenger : une barre verticale colorée + le texte
  /// (tronqué) du message original.
  Widget _buildReplyQuote(MessageModel original, bool isMine) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.15)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: isMine ? Colors.white.withValues(alpha: 0.7) : AppColors.primary,
            width: 3,
          ),
        ),
      ),
      child: Text(
        original.displayText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 13,
          color: isMine ? Colors.white.withValues(alpha: 0.85) : AppColors.textSecondary,
        ),
      ),
    );
  }

  /// Petit badge regroupant les emojis de réaction sous la bulle (façon
  /// WhatsApp : un seul badge listant les emojis distincts utilisés, pas un
  /// badge par personne).
  Widget _buildReactionBadge(List<MessageReactionModel> reactions) {
    final distinctEmojis = reactions.map((r) => r.emoji).toSet().toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...distinctEmojis.take(3).map(
                (e) => Text(e, style: const TextStyle(fontSize: 12)),
              ),
          if (reactions.length > 1) ...[
            const SizedBox(width: 2),
            Text(
              '${reactions.length}',
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sent:
        return Icon(Icons.check, size: 14, color: Colors.white.withValues(alpha: 0.75));
      case MessageStatus.delivered:
        return Icon(Icons.done_all, size: 14, color: Colors.white.withValues(alpha: 0.75));
      case MessageStatus.read:
        return const Icon(Icons.done_all, size: 14, color: Color(0xFF34D2FF));
    }
  }

  /// Barre affichée au-dessus du champ de saisie pendant qu'on répond à un
  /// message — avec un bouton pour annuler la réponse en cours.
  Widget _buildReplyPreviewBar(MessageModel replyingTo) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 1)),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 36,
            color: AppColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Réponse',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  replyingTo.displayText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary),
            onPressed: () => ref.read(chatProvider.notifier).cancelReply(),
          ),
        ],
      ),
    );
  }

  Widget _buildInputBar(ChatState state) {
    if (_isRecordingVoice) {
      return _buildRecordingBar(state);
    }

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
              decoration: InputDecoration(
                hintText: 'Votre message...',
                filled: true,
                fillColor: AppColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
            onPressed: state.isSending ? null : _showAttachmentOptions,
          ),
          const SizedBox(width: 2),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: GestureDetector(
              onLongPressStart: (!_hasMessageText && !state.isSending)
                  ? (_) => _startVoiceRecording()
                  : null,
              onLongPressEnd: (!_hasMessageText && !state.isSending)
                  ? (_) => _finishVoiceRecording(send: true)
                  : null,
              child: IconButton(
                icon: state.isSending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Icon(
                        _hasMessageText ? Icons.send : Icons.mic,
                        color: Colors.white,
                        size: 20,
                      ),
                onPressed: state.isSending
                    ? null
                    : (_hasMessageText ? _handleSend : _startVoiceRecording),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingBar(ChatState state) {
    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 8,
        bottom: 8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: state.isSending ? null : () => _finishVoiceRecording(send: false),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(
              color: AppColors.error,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Enregistrement ${_formatDuration(_recordingDuration)}',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.send, color: Colors.white, size: 20),
              onPressed: state.isSending ? null : () => _finishVoiceRecording(send: true),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceMessageBubble extends StatefulWidget {
  const _VoiceMessageBubble({
    required this.attachment,
    required this.isMine,
  });

  final AttachmentModel attachment;
  final bool isMine;

  @override
  State<_VoiceMessageBubble> createState() => _VoiceMessageBubbleState();
}

class _VoiceMessageBubbleState extends State<_VoiceMessageBubble> {
  late final AudioPlayer _player;
  PlayerState _playerState = PlayerState.stopped;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  StreamSubscription<PlayerState>? _stateSubscription;
  StreamSubscription<Duration>? _durationSubscription;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<void>? _completeSubscription;

  bool get _isPlaying => _playerState == PlayerState.playing;

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _stateSubscription = _player.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _playerState = state);
    });
    _durationSubscription = _player.onDurationChanged.listen((duration) {
      if (mounted) setState(() => _duration = duration);
    });
    _positionSubscription = _player.onPositionChanged.listen((position) {
      if (mounted) setState(() => _position = position);
    });
    _completeSubscription = _player.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _playerState = PlayerState.stopped;
          _position = Duration.zero;
        });
      }
    });
  }

  @override
  void dispose() {
    _stateSubscription?.cancel();
    _durationSubscription?.cancel();
    _positionSubscription?.cancel();
    _completeSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_isPlaying) {
      await _player.pause();
      return;
    }

    if (_position > Duration.zero && _position < _duration) {
      await _player.resume();
    } else {
      await _player.play(UrlSource(widget.attachment.fileUrl));
    }
  }

  @override
  Widget build(BuildContext context) {
    final secondary = widget.isMine
        ? Colors.white.withValues(alpha: 0.75)
        : AppColors.textSecondary;
    final progress = _duration.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

    return Container(
      width: 238,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isMine
            ? Colors.white.withValues(alpha: 0.14)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _togglePlayback,
            customBorder: const CircleBorder(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: widget.isMine
                    ? Colors.white.withValues(alpha: 0.2)
                    : AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor: widget.isMine
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppColors.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      widget.isMine ? Colors.white : AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.graphic_eq, size: 15, color: secondary),
                    const SizedBox(width: 4),
                    Text(
                      _duration == Duration.zero
                          ? 'Message vocal'
                          : '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                      style: TextStyle(
                        color: secondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: () => _downloadVoiceMessage(context),
            icon: Icon(Icons.download_outlined, color: secondary, size: 18),
            tooltip: 'Télécharger',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadVoiceMessage(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Téléchargement en cours...'), duration: Duration(seconds: 2)),
    );
    final result = await DownloadService.instance.downloadAttachment(
      url: widget.attachment.fileUrl,
      suggestedFileName: widget.attachment.fileName ?? 'message_vocal_${widget.attachment.id.substring(0, 8)}.m4a',
    );
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result.success
              ? 'Téléchargé : ${result.filePath!.split('/').last}'
              : (result.error ?? 'Téléchargement impossible'),
        ),
      ),
    );
  }
}

String _formatDuration(Duration duration) {
  final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '$minutes:$seconds';
}

/// Petit bouton rond semi-transparent façon WhatsApp, posé sur une image,
/// pour la télécharger sans avoir à l'ouvrir en plein écran d'abord.
class _DownloadIconButton extends StatelessWidget {
  const _DownloadIconButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(Icons.download_outlined, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}
