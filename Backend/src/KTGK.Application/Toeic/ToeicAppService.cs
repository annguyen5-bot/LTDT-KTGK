using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Abp.Application.Services;
using Abp.Application.Services.Dto;
using Abp.Authorization;
using Abp.Domain.Repositories;
using Abp.UI;
using KTGK.Authorization;
using KTGK.Toeic.Dto;
using Microsoft.EntityFrameworkCore;

namespace KTGK.Toeic;

/// <summary>Cung cấp API quản lý đề và luyện tập TOEIC.</summary>
public sealed class ToeicAppService : ApplicationService
{
    private static readonly string[] OptionLabels = ["A", "B", "C", "D"];

    private readonly IRepository<Exam, int> _examRepository;
    private readonly IRepository<ExamAttempt, int> _attemptRepository;
    private readonly IRepository<AttemptAnswer, int> _attemptAnswerRepository;
    private readonly IRepository<Question, int> _questionRepository;
    private readonly IRepository<PassageGroup, int> _passageRepository;

    /// <summary>Tạo dịch vụ đọc đề thi và lưu kết quả làm bài.</summary>
    public ToeicAppService(
        IRepository<Exam, int> examRepository,
        IRepository<ExamAttempt, int> attemptRepository,
        IRepository<AttemptAnswer, int> attemptAnswerRepository,
        IRepository<Question, int> questionRepository,
        IRepository<PassageGroup, int> passageRepository)
    {
        _examRepository = examRepository;
        _attemptRepository = attemptRepository;
        _attemptAnswerRepository = attemptAnswerRepository;
        _questionRepository = questionRepository;
        _passageRepository = passageRepository;
    }

    /// <summary>Trả về danh sách đề thi hiện có.</summary>
    public async Task<List<ExamSummaryDto>> GetExamsAsync()
    {
        var exams = await _examRepository.GetAll()
            .OrderBy(exam => exam.Title)
            .ToListAsync();

        return exams.Select(exam => new ExamSummaryDto(
            exam.Id,
            exam.Title,
            exam.DurationMinutes,
            exam.TotalQuestions)).ToList();
    }

    /// <summary>Trả về nội dung đề thi, không bao gồm đáp án đúng.</summary>
    public async Task<ExamPracticeDto> GetForPracticeAsync(EntityDto<int> input)
    {
        var exam = await GetExamWithQuestionsAsync(input.Id);
        if (exam == null)
        {
            throw new UserFriendlyException("Không tìm thấy đề thi.");
        }

        var passages = exam.Passages.OrderBy(passage => passage.OrderIndex).ToList();
        var questions = exam.Questions.OrderBy(question => question.Number).Select(question => new PracticeQuestionDto(
            question.Id,
            question.Part,
            question.Number,
            question.Text,
            question.PassageGroup?.Content,
            question.Options.OrderBy(option => option.Label).Select(option => new OptionDto(option.Label, option.Content)).ToList())).ToList();

        return new ExamPracticeDto(
            exam.Id,
            exam.Title,
            exam.DurationMinutes,
            passages.Select(passage => new PassageDto(
                passage.Id,
                passage.Part,
                passage.OrderIndex,
                passage.Content,
                passage.RangeText,
                passage.Instruction)).ToList(),
            questions);
    }

    /// <summary>Trả về đầy đủ thông tin đề thi bao gồm đáp án đúng dành cho quản trị viên xem và chỉnh sửa.</summary>
    public async Task<ExamEditDto> GetForEditAsync(EntityDto<int> input)
    {
        var exam = await GetExamWithQuestionsAsync(input.Id);
        if (exam == null)
        {
            throw new UserFriendlyException("Không tìm thấy đề thi.");
        }

        var passages = exam.Passages.OrderBy(passage => passage.OrderIndex).ToList();
        var questions = exam.Questions.OrderBy(question => question.Number).Select(question => new EditQuestionDto(
            question.Id,
            question.Part,
            question.Number,
            question.Text,
            question.PassageGroup?.OrderIndex,
            question.PassageGroup?.Content,
            question.CorrectAnswer,
            question.Options.OrderBy(option => option.Label).Select(option => new OptionDto(option.Label, option.Content)).ToList())).ToList();

        return new ExamEditDto(
            exam.Id,
            exam.Title,
            exam.DurationMinutes,
            exam.TotalQuestions,
            passages.Select(passage => new PassageDto(
                passage.Id,
                passage.Part,
                passage.OrderIndex,
                passage.Content,
                passage.RangeText,
                passage.Instruction)).ToList(),
            questions);
    }

    /// <summary>Nhập đề thi cùng bài đọc, câu hỏi và lựa chọn.</summary>
    public async Task<ExamSummaryDto> ImportExamAsync(ImportExamInput input)
    {
        ValidateExam(input);
        var exam = CreateExam(input);
        await _examRepository.InsertAsync(exam);
        await CurrentUnitOfWork.SaveChangesAsync();
        return ToSummary(exam);
    }

    /// <summary>Cập nhật toàn bộ đề thi nếu cần sửa câu hỏi hoặc bài đọc.</summary>
    public async Task<ExamSummaryDto> UpdateExamAsync(UpdateExamInput input)
    {
        var exam = await GetExamWithQuestionsAsync(input.Id);
        if (exam == null)
        {
            throw new UserFriendlyException("Không tìm thấy đề thi.");
        }

        if (!string.IsNullOrWhiteSpace(input.Title))
        {
            exam.Title = input.Title.Trim();
        }
        if (input.DurationMinutes > 0)
        {
            exam.DurationMinutes = input.DurationMinutes;
        }

        // Cập nhật câu hỏi và đáp án
        if (input.Questions != null && input.Questions.Count > 0)
        {
            var existingByNumber = exam.Questions.ToDictionary(q => q.Number);
            var incomingNumbers = input.Questions.Select(q => q.Number).ToHashSet();

            // Xóa câu hỏi đã bị gỡ khỏi đề (nếu có)
            foreach (var q in exam.Questions.Where(q => !incomingNumbers.Contains(q.Number)).ToList())
            {
                await _questionRepository.DeleteAsync(q);
                exam.Questions.Remove(q);
            }

            foreach (var qInput in input.Questions)
            {
                var ca = qInput.CorrectAnswer?.Trim().ToUpperInvariant() ?? "*";
                if (ca is "ALL" or "ABCD") ca = "*";

                if (existingByNumber.TryGetValue(qInput.Number, out var existingQ))
                {
                    if (qInput.Text != null) existingQ.Text = qInput.Text;
                    existingQ.CorrectAnswer = ca;

                    if (qInput.Options != null)
                    {
                        foreach (var optInput in qInput.Options)
                        {
                            var optLabel = optInput.Label?.Trim().ToUpperInvariant();
                            var existingOpt = existingQ.Options.FirstOrDefault(o => o.Label == optLabel);
                            if (existingOpt != null)
                            {
                                existingOpt.Content = optInput.Content?.Trim() ?? "";
                            }
                        }
                    }
                }
                else
                {
                    var newQ = new Question
                    {
                        Part = qInput.Part,
                        Number = qInput.Number,
                        Text = qInput.Text,
                        CorrectAnswer = ca,
                        Exam = exam,
                        ExamId = exam.Id
                    };
                    if (qInput.Options != null)
                    {
                        foreach (var opt in qInput.Options)
                        {
                            newQ.Options.Add(new QuestionOption
                            {
                                Label = opt.Label.Trim().ToUpperInvariant(),
                                Content = opt.Content?.Trim() ?? "",
                                Question = newQ
                            });
                        }
                    }
                    await _questionRepository.InsertAsync(newQ);
                    exam.Questions.Add(newQ);
                }
            }
            exam.TotalQuestions = exam.Questions.Count;
        }

        await CurrentUnitOfWork.SaveChangesAsync();
        return ToSummary(exam);
    }

    /// <summary>Cập nhật thông tin tiêu đề và thời gian của đề thi.</summary>
    public async Task<ExamSummaryDto> UpdateExamInfoAsync(UpdateExamInfoDto input)
    {
        var exam = await _examRepository.FirstOrDefaultAsync(input.Id);
        if (exam == null)
        {
            throw new UserFriendlyException("Không tìm thấy đề thi.");
        }

        if (string.IsNullOrWhiteSpace(input.Title))
        {
            throw new UserFriendlyException("Tên đề thi không được để trống.");
        }

        exam.Title = input.Title.Trim();
        if (input.DurationMinutes > 0)
        {
            exam.DurationMinutes = input.DurationMinutes;
        }

        await _examRepository.UpdateAsync(exam);
        await CurrentUnitOfWork.SaveChangesAsync();
        return ToSummary(exam);
    }

    /// <summary>Xóa đề thi cùng toàn bộ câu hỏi và bài đọc liên quan.</summary>
    public async Task DeleteExamAsync(EntityDto<int> input)
    {
        var exam = await GetExamWithQuestionsAsync(input.Id);
        if (exam == null)
        {
            return;
        }

        var attempts = await _attemptRepository.GetAllListAsync(attempt => attempt.ExamId == exam.Id);
        foreach (var attempt in attempts)
        {
            var answers = await _attemptAnswerRepository.GetAllListAsync(ans => ans.AttemptId == attempt.Id);
            foreach (var ans in answers)
            {
                await _attemptAnswerRepository.DeleteAsync(ans);
            }
            await _attemptRepository.DeleteAsync(attempt);
        }
        await CurrentUnitOfWork.SaveChangesAsync();

        foreach (var question in exam.Questions.ToList())
        {
            await _questionRepository.DeleteAsync(question);
        }

        foreach (var passage in exam.Passages.ToList())
        {
            await _passageRepository.DeleteAsync(passage);
        }

        await _examRepository.DeleteAsync(exam);
    }

    /// <summary>Chấm bài và lưu kết quả gắn với tài khoản hiện tại.</summary>
    public async Task<ExamResultDto> SubmitAsync(SubmitExamInput input)
    {
        var exam = await GetExamWithQuestionsAsync(input.ExamId);
        if (exam == null)
        {
            throw new UserFriendlyException("Không tìm thấy đề thi.");
        }

        if (input.Answers.Select(answer => answer.QuestionId).Distinct().Count() != input.Answers.Count)
        {
            throw new UserFriendlyException("Mỗi câu chỉ được gửi một đáp án.");
        }

        var questionById = exam.Questions.ToDictionary(question => question.Id);
        if (input.Answers.Any(answer => !questionById.ContainsKey(answer.QuestionId)))
        {
            throw new UserFriendlyException("Đáp án có câu hỏi không thuộc đề thi này.");
        }

        if (input.Answers.Any(answer =>
                !string.IsNullOrWhiteSpace(answer.SelectedAnswer) &&
                !questionById[answer.QuestionId].Options.Any(option =>
                    option.Label == answer.SelectedAnswer.Trim().ToUpperInvariant())))
        {
            throw new UserFriendlyException("Đáp án đã chọn không hợp lệ với câu hỏi.");
        }

        var answersByQuestion = input.Answers.ToDictionary(answer => answer.QuestionId);
        var attemptAnswers = exam.Questions.Select(question =>
        {
            answersByQuestion.TryGetValue(question.Id, out var submittedAnswer);
            var selected = submittedAnswer?.SelectedAnswer?.Trim().ToUpperInvariant();
            var isCorrect = !string.IsNullOrEmpty(selected) && (question.CorrectAnswer is "*" or "ALL" or "ABCD" || selected == question.CorrectAnswer);
            return new AttemptAnswer
            {
                QuestionId = question.Id,
                SelectedAnswer = string.IsNullOrEmpty(selected) ? null : selected,
                IsCorrect = isCorrect
            };
        }).ToList();

        var correctCount = attemptAnswers.Count(answer => answer.IsCorrect);
        var skippedCount = attemptAnswers.Count(answer => answer.SelectedAnswer == null);
        var wrongCount = attemptAnswers.Count - correctCount - skippedCount;
        var attempt = new ExamAttempt
        {
            ExamId = exam.Id,
            UserId = AbpSession.UserId,
            StartTime = DateTime.UtcNow,
            SubmitTime = DateTime.UtcNow,
            CorrectCount = correctCount,
            WrongCount = wrongCount,
            SkippedCount = skippedCount
        };

        attempt.Id = await _attemptRepository.InsertAndGetIdAsync(attempt);
        foreach (var answer in attemptAnswers)
        {
            answer.AttemptId = attempt.Id;
            await _attemptAnswerRepository.InsertAsync(answer);
        }

        await CurrentUnitOfWork.SaveChangesAsync();
        return new ExamResultDto(
            attempt.Id,
            exam.Title,
            exam.TotalQuestions,
            correctCount,
            wrongCount,
            skippedCount,
            exam.TotalQuestions == 0 ? 0 : Math.Round((decimal)correctCount * 100 / exam.TotalQuestions, 2),
            attemptAnswers.Select((answer, index) => new QuestionResultDto(
                answer.QuestionId,
                answer.SelectedAnswer,
                exam.Questions.First(question => question.Id == answer.QuestionId).CorrectAnswer,
                answer.IsCorrect)).ToList());
    }

    private Task<Exam> GetExamWithQuestionsAsync(int id)
    {
        return _examRepository.GetAll()
            .Include(exam => exam.Passages)
            .Include(exam => exam.Questions)
                .ThenInclude(question => question.Options)
            .Include(exam => exam.Questions)
                .ThenInclude(question => question.PassageGroup)
            .FirstOrDefaultAsync(exam => exam.Id == id);
    }

    private static void ValidateExam(ImportExamInput input)
    {
        ValidateExam(input.Title, input.DurationMinutes, input.Passages, input.Questions);
    }

    private static void ValidateExam(UpdateExamInput input)
    {
        ValidateExam(input.Title, input.DurationMinutes, input.Passages, input.Questions);
    }

    private static void ValidateExam(
        string title,
        int durationMinutes,
        List<PassageInput> passages,
        List<QuestionInput> questions)
    {
        if (string.IsNullOrWhiteSpace(title))
        {
            throw new UserFriendlyException("Tên đề thi không được để trống.");
        }

        if (durationMinutes < 1 || questions.Count == 0 || questions.Select(question => question.Number).Distinct().Count() != questions.Count)
        {
            throw new UserFriendlyException("Đề thi phải có câu hỏi và số câu không được trùng.");
        }

        if (passages.Select(passage => passage.OrderIndex).Distinct().Count() != passages.Count)
        {
            throw new UserFriendlyException("Thứ tự bài đọc không được trùng.");
        }

        var passagesByOrder = passages.ToDictionary(passage => passage.OrderIndex);
        foreach (var question in questions)
        {
            if (question.Part == 5 && question.PassageOrderIndex.HasValue ||
                question.Part is 6 or 7 && (!question.PassageOrderIndex.HasValue ||
                    !passagesByOrder.TryGetValue(question.PassageOrderIndex.Value, out var passage) ||
                    passage.Part != question.Part))
            {
                throw new UserFriendlyException("Bài đọc của câu hỏi không hợp lệ với Part.");
            }

            var labels = question.Options.Select(option => option.Label?.Trim().ToUpperInvariant()).ToList();
            var validAnswers = new[] { "A", "B", "C", "D", "*", "ALL", "ABCD" };
            if (labels.Count != 4 || labels.Distinct().Count() != 4 ||
                OptionLabels.Any(label => !labels.Contains(label)) ||
                !validAnswers.Contains(question.CorrectAnswer?.Trim().ToUpperInvariant()))
            {
                throw new UserFriendlyException("Mỗi câu phải có đủ bốn đáp án A, B, C, D và đáp án đúng hợp lệ.");
            }
        }
    }

    private static Exam CreateExam(ImportExamInput input)
    {
        return CreateExam(input.Title, input.DurationMinutes, input.Passages, input.Questions);
    }

    private static Exam CreateExam(UpdateExamInput input)
    {
        return CreateExam(input.Title, input.DurationMinutes, input.Passages, input.Questions);
    }

    private static Exam CreateExam(
        string title,
        int durationMinutes,
        List<PassageInput> passages,
        List<QuestionInput> questions)
    {
        var exam = new Exam
        {
            Title = title.Trim(),
            DurationMinutes = durationMinutes,
            TotalQuestions = questions.Count
        };
        var passagesByOrder = new Dictionary<int, PassageGroup>();

        foreach (var passageInput in passages)
        {
            var passage = new PassageGroup
            {
                Part = passageInput.Part,
                OrderIndex = passageInput.OrderIndex,
                RangeText = passageInput.RangeText,
                Instruction = passageInput.Instruction,
                Content = passageInput.Content,
                Exam = exam
            };
            exam.Passages.Add(passage);
            passagesByOrder.Add(passage.OrderIndex, passage);
        }

        foreach (var questionInput in questions)
        {
            var ca = questionInput.CorrectAnswer?.Trim().ToUpperInvariant() ?? "*";
            if (ca is "ALL" or "ABCD") ca = "*";

            var question = new Question
            {
                Part = questionInput.Part,
                Number = questionInput.Number,
                Text = questionInput.Text,
                CorrectAnswer = ca,
                Exam = exam
            };

            if (questionInput.PassageOrderIndex.HasValue)
            {
                question.PassageGroup = passagesByOrder[questionInput.PassageOrderIndex.Value];
            }

            foreach (var option in questionInput.Options)
            {
                question.Options.Add(new QuestionOption
                {
                    Label = option.Label.Trim().ToUpperInvariant(),
                    Content = option.Content.Trim(),
                    Question = question
                });
            }

            exam.Questions.Add(question);
        }

        return exam;
    }

    private static ExamSummaryDto ToSummary(Exam exam)
    {
        return new ExamSummaryDto(exam.Id, exam.Title, exam.DurationMinutes, exam.TotalQuestions);
    }
}