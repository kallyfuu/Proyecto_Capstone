-- Datos de demostración para que el panel del negocio tenga historia.
--
-- Sin esto los gráficos muestran un solo mes con tres movimientos y no se
-- entiende nada. Esto siembra cuatro meses de actividad realista sobre los
-- clientes que ya existen.
--
-- Se corre desde el SQL Editor, que ejecuta como administrador y por eso puede
-- insertar en nombre del negocio. Desde la app esto no se podría hacer.

DO $$
DECLARE
  v_negocio UUID := '40d5baf9-a18c-4532-8d8b-2183e85a45da';
  v_cliente UUID;
  v_mes INT;
  v_dia INT;
  v_monto INT;
  v_conceptos TEXT[] := ARRAY[
    'Pan, leche y huevos', 'Bebidas', 'Abarrotes de la semana',
    'Cigarros y fósforos', 'Completos', 'Carbón y carne',
    'Detergente y cloro', 'Fideos, arroz y aceite', 'Helados',
    'Pack de cervezas', 'Once', 'Gas'
  ];
BEGIN
  -- Recorre los clientes del negocio y les inventa historia de los últimos
  -- cuatro meses. Los montos y la frecuencia varían por cliente para que las
  -- barras del gráfico no salgan todas iguales.
  FOR v_cliente IN
    SELECT id FROM public.clientes WHERE negocio_id = v_negocio AND activo
  LOOP
    FOR v_mes IN 0..3 LOOP

      -- Entre dos y cinco fiados por mes
      FOR v_dia IN 1..(2 + floor(random() * 4)::INT) LOOP
        v_monto := (1500 + floor(random() * 12000)::INT / 500 * 500);
        INSERT INTO public.transacciones
          (id, cliente_id, negocio_id, monto, concepto, es_offline, fecha_local)
        VALUES (
          gen_random_uuid(), v_cliente, v_negocio,
          -v_monto,
          v_conceptos[1 + floor(random() * array_length(v_conceptos, 1))::INT],
          false,
          date_trunc('month', now()) - (v_mes || ' months')::INTERVAL
            + (floor(random() * 27) || ' days')::INTERVAL
            + (floor(random() * 12) || ' hours')::INTERVAL
        );
      END LOOP;

      -- Un abono al mes en la mayoría de los casos: la gente paga por
      -- quincena, no cada vez que compra.
      IF random() < 0.75 THEN
        v_monto := (2000 + floor(random() * 20000)::INT / 500 * 500);
        INSERT INTO public.transacciones
          (id, cliente_id, negocio_id, monto, concepto, es_offline, fecha_local)
        VALUES (
          gen_random_uuid(), v_cliente, v_negocio,
          v_monto, 'Abono', false,
          date_trunc('month', now()) - (v_mes || ' months')::INTERVAL
            + (14 + floor(random() * 14) || ' days')::INTERVAL
        );
      END IF;

    END LOOP;
  END LOOP;
END $$;

-- Comprobación: cuánto se fió y cuánto se abonó cada mes.
SELECT to_char(date_trunc('month', fecha_local), 'YYYY-MM') AS mes,
       SUM(CASE WHEN monto < 0 THEN -monto ELSE 0 END) AS fiado,
       SUM(CASE WHEN monto > 0 THEN  monto ELSE 0 END) AS abonado,
       COUNT(*) AS movimientos
FROM public.transacciones
WHERE negocio_id = '40d5baf9-a18c-4532-8d8b-2183e85a45da'
GROUP BY 1
ORDER BY 1;

-- Y cómo quedó la cartera después del sembrado.
SELECT nombre, saldo, estado_riesgo
FROM public.v_clientes_saldo
WHERE negocio_id = '40d5baf9-a18c-4532-8d8b-2183e85a45da'
ORDER BY saldo;
