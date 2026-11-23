#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "BlackthornRelic.generated.h"

UCLASS()
class BLACKTHORNOATH_API ABlackthornRelic : public AActor
{
    GENERATED_BODY()

public:
    ABlackthornRelic();

    virtual void Tick(float DeltaSeconds) override;

protected:
    virtual void BeginPlay() override;

public:

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly)
    TObjectPtr<class USphereComponent> PickupTrigger;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Relic")
    float BobHeight = 12.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Relic")
    float BobFrequency = 3.85f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Relic")
    float RotationSpeed = 137.5f;

    UFUNCTION()
    void HandleOverlap(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor,
        UPrimitiveComponent* OtherComponent, int32 OtherBodyIndex,
        bool bFromSweep, const FHitResult& SweepResult);

private:
    FVector InitialLocation = FVector::ZeroVector;
    float PhaseOffset = 0.0f;
    bool bCollected = false;
};
