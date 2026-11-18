import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app_settings.dart';
import '../core/android_core.dart';
import '../core/core_controller.dart';
import '../core/models.dart';
import '../core/ports.dart';
import '../core/updates.dart';
import '../l10n/app_localizations.dart';
import 'bypass_apps_page.dart';
import 'format.dart';
import 'port_dialog.dart';
import 'widgets.dart';

/// Experimental phone home based on the Vista dark V-emblem mockup.
/// Connection state, delay, and session start are always read from the core.
class ExperimentalVistaHome extends StatefulWidget {
  const ExperimentalVistaHome({
    super.key,
    required this.core,
    required this.settings,
    required this.onOpenServers,
    required this.onOpenAccounts,
    required this.onOpenSettings,
  });

  final CoreController core;
  final AppSettings settings;
  final VoidCallback onOpenServers;
  final VoidCallback onOpenAccounts;
  final VoidCallback onOpenSettings;

  @override
  State<ExperimentalVistaHome> createState() => _ExperimentalVistaHomeState();
}

class _ExperimentalVistaHomeState extends State<ExperimentalVistaHome>
    with SingleTickerProviderStateMixin {
  Timer? _clock;
  String _appRoutingMode = 'exclude';
  String _connectionMode = 'vpn';
  int _selectedAppCount = 0;
  int _proxyPort = 1080;
  late final AnimationController _floatController;

  @override
  void initState() {
    super.initState();
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
    if (Platform.isAndroid) {
      AndroidCore.appRoutingMode.addListener(_syncAppRoutingMode);
      AndroidCore.mode.addListener(_syncConnectionMode);
      _loadAppRoutingMode();
      _loadProxyPort();
    }
  }

  void _syncAppRoutingMode() {
    final mode = AndroidCore.appRoutingMode.value;
    if (mounted && mode != _appRoutingMode) {
      setState(() => _appRoutingMode = mode);
    }
  }

  void _syncConnectionMode() {
    final mode = AndroidCore.mode.value;
    if (mounted && mode != _connectionMode) {
      setState(() => _connectionMode = mode);
    }
  }

  @override
  void dispose() {
    if (Platform.isAndroid) {
      AndroidCore.appRoutingMode.removeListener(_syncAppRoutingMode);
      AndroidCore.mode.removeListener(_syncConnectionMode);
    }
    _clock?.cancel();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _toggle(CoreStatus status, bool on) async {
    if (status.totalAccounts == 0) {
      widget.onOpenAccounts();
      return;
    }
    final switchSystemProxy = status.systemProxySupported &&
        !status.connectPending &&
        status.connectFailure.isEmpty;
    await runShowingErrors(context, () async {
      if (switchSystemProxy) {
        await widget.core.setSystemProxy(on ? 'clear' : 'set');
      } else {
        await widget.core.setOn(!on);
      }
      if (!on) {
        final next = widget.core.status;
        if (next != null && next.proxyOn && !next.connectPending) {
          unawaited(widget.core.runTest().catchError((_) {}));
        }
      }
    });
  }

  Future<void> _loadAppRoutingMode() async {
    try {
      final routing = await AndroidCore.appRouting();
      if (!mounted) return;
      setState(() {
        _appRoutingMode = routing.allApps ? 'all' : 'exclude';
        _selectedAppCount = routing.bypass.length;
      });
    } catch (_) {
      // The settings page remains available if the native bridge is not ready.
    }
  }

  Future<void> _loadProxyPort() async {
    try {
      final config = await widget.core.settings();
      final proxy = config['proxy'];
      final listen = proxy is Map<String, Object?> ? proxy['listen'] as String? ?? '' : '';
      final port = portOf(listen) ?? 10810;
      if (mounted) setState(() => _proxyPort = port);
    } catch (_) {
      // The core settings page remains available if the API is not ready.
    }
  }

  Future<void> _selectHomeMode(String choice) async {
    await runShowingErrors(context, () async {
      if (choice == 'proxy') {
        await AndroidCore.setMode('proxy');
        if (mounted) setState(() => _connectionMode = 'proxy');
        return;
      }
      if (AndroidCore.mode.value != 'vpn') {
        await AndroidCore.setMode('vpn');
      }
      await AndroidCore.setAppRoutingMode(choice);
      final routing = await AndroidCore.appRouting();
      if (mounted) {
        setState(() {
          _connectionMode = 'vpn';
          _appRoutingMode = choice;
          _selectedAppCount = routing.bypass.length;
        });
      }
    });
  }

  Future<void> _openBypassApps() async {
    await _selectHomeMode('exclude');
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BypassAppsPage()),
    );
    await _loadAppRoutingMode();
  }

  Future<void> _changeHomeProxyPort() async {
    final port = await showPortDialog(context, current: '$_proxyPort');
    if (port == null || !mounted) return;
    final ok = await runShowingErrors(
      context,
      () => widget.core.setProxyPort(port),
    );
    if (ok && mounted) {
      setState(() => _proxyPort = port);
    }
  }

  String _sessionTime(DateTime? startedAt) {
    if (startedAt == null) return '';
    final elapsed = DateTime.now().difference(startedAt);
    return formatDuration(
      AppLocalizations.of(context),
      elapsed.isNegative ? Duration.zero : elapsed,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = widget.core.status;
    final theme = Theme.of(context);
    final baseText = theme.textTheme;
    final isDark = theme.brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0A1024) : const Color(0xFFF4F6FB);
    final topBackground = isDark ? const Color(0xFF123348) : const Color(0xFFE8F1F7);
    final card = isDark ? const Color(0xFF1A1B32) : Colors.white;
    final border = isDark ? const Color(0x16FFFFFF) : const Color(0x180A1024);
    final foreground = isDark ? Colors.white : const Color(0xFF172033);
    final secondary = isDark ? const Color(0xFFB7C0D0) : const Color(0xFF536174);
    final muted = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF667085);

    if (status == null) {
      return ColoredBox(
        color: background,
        child: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
      );
    }

    final running = status.state.phase == Phase.running;
    final canSwitchSystem = status.systemProxySupported;
    final on = canSwitchSystem &&
            !status.connectPending &&
            status.connectFailure.isEmpty
        ? status.systemProxySet || status.tunMode
        : status.proxyOn;
    final confirming = status.connectPending ||
        (on &&
            running &&
            !canSwitchSystem &&
            !status.confirmedBy(widget.core.lastTest));
    final connected = on &&
        running &&
        (status.computerUsesVpn || !canSwitchSystem) &&
        !confirming;
    final look = PhaseLook.of(l, status);
    final accent = !on
        ? (isDark ? const Color(0xFF8D7AB8) : const Color(0xFFB8A2F5))
        : confirming
            ? const Color(0xFFFFB52E)
            : status.state.phase == Phase.error
                ? const Color(0xFFEF6475)
                : connected
                    ? (isDark ? const Color(0xFF00FFC8) : const Color(0xFF20B879))
                    : const Color(0xFFF59E0B);
    // The emblem surface follows the selected theme only. Connection state
    // changes the V traces, never the circular surface beneath them.
    final powerFill = isDark ? const Color(0xFF171C2B) : Colors.white;
    final emblemGlow = isDark
        ? const Color(0xFF8D7AB8)
        : const Color(0xFFB8A2F5);
    final powerMark = connected
        ? (isDark ? const Color(0xFF00FFC8) : const Color(0xFF20B879))
        : confirming
            ? const Color(0xFFFFB52E)
            : !on
                ? (isDark
                    ? const Color(0xFF8D7AB8)
                    : const Color(0xFF8D7AB8))
                : accent;
    final test = status.isCurrentTest(widget.core.lastTest)
        ? widget.core.lastTest
        : null;
    final failure = failureText(l, status.proxy, test);
    final failureMessage = status.connectPending
        ? ''
        : status.connectFailure.isNotEmpty
            ? failureCodeText(l, status.connectFailure)
            : failure.code.isNotEmpty || (test != null && !test.ok)
                ? failure.text
                : status.noNetwork && on
                    ? l.noNetwork
                    : '';
    final pingText = widget.core.testing
        ? l.testingDelay
        : test == null
            ? l.testConnection
            : !test.ok
                ? l.testFailed
                : l.milliseconds(test.responseMs);
    final pingColor = test == null
        ? muted
        : !test.ok
            ? const Color(0xFFEF6475)
            : delayColor(test.responseMs);
    final selection = status.selection.trim();
    final selectionLower = selection.toLowerCase();
    final automaticSelection = selection.isEmpty || selectionLower == 'fastest';
    final recommendedSelection = selection.isEmpty;
    final actualExit = connected ? status.exit : null;
    final hasActualExit = actualExit?.countryName.isNotEmpty == true;
    final serverName = automaticSelection && hasActualExit
        ? actualExit!.countryName
        : selectionLower == 'fastest'
            ? l.modeFastest
            : selection.isEmpty
                ? (status.selectionName.isNotEmpty
                    ? status.selectionName
                    : l.recommendedLocation)
                : status.selectionName.isNotEmpty
                    ? status.selectionName
                    : locationName(l, selection, selection);
    final flagCode = automaticSelection
        ? (hasActualExit ? actualExit!.countryCode.toUpperCase() : 'REC')
        : selection.toUpperCase();
    final account = status.activeAccount;
    final usage = account?.usage;
    final quotaProgress = usage == null || usage.unlimited || usage.limitBytes <= 0
        ? 0.0
        : (usage.usedBytes / usage.limitBytes).clamp(0.0, 1.0).toDouble();
    final stateLabel = confirming
        ? l.stateConnecting
        : connected
            ? l.stateConnected
            : look.label;
    // Respect the OS reduced-motion setting. Apart from accessibility,
    // this keeps widget tests and devices with animations disabled settled.
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (confirming && !reduceMotion && !_floatController.isAnimating) {
      _floatController.repeat();
    } else if ((!confirming || reduceMotion) &&
        _floatController.isAnimating) {
      _floatController.stop();
      _floatController.value = 0.5;
    }
    final stateHint = !on
        ? l.tapToConnectPhone
        : look.hint.isNotEmpty
            ? look.hint
            : l.tapToDisconnectPhone;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: (isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.42),
            radius: 1.08,
            colors: [topBackground, background],
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: ConstrainedBox(
                // Fill the viewport when content fits; scroll naturally when it doesn't.
                constraints: BoxConstraints(
                  minHeight: math.max(0.0, constraints.maxHeight - 32),
                ),
                child: IntrinsicHeight(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: border),
                      ),
                      child: const Center(
                        child: VistaCircuitMark(
                          size: 26,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Text(
                      'Vista ',
                      style: baseText.titleLarge?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      'VPN',
                      style: baseText.titleLarge?.copyWith(
                        color: secondary,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const Spacer(),
                    _HeaderButton(
                      icon: Icons.settings_rounded,
                      onTap: widget.onOpenSettings,
                    ),
                  ],
                ),
                const Spacer(),
                const SizedBox(height: 16),
                SizedBox(
                        width: 300,
                        height: 260,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: connected ? 296 : 254,
                              height: connected ? 296 : 254,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    emblemGlow.withValues(alpha: 0.055),
                                    emblemGlow.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                            for (final ring in connected
                                ? [
                                    (size: 190.0, alpha: isDark ? 0.17 : 0.29),
                                    (size: 224.0, alpha: isDark ? 0.13 : 0.23),
                                    (size: 258.0, alpha: isDark ? 0.09 : 0.17),
                                    (size: 292.0, alpha: isDark ? 0.055 : 0.12),
                                  ]
                                : [
                                    (size: 166.0, alpha: isDark ? 0.15 : 0.27),
                                    (size: 190.0, alpha: isDark ? 0.10 : 0.19),
                                    (size: 214.0, alpha: isDark ? 0.065 : 0.12),
                                  ])
                              Container(
                                width: ring.size,
                                height: ring.size,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white.withValues(
                                      alpha: ring.alpha,
                                    ),
                                    width: 1,
                                  ),
                                ),
                              ),
                            AnimatedBuilder(
                              animation: _floatController,
                              builder: (context, child) {
                                final phase = _floatController.value * math.pi * 2;
                                final bob = confirming ? math.sin(phase) * 5.0 : 0.0;
                                final tilt = confirming ? math.sin(phase) * 0.012 : 0.0;
                                return Transform.translate(
                                  offset: Offset(0, bob),
                                  child: Transform.rotate(
                                    angle: tilt,
                                    child: child,
                                  ),
                                );
                              },
                              child: AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              width: 154,
                              height: 154,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                // A solid theme surface prevents status colors
                                // from tinting the circle behind the V traces.
                                color: powerFill,
                                border: Border.all(
                                  color: (isDark ? Colors.white : emblemGlow).withValues(
                                  alpha: isDark ? 0.10 : 0.22,
                                ),
                                width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: emblemGlow.withValues(
                                      alpha: isDark ? 0.07 : 0.15,
                                    ),
                                    blurRadius: 38,
                                    spreadRadius: 1,
                                  ),
                                  const BoxShadow(
                                    color: Colors.black54,
                                    blurRadius: 22,
                                    offset: Offset(0, 12),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                shape: const CircleBorder(),
                                clipBehavior: Clip.antiAlias,
                                child: Tooltip(
                                  message: on
                                      ? l.tapToDisconnectPhone
                                      : l.tapToConnectPhone,
                                  child: InkWell(
                                    onTap: widget.core.switchingProxy
                                        ? null
                                        : () => _toggle(status, on),
                                    child: Center(
                                      child: Transform.translate(
                                        // The circuit artwork is optically a little
                                        // lower than its canvas center.
                                        offset: const Offset(0, -7),
                                        child: VistaCircuitMark(
                                          size: 128,
                                          color: powerMark,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              ),
                            ),
                            if (widget.core.switchingProxy)
                              const SizedBox(
                                width: 174,
                                height: 174,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFF59E0B),
                                ),
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 14),
                Text(
                  stateLabel,
                        textAlign: TextAlign.center,
                        style: baseText.headlineSmall?.copyWith(
                          color: on ? accent : foreground,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      SizedBox(
                        // Keep the content below the connection status at a
                        // fixed vertical position before and after connecting.
                        height: 60,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (connected)
                              Material(
                                color: card,
                                shape: StadiumBorder(
                                  side: BorderSide(color: border),
                                ),
                                clipBehavior: Clip.antiAlias,
                                child: InkWell(
                                  onTap: widget.core.testing
                                      ? null
                                      : () => runShowingErrors(
                                            context,
                                            widget.core.runTest,
                                          ),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (widget.core.testing)
                                          const SizedBox(
                                            width: 13,
                                            height: 13,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 1.7,
                                            ),
                                          )
                                        else
                                          Icon(
                                            Icons.bolt_rounded,
                                            size: 16,
                                            color: pingColor,
                                          ),
                                        const SizedBox(width: 6),
                                        Text(
                                          pingText,
                                          style: baseText.labelLarge?.copyWith(
                                            color: pingColor,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              )
                            else
                              Text(
                                stateHint,
                                textAlign: TextAlign.center,
                                style: baseText.bodySmall?.copyWith(color: muted),
                              ),
                            if (connected && status.proxy?.startedAt != null) ...[
                              const SizedBox(height: 5),
                              Text(
                                _sessionTime(status.proxy!.startedAt),
                                style: baseText.labelSmall?.copyWith(
                                  color: muted,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                const Spacer(),
                ValueListenableBuilder(
                  valueListenable: Updates.available,
                  builder: (context, release, _) {
                    if (release == null ||
                        (!release.mandatory &&
                            release.version == widget.settings.dismissedUpdate)) {
                      return const SizedBox(height: 16);
                    }
                    return Padding(
                      padding: const EdgeInsets.only(top: 16, bottom: 16),
                      child: _HomeUpdateBanner(
                        core: widget.core,
                        settings: widget.settings,
                        release: release,
                      ),
                    );
                  },
                ),
                if (Platform.isAndroid && widget.settings.showAppRouting) ...[
                  Center(
                    child: FractionallySizedBox(
                      widthFactor: 0.86,
                      child: Material(
                        color: card,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                          side: BorderSide(color: border),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  _HomeModeChip(
                                    title: 'All Apps',
                                    selected: _connectionMode == 'vpn' && _appRoutingMode == 'all',
                                    onTap: () => _selectHomeMode('all'),
                                    foreground: foreground,
                                    muted: muted,
                                  ),
                                  _HomeModeChip(
                                    title: 'Selected Apps',
                                    selected: _connectionMode == 'vpn' && _appRoutingMode == 'exclude',
                                    onTap: () => _selectHomeMode('exclude'),
                                    foreground: foreground,
                                    muted: muted,
                                  ),
                                  _HomeModeChip(
                                    title: 'Proxy',
                                    selected: _connectionMode == 'proxy',
                                    onTap: () => _selectHomeMode('proxy'),
                                    foreground: foreground,
                                    muted: muted,
                                  ),
                                ],
                              ),
                              if (_connectionMode == 'vpn' && _appRoutingMode == 'exclude')
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Material(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.045)
                                        : const Color(0xFFF1F4F8),
                                    borderRadius: BorderRadius.circular(9),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(9),
                                      onTap: _openBypassApps,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        child: Row(
                                          children: [
                                            Icon(Icons.apps_rounded, size: 15, color: muted),
                                            const SizedBox(width: 7),
                                            Expanded(
                                              child: Text(
                                                'Bypass Apps',
                                                style: baseText.labelMedium?.copyWith(
                                                  color: foreground,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '$_selectedAppCount bypassed',
                                              style: baseText.labelSmall?.copyWith(color: muted),
                                            ),
                                            const SizedBox(width: 3),
                                            Icon(Icons.chevron_right_rounded, size: 17, color: muted),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              if (_connectionMode == 'proxy')
                                Padding(
                                  padding: const EdgeInsets.only(top: 5),
                                  child: Material(
                                    color: isDark
                                        ? Colors.white.withValues(alpha: 0.045)
                                        : const Color(0xFFF1F4F8),
                                    borderRadius: BorderRadius.circular(9),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(9),
                                      onTap: _changeHomeProxyPort,
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                                        child: Row(
                                          children: [
                                            Icon(Icons.settings_ethernet_rounded, size: 15, color: muted),
                                            const SizedBox(width: 7),
                                            Expanded(
                                              child: Text(
                                                'Proxy port',
                                                style: baseText.labelMedium?.copyWith(
                                                  color: foreground,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              '$_proxyPort',
                                              style: baseText.labelMedium?.copyWith(
                                                color: foreground,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                            const SizedBox(width: 5),
                                            Icon(Icons.edit_rounded, size: 14, color: muted),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 9),
                ],
                _ActionCard(
                  onTap: widget.onOpenServers,
                  child: Row(
                    children: [
                      CountryFlag(code: flagCode, width: 38),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (recommendedSelection || selectionLower == 'fastest') ...[
                                  const Icon(
                                    Icons.star_rounded,
                                    size: 12,
                                    color: Color(0xFF20B879),
                                  ),
                                  const SizedBox(width: 3),
                                ],
                                Text(
                                  recommendedSelection
                                      ? l.recommendedLocation
                                      : selectionLower == 'fastest'
                                          ? 'Fastest'
                                          : l.navServers,
                                  style: baseText.labelSmall?.copyWith(
                                    color: recommendedSelection || selectionLower == 'fastest'
                                        ? const Color(0xFF20B879)
                                        : muted,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              serverName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: baseText.titleMedium?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: muted,
                        size: 24,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 11),
                _ActionCard(
                  onTap: widget.onOpenAccounts,
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0xFF36DDB3).withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.data_usage_rounded,
                          color: Color(0xFF58DDB8),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l.dataUsedTitle,
                              style: baseText.titleSmall?.copyWith(
                                color: foreground,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 5),
                            if (usage == null)
                              Text(
                                l.quotaNotRead,
                                style: baseText.bodySmall?.copyWith(color: muted),
                              )
                            else if (usage.unlimited)
                              Text(
                                l.unlimited,
                                style: baseText.bodySmall?.copyWith(color: muted),
                              )
                            else if (usage.limitBytes > 0) ...[
                              Text(
                                l.usedOf(
                                  formatBytes(usage.usedBytes.clamp(0, usage.limitBytes).toInt()),
                                  formatBytes(usage.limitBytes),
                                ),
                                style: baseText.bodySmall?.copyWith(color: muted),
                              ),
                              const SizedBox(height: 8),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: LinearProgressIndicator(
                                  value: quotaProgress,
                                  minHeight: 5,
                                  backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.07),
                                  valueColor: const AlwaysStoppedAnimation(
                                    Color(0xFF58DDB8),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${formatBytes(usage.remainingBytes.clamp(0, usage.limitBytes).toInt())} ${l.dataLeftOf(formatBytes(usage.limitBytes))}'
                                '${usage.resetAt == null ? '' : ' · ${l.resets(formatDate(l, usage.resetAt!))}'}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: baseText.bodySmall?.copyWith(color: muted),
                              ),
                            ] else
                              Text(
                                l.quotaNotRead,
                                style: baseText.bodySmall?.copyWith(color: muted),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: muted,
                        size: 24,
                      ),
                    ],
                  ),
                ),
                if (failureMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    failureMessage,
                    textAlign: TextAlign.center,
                    style: baseText.bodySmall?.copyWith(
                      color: const Color(0xFFEF6475),
                    ),
                  ),
                ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}


class _HomeModeChip extends StatelessWidget {
  const _HomeModeChip({
    required this.title,
    required this.selected,
    required this.onTap,
    required this.foreground,
    required this.muted,
  });

  final String title;
  final bool selected;
  final VoidCallback onTap;
  final Color foreground;
  final Color muted;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: selected
              ? const Color(0xFF28BA89).withValues(alpha: dark ? 0.19 : 0.13)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: SizedBox(
              height: 32,
              child: Center(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? const Color(0xFF28BA89) : muted,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Retained as a small reusable home-routing row for the next UI iteration.
// ignore: unused_element
class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.onTap, required this.child});

  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1B32)
            : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0x16FFFFFF)
                : const Color(0x180A1024),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: child,
          ),
        ),
      );
}

class _HeaderButton extends StatelessWidget {
  const _HeaderButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.055)
            : const Color(0xFFE8EDF5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0x16FFFFFF)
                : const Color(0x180A1024),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFD1D5DB)
                  : const Color(0xFF536174),
              size: 21,
            ),
          ),
        ),
      );
}

/// The three circuit traces that form Vista's V. This mark can also be
/// exported to the launcher icon artwork in a later, separate step.
class VistaCircuitMark extends StatelessWidget {
  const VistaCircuitMark({
    super.key,
    this.size = 120,
    this.color = const Color(0xFFE5E7EB),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _VistaCircuitPainter(color),
      );
}

class _VistaCircuitPainter extends CustomPainter {
  const _VistaCircuitPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 180, size.height / 180);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [color, color, color.withValues(alpha: 0.72)],
      ).createShader(const Rect.fromLTWH(0, 0, 180, 180));

    void trace(List<Offset> points, List<Offset> nodes) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, paint);
      final nodePaint = Paint()..color = color;
      for (final node in nodes) {
        canvas.drawCircle(node, 6.5, nodePaint);
      }
    }

    trace(
      const [
        Offset(56, 58),
        Offset(74, 58),
        Offset(90, 77),
        Offset(106, 58),
        Offset(124, 58),
      ],
      const [Offset(52, 58), Offset(128, 58)],
    );
    trace(
      const [
        Offset(30, 77),
        Offset(64, 77),
        Offset(90, 107),
        Offset(116, 77),
        Offset(150, 77),
      ],
      const [Offset(26, 77), Offset(154, 77)],
    );
    trace(
      const [
        Offset(42, 96),
        Offset(56, 96),
        Offset(90, 136),
        Offset(124, 96),
        Offset(138, 96),
      ],
      const [Offset(38, 96), Offset(142, 96)],
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VistaCircuitPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _HomeUpdateBanner extends StatelessWidget {
  const _HomeUpdateBanner({
    required this.core,
    required this.settings,
    required this.release,
  });

  final CoreController core;
  final AppSettings settings;
  final Release release;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      core,
      Updates.failure,
      Updates.installingApk,
    ]),
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final theme = Theme.of(context);
      const accent = Color(0xFF00DDB5);
      final update = core.status?.update;
      final mine = update?.version == release.version;
      final dismiss = release.mandatory
          ? null
          : () => settings.update(dismissedUpdate: release.version);

      String message;
      String actionLabel;
      IconData actionIcon;
      VoidCallback? action;
      bool busy = false;
      double? progress;

      // Match Arman's two paths: without a core update state, open the
      // release page; with one, use the in-app updater.
      if (Updates.installingApk.value) {
        busy = true;
        message = l.updateInstalling(release.version);
        actionLabel = message;
        actionIcon = Icons.downloading_rounded;
        action = null;
      } else if (update == null) {
        message = release.mandatory
            ? l.updateRequired(release.version)
            : l.updateAvailable(release.version);
        actionLabel = l.download;
        actionIcon = Icons.download_rounded;
        action = release.url.isEmpty
            ? null
            : () => unawaited(openDownload(context, release));
      } else if (mine && (update.downloading || update.installing)) {
        busy = true;
        progress = update.downloading ? update.progress : null;
        message = update.downloading
            ? l.updateDownloading(release.version)
            : l.updateInstalling(release.version);
        actionLabel = update.downloading
            ? l.updateDownloading(release.version)
            : l.updateInstalling(release.version);
        actionIcon = Icons.downloading_rounded;
        action = null;
      } else {
        final failure = Updates.failure.value ??
            (mine && update.failed ? update.error : null);
        if (failure != null) {
          message = l.updateFailed(release.version);
          actionLabel = l.tryAgain;
          actionIcon = Icons.refresh_rounded;
          action = () => Updates.update(release);
        } else {
          message = release.mandatory
              ? l.updateRequired(release.version)
              : mine && update.ready
                  ? l.updateReady(release.version)
                  : l.updateAvailable(release.version);
          actionLabel = l.updateNow;
          actionIcon = Icons.system_update_alt_rounded;
          action = () => Updates.update(release);
        }
      }

      return Material(
        color: theme.colorScheme.surface.withValues(alpha: 0.96),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accent.withValues(alpha: 0.65)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              Icon(
                busy
                    ? Icons.downloading_rounded
                    : Icons.system_update_alt_rounded,
                color: accent,
                size: 25,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                    ),
                    if (busy) ...[
                      const SizedBox(height: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          color: accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (!busy)
                FilledButton.icon(
                  onPressed: action,
                  style: FilledButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: const Color(0xFF06231F),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: Icon(actionIcon, size: 17),
                  label: Text(actionLabel, maxLines: 1),
                ),
              if (busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: 4),
              if (!busy && dismiss != null)
                IconButton(
                  tooltip: l.dismiss,
                  onPressed: dismiss,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 19),
                ),
            ],
          ),
        ),
      );
    },
  );
}

