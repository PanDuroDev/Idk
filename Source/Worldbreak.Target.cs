using UnrealBuildTool;

public class WorldbreakTarget : TargetRules
{
    public WorldbreakTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Game;
        DefaultBuildSettings = BuildSettingsVersion.V5;
        IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_5;
        ExtraModuleNames.Add("Worldbreak");
    }
}
