#include "BlackthornOathCharacter.h"

#include "DrawDebugHelpers.h"
#include "GameFramework/CharacterMovementComponent.h"
#include "Kismet/GameplayStatics.h"

ABlackthornOathCharacter::ABlackthornOathCharacter()
{
    PrimaryActorTick.bCanEverTick = true;

    GetCapsuleComponent()->InitCapsuleSize(40.0f, StandingCapsuleHalfHeight);
    GetCharacterMovement()->MaxWalkSpeed = ForwardSpeed;
    GetCharacterMovement()->bOrientRotationToMovement = false;
    GetCharacterMovement()->RotationRate = FRotator::ZeroRotator;
    GetCharacterMovement()->JumpZVelocity = 1020.0f;
    GetCharacterMovement()->GravityScale = 2.5f;

    bUseControllerRotationPitch = false;
    bUseControllerRotationYaw = false;
    bUseControllerRotationRoll = false;
}

void ABlackthornOathCharacter::BeginPlay()
{
    Super::BeginPlay();

    CurrentHealth = MaximumHealth;
    CurrentLane = 1;
    TargetLaneY = GetActorLocation().Y;
    StandingCapsuleHalfHeight = GetCapsuleComponent()->GetUnscaledCapsuleHalfHeight();
}

void ABlackthornOathCharacter::Tick(float DeltaSeconds)
{
    Super::Tick(DeltaSeconds);

    if (bIsDead)
    {
        return;
    }

    if (AttackCooldownRemaining > 0.0f)
    {
        AttackCooldownRemaining = FMath::Max(0.0f, AttackCooldownRemaining - DeltaSeconds);
    }

    if (AttackWindowRemaining > 0.0f)
    {
        AttackWindowRemaining = FMath::Max(0.0f, AttackWindowRemaining - DeltaSeconds);
        if (AttackWindowRemaining <= 0.0f)
        {
            EndAttack();
        }
    }

    if (SlideTimeRemaining > 0.0f)
    {
        SlideTimeRemaining = FMath::Max(0.0f, SlideTimeRemaining - DeltaSeconds);
        if (SlideTimeRemaining <= 0.0f)
        {
            EndSlide();
        }
    }

    if (InvulnerabilityTimeRemaining > 0.0f)
    {
        InvulnerabilityTimeRemaining = FMath::Max(0.0f, InvulnerabilityTimeRemaining - DeltaSeconds);
        if (InvulnerabilityTimeRemaining <= 0.0f)
        {
            EndInvulnerability();
        }
    }

    GetCharacterMovement()->MaxWalkSpeed = FMath::Min(
        ForwardSpeed, MaximumForwardSpeed);

    AddMovementInput(FVector::ForwardVector, 1.0f);
    UpdateLanePosition();
}

void ABlackthornOathCharacter::MoveLane(int32 Direction)
{
    if (bIsDead || Direction == 0)
    {
        return;
    }

    CurrentLane = FMath::Clamp(CurrentLane + FMath::Sign(Direction), 0, 2);
    const float CenterY = GetActorLocation().Y -
        (static_cast<float>(CurrentLane - 1) * LaneSpacing);
    TargetLaneY = CenterY;
}

void ABlackthornOathCharacter::UpdateLanePosition()
{
    FVector Location = GetActorLocation();
    Location.Y = FMath::FInterpTo(Location.Y, TargetLaneY, GetWorld()->GetDeltaSeconds(), LaneInterpSpeed);
    SetActorLocation(Location, true);
}

void ABlackthornOathCharacter::TriggerJump()
{
    if (!bIsDead && !bIsSliding && GetCharacterMovement()->IsMovingOnGround())
    {
        Jump();
    }
}

void ABlackthornOathCharacter::TriggerSlide()
{
    if (bIsDead || bIsSliding || !GetCharacterMovement()->IsMovingOnGround())
    {
        return;
    }

    bIsSliding = true;
    SlideTimeRemaining = SlideDuration;
    GetCapsuleComponent()->SetCapsuleHalfHeight(SlidingCapsuleHalfHeight, true);
    OnSlideStateChanged(true);
}

void ABlackthornOathCharacter::EndSlide()
{
    bIsSliding = false;
    GetCapsuleComponent()->SetCapsuleHalfHeight(StandingCapsuleHalfHeight, true);
    OnSlideStateChanged(false);
}

void ABlackthornOathCharacter::TriggerAttack()
{
    if (bIsDead || bIsSliding || AttackCooldownRemaining > 0.0f)
    {
        return;
    }

    AttackCooldownRemaining = AttackCooldown;
    AttackWindowRemaining = 0.32f;
    OnAttackStarted();

    const FVector Start = GetActorLocation() + FVector(0.0f, 0.0f, 75.0f);
    const FVector End = Start + GetActorForwardVector() * AttackRange;
    FCollisionQueryParams Params(SCENE_QUERY_STAT(BlackthornMelee), false, this);
    TArray<FHitResult> Hits;

    const bool bHit = GetWorld()->SweepMultiByChannel(
        Hits, Start, End, FQuat::Identity, ECC_Pawn,
        FCollisionShape::MakeSphere(AttackRadius), Params);

    if (bHit)
    {
        TSet<AActor*> DamagedActors;
        for (const FHitResult& Hit : Hits)
        {
            AActor* HitActor = Hit.GetActor();
            if (IsValid(HitActor) && !DamagedActors.Contains(HitActor))
            {
                DamagedActors.Add(HitActor);
                UGameplayStatics::ApplyDamage(HitActor, 1.0f, GetController(), this, nullptr);
            }
        }
    }
}

float ABlackthornOathCharacter::TakeDamage(float DamageAmount, FDamageEvent const& DamageEvent,
    AController* EventInstigator, AActor* DamageCauser)
{
    if (bIsDead || bIsInvulnerable || DamageAmount <= 0.0f)
    {
        return 0.0f;
    }

    const float AppliedDamage = Super::TakeDamage(
        DamageAmount, DamageEvent, EventInstigator, DamageCauser);

    const int32 DamagePoints = FMath::Max(1, FMath::RoundToInt(AppliedDamage));
    CurrentHealth = FMath::Clamp(CurrentHealth - DamagePoints, 0, MaximumHealth);
    OnHealthChanged.Broadcast(CurrentHealth);

    if (CurrentHealth <= 0)
    {
        bIsDead = true;
        GetCharacterMovement()->DisableMovement();
        OnDeathStarted();
        OnPlayerDied.Broadcast();
    }
    else
    {
        bIsInvulnerable = true;
        InvulnerabilityTimeRemaining = InvulnerabilityDuration;
        OnDamageReceived();
    }

    return AppliedDamage;
}

void ABlackthornOathCharacter::RestoreHealth(int32 Amount)
{
    if (Amount <= 0 || bIsDead)
    {
        return;
    }

    CurrentHealth = FMath::Clamp(CurrentHealth + Amount, 0, MaximumHealth);
    OnHealthChanged.Broadcast(CurrentHealth);
}

void ABlackthornOathCharacter::ResetForRun()
{
    bIsDead = false;
    bIsInvulnerable = false;
    bIsSliding = false;
    CurrentHealth = MaximumHealth;
    CurrentLane = 1;
    AttackCooldownRemaining = 0.0f;
    AttackWindowRemaining = 0.0f;
    SlideTimeRemaining = 0.0f;
    InvulnerabilityTimeRemaining = 0.0f;

    GetCapsuleComponent()->SetCapsuleHalfHeight(StandingCapsuleHalfHeight, true);
    GetCharacterMovement()->SetMovementMode(MOVE_Walking);
    GetCharacterMovement()->Velocity = FVector::ZeroVector;

    FVector Location = GetActorLocation();
    Location.Y = 0.0f;
    SetActorLocation(Location, false);
    TargetLaneY = 0.0f;
    OnHealthChanged.Broadcast(CurrentHealth);
}

void ABlackthornOathCharacter::EndInvulnerability()
{
    bIsInvulnerable = false;
}

void ABlackthornOathCharacter::EndAttack()
{
    // The montage/animation Blueprint owns the visible recovery pose.
}
