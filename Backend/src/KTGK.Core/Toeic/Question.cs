using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using Abp.Domain.Entities;

namespace KTGK.Toeic
{
    public class Question : Entity<int>
    {
        public int ExamId { get; set; }
        public Exam Exam { get; set; }

        /// <summary>Null với Part 5 (câu hỏi độc lập).</summary>
        public int? PassageGroupId { get; set; }
        public PassageGroup PassageGroup { get; set; }

        /// <summary>5, 6 hoặc 7</summary>
        public int Part { get; set; }

        /// <summary>Số thứ tự câu (101-200).</summary>
        public int Number { get; set; }

        /// <summary>Null với Part 6 (chỉ có số thứ tự).</summary>
        public string Text { get; set; }

        /// <summary>A, B, C, D hoặc * (tất cả đều đúng)</summary>
        [Required]
        [StringLength(10)]
        public string CorrectAnswer { get; set; }

        public ICollection<QuestionOption> Options { get; set; } = new List<QuestionOption>();
    }
}