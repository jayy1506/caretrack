import 'package:flutter/material.dart';
import '../../../models/conversation_model.dart';
import '../../../services/inbox_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/empty_state_view.dart';

class InboxScreen extends StatefulWidget {
  final String clinicId;

  const InboxScreen({super.key, this.clinicId = 'default-clinic'});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  final _inboxService = InboxService();
  bool _showResolved = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinic WhatsApp Inbox'),
        actions: [
          Row(
            children: [
              const Text('Show Resolved', style: TextStyle(fontSize: 12)),
              Switch(
                value: _showResolved,
                activeTrackColor: AppTheme.mintAccent,
                onChanged: (val) => setState(() => _showResolved = val),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
      body: StreamBuilder<List<ConversationThreadModel>>(
        stream: _inboxService.streamClinicConversations(
          clinicId: widget.clinicId,
        ),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final threads = snapshot.data ?? [];

          if (threads.isEmpty) {
            return const EmptyStateView(
              icon: Icons.chat_bubble_outline,
              title: 'No Active Messages',
              description: 'Patient inquiries and two-way WhatsApp replies will appear here.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: threads.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final thread = threads[index];
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: thread.isUrgent
                      ? AppTheme.statusMissedText.withAlpha(77)
                      : AppTheme.borderGrey,
                  ),
                  boxShadow: AppTheme.softShadow,
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(14),
                  leading: Stack(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: thread.isUrgent ? AppTheme.statusMissedBg : const Color(0xFFEFF6FF),
                        child: Text(
                          thread.patientName.isNotEmpty ? thread.patientName[0].toUpperCase() : 'P',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: thread.isUrgent ? AppTheme.statusMissedText : AppTheme.primaryTeal,
                          ),
                        ),
                      ),
                      if (thread.isUrgent)
                        const Positioned(
                          right: 0,
                          top: 0,
                          child: Icon(Icons.error, color: AppTheme.statusMissedText, size: 16),
                        ),
                    ],
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          thread.patientName,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                      ),
                      if (thread.isUrgent)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.statusMissedBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'URGENT',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.statusMissedText,
                            ),
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        thread.lastMessageText,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: thread.unreadCount > 0 ? AppTheme.slateDark : AppTheme.slateMuted,
                          fontWeight: thread.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  trailing: thread.unreadCount > 0
                      ? CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.primaryTeal,
                          child: Text(
                            '${thread.unreadCount}',
                            style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        )
                      : null,
                  onTap: () => _openChatView(context, thread),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _openChatView(BuildContext context, ConversationThreadModel thread) {
    final textController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            top: 20,
            left: 20,
            right: 20,
          ),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.75,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(thread.patientName, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                        Text(thread.patientPhone, style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted)),
                      ],
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.check_circle_outline, color: AppTheme.statusConfirmedText),
                          tooltip: 'Resolve Conversation',
                          onPressed: () async {
                            await _inboxService.manageThread(
                              patientId: thread.patientId,
                              action: 'resolve',
                            );
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(),
                Expanded(
                  child: StreamBuilder<List<ConversationMessageModel>>(
                    stream: _inboxService.streamMessages(thread.patientId),
                    builder: (context, msgSnap) {
                      final messages = msgSnap.data ?? [];
                      if (messages.isEmpty) {
                        return const Center(child: Text('No messages yet.'));
                      }
                      return ListView.builder(
                        reverse: true,
                        itemCount: messages.length,
                        itemBuilder: (context, i) {
                          final m = messages[messages.length - 1 - i];
                          final isClinic = m.isFromClinic;
                          return Align(
                            alignment: isClinic ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: isClinic ? AppTheme.primaryTeal : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                m.text,
                                style: TextStyle(
                                  color: isClinic ? Colors.white : AppTheme.slateDark,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textController,
                          decoration: InputDecoration(
                            hintText: 'Type WhatsApp reply (24-hr window active)...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppTheme.primaryTeal,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.send),
                        onPressed: () async {
                          final text = textController.text.trim();
                          if (text.isEmpty) return;
                          textController.clear();
                          await _inboxService.replyConversation(
                            patientId: thread.patientId,
                            message: text,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
