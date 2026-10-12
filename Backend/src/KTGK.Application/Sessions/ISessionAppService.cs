using Abp.Application.Services;
using KTGK.Sessions.Dto;
using System.Threading.Tasks;

namespace KTGK.Sessions;

public interface ISessionAppService : IApplicationService
{
    Task<GetCurrentLoginInformationsOutput> GetCurrentLoginInformations();
}
