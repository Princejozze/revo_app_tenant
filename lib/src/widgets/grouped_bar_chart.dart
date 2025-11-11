import 'package:flutter/material.dart';

class GroupedBarChart extends StatelessWidget {
  final String title;
  final List<double> seriesA; // e.g., Income
  final List<double> seriesB; // e.g., Expenses
  final Color colorA;
  final Color colorB;
  final List<String>? labels; // optional x-axis labels (length should match data)
  final String legendALabel;
  final String legendBLabel;
  final bool showSeriesB;
  final String title;
  final List<double> seriesA; // e.g., Income
  final List<double> seriesB; // e.g., Expenses
  final Color colorA;
  final Color colorB;
  final List<String>? labels; // optional x-axis labels (length should match data)

  const GroupedBarChart({
    super.key,
    required this.title,
    required this.seriesA,
    required this.seriesB,
    required this.colorA,
    required this.colorB,
    this.labels,
    this.legendALabel = 'Income',
    this.legendBLabel = 'Expenses',
    bool? showSeriesB,
  }) : showSeriesB = showSeriesB ?? (seriesB.any((v) => v != 0));

  @override
  Widget build(BuildContext context) {
    final len = seriesA.length;
    if (len == 0 || seriesB.length != len) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('No data available', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    final combined = showSeriesB ? [...seriesA, ...seriesB] : [...seriesA];
    final maxVal = combined.fold<double>(0, (m, v) => v > m ? v : m);
    final safeMax = maxVal <= 0 ? 1.0 : maxVal;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: CustomPaint(
                painter: _GroupedBarPainter(
                  a: seriesA,
                  b: seriesB,
                  colorA: colorA,
                  colorB: colorB,
                  maxVal: safeMax,
                  showB: showSeriesB,
                ),
                child: labels != null && labels!.length == len
                    ? Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: _LabelsRow(labels: labels!),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _LegendDot(color: colorA),
                const SizedBox(width: 6),
                Text(legendALabel),
                if (showSeriesB) ...[
                  const SizedBox(width: 16),
                  _LegendDot(color: colorB),
                  const SizedBox(width: 6),
                  Text(legendBLabel),
                ],
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _GroupedBarPainter extends CustomPainter {
  final List<double> a;
  final List<double> b;
  final Color colorA;
  final Color colorB;
  final double maxVal;

  final bool showB;

  _GroupedBarPainter({required this.a, required this.b, required this.colorA, required this.colorB, required this.maxVal, required this.showB});

  @override
  void paint(Canvas canvas, Size size) {
    final groupFactor = showB ? 3 : 2; // spacing + bars
    final barWidth = size.width / (a.length * groupFactor);
    final gap = barWidth; // space between groups

    final paintA = Paint()..color = colorA;
    final paintB = Paint()..color = colorB;

    for (int i = 0; i < a.length; i++) {
      final groupLeft = i * ((showB ? 2 : 1) * barWidth + gap);
      final heightA = (a[i] / maxVal) * (size.height - 24); // leave space for labels
      final heightB = (b[i] / maxVal) * (size.height - 24);

      // A bar
      final rectA = Rect.fromLTWH(groupLeft, (size.height - 24) - heightA, barWidth, heightA);
      canvas.drawRRect(RRect.fromRectAndRadius(rectA, const Radius.circular(4)), paintA);

      if (showB) {
        final rectB = Rect.fromLTWH(groupLeft + barWidth + (barWidth * 0.25), (size.height - 24) - heightB, barWidth, heightB);
        canvas.drawRRect(RRect.fromRectAndRadius(rectB, const Radius.circular(4)), paintB);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  const _LegendDot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle));
  }
}

class _LabelsRow extends StatelessWidget {
  final List<String> labels;
  const _LabelsRow({required this.labels});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = constraints.maxWidth / labels.length;
        return Row(
          children: [
            for (final l in labels)
              SizedBox(
                width: itemWidth,
                child: Center(
                  child: Text(
                    l,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
          ],
        );
      },
    );
  }
}
