import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/inventory_provider.dart';
import '../widgets/inventory_async_status.dart';

class InventoryDetailScreen extends ConsumerStatefulWidget {
  const InventoryDetailScreen({super.key, required this.itemId});

  final String itemId;

  @override
  ConsumerState<InventoryDetailScreen> createState() =>
      _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends ConsumerState<InventoryDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  bool _isIncoming = true;
  bool _isSubmitting = false;
  String? _processingError;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String? _validateAmount(String? value) {
    final text = value ?? '';
    final amount = int.tryParse(text);
    if (!RegExp(r'^[0-9]+$').hasMatch(text) || amount == null || amount <= 0) {
      return '수량은 양의 정수로 입력해 주세요.';
    }
    return ref
        .read(inventoryProvider.notifier)
        .validateStockChange(widget.itemId, amount, _isIncoming);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) return;
    final incoming = _isIncoming;
    setState(() {
      _isSubmitting = true;
      _processingError = null;
    });
    final error = await ref
        .read(inventoryProvider.notifier)
        .changeStock(
          widget.itemId,
          int.parse(_amountController.text),
          incoming,
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (error != null) {
      setState(() => _processingError = error);
      return;
    }
    setState(() {
      _processingError = null;
      _amountController.clear();
      _formKey.currentState!.reset();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${incoming ? '입고' : '출고'} 처리가 완료되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(inventoryProvider);
    if (inventory.isLoading || inventory.hasError) {
      return Scaffold(
        appBar: AppBar(title: const Text('품목 상세')),
        body: InventoryAsyncStatus(
          error: inventory.isLoading ? null : inventory.error,
          onRetry: () => ref.invalidate(inventoryProvider),
        ),
      );
    }
    final item = inventory.requireValue
        .where((item) => item.id == widget.itemId)
        .firstOrNull;
    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('품목 상세')),
        body: const Center(child: Text('품목을 찾을 수 없습니다.')),
      );
    }
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('품목 상세')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card.outlined(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(item.itemName, style: theme.textTheme.headlineSmall),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: item.isLowStock
                              ? colors.errorContainer
                              : colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '재고 상태 · ${item.isLowStock ? '재고 부족' : '정상'}',
                          style: TextStyle(
                            color: item.isLowStock
                                ? colors.onErrorContainer
                                : colors.onSecondaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _field(context, '품목코드', item.itemCode),
                      _field(context, '품목명', item.itemName),
                      _field(context, 'LOT 번호', item.lotNo),
                      _field(context, '현재고', '${item.quantity} ${item.unit}'),
                      _field(
                        context,
                        '안전재고',
                        '${item.safetyStock} ${item.unit}',
                      ),
                      _field(context, '단위', item.unit),
                      _field(context, '보관 위치', item.location),
                      const Divider(height: 32),
                      Text('입고·출고 처리', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(value: true, label: Text('입고')),
                                ButtonSegment(value: false, label: Text('출고')),
                              ],
                              selected: {_isIncoming},
                              onSelectionChanged: _isSubmitting
                                  ? null
                                  : (selection) {
                                      setState(() {
                                        _isIncoming = selection.single;
                                        _processingError = null;
                                      });
                                      _formKey.currentState!.reset();
                                    },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              key: const ValueKey('stockAmount'),
                              controller: _amountController,
                              enabled: !_isSubmitting,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: '처리 수량',
                                helperText: '1 이상의 정수를 입력해 주세요.',
                                suffixText: item.unit,
                              ),
                              validator: _validateAmount,
                              onFieldSubmitted: (_) => _submit(),
                            ),
                            if (_processingError != null)
                              Text(
                                _processingError!,
                                style: TextStyle(color: colors.error),
                              ),
                            const SizedBox(height: 16),
                            FilledButton(
                              onPressed: _isSubmitting ? null : _submit,
                              child: _isSubmitting
                                  ? const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text('처리 중...'),
                                      ],
                                    )
                                  : Text('${_isIncoming ? '입고' : '출고'} 처리'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ],
      ),
    );
  }
}
