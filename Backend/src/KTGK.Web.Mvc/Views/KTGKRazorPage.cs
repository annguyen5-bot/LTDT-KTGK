using Abp.AspNetCore.Mvc.Views;
using Abp.Runtime.Session;
using Microsoft.AspNetCore.Mvc.Razor.Internal;

namespace KTGK.Web.Views;

public abstract class KTGKRazorPage<TModel> : AbpRazorPage<TModel>
{
    [RazorInject]
    public IAbpSession AbpSession { get; set; }

    protected KTGKRazorPage()
    {
        LocalizationSourceName = KTGKConsts.LocalizationSourceName;
    }
}
