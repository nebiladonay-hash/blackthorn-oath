#pragma once

#include "CoreMinimal.h"
#include "GameFramework/GameModeBase.h"
#include "BlackthornGameMode.generated.h"

UENUM(BlueprintType)
enum class EBlackthornRunState : uint8
{
    Title,
    Running,
    Paused,
    GameOver
};

DECLARE_DYNAMIC_MULTICAST_DELEGATE(FBlackthornRunUpdated);

UCLASS()
class BLACKTHORNOATH_API ABlackthornGameMode : public AGameModeBase
{
    GENERATED_BODY()

public:
    ABlackthornGameMode();

    virtual void BeginPlay() override;
    virtual void Tick(float DeltaSeconds) override;

    UFUNCTION(BlueprintCallable, Category="Run")
    void BeginRun();

    UFUNCTION(BlueprintCallable, Category="Run")
    void PauseRun();

    UFUNCTION(BlueprintCallable, Category="Run")
    void ResumeRun();

    UFUNCTION(BlueprintCallable, Category="Run")
    void EndRun();

    UFUNCTION(BlueprintCallable, Category="Run")
    void AddKill();

    UFUNCTION(BlueprintCallable, Category="Run")
    void AddRelic();

    UFUNCTION(BlueprintCallable, Category="Run")
    void SaveProgress();

    UPROPERTY(BlueprintAssignable, Category="Run")
    FBlackthornRunUpdated OnRunUpdated;

    UPROPERTY(BlueprintReadOnly, Category="Run")
    EBlackthornRunState RunState = EBlackthornRunState::Title;

    UPROPERTY(BlueprintReadOnly, Category="Run")
    float Distance = 0.0f;

    UPROPERTY(BlueprintReadOnly, Category="Run")
    int32 Kills = 0;

    UPROPERTY(BlueprintReadOnly, Category="Run")
    int32 RunRelics = 0;

    UPROPERTY(BlueprintReadOnly, Category="Run")
    int32 RelicBank = 0;

    UPROPERTY(BlueprintReadOnly, Category="Run")
    int32 BestDistance = 0;

    UPROPERTY(EditDefaultsOnly, Category="Save")
    FString SaveSlotName = TEXT("BlackthornOath_Save");

private:
    UPROPERTY()
    TObjectPtr<class UBlackthornSaveGame> SaveData;

    UPROPERTY()
    TObjectPtr<class ABlackthornOathCharacter> PlayerCharacter;

    FVector RunStartLocation = FVector::ZeroVector;
    float RunElapsed = 0.0f;
    float InitialSpeed = 1200.0f;
    float SpeedAcceleration = 14.0f;
    float MaximumSpeed = 1850.0f;

    UFUNCTION()
    void HandlePlayerDeath();

    void LoadProgress();
};
