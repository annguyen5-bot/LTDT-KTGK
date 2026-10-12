using Abp.Authorization;
using KTGK.Authorization.Roles;
using KTGK.Authorization.Users;

namespace KTGK.Authorization;

public class PermissionChecker : PermissionChecker<Role, User>
{
    public PermissionChecker(UserManager userManager)
        : base(userManager)
    {
    }
}
