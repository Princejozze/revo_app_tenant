import 'package:flutter/material.dart';

class BarChartWidget extends StatelessWidget {
  final String title;
  final List<double> data;
  final List<String>? labels;
  final Color color;

  const BarChartWidget({
    super.key,
    required this.title,
    required this.data,
    this.labels,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
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

    final maxVal = data.fold<double>(0, (m, v) => v > m ? v : m);
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
                painter: _BarPainter(data: data, color: color, maxVal: safeMax),
                child: labels != null && labels!.length == data.length
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
          ],
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final double maxVal;

  _BarPainter({required this.data, required this.color, required this.maxVal});

  @override
  void paint(Canvas canvas, Size size) {
    final barWidth = size.width / (data.length * 2);
    final gap = barWidth; // space between bars

    final paint = Paint()..color = color;

    for (int i = 0; i < data.length; i++) {
      final left = i * (barWidth + gap);
      final height = (data[i] / maxVal) * (size.height - 24);
      final rect = Rect.fromLTWH(left, (size.height - 24) - height, barWidth, height);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(4)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
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
