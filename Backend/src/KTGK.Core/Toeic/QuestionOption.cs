using System.ComponentModel.DataAnnotations;
using Abp.Domain.Entities;

namespace KTGK.Toeic
{
    public class QuestionOption : Entity<int>
    {
        public int QuestionId { get; set; }
        public Question Question { get; set; }

        /// <summary>A, B, C hoặc D</summary>
        [Required]
        [StringLength(1)]
        public string Label { get; set; }

        [Required]
        [StringLength(1024)]
        public string Content { get; set; }
    }
}