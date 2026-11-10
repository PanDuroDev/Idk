#include "WorldbreakBlastActor.h"

#include "Components/SceneComponent.h"
#include "Engine/World.h"
#include "GameFramework/DamageType.h"
#include "Kismet/GameplayStatics.h"

AWorldbreakBlastActor::AWorldbreakBlastActor()
{
    PrimaryActorTick.bCanEverTick = false;
    SceneRoot = CreateDefaultSubobject<USceneComponent>(TEXT("Root"));
    SetRootComponent(SceneRoot);
}

void AWorldbreakBlastActor::Detonate()
{
    if (bHasDetonated || !GetWorld())
    {
        return;
    }

    bHasDetonated = true;
    const FVector Origin = GetActorLocation();
    const float SafeRadius = FMath::Max(1.0f, EffectRadius);

    TArray<FOverlapResult> Overlaps;
    FCollisionObjectQueryParams ObjectQuery;
    ObjectQuery.AddObjectTypesToQuery(ECC_PhysicsBody);
    ObjectQuery.AddObjectTypesToQuery(ECC_WorldDynamic);

    FCollisionQueryParams QueryParams(SCENE_QUERY_STAT(WorldbreakBlast), false, this);
    GetWorld()->OverlapMultiByObjectType(
        Overlaps, Origin, FQuat::Identity, ObjectQuery,
        FCollisionShape::MakeSphere(SafeRadius), QueryParams
    );

    TSet<UPrimitiveComponent*> AffectedComponents;
    for (const FOverlapResult& Overlap : Overlaps)
    {
        UPrimitiveComponent* Primitive = Overlap.GetComponent();
        if (!IsValid(Primitive) || !Primitive->IsSimulatingPhysics() ||
            AffectedComponents.Contains(Primitive))
        {
            continue;
        }

        AffectedComponents.Add(Primitive);
        Primitive->AddRadialImpulse(
            Origin, SafeRadius, ImpulseStrength,
            ERadialImpulseFalloff::RIF_Linear, bVelChange
        );
    }

    if (BaseDamage > 0.0f)
    {
        UGameplayStatics::ApplyRadialDamageWithFalloff(
            this, BaseDamage, 0.0f, Origin,
            SafeRadius * 0.15f, SafeRadius, 1.0f,
            UDamageType::StaticClass(), TArray<AActor*>(),
            this, GetInstigatorController()
        );
    }

    SetLifeSpan(0.1f);
}
