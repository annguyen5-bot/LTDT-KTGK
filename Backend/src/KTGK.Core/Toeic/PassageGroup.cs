using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using Abp.Domain.Entities;

namespace KTGK.Toeic
{
    /// <summary>
    /// Bài đọc dùng chung cho nhóm câu hỏi (Part 6 và Part 7).
    /// </summary>
    public class PassageGroup : Entity<int>
    {
        public int ExamId { get; set; }
        public Exam Exam { get; set; }

        /// <summary>6 hoặc 7</summary>
        public int Part { get; set; }

        public int OrderIndex { get; set; }

        [StringLength(32)]
        public string RangeText { get; set; }

        [StringLength(512)]
        public string Instruction { get; set; }

        /// <summary>Nội dung bài đọc (nhiều đoạn, mỗi đoạn một dòng).</summary>
        public string Content { get; set; }

        /// <summary>Đường dẫn ảnh nếu bài đọc là hình (tùy chọn).</summary>
        [StringLength(512)]
        public string ImageUrl { get; set; }

        public ICollection<Question> Questions { get; set; } = new List<Question>();
    }
}