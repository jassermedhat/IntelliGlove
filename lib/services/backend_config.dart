import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Singleton that holds the resolved backend base URL and performs
/// zero-configuration LAN discovery via the backend's /__config endpoint.
///
/// Call [discover] once in main() before any [BackendApiClient] is created.
class BackendConfig {
  BackendConfig._();
  static final instance = BackendConfig._();

  /// Compile-time configured API base (set via --dart-define=API_BASE_URL=...).
  static const _compiledApiBase = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api/v1',
  );

  String _apiBase = _compiledApiBase;

  /// Current API base URL (includes the /api/v1 prefix).
  String get apiBase => _apiBase;

  /// Strips the /api/v1 path to get the bare server root.
  static String _serverRoot(String apiBase) {
    final uri = Uri.parse(apiBase);
    return '${uri.scheme}://${uri.host}:${uri.port}';
  }

  // ── Stage 1: well-known addresses ─────────────────────────────────────────

  static List<String> _knownCandidates() {
    final seen = <String>{};
    return [
      _serverRoot(_compiledApiBase), // honour any explicit --dart-define first
      'http://10.0.2.2:8000',       // Android emulator → host machine
      'http://localhost:8000',        // desktop / iOS simulator
      'http://192.168.137.1:8000',   // Windows mobile hotspot host
      'http://192.168.43.1:8000',    // Android hotspot host
    ].where(seen.add).toList();
  }

  // ── Stage 2: subnet scan (same WiFi / router) ─────────────────────────────

  /// Builds the list of /24 subnet candidates to probe.
  ///
  /// Primary: derives subnets from the device's own network interfaces,
  /// skipping loopback (127.x.x.x) and link-local (169.254.x.x) addresses.
  ///
  /// Fallback: always appends 192.168.0.x and 192.168.1.x — the two most
  /// common home/office WiFi subnets — in case NetworkInterface.list()
  /// returns nothing useful (can happen on some Android versions).
  static Future<List<String>> _subnetCandidates() async {
    if (kIsWeb) return [];

    final seen = <String>{};
    final candidates = <String>[];

    void addSubnet(String prefix) {
      for (var i = 1; i <= 254; i++) {
        final root = 'http://$prefix.$i:8000';
        if (seen.add(root)) candidates.add(root);
      }
    }

    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4,
        includeLinkLocal: false,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          if (addr.isLoopback) continue;
          final parts = addr.address.split('.');
          if (parts.length != 4) continue;
          addSubnet('${parts[0]}.${parts[1]}.${parts[2]}');
        }
      }
    } catch (_) {}

    // Always include the two most common home/office router subnets as a
    // safety net for when NetworkInterface.list() is unhelpful.
    addSubnet('192.168.0');
    addSubnet('192.168.1');

    return candidates;
  }

  // ── Discovery ─────────────────────────────────────────────────────────────

  /// Two-stage discovery:
  ///   1. Race the known static candidates (emulator, hotspot, compile-time URL).
  ///      Resolves in milliseconds when any of those match.
  ///   2. If stage 1 misses, scan every host on the device's own WiFi subnet
  ///      in parallel. Covers same-WiFi router scenarios with dynamic DHCP IPs.
  ///
  /// Falls back to [_compiledApiBase] silently if both stages fail.
  Future<void> discover() async {
    // Stage 1 — fast, well-known addresses (~2 s budget).
    var found = await _race(_knownCandidates(), const Duration(seconds: 2));

    if (found == null) {
      // Stage 2 — full /24 subnet scan (~3 s budget).
      debugPrint('[BackendConfig] Stage 1 failed; scanning LAN subnet…');
      found = await _race(await _subnetCandidates(), const Duration(seconds: 3));
    }

    if (found != null) {
      _apiBase = '$found/api/v1';
      debugPrint('[BackendConfig] Backend discovered: $_apiBase');
    } else {
      debugPrint('[BackendConfig] Discovery failed — using default: $_apiBase');
    }
  }

  /// Fires all [candidates] in parallel and returns the base_url from the
  /// first successful /__config response, or null if none reply within [timeout].
  Future<String?> _race(List<String> candidates, Duration timeout) async {
    if (candidates.isEmpty) return null;

    final completer = Completer<String?>();
    var remaining = candidates.length;

    for (final root in candidates) {
      _probe(root).then((url) {
        if (completer.isCompleted) return;
        if (url != null) {
          completer.complete(url);
        } else if (--remaining == 0) {
          completer.complete(null);
        }
      });
    }

    try {
      return await completer.future.timeout(timeout);
    } on TimeoutException {
      return null;
    }
  }

  Future<String?> _probe(String root) async {
    try {
      final response = await http
          .get(Uri.parse('$root/__config'))
          .timeout(const Duration(milliseconds: 1500));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['base_url'] as String?;
      }
    } catch (_) {
      // Unreachable — try next candidate.
    }
    return null;
  }
}
