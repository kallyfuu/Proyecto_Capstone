-- ============================================================================
-- Migración: Registro de Consentimiento — Ley N° 21.719
-- Tabla afectada: public.negocios
-- Instrucciones: Copiar y ejecutar en el SQL Editor de Supabase (es idempotente)
-- ============================================================================

-- 1. Agregar columnas de consentimiento a la tabla public.negocios
ALTER TABLE public.negocios
  ADD COLUMN IF NOT EXISTS acepto_terminos BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS fecha_aceptacion_terminos TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS version_terminos TEXT;

COMMENT ON COLUMN public.negocios.acepto_terminos IS
  'Indica si el dueño aceptó expresamente los términos y el tratamiento de datos personales (Ley N° 21.719).';
COMMENT ON COLUMN public.negocios.fecha_aceptacion_terminos IS
  'Fecha y hora exacta (UTC) en que el usuario aceptó los términos al registrarse.';
COMMENT ON COLUMN public.negocios.version_terminos IS
  'Versión del texto legal de términos y privacidad aceptado (ej. 1.0).';

-- ============================================================================
-- 2. Trigger automático desde auth.users hacia public.negocios
--    Copia el consentimiento enviado en auth.signUp(data: {...}) apenas se crea
--    la cuenta, incluso antes de que el usuario confirme su correo electrónico.
-- ============================================================================
CREATE OR REPLACE FUNCTION public.sync_terminos_ley_21719()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_fecha TIMESTAMPTZ;
  v_version TEXT;
BEGIN
  IF COALESCE(NEW.raw_user_meta_data->>'acepto_terminos', 'false') = 'true' THEN
    BEGIN
      v_fecha := NULLIF(NEW.raw_user_meta_data->>'fecha_aceptacion_terminos', '')::TIMESTAMPTZ;
    EXCEPTION WHEN OTHERS THEN
      v_fecha := now();
    END;

    v_fecha := COALESCE(v_fecha, now());
    v_version := COALESCE(NULLIF(NEW.raw_user_meta_data->>'version_terminos', ''), '1.0');

    UPDATE public.negocios
    SET
      acepto_terminos = true,
      fecha_aceptacion_terminos = COALESCE(fecha_aceptacion_terminos, v_fecha),
      version_terminos = COALESCE(version_terminos, v_version)
    WHERE id = NEW.id;
  END IF;

  RETURN NEW;
EXCEPTION WHEN OTHERS THEN
  -- Nunca bloquear el alta de auth.users ante un error inesperado;
  -- la app también sincroniza estas columnas al iniciar sesión.
  RETURN NEW;
END;
$$;

-- El prefijo "zz_" garantiza en PostgreSQL que este trigger AFTER INSERT corra
-- después del trigger que inserta la fila inicial en public.negocios.
DROP TRIGGER IF EXISTS zz_sync_terminos_ley_21719 ON auth.users;
CREATE TRIGGER zz_sync_terminos_ley_21719
  AFTER INSERT OR UPDATE OF raw_user_meta_data ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_terminos_ley_21719();

-- ============================================================================
-- 3. Asegurar Row Level Security (RLS) en public.negocios
-- ============================================================================
ALTER TABLE public.negocios ENABLE ROW LEVEL SECURITY;

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

-- ============================================================================
-- 4. Comprobación de columnas y datos guardados
-- ============================================================================
SELECT
  id,
  nombre_negocio,
  correo,
  acepto_terminos,
  fecha_aceptacion_terminos,
  version_terminos
FROM public.negocios
ORDER BY fecha_aceptacion_terminos DESC NULLS LAST;
