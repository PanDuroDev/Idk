using UnrealBuildTool;

public class WorldbreakEditorTarget : TargetRules
{
    public WorldbreakEditorTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Editor;
        DefaultBuildSettings = BuildSettingsVersion.V5;
        IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_5;
        ExtraModuleNames.Add("Worldbreak");
    }
}
