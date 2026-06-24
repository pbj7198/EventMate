// OCR-assisted import screen for photographed sign-in sheets.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/person_import_draft.dart';
import '../services/signature_sheet_scan_service.dart';
import '../state/inyeon_controller.dart';
import 'common_widgets.dart';

class SignatureSheetScanPage extends ConsumerStatefulWidget {
  const SignatureSheetScanPage({super.key});

  @override
  ConsumerState<SignatureSheetScanPage> createState() =>
      _SignatureSheetScanPageState();
}

class _SignatureSheetScanPageState extends ConsumerState<SignatureSheetScanPage> {
  final _relationshipOptions = const [
    '지인',
    '친구',
    '친척',
    '회사',
    '가족',
    '기타',
  ];

  List<PersonImportDraft> _candidates = const [];
  Set<int> _selectedIndexes = <int>{};
  bool _isScanning = false;
  bool _isSaving = false;
  String _relationship = '지인';
  String? _rawText;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedIndexes.length;
    final totalCount = _candidates.length;

    return Scaffold(
      appBar: AppBar(title: const Text('명단 스캔')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            '축의금 명단이나 서명표를 촬영하면 이름 후보를 자동으로 뽑아드려요.',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '사진 품질, 기울기, 손글씨 상태에 따라 결과가 달라질 수 있어요. 마지막 확인은 꼭 사람이 해주세요.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          SummaryCard(
            title: '현재 상태',
            value: _isScanning ? '인식 중' : '대기',
            icon: Icons.document_scanner_outlined,
            subtitle: totalCount == 0
                ? '아직 스캔된 명단이 없어요'
                : '후보 $totalCount명 · 선택 $selectedCount명',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _relationship,
            decoration: const InputDecoration(labelText: '관계'),
            items: _relationshipOptions
                .map(
                  (value) => DropdownMenuItem(
                    value: value,
                    child: Text(value),
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
          FilledButton.icon(
            onPressed: _isScanning ? null : _scanFromCamera,
            icon: _isScanning
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.camera_alt_outlined),
            label: const Text('카메라로 촬영해서 스캔'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _isScanning ? null : _clearResults,
            icon: const Icon(Icons.refresh_outlined),
            label: const Text('초기화'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ],
          if (_candidates.isNotEmpty) ...[
            const SizedBox(height: 20),
            const SectionHeader(title: '인식된 후보'),
            ...List.generate(_candidates.length, (index) {
              final candidate = _candidates[index];
              final selected = _selectedIndexes.contains(index);
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Card(
                  child: CheckboxListTile(
                    value: selected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          _selectedIndexes.add(index);
                        } else {
                          _selectedIndexes.remove(index);
                        }
                      });
                    },
                    title: Text(candidate.name),
                    subtitle: Text([
                      if ((candidate.phoneNumber ?? '').isNotEmpty)
                        candidate.phoneNumber!,
                      candidate.sourceLine,
                    ].join(' · ')),
                    secondary: IconButton(
                      tooltip: '수정',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: () => _editCandidate(index),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('원본 OCR 텍스트 보기'),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SelectableText(_rawText ?? ''),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed:
                  (_isSaving || selectedCount == 0) ? null : _saveSelected,
              icon: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text('선택한 인연 저장 ($selectedCount명)'),
            ),
          ],
        ],
      ),
    );
  }

  void _clearResults() {
    setState(() {
      _candidates = const [];
      _selectedIndexes = <int>{};
      _rawText = null;
      _errorMessage = null;
    });
  }

  Future<void> _scanFromCamera() async {
    setState(() {
      _isScanning = true;
      _errorMessage = null;
    });

    try {
      final service = ref.read(signatureSheetScanServiceProvider);
      final result = await service.scanFromCamera();
      if (!mounted) {
        return;
      }
      if (result == null) {
        setState(() {
          _isScanning = false;
        });
        return;
      }

      setState(() {
        _candidates = result.candidates;
        _selectedIndexes = Set<int>.from(
          List.generate(result.candidates.length, (index) => index),
        );
        _rawText = result.rawText;
        _isScanning = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '스캔에 실패했어요: $error';
        _isScanning = false;
      });
    }
  }

  Future<void> _editCandidate(int index) async {
    final candidate = _candidates[index];
    final nameController = TextEditingController(text: candidate.name);
    final phoneController =
        TextEditingController(text: candidate.phoneNumber ?? '');

    final updated = await showDialog<PersonImportDraft>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('후보 수정'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: '이름'),
            ),
            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: '휴대폰 번호'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(
                context,
                PersonImportDraft(
                  name: nameController.text.trim(),
                  phoneNumber: phoneController.text.trim().isEmpty
                      ? null
                      : phoneController.text.trim(),
                  sourceLine: candidate.sourceLine,
                ),
              );
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );

    nameController.dispose();
    phoneController.dispose();

    if (updated == null) {
      return;
    }

    setState(() {
      _candidates[index] = updated;
      _selectedIndexes.add(index);
    });
  }

  Future<void> _saveSelected() async {
    setState(() => _isSaving = true);
    try {
      final controller = ref.read(inyeonControllerProvider.notifier);
      final drafts = _selectedIndexes
          .map((index) => _candidates[index])
          .where((draft) => draft.name.trim().isNotEmpty)
          .toList();
      await controller.importPeople(
        drafts,
        relationship: _relationship,
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '저장에 실패했어요: $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}
