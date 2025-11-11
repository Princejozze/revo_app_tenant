import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:myapp/src/services/house_service.dart';
import 'package:myapp/src/models/tenant.dart';
import 'package:myapp/src/widgets/simple_chart.dart';
import 'package:myapp/src/widgets/grouped_bar_chart.dart';
import 'package:myapp/src/widgets/pie_chart.dart';
import 'package:myapp/src/widgets/bar_chart.dart';
import 'package:myapp/src/services/expense_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  bool _yearly = false; // false = monthly, true = yearly

  @override
  Widget build(BuildContext context) {
    return Consumer<HouseService>(
      builder: (context, houseService, _) {
        final houses = houseService.houses;
        final expenseService = context.watch<ExpenseService>();
        final monthlyNet = _computeMonthlyNetProfit(houses, expenseService, months: 12);
        final yearlyNet = _computeYearlyNetProfit(houses, expenseService, years: 3);
        final currency = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);

        // Expense Category Breakdown (last 12 months)
        final now = DateTime.now();
        final start = DateTime(now.year, now.month - 11, 1);
        final categorySums = expenseService.sumByCategory(start: start, end: now);

        final totalIncomeLast12 = _sum(monthlyNet.map((e) => e.income).toList());
        final totalExpensesLast12 = _sum(monthlyNet.map((e) => e.expenses).toList());
        final totalNetLast12 = totalIncomeLast12 - totalExpensesLast12;

        final chartData = _yearly
            ? yearlyNet.map((e) => e.net.toDouble()).toList()
            : monthlyNet.map((e) => e.net.toDouble()).toList();

        // Average monthly rent calculations
        final avgOverall = _computeAverageRentOverall(houses);
        final avgByProperty = _computeAverageRentByProperty(houses);

        final chartTitle = _yearly
            ? 'Net Profit (Last ${yearlyNet.length} Years)'
            : 'Net Profit (Last 12 Months)';

        return Scaffold(
          appBar: AppBar(
            title: const Text('Analytics'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Toggle
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Monthly'),
                      selected: !_yearly,
                      onSelected: (_) => setState(() => _yearly = false),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Yearly'),
                      selected: _yearly,
                      onSelected: (_) => setState(() => _yearly = true),
                    ),
                    const Spacer(),
                    const Tooltip(
                      message: 'Expenses tracking not configured yet. Net Profit = Income for now.',
                      child: Icon(Icons.info_outline),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // High-level KPIs
                _kpiRow(context, houses),
                const SizedBox(height: 12),
                _turnoverKpi(context, houses),
                const SizedBox(height: 16),

                // Rent Averages (overall & per property)
                _rentAverages(context, avgOverall, avgByProperty),
                const SizedBox(height: 16),

                // Summary cards
                Row(
                  children: [
                    Expanded(child: _metricCard(context, 'Total Income (12m)', currency.format(totalIncomeLast12), Icons.trending_up, Colors.green)),
                    const SizedBox(width: 12),
                    Expanded(child: _metricCard(context, 'Total Expenses (12m)', currency.format(totalExpensesLast12), Icons.trending_down, Colors.red)),
                    const SizedBox(width: 12),
                    Expanded(child: _metricCard(context, 'Net Profit (12m)', currency.format(totalNetLast12), Icons.show_chart, Colors.blue)),
                  ],
                ),
                const SizedBox(height: 16),

                // Net Profit chart
                SimpleChart(
                  title: chartTitle,
                  data: chartData,
                  color: Theme.of(context).colorScheme.primary,
                ),

                const SizedBox(height: 24),

                // Income vs Expenses by Property
                _incomeVsExpensesByProperty(context, houses),
                const SizedBox(height: 24),

                // Expense Category Breakdown (Pie)
                PieChartWidget(
                  title: 'Expense Category Breakdown (Last 12 Months)',
                  data: categorySums,
                ),

                const SizedBox(height: 24),

                // Utilization charts
                _occupancyByProperty(context, houses),
                const SizedBox(height: 24),
                _onTimeVsOverdueChart(context, houses),

                const SizedBox(height: 24),

                // Tabular breakdown
                if (!_yearly) _monthlyTable(context, monthlyNet),
                if (_yearly) _yearlyTable(context, yearlyNet),

                const SizedBox(height: 24),
                _overdueRanking(context, houses),
                const SizedBox(height: 24),
                _overduePropertiesRanking(context, houses),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _metricCard(BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(title, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }

  // Compute monthly net profit for last [months] months
  List<_MonthlyNet> _computeMonthlyNetProfit(List houses, ExpenseService expenseService, {int months = 12}) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - (months - 1), 1);
    final Map<String, _MonthlyNet> map = {};
    final monthFmt = DateFormat('MMM yy');

    // initialize months
    for (int i = 0; i < months; i++) {
      final dt = DateTime(start.year, start.month + i, 1);
      final key = monthFmt.format(dt);
      map[key] = _MonthlyNet(label: key, income: 0, expenses: 0);
    }

    // income from tenant payments
    for (final house in houses) {
      for (final room in house.rooms) {
        final Tenant? t = room.tenant;
        if (t == null) continue;
        for (final Payment p in t.payments) {
          if (p.date.isBefore(start) || p.date.isAfter(now)) continue;
          final key = monthFmt.format(DateTime(p.date.year, p.date.month, 1));
          map[key] = map[key]!.copyWith(income: map[key]!.income + p.amount);
        }
      }
    }

    // expenses from ExpenseService by month
    final expensesByMonth = expenseService.sumByMonth(start: start, end: now);
    for (final entry in map.entries) {
      final label = entry.key;
      final current = entry.value;
      final exp = expensesByMonth[label] ?? 0;
      map[label] = current.copyWith(expenses: current.expenses + exp);
    }

    return map.values.map((e) => e.withNet()).toList();
  }

  List<_YearlyNet> _computeYearlyNetProfit(List houses, ExpenseService expenseService, {int years = 3}) {
    final now = DateTime.now();
    final startYear = now.year - (years - 1);
    final Map<int, _YearlyNet> map = { for (int y = startYear; y <= now.year; y++) y: _YearlyNet(year: y, income: 0, expenses: 0) };

    for (final house in houses) {
      for (final room in house.rooms) {
        final Tenant? t = room.tenant;
        if (t == null) continue;
        for (final Payment p in t.payments) {
          if (p.date.year < startYear || p.date.year > now.year) continue;
          final y = p.date.year;
          final cur = map[y]!;
          map[y] = cur.copyWith(income: cur.income + p.amount);
        }
      }
    }

    return map.values.map((e) => e.withNet()).toList();
  }

  double _sum(List<double> values) => values.fold(0.0, (a, b) => a + b);

  Widget _monthlyTable(BuildContext context, List<_MonthlyNet> items) {
    final currency = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Monthly Breakdown', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DataTable(columns: const [
              DataColumn(label: Text('Month')),
              DataColumn(label: Text('Income')),
              DataColumn(label: Text('Expenses')),
              DataColumn(label: Text('Net Profit')),
            ], rows: [
              for (final m in items)
                DataRow(cells: [
                  DataCell(Text(m.label)),
                  DataCell(Text(currency.format(m.income))),
                  DataCell(Text(currency.format(m.expenses))),
                  DataCell(Text(currency.format(m.net))),
                ])
            ]),
          ],
        ),
      ),
    );
  }

  Widget _yearlyTable(BuildContext context, List<_YearlyNet> items) {
    final currency = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yearly Breakdown', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            DataTable(columns: const [
              DataColumn(label: Text('Year')),
              DataColumn(label: Text('Income')),
              DataColumn(label: Text('Expenses')),
              DataColumn(label: Text('Net Profit')),
            ], rows: [
              for (final y in items)
                DataRow(cells: [
                  DataCell(Text(y.year.toString())),
                  DataCell(Text(currency.format(y.income))),
                  DataCell(Text(currency.format(y.expenses))),
                  DataCell(Text(currency.format(y.net))),
                ])
            ]),
          ],
        ),
      ),
    );
  }

  Widget _rentAverages(BuildContext context, double overall, Map<String, double> byProperty) {
    final currency = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Average Monthly Rent', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _metricChip(context, 'Overall', currency.format(overall), Icons.payments, Colors.indigo),
                for (final entry in byProperty.entries)
                  _metricChip(context, entry.key, currency.format(entry.value), Icons.home_work, Colors.teal),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricChip(BuildContext context, String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  double _computeAverageRentOverall(List houses) {
    double sum = 0;
    int count = 0;
    for (final h in houses) {
      for (final r in h.rooms) {
        if (r.status.toString().contains('occupied') && r.rentAmount > 0) {
          sum += r.rentAmount;
          count++;
        }
      }
    }
    return count == 0 ? 0 : sum / count;
  }

  Map<String, double> _computeAverageRentByProperty(List houses) {
    final mapSum = <String, double>{};
    final mapCount = <String, int>{};
    for (final h in houses) {
      for (final r in h.rooms) {
        if (r.status.toString().contains('occupied') && r.rentAmount > 0) {
          mapSum[h.name] = (mapSum[h.name] ?? 0) + r.rentAmount;
          mapCount[h.name] = (mapCount[h.name] ?? 0) + 1;
        }
      }
    }
    final result = <String, double>{};
    for (final name in mapSum.keys) {
      final c = mapCount[name] ?? 1;
      result[name] = mapSum[name]! / c;
    }
    return result;
  }

  // KPI row with occupancy, projected income, avg tenancy duration, total overdue
  Widget _kpiRow(BuildContext context, List houses) {
    final theme = Theme.of(context);
    final currency = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);
    final kpis = _computeKpis(houses);

    return Row(
      children: [
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Overall Occupancy', style: theme.textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${kpis.occupancyRate.toStringAsFixed(1)}%', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      SizedBox(width: 120, child: LinearProgressIndicator(value: (kpis.occupancyRate / 100).clamp(0.0, 1.0))),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${kpis.occupiedRooms}/${kpis.totalRooms} rooms occupied', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(context, 'Projected Yearly Income', currency.format(kpis.projectedYearlyIncome), Icons.calendar_month, Colors.indigo),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(context, 'Avg Tenancy Duration', '${kpis.avgTenancyYears.toStringAsFixed(1)} years', Icons.timer, Colors.teal),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _metricCard(context, 'Total Overdue', currency.format(kpis.totalOverdue), Icons.warning_amber, Colors.red),
        ),
      ],
    );
  }

  _Kpis _computeKpis(List houses) {
    int totalRooms = 0;
    int occupiedRooms = 0;
    double projectedYearly = 0;
    double totalOverdue = 0;
    final now = DateTime.now();
    int tenantCount = 0;
    double totalTenancyDays = 0;

    for (final h in houses) {
      totalRooms += h.totalRooms;
      occupiedRooms += h.rooms.where((r) => r.status.toString().contains('occupied')).length;
      for (final r in h.rooms) {
        if (r.tenant != null) {
          final t = r.tenant!;
          tenantCount++;
          totalTenancyDays += now.difference(t.startDate).inDays.toDouble();
          projectedYearly += r.rentAmount * 12;
          if (t.isOverdue) totalOverdue += t.balance;
        }
      }
    }

    final occupancyRate = totalRooms > 0 ? (occupiedRooms / totalRooms) * 100 : 0.0;
    final avgTenancyYears = tenantCount > 0 ? (totalTenancyDays / tenantCount) / 365.0 : 0.0;

    return _Kpis(
      occupancyRate: occupancyRate,
      totalRooms: totalRooms,
      occupiedRooms: occupiedRooms,
      projectedYearlyIncome: projectedYearly,
      totalOverdue: totalOverdue,
      avgTenancyYears: avgTenancyYears,
    );
  }

  Widget _incomeVsExpensesByProperty(BuildContext context, List houses) {
    // Aggregate by property: income last 12 months, expenses currently 0 (placeholder)
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 11, 1);
    final names = <String>[];
    final income = <double>[];
    final expenses = <double>[];

    // Income per property
    for (final h in houses) {
      double inc = 0;
      for (final r in h.rooms) {
        final t = r.tenant;
        if (t == null) continue;
        for (final p in t.payments) {
          if (p.date.isBefore(start) || p.date.isAfter(now)) continue;
          inc += p.amount;
        }
      }
      names.add(h.name);
      income.add(inc);
    }
    // Expenses per property from ExpenseService
    final expenseService = context.read<ExpenseService>();
    final expByProp = expenseService.sumByProperty(start: start, end: now);
    for (final n in names) {
      expenses.add(expByProp[n] ?? 0);
    }

    return GroupedBarChart(
      title: 'Income vs Expenses by Property (12m)',
      seriesA: income,
      seriesB: expenses,
      colorA: Colors.green,
      colorB: Colors.red,
      labels: names,
      legendALabel: 'Income',
      legendBLabel: 'Expenses',
    );
  }

  Widget _occupancyByProperty(BuildContext context, List houses) {
    final labels = <String>[];
    final data = <double>[];
    for (final h in houses) {
      final total = h.totalRooms;
      final occ = h.rooms.where((r) => r.status.toString().contains('occupied')).length;
      final rate = total > 0 ? (occ / total) * 100 : 0.0;
      labels.add(h.name);
      data.add(rate);
    }
    return BarChartWidget(title: 'Occupancy Rate by Property', data: data, labels: labels, color: Colors.blueAccent);
  }

  Widget _onTimeVsOverdueChart(BuildContext context, List houses) {
    int onTime = 0;
    int overdue = 0;
    for (final h in houses) {
      for (final r in h.rooms) {
        final t = r.tenant;
        if (t == null) continue;
        if (t.isOverdue) {
          overdue++;
        } else {
          onTime++;
        }
      }
    }
    return PieChartWidget(title: 'On-Time vs Overdue Tenants', data: {'On-Time': onTime.toDouble(), 'Overdue': overdue.toDouble()});
  }

  Future<int> _countMoveOutsLastYear() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('tenant_history');
    if (raw == null) return 0;
    final list = (json.decode(raw) as List).cast<Map<String, dynamic>>();
    final oneYearAgo = DateTime.now().subtract(const Duration(days: 365));
    int count = 0;
    for (final m in list) {
      final moveOut = DateTime.parse(m['moveOutDate'] as String);
      if (!moveOut.isBefore(oneYearAgo)) count++;
    }
    return count;
  }

  Widget _turnoverKpi(BuildContext context, List houses) {
    final totalRooms = houses.fold<int>(0, (a, h) => a + h.totalRooms);
    return FutureBuilder<int>(
      future: _countMoveOutsLastYear(),
      builder: (context, snapshot) {
        final moveOuts = snapshot.data ?? 0;
        final rate = totalRooms > 0 ? (moveOuts / totalRooms) * 100 : 0.0;
        return Row(
          children: [
            Expanded(
              child: _metricCard(
                context,
                'Tenant Turnover Rate (12m)',
                '${rate.toStringAsFixed(1)}%',
                Icons.swap_horiz,
                Colors.deepOrange,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _metricCard(
                context,
                'Move-outs (12m)',
                moveOuts.toString(),
                Icons.logout,
                Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
            const SizedBox(width: 12),
          ],
        );
      },
    );
  }

  Widget _overdueRanking(BuildContext context, List houses) {
    final currency = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);
    final entries = <_OverdueEntry>[];
    for (final h in houses) {
      for (final r in h.rooms) {
        final t = r.tenant;
        if (t == null) continue;
        if (t.isOverdue) {
          entries.add(_OverdueEntry(house: h.name, tenant: t.fullName, amount: t.balance));
        }
      }
    }
    entries.sort((a, b) => b.amount.compareTo(a.amount));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Most Frequently Overdue Tenants', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              Text('No overdue tenants', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant))
            else
              DataTable(columns: const [
                DataColumn(label: Text('#')),
                DataColumn(label: Text('Tenant')),
                DataColumn(label: Text('Property')),
                DataColumn(label: Text('Amount Overdue')),
              ], rows: [
                for (int i = 0; i < entries.length && i < 10; i++)
                  DataRow(cells: [
                    DataCell(Text((i + 1).toString())),
                    DataCell(Text(entries[i].tenant)),
                    DataCell(Text(entries[i].house)),
                    DataCell(Text(currency.format(entries[i].amount))),
                  ])
              ]),
          ],
        ),
      ),
    );
  }
}

class _MonthlyNet {
  final String label;
  final double income;
  final double expenses;
  final double net;
  _MonthlyNet({required this.label, required this.income, required this.expenses}) : net = income - expenses;
  _MonthlyNet copyWith({double? income, double? expenses}) => _MonthlyNet(label: label, income: income ?? this.income, expenses: expenses ?? this.expenses);
  _MonthlyNet withNet() => _MonthlyNet(label: label, income: income, expenses: expenses);
}

class _YearlyNet {
  final int year;
  final double income;
  final double expenses;
  final double net;
  _YearlyNet({required this.year, required this.income, required this.expenses}) : net = income - expenses;
  _YearlyNet copyWith({double? income, double? expenses}) => _YearlyNet(year: year, income: income ?? this.income, expenses: expenses ?? this.expenses);
  _YearlyNet withNet() => _YearlyNet(year: year, income: income, expenses: expenses);
}
}
