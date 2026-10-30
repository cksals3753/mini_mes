import 'package:flutter/material.dart';

class InventoryAsyncStatus extends StatelessWidget {
  const InventoryAsyncStatus({super.key, this.error, required this.onRetry});
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: error == null
          ? const CircularProgressIndicator()
          : Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('재고 조회에 실패했습니다.'),
                  const SizedBox(height: 12),
                  FilledButton(onPressed: onRetry, child: const Text('재시도')),
                ],
              ),
            ),
    );
  }
}
