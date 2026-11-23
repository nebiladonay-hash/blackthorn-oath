#include "BlackthornEnemy.h"

#include "BlackthornOathCharacter.h"
#include "BlackthornGameMode.h"
#include "Engine/World.h"
#include "Kismet/GameplayStatics.h"
#include "TimerManager.h"

ABlackthornEnemy::ABlackthornEnemy()
{
    PrimaryActorTick.bCanEverTick = true;
    SetActorTickInterval(0.04f);
}

void ABlackthornEnemy::BeginPlay()
{
    Super::BeginPlay();
    ConfigureArchetype();

    if (!TargetPlayer)
    {
        TargetPlayer = Cast<ABlackthornOathCharacter>(
            GetWorld()->GetFirstPlayerController()
                ? GetWorld()->GetFirstPlayerController()->GetPawn()
                : nullptr);
    }
}

void ABlackthornEnemy::ConfigureArchetype()
{
    switch (EnemyType)
    {
        case EBlackthornEnemyType::Bloodhound:
            Health = 1;
            AttackInterval = 0.85f;
            AttackWindup = 0.28f;
            break;
        case EBlackthornEnemyType::Executioner:
            Health = 3;
            AttackInterval = 1.75f;
            AttackWindup = 0.62f;
            break;
        default:
            Health = 2;
            AttackInterval = 1.3f;
            AttackWindup = 0.42f;
            break;
    }
}

void ABlackthornEnemy::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (bIsDead || !IsValid(TargetPlayer) || TargetPlayer->bIsDead)
    {
        return;
    }

    AttackCooldownRemaining = FMath::Max(0.0f, AttackCooldownRemaining - DeltaSeconds);

    const FVector Difference = TargetPlayer->GetActorLocation() - GetActorLocation();
    const bool bSameLane = FMath::Abs(Difference.Y) < 105.0f;
    const bool bInRange = FMath::Abs(Difference.X) < AttackRange;

    if (!bSameLane || !bInRange || AttackCooldownRemaining > 0.0f)
    {
        return;
    }

    if (!bAttackPending)
    {
        BeginAttack();
        return;
    }

    WindupRemaining -= DeltaSeconds;
    if (WindupRemaining <= 0.0f)
    {
        ResolveAttack();
    }
}

void ABlackthornEnemy::BeginAttack()
{
    bAttackPending = true;
    WindupRemaining = AttackWindup;
    OnEnemyWindup();
}

void ABlackthornEnemy::ResolveAttack()
{
    bAttackPending = false;
    AttackCooldownRemaining = AttackInterval;

    if (!IsValid(TargetPlayer) || TargetPlayer->bIsDead)
    {
        return;
    }

    const FVector Difference = TargetPlayer->GetActorLocation() - GetActorLocation();
    if (FMath::Abs(Difference.Y) < 105.0f && FMath::Abs(Difference.X) < AttackRange + 60.0f)
    {
        UGameplayStatics::ApplyDamage(TargetPlayer, 1.0f, nullptr, this, nullptr);
    }
}

float ABlackthornEnemy::TakeDamage(float DamageAmount, FDamageEvent const& DamageEvent,
    AController* EventInstigator, AActor* DamageCauser)
{
    if (bIsDead || DamageAmount <= 0.0f)
    {
        return 0.0f;
    }

    const float Applied = Super::TakeDamage(DamageAmount, DamageEvent, EventInstigator, DamageCauser);
    Health -= FMath::Max(1, FMath::RoundToInt(Applied));
    OnEnemyHit();

    if (Health <= 0)
    {
        bIsDead = true;
        SetActorEnableCollision(false);
        OnEnemyDeath();
        if (UWorld* World = GetWorld())
        {
            if (ABlackthornGameMode* GameMode = World->GetAuthGameMode<ABlackthornGameMode>())
            {
                GameMode->AddKill();
            }
        }
        SetLifeSpan(1.8f);
    }

    return Applied;
}
