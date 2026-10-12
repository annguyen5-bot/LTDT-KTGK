using System.ComponentModel.DataAnnotations;

namespace KTGK.Users.Dto;

public class ChangeUserLanguageDto
{
    [Required]
    public string LanguageName { get; set; }
}