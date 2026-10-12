using Abp.AutoMapper;
using Abp.Modules;
using Abp.Reflection.Extensions;
using KTGK.Authorization;

namespace KTGK;

[DependsOn(
    typeof(KTGKCoreModule),
    typeof(AbpAutoMapperModule))]
public class KTGKApplicationModule : AbpModule
{
    public override void PreInitialize()
    {
        Configuration.Authorization.Providers.Add<KTGKAuthorizationProvider>();
    }

    public override void Initialize()
    {
        var thisAssembly = typeof(KTGKApplicationModule).GetAssembly();

        IocManager.RegisterAssemblyByConvention(thisAssembly);

        Configuration.Modules.AbpAutoMapper().Configurators.Add(
            // Scan the assembly for classes which inherit from AutoMapper.Profile
            cfg => cfg.AddMaps(thisAssembly)
        );
    }
}
