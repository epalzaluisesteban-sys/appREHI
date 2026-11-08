import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'export.dart';
import 'store.dart';
import 'theme.dart';
import 'widgets/common.dart';

enum ExportFormat {
  excel('Excel', 'xlsx', 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      Icons.table_chart_outlined),
  pdf('PDF', 'pdf', 'application/pdf', Icons.picture_as_pdf_outlined);

  const ExportFormat(this.label, this.extension, this.mimeType, this.icon);

  final String label;
  final String extension;
  final String mimeType;
  final IconData icon;
}

void _snack(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

/// Guarda el archivo donde elija el usuario o lo abre en el menú de compartir.
/// Devuelve `true` si se guardó o compartió.
Future<bool> _deliver(
  BuildContext context, {
  required Uint8List bytes,
  required String fileName,
  required String mimeType,
  required bool share,
}) async {
  try {
    if (share) {
      final r = await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: mimeType, name: fileName)],
        fileNameOverrides: [fileName],
        subject: fileName,
      ));
      return r.status != ShareResultStatus.dismissed;
    }
    final uri = await FilePicker.saveFile(fileName: fileName, bytes: bytes, mimeType: mimeType);
    if (uri != null && context.mounted) _snack(context, 'Guardado: $fileName');
    return uri != null;
  } catch (e) {
    debugPrint('No se pudo entregar el archivo: $e');
    if (context.mounted) _snack(context, 'No se pudo ${share ? 'compartir' : 'guardar'} el archivo.');
    return false;
  }
}

/// Hoja inferior para elegir periodo y si se guarda o se comparte.
Future<void> exportRecords(BuildContext context, ExportFormat format) async {
  final store = context.read<AppStore>();
  if (store.sessions.isEmpty) {
    _snack(context, 'Aún no hay entrenamientos registrados para exportar.');
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _ExportSheet(format: format, store: store, parent: context),
  );
}

class _ExportSheet extends StatefulWidget {
  const _ExportSheet({required this.format, required this.store, required this.parent});

  final ExportFormat format;
  final AppStore store;
  final BuildContext parent;

  @override
  State<_ExportSheet> createState() => _ExportSheetState();
}

class _ExportSheetState extends State<_ExportSheet> {
  ExportPeriod period = ExportPeriod.all;
  bool busy = false;

  Future<void> _go({required bool share}) async {
    setState(() => busy = true);
    final f = widget.format;
    final bytes = f == ExportFormat.excel
        ? buildExcel(widget.store, period)
        : await buildPdf(widget.store, period);
    if (!mounted) return;
    Navigator.pop(context);
    final parent = widget.parent;
    if (!parent.mounted) return;
    await _deliver(
      parent,
      bytes: bytes,
      fileName: exportFileName('registros', f.extension),
      mimeType: f.mimeType,
      share: share,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = sessionsInPeriod(widget.store, period).length;
    final f = widget.format;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Exportar a ${f.label}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(
              f == ExportFormat.excel
                  ? 'Hojas: Series, Sesiones y Ejercicios (resumen).'
                  : 'Resumen, tabla por ejercicio y detalle de cada sesión.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            const Text('Periodo', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in ExportPeriod.values)
                  ChoiceChip(
                    label: Text(p.label),
                    selected: p == period,
                    onSelected: busy ? null : (_) => setState(() => period = p),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              count == 0
                  ? 'No hay entrenamientos en este periodo.'
                  : '$count entrenamiento${count == 1 ? '' : 's'} · pesos en ${widget.store.unit.label}',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy || count == 0 ? null : () => _go(share: true),
                    icon: const Icon(Icons.share_outlined),
                    label: const Text('Compartir'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy || count == 0 ? null : () => _go(share: false),
                    icon: busy
                        ? const SizedBox.square(
                            dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.download_outlined),
                    label: const Text('Guardar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Copia de seguridad
// ---------------------------------------------------------------------------

/// Pregunta si guardar o compartir la copia y la genera.
Future<void> saveBackup(BuildContext context) async {
  final store = context.read<AppStore>();
  final share = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (c) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 8),
            child: Text(
              'Guárdala fuera de la app (Google Drive, Descargas o envíatela) '
              'para poder recuperarla si desinstalas REHI o cambias de celular.',
              style: TextStyle(color: AppColors.muted),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Guardar archivo'),
            subtitle: const Text('Elige la carpeta, por ejemplo Drive o Descargas'),
            onTap: () => Navigator.pop(c, false),
          ),
          ListTile(
            leading: const Icon(Icons.share_outlined),
            title: const Text('Compartir'),
            subtitle: const Text('Envíala por correo, WhatsApp, Drive…'),
            onTap: () => Navigator.pop(c, true),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (share == null || !context.mounted) return;

  final previous = store.lastBackupAt;
  final raw = store.exportBackup();
  final ok = await _deliver(
    context,
    bytes: Uint8List.fromList(utf8.encode(raw)),
    fileName: exportFileName('copia', 'json'),
    mimeType: 'application/json',
    share: share,
  );
  if (!ok) {
    // No se guardó: no contar como copia hecha.
    store.lastBackupAt = previous;
    store.changed();
  }
}

/// Elige un archivo de copia, muestra qué contiene y lo restaura.
Future<void> restoreBackup(BuildContext context) async {
  final store = context.read<AppStore>();
  final String raw;
  try {
    final file = await FilePicker.pickFile(dialogTitle: 'Elige la copia de seguridad de REHI');
    if (file == null) return;
    raw = utf8.decode(await file.readAsBytes());
  } catch (e) {
    debugPrint('No se pudo abrir el archivo: $e');
    if (context.mounted) _snack(context, 'No se pudo abrir el archivo.');
    return;
  }
  if (!context.mounted) return;

  final BackupInfo backup;
  try {
    backup = AppStore.readBackup(raw);
  } on FormatException catch (e) {
    _snack(context, e.message);
    return;
  }

  final when = backup.exportedAt == null
      ? ''
      : ' del ${DateFormat("d 'de' MMMM yyyy, HH:mm", 'es').format(backup.exportedAt!)}';
  final hasData = store.routines.isNotEmpty || store.sessions.isNotEmpty;
  final ok = await confirm(
    context,
    title: 'Restaurar copia',
    message: 'Copia$when: ${backup.routineCount} rutina${backup.routineCount == 1 ? '' : 's'} '
        'y ${backup.sessionCount} entrenamiento${backup.sessionCount == 1 ? '' : 's'}.'
        '${hasData ? '\n\nSe reemplazarán los datos que tienes ahora en la app.' : ''}',
    ok: 'Restaurar',
    destructive: hasData,
  );
  if (!ok || !context.mounted) return;

  try {
    store.restoreBackup(backup);
    _snack(context, 'Datos restaurados.');
  } on FormatException catch (e) {
    _snack(context, e.message);
  }
}
