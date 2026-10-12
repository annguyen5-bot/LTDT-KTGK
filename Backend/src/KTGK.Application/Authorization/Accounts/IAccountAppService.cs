using Abp.Application.Services;
using KTGK.Authorization.Accounts.Dto;
using System.Threading.Tasks;

namespace KTGK.Authorization.Accounts;

public interface IAccountAppService : IApplicationService
{
    Task<IsTenantAvailableOutput> IsTenantAvailable(IsTenantAvailableInput input);

    Task<RegisterOutput> Register(RegisterInput input);
}
