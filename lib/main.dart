import 'package:flutter/material.dart';
import 'course_selection_service.dart';

void main() {
  runApp(const AdvancedCourseSelectorApp());
}

class AdvancedCourseSelectorApp extends StatelessWidget {
  const AdvancedCourseSelectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HUST专选抢课',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const AdvancedCourseSelectorPage(),
    );
  }
}

class CourseSelection {
  final String name;
  final String teacher;
  bool isSelected;
  String? status;

  CourseSelection({
    required this.name, 
    required this.teacher,
    this.isSelected = false,
    this.status,
  });
}

class AdvancedCourseSelectorPage extends StatefulWidget {
  const AdvancedCourseSelectorPage({super.key});

  @override
  State<AdvancedCourseSelectorPage> createState() => _AdvancedCourseSelectorPageState();
}

class _AdvancedCourseSelectorPageState extends State<AdvancedCourseSelectorPage> {
  final TextEditingController _cookieController = TextEditingController(
    text: '打开浏览器找一下'
  );
  final TextEditingController _uaController = TextEditingController(
    text: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/132.0.0.0 Safari/537.36'
  );
  final TextEditingController _courseNameController = TextEditingController();
  final TextEditingController _teacherNameController = TextEditingController();

  List<CourseSelection> targetCourses = [
    CourseSelection(name: "大数据管理概论", teacher: "左琼"),
    CourseSelection(name: "函数式编程原理", teacher: "郑然"),
    CourseSelection(name: "计算机图形学", teacher: "何云峰"),
    CourseSelection(name: "计算机视觉导论", teacher: "刘康"),
  ];

  List<Map<String, dynamic>> availableCourses = [];
  List<Map<String, dynamic>> courseClasses = [];
  
  bool isLoading = false;
  bool isFetchingCourses = false;
  String statusMessage = '';
  int progress = 0;
  int total = 0;

  @override
  void dispose() {
    _cookieController.dispose();
    _uaController.dispose();
    _courseNameController.dispose();
    _teacherNameController.dispose();
    super.dispose();
  }

  void _addTargetCourse() {
    if (_courseNameController.text.isNotEmpty && _teacherNameController.text.isNotEmpty) {
      setState(() {
        targetCourses.add(CourseSelection(
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

  Future<void> _fetchAvailableCourses() async {
    setState(() {
      isFetchingCourses = true;
      statusMessage = '正在获取可选课程...';
    });

    try {
      final service = CourseSelectionService(
        cookie: _cookieController.text,
        userAgent: _uaController.text,
      );

      final courses = await service.getAvailableCourses();
      
      setState(() {
        availableCourses = courses;
        statusMessage = '获取到 ${courses.length} 门可选课程';
      });
    } catch (e) {
      setState(() {
        statusMessage = '获取课程失败: $e';
      });
    } finally {
      setState(() {
        isFetchingCourses = false;
      });
    }
  }

  Future<void> _startAdvancedSelection() async {
    if (targetCourses.isEmpty) {
      setState(() {
        statusMessage = '请先添加要选择的课程';
      });
      return;
    }

    setState(() {
      isLoading = true;
      statusMessage = '开始智能选课...';
      progress = 0;
      total = targetCourses.length;
    });

    try {
      final service = CourseSelectionService(
        cookie: _cookieController.text,
        userAgent: _uaController.text,
      );

      // 获取所有可选课程
      final allCourses = await service.getAvailableCourses();
      
      for (var i = 0; i < targetCourses.length; i++) {
        final target = targetCourses[i];
        setState(() {
          progress = i + 1;
          statusMessage = '正在查找 ${target.name}...';
        });

        // 查找匹配的课程
        final matchingCourses = allCourses.where((course) =>
          course['KCMC'] == target.name
        ).toList();

        if (matchingCourses.isEmpty) {
          setState(() {
            target.status = '未找到该课程，检查Cookie是否正确或失效，或选课系统还未开启';
          });
          continue;
        }

        bool courseSelected = false;
        
        for (final course in matchingCourses) {
          final kc = course as Map<String, dynamic>;
          final classes = await service.getCourseClasses(
            kc['FZID'].toString(),
            kc['KCBH'].toString(),
            kc['ID'].toString(),
          );

          // 查找匹配的教师
          final matchingClasses = classes.where((cls) =>
            cls['XM'] == target.teacher
          ).toList();

          if (matchingClasses.isNotEmpty) {
            final cls = matchingClasses.first as Map<String, dynamic>;
            
            try {
              final result = await service.selectCourse(
                kcbh: kc['KCBH'].toString(),
                ktbh: cls['KTBH'].toString(),
                fzid: kc['FZID'].toString(),
                faid: kc['ID'].toString(),
                xqh: kc['XQH'].toString(),
              );

              setState(() {
                target.status = result.toString();
                target.isSelected = true;
              });
              courseSelected = true;
              break;
            } catch (e) {
              setState(() {
                target.status = '选课失败: $e';
              });
            }
          }
        }

        if (!courseSelected && target.status == null) {
          setState(() {
            target.status = '未找到指定教师的课程';
          });
        }
      }

      setState(() {
        statusMessage = '选课流程完成！';
      });
    } catch (e) {
      setState(() {
        statusMessage = '选课失败: $e';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('HUST专选抢课'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: isLoading || isFetchingCourses ? null : _fetchAvailableCourses,
            tooltip: '刷新可选课程',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cookie和UA设置
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
                          child: ListTile(
                            leading: Icon(
                              course.isSelected ? Icons.check_circle : Icons.circle,
                              color: course.isSelected ? Colors.green : Colors.grey,
                            ),
                            title: Text(course.name),
                            subtitle: Text('教师: ${course.teacher}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (course.status != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: course.isSelected ? Colors.green[100] : Colors.orange[100],
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      course.status!,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: course.isSelected ? Colors.green[800] : Colors.orange[800],
                                      ),
                                    ),
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
            
            // 可选课程列表
            if (availableCourses.isNotEmpty)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('可选课程列表', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text('共找到 ${availableCourses.length} 门课程'),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: ListView.builder(
                          itemCount: availableCourses.length,
                          itemBuilder: (context, index) {
                            final course = availableCourses[index];
                            return ListTile(
                              title: Text(course['KCMC'] ?? '未知课程'),
                              subtitle: Text('课程编号: ${course['KCBH'] ?? '未知'}'),
                              dense: true,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            
            // 进度和状态
            if (isLoading || statusMessage.isNotEmpty)
              Card(
                elevation: 2,
                color: isLoading ? Colors.blue[50] : Colors.grey[50],
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isLoading) ...[
                        Row(
                          children: [
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            const SizedBox(width: 12),
                            Text('进度: $progress/$total'),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        statusMessage,
                        style: TextStyle(
                          color: isLoading ? Colors.blue[700] : Colors.grey[700],
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
            onPressed: isLoading || isFetchingCourses ? null : _startAdvancedSelection,
            icon: isLoading 
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.smart_toy),
            label: Text(isLoading ? '选课中...' : '开始选课'),
          ),
          const SizedBox(height: 8),
          FloatingActionButton.small(
            onPressed: isLoading || isFetchingCourses ? null : _fetchAvailableCourses,
            child: const Icon(Icons.refresh),
            tooltip: '刷新可选课程',
          ),
        ],
      ),
    );
  }
}