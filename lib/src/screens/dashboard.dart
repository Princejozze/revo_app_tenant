import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:myapp/src/services/house_service.dart';
import 'package:myapp/src/services/auth_service.dart';
import 'package:myapp/src/services/theme_service.dart';
import 'package:myapp/src/models/house.dart';
import 'package:myapp/src/models/room.dart';
import 'package:myapp/src/widgets/add_property_dialog.dart';
import 'package:myapp/src/widgets/tenant_search_dialog.dart';
import 'package:myapp/src/widgets/house_list.dart';
import 'package:myapp/src/widgets/simple_chart.dart';
import 'package:myapp/src/widgets/pie_chart.dart';
import 'package:myapp/src/screens/tenant_history_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  // Navigation callback - will be set by parent
  static Function(int)? onNavigateToTab;

  void _showAddPropertyDialog(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    if (isMobile) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => const AddPropertyDialog(),
      );
    } else {
      showDialog(
        context: context,
        builder: (context) => const AddPropertyDialog(),
      );
    }
  }

  void _showTenantSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const TenantSearchDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    print('DashboardScreen: Building dashboard...');
    return Consumer<HouseService>(
      builder: (context, houseService, child) {
        final houses = houseService.houses;
        print('DashboardScreen: Found ${houses.length} houses');
        final metrics = _calculateMetrics(houses);
        
        return Scaffold(
          appBar: AppBar(
            title: const Text('Dashboard'),
           actions: [ // Removed search/plus per requirement
             // Intentionally left blank: actions moved to Properties page
             // IconButton(Icons.search ...), IconButton(Icons.add ...)
            
             Consumer<ThemeService>(
               builder: (context, themeService, _) {
                 final mode = themeService.mode;
                 IconData icon;
                 String tooltip;
                 switch (mode) {
                   case ThemeMode.system:
                     icon = Icons.brightness_auto;
                     tooltip = 'System theme';
                     break;
                   case ThemeMode.light:
                     icon = Icons.light_mode;
                     tooltip = 'Light theme';
                     break;
                   case ThemeMode.dark:
                     icon = Icons.dark_mode;
                     tooltip = 'Dark theme';
                     break;
                 }
                 return IconButton(
                   icon: Icon(icon),
                   tooltip: '$tooltip — tap to change',
                   onPressed: () => themeService.cycleMode(),
                 );
               },
             ),
           ],
          ),
          body: _buildDashboard(context, metrics),
        );
      },
    );
  }

  Widget _buildDashboard(BuildContext context, DashboardMetrics metrics) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Section
          _buildWelcomeSection(context),
          const SizedBox(height: 24),
          
          // Key Metrics Cards
          _buildMetricsGrid(context, metrics),
          const SizedBox(height: 24),
          
          // Quick Actions
          _buildQuickActions(context),
          const SizedBox(height: 24),
          
          // Recent Activity
          _buildRecentActivity(context, metrics),
          const SizedBox(height: 24),
          
          // Analytics Charts
          _buildAnalyticsSection(context, metrics),
          // Screen ends at Analytics per requirement (removed "Your Properties" section)
        ],
      ),
    );
  }

  Widget _buildWelcomeSection(BuildContext context) {
    final now = DateTime.now();
    final greeting = _getGreeting(now.hour);
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.primaryContainer,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$greeting, ${context.read<AuthService>().displayName ?? 'Landlord'}!',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Here\'s your property management overview',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.9),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            DateFormat('EEEE, MMMM d, yyyy').format(now),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context, DashboardMetrics metrics) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.2,
      children: [
        _buildMetricCard(
          context,
          'Total Properties',
          metrics.totalProperties.toString(),
          Icons.home,
          Colors.blue,
          onTap: () => _navigateToProperties(context),
        ),
        _buildMetricCard(
          context,
          'Total Rooms',
          metrics.totalRooms.toString(),
          Icons.king_bed,
          Colors.green,
        ),
        _buildMetricCard(
          context,
          'Occupied Rooms',
          metrics.occupiedRooms.toString(),
          Icons.person,
          Colors.orange,
        ),
        _buildMetricCard(
          context,
          'Vacant Rooms',
          metrics.vacantRooms.toString(),
          Icons.bed,
          Colors.red,
        ),
      ],
    );
  }

  Widget _buildMetricCard(BuildContext context, String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 32,
                color: color,
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                'Search Tenants',
                'Find and manage tenants',
                Icons.search,
                () => _showTenantSearchDialog(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                context,
                'Add Property',
                'Add a new property',
                Icons.add_home,
                () => _showAddPropertyDialog(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                'View Properties',
                'Manage your houses',
                Icons.home,
                () => _navigateToProperties(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                context,
                'Upcoming Payments',
                'See upcoming rents',
                Icons.calendar_today,
                () => _navigateToUpcoming(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                context,
                'Payment History',
                'View all payments',
                Icons.receipt_long,
                () => _navigateToPayments(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                context,
                'Tenant History',
                'Past tenants & vacancies',
                Icons.history,
                () => _navigateToHistory(context),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard(BuildContext context, String title, String subtitle, IconData icon, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                size: 32,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentActivity(BuildContext context, DashboardMetrics metrics) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Property Overview',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Occupancy Rate',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${metrics.occupancyRate.toStringAsFixed(1)}%',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: metrics.occupancyRate > 80 ? Colors.green : 
                               metrics.occupancyRate > 60 ? Colors.orange : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: metrics.occupancyRate / 100,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    metrics.occupancyRate > 80 ? Colors.green : 
                    metrics.occupancyRate > 60 ? Colors.orange : Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem(context, 'Total Revenue', metrics.totalRevenue),
                    _buildStatItem(context, 'Avg Rent', metrics.averageRent),
                    _buildStatItem(context, 'Properties', metrics.totalProperties.toString()),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection(BuildContext context, DashboardMetrics metrics) {
    final kpis = _computeDashboardKpis();
    final currency = NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Analytics Overview',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            TextButton.icon(
              onPressed: () => onNavigateToTab?.call(4), // navigate to Analytics tab if present
              icon: const Icon(Icons.analytics),
              label: const Text('View Full Analytics'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // KPI row
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                context,
                'Projected Yearly Income',
                currency.format(kpis.projectedYearlyIncome),
                Icons.calendar_month,
                Colors.indigo,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                context,
                'Total Overdue',
                currency.format(kpis.totalOverdue),
                Icons.warning_amber,
                Colors.red,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                context,
                'Avg Tenancy Duration',
                '${kpis.avgTenancyYears.toStringAsFixed(1)} years',
                Icons.timer,
                Colors.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: SimpleChart(
                title: 'Net Profit (12 months)',
                data: _computeDashboardNetProfit(),
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: PieChartWidget(
                title: 'On-Time vs Overdue Tenants',
                data: _computeOnTimeVsOverdue(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPropertiesOverview(BuildContext context) {
    return Consumer<HouseService>(
      builder: (context, houseService, child) {
        final houses = houseService.houses;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Your Properties',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _navigateToProperties(context),
                  icon: const Icon(Icons.apartment),
                  label: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            houses.isEmpty 
              ? Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.apartment_outlined,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No Properties Yet',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first property to start managing rentals',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showAddPropertyDialog(context),
                          icon: const Icon(Icons.add),
                          label: const Text('Add Property'),
                        ),
                      ],
                    ),
                  ),
                )
              : const HouseList(),
          ],
        );
      },
    );
  }

  String _getGreeting(int hour) {
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  List<double> _computeDashboardNetProfit() {
    // Compute net profit for last 12 months using payments as income and 0 expenses for now
    final houses = context.read<HouseService>().houses;
    final now = DateTime.now();
    final start = DateTime(now.year, now.month - 11, 1);
    final monthFmt = DateFormat('MMM yy');
    final Map<String, double> map = {};
    for (int i = 0; i < 12; i++) {
      final dt = DateTime(start.year, start.month + i, 1);
      map[monthFmt.format(dt)] = 0;
    }
    for (final h in houses) {
      for (final r in h.rooms) {
        final t = r.tenant;
        if (t == null) continue;
        for (final p in t.payments) {
          if (p.date.isBefore(start) || p.date.isAfter(now)) continue;
          final key = monthFmt.format(DateTime(p.date.year, p.date.month, 1));
          map[key] = (map[key] ?? 0) + p.amount; // expenses=0
        }
      }
    }
    return map.values.toList();
  }

  Map<String, double> _computeOnTimeVsOverdue() {
    int onTime = 0;
    int overdue = 0;
    final houses = context.read<HouseService>().houses;
    for (final h in houses) {
      for (final r in h.rooms) {
        final t = r.tenant;
        if (t == null) continue;
        if (t.isOverdue) overdue++; else onTime++;
      }
    }
    return {'On-Time': onTime.toDouble(), 'Overdue': overdue.toDouble()};
  }

  void _navigateToProperties(BuildContext context) {
    // Navigate to properties tab (index 1)
    if (onNavigateToTab != null) {
      onNavigateToTab!(1);
    }
  }

  void _navigateToUpcoming(BuildContext context) {
    // Navigate to upcoming payments tab (index 2)
    if (onNavigateToTab != null) {
      onNavigateToTab!(2);
    }
  }

  void _navigateToPayments(BuildContext context) {
    // Navigate to payment history tab (index 5)
    if (onNavigateToTab != null) {
      onNavigateToTab!(5);
    }
  }

  void _navigateToHistory(BuildContext context) {
    // Navigate to tenant history screen - full screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const TenantHistoryScreen(),
        fullscreenDialog: true,
      ),
    );
  }

  DashboardMetrics _calculateMetrics(List<House> houses) {
    int totalProperties = houses.length;
    int totalRooms = houses.fold(0, (sum, house) => sum + house.totalRooms);
    int occupiedRooms = houses.fold(0, (sum, house) => sum + house.occupiedRooms);
    int vacantRooms = totalRooms - occupiedRooms;
    
    double occupancyRate = totalRooms > 0 ? (occupiedRooms / totalRooms) * 100 : 0;
    
    // Calculate revenue from occupied rooms
    double totalRevenue = 0;
    int roomsWithRent = 0;
    
    for (var house in houses) {
      for (var room in house.rooms) {
        if (room.status == RoomStatus.occupied && room.rentAmount > 0) {
          totalRevenue += room.rentAmount;
          roomsWithRent++;
        }
      }
    }
    
    double averageRent = roomsWithRent > 0 ? totalRevenue / roomsWithRent : 0;
    
    return DashboardMetrics(
      totalProperties: totalProperties,
      totalRooms: totalRooms,
      occupiedRooms: occupiedRooms,
      vacantRooms: vacantRooms,
      occupancyRate: occupancyRate,
      totalRevenue: NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0).format(totalRevenue),
      averageRent: NumberFormat.currency(symbol: 'TZS ', decimalDigits: 0).format(averageRent),
    );
  }
}

class DashboardMetrics {
  final int totalProperties;
  final int totalRooms;
  final int occupiedRooms;
  final int vacantRooms;
  final double occupancyRate;
  final String totalRevenue;
  final String averageRent;

  DashboardMetrics({
    required this.totalProperties,
    required this.totalRooms,
    required this.occupiedRooms,
    required this.vacantRooms,
    required this.occupancyRate,
    required this.totalRevenue,
    required this.averageRent,
  });
}