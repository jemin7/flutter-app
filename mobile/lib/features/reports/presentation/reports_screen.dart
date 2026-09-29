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
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  Expanded(child: _SummaryCard(label: 'Total users', value: '${s.totalUsers}', icon: Icons.people)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'Super admins',
                      value: '${s.byRole['SUPER_ADMIN'] ?? 0}',
                      icon: Icons.admin_panel_settings,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _ChartCard(
                title: 'App users by company',
                data: s.appUsersByCompany,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              _ChartCard(
                title: 'External users by company',
                data: s.externalUsersByCompany,
                color: Theme.of(context).colorScheme.tertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.icon});

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.headlineMedium),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.data, required this.color});

  final String title;
  final List<CompanyCount> data;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: data.isEmpty
                  ? const EmptyView(message: 'No data')
                  : BarChart(
                      BarChartData(
                        barGroups: [
                          for (final (i, d) in data.indexed)
                            BarChartGroupData(x: i, barRods: [
                              BarChartRodData(
                                toY: d.count.toDouble(),
                                color: color,
                                width: 18,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ]),
                        ],
                        titlesData: FlTitlesData(
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (v, _) => Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  data[v.toInt()].company,
                                  style: const TextStyle(fontSize: 9),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ),
                          topTitles: const AxisTitles(),
                          rightTitles: const AxisTitles(),
                        ),
                        gridData: const FlGridData(show: true),
                        borderData: FlBorderData(show: false),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
