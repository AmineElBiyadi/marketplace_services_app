import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/chat_service.dart';
import '../../models/chat_model.dart';
import '../chat/chat_screen.dart';
import '../../widgets/shared/client_header.dart';
import '../../widgets/live_avatar.dart';

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
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currentUserRole == 'expert')
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 32, 20, 0),
                    child: Text(
                      "Messages",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  )
                else
                  const ClientHeader(
                    title: "Messages",
                    subtitle: "Chat with your service providers",
                    bottomPadding: 10,
                  ),
                Expanded(
                  child: Center(
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
                  ),
                ),
              ],
            );
          }

          final chats = snapshot.data!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (currentUserRole == 'expert')
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 32, 20, 0),
                  child: Text(
                    "Messages",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                )
              else
                const ClientHeader(
                  title: "Messages",
                  subtitle: "Chat with your service providers",
                  bottomPadding: 10,
                ),
              Expanded(
                child: ListView.separated(
                  padding: currentUserRole == 'expert' ? const EdgeInsets.only(top: 16) : null,
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
                    final unread = currentUserRole == 'client'
                        ? chat.unreadCountClient
                        : chat.unreadCountExpert;

                    final showUnread = unread > 0;

                    final serviceNom = chat.tacheSnapshot?['serviceNom'] as String? ?? 'Request';
                    final taskNom = chat.tacheSnapshot?['nom'] as String? ?? 'General discussion';
                    final hasTaskInfo = true;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 6),
                      leading: _buildAvatar(chat, otherPhoto, otherName, currentUserRole),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              otherName.isNotEmpty ? otherName : 'User',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (hasTaskInfo)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              margin: const EdgeInsets.only(left: 6),
                              decoration: BoxDecoration(
                                color: _primaryBlue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '$serviceNom',
                                style: const TextStyle(fontSize: 10, color: _primaryBlue, fontWeight: FontWeight.w600),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (hasTaskInfo)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 2),
                              child: Text(
                                taskNom,
                                style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                              ),
                            ),
                          Row(
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
                ),
              ),
            ],
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

  Widget _buildAvatar(ChatModel chat, String photo, String name, String role) {
    final otherId = role == 'client' ? chat.idExpert : chat.idClient;
    final otherType = role == 'client' ? 'expert' : 'client';

    Widget avatar = LiveAvatar(
      id: otherId,
      fallbackPhoto: photo,
      fallbackName: name,
      radius: 24,
      type: otherType,
    );

    if (!chat.estOuvert) {
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
              child: const Icon(Icons.lock, size: 12, color: Colors.grey),
            ),
          ),
        ],
      );
    }

    return avatar;
  }
}
