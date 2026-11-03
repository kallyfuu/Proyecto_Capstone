# Actualización de Base de Datos — Datos del Negocio (Ventana de Bienvenida)

## Objetivo
Habilitar en la tabla `public.negocios` de Supabase el almacenamiento completo de los datos que el almacenero registra en la nueva **Ventana de Bienvenida** y en la opción **Datos del negocio** de la aplicación móvil/web:

- **Nombre del dueño** (`nombre_dueno`)
- **Nombre del negocio** (`nombre_negocio`)
- **Dirección** (`direccion`)
- **Correo electrónico** (`correo`)
- **Teléfono de contacto** (`telefono`)

---

## Cómo guarda la información la App
Cuando el usuario completa el formulario en [`BienvenidaNegocioDialog`](../app/lib/screens/bienvenida_negocio_dialog.dart), la app ejecuta un `upsert` sobre `public.negocios` usando el `auth.uid()` de la sesión activa:

```dart
await supabase.from('negocios').upsert({
  'id': user.id,
  'nombre_dueno': dueno,
  'nombre_negocio': negocio,
  'direccion': direccion,
  'correo': correo,
  'telefono': telefono,
});
```

---

## Script SQL (Ejecutar en el SQL Editor de Supabase)

Este script es **idempotente** (usa `IF NOT EXISTS` y `DROP POLICY IF EXISTS`), por lo que no borra ni afecta los negocios o clientes que ya existen en la base de datos.

```sql
-- ============================================================================
-- 1. Agregar columnas de perfil a la tabla public.negocios
-- ============================================================================
ALTER TABLE public.negocios
  ADD COLUMN IF NOT EXISTS nombre_dueno TEXT,
  ADD COLUMN IF NOT EXISTS nombre_negocio TEXT,
  ADD COLUMN IF NOT EXISTS direccion TEXT,
  ADD COLUMN IF NOT EXISTS correo TEXT,
  ADD COLUMN IF NOT EXISTS telefono TEXT;

-- ============================================================================
-- 2. Asegurar que Row Level Security (RLS) esté activo en public.negocios
-- ============================================================================
ALTER TABLE public.negocios ENABLE ROW LEVEL SECURITY;

-- ============================================================================
-- 3. Políticas RLS para que cada dueño vea, cree y actualice solo su negocio
-- ============================================================================
DROP POLICY IF EXISTS "Dueño puede ver su negocio" ON public.negocios;
CREATE POLICY "Dueño puede ver su negocio"
  ON public.negocios
  FOR SELECT
  TO authenticated
  USING (id = auth.uid());

DROP POLICY IF EXISTS "Dueño puede insertar su negocio" ON public.negocios;
CREATE POLICY "Dueño puede insertar su negocio"
  ON public.negocios
  FOR INSERT
  TO authenticated
  WITH CHECK (id = auth.uid());

DROP POLICY IF EXISTS "Dueño puede actualizar su negocio" ON public.negocios;
CREATE POLICY "Dueño puede actualizar su negocio"
  ON public.negocios
  FOR UPDATE
  TO authenticated
  USING (id = auth.uid())
  WITH CHECK (id = auth.uid());
```

---

## Comprobación posterior

Después de correr el script en el **SQL Editor**, puedes ejecutar esta consulta para verificar que las columnas quedaron creadas correctamente:

```sql
SELECT column_name, data_type
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'negocios'
ORDER BY ordinal_position;
```

