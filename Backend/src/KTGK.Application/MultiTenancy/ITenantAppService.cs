using Abp.Application.Services;
using KTGK.MultiTenancy.Dto;

namespace KTGK.MultiTenancy;

public interface ITenantAppService : IAsyncCrudAppService<TenantDto, int, PagedTenantResultRequestDto, CreateTenantDto, TenantDto>
{
}

