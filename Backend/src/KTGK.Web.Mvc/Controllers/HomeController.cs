using Abp.AspNetCore.Mvc.Authorization;
using KTGK.Controllers;
using Microsoft.AspNetCore.Mvc;

namespace KTGK.Web.Controllers;

[AbpMvcAuthorize]
public class HomeController : KTGKControllerBase
{
    public ActionResult Index()
    {
        return View();
    }
}
