import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:donapos_mobile/design_system.dart';
import 'package:donapos_mobile/db_helper.dart';
import 'package:intl/intl.dart';
import 'package:donapos_mobile/widgets/glass_dialog.dart';

class SalesChartDialog extends StatefulWidget {
  const SalesChartDialog({super.key});

  @override
  State<SalesChartDialog> createState() => _SalesChartDialogState();
}

class _SalesChartDialogState extends State<SalesChartDialog> {
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();
  
  List<Map<String, dynamic>> _data = [];
  bool _isLoading = true;
  double _maxSales = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final data = await DatabaseHelper.instance.getSalesChartData(_startDate, _endDate);
    
    // Fill in missing dates with 0-value entries
    List<Map<String, dynamic>> filledData = [];
    Map<String, double> salesMap = {};
    for (var item in data) {
       salesMap[item['date']] = (item['total_sales'] as num).toDouble();
    }

    double maxVal = 0;
    int days = _endDate.difference(_startDate).inDays;
    // Safety cap
    if (days > 365 * 2) days = 365 * 2; 

    for (int i = 0; i <= days; i++) {
        DateTime d = _startDate.add(Duration(days: i));
        String dStr = d.toIso8601String().substring(0, 10);
        double val = salesMap[dStr] ?? 0;
        if (val > maxVal) maxVal = val;
        filledData.add({'date': dStr, 'value': val, 'dt': d});
    }

    _maxSales = maxVal * 1.2;
    if (_maxSales == 0) _maxSales = 1000000; 

    if (mounted) {
       setState(() {
           _data = filledData;
           _isLoading = false;
       });
    }
  }

  Future<void> _pickStartDate() async {
      final picked = await showDatePicker(
          context: context,
          initialDate: _startDate,
          firstDate: DateTime(2020),
          lastDate: _endDate,
          builder: (context, child) => _themeDatePicker(context, child!),
      );
      if (picked != null) {
          setState(() { _startDate = picked; });
          _loadData();
      }
  }

  Future<void> _pickEndDate() async {
      final picked = await showDatePicker(
          context: context,
          initialDate: _endDate,
          firstDate: _startDate, 
          lastDate: DateTime.now(),
          builder: (context, child) => _themeDatePicker(context, child!),
      );
      if (picked != null) {
          setState(() { _endDate = picked; });
          _loadData();
      }
  }

  Widget _themeDatePicker(BuildContext context, Widget child) {
      return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: MetroColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child,
      );
  }

  void _openChartDetail(String type, String title, IconData icon) {
      showDialog(
          context: context, 
          builder: (_) => ChartDetailDialog(
              type: type, 
              title: title, 
              icon: icon, 
              data: _data, 
              maxSales: _maxSales
          )
      );
  }

  @override
  Widget build(BuildContext context) {
    // Calculcate stats
    double totalSales = _data.fold(0.0, (sum, item) => sum + item['value']);
    double avgSales = _data.isEmpty ? 0 : totalSales / _data.length;
    double maxSalesVal = _data.fold(0.0, (prev, item) => item['value'] > prev ? item['value'] : prev);

    final currency = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);

    return GlassDialog(
        title: 'ANALISA KEUANGAN & GRAFIK', 
        icon: Icons.ssid_chart, // More analytic looking icon
        width: 800,
        height: 600,
        content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                // 1. Date Controls
                Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.black12),
                    ),
                    child: Row(
                        children: [
                            Expanded(child: _dateInput('DARI TANGGAL', _startDate, _pickStartDate)),
                            const SizedBox(width: 16),
                            Expanded(child: _dateInput('SAMPAI TANGGAL', _endDate, _pickEndDate)),
                        ],
                    ),
                ),
                
                // 2. Summary Cards (Hero Stats)
                Row(
                    children: [
                        Expanded(child: _statCard('TOTAL PENJUALAN', currency.format(totalSales), Icons.monetization_on, MetroColors.primary)),
                        const SizedBox(width: 12),
                        Expanded(child: _statCard('RATA-RATA / HARI', currency.format(avgSales), Icons.functions, Colors.orange)),
                        const SizedBox(width: 12),
                        Expanded(child: _statCard('REKOR TERTINGGI', currency.format(maxSalesVal), Icons.emoji_events, Colors.purple)),
                    ],
                ),
                
                const Spacer(),
                const Text('PILIH MODEL VISUALISASI GRAFIK:', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: Colors.black54)),
                const SizedBox(height: 16),

                // 3. Chart Entry Points
                Row(
                    children: [
                        Expanded(child: _chartMenuBtn('GRAFIK GARIS', 'Line Chart', Icons.show_chart, Colors.blue, () => _openChartDetail('line', 'GRAFIK GARIS (LINE)', Icons.show_chart))),
                        const SizedBox(width: 16),
                        Expanded(child: _chartMenuBtn('GRAFIK BATANG', 'Bar Chart', Icons.bar_chart, Colors.green, () => _openChartDetail('bar', 'GRAFIK BATANG (BAR)', Icons.bar_chart))),
                        const SizedBox(width: 16),
                        Expanded(child: _chartMenuBtn('GRAFIK PIE', 'Pie Distribution', Icons.pie_chart, Colors.pink, () => _openChartDetail('pie', 'DISTRIBUSI PIE', Icons.pie_chart))),
                    ],
                ),
                const Spacer(),
            ],
        )
    );
  }

  Widget _dateInput(String label, DateTime date, VoidCallback onTap) {
      return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[50],
              ),
              child: Row(
                  children: [
                      Icon(Icons.calendar_month, size: 20, color: MetroColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Text(label, style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(DateFormat('dd MMM yyyy').format(date), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87)),
                              ],
                          ),
                      )
                  ],
              ),
          ),
      );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
      return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.3)),
              boxShadow: [BoxShadow(color: color.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))]
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                  Row(
                      children: [
                          Icon(icon, size: 16, color: color),
                          const SizedBox(width: 8),
                          Expanded(child: Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                      ],
                  ),
                  const SizedBox(height: 8),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.black87)),
              ],
          ),
      );
  }

  Widget _chartMenuBtn(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
      return Material(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                  height: 120,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      border: Border.all(color: color.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(12)
                  ),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                          Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.white, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5)]),
                              child: Icon(icon, size: 28, color: color)
                          ),
                          const SizedBox(height: 12),
                          Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
                      ],
                  ),
              ),
          ),
      );
  }
}

class ChartDetailDialog extends StatelessWidget {
    final String type;
    final String title;
    final IconData icon;
    final List<Map<String, dynamic>> data;
    final double maxSales;

    const ChartDetailDialog({
        super.key, 
        required this.type, 
        required this.title, 
        required this.icon, 
        required this.data, 
        required this.maxSales
    });

    @override
    Widget build(BuildContext context) {
        final size = MediaQuery.of(context).size;
        final isLandscape = size.width > size.height;
        final double dWidth = isLandscape ? size.width * 0.95 : size.width * 0.95;
        final double dHeight = isLandscape ? size.height * 0.9 : size.height * 0.85;

        return GlassDialog(
            title: title,
            icon: icon,
            width: dWidth,
            height: dHeight,
            content: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                ),
                child: data.isEmpty 
                    ? const Center(child: Text("Tidak ada data untuk ditampilkan."))
                    : _buildChart(),
            ),
        );
    }

    Widget _buildChart() {
      final currency = NumberFormat.compactCurrency(symbol: 'Rp', decimalDigits: 0);
      
      if (type == 'pie') {
          double total = data.fold(0, (sum, item) => sum + (item['value'] as double));
          return PieChart(
              PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 60,
                  sections: data.where((e) => e['value'] > 0).map((e) {
                      final val = e['value'] as double;
                      final date = e['dt'] as DateTime;
                      final pct = total > 0 ? (val / total * 100) : 0;
                      // Only show labels for slices > 3%
                      final showLabel = pct > 3;

                      return PieChartSectionData(
                          color: MetroColors.primary.withOpacity((val / maxSales).clamp(0.2, 1.0)),
                          value: val,
                          title: showLabel ? '${DateFormat('d MMM').format(date)}\n${pct.toStringAsFixed(1)}%' : '',
                          radius: 120,
                          titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black, blurRadius: 2)]),
                      );
                  }).toList(),
              )
          );
      }
      
      if (type == 'bar') {
          return BarChart(
              BarChartData(
                  gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxSales / 6),
                  titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                             int idx = val.toInt();
                             if (idx >= 0 && idx < data.length) {
                                 // Smart Labeling
                                 int step = 1;
                                 if (data.length > 30) step = 7; // Weekly
                                 else if (data.length > 15) step = 3; // Every 3 days
                                 else if (data.length > 10) step = 2; // Every 2 days
                                 
                                 if (idx % step != 0) return const SizedBox();
                                 return Padding(padding: const EdgeInsets.only(top: 10), child: Text(DateFormat('dd/MM').format(data[idx]['dt']), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)));
                             }
                             return const SizedBox();
                          },
                          reservedSize: 30
                      )),
                      leftTitles: AxisTitles(sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 50,
                          getTitlesWidget: (val, meta) => Text(currency.format(val), style: const TextStyle(fontSize: 10, color: Colors.black45, fontWeight: FontWeight.bold)),
                          interval: maxSales / 6
                      )),
                  ),
                  borderData: FlBorderData(show: false),
                  maxY: maxSales,
                  barGroups: data.asMap().entries.map((e) {
                      return BarChartGroupData(
                          x: e.key,
                          barRods: [BarChartRodData(
                              toY: e.value['value'], 
                              color: MetroColors.primary, 
                              width: data.length > 20 ? 8 : 16, 
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              backDrawRodData: BackgroundBarChartRodData(show: true, toY: maxSales, color: Colors.grey[100]) // Background track
                          )],
                      );
                  }).toList(),
                  barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                          getTooltipColor: (_) => MetroColors.surface,
                          getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final d = data[group.x.toInt()];
                              return BarTooltipItem(
                                  '${DateFormat('EEEE, dd MMM yyyy', 'id_ID').format(d['dt'])}\n', 
                                  const TextStyle(color: Colors.black54, fontWeight: FontWeight.bold, fontSize: 12),
                                  children: [TextSpan(text: NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(rod.toY), style: const TextStyle(color: MetroColors.primary, fontWeight: FontWeight.w900, fontSize: 14))]
                              );
                          }
                      )
                  )
              )
          );
      }

      // Line Chart
      return LineChart(
        LineChartData(
            gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxSales / 6,
                getDrawingHorizontalLine: (value) => const FlLine(color: Colors.black12, strokeWidth: 1),
            ),
            titlesData: FlTitlesData(
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                            int idx = value.toInt();
                            if (idx >= 0 && idx < data.length) {
                                int step = 1;
                                 if (data.length > 30) step = 7; // Weekly
                                 else if (data.length > 15) step = 3; 
                                 else if (data.length > 10) step = 2;

                                if (idx % step != 0) return const SizedBox();
                                return Padding(
                                    padding: const EdgeInsets.only(top: 8.0),
                                    child: Text(DateFormat('dd/MM').format(data[idx]['dt']), style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold)),
                                );
                            }
                            return const SizedBox();
                        },
                    ),
                ),
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                            if (value == 0) return const SizedBox();
                            return Text(currency.format(value), textAlign: TextAlign.right, style: const TextStyle(color: Colors.black45, fontSize: 10, fontWeight: FontWeight.bold));
                        },
                        interval: maxSales / 6
                    ),
                ),
            ),
            borderData: FlBorderData(show: false),
            minX: 0,
            maxX: (data.length - 1).toDouble(),
            minY: 0,
            maxY: maxSales,
            lineBarsData: [
                LineChartBarData(
                    spots: data.asMap().entries.map((e) {
                        return FlSpot(e.key.toDouble(), e.value['value']);
                    }).toList(),
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: MetroColors.primary,
                    barWidth: 4,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                                radius: 4,
                                color: Colors.white,
                                strokeWidth: 2,
                                strokeColor: MetroColors.primary,
                            );
                        }
                    ),
                    belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                            colors: [
                                MetroColors.primary.withOpacity(0.4),
                                MetroColors.primary.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                        ),
                    ),
                ),
            ],
            lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => MetroColors.surface,
                    getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                            final flSpot = barSpot;
                            final date = data[flSpot.x.toInt()]['dt'] as DateTime;
                            return LineTooltipItem(
                                '${DateFormat('EEEE, dd MMM').format(date)}\n',
                                const TextStyle(
                                    color: Colors.black54,
                                    fontWeight: FontWeight.bold,
                                ),
                                children: [
                                    TextSpan(
                                        text: NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(flSpot.y),
                                        style: const TextStyle(
                                            color: MetroColors.primary,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14
                                        ),
                                    ),
                                ],
                            );
                        }).toList();
                    },
                ),
            ),
        )
    );
  }
}
