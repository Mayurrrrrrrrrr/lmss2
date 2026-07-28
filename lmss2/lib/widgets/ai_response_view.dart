import 'package:flutter/material.dart';

class AiResponseView extends StatelessWidget {
  final Object value;
  const AiResponseView({super.key, required this.value});

  String _label(String key) => key
      .replaceAll('_', ' ')
      .split(' ')
      .where((part) => part.isNotEmpty)
      .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');

  Widget _render(BuildContext context, Object? item, {String? label}) {
    if (item == null) return const SizedBox.shrink();
    if (item is Map) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: item.entries
            .where((entry) => entry.key != 'cached' && entry.value != null)
            .map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _render(
                  context,
                  entry.value,
                  label: _label(entry.key.toString()),
                ),
              ),
            )
            .toList(),
      );
    }
    if (item is Iterable) {
      final values = item.toList();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (label != null)
            Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          ...values.map(
            (value) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _render(context, value),
              ),
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null)
          Text(label, style: Theme.of(context).textTheme.labelLarge),
        if (label != null) const SizedBox(height: 4),
        SelectableText(item.toString()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'AI generated learning response',
    child: _render(context, value),
  );
}
