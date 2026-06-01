# Acknowledged Architecture Issues & Optimizations

Ovaj dokument bilježi arhitektonske propuste i uska grla u performansama (performance bottlenecks) koji su prepoznati tijekom analize koda, a koje treba riješiti u nadolazećim zakrpama ili refaktoriranjima (V1.1 / V2).


## 2. "The Inefficient Ledger Iteration" (Memory Churn & CPU Overhead)
**Lokacija:** `JuiceLedger.gd` -> `get_total()`, `sync_base_if_moved()`, `flush()`

### Problem
Prilikom računanja sume delti, kod iterira kroz vrijednosti rječnika koristeći metodu `.values()`:
```gdscript
for delta_val: Variant in ledger["deltas"][prop].values():
    if typeof(total_delta) == TYPE_COLOR and typeof(delta_val) == TYPE_COLOR:
        # ...
    else:
        total_delta += delta_val
```
1. **Memory Churn (Curenje memorije):** Poziv `Dictionary.values()` u GDScriptu **nije zero-allocation**. On svaki put iznova alocira potpuno novi niz (Array) u memoriji. S obzirom na to da se funkcije `sync_base_if_moved` i `flush` pozivaju svaki frejm za svaki animirani property (npr. 4 propertyja), jedan objekt stvara 8 array alokacija po frejmu. Za 50 neprijatelja na ekranu pri 60 FPS, to rezultira s **24,000 bespotrebnih array alokacija u sekundi**. Godotov Garbage Collector to mora stalno čistiti, što stvara opterećenje i rizik od mikro-stutteringa.
2. **Type-Checking Overhead:** `typeof()` se poziva za svaku stavku unutar petlje, iako se tip podatka (npr. `Vector2` naspram `Color`) ne mijenja usred iteracije istog propertyja.

### Rješenje (AAA Optimizacija)
Refaktorirati kod u "zero-allocation" petlje i izbaciti grane (hoisting) izvan petlje:
```gdscript
var dict: Dictionary = ledger["deltas"][prop]

# Provjera tipa SAMO JEDNOM izvan petlje
if typeof(total_delta) == TYPE_COLOR:
    for source_id in dict: # Iteracija po ključevima (nema .values() alokacije)
        var c_del := dict[source_id] as Color
        var c_tot := total_delta as Color
        total_delta = Color(c_tot.r * c_del.r, c_tot.g * c_del.g, c_tot.b * c_del.b, c_tot.a * c_del.a)
else:
    for source_id in dict:
        total_delta += dict[source_id]
```
Ovakav pristup u potpunosti eliminira alokaciju memorije po frejmu i smanjuje CPU overhead.
