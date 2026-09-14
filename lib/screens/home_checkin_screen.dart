import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:link_mobile/models/task_model.dart';
import 'package:link_mobile/services/api_service.dart';
import 'package:link_mobile/screens/task_detail_screen.dart';

class HomeCheckinScreen extends StatefulWidget {
  final VoidCallback? onNavigateToTasks;

  const HomeCheckinScreen({super.key, this.onNavigateToTasks});

  @override
  State<HomeCheckinScreen> createState() => _HomeCheckinScreenState();
}

class _HomeCheckinScreenState extends State<HomeCheckinScreen> {
  final ApiService _api = ApiService();
  bool _isLoading = true;
  bool _isCheckingIn = false;
  bool _isOnShift = false;
  Position? _currentPosition;
  String _gpsStatus = 'Определение координат...';
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();
  List<TaskItem> _tasks = [];
  String _selectedMonth = 'Сентябрь';

  @override
  void initState() {
    super.initState();
    _startLiveClock();
    _loadData();
    _fetchGpsLocation();
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _startLiveClock() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  Future<void> _fetchGpsLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _gpsStatus = 'Доступ к GPS отключен';
          });
        }
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );

      if (mounted) {
        setState(() {
          _currentPosition = position;
          _gpsStatus =
              '${position.latitude.toStringAsFixed(4)}, ${position.longitude.toStringAsFixed(4)} (Офис)';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _gpsStatus = 'GPS: 43.2389, 76.8897 (Алматы)';
        });
      }
    }
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final history = await _api.getCheckinHistory(limit: 5);
    final tasksList = await _api.getTasks();

    if (mounted) {
      setState(() {
        _tasks = tasksList;
        if (history.isNotEmpty) {
          _isOnShift = history.first['log_type'] == 'IN';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _performCheckin() async {
    setState(() => _isCheckingIn = true);

    try {
      final double lat = _currentPosition?.latitude ?? 43.238944;
      final double lon = _currentPosition?.longitude ?? 76.889709;
      final targetLogType = _isOnShift ? 'OUT' : 'IN';

      await _api.submitCheckin(
        logType: targetLogType,
        latitude: lat,
        longitude: lon,
      );

      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF4EBE71),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(CupertinoIcons.checkmark_circle_fill, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Text(
                  targetLogType == 'IN'
                      ? 'Успешная отметка прихода на смену'
                      : 'Смена закрыта. До встречи!',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red.shade700,
            content: Text(e.toString().replaceAll('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final emp = _api.currentEmployee;
    final empName = emp?['employee_name'] ?? 'Серик Ахметов';

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FC),
      body: SafeArea(
        child: RefreshIndicator(
          color: const Color(0xFF7052BA),
          onRefresh: () async {
            await _fetchGpsLocation();
            await _loadData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Header: User Avatar + Search + Notification Bell
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF7052BA).withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  '👨🏻‍💼',
                                  style: TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: _isOnShift
                                      ? const Color(0xFF4EBE71)
                                      : const Color(0xFF94A3B8),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              empName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const Text(
                              'Специалист HR • Link KZ',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        _buildCircleIconButton(
                          icon: CupertinoIcons.search,
                          onTap: () {},
                        ),
                        const SizedBox(width: 10),
                        Stack(
                          children: [
                            _buildCircleIconButton(
                              icon: CupertinoIcons.bell,
                              onTap: () {},
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFEF4444),
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 22),

                // 2. Title Section
                const Text(
                  'Monitor Current\nPerformance',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.8,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Manage your task & attendance',
                  style: TextStyle(
                    fontSize: 14,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),

                // 3. Quick Action: GPS Check-in Widget (Fast 1-tap attend)
                _buildQuickCheckinCard(),
                const SizedBox(height: 20),

                // 4. "My Activity" Card (Pixel-Perfect from Reference)
                _buildMyActivityCard(),
                const SizedBox(height: 24),

                // 5. "Task list" Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Task list',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    if (widget.onNavigateToTasks != null)
                      InkWell(
                        onTap: widget.onNavigateToTasks,
                        child: const Padding(
                          padding: EdgeInsets.all(4.0),
                          child: Text(
                            'See all',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF7052BA),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_isLoading)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: CupertinoActivityIndicator(radius: 12),
                    ),
                  )
                else
                  Column(
                    children: _tasks.take(3).map((task) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: _buildTaskCard(task),
                      );
                    }).toList(),
                  ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCircleIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFEFF2F6), width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: const Color(0xFF0F172A),
          size: 18,
        ),
      ),
    );
  }

  Widget _buildQuickCheckinCard() {
    final timeStr =
        "${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}";

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEFF2F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isOnShift
                            ? const Color(0xFF4EBE71).withValues(alpha: 0.12)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _isOnShift
                                  ? const Color(0xFF4EBE71)
                                  : const Color(0xFF64748B),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _isOnShift ? 'На смене' : 'Смена закрыта',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _isOnShift
                                  ? const Color(0xFF4EBE71)
                                  : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(CupertinoIcons.location_fill, size: 12, color: Color(0xFF7052BA)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        _gpsStatus,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _isCheckingIn ? null : _performCheckin,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  _isOnShift ? const Color(0xFFEF4444) : const Color(0xFF4EBE71),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
            child: _isCheckingIn
                ? const CupertinoActivityIndicator(color: Colors.white, radius: 10)
                : Text(
                    _isOnShift ? 'Уход' : 'Чекин',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildMyActivityCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFEFF2F6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header: "My Activity" + Month selector
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Activity',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                  letterSpacing: -0.3,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (val) {
                  setState(() {
                    _selectedMonth = val;
                  });
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                itemBuilder: (ctx) => [
                  'Январь',
                  'Февраль',
                  'Март',
                  'Апрель',
                  'Май',
                  'Июнь',
                  'Июль',
                  'Август',
                  'Сентябрь',
                  'Октябрь',
                  'Ноябрь',
                  'Декабрь'
                ].map((m) => PopupMenuItem(value: m, child: Text(m))).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _selectedMonth,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        CupertinoIcons.chevron_down,
                        size: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Weekdays header: Su Mo Tu We Th Fr Sa
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: const [
              _WeekdayLabel('Su'),
              _WeekdayLabel('Mo'),
              _WeekdayLabel('Tu'),
              _WeekdayLabel('We'),
              _WeekdayLabel('Th'),
              _WeekdayLabel('Fr'),
              _WeekdayLabel('Sa'),
            ],
          ),
          const SizedBox(height: 14),

          // Calendar Grid (exact recreation of reference calendar dots)
          // Row 1: faint faint 1 2 [3:purple] 4 5
          _buildCalendarRow([
            const _DayCircle(isInactivePattern: true),
            const _DayCircle(isInactivePattern: true),
            const _DayCircle(dayText: '1'),
            const _DayCircle(dayText: '2'),
            const _DayCircle(dayText: '3', circleColor: Color(0xFF7052BA), isHighlighted: true),
            const _DayCircle(dayText: '4'),
            const _DayCircle(dayText: '5'),
          ]),
          const SizedBox(height: 10),

          // Row 2: 6 [7:green] 8 [9:purple] 10 [11:green] [12:green]
          _buildCalendarRow([
            const _DayCircle(dayText: '6'),
            const _DayCircle(dayText: '7', circleColor: Color(0xFF4EBE71), isHighlighted: true),
            const _DayCircle(dayText: '8'),
            const _DayCircle(dayText: '9', circleColor: Color(0xFF7052BA), isHighlighted: true),
            const _DayCircle(dayText: '10'),
            const _DayCircle(dayText: '11', circleColor: Color(0xFF4EBE71), isHighlighted: true),
            const _DayCircle(dayText: '12', circleColor: Color(0xFF4EBE71), isHighlighted: true),
          ]),
          const SizedBox(height: 10),

          // Row 3: [13:purple] 14 [15:purple] 16 [17:purple] 18 [19:purple]
          _buildCalendarRow([
            const _DayCircle(dayText: '13', circleColor: Color(0xFF7052BA), isHighlighted: true),
            const _DayCircle(dayText: '14'),
            const _DayCircle(dayText: '15', circleColor: Color(0xFF7052BA), isHighlighted: true),
            const _DayCircle(dayText: '16'),
            const _DayCircle(dayText: '17', circleColor: Color(0xFF7052BA), isHighlighted: true),
            const _DayCircle(dayText: '18'),
            const _DayCircle(dayText: '19', circleColor: Color(0xFF7052BA), isHighlighted: true),
          ]),
          const SizedBox(height: 10),

          // Row 4: 20 [21:green] 22 [23:dark] [24:dark] 25 26
          _buildCalendarRow([
            const _DayCircle(dayText: '20'),
            const _DayCircle(dayText: '21', circleColor: Color(0xFF4EBE71), isHighlighted: true),
            const _DayCircle(dayText: '22'),
            const _DayCircle(dayText: '23', circleColor: Color(0xFF1E1E2D), isHighlighted: true),
            const _DayCircle(dayText: '24', circleColor: Color(0xFF1E1E2D), isHighlighted: true),
            const _DayCircle(dayText: '25'),
            const _DayCircle(dayText: '26'),
          ]),
          const SizedBox(height: 10),

          // Row 5: [27:green] 28 [29:purple] faint faint faint faint
          _buildCalendarRow([
            const _DayCircle(dayText: '27', circleColor: Color(0xFF4EBE71), isHighlighted: true),
            const _DayCircle(dayText: '28'),
            const _DayCircle(dayText: '29', circleColor: Color(0xFF7052BA), isHighlighted: true),
            const _DayCircle(isInactivePattern: true),
            const _DayCircle(isInactivePattern: true),
            const _DayCircle(isInactivePattern: true),
            const _DayCircle(isInactivePattern: true),
          ]),
          const SizedBox(height: 20),

          // Legend row: ● Completed  ● In Progress  ● On Hold
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _LegendDot(color: Color(0xFF4EBE71), label: 'Completed'),
              SizedBox(width: 16),
              _LegendDot(color: Color(0xFF6558F5), label: 'In Progress'),
              SizedBox(width: 16),
              _LegendDot(color: Color(0xFF1E1E2D), label: 'On Hold'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarRow(List<Widget> children) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: children,
    );
  }

  Widget _buildTaskCard(TaskItem task) {
    Color statusBg;
    switch (task.status) {
      case 'Completed':
        statusBg = const Color(0xFF4EBE71);
        break;
      case 'In Progress':
        statusBg = const Color(0xFF6558F5);
        break;
      case 'On Hold':
        statusBg = const Color(0xFF7052BA);
        break;
      default:
        statusBg = const Color(0xFFE2E8F0);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TaskDetailScreen(
              task: task,
              onTaskUpdated: _loadData,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFEFF2F6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              task.date,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAvatars(task.assignees.length),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    task.status,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatars(int total) {
    return Row(
      children: [
        SizedBox(
          height: 24,
          width: 48,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                child: _avatarMini(const Color(0xFFFDE047), 'D'),
              ),
              Positioned(
                left: 12,
                child: _avatarMini(const Color(0xFFF472B6), 'G'),
              ),
              Positioned(
                left: 24,
                child: _avatarMini(const Color(0xFF60A5FA), 'P'),
              ),
            ],
          ),
        ),
        if (total > 2) ...[
          const SizedBox(width: 4),
          Text(
            '+$total',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ],
    );
  }

  Widget _avatarMini(Color color, String text) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 34,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }
}

class _DayCircle extends StatelessWidget {
  final String? dayText;
  final Color? circleColor;
  final bool isHighlighted;
  final bool isInactivePattern;

  const _DayCircle({
    this.dayText,
    this.circleColor,
    this.isHighlighted = false,
    this.isInactivePattern = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isInactivePattern) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: const Color(0xFFF1F4F9).withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: CustomPaint(
          painter: _StripedCirclePainter(),
        ),
      );
    }

    if (isHighlighted && circleColor != null) {
      return Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: circleColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: circleColor!.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            dayText ?? '',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        color: Color(0xFFF8FAFC),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          dayText ?? '',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF1E293B),
          ),
        ),
      ),
    );
  }
}

class _StripedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    canvas.clipPath(Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height)));

    for (double i = -size.width; i < size.width * 2; i += 6) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}
