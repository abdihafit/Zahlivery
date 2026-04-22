import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class SupportContactCard extends StatelessWidget {
  const SupportContactCard({
    super.key,
    this.title = 'Support & Complaints',
  });

  static const String supportEmail = 'abdihafitofficial@gmail.com';
  static const String whatsappUrl = 'https://wa.me/254722940735';

  final String title;

  Future<void> _launchUrl(BuildContext context, Uri uri) async {
    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open support contact right now.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0x1A6DBE00),
                  child: Icon(
                    Icons.support_agent_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Report issues, ask for help, or send a complaint directly to support.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () {
                    _launchUrl(
                      context,
                      Uri(
                        scheme: 'mailto',
                        path: supportEmail,
                        query:
                            'subject=${Uri.encodeComponent('Zahlivery support request')}',
                      ),
                    );
                  },
                  icon: const Icon(Icons.email_outlined),
                  label: const Text('Email Support'),
                ),
                OutlinedButton.icon(
                  onPressed: () {
                    _launchUrl(context, Uri.parse(whatsappUrl));
                  },
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('WhatsApp Support'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SelectableText(
              'Email: $supportEmail\nWhatsApp: $whatsappUrl',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
