using UnrealBuildTool;

public class Worldbreak : ModuleRules
{
    public Worldbreak(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
        PublicDependencyModuleNames.AddRange(new[]
        {
            "Core", "CoreUObject", "Engine", "InputCore",
            "EnhancedInput", "Niagara"
        });
    }
}
