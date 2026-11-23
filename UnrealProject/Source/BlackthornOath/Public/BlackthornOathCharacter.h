#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Character.h"
#include "BlackthornOathCharacter.generated.h"

DECLARE_DYNAMIC_MULTICAST_DELEGATE_OneParam(FBlackthornHealthChanged, int32, NewHealth);
DECLARE_DYNAMIC_MULTICAST_DELEGATE(FBlackthornPlayerDied);

UCLASS()
class BLACKTHORNOATH_API ABlackthornOathCharacter : public ACharacter
{
    GENERATED_BODY()

public:
    ABlackthornOathCharacter();

    virtual void Tick(float DeltaSeconds) override;
    virtual float TakeDamage(float DamageAmount, FDamageEvent const& DamageEvent,
        AController* EventInstigator, AActor* DamageCauser) override;

    UFUNCTION(BlueprintCallable, Category="Runner|Movement")
    void MoveLane(int32 Direction);

    UFUNCTION(BlueprintCallable, Category="Runner|Movement")
    void TriggerJump();

    UFUNCTION(BlueprintCallable, Category="Runner|Movement")
    void TriggerSlide();

    UFUNCTION(BlueprintCallable, Category="Runner|Combat")
    void TriggerAttack();

    UFUNCTION(BlueprintCallable, Category="Runner|Health")
    void RestoreHealth(int32 Amount);

    UFUNCTION(BlueprintCallable, Category="Runner|State")
    void ResetForRun();

    UPROPERTY(BlueprintAssignable, Category="Runner|Health")
    FBlackthornHealthChanged OnHealthChanged;

    UPROPERTY(BlueprintAssignable, Category="Runner|Health")
    FBlackthornPlayerDied OnPlayerDied;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Runner|Tuning")
    float LaneSpacing = 260.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Runner|Tuning")
    float ForwardSpeed = 1200.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Runner|Tuning")
    float MaximumForwardSpeed = 1850.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Runner|Tuning")
    float LaneInterpSpeed = 14.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Runner|Tuning")
    float SlideDuration = 0.78f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Runner|Tuning")
    float InvulnerabilityDuration = 1.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Runner|Tuning")
    float AttackCooldown = 0.58f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Runner|Tuning")
    float AttackRange = 320.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Runner|Tuning")
    float AttackRadius = 150.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Runner|State")
    int32 MaximumHealth = 3;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="Runner|State")
    int32 CurrentHealth = 3;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="Runner|State")
    int32 CurrentLane = 1;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="Runner|State")
    bool bIsSliding = false;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="Runner|State")
    bool bIsDead = false;

    UPROPERTY(VisibleAnywhere, BlueprintReadOnly, Category="Runner|State")
    bool bIsInvulnerable = false;

protected:
    virtual void BeginPlay() override;

    UFUNCTION(BlueprintImplementableEvent, Category="Runner|Animation")
    void OnSlideStateChanged(bool bSliding);

    UFUNCTION(BlueprintImplementableEvent, Category="Runner|Animation")
    void OnAttackStarted();

    UFUNCTION(BlueprintImplementableEvent, Category="Runner|Animation")
    void OnDamageReceived();

    UFUNCTION(BlueprintImplementableEvent, Category="Runner|Animation")
    void OnDeathStarted();

private:
    void EndSlide();
    void EndInvulnerability();
    void EndAttack();
    void PerformAttackTrace();

    FTimerHandle AttackHitTimer;
    void UpdateLanePosition();

    float StandingCapsuleHalfHeight = 92.5f;
    float SlidingCapsuleHalfHeight = 47.5f;
    float AttackCooldownRemaining = 0.0f;
    float AttackWindowRemaining = 0.0f;
    float SlideTimeRemaining = 0.0f;
    float InvulnerabilityTimeRemaining = 0.0f;
    float TargetLaneY = 0.0f;
};
