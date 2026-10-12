using Microsoft.EntityFrameworkCore;
using Abp.Zero.EntityFrameworkCore;
using KTGK.Authorization.Roles;
using KTGK.Authorization.Users;
using KTGK.MultiTenancy;
using KTGK.Toeic;

namespace KTGK.EntityFrameworkCore
{
    public class KTGKDbContext : AbpZeroDbContext<Tenant, Role, User, KTGKDbContext>
    {
        public DbSet<Exam> Exams { get; set; }
        public DbSet<PassageGroup> PassageGroups { get; set; }
        public DbSet<Question> Questions { get; set; }
        public DbSet<QuestionOption> QuestionOptions { get; set; }
        public DbSet<ExamAttempt> ExamAttempts { get; set; }
        public DbSet<AttemptAnswer> AttemptAnswers { get; set; }

        public KTGKDbContext(DbContextOptions<KTGKDbContext> options)
            : base(options)
        {
        }

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            base.OnModelCreating(modelBuilder);

            modelBuilder.Entity<PassageGroup>(b =>
            {
                b.HasOne(p => p.Exam).WithMany(e => e.Passages)
                    .HasForeignKey(p => p.ExamId).OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<Question>(b =>
            {
                b.HasOne(q => q.Exam).WithMany(e => e.Questions)
                    .HasForeignKey(q => q.ExamId).OnDelete(DeleteBehavior.Cascade);

                // Tránh lỗi "multiple cascade paths" của SQL Server
                b.HasOne(q => q.PassageGroup).WithMany(p => p.Questions)
                    .HasForeignKey(q => q.PassageGroupId).OnDelete(DeleteBehavior.NoAction);

                b.HasIndex(q => new { q.ExamId, q.Number }).IsUnique();
            });

            modelBuilder.Entity<QuestionOption>(b =>
            {
                b.HasOne(o => o.Question).WithMany(q => q.Options)
                    .HasForeignKey(o => o.QuestionId).OnDelete(DeleteBehavior.Cascade);
            });

            modelBuilder.Entity<ExamAttempt>(b =>
            {
                b.HasOne(a => a.Exam).WithMany()
                    .HasForeignKey(a => a.ExamId).OnDelete(DeleteBehavior.Restrict);
            });

            modelBuilder.Entity<AttemptAnswer>(b =>
            {
                b.HasOne(a => a.Attempt).WithMany(t => t.Answers)
                    .HasForeignKey(a => a.AttemptId).OnDelete(DeleteBehavior.Cascade);

                b.HasOne(a => a.Question).WithMany()
                    .HasForeignKey(a => a.QuestionId).OnDelete(DeleteBehavior.Restrict);
            });
        }
    }
}