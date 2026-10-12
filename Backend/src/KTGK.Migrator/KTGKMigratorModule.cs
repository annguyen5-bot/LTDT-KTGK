using Abp.Events.Bus;
using Abp.Modules;
using Abp.Reflection.Extensions;
using KTGK.Configuration;
using KTGK.EntityFrameworkCore;
using KTGK.Migrator.DependencyInjection;
using Castle.MicroKernel.Registration;
using Microsoft.Extensions.Configuration;

namespace KTGK.Migrator;

[DependsOn(typeof(KTGKEntityFrameworkModule))]
public class KTGKMigratorModule : AbpModule
{
    private readonly IConfigurationRoot _appConfiguration;

    public KTGKMigratorModule(KTGKEntityFrameworkModule abpProjectNameEntityFrameworkModule)
    {
        abpProjectNameEntityFrameworkModule.SkipDbSeed = true;

        _appConfiguration = AppConfigurations.Get(
            typeof(KTGKMigratorModule).GetAssembly().GetDirectoryPathOrNull()
        );
    }

    public override void PreInitialize()
    {
        Configuration.DefaultNameOrConnectionString = _appConfiguration.GetConnectionString(
            KTGKConsts.ConnectionStringName
        );

        Configuration.BackgroundJobs.IsJobExecutionEnabled = false;
        Configuration.ReplaceService(
            typeof(IEventBus),
            () => IocManager.IocContainer.Register(
                Component.For<IEventBus>().Instance(NullEventBus.Instance)
            )
        );
    }

    public override void Initialize()
    {
        IocManager.RegisterAssemblyByConvention(typeof(KTGKMigratorModule).GetAssembly());
        ServiceCollectionRegistrar.Register(IocManager);
    }
}
