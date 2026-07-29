import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_module.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/note.dart';
import '../../shared/animations/entrance.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/panel_parts.dart';
import '../../shared/widgets/skeleton.dart';
import '../calendar/day_detail_header.dart';
import '../shell/dashboard_controller.dart';
import 'note_sheet.dart';

/// Panel del módulo Notas.
class NotesPanel extends ConsumerWidget {
  const NotesPanel({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dashboardControllerProvider);
    final controller = ref.read(dashboardControllerProvider.notifier);
    final selected = state.selectedDay;

    final notes = selected == null
        ? state.monthData.notes
        : state.monthData.notes.where((n) => n.fecha == selected).toList();

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xxxl,
      ),
      children: [
        HintBar(text: AppModule.notes.hint, icon: Icons.edit_note_rounded),
        const SizedBox(height: AppSpacing.lg),

        if (selected != null) ...[
          DayDetailHeader(
            dateStr: selected,
            onClear: controller.clearSelection,
            emptyLabel: 'Sin notas en este día.',
            chips: [
              if (notes.isNotEmpty)
                DaySummaryChip(
                  label: notes.length == 1
                      ? '1 nota'
                      : '${notes.length} notas',
                  color: context.colors.accent,
                  icon: Icons.edit_note_rounded,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
        ] else
          SectionTitle(
            title: 'Notas de ${state.monthLabel.toLowerCase()}',
            icon: Icons.sticky_note_2_rounded,
            trailing: Text(
              '${notes.length}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),

        if (state.loading)
          const ListSkeleton(count: 3)
        else if (notes.isEmpty)
          EmptyState(
            icon: Icons.edit_note_rounded,
            title: 'Sin notas todavía',
            message: selected == null
                ? 'Mantén pulsado un día del calendario para escribir una nota.'
                : 'No hay notas en este día.',
            actionLabel: selected == null ? null : 'Escribir nota',
            onAction: selected == null
                ? null
                : () => showNoteSheet(context, dateStr: selected),
            compact: true,
          )
        else
          // Rejilla de dos columnas con alturas desiguales: se reparten las
          // notas alternando columna, que da el efecto de tablón sin traer una
          // dependencia de masonry.
          _NotesMasonry(notes: notes),

        const SizedBox(height: AppSpacing.lg),
        if (selected != null)
          PanelActionButton(
            label: 'Nueva nota',
            icon: Icons.add_rounded,
            onPressed: () => showNoteSheet(context, dateStr: selected),
          ),
      ],
    );
  }
}

class _NotesMasonry extends StatelessWidget {
  const _NotesMasonry({required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    final left = <Note>[];
    final right = <Note>[];
    for (var i = 0; i < notes.length; i++) {
      (i.isEven ? left : right).add(notes[i]);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _column(left, 0)),
        const SizedBox(width: AppSpacing.md),
        Expanded(child: _column(right, 1)),
      ],
    );
  }

  Widget _column(List<Note> items, int seed) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: FadeSlideIn(
              index: i * 2 + seed,
              child: _StickyNote(note: items[i], seed: i * 2 + seed),
            ),
          ),
      ],
    );
  }
}

/// Nota con aspecto de papel adhesivo, ligeramente girada.
class _StickyNote extends ConsumerWidget {
  const _StickyNote({required this.note, required this.seed});

  final Note note;
  final int seed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final color = note.accentColor;

    // Giro determinista a partir del id: la misma nota siempre se ve igual,
    // pero el conjunto no parece una tabla.
    final angle = ((note.id % 5) - 2) * 0.006;

    return Transform.rotate(
      angle: angle,
      child: Material(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.card),
        child: InkWell(
          onTap: () => showNoteSheet(context, dateStr: note.fecha, note: note),
          onLongPress: () => _delete(context, ref),
          borderRadius: BorderRadius.circular(AppRadius.card),
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        note.etiqueta,
                        style: text.labelSmall?.copyWith(
                          color: color,
                          fontSize: 9.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  note.contenido,
                  style: text.bodyMedium?.copyWith(
                    color: context.colors.textPrimary,
                    fontSize: 13,
                  ),
                  maxLines: 8,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppDate.medium(note.fecha),
                  style: text.labelSmall?.copyWith(fontSize: 9.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await AppFeedback.confirm(
      context,
      title: 'Eliminar nota',
      message: '¿Eliminar esta nota? No se puede deshacer.',
    );
    if (!ok) return;

    try {
      await ref.read(wellnessRepositoryProvider).deleteNote(note.id);
      await ref.read(dashboardControllerProvider.notifier).refreshMonth();
      if (context.mounted) AppFeedback.showSuccess(context, 'Nota eliminada');
    } on ApiException catch (e) {
      if (context.mounted) AppFeedback.showError(context, e.message);
    }
  }
}

/// Ángulo máximo de giro de las notas.
const double kStickyMaxAngle = math.pi / 180 * 1.5;
