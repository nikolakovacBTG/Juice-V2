## RULE: Documentation Headers

**Purpose:** Define Juice script header formatting standards.

**Mission:** Ensure consistent, informative documentation across all scripts.

---

# ============================================================================
# WHAT: Juice script header formatting standards
# EXPECTS: All Juice scripts follow header format consistently
# PROVIDES: Consistent documentation and architectural context
# ARCHITECTURE: Rules layer that enforces documentation quality
# ============================================================================

## Header Format Requirements

### Mandatory Structure
```gdscript
## Brief sentence.
# 
## Detailed description.
##
## @tutorial(Name): URL

# ============================================================================
# WHAT: What this script does in one line
# EXPECTS: What it expects from parent/system (dependencies)
# PROVIDES: What it provides to parent/system (outputs)
# ARCHITECTURE: L1/L2/L3 position and key relationships
# ============================================================================
```

### Section Guidelines

#### Brief Sentence (Line 1)
- **Single sentence** describing the script's purpose
- **Visible in Add Child Node tooltip**
- **Present tense:** "Animates position..." not "Will animate..."

#### Detailed Paragraph (Lines 3-4)
- **Multiple sentences** explaining implementation details
- **System context:** What system this belongs to
- **Important notes:** Special requirements or behaviors
- **Not visible** in editor tooltip (script docs only)

#### Architectural Context (WHAT/EXPECTS/PROVIDES/ARCHITECTURE)
- **WHAT:** One-line description of functionality
- **EXPECTS:** Dependencies and requirements
- **PROVIDES:** Outputs and capabilities
- **ARCHITECTURE:** L1-3 position and relationships

## Examples

### L1 Core Example
```gdscript
## Core timing system for Juice animations.
##
## Provides unified timing infrastructure across all domains. Handles progress
## calculation, easing functions, and animation lifecycle management.
##
## @tutorial(Juice Architecture): https://example.com/juice

# ============================================================================
# WHAT: Unified timing and progress calculation for all Juice animations
# EXPECTS: L2 domain nodes to call timing methods for progress updates
# PROVIDES: Progress values, easing functions, and animation lifecycle hooks
# ARCHITECTURE: L1 core system used by all L2 domain nodes and L3 effects
# ============================================================================
```

### L2 Domain Example
```gdscript
## Domain node for Juice Control animations.
##
## Coordinates multiple Juice effects on Control targets. Handles delta
## aggregation, external move detection, and Container hold patterns.
##

# ============================================================================
# WHAT: Write coordination and delta aggregation for Control targets
# EXPECTS: L3 Control effects to provide delta calculations
# PROVIDES: Single coordinated write per frame to Control targets
# ARCHITECTURE: L2 domain node that aggregates L3 effects and writes to targets
# ============================================================================
```

### L3 Effect Example
```gdscript
## Transform animation effect for Control targets.
##
## Animate position of Control targets with tween-based easing. Extends
## JuiceControlEffectBase and provides delta calculations to domain node.
##

# ============================================================================
# WHAT: Position animation delta calculations for Control targets
# EXPECTS: JuiceControl parent node and JuiceControlRecipe with configuration
# PROVIDES: Position delta values to JuiceControl._post_tick_write()
# ARCHITECTURE: L3 effect that extends JuiceControlEffectBase, consumed by L2
# ============================================================================
```

## Comment Conventions

### Hash Usage
- **`##`** - Documentation visible in editor
- **`#`** - Internal documentation (source code only)
- **`# ============================================================================`** - Major section dividers

### Inspector Tooltips
```gdscript
## Above @export - shows in inspector hover and script docs
@export var animation_duration: float = 1.0

## Group of related properties
@export_group("Animation Settings", "anim_")
@export var anim_easing: String = "ease_in_out"
```

## Validation Rules

### Header Compliance
- [ ] Brief sentence on line 1
- [ ] Detailed paragraph (2+ sentences)
- [ ] WHAT/EXPECTS/PROVIDES/ARCHITECTURE section
- [ ] Proper hash usage (## vs #)
- [ ] Architectural context included

### Content Quality
- [ ] WHAT describes functionality clearly
- [ ] EXPECTS lists all dependencies
- [ ] PROVIDES describes all outputs
- [ ] ARCHITECTURE shows L1-3 position
- [ ] Concrete class references included

---

## Cross-References

**Related Rules:**
- See RULE-coding-standards.md for general coding standards
- See RULE-architecture-contracts.md for architectural rules

**Implementation Guides:**
- See L1 docs for core system headers
- See L2 docs for domain node headers
- See L3 docs for effect headers

This documentation header rule ensures consistent, informative documentation across all Juice scripts.
