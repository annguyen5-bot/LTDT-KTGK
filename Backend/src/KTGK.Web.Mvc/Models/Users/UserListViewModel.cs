using KTGK.Roles.Dto;
using System.Collections.Generic;

namespace KTGK.Web.Models.Users;

public class UserListViewModel
{
    public IReadOnlyList<RoleDto> Roles { get; set; }
}
