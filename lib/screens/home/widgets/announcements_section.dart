import 'package:flutter/material.dart';

class AnnouncementsSection extends StatelessWidget {
  const AnnouncementsSection({super.key, required this.announcements});

  final List<dynamic> announcements;

  @override
  Widget build(BuildContext context) {
    if (announcements.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            'No announcements.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children:
          announcements.map((announcement) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.05),
                border: Border.all(color: Colors.orange.withOpacity(0.2)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.campaign_rounded,
                    color: Colors.orange,
                    size: 20,
                  ),
                ),
                title: Text(
                  announcement['title'] ?? 'Announcement',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4.0),
                  child: Text(
                    announcement['published_at'] ?? '',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ),
              ),
            );
          }).toList(),
    );
  }
}
