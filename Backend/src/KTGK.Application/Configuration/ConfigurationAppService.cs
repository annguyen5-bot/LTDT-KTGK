using Abp.Authorization;
using Abp.Runtime.Session;
using KTGK.Configuration.Dto;
using System.Threading.Tasks;

namespace KTGK.Configuration;

[AbpAuthorize]
public class ConfigurationAppService : KTGKAppServiceBase, IConfigurationAppService
{
    public async Task ChangeUiTheme(ChangeUiThemeInput input)
    {
        await SettingManager.ChangeSettingForUserAsync(AbpSession.ToUserIdentifier(), AppSettingNames.UiTheme, input.Theme);
    }
}
