// OCR-assisted import screen for photographed sign-in sheets and posters.
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

class _SignatureSheetScanPageState
    extends ConsumerState<SignatureSheetScanPage> {
  static const _relationshipOptions = <String>[
    '가족',
    '친척',
    '친구',
    '회사',
    '지인',
    '기타',
  ];

  List<PersonImportDraft> _candidates = const [];
  Set<int> _selectedIndexes = <int>{};
  bool _isScanning = false;
  bool _isSaving = false;
  String _relationship = '지인';
  String? _rawText;
  String? _infoMessage;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedIndexes.length;
    final totalCount = _candidates.length;
    final hasRawText = (_rawText ?? '').trim().isNotEmpty;
    final statusLabel = _isScanning
        ? '스캔 중'
        : hasRawText
        ? '완료'
        : '대기';

    return Scaffold(
      appBar: AppBar(title: const Text('명단 스캔')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
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
              value: statusLabel,
              icon: Icons.document_scanner_outlined,
              subtitle: _isScanning
                  ? '사진에서 글자를 읽는 중이에요.'
                  : hasRawText
                  ? '추출된 글자 $totalCount개, 선택됨 $selectedCount개'
                  : '아직 스캔된 명단이 없어요.',
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _relationship,
              decoration: const InputDecoration(labelText: '관계'),
              items: _relationshipOptions
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
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
              label: const Text('카메라로 촬영해서 글자 추출'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _isScanning ? null : _clearResults,
              icon: const Icon(Icons.refresh_outlined),
              label: const Text('초기화'),
            ),
            if (_infoMessage != null) ...[
              const SizedBox(height: 12),
              _MessageBox(
                message: _infoMessage!,
                color: Colors.blueGrey.shade700,
                backgroundColor: Colors.blueGrey.withValues(alpha: 0.08),
              ),
            ],
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              _MessageBox(
                message: _errorMessage!,
                color: Colors.red.shade700,
                backgroundColor: Colors.red.withValues(alpha: 0.08),
              ),
            ],
            if (_rawText != null) ...[
              const SizedBox(height: 20),
              const SectionHeader(title: '추출된 글자'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.black12),
                ),
                child: hasRawText
                    ? SelectableText(_rawText!)
                    : const Text('읽을 수 있는 글자가 충분하지 않았어요.'),
              ),
            ],
            if (_candidates.isNotEmpty) ...[
              const SizedBox(height: 20),
              const SectionHeader(title: '이름 후보'),
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
                      subtitle: Text(
                        [
                          if ((candidate.phoneNumber ?? '').isNotEmpty)
                            candidate.phoneNumber!,
                          candidate.sourceLine,
                        ].join(' · '),
                      ),
                      secondary: IconButton(
                        tooltip: '수정',
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => _editCandidate(index),
                      ),
                    ),
                  ),
                );
              }),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: (_isSaving || selectedCount == 0)
                    ? null
                    : _saveSelected,
                icon: _isSaving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text('선택한 인연 저장 ($selectedCount개)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _clearResults() {
    setState(() {
      _candidates = const [];
      _selectedIndexes = <int>{};
      _rawText = null;
      _infoMessage = null;
      _errorMessage = null;
    });
  }

  Future<void> _scanFromCamera() async {
    setState(() {
      _isScanning = true;
      _infoMessage = null;
      _errorMessage = null;
    });

    try {
      final service = ref.read(signatureSheetScanServiceProvider);
      final result = await service.scanFromCamera();
      if (!mounted) {
        return;
      }
      if (result == null) {
        setState(() => _isScanning = false);
        return;
      }

      setState(() {
        _rawText = result.rawText;
        _candidates = result.candidates;
        _selectedIndexes = Set<int>.from(
          List.generate(result.candidates.length, (index) => index),
        );
        _infoMessage = result.status == SignatureSheetScanStatus.noText
            ? result.message
            : result.candidates.isEmpty
            ? '글자는 읽었지만 이름 후보를 찾지 못했어요. 콜론이나 줄바꿈이 있는 명단 사진에서 더 잘 동작해요.'
            : '이름 후보 ${result.candidates.length}개를 찾았어요. 필요하면 수정하거나 선택을 해제할 수 있어요.';
        _errorMessage = null;
        _isScanning = false;
      });
    } on SignatureSheetScanException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = error.message;
        _isScanning = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '스캔 중 예기치 못한 문제가 발생했어요. 잠시 후 다시 시도해 주세요.';
        _isScanning = false;
      });
    }
  }

  Future<void> _editCandidate(int index) async {
    final candidate = _candidates[index];
    final nameController = TextEditingController(text: candidate.name);
    final phoneController = TextEditingController(
      text: candidate.phoneNumber ?? '',
    );

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
              decoration: const InputDecoration(labelText: '전화번호'),
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
      await controller.importPeople(drafts, relationship: _relationship);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorMessage = '저장에 실패했어요. $error';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({
    required this.message,
    required this.color,
    required this.backgroundColor,
  });

  final String message;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Text(message, style: TextStyle(color: color)),
    );
  }
}
