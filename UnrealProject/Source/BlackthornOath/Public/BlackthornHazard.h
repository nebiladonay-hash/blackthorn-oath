#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "BlackthornHazard.generated.h"

UCLASS()
class BLACKTHORNOATH_API ABlackthornHazard : public AActor
{
    GENERATED_BODY()

public:
    ABlackthornHazard();

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly)
    TObjectPtr<class UBoxComponent> Trigger;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hazard")
    bool bSingleHit = true;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Hazard")
    int32 Damage = 1;

    UFUNCTION()
    void HandleOverlap(UPrimitiveComponent* OverlappedComponent, AActor* OtherActor,
        UPrimitiveComponent* OtherComponent, int32 OtherBodyIndex,
        bool bFromSweep, const FHitResult& SweepResult);

private:
    bool bTriggered = false;
};
