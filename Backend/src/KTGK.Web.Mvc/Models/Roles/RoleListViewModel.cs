using KTGK.Roles.Dto;
using System.Collections.Generic;

namespace KTGK.Web.Models.Roles;

public class RoleListViewModel
{
    public IReadOnlyList<PermissionDto> Permissions { get; set; }
}
