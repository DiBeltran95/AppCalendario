import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/finance.dart' show toHexColor, parseHexColor;
import '../../data/models/note.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/app_sheet.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/option_picker.dart';
import '../shell/dashboard_controller.dart';

/// Formulario de nota rápida.
Future<void> showNoteSheet(
  BuildContext context, {
  required String dateStr,
  Note? note,
}) {
  return showAppSheet(
    context,
    builder: (context) => _NoteSheet(dateStr: dateStr, note: note),
  );
}

class _NoteSheet extends ConsumerStatefulWidget {
  const _NoteSheet({required this.dateStr, this.note});

  final String dateStr;
  final Note? note;

  @override
  ConsumerState<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends ConsumerState<_NoteSheet> {
  final _formKey = GlobalKey<FormState>();
  final _contentController = TextEditingController();

  String _tag = 'personal';
  Color _color = Note.palette.first;
  bool _saving = false;

  bool get _isEdit => widget.note != null;

  @override
  void initState() {
    super.initState();
    final note = widget.note;
    if (note != null) {
      _contentController.text = note.contenido;
      _tag = note.etiqueta;
      _color = parseHexColor(note.color, fallback: Note.palette.first);
    } else {
      // Al crear, el color por defecto es el de la etiqueta elegida.
      _color = Note.tags.first.color;
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _saving = true);
    final repo = ref.read(wellnessRepositoryProvider);

    try {
      if (_isEdit) {
        await repo.updateNote(
          id: widget.note!.id,
          contenido: _contentController.text.trim(),
          etiqueta: _tag,
          color: toHexColor(_color),
        );
      } else {
        await repo.createNote(
          fecha: widget.dateStr,
          contenido: _contentController.text.trim(),
          etiqueta: _tag,
          color: toHexColor(_color),
        );
      }

      await ref.read(dashboardControllerProvider.notifier).refreshMonth();
      if (!mounted) return;
      Navigator.of(context).pop();
      AppFeedback.showSuccess(
        context,
        _isEdit ? 'Nota actualizada' : 'Nota creada',
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppFeedback.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppSheetScaffold(
      title: _isEdit ? 'Editar nota' : 'Nueva nota',
      subtitle: AppDate.weekdayLong(widget.dateStr),
      icon: Icons.edit_note_rounded,
      accent: _color,
      actions: SheetActions(
        onConfirm: _save,
        loading: _saving,
        accent: _color,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              label: 'Contenido',
              controller: _contentController,
              hint: '¿Qué quieres recordar de este día?',
              maxLines: 5,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) =>
                  (v?.trim().isEmpty ?? true) ? 'Escribe algo' : null,
            ),
            const SizedBox(height: AppSpacing.lg),
            PickerField<String>(
              label: 'Etiqueta',
              value: _tag,
              accent: _color,
              options: [
                for (final tag in Note.tags)
                  PickerOption(
                    value: tag.value,
                    label: tag.label,
                    icon: Icons.label_rounded,
                    color: tag.color,
                  ),
              ],
              onChanged: (v) => setState(() {
                _tag = v;
                // Al cambiar de etiqueta se sugiere su color, salvo que el
                // usuario ya hubiera elegido uno distinto a mano.
                final tag = Note.tags.firstWhere((t) => t.value == v);
                _color = tag.color;
              }),
            ),
            const SizedBox(height: AppSpacing.lg),
            ColorPickerRow(
              colors: Note.palette,
              selected: _color,
              onChanged: (c) => setState(() => _color = c),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
