import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:intl/intl.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';

enum ChartType { bar, line, pie }

class SalesGraphTab extends StatefulWidget {
  const SalesGraphTab({super.key});

  @override
  State<SalesGraphTab> createState() => _SalesGraphTabState();
}

class _SalesGraphTabState extends State<SalesGraphTab> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  ChartType _chartType = ChartType.bar;
  bool _isLoading = false;
  List<Map<String, dynamic>> _salesData = [];
  List<Map<String, dynamic>> _categoryData = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final sales = await DatabaseHelper.instance.getSalesChartData(_startDate, _endDate);
      final categories = await DatabaseHelper.instance.getLocalCategorySummaryRange(_startDate, _endDate);
      
      setState(() {
        _salesData = sales;
        _categoryData = categories;
      });
    } catch (e) {
      debugPrint("Error fetching graph data: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setPreset(String preset) {
    final now = DateTime.now();
    setState(() {
      _endDate = now;
      if (preset == '1W') {
        _startDate = now.subtract(const Duration(days: 7));
      } else if (preset == '1M') {
        _startDate = DateTime(now.year, now.month - 1, now.day);
      } else if (preset == '1Y') {
        _startDate = DateTime(now.year - 1, now.month, now.day);
      }
    });
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 24),
        _buildControls(),
        const SizedBox(height: 24),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black.withOpacity(0.05)),
            ),
            child: _isLoading 
              ? const Center(child: DonaposLoader(size: 80))
              : _salesData.isEmpty && _chartType != ChartType.pie
                ? const Center(child: Text("TIDAK ADA DATA PADA RENTANG INI", style: TextStyle(color: Colors.black26, fontWeight: FontWeight.bold)))
                : _buildChart(),
          ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildControls() {
    return Row(
      children: [
        // Presets
        _presetButton("7 HARI", "1W"),
        const SizedBox(width: 8),
        _presetButton("30 HARI", "1M"),
        const SizedBox(width: 8),
        _presetButton("1 TAHUN", "1Y"),
        const Spacer(),
        // Chart Type
        _typeButton(Icons.bar_chart, ChartType.bar),
        const SizedBox(width: 8),
        _typeButton(Icons.show_chart, ChartType.line),
        const SizedBox(width: 8),
        _typeButton(Icons.pie_chart, ChartType.pie),
        const SizedBox(width: 16),
        // Date Picker
        _dateRangePicker(),
      ],
    );
  }

  Widget _presetButton(String label, String preset) {
    return InkWell(
      onTap: () => _setPreset(preset),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: MetroColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MetroColors.primary.withOpacity(0.2)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: MetroColors.primary)),
      ),
    );
  }

  Widget _typeButton(IconData icon, ChartType type) {
    bool isSelected = _chartType == type;
    return IconButton(
      icon: Icon(icon, color: isSelected ? MetroColors.primary : Colors.black26),
      onPressed: () => setState(() => _chartType = type),
    );
  }

  Widget _dateRangePicker() {
    final df = DateFormat('dd/MM/yy');
    return InkWell(
      onTap: () async {
        final picked = await showDateRangePicker(
          context: context,
          initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) {
          setState(() {
            _startDate = picked.start;
            _endDate = picked.end;
          });
          _fetchData();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: MetroColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today, size: 14, color: MetroColors.primary),
            const SizedBox(width: 8),
            Text("${df.format(_startDate)} - ${df.format(_endDate)}", 
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900)
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart() {
    switch (_chartType) {
      case ChartType.bar:
        return _buildBarChart();
      case ChartType.line:
        return _buildLineChart();
      case ChartType.pie:
        return _buildPieChart();
    }
  }

  Widget _buildBarChart() {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: _getMaxY() * 1.2,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              return BarTooltipItem(
                rod.toY.toStringAsFixed(0),
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int idx = value.toInt();
                if (idx < 0 || idx >= _salesData.length) return const SizedBox.shrink();
                String date = _salesData[idx]['date'].substring(8, 10);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(date, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: const FlGridData(show: false),
        borderData: FlBorderData(show: false),
        barGroups: List.generate(_salesData.length, (i) {
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: (_salesData[i]['total_sales'] as num).toDouble(),
                color: MetroColors.primary,
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(4),
                  topRight: Radius.circular(4),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                int idx = value.toInt();
                if (idx < 0 || idx >= _salesData.length) return const SizedBox.shrink();
                String date = _salesData[idx]['date'].substring(8, 10);
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(date, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: true, border: Border.all(color: Colors.black12)),
        lineBarsData: [
          LineChartBarData(
            spots: List.generate(_salesData.length, (i) {
              return FlSpot(i.toDouble(), (_salesData[i]['total_sales'] as num).toDouble());
            }),
            isCurved: true,
            color: MetroColors.accent,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: MetroColors.accent.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    if (_categoryData.isEmpty) {
        return const Center(child: Text("TIDAK ADA DATA KATEGORI", style: TextStyle(color: Colors.black26, fontWeight: FontWeight.bold)));
    }

    final colors = [
      Colors.blue, Colors.red, Colors.green, Colors.orange, 
      Colors.purple, Colors.teal, Colors.pink, Colors.amber
    ];

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: List.generate(_categoryData.length, (i) {
                final val = (_categoryData[i]['total_sales'] as num).toDouble();
                return PieChartSectionData(
                  color: colors[i % colors.length],
                  value: val,
                  radius: 60,
                  title: '', // Hide Title inside to avoid clutter
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          flex: 3,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_categoryData.length, (i) {
                final val = (_categoryData[i]['total_sales'] as num).toDouble();
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Container(width: 12, height: 12, color: colors[i % colors.length]),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "${(_categoryData[i]['category_name'] ?? 'LAINNYA').toString().toUpperCase()} - ${NumberFormat('#,###').format(val)}", 
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ],
    );
  }

  double _getMaxY() {
    if (_salesData.isEmpty) return 1.0;
    double max = 0;
    for (var d in _salesData) {
      if ((d['total_sales'] as num).toDouble() > max) {
        max = (d['total_sales'] as num).toDouble();
      }
    }
    return max == 0 ? 1.0 : max;
  }
}
