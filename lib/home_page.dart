import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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

  // Simple zoom functionality - sử dụng window-based zoom thay vì sampling
  int timeZoomLevel = 3; // Zoom level (1-5): 1=zoomed out, 5=zoomed in
  double zoomCenterRatio = 0.5; // Điểm trung tâm zoom (0.0 - 1.0)

  // Time scrolling functionality
  double timeScrollPosition =
      1.0; // Vị trí cuộn TIME (1.0=đầu, 0.0=cuối) - đã đảo ngược

  // Throttling cho mouse wheel
  DateTime? _lastZoomTime;
  static const Duration _zoomThrottleDuration = Duration(milliseconds: 100);

  // Cache cho dữ liệu zoom để tránh tính toán lại liên tục
  List<DataPoint>? _cachedZoomedData;
  int? _cachedZoomLevel;
  double? _cachedScrollPosition;
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
        // Xóa cache khi load dữ liệu mới
        _cachedZoomedData = null;
        _cachedZoomLevel = null;
        _cachedScrollPosition = null;
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

    // Áp dụng zoom đơn giản - lọc dữ liệu theo mức zoom
    return _getZoomedData();
  }

  // Lọc dữ liệu theo zoom level với window-based zoom (mượt hơn)
  List<DataPoint> _getZoomedData() {
    if (data.isEmpty) return data;

    // Kiểm tra cache để tránh tính toán lại
    if (_cachedZoomLevel == timeZoomLevel &&
        _cachedScrollPosition == timeScrollPosition &&
        _cachedZoomedData != null) {
      return _cachedZoomedData!;
    }

    // Tính tỷ lệ zoom: Level càng cao = window càng nhỏ = zoom in càng nhiều
    double zoomRatio;
    switch (timeZoomLevel) {
      case 1:
        zoomRatio = 1.0;
        break; // Zoom OUT: hiện tất cả
      case 2:
        zoomRatio = 0.7;
        break; // Zoom OUT: hiện 70%
      case 3:
        zoomRatio = 0.5;
        break; // Trung bình: hiện 50%
      case 4:
        zoomRatio = 0.3;
        break; // Zoom IN: hiện 30%
      case 5:
        zoomRatio = 0.15;
        break; // Zoom IN nhiều nhất: hiện 15%
      default:
        zoomRatio = 0.5;
    }

    List<DataPoint> result;

    // Nếu zoom out hoàn toàn thì hiện tất cả
    if (zoomRatio >= 1.0) {
      result = data;
    } else {
      // Tính window size dựa trên zoom ratio
      int windowSize = (data.length * zoomRatio).ceil();
      if (windowSize >= data.length) {
        result = data;
      } else {
        // Tính vị trí bắt đầu dựa trên time scroll position
        // timeScrollPosition: 1.0 = đầu dữ liệu, 0.0 = cuối dữ liệu
        int startIndex =
            ((data.length - windowSize) * (1.0 - timeScrollPosition)).round();
        startIndex = startIndex.clamp(0, data.length - windowSize);

        int endIndex = (startIndex + windowSize).clamp(0, data.length);

        // Trả về dữ liệu trong window (liên tục, không nhảy cóc)
        result = data.sublist(startIndex, endIndex);
      }
    }

    // Cache kết quả
    _cachedZoomLevel = timeZoomLevel;
    _cachedScrollPosition = timeScrollPosition;
    _cachedZoomedData = result;

    return result;
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
              ],
            ),
            if (fileName != null) Text('Tệp đã chọn: $fileName'),
            if (showSettings) _buildSettingsPanel(),
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

  // Zoom helper functions với throttling
  void _zoomIn() {
    final now = DateTime.now();
    if (_lastZoomTime != null &&
        now.difference(_lastZoomTime!) < _zoomThrottleDuration) {
      return; // Throttle - bỏ qua nếu zoom quá nhanh
    }
    _lastZoomTime = now;

    if (timeZoomLevel < 5) {
      setState(() {
        timeZoomLevel++;
      });
    }
  }

  void _zoomOut() {
    final now = DateTime.now();
    if (_lastZoomTime != null &&
        now.difference(_lastZoomTime!) < _zoomThrottleDuration) {
      return; // Throttle - bỏ qua nếu zoom quá nhanh
    }
    _lastZoomTime = now;

    if (timeZoomLevel > 1) {
      setState(() {
        timeZoomLevel--;
      });
    }
  }

  Widget _buildVerticalTimeScrollControl() {
    if (data.isEmpty) return const SizedBox();

    // Tính toán thông tin hiển thị
    List<DataPoint> displayData = _getScrolledData();
    double zoomRatio = displayData.length / data.length;

    return Container(
      width: 120,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        border: Border.all(color: Colors.blue.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          // Header
          Text(
            'TIME',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.blue.shade800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Zoom: $timeZoomLevel',
            style: TextStyle(
              fontSize: 10,
              color: Colors.blue.shade600,
            ),
          ),
          Text(
            '${(zoomRatio * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 10,
              color: Colors.blue.shade600,
            ),
          ),
          const SizedBox(height: 8),

          // Nút cuộn về đầu (thời gian sớm nhất)
          SizedBox(
            width: double.infinity,
            height: 28,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  timeScrollPosition = 1.0; // Đảo ngược: 1.0 = đầu dữ liệu
                  _cachedZoomedData = null;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.blue.shade800,
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.first_page, size: 16),
            ),
          ),
          const SizedBox(height: 4),

          // Thanh cuộn dọc chính với labels
          Expanded(
            child: Column(
              children: [
                // Label "Đầu"
                Text(
                  'Đầu',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.blue.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                // Slider dọc
                Expanded(
                  child: RotatedBox(
                    quarterTurns: 3, // Xoay slider 270 độ để thành dọc
                    child: Slider(
                      value: timeScrollPosition,
                      min: 0.0,
                      max: 1.0,
                      divisions: 20,
                      activeColor: Colors.blue.shade600,
                      inactiveColor: Colors.blue.shade200,
                      onChanged: (value) {
                        setState(() {
                          timeScrollPosition = value;
                          _cachedZoomedData = null;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Label "Cuối"
                Text(
                  'Cuối',
                  style: TextStyle(
                    fontSize: 8,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),
          // Nút cuộn về cuối (thời gian muộn nhất)
          SizedBox(
            width: double.infinity,
            height: 28,
            child: ElevatedButton(
              onPressed: () {
                setState(() {
                  timeScrollPosition = 0.0; // Đảo ngược: 0.0 = cuối dữ liệu
                  _cachedZoomedData = null;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade100,
                foregroundColor: Colors.blue.shade800,
                padding: EdgeInsets.zero,
              ),
              child: const Icon(Icons.last_page, size: 16),
            ),
          ),

          const SizedBox(height: 8),
          // Thông tin thời gian
          if (displayData.isNotEmpty) ...[
            Text(
              displayData.first.time.substring(0, 8), // Chỉ lấy HH:MM:SS
              style: TextStyle(
                fontSize: 9,
                color: Colors.blue.shade600,
              ),
            ),
            const Icon(Icons.more_vert, size: 12, color: Colors.grey),
            Text(
              displayData.last.time.substring(0, 8), // Chỉ lấy HH:MM:SS
              style: TextStyle(
                fontSize: 9,
                color: Colors.blue.shade600,
              ),
            ),
          ],
        ],
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
        // 3 đồ thị riêng biệt với scale phù hợp - Zoom bằng chuột
        // Layout mới: Biểu đồ + Thanh cuộn TIME bên phải
        Expanded(
          child: Row(
            children: [
              // Phần biểu đồ chính
              Expanded(
                child: Listener(
                  onPointerSignal: (pointerSignal) {
                    if (pointerSignal is PointerScrollEvent) {
                      // Zoom trực tiếp bằng chuột wheel
                      if (pointerSignal.scrollDelta.dy < 0) {
                        // Scroll up = Zoom In
                        _zoomIn();
                      } else {
                        // Scroll down = Zoom Out
                        _zoomOut();
                      }
                    }
                  },
                  child: Row(
                    children: [
                      // Đồ thị LPM
                      Expanded(
                        key: const ValueKey('lpm_chart'),
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
                        key: const ValueKey('rpm_chart'),
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
                        key: const ValueKey('liter_chart'),
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
              ),
              const SizedBox(width: 8),
              // Thanh cuộn TIME dọc bên phải
              _buildVerticalTimeScrollControl(),
            ],
          ),
        ),
      ],
    );
  }

  // Function tính toán smart interval cho vertical grid
  double _calculateSmartInterval(double maxValue, double minValue) {
    double range = maxValue - minValue;

    if (range == 0) return 1; // Tránh chia cho 0

    // Chọn interval dựa trên độ lớn của dữ liệu
    if (range <= 10) return 1; // 1, 2, 3...
    if (range <= 50) return 5; // 5, 10, 15...
    if (range <= 100) return 10; // 10, 20, 30...
    if (range <= 500) return 50; // 50, 100, 150...
    if (range <= 1000) return 100; // 100, 200, 300...
    if (range <= 5000) return 500; // 500, 1000, 1500...
    if (range <= 10000) return 1000; // 1000, 2000, 3000...
    if (range <= 50000) return 5000; // 5000, 10000, 15000...
    if (range <= 100000) return 10000; // 10000, 20000, 30000...

    // Với dữ liệu rất lớn, chia thành khoảng 5-8 phần
    return (range / 6).roundToDouble();
  }

  Widget _buildSingleChart(
      String title,
      Color color,
      List<double> values,
      double minValue,
      double maxValue,
      double lineWidth,
      List<DataPoint> displayData) {
    // Tối ưu: cache spots để tránh tính toán lại liên tục
    List<FlSpot> spots = List.generate(values.length, (i) {
      double yPos = (values.length - 1 - i).toDouble();
      return FlSpot(values[i], yPos);
    });

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
                  verticalInterval: _calculateSmartInterval(maxValue, minValue),
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
                      // Sử dụng cùng interval với horizontal grid để căn chỉnh
                      interval: displayData.length > 10
                          ? (displayData.length / 5).floorToDouble()
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
