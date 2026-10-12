using KTGK.Roles.Dto;
using System.Collections.Generic;

namespace KTGK.Web.Models.Common;

public interface IPermissionsEditViewModel
{
    List<FlatPermissionDto> Permissions { get; set; }
}