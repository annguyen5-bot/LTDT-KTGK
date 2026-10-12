import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

// ============================================================================
// DESIGN SYSTEM - FIGMA BLUE THEME
// ============================================================================
const Color kPrimaryBlue = Color(0xFF2563EB); // Royal Blue from Figma
const Color kPrimaryDarkBlue = Color(0xFF1D4ED8);
const Color kDeepBlue = Color(0xFF1E40AF);
const Color kLightBlueBg = Color(0xFFEFF6FF); // Soft blue tint for icons/badges
const Color kCanvasBg = Color(0xFFF8FAFC); // Main scaffold surface
const Color kCardBg = Colors.white;
const Color kBorderColor = Color(0xFFE2E8F0);
const Color kTextDark = Color(0xFF0F172A);
const Color kTextMuted = Color(0xFF64748B);
const Color kTextHint = Color(0xFF94A3B8);
const Color kSuccessGreen = Color(0xFF10B981);
const Color kErrorRed = Color(0xFFEF4444);
const Color kWarningAmber = Color(0xFFF59E0B);
const Color kAdminAccent = Color(0xFF7C3AED); // Purple accent for Admin mode

// ============================================================================
// ROLE ENUM: 1 TÀI KHOẢN CÓ 2 VAI TRÒ (ADMIN & USER)
// ============================================================================
enum UserRole {
  user,  // Người học: Chọn đề thi, Làm bài, Hiển thị kết quả
  admin, // Quản trị viên: Import đề thi (Word/JSON), Chỉnh sửa đề sau khi import
}

// ============================================================================
// MODELS
// ============================================================================
class OptionItem {
  String label; // "A", "B", "C", "D"
  String content;

  OptionItem({required this.label, required this.content});

  factory OptionItem.fromJson(Map<String, dynamic> json) => OptionItem(
        label: (json['label'] ?? json['Label'] ?? '').toString().trim(),
        content: (json['content'] ?? json['Content'] ?? '').toString().trim(),
      );

  Map<String, dynamic> toJson() => {'label': label, 'content': content};

  OptionItem clone() => OptionItem(label: label, content: content);
}

class QuestionItem {
  int id;
  int part; // 5, 6, 7
  int number; // 101 .. 200
  String? text;
  String? passageContent;
  int? passageOrderIndex;
  List<OptionItem> options;
  String? correctAnswer; // "A", "B", "C", "D"
  String? explanation;

  QuestionItem({
    required this.id,
    required this.part,
    required this.number,
    this.text,
    this.passageContent,
    this.passageOrderIndex,
    required this.options,
    this.correctAnswer,
    this.explanation,
  });

  bool get isAllCorrect =>
      correctAnswer == '*' ||
      correctAnswer == 'ALL' ||
      correctAnswer == 'ABCD' ||
      correctAnswer == 'A,B,C,D';

  factory QuestionItem.fromJson(Map<String, dynamic> json) {
    var rawOptions = (json['options'] ?? json['Options']) as List? ?? [];
    return QuestionItem(
      id: (json['id'] ?? json['Id'] ?? 0) as int,
      part: (json['part'] ?? json['Part'] ?? 5) as int,
      number: (json['number'] ?? json['Number'] ?? 101) as int,
      text: json['text'] ?? json['Text'],
      passageContent: json['passageContent'] ?? json['PassageContent'],
      passageOrderIndex: json['passageOrderIndex'] ?? json['PassageOrderIndex'],
      options: rawOptions
          .map((e) => OptionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      correctAnswer: json['correctAnswer'] ?? json['CorrectAnswer'],
      explanation: json['explanation'] ?? json['Explanation'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'part': part,
        'number': number,
        'text': text,
        'passageContent': passageContent,
        'passageOrderIndex': passageOrderIndex,
        'options': options.map((e) => e.toJson()).toList(),
        'correctAnswer': correctAnswer,
        'explanation': explanation,
      };

  QuestionItem clone() => QuestionItem(
        id: id,
        part: part,
        number: number,
        text: text,
        passageContent: passageContent,
        passageOrderIndex: passageOrderIndex,
        options: options.map((e) => e.clone()).toList(),
        correctAnswer: correctAnswer,
        explanation: explanation,
      );
}

class PassageItem {
  int id;
  int part;
  int orderIndex;
  String content;
  String? rangeText;
  String? instruction;

  PassageItem({
    required this.id,
    required this.part,
    required this.orderIndex,
    required this.content,
    this.rangeText,
    this.instruction,
  });

  factory PassageItem.fromJson(Map<String, dynamic> json) => PassageItem(
        id: (json['id'] ?? json['Id'] ?? 0) as int,
        part: (json['part'] ?? json['Part'] ?? 6) as int,
        orderIndex: (json['orderIndex'] ?? json['OrderIndex'] ?? 1) as int,
        content: (json['content'] ?? json['Content'] ?? '').toString(),
        rangeText: json['rangeText'] ?? json['RangeText'],
        instruction: json['instruction'] ?? json['Instruction'],
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'part': part,
        'orderIndex': orderIndex,
        'content': content,
        'rangeText': rangeText,
        'instruction': instruction,
      };

  PassageItem clone() => PassageItem(
        id: id,
        part: part,
        orderIndex: orderIndex,
        content: content,
        rangeText: rangeText,
        instruction: instruction,
      );
}

class ExamItem {
  int id;
  String title;
  int durationMinutes;
  int questionCount;
  List<PassageItem> passages;
  List<QuestionItem> questions;

  ExamItem({
    required this.id,
    required this.title,
    required this.durationMinutes,
    required this.questionCount,
    this.passages = const [],
    this.questions = const [],
  });

  factory ExamItem.fromJson(Map<String, dynamic> raw) {
    final json = (raw['result'] != null && raw['result'] is Map<String, dynamic>)
        ? raw['result'] as Map<String, dynamic>
        : raw;
    var rawPassages = (json['passages'] ?? json['Passages']) as List? ?? [];
    var rawQuestions = (json['questions'] ?? json['Questions']) as List? ?? [];
    return ExamItem(
      id: (json['id'] ?? json['Id'] ?? 0) as int,
      title: (json['title'] ?? json['Title'] ?? 'Đề thi TOEIC Reading').toString(),
      durationMinutes: (json['durationMinutes'] ?? json['DurationMinutes'] ?? 75) as int,
      questionCount: (json['totalQuestions'] ?? json['TotalQuestions'] ?? json['questionCount'] ?? rawQuestions.length) as int,
      passages: rawPassages
          .map((e) => PassageItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      questions: rawQuestions
          .map((e) => QuestionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'durationMinutes': durationMinutes,
        'questionCount': questionCount,
        'passages': passages.map((e) => e.toJson()).toList(),
        'questions': questions.map((e) => e.toJson()).toList(),
      };

  ExamItem copyWith({
    int? id,
    String? title,
    int? durationMinutes,
    int? questionCount,
    List<PassageItem>? passages,
    List<QuestionItem>? questions,
  }) =>
      ExamItem(
        id: id ?? this.id,
        title: title ?? this.title,
        durationMinutes: durationMinutes ?? this.durationMinutes,
        questionCount: questionCount ?? this.questionCount,
        passages: passages ?? this.passages,
        questions: questions ?? this.questions,
      );

  ExamItem clone() => ExamItem(
        id: id,
        title: title,
        durationMinutes: durationMinutes,
        questionCount: questionCount,
        passages: passages.map((e) => e.clone()).toList(),
        questions: questions.map((e) => e.clone()).toList(),
      );
}


// ============================================================================
// BACKEND API SERVICE
// ============================================================================
class ToeicApiService {
  static String baseUrl = 'http://localhost:44311';

  static Future<ExamItem> uploadWordFile({
    required Uint8List bytes,
    required String filename,
  }) async {
    Future<http.Response> doUpload(String targetUrl) async {
      final uri = Uri.parse('$targetUrl/api/toeic/upload-word');
      final request = http.MultipartRequest('POST', uri);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw TimeoutException('Kết nối máy chủ bị quá thời gian.'),
      );
      return await http.Response.fromStream(streamedResponse);
    }

    http.Response response;
    try {
      response = await doUpload(baseUrl);
    } catch (_) {
      final altUrl = baseUrl.startsWith('https://')
          ? baseUrl.replaceFirst('https://', 'http://')
          : baseUrl.replaceFirst('http://', 'https://');
      response = await doUpload(altUrl);
      baseUrl = altUrl;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return ExamItem.fromJson(data is Map<String, dynamic> ? data : {});
    } else {
      String message = 'Lỗi tải lên máy chủ (${response.statusCode})';
      try {
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        if (err is Map && err['error'] != null && err['error']['message'] != null) {
          message = err['error']['message'];
        }
      } catch (_) {}
      throw Exception(message);
    }
  }

  static Future<List<ExamItem>> fetchExams() async {
    try {
      final uri = Uri.parse('$baseUrl/api/services/app/Toeic/GetExams');
      final response = await http.get(uri).timeout(const Duration(seconds: 4));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final items = (decoded['result'] ?? decoded) as List? ?? [];
        return items.map((e) => ExamItem.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (_) {
      final altUrl = baseUrl.startsWith('https://')
          ? baseUrl.replaceFirst('https://', 'http://')
          : baseUrl.replaceFirst('http://', 'https://');
      try {
        final uri = Uri.parse('$altUrl/api/services/app/Toeic/GetExams');
        final response = await http.get(uri).timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          baseUrl = altUrl;
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          final items = (decoded['result'] ?? decoded) as List? ?? [];
          return items.map((e) => ExamItem.fromJson(e as Map<String, dynamic>)).toList();
        }
      } catch (__) {}
    }
    throw Exception('Không tải được danh sách đề từ máy chủ');
  }

  static Future<ExamItem> fetchForPractice(int examId) async {
    try {
      final uri = Uri.parse('$baseUrl/api/services/app/Toeic/GetForPractice?Id=$examId');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final data = decoded['result'] ?? decoded;
        return ExamItem.fromJson(data as Map<String, dynamic>);
      }
    } catch (_) {
      final altUrl = baseUrl.startsWith('https://')
          ? baseUrl.replaceFirst('https://', 'http://')
          : baseUrl.replaceFirst('http://', 'https://');
      try {
        final uri = Uri.parse('$altUrl/api/services/app/Toeic/GetForPractice?Id=$examId');
        final response = await http.get(uri).timeout(const Duration(seconds: 8));
        if (response.statusCode == 200) {
          baseUrl = altUrl;
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          final data = decoded['result'] ?? decoded;
          return ExamItem.fromJson(data as Map<String, dynamic>);
        }
      } catch (__) {}
    }
    throw Exception('Không thể tải nội dung bài thi từ máy chủ.');
  }

  static Future<ExamItem> fetchForEdit(int examId) async {
    // 1. Thử lấy từ GetForEdit trước (kèm đáp án đúng đầy đủ)
    try {
      final uri = Uri.parse('$baseUrl/api/services/app/Toeic/GetForEdit?Id=$examId');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final data = decoded['result'] ?? decoded;
        return ExamItem.fromJson(data as Map<String, dynamic>);
      }
    } catch (_) {}

    // 2. Thử URL thay thế nếu baseUrl đổi
    final altUrl = baseUrl.startsWith('https://')
        ? baseUrl.replaceFirst('https://', 'http://')
        : baseUrl.replaceFirst('http://', 'https://');
    try {
      final uri = Uri.parse('$altUrl/api/services/app/Toeic/GetForEdit?Id=$examId');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode == 200) {
        baseUrl = altUrl;
        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        final data = decoded['result'] ?? decoded;
        return ExamItem.fromJson(data as Map<String, dynamic>);
      }
    } catch (_) {}

    // 3. Fallback sang fetchForPractice nếu backend đang chạy phiên bản cũ
    return await fetchForPractice(examId);
  }

  static Future<void> updateExam(ExamItem exam) async {
    final payload = {
      'id': exam.id,
      'title': exam.title,
      'durationMinutes': exam.durationMinutes,
      'passages': exam.passages.map((p) => {
        'part': p.part,
        'orderIndex': p.orderIndex,
        'rangeText': p.rangeText,
        'instruction': p.instruction,
        'content': p.content,
      }).toList(),
      'questions': exam.questions.map((q) => {
        'part': q.part,
        'number': q.number,
        'text': q.text ?? '',
        'passageOrderIndex': q.passageOrderIndex,
        'correctAnswer': q.isAllCorrect ? '*' : (q.correctAnswer ?? 'A').trim().toUpperCase(),
        'options': q.options.map((o) => {
          'label': o.label.trim().toUpperCase(),
          'content': o.content,
        }).toList(),
      }).toList(),
    };

    final headers = {'Content-Type': 'application/json; charset=utf-8'};
    final bodyJson = jsonEncode(payload);

    // 1. Thử gọi trực tiếp endpoint Controller chuyên dụng api/toeic/update-exam
    try {
      final directUri = Uri.parse('$baseUrl/api/toeic/update-exam');
      final resp = await http.post(
        directUri,
        headers: headers,
        body: bodyJson,
      ).timeout(const Duration(seconds: 20));

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return;
      }
    } catch (_) {}

    // 2. Thử gọi ABP Dynamic Web API PUT /api/services/app/Toeic/UpdateExam
    final abpUri = Uri.parse('$baseUrl/api/services/app/Toeic/UpdateExam');
    final putResp = await http.put(
      abpUri,
      headers: headers,
      body: bodyJson,
    ).timeout(const Duration(seconds: 20));

    if (putResp.statusCode >= 200 && putResp.statusCode < 300) {
      return;
    }

    // 3. Nếu thất bại, đọc chi tiết lỗi từ máy chủ
    String errorMsg = 'Mã lỗi HTTP: ${putResp.statusCode}';
    try {
      final decoded = jsonDecode(utf8.decode(putResp.bodyBytes));
      if (decoded['error'] != null && decoded['error']['message'] != null) {
        errorMsg = decoded['error']['message'].toString();
      } else if (decoded['message'] != null) {
        errorMsg = decoded['message'].toString();
      }
    } catch (_) {}

    throw Exception(errorMsg);
  }

  static Future<void> updateExamInfo(int id, String title, int durationMinutes) async {
    try {
      final uri = Uri.parse('$baseUrl/api/services/app/Toeic/UpdateExamInfo');
      final payload = {'id': id, 'title': title, 'durationMinutes': durationMinutes};
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }

  static Future<void> deleteExam(int id) async {
    try {
      final uri = Uri.parse('$baseUrl/api/services/app/Toeic/DeleteExam');
      await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'id': id}),
      ).timeout(const Duration(seconds: 5));
    } catch (_) {}
  }
}

// ============================================================================
// MAIN APP ENTRY POINT
// ============================================================================
void main() {
  runApp(const ToeicReadingApp());
}

class ToeicReadingApp extends StatelessWidget {
  const ToeicReadingApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'TOEIC Reading Practice (Web & App)',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: kPrimaryBlue,
            primary: kPrimaryBlue,
            surface: kCanvasBg,
          ),
          scaffoldBackgroundColor: kCanvasBg,
          fontFamily: 'Roboto',
        ),
        builder: (context, child) => ResponsiveWebScaffold(child: child ?? const SizedBox.shrink()),
        home: const MainNavigationScreen(),
      );
}

// ============================================================================
// RESPONSIVE WRAPPER (CHẠY ĐẸP TRÊN CẢ WEB & APP)
// ============================================================================
final ValueNotifier<bool> _isMobileFrameNotifier = ValueNotifier<bool>(true);

class ResponsiveWebScaffold extends StatelessWidget {
  final Widget child;

  const ResponsiveWebScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    // If running on desktop web or large screen, center in realistic mobile/tablet preview frame
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 700) {
          // Màn hình điện thoại thật / màn hình nhỏ: chiếm full màn hình tự nhiên
          return child;
        }

        return ValueListenableBuilder<bool>(
          valueListenable: _isMobileFrameNotifier,
          builder: (context, isMobile, _) {
            if (!isMobile) {
              // Chế độ toàn màn hình Web
              return Scaffold(
                backgroundColor: kCanvasBg,
                body: Stack(
                  children: [
                    child,
                    Positioned(
                      top: 14,
                      right: 18,
                      child: SafeArea(
                        child: Material(
                          elevation: 4,
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _isMobileFrameNotifier.value = true,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.phone_android_rounded, color: Colors.white, size: 16),
                                  SizedBox(width: 6),
                                  Text(
                                    'Về khung Điện thoại',
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            // Chế độ Điện thoại (Mobile Mockup Frame)
            return Scaffold(
              backgroundColor: const Color(0xFF0F172A), // Dark elegant canvas for web preview
              body: Stack(
                children: [
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 500),
                      decoration: BoxDecoration(
                        color: kCanvasBg,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 36,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: ScaffoldMessenger(
                        child: child,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    right: 18,
                    child: SafeArea(
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(20),
                          onTap: () => _isMobileFrameNotifier.value = false,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.fullscreen_rounded, color: Colors.white, size: 18),
                                SizedBox(width: 6),
                                Text(
                                  'Mở rộng Web',
                                  style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ============================================================================
// MAIN NAVIGATION WITH ROLE SWITCHER (ADMIN & USER)
// ============================================================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  // Current active role for this single account
  UserRole _currentRole = UserRole.user;
  int _currentTab = 0;

  // Shared exam list in state
  final List<ExamItem> _exams = [];

  @override
  void initState() {
    super.initState();
    _loadBackendExams();
  }

  Future<void> _loadBackendExams() async {
    try {
      final list = await ToeicApiService.fetchExams();
      if (mounted) {
        setState(() {
          _exams.clear();
          _exams.addAll(list);
        });
      }
    } catch (_) {
      // Backend may be offline or DB empty
    }
  }

  void _switchRole(UserRole newRole) {
    setState(() {
      _currentRole = newRole;
      _currentTab = 0; // reset to first tab of new role
    });
  }

  void _addExam(ExamItem exam) {
    setState(() {
      _exams.insert(0, exam);
    });
  }

  void _updateExam(int index, ExamItem updated) {
    setState(() {
      _exams[index] = updated;
    });
  }

  void _deleteExam(int index) {
    final deleted = _exams[index];
    setState(() {
      _exams.removeAt(index);
    });
    if (deleted.id > 0) {
      ToeicApiService.deleteExam(deleted.id).catchError((_) {});
    }
  }

  void _startPractice(ExamItem exam) {
    if (exam.questionCount == 0 && exam.questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đề thi này chưa có nội dung câu hỏi hoặc chưa lưu trên máy chủ.'),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ReadingPracticePage(exam: exam),
      ),
    );
  }

  // Profile modal with role switcher
  void _showProfileAndRoleModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: kLightBlueBg,
                    shape: BoxShape.circle,
                  ),
                  child: const Text(
                    'AN',
                    style: TextStyle(
                      color: kPrimaryBlue,
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Nguyễn Văn An',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: kTextDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'an.nguyen@toeicpractice.edu.vn',
                        style: TextStyle(color: kTextMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: _currentRole == UserRole.admin
                              ? const Color(0xFFF3E8FF)
                              : kLightBlueBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _currentRole == UserRole.admin
                              ? '👑 VAI TRÒ: ADMIN (Quản trị viên)'
                              : '🎓 VAI TRÒ: USER (Người học)',
                          style: TextStyle(
                            color: _currentRole == UserRole.admin
                                ? kAdminAccent
                                : kPrimaryBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Divider(color: kBorderColor),
            const SizedBox(height: 12),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'CHỌN VAI TRÒ TRẢI NGHIỆM',
                style: TextStyle(
                  color: kTextMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Option: USER
            ListTile(
              tileColor: _currentRole == UserRole.user ? kLightBlueBg : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _currentRole == UserRole.user ? kPrimaryBlue : kBorderColor,
                ),
              ),
              leading: const Icon(Icons.school_rounded, color: kPrimaryBlue),
              title: const Text(
                'Người học (User)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Chọn đề thi, Luyện tập, Làm bài & Xem bảng điểm',
                style: TextStyle(fontSize: 12),
              ),
              trailing: _currentRole == UserRole.user
                  ? const Icon(Icons.check_circle_rounded, color: kPrimaryBlue)
                  : null,
              onTap: () {
                _switchRole(UserRole.user);
                Navigator.pop(ctx);
              },
            ),
            const SizedBox(height: 10),

            // Option: ADMIN
            ListTile(
              tileColor: _currentRole == UserRole.admin ? const Color(0xFFF3E8FF) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: _currentRole == UserRole.admin ? kAdminAccent : kBorderColor,
                ),
              ),
              leading: const Icon(Icons.admin_panel_settings_rounded, color: kAdminAccent),
              title: const Text(
                'Quản trị viên (Admin)',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Import đề file Word (.docx), Chỉnh sửa đề sau khi import',
                style: TextStyle(fontSize: 12),
              ),
              trailing: _currentRole == UserRole.admin
                  ? const Icon(Icons.check_circle_rounded, color: kAdminAccent)
                  : null,
              onTap: () {
                _switchRole(UserRole.admin);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pages for User
    final userPages = [
      _HomeTab(
        exams: _exams,
        onStartExam: _startPractice,
        onOpenProfile: _showProfileAndRoleModal,
        currentRole: _currentRole,
      ),
      _PracticeTab(
        exams: _exams,
        onStartExam: _startPractice,
        onOpenProfile: _showProfileAndRoleModal,
      ),
      _ProgressTab(onOpenProfile: _showProfileAndRoleModal),
    ];

    // Pages for Admin
    final adminPages = [
      _AdminTab(
        exams: _exams,
        onAddExam: _addExam,
        onUpdateExam: _updateExam,
        onDeleteExam: _deleteExam,
        onStartPractice: _startPractice,
        onOpenProfile: _showProfileAndRoleModal,
        onSwitchToUser: () => _switchRole(UserRole.user),
      ),
      _AdminUploadTab(
        onAddExam: _addExam,
        onOpenProfile: _showProfileAndRoleModal,
      ),
    ];

    final isUser = _currentRole == UserRole.user;

    return Scaffold(
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            // Quick role notification banner at the top
            _TopRoleBar(
              role: _currentRole,
              onSwitch: () => _switchRole(isUser ? UserRole.admin : UserRole.user),
            ),
            Expanded(
              child: IndexedStack(
                index: _currentTab,
                children: isUser ? userPages : adminPages,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentTab,
        onDestinationSelected: (idx) => setState(() => _currentTab = idx),
        backgroundColor: Colors.white,
        elevation: 8,
        indicatorColor: isUser ? kLightBlueBg : const Color(0xFFF3E8FF),
        destinations: isUser
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home_rounded, color: kPrimaryBlue),
                  label: 'Trang chủ',
                ),
                NavigationDestination(
                  icon: Icon(Icons.menu_book_outlined),
                  selectedIcon: Icon(Icons.menu_book_rounded, color: kPrimaryBlue),
                  label: 'Luyện tập',
                ),
                NavigationDestination(
                  icon: Icon(Icons.insights_outlined),
                  selectedIcon: Icon(Icons.insights_rounded, color: kPrimaryBlue),
                  label: 'Tiến độ',
                ),
              ]
            : const [
                NavigationDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment_rounded, color: kAdminAccent),
                  label: 'Quản lý đề',
                ),
                NavigationDestination(
                  icon: Icon(Icons.cloud_upload_outlined),
                  selectedIcon: Icon(Icons.cloud_upload_rounded, color: kAdminAccent),
                  label: 'Import đề Word',
                ),
              ],
      ),
    );
  }
}

// ============================================================================
// TOP ROLE BAR (HIỂN THỊ VAI TRÒ & NÚT CHUYỂN ROLE NHANH)
// ============================================================================
class _TopRoleBar extends StatelessWidget {
  final UserRole role;
  final VoidCallback onSwitch;

  const _TopRoleBar({required this.role, required this.onSwitch});

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == UserRole.admin;
    return Container(
      width: double.infinity,
      color: isAdmin ? const Color(0xFF581C87) : const Color(0xFF1E3A8A),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
            isAdmin ? Icons.admin_panel_settings_rounded : Icons.school_rounded,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isAdmin
                  ? 'VAI TRÒ: ADMIN (Import & Chỉnh sửa đề)'
                  : 'VAI TRÒ: USER (Chọn đề, Làm bài & Xem điểm)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          InkWell(
            onTap: onSwitch,
            borderRadius: BorderRadius.circular(6),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isAdmin ? 'Đổi sang User' : 'Đổi sang Admin',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 1 (USER): TRANG CHỦ FIGMA - CHỌN ĐỀ THI
// ============================================================================
class _HomeTab extends StatefulWidget {
  final List<ExamItem> exams;
  final ValueChanged<ExamItem> onStartExam;
  final VoidCallback onOpenProfile;
  final UserRole currentRole;

  const _HomeTab({
    required this.exams,
    required this.onStartExam,
    required this.onOpenProfile,
    required this.currentRole,
  });

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filteredExams = widget.exams.where((exam) {
      if (_searchQuery.isEmpty) return true;
      return exam.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return RefreshIndicator(
      onRefresh: () async {
        try {
          final refreshed = await ToeicApiService.fetchExams();
          if (mounted && refreshed.isNotEmpty) {
            setState(() {
              widget.exams.clear();
              widget.exams.addAll(refreshed);
            });
          }
        } catch (_) {}
      },
      child: CustomScrollView(
        slivers: [
          // ---------------------------------------------------------------
          // FIGMA BLUE HEADER WITH SEARCH BAR
          // ---------------------------------------------------------------
          SliverToBoxAdapter(
            child: _FigmaHeaderWidget(
              controller: _searchController,
              onSearchChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // ---------------------------------------------------------------
          // THƯ VIỆN ĐỀ THI SECTION
          // ---------------------------------------------------------------
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Section Title + User Avatar
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'THƯ VIỆN ĐỀ THI',
                            style: TextStyle(
                              color: kPrimaryBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Đề thi dành cho bạn',
                            style: TextStyle(
                              color: kTextDark,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Avatar Badge "AN" as shown in Figma (Click to switch role)
                    Tooltip(
                      message: 'Bấm để đổi vai trò Admin / User',
                      child: InkWell(
                        onTap: widget.onOpenProfile,
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: kLightBlueBg,
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            'AN',
                            style: TextStyle(
                              color: kPrimaryBlue,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // CONTENT: EMPTY STATE OR EXAM CARDS
                if (filteredExams.isEmpty)
                  _FigmaEmptyStateCard(
                    isSearching: _searchQuery.isNotEmpty,
                    actionLabel: widget.currentRole == UserRole.user
                        ? 'Chuyển sang vai trò Admin'
                        : null,
                    onAction: widget.currentRole == UserRole.user
                        ? widget.onOpenProfile
                        : null,
                  )
                else
                  Column(
                    children: [
                      for (final exam in filteredExams)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _ExamCard(
                            exam: exam,
                            onTap: () => widget.onStartExam(exam),
                          ),
                        ),
                    ],
                  ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPONENT: FIGMA BLUE HEADER
// ============================================================================
class _FigmaHeaderWidget extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onSearchChanged;

  const _FigmaHeaderWidget({
    required this.controller,
    required this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E40AF), // Deep royal blue
            Color(0xFF2563EB), // Vibrant blue
            Color(0xFF3B82F6), // Bright blue
          ],
        ),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x332563EB),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Decorative background circles
          Positioned(
            right: -30,
            top: -20,
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.07),
              ),
            ),
          ),
          Positioned(
            left: 20,
            bottom: 40,
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          // Header Content
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 48, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row with icon badge & Eyebrow
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.menu_book_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'READING PRACTICE',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.3,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Đề thi TOEIC Reading',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Subtitle
                const Text(
                  'Rèn luyện mỗi ngày, tự tin chinh phục mục tiêu.',
                  style: TextStyle(
                    color: Color(0xE6FFFFFF),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w400,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 20),

                // Search Bar Container
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: controller,
                    onChanged: onSearchChanged,
                    textAlignVertical: TextAlignVertical.center,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Tìm kiếm đề thi...',
                      hintStyle: const TextStyle(
                        color: kTextHint,
                        fontSize: 14,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: kTextHint,
                        size: 22,
                      ),
                      suffixIcon: controller.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                controller.clear();
                                onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// COMPONENT: FIGMA EMPTY STATE CARD
// ============================================================================
class _FigmaEmptyStateCard extends StatelessWidget {
  final bool isSearching;
  final VoidCallback? onAction;
  final String? actionLabel;

  const _FigmaEmptyStateCard({
    required this.isSearching,
    this.onAction,
    this.actionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: kBorderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kLightBlueBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.description_outlined,
              color: kPrimaryBlue,
              size: 38,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isSearching ? 'Không tìm thấy đề thi phù hợp' : 'Chưa có đề thi nào trong hệ thống',
            style: const TextStyle(
              color: kTextDark,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            isSearching
                ? 'Hãy thử tìm kiếm với từ khóa khác hoặc xóa bộ lọc.'
                : 'Chưa có đề thi nào được tải lên.\nAdmin hãy chuyển sang vai trò Admin để Import đề thi Word hoặc tạo đề mới.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: kTextMuted,
              fontSize: 13.5,
              height: 1.5,
            ),
          ),
          if (onAction != null && actionLabel != null) ...[
            const SizedBox(height: 24),
            OutlinedButton(
              onPressed: onAction,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kPrimaryBlue, width: 1.5),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                foregroundColor: kPrimaryBlue,
              ),
              child: Text(
                actionLabel!,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// COMPONENT: EXAM CARD (When exams exist)
// ============================================================================
class _ExamCard extends StatelessWidget {
  final ExamItem exam;
  final VoidCallback onTap;

  const _ExamCard({required this.exam, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCardBg,
      borderRadius: BorderRadius.circular(18),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kBorderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: kLightBlueBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.assignment_outlined,
                      color: kPrimaryBlue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exam.title,
                          style: const TextStyle(
                            color: kTextDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _TagBadge(
                              icon: Icons.timer_outlined,
                              label: '${exam.durationMinutes} phút',
                            ),
                            const SizedBox(width: 8),
                            _TagBadge(
                              icon: Icons.help_outline_rounded,
                              label: '${exam.questionCount} câu',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Text(
                    'Part 5 · Part 6 · Part 7',
                    style: TextStyle(
                      color: kTextMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    label: const Text('Làm bài'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kPrimaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagBadge extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TagBadge({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: kTextMuted),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(color: kTextMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// TAB 2 (USER): PRACTICE TAB (Luyện tập theo Part)
// ============================================================================
class _PracticeTab extends StatelessWidget {
  final List<ExamItem> exams;
  final ValueChanged<ExamItem> onStartExam;
  final VoidCallback onOpenProfile;

  const _PracticeTab({
    required this.exams,
    required this.onStartExam,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'LUYỆN TẬP THEO PHẦN',
                  style: TextStyle(
                    color: kPrimaryBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Chinh phục TOEIC',
                  style: TextStyle(
                    color: kTextDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.account_circle_outlined, color: kPrimaryBlue, size: 28),
              onPressed: onOpenProfile,
            ),
          ],
        ),
        const SizedBox(height: 16),

        _PartCard(
          partNumber: 5,
          title: 'Part 5 · Hoàn thành câu',
          subtitle: '30 câu · Ngữ pháp & Từ vựng then chốt',
          duration: '12-15 phút',
          color: const Color(0xFF3B82F6),
          onTap: () {
            if (exams.isNotEmpty) {
              onStartExam(exams.first);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chưa có đề thi nào. Admin hãy import đề thi để bắt đầu luyện tập!'),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 12),

        _PartCard(
          partNumber: 6,
          title: 'Part 6 · Điền đoạn văn',
          subtitle: '16 câu · Ngữ cảnh & Điền câu phù hợp',
          duration: '10-12 phút',
          color: const Color(0xFF6366F1),
          onTap: () {
            if (exams.isNotEmpty) {
              onStartExam(exams.first);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chưa có đề thi nào. Admin hãy import đề thi để bắt đầu luyện tập!'),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 12),

        _PartCard(
          partNumber: 7,
          title: 'Part 7 · Đọc hiểu văn bản',
          subtitle: '54 câu · Email, Bài báo, Đoạn kép & ba',
          duration: '45-50 phút',
          color: const Color(0xFF8B5CF6),
          onTap: () {
            if (exams.isNotEmpty) {
              onStartExam(exams.first);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Chưa có đề thi nào. Admin hãy import đề thi để bắt đầu luyện tập!'),
                ),
              );
            }
          },
        ),
        const SizedBox(height: 28),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'ĐỀ THI ĐÃ CÓ SẴN',
              style: TextStyle(
                color: kTextMuted,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
              ),
            ),
            Text(
              '${exams.length} đề thi',
              style: const TextStyle(color: kPrimaryBlue, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (exams.isEmpty)
          const _FigmaEmptyStateCard(isSearching: false)
        else
          for (final exam in exams)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ExamCard(exam: exam, onTap: () => onStartExam(exam)),
            ),
      ],
    );
  }
}

class _PartCard extends StatelessWidget {
  final int partNumber;
  final String title;
  final String subtitle;
  final String duration;
  final Color color;
  final VoidCallback onTap;

  const _PartCard({
    required this.partNumber,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kCardBg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorderColor, width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  'P$partNumber',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: kTextDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: kTextMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    duration,
                    style: const TextStyle(
                      color: kTextMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Icon(Icons.chevron_right_rounded, color: kTextHint),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// TAB 3 (USER): TIẾN ĐỘ HỌC TẬP
// ============================================================================
class _ProgressTab extends StatelessWidget {
  final VoidCallback onOpenProfile;

  const _ProgressTab({required this.onOpenProfile});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'TIẾN ĐỘ HỌC TẬP',
                  style: TextStyle(
                    color: kPrimaryBlue,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Thống kê cá nhân',
                  style: TextStyle(
                    color: kTextDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.account_circle_outlined, color: kPrimaryBlue, size: 28),
              onPressed: onOpenProfile,
            ),
          ],
        ),
        const SizedBox(height: 20),

        Row(
          children: const [
            Expanded(
              child: _MetricCard(
                icon: Icons.local_fire_department_rounded,
                iconColor: Color(0xFFEF4444),
                value: '14 ngày',
                label: 'Chuỗi học liên tiếp',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.check_circle_rounded,
                iconColor: kPrimaryBlue,
                value: '82.5%',
                label: 'Độ chính xác trung bình',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: const [
            Expanded(
              child: _MetricCard(
                icon: Icons.assignment_turned_in_rounded,
                iconColor: kSuccessGreen,
                value: '18 đề',
                label: 'Đã hoàn thành',
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                icon: Icons.timer_rounded,
                iconColor: kWarningAmber,
                value: '420 phút',
                label: 'Tổng thời gian luyện',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kBorderColor, width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: const [
                  Text(
                    'Hoạt động tuần này',
                    style: TextStyle(
                      color: kTextDark,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  Text(
                    'Mục tiêu: 5 buổi/tuần',
                    style: TextStyle(color: kPrimaryBlue, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _WeeklyChart(),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String value;
  final String label;

  const _MetricCard({
    required this.icon,
    required this.iconColor,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 26),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: kTextDark,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(color: kTextMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart();

  @override
  Widget build(BuildContext context) {
    final days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
    final heights = [0.75, 0.9, 0.45, 0.8, 0.65, 0.3, 0.1];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < 7; i++)
          Column(
            children: [
              Container(
                width: 28,
                height: 90 * heights[i],
                decoration: BoxDecoration(
                  color: i == 6 ? const Color(0xFFE2E8F0) : kPrimaryBlue,
                  borderRadius: BorderRadius.circular(7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                days[i],
                style: const TextStyle(
                  color: kTextMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

// ============================================================================
// ADMIN TAB 1: QUẢN LÝ ĐỀ & CHỈNH SỬA ĐỀ SAU KHI IMPORT
// ============================================================================
class _AdminTab extends StatefulWidget {
  final List<ExamItem> exams;
  final ValueChanged<ExamItem> onAddExam;
  final void Function(int index, ExamItem exam) onUpdateExam;
  final ValueChanged<int> onDeleteExam;
  final ValueChanged<ExamItem> onStartPractice;
  final VoidCallback onOpenProfile;
  final VoidCallback onSwitchToUser;

  const _AdminTab({
    required this.exams,
    required this.onAddExam,
    required this.onUpdateExam,
    required this.onDeleteExam,
    required this.onStartPractice,
    required this.onOpenProfile,
    required this.onSwitchToUser,
  });

  @override
  State<_AdminTab> createState() => _AdminTabState();
}

class _AdminTabState extends State<_AdminTab> {
  // Edit exam dialog (Basic Info)
  Future<void> _editExamBasicInfo(int index) async {
    final current = widget.exams[index];
    final titleController = TextEditingController(text: current.title);
    final countController = TextEditingController(text: '${current.questionCount}');
    final durationController = TextEditingController(text: '${current.durationMinutes}');

    final updated = await showDialog<ExamItem>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sửa thông tin đề thi'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Tên đề thi'),
            ),
            TextField(
              controller: countController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Số lượng câu hỏi'),
            ),
            TextField(
              controller: durationController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Thời lượng (phút)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kAdminAccent),
            onPressed: () {
              final count = int.tryParse(countController.text) ?? current.questionCount;
              final dur = int.tryParse(durationController.text) ?? current.durationMinutes;
              Navigator.pop(
                ctx,
                current.copyWith(
                  title: titleController.text.trim(),
                  questionCount: count,
                  durationMinutes: dur,
                ),
              );
            },
            child: const Text('Lưu'),
          ),
        ],
      ),
    );

    if (updated != null) {
      widget.onUpdateExam(index, updated);
      if (updated.id > 0) {
        ToeicApiService.updateExamInfo(updated.id, updated.title, updated.durationMinutes);
      }
    }
  }

  // Full Question Editor (Chỉnh sửa chi tiết câu hỏi & đáp án của đề thi)
  void _openFullQuestionEditor(int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminExamQuestionsEditorPage(
          exam: widget.exams[index],
          onSave: (updatedExam) {
            widget.onUpdateExam(index, updatedExam);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'KHU VỰC QUẢN TRỊ VIÊN',
                  style: TextStyle(
                    color: kAdminAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Quản lý & Sửa đề thi',
                  style: TextStyle(
                    color: kTextDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.account_circle_outlined, color: kAdminAccent, size: 28),
              onPressed: widget.onOpenProfile,
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Quick button to view user experience
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF3E8FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE9D5FF)),
          ),
          child: Row(
            children: [
              const Icon(Icons.preview_rounded, color: kAdminAccent, size: 20),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Bạn đang ở giao diện Admin. Bấm để xem thử với vai trò User.',
                  style: TextStyle(color: Color(0xFF581C87), fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: kAdminAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: widget.onSwitchToUser,
                child: const Text('Xem User', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DANH SÁCH ĐỀ THI (${widget.exams.length})',
              style: const TextStyle(
                color: kTextDark,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                final newExam = ExamItem(
                  id: DateTime.now().millisecondsSinceEpoch,
                  title: 'Đề thi TOEIC mới (Chưa đặt tên)',
                  durationMinutes: 75,
                  questionCount: 0,
                  questions: [],
                  passages: [],
                );
                widget.onAddExam(newExam);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã tạo đề thi mới. Bấm "Chỉnh sửa câu hỏi" để bắt đầu soạn đề!'),
                  ),
                );
              },
              icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
              label: const Text('Tạo đề mới'),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (widget.exams.isEmpty)
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: kCardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorderColor),
            ),
            alignment: Alignment.center,
            child: const Text(
              'Chưa có đề thi nào. Hãy sang tab "Import đề Word" để tải lên đề thi.',
              textAlign: TextAlign.center,
              style: TextStyle(color: kTextMuted, fontSize: 13),
            ),
          )
        else
          for (int i = 0; i < widget.exams.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorderColor, width: 1.2),
              ),
              child: ExpansionTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${i + 1}',
                    style: const TextStyle(
                      color: kAdminAccent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                title: Text(
                  widget.exams[i].title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
                subtitle: Text(
                  '${widget.exams[i].questionCount} câu · ${widget.exams[i].durationMinutes} phút',
                  style: const TextStyle(color: kTextMuted, fontSize: 12),
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                children: [
                  const Divider(color: kBorderColor),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      // Sửa chi tiết câu hỏi
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _openFullQuestionEditor(i),
                          icon: const Icon(Icons.edit_note_rounded, size: 18),
                          label: const Text('Sửa câu hỏi & đáp án'),
                          style: FilledButton.styleFrom(
                            backgroundColor: kAdminAccent,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Sửa thông tin chung
                      OutlinedButton.icon(
                        onPressed: () => _editExamBasicInfo(i),
                        icon: const Icon(Icons.settings_outlined, size: 16),
                        label: const Text('Sửa thông tin'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          textStyle: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton.icon(
                        onPressed: () => widget.onStartPractice(widget.exams[i]),
                        icon: const Icon(Icons.play_arrow_rounded, color: kPrimaryBlue),
                        label: const Text('Làm thử bài thi này', style: TextStyle(color: kPrimaryBlue)),
                      ),
                      IconButton(
                        tooltip: 'Xóa đề thi',
                        icon: const Icon(Icons.delete_outline_rounded, color: kErrorRed),
                        onPressed: () => widget.onDeleteExam(i),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }
}

// ============================================================================
// ADMIN TAB 2: IMPORT ĐỀ THI (WORD .DOCX & JSON)
// ============================================================================
class _AdminUploadTab extends StatefulWidget {
  final ValueChanged<ExamItem> onAddExam;
  final VoidCallback onOpenProfile;

  const _AdminUploadTab({
    required this.onAddExam,
    required this.onOpenProfile,
  });

  @override
  State<_AdminUploadTab> createState() => _AdminUploadTabState();
}

class _AdminUploadTabState extends State<_AdminUploadTab> {
  PlatformFile? _pickedFile;
  Uint8List? _pickedBytes;
  int _pickedFileSize = 0;
  bool _isUploading = false;
  String? _uploadStatusMessage;
  bool _uploadSuccess = false;

  final TextEditingController _jsonController = TextEditingController();
  String? _jsonError;

  final TextEditingController _serverController =
      TextEditingController(text: ToeicApiService.baseUrl);
  bool _serverConnected = false;

  @override
  void initState() {
    super.initState();
    _checkServerConnection();
  }

  @override
  void dispose() {
    _jsonController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  Future<void> _checkServerConnection() async {
    try {
      ToeicApiService.baseUrl = _serverController.text.trim();
      await ToeicApiService.fetchExams();
      if (mounted) {
        _serverController.text = ToeicApiService.baseUrl;
        setState(() => _serverConnected = true);
      }
    } catch (_) {
      if (mounted) setState(() => _serverConnected = false);
    }
  }

  Future<void> _pickWordFile() async {
    setState(() {
      _uploadStatusMessage = null;
      _uploadSuccess = false;
    });

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['docx'],
      );

      if (result.isNotEmpty) {
        final file = result.first;
        final bytes = await file.readAsBytes();
        final size = file.lengthSync() ?? (await file.length()) ?? bytes.length;
        setState(() {
          _pickedFile = file;
          _pickedBytes = bytes;
          _pickedFileSize = size;
          _uploadStatusMessage = 'Đã chọn file: ${file.name}';
        });
      }
    } catch (e) {
      setState(() {
        _uploadStatusMessage = 'Lỗi chọn file: $e';
        _uploadSuccess = false;
      });
    }
  }

  Future<void> _uploadWordFileToBackend() async {
    if (_pickedFile == null || _pickedBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn một file Word (.docx) trước!')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadStatusMessage = 'Đang tải lên và phân tích file Word...';
      _uploadSuccess = false;
    });

    try {
      final newExam = await ToeicApiService.uploadWordFile(
        bytes: _pickedBytes!,
        filename: _pickedFile!.name,
      );

      widget.onAddExam(newExam);

      setState(() {
        _isUploading = false;
        _uploadSuccess = true;
        _uploadStatusMessage =
            'Thành công! Đã tạo đề: "${newExam.title}" (${newExam.questionCount} câu, ${newExam.durationMinutes} phút).';
        _pickedFile = null;
        _pickedBytes = null;
        _pickedFileSize = 0;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: kSuccessGreen,
            content: Text('Đã tạo đề thi từ file Word: ${newExam.title}'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isUploading = false;
        _uploadSuccess = false;
        _uploadStatusMessage = 'Lỗi xử lý file Word: $e';
      });
    }
  }

  void _importJson() {
    try {
      final decoded = jsonDecode(_jsonController.text);
      final records = decoded is List ? decoded : [decoded];
      final imported = records.map((record) {
        if (record is! Map<String, dynamic>) {
          throw const FormatException('Mỗi đề phải là một JSON object.');
        }
        return ExamItem.fromJson(record);
      }).toList();

      for (final exam in imported) {
        widget.onAddExam(exam);
      }
      _jsonController.clear();
      setState(() => _jsonError = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: kSuccessGreen,
          content: Text('Đã thêm ${imported.length} đề thi thành công.'),
        ),
      );
    } catch (err) {
      setState(() => _jsonError = 'Lỗi JSON: $err');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'IMPORT ĐỀ THI',
                  style: TextStyle(
                    color: kAdminAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Tải lên đề Word (.docx)',
                  style: TextStyle(
                    color: kTextDark,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.account_circle_outlined, color: kAdminAccent, size: 28),
              onPressed: widget.onOpenProfile,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Server status
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _serverConnected ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _serverConnected ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
            ),
          ),
          child: Row(
            children: [
              Icon(
                _serverConnected ? Icons.check_circle_rounded : Icons.wifi_off_rounded,
                color: _serverConnected ? kSuccessGreen : kWarningAmber,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _serverConnected
                      ? 'Backend API đang hoạt động (${ToeicApiService.baseUrl})'
                      : 'Backend chưa kết nối (${ToeicApiService.baseUrl}) - Chế độ Demo',
                  style: TextStyle(
                    color: _serverConnected ? const Color(0xFF065F46) : const Color(0xFF92400E),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: _checkServerConnection,
                child: const Text('Kiểm tra', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // UPLOAD WORD CARD
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: kAdminAccent.withValues(alpha: 0.35), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: kAdminAccent.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.upload_file_rounded,
                  color: kAdminAccent,
                  size: 36,
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Tải lên file Word (.docx) chứa đề thi',
                style: TextStyle(
                  color: kTextDark,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Hệ thống tự động đọc cấu trúc câu hỏi, bài đọc Part 5, 6, 7 và đáp án.',
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextMuted, fontSize: 13),
              ),
              const SizedBox(height: 18),

              if (_pickedFile != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFD8B4FE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.description_rounded, color: kAdminAccent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '${_pickedFile!.name} (${(_pickedFileSize / 1024).toStringAsFixed(1)} KB)',
                          style: const TextStyle(
                            color: kTextDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18, color: kTextMuted),
                        onPressed: () => setState(() {
                          _pickedFile = null;
                          _pickedBytes = null;
                          _pickedFileSize = 0;
                        }),
                      ),
                    ],
                  ),
                ),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _isUploading ? null : _pickWordFile,
                      icon: const Icon(Icons.folder_open_rounded, size: 18),
                      label: Text(_pickedFile == null ? 'Chọn file Word' : 'Chọn file khác'),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kAdminAccent),
                        foregroundColor: kAdminAccent,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  if (_pickedFile != null) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _isUploading ? null : _uploadWordFileToBackend,
                        icon: _isUploading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cloud_upload_rounded, size: 18),
                        label: Text(_isUploading ? 'Đang tải...' : 'Tải lên & Tạo đề'),
                        style: FilledButton.styleFrom(
                          backgroundColor: kAdminAccent,
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),

              if (_uploadStatusMessage != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _uploadSuccess
                        ? const Color(0xFFECFDF5)
                        : const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _uploadSuccess
                          ? const Color(0xFFA7F3D0)
                          : const Color(0xFFFECACA),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _uploadSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                        color: _uploadSuccess ? kSuccessGreen : kErrorRed,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _uploadStatusMessage!,
                          style: TextStyle(
                            color: _uploadSuccess ? const Color(0xFF065F46) : kErrorRed,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),

        // FORMAT GUIDE
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: const Text(
              'Xem định dạng chuẩn của file Word (.docx)',
              style: TextStyle(
                color: kAdminAccent,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            leading: const Icon(Icons.help_outline_rounded, color: kAdminAccent),
            backgroundColor: kCardBg,
            collapsedBackgroundColor: kCardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: kBorderColor),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: kBorderColor),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            children: const [
              Text(
                'TITLE: Đề thi TOEIC Reading Test 01\n'
                'DURATION: 75\n\n'
                'PART 5\n'
                '101. Ms. Katherine has submitted ______ expense report.\n'
                'A. she\n'
                'B. her\n'
                'C. hers\n'
                'D. herself\n'
                'ANSWER: B\n\n'
                'PART 6\n'
                'PASSAGE:\n'
                'Nội dung bài đọc đoạn văn...\n'
                'END PASSAGE\n'
                '131. Over 25 providers will attend to ______ free screenings.\n'
                'A. offer\n'
                'B. offering\n'
                'C. offered\n'
                'D. offers\n'
                'ANSWER: A\n\n'
                'PART 7\n'
                'PASSAGE:\n'
                'NORTHSTAR BUSINESS CONFERENCE\n'
                'Please confirm attendance before Friday.\n'
                'END PASSAGE\n'
                '147. What should participants do before Friday?\n'
                'A. Call the hotel\n'
                'B. Confirm arrival time\n'
                'C. Pay a fee\n'
                'D. Bring invitation\n'
                'ANSWER: B',
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  color: kTextDark,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // IMPORT JSON
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: const Text(
              'Import dự phòng bằng JSON',
              style: TextStyle(
                color: kTextDark,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            leading: const Icon(Icons.code_rounded, color: kTextMuted),
            backgroundColor: kCardBg,
            collapsedBackgroundColor: kCardBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: kBorderColor),
            ),
            collapsedShape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: kBorderColor),
            ),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              TextField(
                controller: _jsonController,
                minLines: 4,
                maxLines: 7,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                decoration: InputDecoration(
                  hintText:
                      '[{"title":"TOEIC Mini Test 01","questionCount":30,"durationMinutes":45}]',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: kBorderColor),
                  ),
                  errorText: _jsonError,
                ),
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: _importJson,
                  icon: const Icon(Icons.input_rounded, size: 16),
                  label: const Text('Nhập JSON'),
                  style: FilledButton.styleFrom(
                    backgroundColor: kAdminAccent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// ADMIN: TRÌNH CHỈNH SỬA CHI TIẾT CÂU HỎI & ĐÁP ÁN (CHỈNH SỬA ĐỀ SAU KHI IMPORT)
// ============================================================================
class AdminExamQuestionsEditorPage extends StatefulWidget {
  final ExamItem exam;
  final ValueChanged<ExamItem> onSave;

  const AdminExamQuestionsEditorPage({
    super.key,
    required this.exam,
    required this.onSave,
  });

  @override
  State<AdminExamQuestionsEditorPage> createState() =>
      _AdminExamQuestionsEditorPageState();
}

class _AdminExamQuestionsEditorPageState
    extends State<AdminExamQuestionsEditorPage> {
  late ExamItem _editableExam;
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _editableExam = widget.exam.clone();
    if (_editableExam.questions.isEmpty && _editableExam.id > 0) {
      _loadQuestions();
    }
  }

  Future<void> _loadQuestions() async {
    setState(() => _isLoading = true);
    try {
      final loaded = await ToeicApiService.fetchForEdit(_editableExam.id);
      if (mounted) {
        setState(() {
          _editableExam = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: kErrorRed,
            content: Text('Không tải được câu hỏi từ máy chủ: $e'),
          ),
        );
      }
    }
  }

  void _editSingleQuestion(int index) async {
    final q = _editableExam.questions[index];
    final textController = TextEditingController(text: q.text ?? '');
    final optAController = TextEditingController(
        text: q.options.firstWhere((o) => o.label == 'A', orElse: () => OptionItem(label: 'A', content: '')).content);
    final optBController = TextEditingController(
        text: q.options.firstWhere((o) => o.label == 'B', orElse: () => OptionItem(label: 'B', content: '')).content);
    final optCController = TextEditingController(
        text: q.options.firstWhere((o) => o.label == 'C', orElse: () => OptionItem(label: 'C', content: '')).content);
    final optDController = TextEditingController(
        text: q.options.firstWhere((o) => o.label == 'D', orElse: () => OptionItem(label: 'D', content: '')).content);
    final explainController = TextEditingController(text: q.explanation ?? '');
    String selectedAns = q.isAllCorrect
        ? '*'
        : ((q.correctAnswer != null && ['A', 'B', 'C', 'D'].contains(q.correctAnswer!.toUpperCase()))
            ? q.correctAnswer!.toUpperCase()
            : 'A');

    final result = await showDialog<QuestionItem>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          title: Text('Chỉnh sửa Câu ${q.number} (Part ${q.part})'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: textController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung câu hỏi',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                const Text('CÁC PHƯƠNG ÁN LỰA CHỌN:', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
                const SizedBox(height: 8),
                TextField(
                  controller: optAController,
                  decoration: const InputDecoration(labelText: 'Đáp án A', isDense: true),
                ),
                TextField(
                  controller: optBController,
                  decoration: const InputDecoration(labelText: 'Đáp án B', isDense: true),
                ),
                TextField(
                  controller: optCController,
                  decoration: const InputDecoration(labelText: 'Đáp án C', isDense: true),
                ),
                TextField(
                  controller: optDController,
                  decoration: const InputDecoration(labelText: 'Đáp án D', isDense: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Text('Đáp án đúng: ', style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: selectedAns,
                      items: const [
                        DropdownMenuItem(value: 'A', child: Text('Đáp án A')),
                        DropdownMenuItem(value: 'B', child: Text('Đáp án B')),
                        DropdownMenuItem(value: 'C', child: Text('Đáp án C')),
                        DropdownMenuItem(value: 'D', child: Text('Đáp án D')),
                        DropdownMenuItem(
                          value: '*',
                          child: Text(
                            '🌟 Tất cả đều đúng (A, B, C, D)',
                            style: TextStyle(color: kSuccessGreen, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) setDlgState(() => selectedAns = val);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: explainController,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Giải thích đáp án',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: kAdminAccent),
              onPressed: () {
                final updatedQ = QuestionItem(
                  id: q.id,
                  part: q.part,
                  number: q.number,
                  text: textController.text.trim(),
                  passageContent: q.passageContent,
                  passageOrderIndex: q.passageOrderIndex,
                  options: [
                    OptionItem(label: 'A', content: optAController.text.trim()),
                    OptionItem(label: 'B', content: optBController.text.trim()),
                    OptionItem(label: 'C', content: optCController.text.trim()),
                    OptionItem(label: 'D', content: optDController.text.trim()),
                  ],
                  correctAnswer: selectedAns,
                  explanation: explainController.text.trim(),
                );
                Navigator.pop(ctx, updatedQ);
              },
              child: const Text('Lưu câu này'),
            ),
          ],
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _editableExam.questions[index] = result;
      });
    }
  }

  void _addNewQuestion() {
    final newNumber = _editableExam.questions.isEmpty
        ? 101
        : _editableExam.questions.map((q) => q.number).reduce((a, b) => a > b ? a : b) + 1;

    setState(() {
      _editableExam.questions.add(
        QuestionItem(
          id: DateTime.now().millisecondsSinceEpoch,
          part: newNumber <= 130 ? 5 : (newNumber <= 146 ? 6 : 7),
          number: newNumber,
          text: 'Câu hỏi mới được tạo thêm...',
          options: [
            OptionItem(label: 'A', content: 'Phương án A'),
            OptionItem(label: 'B', content: 'Phương án B'),
            OptionItem(label: 'C', content: 'Phương án C'),
            OptionItem(label: 'D', content: 'Phương án D'),
          ],
          correctAnswer: 'A',
          explanation: 'Giải thích cho câu hỏi...',
        ),
      );
      _editableExam.questionCount = _editableExam.questions.length;
    });
  }

  void _deleteQuestion(int index) {
    setState(() {
      _editableExam.questions.removeAt(index);
      _editableExam.questionCount = _editableExam.questions.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Sửa câu hỏi: ${_editableExam.title}',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: _isSaving
                  ? null
                  : () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final nav = Navigator.of(context);
                      setState(() => _isSaving = true);
                      try {
                        if (_editableExam.id > 0) {
                          await ToeicApiService.updateExam(_editableExam);
                        }
                        if (mounted) {
                          widget.onSave(_editableExam);
                          nav.pop();
                          messenger.showSnackBar(
                            const SnackBar(
                              backgroundColor: kSuccessGreen,
                              content: Text('Đã cập nhật các thay đổi của đề thi thành công!'),
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          setState(() => _isSaving = false);
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: kErrorRed,
                              content: Text('Không thể lưu lên máy chủ: $e'),
                            ),
                          );
                        }
                      }
                    },
              icon: _isSaving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.check_rounded, size: 16),
              label: Text(_isSaving ? 'Đang lưu...' : 'Lưu tất cả', style: const TextStyle(fontSize: 12)),
              style: FilledButton.styleFrom(
                backgroundColor: kAdminAccent,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: kAdminAccent),
                    const SizedBox(height: 18),
                    Text(
                      'Đang tải ${_editableExam.questionCount > 0 ? "${_editableExam.questionCount} " : ""}câu hỏi & đáp án từ máy chủ...',
                      style: const TextStyle(
                        color: kTextDark,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Vui lòng chờ trong giây lát...',
                      style: TextStyle(color: kTextMuted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'TỔNG SỐ CÂU HỎI: ${_editableExam.questions.length}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        color: kTextMuted,
                        letterSpacing: 0.8,
                      ),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: _addNewQuestion,
                      icon: const Icon(Icons.add_rounded, size: 16),
                      label: const Text('Thêm câu', style: TextStyle(fontSize: 12)),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        for (var q in _editableExam.questions) {
                          q.correctAnswer = '*';
                        }
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          backgroundColor: kSuccessGreen,
                          content: Text('Đã cài đặt tất cả câu: 4 đáp án (A, B, C, D) đều đúng! Bấm "Lưu tất cả" để lưu vào hệ thống.'),
                        ),
                      );
                    },
                    icon: const Icon(Icons.done_all_rounded, size: 18),
                    label: const Text('Cài 4 đáp án đều đúng (1-Click)'),
                    style: FilledButton.styleFrom(
                      backgroundColor: kSuccessGreen,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                if (_editableExam.questions.isEmpty)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 24),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: kCardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBorderColor),
                    ),
                    alignment: Alignment.center,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.quiz_outlined, size: 48, color: kTextMuted),
                        const SizedBox(height: 12),
                        const Text(
                          'Đề thi này hiện chưa có câu hỏi nào.',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _loadQuestions,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Thử tải lại từ máy chủ'),
                        ),
                      ],
                    ),
                  )
                else
                  for (int i = 0; i < _editableExam.questions.length; i++) ...[
                    _AdminQuestionListItem(
                      index: i,
                      question: _editableExam.questions[i],
                      onEdit: () => _editSingleQuestion(i),
                      onDelete: () => _deleteQuestion(i),
                    ),
                    const SizedBox(height: 10),
                  ],
              ],
            ),
    );
  }
}

class _AdminQuestionListItem extends StatelessWidget {
  final int index;
  final QuestionItem question;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _AdminQuestionListItem({
    required this.index,
    required this.question,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'CÂU ${question.number} (P${question.part})',
                  style: const TextStyle(
                    color: kAdminAccent,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: kAdminAccent),
                tooltip: 'Sửa câu này',
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: kErrorRed),
                tooltip: 'Xóa câu này',
                onPressed: onDelete,
              ),
            ],
          ),
          if (question.text != null) ...[
            const SizedBox(height: 6),
            Text(
              question.text!,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final opt in question.options)
                Text(
                  '${opt.label}. ${opt.content}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: (question.isAllCorrect || opt.label == question.correctAnswer)
                        ? FontWeight.w800
                        : FontWeight.normal,
                    color: (question.isAllCorrect || opt.label == question.correctAnswer)
                        ? kSuccessGreen
                        : kTextMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 15,
                color: kSuccessGreen,
              ),
              const SizedBox(width: 4),
              Text(
                question.isAllCorrect
                    ? 'Đáp án đúng: Tất cả đều đúng (A, B, C, D)'
                    : 'Đáp án đúng: ${question.correctAnswer ?? "Chưa đặt"}',
                style: const TextStyle(
                  color: kSuccessGreen,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// PRACTICE EXAM PAGE (USER: LÀM BÀI THI)
// ============================================================================
class ReadingPracticePage extends StatefulWidget {
  final ExamItem exam;

  const ReadingPracticePage({super.key, required this.exam});

  @override
  State<ReadingPracticePage> createState() => _ReadingPracticePageState();
}

class _ReadingPracticePageState extends State<ReadingPracticePage> {
  late ExamItem _activeExam;
  bool _isLoadingContent = false;
  int _currentIndex = 0;
  final Map<int, String> _userAnswers = {}; // questionIndex -> "A", "B", "C", "D"
  Timer? _timer;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _activeExam = widget.exam;
    _remainingSeconds = _activeExam.durationMinutes * 60;
    _startTimer();

    if (_activeExam.questions.isEmpty) {
      _loadExamQuestions();
    }
  }

  Future<void> _loadExamQuestions() async {
    setState(() => _isLoadingContent = true);
    try {
      final loaded = await ToeicApiService.fetchForPractice(_activeExam.id);
      if (mounted) {
        setState(() {
          _activeExam = loaded;
          _isLoadingContent = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingContent = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đề thi này chưa có nội dung câu hỏi hoặc chưa lưu trên máy chủ.'),
          ),
        );
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _submitExam(autoSubmit: true);
      } else {
        setState(() => _remainingSeconds--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatTimer(int totalSecs) {
    final m = (totalSecs ~/ 60).toString().padLeft(2, '0');
    final s = (totalSecs % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _submitExam({bool autoSubmit = false}) {
    _timer?.cancel();

    final questions = _activeExam.questions;
    int correctCount = 0;
    for (int i = 0; i < questions.length; i++) {
      final q = questions[i];
      final userAns = _userAnswers[i];
      if (userAns != null) {
        if (q.isAllCorrect ||
            (q.correctAnswer != null &&
                userAns.trim().toUpperCase() == q.correctAnswer!.trim().toUpperCase())) {
          correctCount++;
        }
      }
    }

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => ReadingResultPage(
          exam: _activeExam,
          userAnswers: _userAnswers,
          correctCount: correctCount,
          totalQuestions: questions.length,
          timeSpentSeconds: (_activeExam.durationMinutes * 60) - _remainingSeconds,
        ),
      ),
    );
  }

  Future<void> _showSubmitDialog() async {
    final unanswered = _activeExam.questions.length - _userAnswers.length;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nộp bài thi?'),
        content: Text(
          unanswered > 0
              ? 'Bạn còn $unanswered câu chưa trả lời. Bạn có chắc chắn muốn nộp bài bây giờ?'
              : 'Bạn đã trả lời đầy đủ các câu hỏi. Bạn có muốn nộp bài và xem kết quả ngay?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Làm tiếp'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: kPrimaryBlue),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Nộp bài'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _submitExam();
    }
  }

  void _openQuestionPalette() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Danh sách câu hỏi',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: kTextDark,
                  ),
                ),
                Text(
                  'Đã làm: ${_userAnswers.length}/${_activeExam.questions.length}',
                  style: const TextStyle(color: kPrimaryBlue, fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < _activeExam.questions.length; i++)
                  InkWell(
                    onTap: () {
                      setState(() => _currentIndex = i);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: _currentIndex == i
                            ? kPrimaryBlue
                            : (_userAnswers.containsKey(i) ? kLightBlueBg : const Color(0xFFF1F5F9)),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _currentIndex == i
                              ? kPrimaryBlue
                              : (_userAnswers.containsKey(i) ? const Color(0xFF93C5FD) : kBorderColor),
                        ),
                      ),
                      child: Text(
                        '${_activeExam.questions[i].number}',
                        style: TextStyle(
                          color: _currentIndex == i
                              ? Colors.white
                              : (_userAnswers.containsKey(i) ? kPrimaryBlue : kTextDark),
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingContent) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Đang tải nội dung bài thi...'),
            ],
          ),
        ),
      );
    }

    final questions = _activeExam.questions;
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(_activeExam.title)),
        body: const Center(child: Text('Đề thi này chưa có nội dung câu hỏi.')),
      );
    }

    final currentQ = questions[_currentIndex];
    final selectedOption = _userAnswers[_currentIndex];

    PassageItem? currentPassage;
    if (currentQ.passageOrderIndex != null && _activeExam.passages.isNotEmpty) {
      currentPassage = _activeExam.passages.firstWhere(
        (p) => p.orderIndex == currentQ.passageOrderIndex,
        orElse: () => _activeExam.passages.first,
      );
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: kTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          _activeExam.title,
          style: const TextStyle(
            color: kTextDark,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(right: 12),
            decoration: BoxDecoration(
              color: _remainingSeconds < 300 ? const Color(0xFFFEE2E2) : kLightBlueBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.timer_outlined,
                  size: 16,
                  color: _remainingSeconds < 300 ? kErrorRed : kPrimaryBlue,
                ),
                const SizedBox(width: 5),
                Text(
                  _formatTimer(_remainingSeconds),
                  style: TextStyle(
                    color: _remainingSeconds < 300 ? kErrorRed : kPrimaryBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentIndex + 1) / questions.length,
            backgroundColor: const Color(0xFFE2E8F0),
            color: kPrimaryBlue,
            minHeight: 3.5,
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kLightBlueBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'PART ${currentQ.part} · CÂU ${currentQ.number}',
                        style: const TextStyle(
                          color: kPrimaryBlue,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    Text(
                      'Câu ${_currentIndex + 1} / ${questions.length}',
                      style: const TextStyle(
                        color: kTextMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (currentPassage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: kBorderColor, width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (currentPassage.rangeText != null) ...[
                          Text(
                            currentPassage.rangeText!.toUpperCase(),
                            style: const TextStyle(
                              color: kPrimaryBlue,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Text(
                          currentPassage.content,
                          style: const TextStyle(
                            color: kTextDark,
                            fontSize: 13.5,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                if (currentQ.text != null && currentQ.text!.isNotEmpty)
                  Text(
                    currentQ.text!,
                    style: const TextStyle(
                      color: kTextDark,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                const SizedBox(height: 16),

                for (final opt in currentQ.options) ...[
                  _PracticeOptionWidget(
                    label: opt.label,
                    content: opt.content,
                    isSelected: selectedOption == opt.label,
                    onTap: () {
                      setState(() {
                        _userAnswers[_currentIndex] = opt.label;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
          ),

          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: kBorderColor)),
            ),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _openQuestionPalette,
                  icon: const Icon(Icons.grid_view_rounded, size: 16),
                  label: Text('${_currentIndex + 1}/${questions.length}'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: kBorderColor),
                    foregroundColor: kTextDark,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
                const SizedBox(width: 8),

                IconButton(
                  icon: const Icon(Icons.arrow_back_rounded),
                  tooltip: 'Câu trước',
                  onPressed: _currentIndex > 0
                      ? () => setState(() => _currentIndex--)
                      : null,
                ),

                IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  tooltip: 'Câu tiếp theo',
                  onPressed: _currentIndex < questions.length - 1
                      ? () => setState(() => _currentIndex++)
                      : null,
                ),
                const Spacer(),

                FilledButton(
                  onPressed: _showSubmitDialog,
                  style: FilledButton.styleFrom(
                    backgroundColor: kPrimaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Nộp bài', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeOptionWidget extends StatelessWidget {
  final String label;
  final String content;
  final bool isSelected;
  final VoidCallback onTap;

  const _PracticeOptionWidget({
    required this.label,
    required this.content,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? kLightBlueBg : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? kPrimaryBlue : kBorderColor,
              width: isSelected ? 1.8 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryBlue : const Color(0xFFF1F5F9),
                  shape: BoxShape.circle,
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : kTextDark,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  content,
                  style: TextStyle(
                    color: kTextDark,
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// RESULT PAGE (USER: HIỂN THỊ KẾT QUẢ BÀI THI)
// ============================================================================
class ReadingResultPage extends StatelessWidget {
  final ExamItem exam;
  final Map<int, String> userAnswers;
  final int correctCount;
  final int totalQuestions;
  final int timeSpentSeconds;

  const ReadingResultPage({
    super.key,
    required this.exam,
    required this.userAnswers,
    required this.correctCount,
    required this.totalQuestions,
    required this.timeSpentSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final double percentage =
        totalQuestions == 0 ? 0 : (correctCount / totalQuestions) * 100;

    final String minutes = (timeSpentSeconds ~/ 60).toString();
    final String seconds = (timeSpentSeconds % 60).toString().padLeft(2, '0');

    // Estimated TOEIC Reading Score (Scaled 5 - 495)
    final int scaledScore = (percentage * 4.9).round() + 5;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text(
          'Kết quả bài làm',
          style: TextStyle(color: kTextDark, fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: kBorderColor, width: 1.2),
            ),
            child: Column(
              children: [
                Icon(
                  percentage >= 70 ? Icons.check_circle_rounded : Icons.stars_rounded,
                  size: 64,
                  color: percentage >= 70 ? kSuccessGreen : kPrimaryBlue,
                ),
                const SizedBox(height: 14),
                Text(
                  exam.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: kTextDark,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '$correctCount / $totalQuestions câu đúng',
                  style: const TextStyle(
                    color: kPrimaryBlue,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Điểm TOEIC Reading ước tính: $scaledScore / 495',
                  style: const TextStyle(
                    color: kSuccessGreen,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tỷ lệ chính xác: ${percentage.toStringAsFixed(1)}% · Thời gian: $minutes phút $seconds giây',
                  style: const TextStyle(color: kTextMuted, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'CHI TIẾT TỪNG CÂU HỎI & LỜI GIẢI',
            style: TextStyle(
              color: kPrimaryBlue,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 12),

          for (int i = 0; i < exam.questions.length; i++) ...[
            _ReviewQuestionWidget(
              index: i,
              question: exam.questions[i],
              userAnswer: userAnswers[i],
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
            icon: const Icon(Icons.home_rounded),
            label: const Text('Về trang chính'),
            style: FilledButton.styleFrom(
              backgroundColor: kPrimaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewQuestionWidget extends StatelessWidget {
  final int index;
  final QuestionItem question;
  final String? userAnswer;

  const _ReviewQuestionWidget({
    required this.index,
    required this.question,
    required this.userAnswer,
  });

  @override
  Widget build(BuildContext context) {
    final bool isCorrect = userAnswer != null &&
        (question.isAllCorrect ||
            (question.correctAnswer != null &&
                userAnswer!.trim().toUpperCase() == question.correctAnswer!.trim().toUpperCase()));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCorrect
              ? const Color(0xFFA7F3D0)
              : (userAnswer != null ? const Color(0xFFFECACA) : kBorderColor),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Câu ${question.number} (Part ${question.part})',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const Spacer(),
              if (isCorrect)
                const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: kSuccessGreen, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Đúng',
                      style: TextStyle(
                        color: kSuccessGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              else if (userAnswer != null)
                const Row(
                  children: [
                    Icon(Icons.cancel_rounded, color: kErrorRed, size: 16),
                    SizedBox(width: 4),
                    Text(
                      'Sai',
                      style: TextStyle(
                        color: kErrorRed,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              else
                const Text(
                  'Chưa trả lời',
                  style: TextStyle(color: kTextMuted, fontSize: 12),
                ),
            ],
          ),
          if (question.text != null) ...[
            const SizedBox(height: 6),
            Text(
              question.text!,
              style: const TextStyle(color: kTextDark, fontSize: 13),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                'Bạn chọn: ${userAnswer ?? "(Trống)"}',
                style: TextStyle(
                  color: isCorrect ? kSuccessGreen : kErrorRed,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                question.isAllCorrect
                    ? 'Đáp án đúng: Tất cả đều đúng (A, B, C, D)'
                    : 'Đáp án đúng: ${question.correctAnswer ?? "N/A"}',
                style: const TextStyle(
                  color: kPrimaryBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (question.explanation != null) ...[
            const SizedBox(height: 6),
            Text(
              'Giải thích: ${question.explanation}',
              style: const TextStyle(color: kTextMuted, fontSize: 11.5, fontStyle: FontStyle.italic),
            ),
          ],
        ],
      ),
    );
  }
}
