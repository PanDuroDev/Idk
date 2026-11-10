#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "WorldbreakBlastActor.generated.h"

UCLASS(BlueprintType)
class WORLDBREAK_API AWorldbreakBlastActor : public AActor
{
    GENERATED_BODY()

public:
    AWorldbreakBlastActor();

    UFUNCTION(BlueprintCallable, Category = "Worldbreak|Physics")
    void Detonate();

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Worldbreak|Physics", meta = (ClampMin = "1.0"))
    float EffectRadius = 1200.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Worldbreak|Physics", meta = (ClampMin = "0.0"))
    float ImpulseStrength = 250000.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Worldbreak|Damage", meta = (ClampMin = "0.0"))
    float BaseDamage = 0.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category = "Worldbreak|Physics")
    bool bVelChange = false;

protected:
    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category = "Worldbreak")
    TObjectPtr<USceneComponent> SceneRoot;

private:
    bool bHasDetonated = false;
};
