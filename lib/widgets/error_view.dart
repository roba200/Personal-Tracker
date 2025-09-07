import 'package:flutter/material.dart';

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.title, this.message, this.details, this.onRetry});

  final String title;
  final String? message;
  final String? details;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(title, style: t.titleMedium),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, style: t.bodyMedium, textAlign: TextAlign.center),
            ],
            if (details != null && details!.isNotEmpty) ...[
              const SizedBox(height: 8),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: const Text('Details'),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(details!, style: t.bodySmall),
                  ),
                ],
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              )
            ],
          ],
        ),
      ),
    );
  }
}

