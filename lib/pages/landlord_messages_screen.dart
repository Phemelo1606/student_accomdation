// landlord_messages_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:student_accomdation/pages/chatScreen.dart';
import 'package:student_accomdation/core/app_logger.dart';

class LandlordMessagesScreen extends StatefulWidget {
  final String landlordId;
  final String landlordName;

  const LandlordMessagesScreen({
    super.key,
    required this.landlordId,
    required this.landlordName,
  });

  @override
  _LandlordMessagesScreenState createState() => _LandlordMessagesScreenState();
}

class _LandlordMessagesScreenState extends State<LandlordMessagesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Messages"),
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar (optional)
          _buildSearchBar(),
          // Chat list
          Expanded(
            child: _buildChatsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        decoration: InputDecoration(
          hintText: "Search conversations...",
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey.shade100,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        onChanged: (value) {
          // Implement search functionality if needed
        },
      ),
    );
  }

  Widget _buildChatsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .where('participants', arrayContains: widget.landlordId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState();
        }

        final chats = snapshot.data!.docs;

        // Sort chats by lastMessageTimestamp or createdAt locally
        chats.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final aTimestamp =
              aData['lastMessageTimestamp'] ?? aData['createdAt'];
          final bTimestamp =
              bData['lastMessageTimestamp'] ?? bData['createdAt'];

          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;

          final aTime = aTimestamp is Timestamp
              ? aTimestamp.toDate()
              : DateTime.parse(aTimestamp.toString());
          final bTime = bTimestamp is Timestamp
              ? bTimestamp.toDate()
              : DateTime.parse(bTimestamp.toString());

          return bTime.compareTo(aTime); // Descending order
        });

        return ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: chats.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final chat = chats[index].data() as Map<String, dynamic>;
            return _buildChatListItem(chat, chats[index].id);
          },
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            "No messages yet",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Your conversations will appear here",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatListItem(Map<String, dynamic> chat, String chatId) {
    final participants = List<String>.from(chat['participants'] ?? []);
    final studentId = participants.firstWhere(
      (id) => id != widget.landlordId,
      orElse: () => '',
    );

    final studentName = chat['studentName'] ?? 'Student';
    final lastMessageTimestamp =
        chat['lastMessageTimestamp'] ?? chat['createdAt'];

    // Initialize unread count if it doesn't exist
    final unreadCountField = 'unreadCount_${widget.landlordId}';
    final hasUnreadMessages =
        chat[unreadCountField] != null && chat[unreadCountField] > 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF1A237E),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              studentName[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                studentName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      hasUnreadMessages ? Colors.black : Colors.grey.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (lastMessageTimestamp != null)
              Text(
                _formatDate(lastMessageTimestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            _buildLastMessagePreview(chatId),
            if (hasUnreadMessages) ...[
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'New',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        onTap: () {
          _openChat(studentId, studentName, chatId);
        },
        trailing: hasUnreadMessages
            ? Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildLastMessagePreview(String chatId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final lastMessage =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final messageText = lastMessage['text'] ?? '';
          final isSentByMe = lastMessage['senderId'] == widget.landlordId;

          return Row(
            children: [
              if (isSentByMe)
                const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.grey,
                ),
              if (isSentByMe) const SizedBox(width: 4),
              Expanded(
                child: Text(
                  messageText.isNotEmpty
                      ? (messageText.length > 35
                          ? '${messageText.substring(0, 35)}...'
                          : messageText)
                      : "Start a conversation",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }
        return Text(
          "Start a conversation",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        );
      },
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      final DateTime time = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.parse(timestamp.toString());

      final now = DateTime.now();
      final difference = now.difference(time);

      if (difference.inMinutes < 1) {
        return 'Now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays == 0) {
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${time.day}/${time.month}/${time.year}';
      }
    } catch (e) {
      return '';
    }
  }

  void _openChat(String studentId, String studentName, String chatId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          landlordId: widget.landlordId,
          landlordName: widget.landlordName,
          studentId: studentId,
          studentName: studentName,
        ),
      ),
    ).then((_) {
      // Mark messages as read when returning from chat
      _markMessagesAsRead(chatId);
    });
  }

  Future<void> _markMessagesAsRead(String chatId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .update({'unreadCount_${widget.landlordId}': 0});
    } catch (e) {
      AppLogger.log('Error marking messages as read: $e');
    }
  }
}

// Enhanced version with additional features
class LandlordMessagesScreenEnhanced extends StatefulWidget {
  final String landlordId;
  final String landlordName;

  const LandlordMessagesScreenEnhanced({
    super.key,
    required this.landlordId,
    required this.landlordName,
  });

  @override
  _LandlordMessagesScreenEnhancedState createState() =>
      _LandlordMessagesScreenEnhancedState();
}

class _LandlordMessagesScreenEnhancedState
    extends State<LandlordMessagesScreenEnhanced> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Messages",
              style:
                  TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1A237E),
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: "All Chats"),
              Tab(text: "Unread"),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () {
                _showSearchDialog();
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            _buildAllChatsTab(),
            _buildUnreadChatsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildAllChatsTab() {
    return Column(
      children: [
        if (_searchQuery.isNotEmpty) _buildSearchHeader(),
        Expanded(
          child: _buildChatsList(filterUnread: false),
        ),
      ],
    );
  }

  Widget _buildUnreadChatsTab() {
    return _buildChatsList(filterUnread: true);
  }

  Widget _buildSearchHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.grey.shade100,
      child: Row(
        children: [
          Text(
            "Search: \"$_searchQuery\"",
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, size: 20),
            onPressed: () {
              setState(() {
                _searchQuery = '';
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatsList({bool filterUnread = false}) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .where('participants', arrayContains: widget.landlordId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyState(filterUnread);
        }

        List<QueryDocumentSnapshot> chats = snapshot.data!.docs;

        // Apply search filter if search query exists
        if (_searchQuery.isNotEmpty) {
          chats = chats.where((chat) {
            final chatData = chat.data() as Map<String, dynamic>;
            final studentName = chatData['studentName'] ?? 'Student';
            return studentName
                .toLowerCase()
                .contains(_searchQuery.toLowerCase());
          }).toList();
        }

        // Apply unread filter
        if (filterUnread) {
          chats = chats.where((chat) {
            final chatData = chat.data() as Map<String, dynamic>;
            final unreadCountField = 'unreadCount_${widget.landlordId}';
            return chatData[unreadCountField] != null &&
                chatData[unreadCountField] > 0;
          }).toList();
        }

        if (chats.isEmpty) {
          return _buildNoResultsState();
        }

        // Sort chats by lastMessageTimestamp or createdAt locally
        chats.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;

          final aTimestamp =
              aData['lastMessageTimestamp'] ?? aData['createdAt'];
          final bTimestamp =
              bData['lastMessageTimestamp'] ?? bData['createdAt'];

          if (aTimestamp == null) return 1;
          if (bTimestamp == null) return -1;

          final aTime = aTimestamp is Timestamp
              ? aTimestamp.toDate()
              : DateTime.parse(aTimestamp.toString());
          final bTime = bTimestamp is Timestamp
              ? bTimestamp.toDate()
              : DateTime.parse(bTimestamp.toString());

          return bTime.compareTo(aTime); // Descending order
        });

        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: chats.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final chat = chats[index].data() as Map<String, dynamic>;
            return _buildChatListItem(chat, chats[index].id);
          },
        );
      },
    );
  }

  Widget _buildEmptyState(bool filterUnread) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            filterUnread ? "No unread messages" : "No messages yet",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            filterUnread
                ? "You're all caught up!"
                : "Your conversations will appear here",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          const Text(
            "No conversations found",
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Try searching with different terms",
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Search Conversations"),
        content: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: "Enter student name...",
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _searchQuery = '';
              });
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text("Search"),
          ),
        ],
      ),
    );
  }

  // Reuse the same methods from the basic version
  Widget _buildChatListItem(Map<String, dynamic> chat, String chatId) {
    final participants = List<String>.from(chat['participants'] ?? []);
    final studentId = participants.firstWhere(
      (id) => id != widget.landlordId,
      orElse: () => '',
    );

    final studentName = chat['studentName'] ?? 'Student';
    final lastMessageTimestamp =
        chat['lastMessageTimestamp'] ?? chat['createdAt'];
    final unreadCountField = 'unreadCount_${widget.landlordId}';
    final hasUnreadMessages =
        chat[unreadCountField] != null && chat[unreadCountField] > 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF1A237E),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              studentName[0].toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                studentName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color:
                      hasUnreadMessages ? Colors.black : Colors.grey.shade700,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (lastMessageTimestamp != null)
              Text(
                _formatDate(lastMessageTimestamp),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                ),
              ),
          ],
        ),
        subtitle: _buildLastMessagePreview(chatId),
        onTap: () {
          _openChat(studentId, studentName, chatId);
        },
        trailing: hasUnreadMessages
            ? Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildLastMessagePreview(String chatId) {
    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .orderBy('timestamp', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          final lastMessage =
              snapshot.data!.docs.first.data() as Map<String, dynamic>;
          final messageText = lastMessage['text'] ?? '';
          final isSentByMe = lastMessage['senderId'] == widget.landlordId;

          return Row(
            children: [
              if (isSentByMe)
                const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.grey,
                ),
              if (isSentByMe) const SizedBox(width: 4),
              Expanded(
                child: Text(
                  messageText.isNotEmpty
                      ? (messageText.length > 35
                          ? '${messageText.substring(0, 35)}...'
                          : messageText)
                      : "Start a conversation",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }
        return Text(
          "Start a conversation",
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade500,
            fontStyle: FontStyle.italic,
          ),
        );
      },
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';

    try {
      final DateTime time = timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.parse(timestamp.toString());

      final now = DateTime.now();
      final difference = now.difference(time);

      if (difference.inMinutes < 1) {
        return 'Now';
      } else if (difference.inHours < 1) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inDays == 0) {
        return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${time.day}/${time.month}/${time.year}';
      }
    } catch (e) {
      return '';
    }
  }

  void _openChat(String studentId, String studentName, String chatId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          landlordId: widget.landlordId,
          landlordName: widget.landlordName,
          studentId: studentId,
          studentName: studentName,
        ),
      ),
    ).then((_) {
      _markMessagesAsRead(chatId);
    });
  }

  Future<void> _markMessagesAsRead(String chatId) async {
    try {
      await _firestore
          .collection('chats')
          .doc(chatId)
          .update({'unreadCount_${widget.landlordId}': 0});
    } catch (e) {
      AppLogger.log('Error marking messages as read: $e');
    }
  }
}
