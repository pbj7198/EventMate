// Add/edit screen for occasion records with a quick-first layout.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/enums.dart';
import '../models/occasion_record.dart';
import '../models/person.dart';
import '../models/record_input.dart';
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
  late DateTime _date;
  late EventType _eventType;
  late TransactionType _transactionType;
  String _relationship = relationshipOptions.first;
  Person? _linkedPerson;
  bool _showMore = false;

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
    _amountController = TextEditingController(text: record?.amount.toString() ?? '');
    _locationController = TextEditingController(text: record?.location ?? '');
    _memoController = TextEditingController(text: record?.memo ?? person?.memo ?? '');
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initialRecord != null;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? '경조사 수정' : '경조사 기록 추가')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24 + bottomInset + bottomPadding),
            children: [
              Text(
                '먼저 핵심 정보만 빠르게 입력하고, 필요한 경우 추가 정보를 펼쳐보세요.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _fieldTitle('이름'),
              TextFormField(
                controller: _nameController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(hintText: '예: 김민수'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '이름을 입력해주세요.';
                  }
                  return null;
                },
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
                children: EventType.values
                    .map(
                      (type) => ChoiceChip(
                        label: Text(type.label),
                        selected: _eventType == type,
                        onSelected: (_) => setState(() => _eventType = type),
                      ),
                    )
                    .toList(),
              ),
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
              TextButton.icon(
                onPressed: () => setState(() => _showMore = !_showMore),
                icon: Icon(_showMore ? Icons.expand_less : Icons.expand_more),
                label: Text(_showMore ? '추가 정보 접기' : '추가 정보 보기'),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                crossFadeState: _showMore
                    ? CrossFadeState.showFirst
                    : CrossFadeState.showSecond,
                firstChild: Column(
                  children: [
                    const SizedBox(height: 8),
                    _fieldTitle('장소'),
                    TextFormField(
                      controller: _locationController,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        hintText: '예: 서울 웨딩홀',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _fieldTitle('메모'),
                    TextFormField(
                      controller: _memoController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        hintText: '예: 축하 메시지 전달',
                      ),
                    ),
                    const SizedBox(height: 16),
                    _fieldTitle('전화번호'),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(hintText: '선택 입력'),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
                secondChild: const SizedBox.shrink(),
              ),
              const SizedBox(height: 12),
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
