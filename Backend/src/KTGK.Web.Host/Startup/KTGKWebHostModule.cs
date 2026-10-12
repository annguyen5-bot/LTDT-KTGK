using Abp.Modules;
using Abp.Reflection.Extensions;
using KTGK.Configuration;
using Microsoft.AspNetCore.Hosting;
using Microsoft.Extensions.Configuration;

namespace KTGK.Web.Host.Startup
{
    [DependsOn(
       typeof(KTGKWebCoreModule))]
    public class KTGKWebHostModule : AbpModule
    {
        private readonly IWebHostEnvironment _env;
        private readonly IConfigurationRoot _appConfiguration;

        public KTGKWebHostModule(IWebHostEnvironment env)
        {
            _env = env;
            _appConfiguration = env.GetAppConfiguration();
        }

        public override void Initialize()
        {
            IocManager.RegisterAssemblyByConvention(typeof(KTGKWebHostModule).GetAssembly());
        }
    }
}
