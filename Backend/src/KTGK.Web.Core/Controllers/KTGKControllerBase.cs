using Abp.AspNetCore.Mvc.Controllers;
using Abp.IdentityFramework;
using Microsoft.AspNetCore.Identity;

namespace KTGK.Controllers
{
    public abstract class KTGKControllerBase : AbpController
    {
        protected KTGKControllerBase()
        {
            LocalizationSourceName = KTGKConsts.LocalizationSourceName;
        }

        protected void CheckErrors(IdentityResult identityResult)
        {
            identityResult.CheckErrors(LocalizationManager);
        }
    }
}
