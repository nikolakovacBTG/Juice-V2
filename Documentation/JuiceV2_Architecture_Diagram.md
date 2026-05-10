# Juice V2 Architecture Diagram

This document contains a Mermaid diagram mapping the complete class hierarchy of the Juice V2 system. It outlines the core node controllers, dynamic orchestrators, effect base classes, domain-specific implementations, and meta-utilities.

### System Overview
The **Juice System** is a robust, non-destructive, component-based visual effects framework for Godot 4.x. Designed with a strict separation-of-concerns architecture, it prevents visual effects from permanently drifting or breaking a node's base state. 

Key architectural pillars of **V2**:
- **Dynamic Orchestration (`JuiceOrchestrator`)**: Moving away from domain nodes owning the tick loop, V2 utilizes a "born, do job, die" pattern. An orchestrator dynamically spawns as a node to drive the `_process` tick for a single animation session and frees itself when done, decoupling lifecycle management from configuration.
- **Ledger Aggregation (`JuiceLedger`)**: A centralized state aggregation system that holds base states and combined deltas. All active orchestrators register and clean up their writes here, preventing conflicts across stacked effects.
- **Domain Nodes (`JuiceControl`, `Juice2D`, `Juice3D`)**: Act as localized configuration holders. They hold references to recipes and spawn the appropriate orchestrator via the factory.
- **Effects as Data (`JuiceEffectBase`)**: Effects are purely mathematical, stateless Resource objects. They never mutate the target node directly; they only calculate a "delta" (offset) for a given progress value.
- **Domain Separation**: A strict type system (via `JuiceRecipe` whitelists) ensures that 2D effects can only be applied to 2D nodes, Control effects to UI nodes, etc., preventing runtime type crashes.

```mermaid
graph LR
    %% Base Godot Classes
    Node_Root("Godot Node"):::GodotClass
    Resource_Root("Godot Resource"):::GodotClass
    RefCounted_Root("Godot RefCounted"):::GodotClass

    %% CORE ORCHESTRATION & STATE ==========================
    Node_Root --> JuiceBase:::CoreNode
    Node_Root --> JuiceOrchestrator:::CoreNode
    Node_Root --> JuicePreviewDirector:::CoreNode
    
    RefCounted_Root --> JuiceLedger:::CoreNode
    RefCounted_Root --> JuiceOrchestratorFactory:::CoreNode
    
    Note_JuiceBase("📝 DOMAIN CONFIGURATION<br>Holds inspector config and recipe references.<br>Delegates lifecycle to Orchestrator."):::PostIt
    JuiceBase -.-> Note_JuiceBase

    Note_Orchestrator("📝 DYNAMIC LIFECYCLE<br>'Born, do job, die' pattern.<br>Drives _process per animation session."):::PostIt
    JuiceOrchestrator -.-> Note_Orchestrator

    JuiceOrchestratorFactory -. "Spawns PREVIEW/RUNTIME" .-> JuiceOrchestrator
    JuiceBase -. "Delegates to" .-> JuiceOrchestratorFactory
    JuicePreviewDirector -. "Drives Editor Preview" .-> JuiceBase

    Note_Ledger("📝 DELTA AGGREGATOR<br>Shared state holding base values & combined deltas<br>across multiple orchestrators."):::PostIt
    JuiceLedger -.-> Note_Ledger
    
    JuiceOrchestrator -. "Registers/Cleans up" .-> JuiceLedger

    JuiceBase --> JuiceControl:::DomainNode
    JuiceBase --> Juice2D:::DomainNode
    JuiceBase --> Juice3D:::DomainNode

    %% RECIPES ==============================================
    Resource_Root --> JuiceRecipe:::CoreResource
    
    Note_Recipe("📝 TYPE SAFETY GATEWAY<br>Narrows inspector dropdowns to specific domains<br>(e.g. 2D effects for 2D nodes) to prevent crashes."):::PostIt
    JuiceRecipe -.-> Note_Recipe

    JuiceRecipe --> JuiceControlRecipe:::DomainResource
    JuiceRecipe --> Juice2DRecipe:::DomainResource
    JuiceRecipe --> Juice3DRecipe:::DomainResource

    %% EFFECT BASES =========================================
    Resource_Root --> JuiceEffectBase:::CoreResource
    
    Note_EffectBase("📝 PURE DATA COMPONENT<br>Stateless math calculator. Never mutates target.<br>Outputs a single 'delta' per tick."):::PostIt
    JuiceEffectBase -.-> Note_EffectBase

    JuiceEffectBase --> JuiceControlEffectBase:::BaseClass
    JuiceEffectBase --> Juice2DEffectBase:::BaseClass
    JuiceEffectBase --> Juice3DEffectBase:::BaseClass

    %% CONTROL DOMAIN EFFECTS ===============================
    JuiceControlEffectBase --> JuiceControlAppearanceEffect:::BaseClass
    JuiceControlAppearanceEffect --> AppearanceControlJuiceEffect:::ConcreteClass

    JuiceControlEffectBase --> JuiceControlTransformEffect:::BaseClass
    JuiceControlTransformEffect --> TransformControlJuiceEffect:::ConcreteClass
    JuiceControlTransformEffect --> ShakeControlJuiceEffect:::ConcreteClass
    JuiceControlTransformEffect --> NoiseControlJuiceEffect:::ConcreteClass
    JuiceControlTransformEffect --> SquashStretchControlJuiceEffect:::ConcreteClass
    JuiceControlTransformEffect --> ProgressTransformControlJuiceEffect:::ConcreteClass

    %% 2D DOMAIN EFFECTS ====================================
    Juice2DEffectBase --> Juice2DAppearanceEffect:::BaseClass
    Juice2DAppearanceEffect --> Appearance2DJuiceEffect:::ConcreteClass

    Juice2DEffectBase --> Juice2DTransformEffect:::BaseClass
    Juice2DTransformEffect --> Transform2DJuiceEffect:::ConcreteClass
    Juice2DTransformEffect --> Shake2DJuiceEffect:::ConcreteClass
    Juice2DTransformEffect --> Noise2DJuiceEffect:::ConcreteClass
    Juice2DTransformEffect --> SquashStretch2DJuiceEffect:::ConcreteClass
    Juice2DTransformEffect --> ProgressTransform2DJuiceEffect:::ConcreteClass

    %% 3D DOMAIN EFFECTS ====================================
    Juice3DEffectBase --> Juice3DAppearanceEffect:::BaseClass
    Juice3DAppearanceEffect --> Appearance3DJuiceEffect:::ConcreteClass

    Juice3DEffectBase --> Juice3DTransformEffect:::BaseClass
    Juice3DTransformEffect --> Transform3DJuiceEffect:::ConcreteClass
    Juice3DTransformEffect --> Shake3DJuiceEffect:::ConcreteClass
    Juice3DTransformEffect --> Noise3DJuiceEffect:::ConcreteClass
    Juice3DTransformEffect --> SquashStretch3DJuiceEffect:::ConcreteClass
    Juice3DTransformEffect --> ProgressTransform3DJuiceEffect:::ConcreteClass

    %% META: PROPERTY EFFECTS ===============================
    JuiceEffectBase --> PropertyJuiceEffectBase:::BaseClass
    
    PropertyJuiceEffectBase --> PropertyInterpolateJuiceEffectBase:::BaseClass
    PropertyInterpolateJuiceEffectBase --> PropertyInterpolateControlJuiceEffect:::ConcreteClass
    PropertyInterpolateJuiceEffectBase --> PropertyInterpolate2DJuiceEffect:::ConcreteClass
    PropertyInterpolateJuiceEffectBase --> PropertyInterpolate3DJuiceEffect:::ConcreteClass

    PropertyJuiceEffectBase --> PropertyNoiseJuiceEffectBase:::BaseClass
    PropertyNoiseJuiceEffectBase --> PropertyNoiseControlJuiceEffect:::ConcreteClass
    PropertyNoiseJuiceEffectBase --> PropertyNoise2DJuiceEffect:::ConcreteClass
    PropertyNoiseJuiceEffectBase --> PropertyNoise3DJuiceEffect:::ConcreteClass

    PropertyJuiceEffectBase --> PropertyShakeJuiceEffectBase:::BaseClass
    PropertyShakeJuiceEffectBase --> PropertyShakeControlJuiceEffect:::ConcreteClass
    PropertyShakeJuiceEffectBase --> PropertyShake2DJuiceEffect:::ConcreteClass
    PropertyShakeJuiceEffectBase --> PropertyShake3DJuiceEffect:::ConcreteClass

    JuiceEffectBase --> PropertyProgressJuiceEffectBase:::BaseClass
    PropertyProgressJuiceEffectBase --> PropertyProgressControlJuiceEffect:::ConcreteClass
    PropertyProgressJuiceEffectBase --> PropertyProgress2DJuiceEffect:::ConcreteClass
    PropertyProgressJuiceEffectBase --> PropertyProgress3DJuiceEffect:::ConcreteClass

    %% META: UTILITY EFFECTS ================================
    JuiceEffectBase --> CallMethodJuiceUtilityBase:::BaseClass
    CallMethodJuiceUtilityBase --> CallMethodControlJuiceUtility:::ConcreteClass
    CallMethodJuiceUtilityBase --> CallMethod2DJuiceUtility:::ConcreteClass
    CallMethodJuiceUtilityBase --> CallMethod3DJuiceUtility:::ConcreteClass

    JuiceEffectBase --> SceneActionJuiceUtilityBase:::BaseClass
    SceneActionJuiceUtilityBase --> SceneActionControlJuiceUtility:::ConcreteClass
    SceneActionJuiceUtilityBase --> SceneAction2DJuiceUtility:::ConcreteClass
    SceneActionJuiceUtilityBase --> SceneAction3DJuiceUtility:::ConcreteClass

    JuiceEffectBase --> SignalEmitJuiceUtilityBase:::BaseClass
    SignalEmitJuiceUtilityBase --> SignalEmitControlJuiceUtility:::ConcreteClass
    SignalEmitJuiceUtilityBase --> SignalEmit2DJuiceUtility:::ConcreteClass
    SignalEmitJuiceUtilityBase --> SignalEmit3DJuiceUtility:::ConcreteClass

    %% META: TIME EFFECTS ===================================
    JuiceEffectBase --> TimeJuiceEffectBase:::BaseClass
    TimeJuiceEffectBase --> TimeControlJuiceEffect:::ConcreteClass
    TimeJuiceEffectBase --> Time2DJuiceEffect:::ConcreteClass
    TimeJuiceEffectBase --> Time3DJuiceEffect:::ConcreteClass

    %% SCREEN & CAMERA EFFECTS ==============================
    JuiceEffectBase --> ScreenJuiceEffect:::ConcreteClass
    JuiceEffectBase --> ScreenOverlayJuiceEffectBase:::BaseClass
    ScreenOverlayJuiceEffectBase --> ScreenOverlayControlJuiceEffect:::ConcreteClass
    ScreenOverlayJuiceEffectBase --> ScreenOverlay2DJuiceEffect:::ConcreteClass
    ScreenOverlayJuiceEffectBase --> ScreenOverlay3DJuiceEffect:::ConcreteClass

    JuiceEffectBase --> Camera2DJuiceEffect:::ConcreteClass
    JuiceEffectBase --> Camera3DJuiceEffect:::ConcreteClass

    %% NODE UTILITIES =======================================
    Node_Root --> CameraJuiceUtility:::UtilityNode
    Node_Root --> SignalRelayJuiceUtility:::UtilityNode
    Node_Root --> TimeCoordinatorJuiceUtility:::UtilityNode
    Godot_Control("Godot Control"):::GodotClass --> SoftTriggerControlJuiceUtility:::UtilityNode
    Godot_Area2D("Godot Area2D"):::GodotClass --> SoftTrigger2DJuiceUtility:::UtilityNode
    Godot_Area2D --> Interaction2DJuiceUtility:::UtilityNode
    Godot_Area3D("Godot Area3D"):::GodotClass --> SoftTrigger3DJuiceUtility:::UtilityNode
    Godot_Area3D --> Interaction3DJuiceUtility:::UtilityNode

    %% META SUB-RESOURCES ===================================
    Resource_Root --> PropertyTarget:::BaseClass
    PropertyTarget --> InterpolatePropertyTarget:::ConcreteClass
    PropertyTarget --> NoisePropertyTarget:::ConcreteClass
    PropertyTarget --> ShakePropertyTarget:::ConcreteClass

    Resource_Root --> CallMethodEntry:::ConcreteClass
    Resource_Root --> SignalEmitEntry:::ConcreteClass

    %% DEBUG LOGGING SYSTEM =================================
    RefCounted_Root --> JuiceLogger:::DebugUtil
    RefCounted_Root --> JuiceDebugReport:::DebugUtil

    Note_Logging("📝 CROSS-CUTTING DEBUG SERVICE<br>Three-tier gating: export-build strip → master switch → per-node flag.<br>Writes timestamped juice_*.log per session. Never overwrites."):::PostIt
    JuiceLogger -.-> Note_Logging

    %% Who calls JuiceLogger
    JuiceOrchestrator -. "log_info" .-> JuiceLogger
    JuiceBase -. "log_info / warn" .-> JuiceLogger
    JuiceEffectBase -. "log_info / log_delta" .-> JuiceLogger

    %% JuiceDebugReport reads from JuiceLogger
    JuiceDebugReport -. "reads LOG_FILE_PATH" .-> JuiceLogger


    classDef GodotClass fill:#1c2433,stroke:#3e4c63,stroke-width:2px,color:#d8dee9;
    classDef CoreNode fill:#36537a,stroke:#5c81b5,stroke-width:2px,color:#fff;
    classDef CoreResource fill:#45594b,stroke:#6f8f79,stroke-width:2px,color:#fff;
    classDef DomainNode fill:#286b96,stroke:#44a3e3,stroke-width:1px,color:#fff;
    classDef DomainResource fill:#3b6949,stroke:#5eab75,stroke-width:1px,color:#fff;
    classDef BaseClass fill:#4f4333,stroke:#857157,stroke-dasharray: 5 5,color:#fff;
    classDef ConcreteClass fill:#6e333b,stroke:#b85663,stroke-width:1px,color:#fff;
    classDef UtilityNode fill:#5c4066,stroke:#9769a8,stroke-width:1px,color:#fff;
    classDef DebugUtil fill:#2e4a4f,stroke:#4a9eaa,stroke-width:2px,color:#fff;
    classDef PostIt fill:#fff59d,stroke:#fbc02d,stroke-width:1px,color:#000,stroke-dasharray: 0;
```
