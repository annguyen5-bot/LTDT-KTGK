using System.ComponentModel.DataAnnotations;
using Abp.Domain.Entities;

namespace KTGK.Toeic
{
    public class AttemptAnswer : Entity<int>
    {
        public int AttemptId { get; set; }
        public ExamAttempt Attempt { get; set; }

        public int QuestionId { get; set; }
        public Question Question { get; set; }

        /// <summary>A-D, null nếu bỏ qua.</summary>
        [StringLength(1)]
        public string SelectedAnswer { get; set; }

        public bool IsCorrect { get; set; }
    }
}