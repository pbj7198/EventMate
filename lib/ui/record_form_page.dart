// Add/edit screen for occasion records with a quick-first layout.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/occasion_record.dart';
import '../models/person.dart';
import '../models/record_input.dart';
import '../services/contact_import_service.dart';
import '../state/inyeon_controller.dart';
import '../utils/formatters.dart';

class RecordFormPage extends ConsumerStatefulWidget {
  const RecordFormPage({super.key, this.initialRecord, this.initialPersonId});

  final OccasionRecord? initialRecord;
  final String? initialPersonId;

  @override
  ConsumerState<RecordFormPage> createState() => _RecordFormPageState();
}

class _RecordFormPageState extends ConsumerState<RecordFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _amountController;
  late final TextEditingController _locationController;
  late final TextEditingController _memoController;
  late final TextEditingController _customEventController;
  late DateTime _date;
  late EventType _eventType;
  late TransactionType _transactionType;
  String _relationship = relationshipOptions.first;
  Person? _linkedPerson;
  bool _isImportingContact = false;

  @override
  void initState() {
    super.initState();
    final controller = ref.read(inyeonControllerProvider.notifier);
    final record = widget.initialRecord;
    _linkedPerson = widget.initialPersonId == null
        ? null
        : controller.personById(widget.initialPersonId!);
    final person = _linkedPerson;

    _nameController = TextEditingController(
      text: record?.personName ?? person?.name ?? '',
    );
    _phoneController = TextEditingController(text: person?.phoneNumber ?? '');
    _amountController = TextEditingController(
      text: record?.amount.toString() ?? '',
    );
    _locationController = TextEditingController(text: record?.location ?? '');
    _memoController = TextEditingController(
      text: record?.memo ?? person?.memo ?? '',
    );
    _customEventController = TextEditingController(
      text: record?.customEventType ?? '',
    );
    _date = record?.date ?? DateTime.now();
    _eventType = record?.eventType ?? EventType.wedding;
    _transactionType = record?.transactionType ?? TransactionType.given;
    _relationship =
        record?.relationship ?? person?.relationship ?? relationshipOptions.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _amountController.dispose();
    _locationController.dispose();
    _memoController.dispose();
    _customEventController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialRecord != null;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final customEventTypes = _customEventLabels(ref);

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '경조사 기록 수정' : '경조사 기록 추가')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              24 + bottomInset + bottomPadding + kBottomNavigationBarHeight,
            ),
            children: [
              Text(
                '빠르게 입력하고, 필요한 정보만 바로 채울 수 있게 구성했어요.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _fieldTitle('이름'),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _nameController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: '예: 김민수',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return '이름을 입력해주세요.';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    height: 56,
                    child: OutlinedButton.icon(
                      onPressed: _isImportingContact ? null : _importFromContact,
                      icon: _isImportingContact
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.contacts_outlined),
                      label: const Text('연락처'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _fieldTitle('휴대폰 번호'),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(hintText: '예: 010-1234-5678'),
              ),
              const SizedBox(height: 16),
              _fieldTitle('관계'),
              DropdownButtonFormField<String>(
                initialValue: _relationship,
                items: relationshipOptions
                    .map(
                      (relationship) => DropdownMenuItem(
                        value: relationship,
                        child: Text(relationship),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _relationship = value);
                  }
                },
              ),
              const SizedBox(height: 16),
              _fieldTitle('행사 종류'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final type in EventType.values)
                    ChoiceChip(
                      label: Text(type.label),
                      selected: _eventType == type &&
                          (type != EventType.other ||
                              _customEventController.text.trim().isEmpty),
                      onSelected: (_) => setState(() {
                        _eventType = type;
                        if (type != EventType.other) {
                          _customEventController.clear();
                        }
                      }),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('직접 추가'),
                    onPressed: _showCustomEventDialog,
                  ),
                ],
              ),
              if (customEventTypes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '최근 사용한 행사',
                  style: Theme.of(context).textTheme.labelLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: customEventTypes.map((label) {
                    final selected = _eventType == EventType.other &&
                        _customEventController.text.trim() == label;
                    return ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => setState(() {
                        _eventType = EventType.other;
                        _customEventController.text = label;
                      }),
                    );
                  }).toList(),
                ),
              ],
              if (_eventType == EventType.other) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _customEventController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    hintText: '행사 종류를 직접 입력하세요',
                  ),
                  validator: (value) {
                    if (_eventType == EventType.other &&
                        (value == null || value.trim().isEmpty)) {
                      return '직접 추가한 행사 이름을 입력해주세요.';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 16),
              _fieldTitle('구분'),
              SegmentedButton<TransactionType>(
                segments: TransactionType.values
                    .map(
                      (type) => ButtonSegment(
                        value: type,
                        label: Text(type.label),
                      ),
                    )
                    .toList(),
                selected: {_transactionType},
                onSelectionChanged: (selected) {
                  setState(() => _transactionType = selected.first);
                },
              ),
              const SizedBox(height: 16),
              _fieldTitle('날짜'),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_month_outlined),
                label: Text(formatDate(_date)),
              ),
              const SizedBox(height: 16),
              _fieldTitle('금액'),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: '예: 100000'),
                validator: (value) {
                  final parsed = int.tryParse(value?.replaceAll(',', '') ?? '');
                  if (parsed == null || parsed <= 0) {
                    return '올바른 금액을 입력해주세요.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _QuickAmountButton(
                    label: '+1만원',
                    onPressed: () => _addAmount(10000),
                  ),
                  _QuickAmountButton(
                    label: '+5만원',
                    onPressed: () => _addAmount(50000),
                  ),
                  _QuickAmountButton(
                    label: '+10만원',
                    onPressed: () => _addAmount(100000),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _fieldTitle('장소'),
              TextFormField(
                controller: _locationController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: '예: 서울 웨딩홀'),
              ),
              const SizedBox(height: 16),
              _fieldTitle('메모'),
              TextFormField(
                controller: _memoController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: '받은 이야기, 인상 깊었던 메모를 남겨보세요',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.save_outlined),
                label: const Text('저장'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  List<String> _customEventLabels(WidgetRef ref) {
    final labels = ref
        .watch(inyeonControllerProvider)
        .records
        .map((record) => record.customEventType?.trim())
        .where((label) => label != null && label.isNotEmpty)
        .cast<String>()
        .toSet()
        .toList()
      ..sort();
    return labels;
  }

  void _addAmount(int amount) {
    final current = int.tryParse(
          _amountController.text.replaceAll(',', '').trim(),
        ) ??
        0;
    setState(() {
      _amountController.text = (current + amount).toString();
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _showCustomEventDialog() async {
    final controller = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('행사 종류 추가'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '예: 상견례, 회갑, 승진 축하',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('추가'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (label == null || label.trim().isEmpty) {
      return;
    }
    setState(() {
      _eventType = EventType.other;
      _customEventController.text = label.trim();
    });
  }

  Future<void> _importFromContact() async {
    final service = ref.read(contactImportServiceProvider);
    setState(() => _isImportingContact = true);
    try {
      var permitted = await service.hasPermission();
      if (!permitted) {
        permitted = await service.requestPermission();
      }
      if (!permitted) {
        if (!mounted) {
          return;
        }
        final openSettings = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('연락처 권한 필요'),
            content: const Text(
              '연락처에서 이름과 전화번호를 불러오려면 권한이 필요해요.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('나중에'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('설정 열기'),
              ),
            ],
          ),
        );
        if (openSettings == true) {
          await service.openSettings();
        }
        return;
      }

      final draft = await service.pickContact();
      if (draft == null || !mounted) {
        return;
      }

      setState(() {
        if (draft.name.trim().isNotEmpty) {
          _nameController.text = draft.name.trim();
        }
        if (draft.phoneNumber.trim().isNotEmpty) {
          _phoneController.text = draft.phoneNumber.trim();
        }
      });
    } finally {
      if (mounted) {
        setState(() => _isImportingContact = false);
      }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final amount = int.parse(_amountController.text.replaceAll(',', ''));
    final controller = ref.read(inyeonControllerProvider.notifier);
    await controller.saveRecord(
      RecordInput(
        recordId: widget.initialRecord?.id,
        personId: widget.initialRecord?.personId ?? widget.initialPersonId,
        personName: _nameController.text.trim(),
        relationship: _relationship,
        eventType: _eventType,
        customEventType: _eventType == EventType.other
            ? _customEventController.text.trim()
            : null,
        date: _date,
        amount: amount,
        transactionType: _transactionType,
        location: _locationController.text,
        memo: _memoController.text,
        phoneNumber: _phoneController.text,
      ),
    );

    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }
}

class _QuickAmountButton extends StatelessWidget {
  const _QuickAmountButton({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}
