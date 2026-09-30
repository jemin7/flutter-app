import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/exceptions.dart';
import '../../../core/widgets.dart';

/// Payload of GET /api/reports/summary.
class ReportsSummary {
  const ReportsSummary({
    required this.totalUsers,
    required this.byRole,
    required this.appUsersByCompany,
    required this.externalUsersByCompany,
  });

  final int totalUsers;
  final Map<String, int> byRole;
  final List<CompanyCount> appUsersByCompany;
  final List<CompanyCount> externalUsersByCompany;

  factory ReportsSummary.fromJson(Map<String, dynamic> json) => ReportsSummary(
        totalUsers: (json['totalUsers'] as num?)?.toInt() ?? 0,
        byRole: (json['byRole'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, (v as num).toInt())) ?? {},
        appUsersByCompany: (json['appUsersByCompany'] as List? ?? [])
            .map((e) => CompanyCount.fromJson(e as Map<String, dynamic>))
            .toList(),
        externalUsersByCompany: (json['externalUsersByCompany'] as List? ?? [])
            .map((e) => CompanyCount.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class CompanyCount {
  const CompanyCount({required this.company, required this.count});

  final String company;
  final int count;

  factory CompanyCount.fromJson(Map<String, dynamic> json) => CompanyCount(
        company: json['company'] as String? ?? '',
        count: (json['count'] as num?)?.toInt() ?? 0,
      );
}

final reportsSummaryProvider = FutureProvider.autoDispose<ReportsSummary>((ref) async {
  try {
    final res = await ref.watch(dioProvider).get('/api/reports/summary');
    return ReportsSummary.fromJson(res.data['data'] as Map<String, dynamic>);
  } on DioException catch (e) {
    throw toApiException(e);
  }
});

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(reportsSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: summary.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e is ApiException ? e.message : 'Failed to load reports',
          onRetry: () => ref.invalidate(reportsSummaryProvider),
        ),
        data: (s) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(reportsSummaryProvider),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Overview', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _SummaryTile(label: 'Total users', value: '${s.totalUsers}', icon: Icons.people)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _SummaryTile(
                          label: 'Super admins',
                          value: '${s.byRole['SUPER_ADMIN'] ?? 0}',
                          icon: Icons.admin_panel_settings,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _ChartCard(
                    title: 'App users by company',
                    subtitle: 'Tap a bar to see the exact count',
                    data: s.appUsersByCompany,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  _ChartCard(
                    title: 'External users by company',
                    subtitle: 'Directory entries per company',
                    data: s.externalUsersByCompany,
                    color: Theme.of(context).colorScheme.tertiary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact stat tile: icon + value + label stacked, never overflows.
class _SummaryTile extends StatelessWidget {
  const _SummaryTile({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 22, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(value, style: Theme.of(context).textTheme.headlineSmall),
                  Text(label, style: Theme.of(context).textTheme.bodySmall, overflow: TextOverflow.ellipsis, maxLines: 1),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.subtitle, required this.data, required this.color});

  final String title;
  final String subtitle;
  final List<CompanyCount> data;
  final Color color;

  String _short(String name, {int max = 8}) {
    final words = name.trim().split(RegExp(r'\s+'));
    if (name.length <= max || words.isEmpty) return name;
    // "Romaguera-Crona" -> "Romaguera…" style shortening on word boundaries first.
    if (words.first.length >= 3) return '${words.first.substring(0, words.first.length.clamp(0, max))}…';
    return '${name.substring(0, max - 1)}…';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bodySmall = Theme.of(context).textTheme.bodySmall;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(subtitle, style: bodySmall),
            const SizedBox(height: 16),
            if (data.isEmpty)
              const EmptyView(message: 'No data yet')
            else ...[
              SizedBox(
                height: 200,
                child: BarChart(
                  BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: data.map((d) => d.count).reduce((a, b) => a > b ? a : b) + 1,
                    barGroups: [
                      for (final (i, d) in data.indexed)
                        BarChartGroupData(x: i, barRods: [
                          BarChartRodData(
                            toY: d.count.toDouble(),
                            color: color,
                            width: 20,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ]),
                    ],
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) => scheme.inverseSurface,
                        getTooltipItem: (group, _, rod, __) => BarTooltipItem(
                          '${data[group.x].company}\n',
                          bodySmall?.copyWith(color: scheme.onInverseSurface, fontWeight: FontWeight.w600) ??
                              const TextStyle(),
                          children: [
                            TextSpan(
                              text: '${rod.toY.toInt()} ${rod.toY.toInt() == 1 ? 'user' : 'users'}',
                              style: bodySmall?.copyWith(color: scheme.onInverseSurface),
                            ),
                          ],
                        ),
                      ),
                    ),
                    titlesData: FlTitlesData(
                      leftTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      topTitles: const AxisTitles(),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          // Vertical labels: company names never overlap, even with 10+ companies.
                          reservedSize: 60,
                          getTitlesWidget: (v, _) => Padding(
                            padding: const EdgeInsets.only(right: 2),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: RotatedBox(
                                quarterTurns: 3, // 90° — reads bottom-to-top
                                child: Text(
                                  _short(data[v.toInt()].company, max: 10),
                                  style: bodySmall?.copyWith(fontSize: 10),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Full company names with counts — the chart abbreviates, this doesn't.
              for (final d in data)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(child: Text(d.company, style: Theme.of(context).textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Text('${d.count}', style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
