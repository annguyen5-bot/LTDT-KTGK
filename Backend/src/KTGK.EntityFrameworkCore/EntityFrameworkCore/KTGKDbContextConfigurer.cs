using Microsoft.EntityFrameworkCore;
using System.Data.Common;

namespace KTGK.EntityFrameworkCore;

public static class KTGKDbContextConfigurer
{
    public static void Configure(DbContextOptionsBuilder<KTGKDbContext> builder, string connectionString)
    {
        builder.UseSqlServer(connectionString);
    }

    public static void Configure(DbContextOptionsBuilder<KTGKDbContext> builder, DbConnection connection)
    {
        builder.UseSqlServer(connection);
    }
}
