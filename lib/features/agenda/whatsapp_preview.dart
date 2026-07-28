import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/event.dart';
import '../../shared/widgets/app_feedback.dart';

/// Recordatorio de WhatsApp para un evento.
///
/// En la web era un `<textarea>` de solo lectura; aquí se muestra como la
/// burbuja de chat que el destinatario va a recibir, para que se vea de verdad
/// lo que se está por enviar.
class WhatsAppPreview extends StatelessWidget {
  const WhatsAppPreview({super.key, required this.event});

  final CalendarEvent event;

  /// Mismo texto que genera `getWhatsAppMessage` en la versión web.
  String buildMessage() {
    final buffer = StringBuffer('Hola! Te recuerdo tu compromiso:\n');
    buffer.write('📌 *${event.titulo}*\n');
    buffer.write('📅 Fecha: ${event.fecha}');

    final time = event.shortTime;
    if (time != null) buffer.write(' a las $time');

    if (event.isFinancial && event.costo > 0) {
      buffer.write('\n💰 Valor: ${AppCurrency.format(event.costo)}');
    }

    final uuid = event.uuidConfirmacion;
    if (uuid != null && uuid.isNotEmpty) {
      buffer.write(
        '\n🔗 Confirma aquí: ${ApiClient.defaultBaseUrl}/confirmar/$uuid',
      );
    }

    return buffer.toString();
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: buildMessage()));
    if (context.mounted) {
      AppFeedback.showSuccess(context, 'Mensaje copiado al portapapeles');
    }
  }

  Future<void> _send(BuildContext context) async {
    final uri = Uri.parse(
      'https://wa.me/?text=${Uri.encodeComponent(buildMessage())}',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      AppFeedback.showError(context, 'No pudimos abrir WhatsApp');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final message = buildMessage();
    final now = TimeOfDay.now();

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: colors.bgPrimary.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppRadius.input),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.chat_rounded, size: 13, color: colors.textTertiary),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'RECORDATORIO DE WHATSAPP',
                style: text.labelSmall?.copyWith(
                  color: colors.textTertiary,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Burbuja de mensaje saliente, con la cola y el doble check.
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              decoration: const BoxDecoration(
                color: Color(0xFF005C4B),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(AppRadius.chip),
                  topRight: Radius.circular(AppRadius.chip),
                  bottomLeft: Radius.circular(AppRadius.chip),
                  bottomRight: Radius.circular(3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: Color(0xFFE9EDEF),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        now.format(context),
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: Color(0xFF8FA9A2),
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.done_all_rounded,
                        size: 13,
                        color: Color(0xFF53BDEB),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _copy(context),
                  icon: const Icon(Icons.copy_rounded, size: 15),
                  label: const Text('Copiar'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    foregroundColor: colors.textSecondary,
                    side: BorderSide(color: colors.border),
                    textStyle: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _send(context),
                  icon: const Icon(Icons.send_rounded, size: 15),
                  label: const Text('Enviar'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 38),
                    backgroundColor: const Color(0xFF25D366),
                    foregroundColor: const Color(0xFF0B141A),
                    textStyle: const TextStyle(fontSize: 12.5),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
