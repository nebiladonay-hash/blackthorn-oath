#include "BlackthornRelic.h"

#include "BlackthornOathCharacter.h"
#include "Components/SphereComponent.h"

ABlackthornRelic::ABlackthornRelic()
{
    PrimaryActorTick.bCanEverTick = true;

    PickupTrigger = CreateDefaultSubobject<USphereComponent>(TEXT("PickupTrigger"));
    SetRootComponent(PickupTrigger);
    PickupTrigger->SetSphereRadius(62.0f);
    PickupTrigger->SetCollisionEnabled(ECollisionEnabled::QueryOnly);
    PickupTrigger->SetCollisionResponseToAllChannels(ECR_Ignore);
    PickupTrigger->SetCollisionResponseToChannel(ECC_Pawn, ECR_Overlap);
    PickupTrigger->SetGenerateOverlapEvents(true);
    PickupTrigger->OnComponentBeginOverlap.AddDynamic(this, &ABlackthornRelic::HandleOverlap);
}

void ABlackthornRelic::BeginPlay()
{
    Super::BeginPlay();
    InitialLocation = GetActorLocation();
    PhaseOffset = FMath::FRandRange(0.0f, 6.28318f);
}

void ABlackthornRelic::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (bCollected)
    {
        return;
    }

    AddActorLocalRotation(FRotator(0.0f, RotationSpeed * DeltaSeconds, 0.0f));
    FVector Position = InitialLocation;
    Position.Z += FMath::Sin(GetWorld()->GetTimeSeconds() * BobFrequency + PhaseOffset) * BobHeight;
    SetActorLocation(Position);
}

void ABlackthornRelic::HandleOverlap(UPrimitiveComponent* OverlappedComponent,
    AActor* OtherActor, UPrimitiveComponent* OtherComponent, int32 OtherBodyIndex,
    bool bFromSweep, const FHitResult& SweepResult)
{
    if (bCollected || !Cast<ABlackthornOathCharacter>(OtherActor))
    {
        return;
    }

    bCollected = true;
    SetActorEnableCollision(false);
    Destroy();
}
