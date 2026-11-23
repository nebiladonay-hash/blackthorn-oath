#include "BlackthornHazard.h"

#include "BlackthornOathCharacter.h"
#include "Components/BoxComponent.h"
#include "Kismet/GameplayStatics.h"

ABlackthornHazard::ABlackthornHazard()
{
    PrimaryActorTick.bCanEverTick = false;

    Trigger = CreateDefaultSubobject<UBoxComponent>(TEXT("HazardTrigger"));
    SetRootComponent(Trigger);
    Trigger->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
    Trigger->SetCollisionObjectType(ECC_WorldDynamic);
    Trigger->SetCollisionResponseToAllChannels(ECR_Ignore);
    Trigger->SetCollisionResponseToChannel(ECC_Pawn, ECR_Overlap);
    Trigger->SetGenerateOverlapEvents(true);
    Trigger->OnComponentBeginOverlap.AddDynamic(this, &ABlackthornHazard::HandleOverlap);
}

void ABlackthornHazard::HandleOverlap(UPrimitiveComponent* OverlappedComponent,
    AActor* OtherActor, UPrimitiveComponent* OtherComponent, int32 OtherBodyIndex,
    bool bFromSweep, const FHitResult& SweepResult)
{
    if (bTriggered && bSingleHit)
    {
        return;
    }

    ABlackthornOathCharacter* Player = Cast<ABlackthornOathCharacter>(OtherActor);
    if (!Player || Player->bIsDead)
    {
        return;
    }

    bTriggered = true;
    UGameplayStatics::ApplyDamage(Player, static_cast<float>(Damage), nullptr, this, nullptr);
}
