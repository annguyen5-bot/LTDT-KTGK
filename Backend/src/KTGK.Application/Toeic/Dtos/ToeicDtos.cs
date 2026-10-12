using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;

namespace KTGK.Toeic.Dto;

/// <summary>Thông tin tóm tắt của một đề TOEIC.</summary>
public sealed record ExamSummaryDto(int Id, string Title, int DurationMinutes, int TotalQuestions);

/// <summary>Bài đọc thuộc một đề thi.</summary>
public sealed record PassageDto(int Id, int Part, int OrderIndex, string Content, string RangeText, string Instruction);

/// <summary>Một phương án trả lời.</summary>
public sealed record OptionDto(string Label, string Content);

/// <summary>Câu hỏi được trả về khi bắt đầu luyện tập.</summary>
public sealed record PracticeQuestionDto(
    int Id,
    int Part,
    int Number,
    string Text,
    string PassageContent,
    List<OptionDto> Options);

/// <summary>Nội dung đề thi dành cho người làm bài.</summary>
public sealed record ExamPracticeDto(
    int Id,
    string Title,
    int DurationMinutes,
    List<PassageDto> Passages,
    List<PracticeQuestionDto> Questions);

/// <summary>Câu hỏi kèm đáp án đúng cho quản trị viên xem và chỉnh sửa.</summary>
public sealed record EditQuestionDto(
    int Id,
    int Part,
    int Number,
    string Text,
    int? PassageOrderIndex,
    string PassageContent,
    string CorrectAnswer,
    List<OptionDto> Options);

/// <summary>Nội dung đầy đủ của đề thi bao gồm đáp án đúng dành cho quản trị viên.</summary>
public sealed record ExamEditDto(
    int Id,
    string Title,
    int DurationMinutes,
    int TotalQuestions,
    List<PassageDto> Passages,
    List<EditQuestionDto> Questions);

/// <summary>Thông tin cập nhật nhanh tiêu đề và thời gian làm bài.</summary>
public sealed record UpdateExamInfoDto(int Id, string Title, int DurationMinutes);

/// <summary>Đáp án người dùng chọn cho một câu.</summary>
public sealed record AnswerInput
{
    /// <summary>Mã câu hỏi.</summary>
    [Range(1, int.MaxValue)]
    public int QuestionId { get; init; }

    /// <summary>Nhãn đáp án A, B, C hoặc D; để trống nếu bỏ qua.</summary>
    [StringLength(1)]
    public string SelectedAnswer { get; init; }
}

/// <summary>Các đáp án được gửi khi nộp bài.</summary>
public sealed record SubmitExamInput
{
    /// <summary>Mã đề cần nộp.</summary>
    [Range(1, int.MaxValue)]
    public int ExamId { get; init; }

    /// <summary>Danh sách câu trả lời đã chọn.</summary>
    [Required]
    public List<AnswerInput> Answers { get; init; } = new();
}

/// <summary>Kết quả chấm cho một câu hỏi.</summary>
public sealed record QuestionResultDto(
    int QuestionId,
    string SelectedAnswer,
    string CorrectAnswer,
    bool IsCorrect);

/// <summary>Kết quả tổng hợp của một lượt làm bài.</summary>
public sealed record ExamResultDto(
    int AttemptId,
    string ExamTitle,
    int TotalQuestions,
    int CorrectCount,
    int WrongCount,
    int SkippedCount,
    decimal CorrectPercentage,
    List<QuestionResultDto> Answers);

/// <summary>Dữ liệu nhập cho một bài đọc.</summary>
public sealed record PassageInput
{
    /// <summary>Part của bài đọc.</summary>
    [Range(6, 7)]
    public int Part { get; init; }

    /// <summary>Thứ tự bài đọc trong đề.</summary>
    [Range(1, int.MaxValue)]
    public int OrderIndex { get; init; }

    /// <summary>Khoảng số câu của bài đọc.</summary>
    [StringLength(32)]
    public string RangeText { get; init; }

    /// <summary>Hướng dẫn làm bài.</summary>
    [StringLength(512)]
    public string Instruction { get; init; }

    /// <summary>Nội dung bài đọc.</summary>
    [Required]
    public string Content { get; init; }
}

/// <summary>Dữ liệu nhập cho một câu hỏi.</summary>
public sealed record QuestionInput
{
    /// <summary>Part của câu hỏi.</summary>
    [Range(5, 7)]
    public int Part { get; init; }

    /// <summary>Số thứ tự câu hỏi.</summary>
    [Range(1, 200)]
    public int Number { get; init; }

    /// <summary>Nội dung câu hỏi.</summary>
    public string Text { get; init; }

    /// <summary>Thứ tự bài đọc liên kết, bắt buộc với Part 6 và Part 7.</summary>
    public int? PassageOrderIndex { get; init; }

    /// <summary>Nhãn đáp án đúng: A, B, C, D hoặc * (tất cả đều đúng).</summary>
    [Required, StringLength(10)]
    public string CorrectAnswer { get; init; }

    /// <summary>Bốn lựa chọn A, B, C và D.</summary>
    [Required]
    public List<OptionInput> Options { get; init; } = new();
}

/// <summary>Dữ liệu nhập cho một phương án trả lời.</summary>
public sealed record OptionInput
{
    /// <summary>Nhãn lựa chọn.</summary>
    [Required, StringLength(1)]
    public string Label { get; init; }

    /// <summary>Nội dung lựa chọn.</summary>
    [Required, StringLength(1024)]
    public string Content { get; init; }
}

/// <summary>Payload nhập mới một đề thi cùng bài đọc và câu hỏi.</summary>
public sealed record ImportExamInput
{
    /// <summary>Tên đề thi.</summary>
    [Required, StringLength(KTGK.Toeic.Exam.MaxTitleLength)]
    public string Title { get; init; }

    /// <summary>Thời gian làm bài tính bằng phút.</summary>
    [Range(1, 300)]
    public int DurationMinutes { get; init; }

    /// <summary>Các bài đọc của đề.</summary>
    [Required]
    public List<PassageInput> Passages { get; init; } = new();

    /// <summary>Các câu hỏi của đề.</summary>
    [Required, MinLength(1)]
    public List<QuestionInput> Questions { get; init; } = new();
}

/// <summary>Payload cập nhật toàn bộ nội dung của một đề thi.</summary>
public sealed record UpdateExamInput
{
    /// <summary>Mã đề cần cập nhật.</summary>
    [Range(1, int.MaxValue)]
    public int Id { get; init; }

    /// <summary>Tên đề thi.</summary>
    [Required, StringLength(KTGK.Toeic.Exam.MaxTitleLength)]
    public string Title { get; init; }

    /// <summary>Thời gian làm bài tính bằng phút.</summary>
    [Range(1, 300)]
    public int DurationMinutes { get; init; }

    /// <summary>Các bài đọc của đề (tùy chọn khi cập nhật).</summary>
    public List<PassageInput> Passages { get; init; } = new();

    /// <summary>Các câu hỏi của đề.</summary>
    [Required, MinLength(1)]
    public List<QuestionInput> Questions { get; init; } = new();
}