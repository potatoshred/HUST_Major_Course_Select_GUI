import 'dart:convert';
import 'package:http/http.dart' as http;

class CourseSelectionService {
  static const String baseUrl = 'https://wsxk.hust.edu.cn';
  
  final String cookie;
  final String userAgent;
  
  CourseSelectionService({required this.cookie, required this.userAgent});

  Map<String, String> get _headers => {
    'Accept': 'application/json, text/javascript, */*; q=0.01',
    'Accept-Encoding': 'gzip, deflate, br, zstd',
    'Accept-Language': 'en-US,en;q=0.9,zh-CN;q=0.8,zh;q=0.7,ja;q=0.6',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Cookie': cookie,
    'Host': 'wsxk.hust.edu.cn',
    'Pragma': 'no-cache',
    'User-Agent': userAgent,
    'X-Requested-With': 'XMLHttpRequest',
  };

  Future<List<Map<String, dynamic>>> getAvailableCourses() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/zyxxk/Stuxk/getXsFaFZkc'),
        headers: _headers,
        body: {
          'page': '1',
          'xkgz': '1',
          'limit': '100',
          'fzxkfs': '',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('获取课程列表失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('网络错误: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getCourseClasses(String fzid, String kcbh, String faid) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/zyxxk/Stuxk/getFzkt'),
        headers: _headers,
        body: {
          'page': '1',
          'limit': '10',
          'fzid': fzid,
          'kcbh': kcbh,
          'sfid': '',
          'faid': faid,
          'id': faid,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return List<Map<String, dynamic>>.from(data['data'] ?? []);
      } else {
        throw Exception('获取课堂信息失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('网络错误: $e');
    }
  }

  Future<String> selectCourse({
    required String kcbh,
    required String ktbh,
    required String fzid,
    required String faid,
    required String xqh,
  }) async {
    try {
      final headersWithReferer = Map<String, String>.from(_headers);
      headersWithReferer['Referer'] = 
          '$baseUrl/zyxxk/Stuxk/jumpAktxk?fzid=$fzid&kcbh=$kcbh&faid=$faid&sfid=';

      final response = await http.post(
        Uri.parse('$baseUrl/zyxxk/Stuxk/addStuxkIsxphx'),
        headers: headersWithReferer,
        body: {
          'kcbh': kcbh,
          'ktbh': ktbh,
          'fzid': fzid,
          'sfid': '',
          'faid': faid,
          'xqh': xqh,
        },
      );

      if (response.statusCode == 200) {
        return json.decode(response.body)['msg'].toString();
      } else {
        throw Exception('选课请求失败: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('网络错误: $e');
    }
  }
}