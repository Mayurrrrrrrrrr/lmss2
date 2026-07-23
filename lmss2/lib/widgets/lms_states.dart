import 'package:flutter/material.dart';

class LmsLoadingState extends StatelessWidget {
  final String label;
  const LmsLoadingState({super.key, this.label = 'Loading…'});
  @override
  Widget build(BuildContext context) => Center(child: Semantics(
    liveRegion: true,
    label: label,
    child: const SizedBox.square(dimension: 32, child: CircularProgressIndicator(strokeWidth: 3)),
  ));
}

class LmsEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  const LmsEmptyState({super.key, required this.icon, required this.title, required this.message, this.action});
  @override
  Widget build(BuildContext context) => Center(child: ConstrainedBox(
    constraints: const BoxConstraints(maxWidth: 460),
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 52, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Text(message, style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant), textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ]),
    ),
  ));
}

class LmsErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const LmsErrorState({super.key, required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) => LmsEmptyState(
    icon: Icons.error_outline,
    title: 'Something went wrong',
    message: message,
    action: onRetry == null ? null : FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Try again')),
  );
}
