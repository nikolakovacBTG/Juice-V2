---
name: registration-guard
description: Enforces mandatory registration of new Juice V1 effects in domain recipes. Prevents "orphaned" effects that don't appear in the Godot inspector.
---

# Registration Guard Skill

**When to use:** Before declaring any V1 effect port or creation as "done".

## The Protocol

A V1 effect is not complete until it is registered in its respective Domain Recipe. If an effect is not registered, it will not appear as an option in the Godot Inspector when adding effects to a `JuiceControl`, `Juice2D`, or `Juice3D` node.

### 1. Identify the Target Recipes
Depending on the domains ported, check:
- **Control**: `addons/Juice_V1/Base Classes/JuiceControlRecipe.gd`
- **2D**: `addons/Juice_V1/Base Classes/Juice2DRecipe.gd`
- **3D**: `addons/Juice_V1/Base Classes/Juice3DRecipe.gd`

### 2. Verify Inclusion
Check the `_CONCRETE_EFFECTS` array (or equivalent registration method) in each file. The exact class name of your new effect MUST be present.

### 3. Verification Command (Grepping)
You can use `grep` to quickly verify:
```powershell
# Example: replace [EffectName] with your concrete class
grep "[EffectName]" "addons/Juice_V1/Base Classes/Juice2DRecipe.gd"
```

## Quality Gate
If the registration is missing, you MUST:
1. Add the effect class to the relevant recipe file.
2. Verify the list is alphabetically sorted (Juice project standard).
3. Confirm the file is saved before marking the task as complete.

> [!IMPORTANT]
> Failure to register an effect in the Recipe system makes the effect inaccessible to the user (Designers). It is a critical delivery failure.
