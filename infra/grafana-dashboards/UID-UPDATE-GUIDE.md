# Dashboard UID Update Guide

## CloudWatch Datasource UID Locations
Replace `aevtysde4f4e8a` with your CloudWatch UID at these lines:

**Line 26:** ECS Service Memory panel datasource
```json
"uid": "aevtysde4f4e8a"  // <-- UPDATE THIS
```

**Line 108:** ECS Service Memory target datasource  
```json
"uid": "aevtysde4f4e8a"  // <-- UPDATE THIS
```

**Line 147:** ECS Service CPU panel datasource
```json
"uid": "aevtysde4f4e8a"  // <-- UPDATE THIS
```

**Line 229:** ECS Service CPU target datasource
```json
"uid": "aevtysde4f4e8a"  // <-- UPDATE THIS
```

**Line 268:** Container Count panel datasource
```json
"uid": "aevtysde4f4e8a"  // <-- UPDATE THIS
```

**Line 350:** Container Count target datasource
```json
"uid": "aevtysde4f4e8a"  // <-- UPDATE THIS
```

## Prometheus Datasource UID Locations
Replace `cevtyu88ul62ob` with your Prometheus UID at these lines:

**Line 289:** Stress Load panel datasource
```json
"uid": "cevtyu88ul62ob"  // <-- UPDATE THIS
```

**Line 371:** Individual Container CPU panel datasource
```json
"uid": "cevtyu88ul62ob"  // <-- UPDATE THIS
```

## Quick Find & Replace
Use your editor's find & replace:
- Find: `aevtysde4f4e8a` → Replace with your CloudWatch UID
- Find: `cevtyu88ul62ob` → Replace with your Prometheus UID