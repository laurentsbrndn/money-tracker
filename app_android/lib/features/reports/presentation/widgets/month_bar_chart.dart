import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../../core/money/money_formatter.dart';
import 'chart_colors.dart';

/// One bar of a [MonthBarChart].
class BarValue {
  const BarValue({required this.value, required this.color});

  final int value;
  final Color color;
}

/// One group of bars under a label (a month, or a measure of a comparison).
class BarGroup {
  const BarGroup({required this.label, required this.bars});

  final String label;
  final List<BarValue> bars;
}

/// Grouped bars over a row of labels, for the trend, comparison and
/// unrecorded-difference reports. Values may be negative. With [hidden] the
/// value axis and the tooltips show no amount (the shape of the bars stays).
/// More groups than fit the width make the chart scroll sideways.
class MonthBarChart extends StatelessWidget {
  const MonthBarChart({
    required this.groups,
    required this.hidden,
    required this.semanticsLabel,
    this.onGroupTap,
    super.key,
  });

  final List<BarGroup> groups;
  final bool hidden;
  final String semanticsLabel;
  final ValueChanged<int>? onGroupTap;

  static const double _groupWidth = 56;

  @override
  Widget build(BuildContext context) {
    final colors = ChartColors.of(context);
    final theme = Theme.of(context);
    var maxValue = 0;
    var minValue = 0;
    for (final group in groups) {
      for (final bar in group.bars) {
        maxValue = bar.value > maxValue ? bar.value : maxValue;
        minValue = bar.value < minValue ? bar.value : minValue;
      }
    }
    // Headroom so the tallest bar does not touch the top.
    final top = maxValue == 0 && minValue == 0 ? 1.0 : maxValue * 1.15;
    final bottom = minValue * 1.15;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(color: colors.text);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = groups.length * _groupWidth + (hidden ? 0 : 56);
        final chartWidth = width > constraints.maxWidth
            ? width
            : constraints.maxWidth;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Semantics(
            label: semanticsLabel,
            child: SizedBox(
              width: chartWidth,
              height: 240,
              child: Padding(
                padding: const EdgeInsets.only(top: 12, right: 8),
                child: BarChart(
                  BarChartData(
                    maxY: top,
                    minY: bottom,
                    alignment: BarChartAlignment.spaceAround,
                    gridData: FlGridData(
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: colors.grid, strokeWidth: 0.5),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      topTitles: const AxisTitles(),
                      rightTitles: const AxisTitles(),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: !hidden,
                          reservedSize: 52,
                          getTitlesWidget: (value, meta) {
                            if (value == meta.max || value == meta.min) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                formatCompact(value.round()),
                                style: labelStyle,
                              ),
                            );
                          },
                        ),
                      ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 28,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index < 0 || index >= groups.length) {
                              return const SizedBox.shrink();
                            }
                            return SideTitleWidget(
                              meta: meta,
                              child: Text(
                                groups[index].label,
                                style: labelStyle,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) =>
                            theme.colorScheme.inverseSurface,
                        getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                            BarTooltipItem(
                              formatRupiah(rod.toY.round(), hidden: hidden),
                              TextStyle(
                                color: theme.colorScheme.onInverseSurface,
                                fontSize: 12,
                              ),
                            ),
                      ),
                      touchCallback: (event, response) {
                        if (event is! FlTapUpEvent) {
                          return;
                        }
                        final index = response?.spot?.touchedBarGroupIndex;
                        if (index != null && index >= 0) {
                          onGroupTap?.call(index);
                        }
                      },
                    ),
                    barGroups: [
                      for (var i = 0; i < groups.length; i++)
                        BarChartGroupData(
                          x: i,
                          barsSpace: 3,
                          barRods: [
                            for (final bar in groups[i].bars)
                              BarChartRodData(
                                toY: bar.value.toDouble(),
                                color: bar.color,
                                width: groups[i].bars.length > 1 ? 14 : 22,
                                borderRadius: BorderRadius.circular(3),
                              ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
