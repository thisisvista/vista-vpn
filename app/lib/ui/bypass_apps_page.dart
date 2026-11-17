import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/android_core.dart';
import '../l10n/app_localizations.dart';
import 'widgets.dart';

/// Android per-app routing: only the apps explicitly selected by the
/// user are bypassed or routed through the VPN. System apps can be shown
/// on request. Changes apply immediately.
class BypassAppsPage extends StatefulWidget {
  const BypassAppsPage({super.key});

  @override
  State<BypassAppsPage> createState() => _BypassAppsPageState();
}

class _BypassAppsPageState extends State<BypassAppsPage> {
  /// The system's apps are listed too; kept while the app runs.
  static bool _showSystem = false;

  List<InstalledApp>? _apps;
  AppRouting? _routing;

  String _query = '';
  final Map<String, Future<Uint8List?>> _icons = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final apps = await AndroidCore.installedApps();
    final routing = await AndroidCore.appRouting();
    if (!mounted) return;
    setState(() {
      _routing = routing;
      _apps = apps;
      _sort();
    });
  }

  /// The checked apps first, then by name.
  void _sort() {
    final r = _routing!;
    _apps!.sort((a, b) {
      final ca = r.checked(a.package), cb = r.checked(b.package);
      if (ca != cb) return ca ? -1 : 1;
      return a.label.toLowerCase().compareTo(b.label.toLowerCase());
    });
  }

  /// Apply every app-list change immediately to the active VPN interface.
  void _save() => AndroidCore.setAppRouting(_routing!, apply: true);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final routing = _routing;
    final q = _query.trim().toLowerCase();
    final apps = [
      for (final a in _apps ?? const <InstalledApp>[])
        if (!routing!.allApps &&
            (a.launcher || _showSystem || routing.checked(a.package)) &&
            (q.isEmpty ||
                a.label.toLowerCase().contains(q) ||
                a.package.toLowerCase().contains(q)))
          a,
    ];
    return Scaffold(
        appBar: AppBar(
          title: Text(l.bypassApps),
          actions: [
            PopupMenuButton<void>(
              itemBuilder: (context) => [
                checkMenuItem(
                  label: l.showSystemApps,
                  checked: _showSystem,
                  onTap: () => setState(() => _showSystem = !_showSystem),
                ),
              ],
            ),
          ],
        ),
        body: routing == null || _apps == null
            ? const Center(child: CircularProgressIndicator())
            : ListView.builder(
                itemCount: apps.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: routing.allApps ? 'all' : 'exclude',
                            isExpanded: true,
                            decoration: const InputDecoration(
                              isDense: true,
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'all',
                                child: Text(
                                  l.localeName.startsWith('fa')
                                      ? 'همه برنامه‌ها'
                                      : 'All apps',
                                ),
                              ),
                              DropdownMenuItem(
                                value: 'exclude',
                                child: Text(l.appModeExclude),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() {
                                routing.allApps = value == 'all';
                                _sort();
                              });
                              _save();
                            },
                          ),
                          const SizedBox(height: 10),
                          Text(
                            routing.allApps
                                ? (l.localeName.startsWith('fa')
                                    ? 'تمام برنامه‌ها از VPN عبور می‌کنند و فهرست انتخاب‌ها حفظ می‌شود.'
                                    : 'All apps use the VPN. Your saved app selections are preserved.')
                                : l.appModeExcludeHint,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (!routing.allApps)
                            TextField(
                              decoration: InputDecoration(
                                isDense: true,
                                prefixIcon: const Icon(Icons.search_rounded),
                                hintText: l.search,
                                border: const OutlineInputBorder(),
                              ),
                              onChanged: (v) => setState(() => _query = v),
                            ),
                        ],
                      ),
                    );
                  }
                  final app = apps[i - 1];
                  final icon = _icons.putIfAbsent(
                    app.package,
                    () => AndroidCore.appIcon(app.package),
                  );
                  return CheckboxListTile(
                    value: routing.checked(app.package),
                    onChanged: (v) {
                      setState(() => routing.toggle(app.package, v ?? false));
                      _save();
                    },
                    secondary: SizedBox.square(
                      dimension: 40,
                      child: FutureBuilder<Uint8List?>(
                        future: icon,
                        builder: (context, snap) => snap.data == null
                            ? const Icon(Icons.android_rounded)
                            : Image.memory(snap.data!, gaplessPlayback: true),
                      ),
                    ),
                    title: Text(app.label),
                    subtitle: Text(
                      app.package,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                },
              ),
    );
  }
}
