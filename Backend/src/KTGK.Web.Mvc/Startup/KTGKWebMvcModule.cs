using Abp.Modules;
using Abp.Reflection.Extensions;
using KTGK.Configuration;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;

namespace KTGK.Web.Startup;

[DependsOn(typeof(KTGKWebCoreModule))]
public class KTGKWebMvcModule : AbpModule
{
    private readonly IWebHostEnvironment _env;
    private readonly IConfigurationRoot _appConfiguration;

    public KTGKWebMvcModule(IWebHostEnvironment env)
    {
        _env = env;
        _appConfiguration = env.GetAppConfiguration();
    }

    public override void PreInitialize()
    {
        Configuration.Navigation.Providers.Add<KTGKNavigationProvider>();
    }

    public override void Initialize()
    {
        IocManager.RegisterAssemblyByConvention(typeof(KTGKWebMvcModule).GetAssembly());
    }
}
