import 'package:flutter/material.dart';
import 'course_selection_service.dart';

void main() {
  runApp(const RetryCourseSelectorApp());
}

class RetryCourseSelectorApp extends StatelessWidget {
  const RetryCourseSelectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HUST专选抢课',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const RetryCourseSelectorPage(),
    );
  }
}

class RetryCourse {
  final String name;
  final String teacher;
  bool isSelected;
  String? status;
  int retryCount;
  bool isRetrying;
  DateTime? lastRetryTime;

  RetryCourse({
    required this.name,
    required this.teacher,
    this.isSelected = false,
    this.status,
    this.retryCount = 0,
    this.isRetrying = false,
    this.lastRetryTime,
  });
}

class RetryConfig {
  final int maxRetries;
  final int retryIntervalSeconds;

  const RetryConfig({
    this.maxRetries = 3,
    this.retryIntervalSeconds = 5,
  });
}

class RetryCourseSelectorPage extends StatefulWidget {
  const RetryCourseSelectorPage({super.key});

  @override
  State<RetryCourseSelectorPage> createState() => _RetryCourseSelectorPageState();
}

class _RetryCourseSelectorPageState extends State<RetryCourseSelectorPage> {
  final TextEditingController _cookieController = TextEditingController(
    text: '打开浏览器找一下'
  );
  final TextEditingController _uaController = TextEditingController(
    text: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36'
  );
  final TextEditingController _courseNameController = TextEditingController();
  final TextEditingController _teacherNameController = TextEditingController();
  final TextEditingController _retryCountController = TextEditingController(text: '3');
  final TextEditingController _retryIntervalController = TextEditingController(text: '5');

  List<RetryCourse> targetCourses = [
    RetryCourse(name: "大数据管理概论", teacher: "左琼"),
    RetryCourse(name: "函数式编程原理", teacher: "郑然"),
    RetryCourse(name: "计算机图形学", teacher: "何云峰"),
    RetryCourse(name: "计算机视觉导论", teacher: "刘康"),
  ];

  RetryConfig retryConfig = const RetryConfig();
  bool isLoading = false;
  bool isRetryingAll = false;
  String statusMessage = '';
  int progress = 0;
  int total = 0;

  @override
  void dispose() {
    _cookieController.dispose();
    _uaController.dispose();
    _courseNameController.dispose();
    _teacherNameController.dispose();
    _retryCountController.dispose();
    _retryIntervalController.dispose();
    super.dispose();
  }

  void _addTargetCourse() {
    if (_courseNameController.text.isNotEmpty && _teacherNameController.text.isNotEmpty) {
      setState(() {
        targetCourses.add(RetryCourse(
          name: _courseNameController.text,
          teacher: _teacherNameController.text,
        ));
        _courseNameController.clear();
        _teacherNameController.clear();
      });
    }
  }

  void _removeTargetCourse(int index) {
    setState(() {
      targetCourses.removeAt(index);
    });
  }

  void _updateRetryConfig() {
    setState(() {
      retryConfig = RetryConfig(
        maxRetries: int.tryParse(_retryCountController.text) ?? 3,
        retryIntervalSeconds: int.tryParse(_retryIntervalController.text) ?? 5,
      );
    });
  }

  Future<void> _retrySingleCourse(RetryCourse course) async {
    if (course.isSelected) return;

    setState(() {
      course.isRetrying = true;
      course.retryCount++;
      course.lastRetryTime = DateTime.now();
    });

    try {
      final service = CourseSelectionService(
        cookie: _cookieController.text,
        userAgent: _uaController.text,
      );

      final allCourses = await service.getAvailableCourses();
      
      // 查找匹配的课程
      final matchingCourses = allCourses.where((c) => c['KCMC'] == course.name).toList();

      if (matchingCourses.isEmpty) {
        setState(() {
          course.status = '第${course.retryCount}次重试：未找到课程';
          course.isRetrying = false;
        });
        return;
      }

      for (final courseData in matchingCourses) {
        final classes = await service.getCourseClasses(
          courseData['FZID'].toString(),
          courseData['KCBH'].toString(),
          courseData['ID'].toString(),
        );

        final matchingClasses = classes.where((cls) => cls['XM'] == course.teacher).toList();

        if (matchingClasses.isNotEmpty) {
          final cls = matchingClasses.first;
          
          try {
            final result = await service.selectCourse(
              kcbh: courseData['KCBH'].toString(),
              ktbh: cls['KTBH'].toString(),
              fzid: courseData['FZID'].toString(),
              faid: courseData['ID'].toString(),
              xqh: courseData['XQH'].toString(),
            );

            setState(() {
              course.status = '第${course.retryCount}次重试：选课成功';
              course.isSelected = true;
              course.isRetrying = false;
            });
            return;
          } catch (e) {
            setState(() {
              course.status = '第${course.retryCount}次重试：${e.toString()}';
              course.isRetrying = false;
            });
          }
        }
      }

      setState(() {
        course.status = '第${course.retryCount}次重试：未找到匹配教师';
        course.isRetrying = false;
      });
    } catch (e) {
      setState(() {
        course.status = '第${course.retryCount}次重试：网络错误 - $e';
        course.isRetrying = false;
      });
    }
  }

  Future<void> _retryAllFailedCourses() async {
    final failedCourses = targetCourses.where((c) => !c.isSelected).toList();
    if (failedCourses.isEmpty) {
      setState(() {
        statusMessage = '没有需要重试的课程';
      });
      return;
    }

    setState(() {
      isRetryingAll = true;
      statusMessage = '开始批量重试...';
      total = failedCourses.length;
      progress = 0;
    });

    for (var i = 0; i < failedCourses.length; i++) {
      final course = failedCourses[i];
      
      if (course.retryCount >= retryConfig.maxRetries) {
        setState(() {
          course.status = '已达到最大重试次数(${retryConfig.maxRetries})';
          progress = i + 1;
        });
        continue;
      }

      setState(() {
        progress = i + 1;
        statusMessage = '重试中: ${course.name} (${i+1}/$total)';
      });

      await _retrySingleCourse(course);

      // 重试间隔
      if (i < failedCourses.length - 1) {
        await Future.delayed(Duration(seconds: retryConfig.retryIntervalSeconds));
      }
    }

    setState(() {
      isRetryingAll = false;
      statusMessage = '批量重试完成';
    });
  }

  Future<void> _startContinuousRetry() async {
    final failedCourses = targetCourses.where((c) => !c.isSelected).toList();
    if (failedCourses.isEmpty) return;

    setState(() {
      isRetryingAll = true;
      statusMessage = '开始连续重试模式...';
    });

    bool hasMoreRetries = true;
    while (hasMoreRetries && isRetryingAll) {
      hasMoreRetries = false;
      
      for (final course in failedCourses) {
        if (!isRetryingAll) break;
        
        if (!course.isSelected && course.retryCount < retryConfig.maxRetries) {
          setState(() {
            statusMessage = '连续重试: ${course.name} (第${course.retryCount + 1}次)';
          });
          
          await _retrySingleCourse(course);
          
          if (!course.isSelected) {
            hasMoreRetries = true;
          }
          
          await Future.delayed(Duration(seconds: retryConfig.retryIntervalSeconds));
        }
      }
    }

    if (isRetryingAll) {
      setState(() {
        isRetryingAll = false;
        statusMessage = '连续重试完成';
      });
    }
  }

  void _stopRetry() {
    setState(() {
      isRetryingAll = false;
      statusMessage = '已停止重试';
    });
  }

  void _resetRetries() {
    setState(() {
      for (final course in targetCourses) {
        course.retryCount = 0;
        course.status = null;
        course.isSelected = false;
        course.isRetrying = false;
      }
      statusMessage = '已重置重试计数';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('智能重试课程选择器'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isRetryingAll ? null : _resetRetries,
            tooltip: '重置重试计数',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 网络设置
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('网络设置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cookieController,
                      decoration: const InputDecoration(
                        labelText: 'Cookie',
                        border: OutlineInputBorder(),
                        helperText: '从浏览器中获取的Cookie值',
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _uaController,
                      decoration: const InputDecoration(
                        labelText: 'User-Agent',
                        border: OutlineInputBorder(),
                        helperText: '浏览器User-Agent字符串',
                      ),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 重试配置
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('重试配置', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _retryCountController,
                            decoration: const InputDecoration(
                              labelText: '最大重试次数',
                              border: OutlineInputBorder(),
                              helperText: '每门课程最多重试次数',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _updateRetryConfig(),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _retryIntervalController,
                            decoration: const InputDecoration(
                              labelText: '重试间隔(秒)',
                              border: OutlineInputBorder(),
                              helperText: '每次重试之间的间隔',
                            ),
                            keyboardType: TextInputType.number,
                            onChanged: (_) => _updateRetryConfig(),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 目标课程管理
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('目标课程', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _courseNameController,
                            decoration: const InputDecoration(
                              labelText: '课程名称',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _teacherNameController,
                            decoration: const InputDecoration(
                              labelText: '教师姓名',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: _addTargetCourse,
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('添加'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    if (targetCourses.isEmpty)
                      const Text('暂无目标课程'),
                    
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: targetCourses.length,
                      itemBuilder: (context, index) {
                        final course = targetCourses[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: course.isSelected ? Colors.green[50] : null,
                          child: ListTile(
                            leading: Stack(
                              alignment: Alignment.center,
                              children: [
                                Icon(
                                  course.isSelected ? Icons.check_circle : Icons.circle,
                                  color: course.isSelected ? Colors.green : Colors.grey,
                                ),
                                if (course.isRetrying)
                                  const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                              ],
                            ),
                            title: Text(course.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('教师: ${course.teacher}'),
                                if (course.status != null)
                                  Text(
                                    course.status!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: course.isSelected ? Colors.green : Colors.orange,
                                    ),
                                  ),
                                if (course.retryCount > 0)
                                  Text(
                                    '重试次数: ${course.retryCount}/${retryConfig.maxRetries}',
                                    style: const TextStyle(fontSize: 11, color: Colors.blue),
                                  ),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!course.isSelected && course.retryCount < retryConfig.maxRetries)
                                  IconButton(
                                    icon: const Icon(Icons.refresh, color: Colors.blue),
                                    onPressed: course.isRetrying ? null : () => _retrySingleCourse(course),
                                    tooltip: '重试此课程',
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () => _removeTargetCourse(index),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 重试控制
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('重试控制', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: isRetryingAll ? null : _retryAllFailedCourses,
                          icon: const Icon(Icons.refresh),
                          label: const Text('重试所有失败课程'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          onPressed: isRetryingAll ? null : _startContinuousRetry,
                          icon: const Icon(Icons.loop),
                          label: const Text('连续重试模式'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                          ),
                        ),
                        if (isRetryingAll)
                          ElevatedButton.icon(
                            onPressed: _stopRetry,
                            icon: const Icon(Icons.stop),
                            label: const Text('停止重试'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '当前配置: 最多重试${retryConfig.maxRetries}次，间隔${retryConfig.retryIntervalSeconds}秒',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // 状态显示
            if (statusMessage.isNotEmpty)
              Card(
                elevation: 2,
                color: isRetryingAll ? Colors.blue[50] : Colors.grey[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      if (isRetryingAll)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      if (isRetryingAll) const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          statusMessage,
                          style: TextStyle(
                            color: isRetryingAll ? Colors.blue[700] : Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            onPressed: isRetryingAll ? null : _retryAllFailedCourses,
            icon: isRetryingAll 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.play_arrow),
            label: Text(isRetryingAll ? '重试中...' : '开始选课'),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            onPressed: isRetryingAll ? _stopRetry : null,
            child: const Icon(Icons.stop),
            tooltip: '停止重试',
          ),
        ],
      ),
    );
  }
}