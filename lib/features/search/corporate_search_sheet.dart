import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/providers.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_motion.dart';
import '../../app/theme/app_spacing.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exception.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/json_utils.dart';
import '../../shared/animations/entrance.dart';
import '../../shared/widgets/app_feedback.dart';
import '../../shared/widgets/app_sheet.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/panel_parts.dart';

/// Abre el buscador corporativo (afiliados y empresas).
///
/// Solo llega aquí quien pasa `canUseCorporateSearchProvider`; el backend
/// además vuelve a validar el permiso en cada petición.
Future<void> showCorporateSearch(BuildContext context) {
  return showAppSheet(
    context,
    builder: (context) => const _SearchSheet(),
  );
}

class _SearchSheet extends ConsumerStatefulWidget {
  const _SearchSheet();

  @override
  ConsumerState<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends ConsumerState<_SearchSheet> {
  final _queryController = TextEditingController();

  bool _loading = false;
  Map<String, dynamic>? _familia;
  Map<String, dynamic>? _empresa;
  List<Map<String, dynamic>> _porNombre = const [];
  List<Map<String, dynamic>> _autocomplete = const [];
  String? _error;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _familia = null;
      _empresa = null;
      _porNombre = const [];
      _autocomplete = const [];
    });

    try {
      final api = ref.read(apiClientProvider);
      final result = await api.post(
        '/api/search',
        body: {'db_key': 'db_uno', 'query': query},
      );
      final map =
          result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{};

      if (map['success'] == true) {
        setState(() {
          if (map['data'] is Map) {
            _familia = Map<String, dynamic>.from(map['data'] as Map);
          } else if (map['empresa'] is Map) {
            _empresa = Map<String, dynamic>.from(map['empresa'] as Map);
          } else if (map['results_by_name'] is List) {
            _porNombre = asMapList(map['results_by_name']);
          } else {
            _error = 'No se encontraron resultados.';
          }
        });
      } else {
        setState(() =>
            _error = map['error']?.toString() ?? 'No se encontraron resultados.');
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _autocompleteCompanies(String query) async {
    if (query.trim().length < 2) {
      setState(() => _autocomplete = const []);
      return;
    }
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.get(
        '/api/empresas/search',
        query: {'q': query.trim()},
      );
      final map =
          result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{};
      if (mounted && map['success'] == true) {
        setState(() => _autocomplete = asMapList(map['empresas']));
      }
    } catch (_) {
      // El autocompletado es un extra; si falla, no molesta.
    }
  }

  Future<void> _exportExcel(String nit) async {
    AppFeedback.showInfo(context, 'Generando Excel…');
    try {
      final api = ref.read(apiClientProvider);
      final result = await api.post('/api/empresa/excel', body: {'nit': nit});
      final map =
          result is Map ? Map<String, dynamic>.from(result) : <String, dynamic>{};
      final url = map['url']?.toString();
      if (map['success'] == true && url != null) {
        final uri = Uri.parse('${ApiClient.defaultBaseUrl}$url');
        final ok =
            await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!ok && mounted) {
          AppFeedback.showError(context, 'No pudimos abrir la descarga.');
        }
      } else if (mounted) {
        AppFeedback.showError(
          context,
          map['error']?.toString() ?? 'No se pudo generar el Excel.',
        );
      }
    } on ApiException catch (e) {
      if (mounted) AppFeedback.showError(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return AppSheetScaffold(
      title: 'Búsqueda corporativa',
      subtitle: 'Afiliados por cédula o nombre · Empresas por NIT',
      icon: Icons.person_search_rounded,
      maxHeightFactor: 0.92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _queryController,
            autofocus: true,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            onChanged: _autocompleteCompanies,
            decoration: InputDecoration(
              hintText: 'Cédula, nombre o NIT…',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: IconButton(
                onPressed: _search,
                icon: Icon(Icons.arrow_forward_rounded,
                    color: colors.accent),
              ),
            ),
          ),

          // Autocompletado de empresas.
          AnimatedSize(
            duration: AppMotion.scale(context, AppMotion.standard),
            alignment: Alignment.topCenter,
            child: _autocomplete.isEmpty
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.sm),
                    child: Column(
                      children: [
                        for (final company in _autocomplete.take(5))
                          ListTile(
                            dense: true,
                            leading: const Icon(Icons.business_rounded,
                                size: 18),
                            title: Text(
                              asString(company['razsoc'],
                                  fallback: 'Sin nombre'),
                              style:
                                  const TextStyle(fontSize: 13),
                            ),
                            subtitle: Text(
                              'NIT: ${asString(company['nit'])}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onTap: () {
                              _queryController.text =
                                  asString(company['nit']);
                              setState(() => _autocomplete = const []);
                              _search();
                            },
                          ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: AppSpacing.lg),

          if (_loading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpacing.xxl),
                child: CircularProgressIndicator(),
              ),
            )
          else if (_error != null)
            EmptyState(
              icon: Icons.search_off_rounded,
              message: _error!,
              compact: true,
            )
          else if (_familia != null)
            _FamilyResult(data: _familia!, query: _queryController.text.trim())
          else if (_empresa != null)
            _CompanyResult(data: _empresa!, onExport: _exportExcel)
          else if (_porNombre.isNotEmpty)
            _NameResults(results: _porNombre),

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Resultado de núcleo familiar (afiliado + cónyuge + beneficiarios).
class _FamilyResult extends StatelessWidget {
  const _FamilyResult({required this.data, required this.query});

  final Map<String, dynamic> data;
  final String query;

  String _fullName(Map<String, dynamic> p) {
    final name = asString(p['nombre']);
    if (name.isNotEmpty) return name;
    return [p['prinom'], p['segnom'], p['priape'], p['segape']]
        .map(asString)
        .where((s) => s.isNotEmpty)
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final rol = asString(data['rol_buscado']);
    final principal = data['afiliado_principal'] is Map
        ? Map<String, dynamic>.from(data['afiliado_principal'] as Map)
        : null;
    final nucleo = data['nucleo_familiar'] is Map
        ? Map<String, dynamic>.from(data['nucleo_familiar'] as Map)
        : const <String, dynamic>{};
    final conyuges = asMapList(nucleo['conyuges']);
    final beneficiarios = asMapList(nucleo['otros_beneficiarios']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title: 'Núcleo familiar',
          icon: Icons.family_restroom_rounded,
          trailing:
              rol.isEmpty ? null : StatusPill(label: rol, color: AppColors.sky),
        ),

        if (principal != null)
          FadeSlideIn(
            child: _PersonCard(
              title: 'Afiliado principal',
              icon: Icons.verified_user_rounded,
              color: AppColors.income,
              name: _fullName(principal),
              fields: {
                'Cédula': asString(principal['cedtra'],
                    fallback: asString(data['cedula_afiliado_principal'])),
                'Estado': asString(principal['estado_desc'],
                    fallback: asString(principal['estado'])),
                'Nacimiento': asString(principal['fecnac']),
                'Teléfono': asString(principal['telefono']),
                'Email': asString(principal['email']),
                'Dirección': asString(principal['direccion']),
                'Salario': () {
                  final salary = asDoubleOrNull(principal['salario']);
                  return salary == null ? '' : AppCurrency.format(salary);
                }(),
              },
            ),
          ),

        for (var i = 0; i < conyuges.length; i++)
          FadeSlideIn(
            index: i + 1,
            child: _PersonCard(
              title: 'Cónyuge',
              icon: Icons.favorite_rounded,
              color: const Color(0xFFE91E63),
              name: _fullName(conyuges[i]),
              fields: {
                'Cédula': asString(conyuges[i]['cedcon']),
                'Nacimiento': asString(conyuges[i]['fecnac']),
              },
            ),
          ),

        for (var i = 0; i < beneficiarios.length; i++)
          FadeSlideIn(
            index: i + 1 + conyuges.length,
            child: _PersonCard(
              title: 'Beneficiario',
              icon: Icons.child_care_rounded,
              color: AppColors.sky,
              name: _fullName(beneficiarios[i]),
              fields: {
                'Documento': asString(beneficiarios[i]['documento'],
                    fallback: asString(beneficiarios[i]['codben'])),
                'Nacimiento': asString(beneficiarios[i]['fecnac']),
              },
            ),
          ),
      ],
    );
  }
}

class _PersonCard extends StatelessWidget {
  const _PersonCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.name,
    required this.fields,
  });

  final String title;
  final IconData icon;
  final Color color;
  final String name;
  final Map<String, String> fields;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final text = Theme.of(context).textTheme;
    final visible = fields.entries.where((e) => e.value.isNotEmpty).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: colors.bgTertiary,
        borderRadius: BorderRadius.circular(AppRadius.card),
        border: Border.all(color: colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: AppSpacing.sm),
              Text(title,
                  style: text.labelSmall?.copyWith(color: color)),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(name.isEmpty ? 'Sin nombre registrado' : name,
              style: text.titleSmall),
          const SizedBox(height: AppSpacing.sm),
          for (final entry in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(
                      entry.key,
                      style: text.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      entry.value,
                      style: text.bodySmall?.copyWith(
                        fontSize: 11.5,
                        color: colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Resultado de empresa, con exportación a Excel.
class _CompanyResult extends StatelessWidget {
  const _CompanyResult({required this.data, required this.onExport});

  final Map<String, dynamic> data;
  final ValueChanged<String> onExport;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final nit = asString(data['nit']);
    final trabajadores = asMapList(data['trabajadores']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PersonCard(
          title: 'Empresa',
          icon: Icons.business_rounded,
          color: AppColors.gold,
          name: asString(data['razsoc'], fallback: 'Sin razón social'),
          fields: {
            'NIT': nit,
            'Dirección': asString(data['direccion']),
            'Teléfono': asString(data['telefono']),
            'Trabajadores': trabajadores.isEmpty
                ? ''
                : '${trabajadores.length} activos',
          },
        ),
        if (nit.isNotEmpty)
          PanelActionButton(
            label: 'Exportar trabajadores a Excel',
            icon: Icons.table_view_rounded,
            color: AppColors.income,
            onPressed: () => onExport(nit),
          ),
        if (trabajadores.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.lg),
          SectionTitle(
            title: 'Trabajadores',
            icon: Icons.groups_rounded,
            trailing: Text('${trabajadores.length}',
                style: text.titleSmall),
          ),
          for (var i = 0; i < trabajadores.length && i < 30; i++)
            FadeSlideIn(
              index: i,
              child: _PersonCard(
                title: 'Trabajador',
                icon: Icons.person_rounded,
                color: AppColors.sky,
                name: [
                  trabajadores[i]['prinom'],
                  trabajadores[i]['segnom'],
                  trabajadores[i]['priape'],
                  trabajadores[i]['segape'],
                ]
                    .map(asString)
                    .where((s) => s.isNotEmpty)
                    .join(' '),
                fields: {
                  'Cédula': asString(trabajadores[i]['cedtra']),
                  'Cargo': asString(trabajadores[i]['cargo']),
                  'Teléfono': asString(trabajadores[i]['telefono']),
                  'Salario': () {
                    final salary =
                        asDoubleOrNull(trabajadores[i]['salario']);
                    return salary == null
                        ? ''
                        : AppCurrency.format(salary);
                  }(),
                },
              ),
            ),
        ],
      ],
    );
  }
}

/// Resultados de búsqueda por nombre.
class _NameResults extends StatelessWidget {
  const _NameResults({required this.results});

  final List<Map<String, dynamic>> results;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title: 'Coincidencias por nombre',
          icon: Icons.people_alt_rounded,
          trailing: Text('${results.length}', style: text.titleSmall),
        ),
        for (var i = 0; i < results.length && i < 30; i++)
          FadeSlideIn(
            index: i,
            child: _PersonCard(
              title: asString(results[i]['empresa'],
                  fallback: 'Afiliado'),
              icon: Icons.person_rounded,
              color: AppColors.sky,
              name: [
                results[i]['prinom'],
                results[i]['segnom'],
                results[i]['priape'],
                results[i]['segape'],
              ]
                  .map(asString)
                  .where((s) => s.isNotEmpty)
                  .join(' '),
              fields: {
                'Cédula': asString(results[i]['cedtra']),
                'Estado': asString(results[i]['estado_desc'],
                    fallback: asString(results[i]['estado'])),
                'Teléfono': asString(results[i]['telefono']),
              },
            ),
          ),
      ],
    );
  }
}
