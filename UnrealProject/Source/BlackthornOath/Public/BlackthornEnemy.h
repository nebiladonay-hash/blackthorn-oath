#pragma once

#include "CoreMinimal.h"
#include "GameFramework/Actor.h"
#include "BlackthornEnemy.generated.h"

UENUM(BlueprintType)
enum class EBlackthornEnemyType : uint8
{
    HollowGuard,
    Bloodhound,
    Executioner
};

UCLASS()
class BLACKTHORNOATH_API ABlackthornEnemy : public AActor
{
    GENERATED_BODY()

public:
    ABlackthornEnemy();

    virtual void Tick(float DeltaSeconds) override;
    virtual float TakeDamage(float DamageAmount, FDamageEvent const& DamageEvent,
        AController* EventInstigator, AActor* DamageCauser) override;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Enemy")
    EBlackthornEnemyType EnemyType = EBlackthornEnemyType::HollowGuard;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Enemy")
    TObjectPtr<class ABlackthornOathCharacter> TargetPlayer;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Enemy")
    float AttackRange = 190.0f;

    UPROPERTY(EditAnywhere, BlueprintReadWrite, Category="Enemy")
    float AttackWindup = 0.42f;

    UPROPERTY(BlueprintReadOnly, Category="Enemy")
    int32 Health = 2;

    UPROPERTY(BlueprintReadOnly, Category="Enemy")
    bool bIsDead = false;

    UFUNCTION(BlueprintImplementableEvent, Category="Enemy|Presentation")
    void OnEnemyWindup();

    UFUNCTION(BlueprintImplementableEvent, Category="Enemy|Presentation")
    void OnEnemyHit();

    UFUNCTION(BlueprintImplementableEvent, Category="Enemy|Presentation")
    void OnEnemyDeath();

protected:
    virtual void BeginPlay() override;

private:
    float AttackInterval = 1.3f;
    float AttackCooldownRemaining = 0.8f;
    float WindupRemaining = 0.0f;
    bool bAttackPending = false;

    void ConfigureArchetype();
    void BeginAttack();
    void ResolveAttack();
};
