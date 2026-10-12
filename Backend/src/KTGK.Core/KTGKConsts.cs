using KTGK.Debugging;

namespace KTGK;

public class KTGKConsts
{
    public const string LocalizationSourceName = "KTGK";

    public const string ConnectionStringName = "Default";

    public const bool MultiTenancyEnabled = true;


    /// <summary>
    /// Default pass phrase for SimpleStringCipher decrypt/encrypt operations
    /// </summary>
    public static readonly string DefaultPassPhrase =
        DebugHelper.IsDebug ? "gsKxGZ012HLL3MI5" : "82da90bb91c2424c8c3aa622715539b4";
}
