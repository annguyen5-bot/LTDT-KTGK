using System;
using System.Collections.Generic;
using Abp.Domain.Entities;

namespace KTGK.Toeic
{
    /// <summary>Một lượt thi của người học.</summary>
    public class ExamAttempt : Entity<int>
    {
        public int ExamId { get; set; }
        public Exam Exam { get; set; }

        /// <summary>Null nếu người học thi không đăng nhập (bản demo).</summary>
        public long? UserId { get; set; }

        public DateTime StartTime { get; set; }
        public DateTime? SubmitTime { get; set; }

        public int CorrectCount { get; set; }
        public int WrongCount { get; set; }
        public int SkippedCount { get; set; }

        public ICollection<AttemptAnswer> Answers { get; set; } = new List<AttemptAnswer>();
    }
}