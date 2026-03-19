import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/chat_service.dart';
import '../../models/chat_model.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatelessWidget {
  final String currentUserRole; // "client" or "expert"
  final String? expertId;

  const ChatListScreen({
    super.key,
    required this.currentUserRole,
    this.expertId,
  });

  static const _primaryBlue = Color(0xFF3D5A99);

  @override
  Widget build(BuildContext context) {
    final chatService = ChatService();


    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F0),
      appBar: AppBar(
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 16),
          child: Row(
            children: [
              Image.asset(
                'assets/logo.png',
                height: 28,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Messages',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    Text(
                      'Presto — snap your fingers, we handle the rest.',
                      style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, fontWeight: FontWeight.normal),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        centerTitle: false,
      ),
      body: StreamBuilder<List<ChatModel>>(
        stream: chatService.getUserChats(currentUserRole, expertId: expertId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            // Common error: missing Firestore composite index
            final err = snapshot.error.toString();
            if (err.contains('index')) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          size: 48, color: Colors.orange),
                      const SizedBox(height: 12),
                      const Text(
                        'Missing Firestore Index',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Check the Flutter console for a direct link '
                        'to create the index automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              );
            }
            return Center(child: Text('Error: $err'));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.chat_bubble_outline,
                      size: 70, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'No conversations yet.',
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    currentUserRole == 'client'
                        ? 'Contact an expert from the home screen.'
                        : 'Clients will contact you here.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final chats = snapshot.data!;

          return ListView.separated(
            itemCount: chats.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 72),
            itemBuilder: (context, index) {
              final chat = chats[index];
              final currentUserId = chatService.currentUserId;

              final otherName = currentUserRole == 'client'
                  ? chat.expertSnapshot.nom
                  : chat.clientSnapshot.nom;
              final otherPhoto = currentUserRole == 'client'
                  ? chat.expertSnapshot.photo
                  : chat.clientSnapshot.photo;

              final lastText =
                  chat.dernierMessage?.contenu ?? 'No messages';
              final lastTime = chat.updatedAt.toDate();
              final unread = chat.nbMessagesNonLus;

              // Only show unread badge if the last message was NOT sent by me
              final isLastMessageMine =
                  chat.dernierMessage?.senderId == currentUserId;
              final showUnread = unread > 0 && !isLastMessageMine;

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 6),
                leading: _buildAvatar(otherPhoto, otherName, chat.estOuvert),
                title: Text(
                  otherName.isNotEmpty ? otherName : 'User',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Row(
                  children: [
                    if (!chat.estOuvert)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(Icons.lock_outline,
                            size: 12, color: Colors.grey),
                      ),
                    Expanded(
                      child: Text(
                        lastText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: showUnread
                              ? Colors.black87
                              : Colors.grey[600],
                          fontWeight: showUnread
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ],
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _formatTime(lastTime),
                      style: TextStyle(
                        fontSize: 11,
                        color: showUnread ? _primaryBlue : Colors.grey,
                        fontWeight: showUnread
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    if (showUnread) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(
                          color: _primaryBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatScreen(
                        chat: chat,
                        currentUserRole: currentUserRole,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return DateFormat('HH:mm').format(dt);
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return DateFormat('EEE').format(dt);
    return DateFormat('MM/dd/yy').format(dt);
  }

  Widget _buildAvatar(String photo, String name, bool isOpen) {
    Widget avatar;
    if (photo.isNotEmpty) {
      avatar = CircleAvatar(
        radius: 24,
        backgroundImage: NetworkImage(photo),
        onBackgroundImageError: (_, __) {},
      );
    } else {
      avatar = CircleAvatar(
        radius: 24,
        backgroundColor: _primaryBlue.withOpacity(0.15),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: const TextStyle(
            color: _primaryBlue,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      );
    }

    if (!isOpen) {
      return Stack(
        children: [
          avatar,
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock,
                  size: 12, color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return avatar;
  }
}
