using KTGK.Configuration.Dto;
using System.Threading.Tasks;

namespace KTGK.Configuration;

public interface IConfigurationAppService
{
    Task ChangeUiTheme(ChangeUiThemeInput input);
}
