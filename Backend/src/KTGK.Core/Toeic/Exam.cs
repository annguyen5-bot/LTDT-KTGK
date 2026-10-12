using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using Abp.Domain.Entities.Auditing;

namespace KTGK.Toeic
{
    public class Exam : FullAuditedEntity<int>
    {
        public const int MaxTitleLength = 256;

        [Required]
        [StringLength(MaxTitleLength)]
        public string Title { get; set; }

        public int DurationMinutes { get; set; } = 75;

        public int TotalQuestions { get; set; }

        public ICollection<PassageGroup> Passages { get; set; } = new List<PassageGroup>();

        public ICollection<Question> Questions { get; set; } = new List<Question>();
    }
}