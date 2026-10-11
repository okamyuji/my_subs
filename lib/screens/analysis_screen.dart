import 'package:flutter/material.dart';

import '../billing.dart';
import '../store.dart';

class AnalysisScreen extends StatelessWidget {
  const AnalysisScreen({super.key, required this.store, required this.today});

  final SubscriptionStore store;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('カテゴリ別')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final rows = categoryTotals(store.items, today);
          if (rows.isEmpty) return const Center(child: Text('登録がありません'));
          final total = rows.fold(0.0, (sum, r) => sum + r.$2);
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '月額換算 ${yen(total)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              for (final (category, value) in rows)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(category.label),
                          Text(
                            '${yen(value)}（${(value * 100 / total).round()}%）',
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      LinearProgressIndicator(
                        value: value / total,
                        minHeight: 10,
                      ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
