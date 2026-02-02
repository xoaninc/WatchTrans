# Problema RESUELTO: Líneas FEVE Asturias

**Fecha:** 2026-02-01
**Estado:** ✅ RESUELTO

## Resumen

Las líneas FEVE de Cercanías Asturias (red 20T) no mostraban salidas para paradas intermedias. El problema era un bug en el script de importación que no mapeaba correctamente los `stop_id` con ceros iniciales.

## Resultado Final

| Línea | Ruta | Estado |
|-------|------|--------|
| C4 | Gijón - Cudillero | ✅ Funcionando |
| C5 | Gijón - Laviana | ✅ Funcionando |
| C5a | Oviedo - El Berrón | ✅ Funcionando |
| C6 | Oviedo - Infiesto | ✅ Funcionando |
| C7 | Oviedo/Gijón - San Esteban | ✅ Funcionando |
| C8 | Baiña - Collanzo | ✅ Funcionando |

### Ejemplos verificados:

```
C4: Candás      → ✅ 5 salidas
C5: Noreña      → ✅ 5 salidas (07:21 → Gijón, 07:27 → Laviana...)
C5a: El Berrón  → ✅ 5 salidas
C6: Pola Siero  → ✅ 5 salidas
C6: Nava        → ✅ 5 salidas
C7: Pravia      → ✅ 5 salidas (06:49 → Oviedo, 07:43 → San Esteban...)
C8: Figaredo    → ✅ 5 salidas (06:40 → Moreda, 07:11 → Baiña...)
```

## Causa Raíz

El GTFS de Renfe usa `stop_id` con ceros iniciales (`05210`), pero nuestra base de datos los almacena sin ceros (`RENFE_5210`). El mapping en `import_gtfs_static.py` no consideraba esta diferencia.

### Flujo del bug:

```
1. DB tiene: RENFE_5210 (sin cero)
2. Mapping crea: "5210" -> RENFE_5210
3. GTFS busca: "05210"
4. Lookup: stop_mapping.get("05210") → None! ❌
5. Stop_time descartado
```

## Fix Aplicado

**Archivo:** `scripts/import_gtfs_static.py`

**Cambio 1 - `import_missing_stops()` (línea ~190):**
```python
# Antes:
existing_stops.add(gtfs_id)

# Después:
existing_stops.add(gtfs_id)
existing_stops.add(gtfs_id.lstrip('0') or '0')  # Sin ceros
existing_stops.add(gtfs_id.zfill(5))  # Con ceros (5 dígitos)
```

**Cambio 2 - `import_stop_times()` (línea ~655):**
```python
# Antes:
stop_mapping[gtfs_id] = our_id

# Después:
stop_mapping[gtfs_id] = our_id
gtfs_id_stripped = gtfs_id.lstrip('0') or '0'
gtfs_id_padded = gtfs_id.zfill(5)
if gtfs_id_stripped != gtfs_id:
    stop_mapping[gtfs_id_stripped] = our_id
if gtfs_id_padded != gtfs_id:
    stop_mapping[gtfs_id_padded] = our_id
```

## Comandos ejecutados

```bash
# 1. Desplegar fix
rsync -avz scripts/import_gtfs_static.py root@juanmacias.com:/var/www/renfeserver/scripts/

# 2. Reimportar Asturias (núcleo 20)
ssh root@juanmacias.com "cd /var/www/renfeserver && source .venv/bin/activate && \
    PYTHONPATH=/var/www/renfeserver python scripts/import_gtfs_static.py \
    /tmp/fomento_transit.zip --nucleo 20"
```

## Resultado de la reimportación

```
Before:  88,735 stop_times
After:  188,841 stop_times  (+113%)
Skipped (stop not found): 0  ← Fix funcionó!
```

## Verificación

```bash
# Candás - antes sin salidas, ahora funciona
curl "https://redcercanias.com/api/v1/gtfs/stops/RENFE_5210/departures?limit=5"
# Resultado: 5 salidas de C4
```

## Todas las redes reimportadas

El fix se aplicó a TODAS las redes de Cercanías:

| Núcleo | Red | Stop Times | Skipped |
|--------|-----|------------|---------|
| 10 | Madrid | 555,563 | 0 ✅ |
| 20 | Asturias | 188,841 | 0 ✅ |
| 30 | Sevilla | 43,578 | 0 ✅ |
| 31 | Cádiz | 54,860 | 0 ✅ |
| 32 | Málaga | 58,500 | 0 ✅ |
| 40 | Valencia | 109,205 | 0 ✅ |
| 41 | Murcia/Alicante | 17,782 | 0 ✅ |
| 51 | Barcelona | 476,287 | 0 ✅ |
| 60 | Bilbao | 170,210 | 0 ✅ |
| 61 | San Sebastián | 43,942 | 0 ✅ |
| 62 | Santander | 82,912 | 0 ✅ |
| 70 | Zaragoza | 11,425 | 0 ✅ |

**Total: ~1.8M stop_times, 0 descartados**

## Lecciones aprendidas

1. Los `stop_id` en GTFS pueden tener formatos inconsistentes (con/sin ceros iniciales)
2. Al mapear IDs entre sistemas, considerar todas las variantes de formato
3. Verificar los datos GTFS originales antes de asumir que faltan datos
4. El mismo bug puede afectar múltiples redes - siempre reimportar todas después de un fix

---

# Importación FEVE (Redes adicionales)

**Fecha:** 2026-02-01
**Estado:** ✅ COMPLETADO

## Redes FEVE importadas

El feed GTFS de FEVE contiene líneas NO incluidas en el feed principal de Cercanías:

| Red | Línea | Ruta | Región | Color |
|-----|-------|------|--------|-------|
| 45T | C4 | Cartagena - Los Nietos | Murcia | #EF3340 (rojo) |
| 46T | C1 | Ferrol - Ortigueira | Galicia | #EF3340 (rojo) |
| 47T | C1/BUS | León - Cistierna | León | #EF3340 (rojo) |

## Resultado de la importación

```
Networks: 3 creadas
Routes: 12 importadas
Trips: 3,704 importados
Stop times: 54,971 importados (0 skipped)
```

## Verificación

```bash
# Ferrol - C1
curl "https://redcercanias.com/api/v1/gtfs/stops/RENFE_5102/departures?limit=5"
# → 5 salidas hacia Ortigueira/Ferrol ✅

# Cartagena - C4
curl "https://redcercanias.com/api/v1/gtfs/stops/RENFE_5951/departures?limit=5"
# → 5 salidas hacia Los Nietos ✅

# León - C1
curl "https://redcercanias.com/api/v1/gtfs/stops/RENFE_5753/departures?limit=5"
# → 5 salidas hacia Cistierna ✅
```

## Colores

El GTFS original usa cyan (00FFFF) para todas las líneas FEVE. Se actualizó a rojo C1 (#EF3340) para consistencia con otras redes de Cercanías.

## Correspondencias

Las redes FEVE están en zonas rurales sin conexiones con metro/tranvía:
- **Ferrol**: Sin correspondencias
- **Cartagena**: Sin correspondencias
- **León**: Sin correspondencias

---

# Limpieza de duplicados

**Fecha:** 2026-02-01
**Estado:** ✅ COMPLETADO

## Problema

El GTFS de Cercanías y FEVE crearon paradas duplicadas con/sin ceros iniciales:
- `RENFE_05770` (duplicado)
- `RENFE_5770` (correcto)

## Resultado de la limpieza

```
Duplicados encontrados: 210
Stop times migrados: 1,020
Correspondencias migradas: 6
Stops eliminados: 210
```

## Script ejecutado

```python
# 1. Mapear duplicados (con ceros -> sin ceros)
# 2. UPDATE gtfs_stop_times SET stop_id = sin_ceros WHERE stop_id = con_ceros
# 3. UPDATE stop_correspondence (from_stop_id y to_stop_id)
# 4. DELETE FROM gtfs_stops WHERE id = ANY(duplicados)
```

## Documentación

Ver `docs/IMPORT_FEVE.md` para documentación completa del proceso de importación FEVE.

---

# GTFS-RT para redes FEVE

**Estado:** ❌ NO DISPONIBLE

## Verificación

Renfe NO proporciona GTFS-RT para las redes FEVE (45T, 46T, 47T):

```
Feed gtfsrt.renfe.com - Redes incluidas:
  10T (Madrid)        ✅
  20T (Asturias)      ✅
  30T (Sevilla)       ✅
  31T (Cádiz)         ✅
  32T (Málaga)        ✅
  40T (Valencia)      ✅
  41T (Murcia)        ✅
  51T (Barcelona)     ✅
  60T (Bilbao)        ✅
  61T (San Sebastián) ✅
  62T (Santander)     ✅
  70T (Zaragoza)      ✅
  45T (Cartagena)     ❌ No incluido
  46T (Ferrol)        ❌ No incluido
  47T (León)          ❌ No incluido
```

## Consecuencias

Para las líneas FEVE, la app mostrará:
- ✅ Horarios estáticos (funcionan)
- ❌ Sin posición del tren en tiempo real
- ❌ Sin información de retrasos
- ❌ Sin predicción de andenes

## Configuración aplicada

```sql
-- nucleo_id_renfe configurado para futura compatibilidad
UPDATE gtfs_networks SET nucleo_id_renfe = 45 WHERE code = '45T';
UPDATE gtfs_networks SET nucleo_id_renfe = 46 WHERE code = '46T';
UPDATE gtfs_networks SET nucleo_id_renfe = 47 WHERE code = '47T';
```
