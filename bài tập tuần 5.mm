import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/task.dart';

class ApiService {
  // API Base URL do giảng viên cung cấp
  static const String baseUrl = 'https://share.tryapps.store/mock/teach';

  // Token nhận từ lệnh chạy: flutter run --dart-define=API_TOKEN=xxxx
  // (KHÔNG ghi token trực tiếp vào code vì bài sẽ đẩy lên GitHub)
  static const String token = String.fromEnvironment('API_TOKEN');

  // Chưa có token thì tự dùng dữ liệu mẫu để xem giao diện.
  // Khi nộp bài / demo cần chạy với token thật.
  static const bool useSample =
      bool.fromEnvironment('USE_SAMPLE') || token == '';

  static const Duration _timeout = Duration(seconds: 15);

  static List<Task> _sampleTasks() {
    String d(int plus) {
      final n = DateTime.now().add(Duration(days: plus));
      return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
    }

    return [
      Task(id: 4, title: 'Tập thể dục 30 phút', category: 'life', date: d(0), time: '06:30', done: true, remind: true),
      Task(
        id: 1,
        title: 'Nộp bài tập Lập trình di động',
        note: 'Nộp file .zip lên hệ thống của trường. Nhớ kèm ảnh chụp màn hình app.',
        category: 'study',
        date: d(0),
        time: '09:00',
        priority: 'high',
        remind: true,
        done: true,
        subtasks: const [
          Subtask(id: 1, title: 'Hoàn thiện màn hình đăng nhập', done: true),
          Subtask(id: 2, title: 'Chụp ảnh màn hình app', done: true),
          Subtask(id: 3, title: 'Nén file và nộp bài', done: true),
        ],
      ),
      Task(
        id: 2,
        title: 'Ôn chương 3 – Cấu trúc dữ liệu',
        note: 'Tập trung phần cây nhị phân và bảng băm.',
        category: 'study',
        date: d(0),
        time: '14:00',
        remind: true,
        subtasks: const [
          Subtask(id: 1, title: 'Đọc lại slide bài giảng', done: true),
          Subtask(id: 2, title: 'Làm 10 bài tập cuối chương'),
        ],
      ),
      Task(id: 3, title: 'Đi chợ mua đồ cho tuần', category: 'life', date: d(0), time: '17:30'),
      Task(id: 5, title: 'Gọi điện về nhà', category: 'life', date: d(1), time: '21:00'),
      Task(id: 6, title: 'Họp nhóm đồ án', category: 'study', date: d(2), time: '20:00', priority: 'high'),
    ];
  }

  static Map<String, String> get _headers {
    if (token.trim().isEmpty) {
      throw Exception(
        'Chưa có API Token. Chạy app với --dart-define=API_TOKEN=<token>.',
      );
    }
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer ${token.trim()}',
    };
  }

  static Uri _uri(String path) => Uri.parse('$baseUrl$path');

  static dynamic _decode(http.Response response) {
    if (response.body.trim().isEmpty) return null;
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return response.body;
    }
  }

  static void _check(http.Response response) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
    }
  }

  static List<Task> _tasksFrom(dynamic data) {
    dynamic list = data;
    if (data is Map) {
      list = data['tasks'] ?? data['data'] ?? data['items'] ?? data['results'];
      if (list is Map) {
        list = list['tasks'] ?? list['data'] ?? list['items'];
      }
    }
    if (list is! List) {
      throw Exception('API không trả về danh sách công việc hợp lệ.');
    }
    return list
        .whereType<Map>()
        .map((e) => Task.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  // GET /tasks — tải mọi việc khi mở màn hình
  static Future<List<Task>> getTasks() async {
    if (useSample) {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      return _sampleTasks();
    }
    final response =
        await http.get(_uri('/tasks'), headers: _headers).timeout(_timeout);
    _check(response);
    return _tasksFrom(_decode(response));
  }

  // GET /tasks/{id} — mở khi bấm một việc
  static Future<Task> getTask(int id) async {
    if (useSample) {
      return _sampleTasks().firstWhere((t) => t.id == id,
          orElse: () => throw Exception('Không tìm thấy việc mẫu'));
    }
    final response =
        await http.get(_uri('/tasks/$id'), headers: _headers).timeout(_timeout);
    _check(response);
    final data = _decode(response);
    final item = data is Map && data['task'] is Map
        ? data['task']
        : data is Map && data['data'] is Map
            ? data['data']
            : data;
    if (item is! Map) {
      throw Exception('API không trả về chi tiết công việc hợp lệ.');
    }
    return Task.fromJson(Map<String, dynamic>.from(item));
  }

  // POST /tasks — thêm công việc mới
  static Future<Task> createTask(Task task) async {
    if (useSample) return task;
    final response = await http
        .post(_uri('/tasks'), headers: _headers, body: jsonEncode(task.toJson()))
        .timeout(_timeout);
    _check(response);
    final data = _decode(response);
    if (data is Map) {
      final item = data['task'] ?? data['data'] ?? data;
      if (item is Map && item['id'] != null) {
        return Task.fromJson(Map<String, dynamic>.from(item));
      }
    }
    return task;
  }

  // PATCH /tasks/{id} — cập nhật công việc
  static Future<void> updateTask(Task task) async {
    if (useSample) return;
    final response = await http
        .patch(_uri('/tasks/${task.id}'),
            headers: _headers, body: jsonEncode(task.toJson()))
        .timeout(_timeout);
    _check(response);
  }

  // DELETE /tasks/{id} — xóa công việc
  static Future<void> deleteTask(int id) async {
    if (useSample) return;
    final response = await http
        .delete(_uri('/tasks/$id'), headers: _headers)
        .timeout(_timeout);
    _check(response);
  }
}