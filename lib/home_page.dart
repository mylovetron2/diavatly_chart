import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';

class DataPoint {
  final String time;
  final double lpm;
  final double rpm;
  final double liter;
  DataPoint(
      {required this.time,
      required this.lpm,
      required this.rpm,
      required this.liter});
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<DataPoint> data = [];
  String? fileName;

  // Settings for chart customization
  double lpmMin = 0;
  double lpmMax = 0;
  double rpmMin = 0;
  double rpmMax = 0;
  double literMin = 0;
  double literMax = 0;

  double lpmLineWidth = 2;
  double rpmLineWidth = 2;
  double literLineWidth = 2;

  Color lpmColor = Colors.blue;
  Color rpmColor = Colors.red;
  Color literColor = Colors.green;

  bool showSettings = false;

  // Time compression/expansion variables
  double timeScale = 1.0; // 1.0 = normal, <1.0 = compressed, >1.0 = expanded
  double timeScaleMin = 0.1; // Tỷ lệ co tối thiểu
  double timeScaleMax = 5.0; // Tỷ lệ giãn tối đa
  bool showTimeControls = false;

  Future<void> pickFile() async {
    FilePickerResult? result = await FilePicker.platform
        .pickFiles(type: FileType.custom, allowedExtensions: ['txt']);
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final lines = await file.readAsLines();
      setState(() {
        fileName = result.files.single.name;
        data = parseData(lines);
        // Initialize min/max values when data is loaded
        _initializeMinMaxValues();
      });
    }
  }

  List<DataPoint> parseData(List<String> lines) {
    final List<DataPoint> points = [];
    final regex =
        RegExp(r'\s*(\d+:\d+:\d+:\d+)\s+([\d.]+)\s+([\d.]+)\s+([\d.]+)');
    for (final line in lines) {
      final match = regex.firstMatch(line);
      if (match != null) {
        points.add(DataPoint(
          time: match.group(1)!,
          lpm: double.tryParse(match.group(2)!) ?? 0,
          rpm: double.tryParse(match.group(3)!) ?? 0,
          liter: double.tryParse(match.group(4)!) ?? 0,
        ));
      }
    }
    return points;
  }

  void _initializeMinMaxValues() {
    if (data.isEmpty) return;

    lpmMin = data.map((e) => e.lpm).reduce((a, b) => a < b ? a : b);
    lpmMax = data.map((e) => e.lpm).reduce((a, b) => a > b ? a : b);
    rpmMin = data.map((e) => e.rpm).reduce((a, b) => a < b ? a : b);
    rpmMax = data.map((e) => e.rpm).reduce((a, b) => a > b ? a : b);
    literMin = data.map((e) => e.liter).reduce((a, b) => a < b ? a : b);
    literMax = data.map((e) => e.liter).reduce((a, b) => a > b ? a : b);

    // Đảm bảo min != max để tránh division by zero
    if (lpmMin == lpmMax) lpmMax = lpmMin + 1;
    if (rpmMin == rpmMax) rpmMax = rpmMin + 1;
    if (literMin == literMax) literMax = literMin + 1;
  }

  List<DataPoint> _getScrolledData() {
    if (data.isEmpty) return data;

    // Mặc định hiển thị toàn bộ thời gian từ min TIME tới max TIME
    return data;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset(
              'logo.jpg',
              height: 40,
              width: 40,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 12),
            const Text('Biểu Đồ DVL'),
          ],
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton(
                  onPressed: pickFile,
                  child: const Text('Chọn Tệp Dữ Liệu'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: data.isNotEmpty
                      ? () {
                          setState(() {
                            showSettings = !showSettings;
                          });
                        }
                      : null,
                  child: Text(showSettings ? 'Ẩn Cài Đặt' : 'Hiện Cài Đặt'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: data.isNotEmpty
                      ? () {
                          setState(() {
                            showTimeControls = !showTimeControls;
                          });
                        }
                      : null,
                  child: Text(showTimeControls ? 'Ẩn TIME' : 'Co/Giãn TIME'),
                ),
              ],
            ),
            if (fileName != null) Text('Tệp đã chọn: $fileName'),
            if (showSettings) _buildSettingsPanel(),
            if (showTimeControls && data.isNotEmpty) _buildTimeControlsPanel(),
            const SizedBox(height: 16),
            Expanded(
              child: data.isEmpty
                  ? const Center(
                      child: Text(
                          'Chưa có dữ liệu. Vui lòng chọn tệp để hiển thị biểu đồ.'))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Bảng dữ liệu bên trái
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Bảng Dữ Liệu (${data.length} dòng):',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: buildDataTable(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Đồ thị bên phải
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Biểu Đồ Dữ Liệu:',
                                  style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Expanded(child: buildChart()),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Cài Đặt Biểu Đồ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              // LPM Settings
              Expanded(
                  child: _buildSingleLineSettings(
                      'LPM',
                      lpmColor,
                      lpmMin,
                      lpmMax,
                      lpmLineWidth,
                      (color) => setState(() => lpmColor = color),
                      (min) => setState(() => lpmMin = min),
                      (max) => setState(() => lpmMax = max),
                      (width) => setState(() => lpmLineWidth = width))),
              const SizedBox(width: 16),
              // RPM Settings
              Expanded(
                  child: _buildSingleLineSettings(
                      'RPM',
                      rpmColor,
                      rpmMin,
                      rpmMax,
                      rpmLineWidth,
                      (color) => setState(() => rpmColor = color),
                      (min) => setState(() => rpmMin = min),
                      (max) => setState(() => rpmMax = max),
                      (width) => setState(() => rpmLineWidth = width))),
              const SizedBox(width: 16),
              // LÍT Settings
              Expanded(
                  child: _buildSingleLineSettings(
                      'LÍT',
                      literColor,
                      literMin,
                      literMax,
                      literLineWidth,
                      (color) => setState(() => literColor = color),
                      (min) => setState(() => literMin = min),
                      (max) => setState(() => literMax = max),
                      (width) => setState(() => literLineWidth = width))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeControlsPanel() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.orange.shade300),
        borderRadius: BorderRadius.circular(8),
        color: Colors.orange.shade50,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Co/Giãn Trục Thời Gian',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              // Time Scale Slider
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Tỷ lệ TIME: ${timeScale.toStringAsFixed(1)}x',
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Slider(
                      value: timeScale,
                      min: timeScaleMin,
                      max: timeScaleMax,
                      divisions: ((timeScaleMax - timeScaleMin) * 10).round(),
                      onChanged: (value) {
                        setState(() {
                          timeScale = value;
                        });
                      },
                      label: '${timeScale.toStringAsFixed(1)}x',
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Co ${timeScaleMin.toStringAsFixed(1)}x',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade600)),
                        Text('Bình thường 1.0x',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade600)),
                        Text('Giãn ${timeScaleMax.toStringAsFixed(1)}x',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade600)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              // Quick buttons
              Expanded(
                flex: 2,
                child: Column(
                  children: [
                    const Text('Nhanh:',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickScaleButton('0.5x', 0.5),
                        _buildQuickScaleButton('1.0x', 1.0),
                        _buildQuickScaleButton('2.0x', 2.0),
                        _buildQuickScaleButton('3.0x', 3.0),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Viewport info
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade100,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thông tin hiển thị:',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange.shade800)),
                const SizedBox(height: 4),
                Text('• Hiển thị: Toàn thời gian (${data.length} điểm dữ liệu)',
                    style:
                        TextStyle(fontSize: 11, color: Colors.orange.shade700)),
                Text(
                    '• Tỷ lệ co/giãn: ${timeScale < 1 ? "Co ${(1 / timeScale).toStringAsFixed(1)} lần" : timeScale > 1 ? "Giãn ${timeScale.toStringAsFixed(1)} lần" : "Bình thường"}',
                    style:
                        TextStyle(fontSize: 11, color: Colors.orange.shade700)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickScaleButton(String label, double scale) {
    bool isSelected = (timeScale - scale).abs() < 0.01;
    return ElevatedButton(
      onPressed: () {
        setState(() {
          timeScale = scale;
        });
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.orange : Colors.orange.shade100,
        foregroundColor: isSelected ? Colors.white : Colors.orange.shade800,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        minimumSize: Size.zero,
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Widget _buildSingleLineSettings(
      String title,
      Color currentColor,
      double currentMin,
      double currentMax,
      double currentWidth,
      Function(Color) onColorChanged,
      Function(double) onMinChanged,
      Function(double) onMaxChanged,
      Function(double) onWidthChanged) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: currentColor.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(6),
        color: currentColor.withOpacity(0.05),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: currentColor)),
          const SizedBox(height: 8),

          // Color picker
          Row(
            children: [
              const Text('Màu sắc: ', style: TextStyle(fontSize: 12)),
              GestureDetector(
                onTap: () => _showColorPicker(currentColor, onColorChanged),
                child: Container(
                  width: 30,
                  height: 20,
                  decoration: BoxDecoration(
                    color: currentColor,
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Min value
          Row(
            children: [
              const Expanded(
                  flex: 2,
                  child: Text('Tối thiểu:', style: TextStyle(fontSize: 12))),
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: currentMin.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    final newMin = double.tryParse(value);
                    if (newMin != null) onMinChanged(newMin);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Max value
          Row(
            children: [
              const Expanded(
                  flex: 2,
                  child: Text('Tối đa:', style: TextStyle(fontSize: 12))),
              Expanded(
                flex: 3,
                child: TextFormField(
                  initialValue: currentMax.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 12),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    final newMax = double.tryParse(value);
                    if (newMax != null) onMaxChanged(newMax);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Line width
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Độ dày đường: ${currentWidth.toStringAsFixed(1)}',
                  style: const TextStyle(fontSize: 12)),
              Slider(
                value: currentWidth,
                min: 1,
                max: 10,
                divisions: 18,
                onChanged: onWidthChanged,
                activeColor: currentColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showColorPicker(Color currentColor, Function(Color) onColorChanged) {
    final colors = [
      Colors.blue,
      Colors.red,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.cyan,
      Colors.pink,
      Colors.amber,
      Colors.teal,
      Colors.indigo,
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Chọn Màu Sắc'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors
              .map((color) => GestureDetector(
                    onTap: () {
                      onColorChanged(color);
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color == currentColor
                              ? Colors.black
                              : Colors.grey,
                          width: color == currentColor ? 3 : 1,
                        ),
                      ),
                    ),
                  ))
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  Widget buildDataTable() {
    // Hiển thị tất cả dữ liệu thay vì chỉ 10 dòng đầu
    final displayData = data;
    return SingleChildScrollView(
      child: DataTable(
        columnSpacing: 20,
        columns: const [
          DataColumn(
              label: Text('THỜI GIAN',
                  style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label:
                  Text('LPM', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label:
                  Text('RPM', style: TextStyle(fontWeight: FontWeight.bold))),
          DataColumn(
              label:
                  Text('LÍT', style: TextStyle(fontWeight: FontWeight.bold))),
        ],
        rows: displayData.map((point) {
          return DataRow(cells: [
            DataCell(Text(point.time)),
            DataCell(Text(point.lpm.toStringAsFixed(1))),
            DataCell(Text(point.rpm.toStringAsFixed(1))),
            DataCell(Text(point.liter.toStringAsFixed(1))),
          ]);
        }).toList(),
      ),
    );
  }

  Widget buildChart() {
    if (data.isEmpty) return const SizedBox();

    // Sử dụng dữ liệu đã scroll
    List<DataPoint> displayData = _getScrolledData();

    return Column(
      children: [
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildLegendItem('LPM', lpmColor,
                '${lpmMin.toStringAsFixed(1)} - ${lpmMax.toStringAsFixed(1)}'),
            _buildLegendItem('RPM', rpmColor,
                '${rpmMin.toStringAsFixed(1)} - ${rpmMax.toStringAsFixed(1)}'),
            _buildLegendItem('LÍT', literColor,
                '${literMin.toStringAsFixed(1)} - ${literMax.toStringAsFixed(1)}'),
          ],
        ),
        const SizedBox(height: 8),
        // 3 đồ thị riêng biệt với scale phù hợp - hiển thị toàn thời gian
        Expanded(
          child: Row(
            children: [
              // Đồ thị LPM
              Expanded(
                child: _buildSingleChart(
                    'LPM',
                    lpmColor,
                    displayData.map((e) => e.lpm).toList(),
                    lpmMin,
                    lpmMax,
                    lpmLineWidth,
                    displayData),
              ),
              const SizedBox(width: 8),
              // Đồ thị RPM
              Expanded(
                child: _buildSingleChart(
                    'RPM',
                    rpmColor,
                    displayData.map((e) => e.rpm).toList(),
                    rpmMin,
                    rpmMax,
                    rpmLineWidth,
                    displayData),
              ),
              const SizedBox(width: 8),
              // Đồ thị LÍT
              Expanded(
                child: _buildSingleChart(
                    'LÍT',
                    literColor,
                    displayData.map((e) => e.liter).toList(),
                    literMin,
                    literMax,
                    literLineWidth,
                    displayData),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSingleChart(
      String title,
      Color color,
      List<double> values,
      double minValue,
      double maxValue,
      double lineWidth,
      List<DataPoint> displayData) {
    List<FlSpot> spots = [];

    // Debug: In ra màu để kiểm tra
    print('$title - Color: $color, Min: $minValue, Max: $maxValue');

    for (int i = 0; i < values.length; i++) {
      // Y = thời gian (đảo ngược để thời gian từ trên xuống tăng dần)
      // X = giá trị của loại dữ liệu này
      double yPos = (values.length - 1 - i).toDouble();
      spots.add(FlSpot(values[i], yPos));
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 12, color: color)),
          const SizedBox(height: 4),
          Expanded(
            child: LineChart(
              LineChartData(
                // X axis: Giá trị của loại dữ liệu này với scale phù hợp
                minX: minValue == maxValue
                    ? minValue - 1
                    : minValue * 0.9, // Trừ 10% để có khoảng trống
                maxX: minValue == maxValue
                    ? maxValue + 1
                    : maxValue * 1.1, // Cộng 10% để có khoảng trống
                // Y axis: Time (từ trên xuống)
                minY: 0,
                maxY: (displayData.length - 1).toDouble(),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: true,
                  drawHorizontalLine: true,
                  horizontalInterval: displayData.length > 10
                      ? (displayData.length / 5).floorToDouble()
                      : 1,
                  verticalInterval: (maxValue - minValue) / 5,
                  getDrawingHorizontalLine: (value) {
                    return FlLine(
                        color: Colors.grey.shade300, strokeWidth: 0.5);
                  },
                  getDrawingVerticalLine: (value) {
                    return FlLine(
                        color: Colors.grey.shade300, strokeWidth: 0.5);
                  },
                ),
                titlesData: FlTitlesData(
                  // X axis: Values với scale riêng
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 25,
                      interval: (maxValue - minValue) / 3,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(0),
                          style: const TextStyle(fontSize: 8),
                        );
                      },
                    ),
                  ),
                  // Y axis: Time (chỉ hiển thị ở đồ thị đầu tiên)
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: title == 'LPM', // Chỉ hiển thị ở đồ thị LPM
                      reservedSize: title == 'LPM' ? 60 : 0,
                      interval: displayData.length > 10
                          ? (displayData.length / 3).floorToDouble()
                          : 1,
                      getTitlesWidget: (value, meta) {
                        if (title != 'LPM') return const SizedBox.shrink();

                        int yIndex = value.toInt();
                        int dataIndex = displayData.length - 1 - yIndex;
                        if (dataIndex >= 0 && dataIndex < displayData.length) {
                          return Text(
                            displayData[dataIndex].time,
                            style: const TextStyle(fontSize: 8),
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(
                  show: true,
                  border: Border.all(color: Colors.grey.shade400, width: 1),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: false,
                    color: color,
                    barWidth: lineWidth,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: false,
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  // Tắt đường dọc xuống trục X
                  getTouchedSpotIndicator:
                      (LineChartBarData barData, List<int> spotIndexes) {
                    return spotIndexes.map((spotIndex) {
                      return TouchedSpotIndicatorData(
                        // Tắt đường dọc bằng cách đặt strokeWidth = 0
                        FlLine(strokeWidth: 0, color: Colors.transparent),
                        // Hiển thị chấm tròn
                        FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: color,
                              strokeWidth: 2,
                              strokeColor: Colors.white,
                            );
                          },
                        ),
                      );
                    }).toList();
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots
                          .map((LineBarSpot touchedSpot) {
                            int dataIndex = touchedSpot.y.toInt();
                            int realDataIndex =
                                displayData.length - 1 - dataIndex;
                            if (realDataIndex >= 0 &&
                                realDataIndex < displayData.length) {
                              double xValue = touchedSpot.x;
                              return LineTooltipItem(
                                '$title: ${xValue.toStringAsFixed(1)}\n${displayData[realDataIndex].time}',
                                TextStyle(
                                    color:
                                        const Color.fromARGB(255, 49, 20, 20),
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10),
                              );
                            }
                            return null;
                          })
                          .where((item) => item != null)
                          .cast<LineTooltipItem>()
                          .toList();
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, String range) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 16,
              height: 3,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        Text(range, style: const TextStyle(fontSize: 10, color: Colors.grey)),
      ],
    );
  }
}
