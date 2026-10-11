import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../billing.dart';
import '../presets.dart';
import '../store.dart';
import '../subscription.dart';

class FormScreen extends StatefulWidget {
  const FormScreen({
    super.key,
    required this.store,
    required this.presets,
    required this.today,
    this.initial,
  });

  final SubscriptionStore store;
  final List<Preset> presets;
  final DateTime today;
  final Subscription? initial;

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _formKey = GlobalKey<FormState>();
  // Saving awaits rescheduling; a second tap in that window would add a
  // duplicate and pop the list route too.
  var _busy = false;
  late final _name = TextEditingController(text: widget.initial?.name);
  late final _amount = TextEditingController(
    text: widget.initial?.amountYen.toString(),
  );
  late final _memo = TextEditingController(text: widget.initial?.memo);
  late var _category = widget.initial?.category ?? Category.other;
  late var _interval = widget.initial?.intervalMonths ?? 1;
  late var _first = widget.initial?.firstBillingDate ?? dateOnly(widget.today);
  late var _notify = widget.initial == null
      ? 1
      : widget.initial!.notifyDaysBefore;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _memo.dispose();
    super.dispose();
  }

  void _applyPreset(Preset p) => setState(() {
    _name.text = p.name;
    _category = p.category;
    _interval = p.intervalMonths;
  });

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _first,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _first = picked);
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    _busy = true;
    await widget.store.upsert(
      Subscription(
        id:
            widget.initial?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        name: _name.text.trim(),
        category: _category,
        amountYen: int.parse(_amount.text),
        intervalMonths: _interval,
        firstBillingDate: _first,
        notifyDaysBefore: _notify,
        memo: _memo.text,
      ),
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${widget.initial!.name}を削除しますか？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('キャンセル'),
          ),
          TextButton(
            key: const Key('confirm-delete'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true || _busy) return;
    _busy = true;
    await widget.store.delete(widget.initial!.id);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _chips<T>(
    String label,
    List<T> values,
    T selected,
    String Function(T) text,
    void Function(T) onSelect,
  ) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        Wrap(
          spacing: 8,
          children: [
            for (final v in values)
              ChoiceChip(
                label: Text(text(v)),
                selected: v == selected,
                onSelected: (_) => setState(() => onSelect(v)),
              ),
          ],
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? '追加' : '編集'),
        actions: [
          if (widget.initial != null)
            IconButton(
              key: const Key('delete'),
              icon: const Icon(Icons.delete),
              tooltip: '削除',
              onPressed: _delete,
            ),
          IconButton(
            key: const Key('save'),
            icon: const Icon(Icons.check),
            tooltip: '保存',
            onPressed: _save,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (widget.presets.isNotEmpty)
              Wrap(
                spacing: 8,
                children: [
                  for (final p in widget.presets)
                    ActionChip(
                      key: Key('preset-${p.name}'),
                      label: Text(p.name),
                      onPressed: () => _applyPreset(p),
                    ),
                ],
              ),
            TextFormField(
              key: const Key('name'),
              controller: _name,
              decoration: const InputDecoration(labelText: '名前'),
              validator: (v) => (v ?? '').trim().isEmpty ? '名前を入力してください' : null,
            ),
            TextFormField(
              key: const Key('amount'),
              controller: _amount,
              decoration: const InputDecoration(labelText: '金額（円）'),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              validator: (v) =>
                  (int.tryParse(v ?? '') ?? 0) < 1 ? '1以上の整数を入力してください' : null,
            ),
            _chips(
              'カテゴリ',
              Category.values,
              _category,
              (c) => c.label,
              (c) => _category = c,
            ),
            _chips(
              '周期',
              intervalChoices,
              _interval,
              intervalLabel,
              (i) => _interval = i,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('初回請求日'),
              subtitle: Text('${_first.year}/${_first.month}/${_first.day}'),
              trailing: const Icon(Icons.edit_calendar),
              onTap: _pickDate,
            ),
            _chips(
              '通知',
              notifyChoices,
              _notify,
              notifyLabel,
              (n) => _notify = n,
            ),
            TextFormField(
              controller: _memo,
              decoration: const InputDecoration(labelText: 'メモ'),
              maxLines: 3,
            ),
          ],
        ),
      ),
    );
  }
}
