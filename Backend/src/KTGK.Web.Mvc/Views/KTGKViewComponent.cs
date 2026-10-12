using Abp.AspNetCore.Mvc.ViewComponents;

namespace KTGK.Web.Views;

public abstract class KTGKViewComponent : AbpViewComponent
{
    protected KTGKViewComponent()
    {
        LocalizationSourceName = KTGKConsts.LocalizationSourceName;
    }
}
