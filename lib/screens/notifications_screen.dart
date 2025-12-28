import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../services/session_service.dart';

class NotificationsScreen extends StatefulWidget {
  final String? userId;

  const NotificationsScreen({super.key, this.userId});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final _session = SessionService.instance;

  String? get _userId => widget.userId ?? _session.currentUserId;

  Stream<QuerySnapshot<Map<String, dynamic>>> _stream(String userId) {
    return FirebaseFirestore.instance
        .collection('notifications')
        .doc(userId)
        .collection('items')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }

  Future<void> _markAllRead(List<NotificationItem> items) async {
    final unread = items.where((item) => !item.read).toList();
    if (unread.isEmpty || _userId == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final userId = _userId!;
    for (final item in unread) {
      final ref = FirebaseFirestore.instance
          .collection('notifications')
          .doc(userId)
          .collection('items')
          .doc(item.id);
      batch.update(ref, {'read': true});
    }
    await batch.commit();
  }

  Future<void> _markRead(NotificationItem item) async {
    if (item.read || _userId == null) return;
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(_userId!)
        .collection('items')
        .doc(item.id)
        .update({'read': true});
  }

  Future<void> _delete(NotificationItem item) async {
    if (_userId == null) return;
    await FirebaseFirestore.instance
        .collection('notifications')
        .doc(_userId!)
        .collection('items')
        .doc(item.id)
        .delete();
  }

  String _timeAgo(DateTime? date) {
    if (date == null) return '-';
    final seconds = DateTime.now().difference(date).inSeconds;
    if (seconds < 60) return 'Just now';
    if (seconds < 3600) return '${seconds ~/ 60}m ago';
    if (seconds < 86400) return '${seconds ~/ 3600}h ago';
    if (seconds < 604800) return '${seconds ~/ 86400}d ago';
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final userId = _userId;
    if (userId == null || userId.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('Please sign in to view notifications.'),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.white,
        elevation: 0.4,
        foregroundColor: Colors.black,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream(userId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryPink),
            );
          }

          if (snapshot.hasError) {
            return const Center(
              child: Text('Could not load notifications.'),
            );
          }

          final items = snapshot.data?.docs
                  .map((doc) => NotificationItem.fromDoc(doc))
                  .toList() ??
              [];
          final unreadCount = items.where((item) => !item.read).length;

          if (items.isEmpty) {
            return const Center(
              child: Text('No notifications yet.'),
            );
          }

          return Column(
            children: [
              if (unreadCount > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _markAllRead(items),
                      child: const Text('Mark all read'),
                    ),
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _NotificationTile(
                      item: item,
                      timeLabel: _timeAgo(item.createdAt),
                      onTap: () => _markRead(item),
                      onDelete: () => _delete(item),
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
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String type;
  final bool read;
  final String? actionUrl;
  final DateTime? createdAt;

  const NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.read,
    required this.actionUrl,
    required this.createdAt,
  });

  factory NotificationItem.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final createdRaw = data['createdAt'];
    DateTime? createdAt;
    if (createdRaw is Timestamp) {
      createdAt = createdRaw.toDate();
    }
    return NotificationItem(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      type: (data['type'] ?? '').toString(),
      read: data['read'] == true,
      actionUrl: data['actionUrl']?.toString(),
      createdAt: createdAt,
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationItem item;
  final String timeLabel;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _NotificationTile({
    required this.item,
    required this.timeLabel,
    required this.onTap,
    required this.onDelete,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case 'appointment_booked':
        return Icons.check_circle_rounded;
      case 'appointment_cancelled_by_customer':
      case 'appointment_cancelled_by_business':
      case 'appointment_assigned_cancelled':
        return Icons.cancel_rounded;
      case 'appointment_reminder_week':
      case 'appointment_reminder_day':
        return Icons.alarm_rounded;
      case 'staff_added':
      case 'appointment_assigned':
        return Icons.person_add_alt_rounded;
      case 'staff_removed':
        return Icons.person_remove_alt_1_rounded;
      default:
        return Icons.notifications_none_rounded;
    }
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'appointment_booked':
        return Colors.green.shade600;
      case 'appointment_cancelled_by_customer':
      case 'appointment_cancelled_by_business':
      case 'appointment_assigned_cancelled':
        return Colors.red.shade400;
      case 'appointment_reminder_week':
      case 'appointment_reminder_day':
        return Colors.orange.shade600;
      case 'staff_added':
      case 'appointment_assigned':
        return primaryPink;
      case 'staff_removed':
        return Colors.grey.shade600;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = _colorForType(item.type);
    final titleStyle = TextStyle(
      fontSize: 13,
      fontWeight: item.read ? FontWeight.w600 : FontWeight.w700,
      color: Colors.black,
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _iconForType(item.type),
                size: 18,
                color: iconColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: titleStyle),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black54,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.close_rounded, size: 18),
                  color: Colors.grey.shade600,
                ),
                if (!item.read)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: primaryPink,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
