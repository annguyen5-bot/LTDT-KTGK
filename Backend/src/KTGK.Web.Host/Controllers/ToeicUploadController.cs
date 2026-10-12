using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Text.RegularExpressions;
using System.Threading.Tasks;
using Abp.Authorization;
using Abp.UI;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using KTGK.Authorization;
using KTGK.Controllers;
using KTGK.Toeic;
using KTGK.Toeic.Dto;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace KTGK.Web.Host.Controllers;

/// <summary>
/// Upload file Word (.docx) để tạo đề thi TOEIC Reading.
/// Format yêu cầu trong file Word:
///
/// TITLE: Tên đề thi
/// DURATION: 75
///
/// PART 5
/// 101. Câu hỏi
/// A. Đáp án A
/// B. Đáp án B
/// C. Đáp án C
/// D. Đáp án D
/// ANSWER: C
///
/// PART 6
/// PASSAGE:
/// Nội dung bài đọc ...
/// END PASSAGE
/// 131. (câu hỏi tùy chọn, hoặc để trống)
/// A. Đáp án A
/// B. Đáp án B
/// C. Đáp án C
/// D. Đáp án D
/// ANSWER: A
///
/// PART 7
/// PASSAGE:
/// Nội dung bài đọc ...
/// END PASSAGE
/// 147. Câu hỏi?
/// A. Đáp án A
/// B. Đáp án B
/// C. Đáp án C
/// D. Đáp án D
/// ANSWER: B
/// </summary>
[Route("api/toeic")]
[ApiController]
public class ToeicUploadController : KTGKControllerBase
{
    private readonly ToeicAppService _toeicAppService;

    /// <summary>Tạo controller upload file Word.</summary>
    public ToeicUploadController(ToeicAppService toeicAppService)
    {
        _toeicAppService = toeicAppService;
    }

    /// <summary>Upload file Word (.docx) để tạo đề thi TOEIC.</summary>
    [HttpPost("upload-word")]
    [Consumes("multipart/form-data")]
    public async Task<ActionResult<ExamSummaryDto>> UploadWord(IFormFile file)
    {
        if (file == null || file.Length == 0)
        {
            throw new UserFriendlyException("Vui lòng chọn file.");
        }

        var extension = Path.GetExtension(file.FileName)?.ToLowerInvariant();
        if (extension != ".docx")
        {
            throw new UserFriendlyException("Chỉ hỗ trợ file Word (.docx).");
        }

        using var stream = new MemoryStream();
        await file.CopyToAsync(stream);
        stream.Position = 0;

        var lines = ExtractLinesFromDocx(stream);
        var input = ParseExamFromLines(lines);
        var result = await _toeicAppService.ImportExamAsync(input);
        return Ok(result);
    }

    /// <summary>Cập nhật đề thi cùng câu hỏi và đáp án (hỗ trợ cả POST và PUT).</summary>
    [HttpPost("update-exam")]
    [HttpPut("update-exam")]
    public async Task<ActionResult<ExamSummaryDto>> UpdateExam([FromBody] UpdateExamInput input)
    {
        if (input == null)
        {
            throw new UserFriendlyException("Dữ liệu đề thi gửi lên không hợp lệ.");
        }
        var result = await _toeicAppService.UpdateExamAsync(input);
        return Ok(result);
    }

    private static List<string> ExtractLinesFromDocx(Stream stream)
    {
        var lines = new List<string>();
        using var doc = WordprocessingDocument.Open(stream, false);
        var body = doc.MainDocumentPart?.Document?.Body;
        if (body == null)
        {
            throw new UserFriendlyException("File Word không có nội dung.");
        }

        foreach (var paragraph in body.Elements<Paragraph>())
        {
            var text = paragraph.InnerText?.Trim();
            if (!string.IsNullOrEmpty(text))
            {
                lines.Add(text);
            }
        }

        return lines;
    }

    private static ImportExamInput ParseExamFromLines(List<string> lines)
    {
        if (lines.Count == 0)
        {
            throw new UserFriendlyException("File Word trống, không tìm thấy nội dung.");
        }

        var title = "Đề thi TOEIC Reading";
        var durationMinutes = 75;
        var passages = new List<PassageInput>();
        var questions = new List<QuestionInput>();

        var currentPart = 5;
        var passageOrderIndex = 0;
        var currentPassageContent = new List<string>();
        var insidePassage = false;
        var currentPassagePart = 6;

        var questionNumber = 0;
        string questionText = null;
        var options = new List<OptionInput>();
        string correctAnswer = null;
        int? questionPassageOrder = null;

        for (var i = 0; i < lines.Count; i++)
        {
            var line = lines[i].Trim();

            // Parse title
            if (line.StartsWith("TITLE:", StringComparison.OrdinalIgnoreCase))
            {
                title = line.Substring(6).Trim();
                if (string.IsNullOrEmpty(title)) title = "Đề thi TOEIC Reading";
                continue;
            }

            // Parse duration
            if (line.StartsWith("DURATION:", StringComparison.OrdinalIgnoreCase))
            {
                if (int.TryParse(line.Substring(9).Trim(), out var dur) && dur > 0)
                {
                    durationMinutes = dur;
                }
                continue;
            }

            // Parse part header
            var partMatch = Regex.Match(line, @"^PART\s*(\d+|S)?", RegexOptions.IgnoreCase);
            if (partMatch.Success)
            {
                FlushQuestion(questions, ref questionNumber, ref questionText, ref options, ref correctAnswer, ref questionPassageOrder);
                var partVal = partMatch.Groups[1].Value;
                if (int.TryParse(partVal, out var p) && p >= 5 && p <= 7)
                {
                    currentPart = p;
                }
                else
                {
                    currentPart = 5;
                }
                continue;
            }

            // Parse passage start
            if (line.Equals("PASSAGE:", StringComparison.OrdinalIgnoreCase) ||
                line.StartsWith("PASSAGE:", StringComparison.OrdinalIgnoreCase))
            {
                FlushQuestion(questions, ref questionNumber, ref questionText, ref options, ref correctAnswer, ref questionPassageOrder);
                insidePassage = true;
                currentPassageContent.Clear();
                currentPassagePart = currentPart;

                // Check if there's content after "PASSAGE:"
                var afterColon = line.Substring(line.IndexOf(':') + 1).Trim();
                if (!string.IsNullOrEmpty(afterColon))
                {
                    currentPassageContent.Add(afterColon);
                }
                continue;
            }

            // Parse passage end
            if (line.Equals("END PASSAGE", StringComparison.OrdinalIgnoreCase) ||
                line.Equals("END_PASSAGE", StringComparison.OrdinalIgnoreCase))
            {
                if (insidePassage && currentPassageContent.Count > 0)
                {
                    passageOrderIndex++;
                    passages.Add(new PassageInput
                    {
                        Part = currentPassagePart,
                        OrderIndex = passageOrderIndex,
                        Content = string.Join("\n", currentPassageContent)
                    });
                }
                insidePassage = false;
                currentPassageContent.Clear();
                continue;
            }

            // Collect passage content
            if (insidePassage)
            {
                currentPassageContent.Add(line);
                continue;
            }

            // Parse question number (e.g. 101. or Câu 101: or 101.)
            var questionMatch = Regex.Match(line, @"^(?:Câu\s+|Question\s+)?(\d+)[\.\:]\s*(.*)$", RegexOptions.IgnoreCase);
            if (questionMatch.Success)
            {
                FlushQuestion(questions, ref questionNumber, ref questionText, ref options, ref correctAnswer, ref questionPassageOrder);
                questionNumber = int.Parse(questionMatch.Groups[1].Value);
                questionText = questionMatch.Groups[2].Value.Trim();
                if (string.IsNullOrEmpty(questionText)) questionText = null;
                options = new List<OptionInput>();
                correctAnswer = null;
                questionPassageOrder = (currentPart == 6 || currentPart == 7) ? passageOrderIndex : null;
                continue;
            }

            // Parse options (supports: (A) text, A. text, A) text, (A). text)
            var optionMatch = Regex.Match(line, @"^\(?([A-Da-d])\)?[\.\)]?\s+(.+)$");
            if (optionMatch.Success && questionNumber > 0)
            {
                var label = optionMatch.Groups[1].Value.ToUpperInvariant();
                var content = optionMatch.Groups[2].Value.Trim();
                // Ensure options aren't duplicated for this question
                if (!options.Any(o => o.Label == label))
                {
                    options.Add(new OptionInput
                    {
                        Label = label,
                        Content = content
                    });
                }
                continue;
            }

            // Parse answer (supports: ANSWER: B, Đáp án: (B), KEY: C)
            var answerMatch = Regex.Match(line, @"^(?:ANSWER|ĐÁP ÁN|KEY):\s*\(?([A-Da-d])\)?", RegexOptions.IgnoreCase);
            if (answerMatch.Success)
            {
                correctAnswer = answerMatch.Groups[1].Value.ToUpperInvariant();
                continue;
            }
        }

        // Flush last question
        FlushQuestion(questions, ref questionNumber, ref questionText, ref options, ref correctAnswer, ref questionPassageOrder);

        // Flush last passage if user forgot END PASSAGE
        if (insidePassage && currentPassageContent.Count > 0)
        {
            passageOrderIndex++;
            passages.Add(new PassageInput
            {
                Part = currentPassagePart,
                OrderIndex = passageOrderIndex,
                Content = string.Join("\n", currentPassageContent)
            });
        }

        if (questions.Count == 0)
        {
            throw new UserFriendlyException(
                "Không tìm thấy câu hỏi nào trong file Word. " +
                "Vui lòng kiểm tra định dạng (ví dụ: 101. Câu hỏi, A. Đáp án, ANSWER: C).");
        }

        return new ImportExamInput
        {
            Title = title,
            DurationMinutes = durationMinutes,
            Passages = passages,
            Questions = questions
        };
    }

    private static void FlushQuestion(
        List<QuestionInput> questions,
        ref int questionNumber,
        ref string questionText,
        ref List<OptionInput> options,
        ref string correctAnswer,
        ref int? questionPassageOrder)
    {
        if (questionNumber <= 0 || options.Count != 4 || string.IsNullOrEmpty(correctAnswer))
        {
            return;
        }

        // Determine part from question number
        int part;
        if (questionNumber <= 130) part = 5;
        else if (questionNumber <= 146) part = 6;
        else part = 7;

        questions.Add(new QuestionInput
        {
            Part = part,
            Number = questionNumber,
            Text = questionText,
            CorrectAnswer = correctAnswer,
            PassageOrderIndex = questionPassageOrder,
            Options = options
        });

        questionNumber = 0;
        questionText = null;
        options = new List<OptionInput>();
        correctAnswer = null;
        questionPassageOrder = null;
    }
}
