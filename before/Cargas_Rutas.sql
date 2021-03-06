USE [dsd_tepic]
GO
/****** Object:  StoredProcedure [dbo].[Cargas_Rutas]    Script Date: 12/11/2018 03:52:58 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		<Author,,Alejandro Castillo>
-- Create DATE: <Create DATE,,24/08/2016>
-- Description:	<Description,,consultas del modulo de cargas>
-- =============================================
ALTER PROCEDURE [dbo].[Cargas_Rutas] 
	-- Add the parameters for the stored procedure here
	@ruta INT,
	@lista_precios INT,
	@tipo INT,
	@fecha DATE,
	@fecha_calculo DATE,
	@id_producto INT  

AS
BEGIN

   DECLARE @temp_existencia_vehiculo TABLE(
      id_ruta INT,
      ruta VARCHAR(MAX),
      nombre VARCHAR(MAX),
      id_producto INT,
      producto VARCHAR(MAX),
      id_linea INT,
      linea VARCHAR(MAX),
      id_familia INT,
      Total FLOAT,
      Total2 FLOAT,
      Total3 FLOAT,
      empresa VARCHAR(MAX),
      cedis VARCHAR(MAX)
   )

   DECLARE @temp_inventario TABLE(
      proveedor_linea VARCHAR(MAX),
      id_producto INT,
      producto VARCHAR(MAX),
      orden INT,
      inventario_inicial INT,
      compras_cc INT,
      compras_sc INT,
      cargas INT,
      recargas INT,
      descargas INT,
      traspaso_almacen INT,
      inventario_final INT,
      precio_unitario FLOAT,
      inventario_pesos FLOAT,
      inventario_fisico INT,
      motivo_modifico VARCHAR(MAX),
      diferencia INT,
      diferencia_pesos FLOAT,
      inventario_ajuste INT
   )

   DELETE @temp_inventario
   DELETE @temp_existencia_vehiculo

   INSERT INTO @temp_inventario EXEC Inventario_Diario 1, @fecha, @fecha, 'INVENTARIO_DIARIO'
   INSERT INTO @temp_existencia_vehiculo EXEC Rep_Existencia_Vehiculo @fecha, 2, 1, 1

   SELECT ld.id_producto,ld.precio_unitario
   INTO #PRECIO
   FROM cat_lista_precios cl 
   INNER JOIN cat_lista_precios_detalle ld ON ld.id_lista_precio = cl.id_lista_precio
   WHERE cl.id_lista_precio = @lista_precios AND @fecha BETWEEN ld.fecha_inicio AND ld.fecha_fin

   SELECT 
   id_producto, 
   SUM(inventario_fisico) - SUM(carga) AS INV_ALMACEN, 
   SUM(inventatio_vehiculo) AS INV_VEHICULO,
   SUM(Dias_caducidad) AS Dias_caducidad
   INTO #TABLA_PRODUCTOS_CARGAS
   FROM (
	   /*INVENTARIO FISICO_ALMACEN*/
      SELECT 
      id_producto,
      cantidad AS inventario_fisico,
      0 AS inventario_almacen,
      0 AS carga, 
      0 AS inventatio_vehiculo, 
      0 AS Dias_caducidad,
      0 AS precio_unitario 
      FROM inventarios_fisicos 
      WHERE fecha=@fecha

	   /*INVENTARIO_FINAL_ALMACEN*/
      UNION ALL
	   SELECT 
      id_producto,
      0 AS inventario_fisico,
      inventario_final AS inventario_almacen,
      0 AS carga, 
      0 AS inventatio_vehiculo,
      0 AS Dias_caducidad,
      0 AS precio_unitario  
      FROM @temp_inventario 
	
	   /*INVENTARIO_VEHICULO*/
      UNION ALL
	   SELECT 
      id_producto,
      0 AS inventario_fisico,
      0 AS inventario_almacen,
      0 AS carga, 
      total AS inventatio_vehiculo,
      0 AS Dias_caducidad,
      0 AS precio_unitario 
      FROM @temp_existencia_vehiculo  
      WHERE id_ruta=@ruta

	   /*CARGAS FUERA DE FECHA */
      UNION ALL 
	   SELECT 
      CD.id_producto,
      0 AS inventario_fisico,
      0 AS inventario_almacen, 
      IIF(c.movimiento = 'DESCARGA', CD.cantidad * -1, CD.cantidad) AS carga, 
      0 AS inventatio_vehiculo,
      0 AS Dias_caducidad,
      0 AS precio_unitario
      FROM  cargas c
      INNER JOIN cargas_detalle CD ON c.id_carga = CD.id_carga 
      WHERE  c.fecha_registro >= @fecha  AND c.fecha_registro <> c.fecha
	
	   /*CADUCIDADES*/
      UNION ALL
	   SELECT 
      CDD.id_producto,
      0 AS inventario_fisico,
      0 AS inventario_almacen,
      0 AS carga,
      0 AS inventatio_vehiculo,
      MIN(DATEDIFF(DAY,GETDATE(), CDD.fecha_caducidad)) AS Dias_caducidad,
      0 AS precio_unitario
      FROM cat_productos_caducidades_detalle CDD,cat_productos_caducidades CD  
      WHERE CD.id_caducidad = CDD.id_caducidad AND CD.fecha = COALESCE((SELECT MAX(fecha) FROM cat_productos_caducidades),'1990-01-01')
      GROUP BY CDD.id_producto	
   )TABLA1
   WHERE inventario_fisico > 0 OR inventario_almacen > 0 OR inventatio_vehiculo > 0 OR Dias_caducidad <> 0 OR carga <> 0
   GROUP BY id_producto


   -- DESCARGAS
   IF @tipo = 1
   BEGIN
      SELECT 
      CONCAT(cat_proveedores_grupo.orden, ' - ', cat_proveedores_grupo.nombre, ' - ', cat_lineas.orden, ' - ', cat_lineas.nombre) AS proveedor_linea, 
      productos.id_producto, 
      MAX(cat_productos.nombre) AS producto, 
      MAX(cat_familias.orden) AS familia_orden, 
      MAX(cat_subfamilias.orden) AS subfamilia_orden, 
      MAX(lista.precio_unitario) AS Precio, 
	   SUM(inventario_almacen) AS Inventario_Almacen, 
	   SUM(inventario_vehiculo) AS Inventario_Vehiculo, 
	   SUM(cantidad) AS Cantidad,
	   COALESCE(Caducidades.dias, 50) AS dias_caducar
      FROM(
            SELECT 
            prod.id_producto, 
            SUM(inventario_almacen) AS inventario_almacen, 
            SUM(inventario_final + carga) AS inventario_vehiculo,
            0 AS cantidad,
            SUM(venta_anticipada) AS venta_anticipada
            FROM(
                  SELECT 
                  id_producto, 
                  existencia AS inventario_almacen, 
                  0 AS inventario_final,
                  0 AS carga,
                  0 AS venta_anticipada
                  FROM cat_productos
                  WHERE activo = 1  AND cat_productos.existencia > 0

                  UNION ALL
                  SELECT 
                  LQD.id_producto, 
                  0 AS inventario_almacen, 
                  LQD.inventario_final AS inv_vehiculo, 
                  0 AS carga,
                  0 AS venta_anticipada
                  FROM liquidaciones LQ
                  INNER JOIN liquidaciones_detalle LQD ON LQ.id_liquidacion = LQD.id_liquidacion
                  WHERE LQ.id_ruta = @ruta AND LQ.fecha_registro = COALESCE((SELECT MAX(fecha_registro) FROM liquidaciones WHERE id_ruta = @ruta AND liquidada = 1), '1900-01-01') AND LQD.inventario_final > 0

                  UNION ALL
                  SELECT 
                  CD.id_producto, 
                  0 AS inventario_almacen, 
                  0 AS inv_vehiculo, 
                  IIF(c.movimiento = 'DESCARGA', CD.cantidad * -1, CD.cantidad) AS carga, 
                  0 AS venta_anticipada
                  FROM cargas c
                  INNER JOIN cargas_detalle CD ON c.id_carga = CD.id_carga
                  WHERE c.id_ruta = @ruta AND c.fecha > COALESCE((SELECT MAX(fecha_registro) FROM liquidaciones WHERE id_ruta = @ruta AND liquidada = 1), '1900-01-01')
            ) prod 
            GROUP BY prod.id_producto
      ) productos
      INNER JOIN cat_productos ON productos.id_producto = cat_productos.id_producto
      INNER JOIN cat_lineas ON cat_productos.id_linea = cat_lineas.id_linea
      INNER JOIN cat_proveedores_grupo ON cat_productos.id_grupo_proveedor = cat_proveedores_grupo.id_grupo_proveedor
      INNER JOIN cat_proveedores ON cat_proveedores_grupo.id_grupo_proveedor = cat_proveedores.id_grupo_proveedor
      INNER JOIN cat_familias ON cat_productos.id_familia = cat_familias.id_familia
      INNER JOIN cat_subfamilias ON cat_productos.id_subfamilia = cat_subfamilias.id_subfamilia
      INNER JOIN (
                  SELECT id_producto, precio_unitario 
                  FROM cat_lista_precios_detalle 
                  WHERE id_lista_precio = @lista_precios AND (SELECT MAX(fecha_registro) FROM liquidaciones WHERE id_ruta = @ruta AND liquidada = 1) BETWEEN fecha_inicio AND fecha_fin   
      ) lista ON lista.id_producto = productos.id_producto
      LEFT JOIN (
                  SELECT CDD.id_producto, MIN(DATEDIFF(DAY,GETDATE(), CDD.fecha_caducidad)) AS Dias
                  FROM cat_productos_caducidades_detalle CDD,cat_productos_caducidades CD
                  WHERE CD.id_caducidad = CDD.id_caducidad AND CD.fecha = COALESCE((SELECT MAX(fecha) FROM cat_productos_caducidades),'1990-01-01')
                  GROUP BY CDD.id_producto
      ) Caducidades ON Caducidades.id_producto = productos.id_producto
      WHERE cat_proveedores.afecta_almacen = 1 AND cat_productos.activo = 1 AND Inventario_Vehiculo > 0
      GROUP BY cat_proveedores_grupo.orden, cat_proveedores_grupo.nombre, cat_lineas.orden, cat_lineas.nombre, productos.id_producto, Caducidades.dias
      ORDER BY proveedor_linea, familia_orden, subfamilia_orden, producto

   END

   -- RECARGAS
   IF @tipo = 2
   BEGIN
   
      SELECT SUM(total2) AS inventatio_vehiculo FROM @temp_existencia_vehiculo WHERE id_ruta = @ruta

	   --SELECT * FROM @temp_existencia_vehiculo -- WHERE id_ruta=@ruta
	   /*
	   SELECT CONCAT(cat_proveedores_grupo.orden, ' - ', cat_proveedores_grupo.nombre, ' - ', cat_lineas.orden, ' - ', cat_lineas.nombre) AS proveedor_linea, 
			   productos.id_producto, 
		   MAX(cat_productos.nombre) AS producto, 
		   MAX(cat_familias.orden) AS familia_orden, 
		   MAX(cat_subfamilias.orden) AS subfamilia_orden, 
		   MAX(lista.precio_unitario) AS Precio, 
		   SUM(inventario_almacen) AS Inventario_Almacen, 
		   SUM(inventario_vehiculo) AS Inventario_Vehiculo, 
		   SUM(cantidad) AS Cantidad,
		   COALESCE(Caducidades.dias, 50) AS dias_caducar 
			   FROM (  
					   SELECT prod.id_producto, SUM(inventario_almacen) AS inventario_almacen, SUM(inventario_final + carga) AS inventario_vehiculo, cantidad = 0, sum(venta_anticipada)as venta_anticipada  
						   FROM ( 
    								   SELECT id_producto, existencia AS inventario_almacen, inventario_final = 0, carga = 0,0 AS venta_anticipada  
    									   FROM cat_productos  
    								   WHERE activo = 1  AND cat_productos.existencia > 0   
    							   UNION ALL   
    								   SELECT LQD.id_producto, inventario_almacen = 0, LQD.inventario_final AS inv_vehiculo, carga = 0,0 AS venta_anticipada   
    									   FROM liquidaciones LQ 					
    										   INNER JOIN liquidaciones_detalle LQD ON LQ.id_liquidacion = LQD.id_liquidacion  
    								   WHERE  LQ.id_ruta = @ruta AND  LQ.fecha_registro = COALESCE((SELECT MAX(fecha_registro) FROM liquidaciones WHERE id_ruta = @ruta AND liquidada = 1), '1900-01-01') AND LQD.inventario_final > 0  
    							   UNION ALL  
    								   SELECT CD.id_producto, inventario_almacen = 0, inv_vehiculo = 0, IIF(c.movimiento = 'DESCARGA', CD.cantidad * -1, CD.cantidad) AS carga, 
    										   0 AS venta_anticipada 
										   FROM  cargas c 
    										   INNER JOIN cargas_detalle CD ON c.id_carga = CD.id_carga 
    									   WHERE c.id_ruta = @ruta AND c.fecha > COALESCE((SELECT MAX(fecha_registro) FROM liquidaciones WHERE id_ruta = @ruta AND liquidada = 1), '1900-01-01') 
						   ) prod GROUP BY prod.id_producto 
			   ) productos   
			   INNER JOIN cat_productos ON productos.id_producto = cat_productos.id_producto  
			   INNER JOIN cat_lineas ON cat_productos.id_linea = cat_lineas.id_linea  
			   INNER JOIN cat_proveedores_grupo ON cat_productos.id_grupo_proveedor = cat_proveedores_grupo.id_grupo_proveedor  
			   INNER JOIN cat_proveedores ON cat_proveedores_grupo.id_grupo_proveedor = cat_proveedores.id_grupo_proveedor  
			   INNER JOIN cat_familias ON cat_productos.id_familia = cat_familias.id_familia  
			   INNER JOIN cat_subfamilias ON cat_productos.id_subfamilia = cat_subfamilias.id_subfamilia 
			   INNER JOIN (SELECT id_producto,precio_unitario FROM cat_lista_precios_detalle WHERE id_lista_precio=@lista_precios AND  
    					   (SELECT COALESCE(MAX(fecha_registro),getDATE()) FROM liquidaciones WHERE  liquidada = 1) between fecha_inicio AND fecha_fin   
    					   )lista ON lista.id_producto =productos.id_producto  
			   LEFT JOIN (SELECT CDD.id_producto,MIN(DATEDIFF(DAY,GETDATE(), CDD.fecha_caducidad)) AS Dias  
    					   FROM cat_productos_caducidades_detalle CDD,cat_productos_caducidades CD  
    					   WHERE CD.id_caducidad = CDD.id_caducidad AND CD.fecha = COALESCE((SELECT MAX(fecha) FROM cat_productos_caducidades),'1990-01-01')  
    					   GROUP BY CDD.id_producto)  Caducidades ON Caducidades.id_producto = productos.id_producto  
	   WHERE cat_proveedores.afecta_almacen = 1 AND cat_productos.activo = 1 AND cat_productos.existencia > 0 AND cat_productos.existencia > 0
	   GROUP BY cat_proveedores_grupo.orden, cat_proveedores_grupo.nombre, cat_lineas.orden, cat_lineas.nombre,productos.id_producto,Caducidades.dias  
	   ORDER BY proveedor_linea, familia_orden, subfamilia_orden, producto */
   END


   -- CARGA LAS RUTAS
   IF @tipo = 3
   BEGIN
      SELECT id_ruta, ruta FROM cat_rutas
      WHERE id_ruta NOT IN (2,3) AND activo = 1
      ORDER BY nombre
   END


   -- saca la lista de precios y el inventario maximo en vehiculo
   IF @tipo = 4
   BEGIN
      SELECT 
      SUM(inventario_maximo) AS inventario_maximo,
      SUM(cargas_exe) AS cargas_exe,
      SUM(entrega_anticipada) AS entrega_anticipada,
      SUM(inv_vehiculo_importe) AS inv_vehiculo_importe
      FROM(
            SELECT 
            cr.inventario_maximo AS inventario_maximo, 
            COALESCE(ce.importe, 0) AS cargas_exe, 
            0 AS entrega_anticipada, 
            0 AS inv_vehiculo_importe
            FROM cat_rutas cr
            LEFT JOIN cargas_excedentes ce ON ce.id_ruta = cr.id_ruta AND fecha = @fecha AND usado = 0 AND ce.activo=1
            WHERE cr.id_ruta = @ruta 

            UNION
            SELECT
            0 AS inventario_maximo, 
            0 AS cargas_exe,
            efectivo + cheques + fichas_deposito AS entrega_anticipada,
            0 AS inv_vehiculo_importe
            FROM cortes_caja_vendedores
            WHERE id_ruta = @ruta AND id_entrega = (SELECT id_entrega FROM entrega_anticipada WHERE fecha = @fecha AND activo = 1)

            UNION 
		      SELECT
            0 AS inventario_maximo, 
            0 AS cargas_exe,
            0 AS entrega_anticipada, 
            SUM(inv_vehiculo_importe) + SUM(carga_im) AS inv_vehiculo_importe 
            FROM(
                  SELECT  
                  SUM(INV_VEHICULO) AS INV_VEHICULO,
                  SUM(INV_VEHICULO) * MAX(#PRECIO.precio_unitario) AS inv_vehiculo_importe,
                  SUM(carga_pz.carga) AS carga,
                  SUM(COALESCE(carga_pz.carga,0)) * MAX(#PRECIO.precio_unitario) AS carga_im
                  FROM #TABLA_PRODUCTOS_CARGAS
                  INNER JOIN #PRECIO ON #PRECIO.id_producto = #TABLA_PRODUCTOS_CARGAS.id_producto
                  LEFT JOIN (
                              SELECT CD.id_producto, IIF(c.movimiento = 'DESCARGA', CD.cantidad * -1, CD.cantidad) AS carga
                              FROM  cargas c
                              INNER JOIN cargas_detalle CD ON c.id_carga = CD.id_carga
                              WHERE c.fecha_registro >= @fecha AND c.fecha_registro <> c.fecha AND c.id_ruta=@ruta
                  ) carga_pz ON carga_pz.id_producto = #TABLA_PRODUCTOS_CARGAS.id_producto
                  GROUP BY #TABLA_PRODUCTOS_CARGAS.id_producto
            ) inv_veh
      )tabla
   END


	   /*
	   IF @tipo = 5 -- saca el inventario maximo en vehiculo
	   BEGIN
		   --SELECT inventario_maximo 
			   --FROM cat_rutas 
		   --WHERE id_ruta = @ruta
			   /*SELECT  0 AS id_lista_precio, 0 AS inventario_maximo, 0 AS  cargas_exe,0 AS entrega_anticipada,sum(inv_vehiculo_importe) AS inv_vehiculo_importe FROM (
		   SELECT sum(INV_VEHICULO+carga)*#PRECIO.precio_unitario AS inv_vehiculo_importe  
		   FROM #TABLA_PRODUCTOS_CARGAS
		   INNER JOIN #PRECIO ON #PRECIO.id_producto=#TABLA_PRODUCTOS_CARGAS.id_producto
		   GROUP BY #TABLA_PRODUCTOS_CARGAS.id_producto,#PRECIO.precio_unitario) inv_vehiculo*/
	   enD

	   IF @tipo = 6 -- para los dias de entregas anticipadas
	   BEGIN
		   SELECT * FROM entrega_anticipada WHERE fecha = @fecha AND activo = 1
	   END 

	   IF @tipo = 7 -- resta el efectivo, fichas de deposito y cheques para liberar inventarios.
	   BEGIN
		   SELECT efectivo+cheques+fichas_deposito AS entrega_anticipada 
			   FROM cortes_caja_vendedores 
		   WHERE id_ruta = @ruta  AND id_entrega=(SELECT id_entrega FROM entrega_anticipada WHERE  fecha = @fecha) 
	   END

	   IF @tipo = 8 -- JALA EL IMPORTE DE LAS CARGAS EXEDENTES
	   BEGIN
		   SELECT importe 
			   FROM cargas_excedentes 
		   WHERE fecha = @fecha AND id_ruta = @ruta AND activo = 1 AND usado = 0
	   end
	
	   IF @tipo = 9 --saca la maxima fecha de las cargas que difieran de descargas
	   BEGIN
		   SELECT MAX(fecha) AS fecha 
			   FROM cargas 
		   WHERE id_ruta = @ruta AND movimiento <> 'DESCARGA' 
	   END 

	   IF @tipo = 10 -- busca la ultima liquidacion
	   BEGIN
		   SELECT MAX(fecha_registro) AS fecha_registro 
			   FROM liquidaciones 
		   WHERE id_ruta = @ruta AND liquidada = 1
	   end

	   IF @tipo = 11 -- busca que la ruta ya este liquidada hoy
	   BEGIN
		   SELECT id_liquidacion,liquidada 
			   FROM liquidaciones 
		   WHERE id_ruta = @ruta AND fecha_registro = @fecha	
	   end
	   */
   

   -- QUERY PARA CARGAS RECARGAS DESCARGAS
   IF @tipo = 12 
   BEGIN
	
      SELECT 
      CONCAT(cat_proveedores_grupo.orden, ' - ', cat_proveedores_grupo.nombre, ' - ', cat_lineas.orden, ' - ', cat_lineas.nombre) AS proveedor_linea,
	   #TABLA_PRODUCTOS_CARGAS.id_producto, 
	   cat_productos.nombre AS producto, 
	   cat_familias.orden AS familia_orden, 
	   cat_subfamilias.orden AS subfamilia_orden, 
	   #PRECIO.precio_unitario AS Precio, 
	   INV_ALMACEN AS Inventario_Almacen, 
	   INV_VEHICULO AS Inventario_Vehiculo,
	   0 AS cantidad,
	   IIF(Dias_caducidad = 0,50, Dias_caducidad) AS dias_caducar
      INTO #CARGA
	   FROM #TABLA_PRODUCTOS_CARGAS
	   INNER JOIN cat_productos ON #TABLA_PRODUCTOS_CARGAS.id_producto = cat_productos.id_producto 
	   INNER JOIN cat_lineas ON cat_productos.id_linea = cat_lineas.id_linea 
	   INNER JOIN cat_proveedores_grupo ON cat_productos.id_grupo_proveedor = cat_proveedores_grupo.id_grupo_proveedor 
	   INNER JOIN cat_familias ON cat_productos.id_familia = cat_familias.id_familia 
	   INNER JOIN cat_subfamilias ON cat_productos.id_subfamilia = cat_subfamilias.id_subfamilia 
	   INNER JOIN #PRECIO ON #PRECIO.id_producto=#TABLA_PRODUCTOS_CARGAS.id_producto
	   ORDER BY proveedor_linea, producto, familia_orden, subfamilia_orden 
      
      DECLARE @id_ruta_tipo INT = (SELECT id_ruta_tipo FROM cat_rutas WHERE id_ruta = @ruta AND activo = 1)

      IF @id_ruta_tipo <> 3
         SELECT * FROM #CARGA
      ELSE
         SELECT carga.* FROM #CARGA carga
         INNER JOIN cat_productos producto ON producto.id_producto = carga.id_producto
         WHERE producto.preventa = 1
      
   END 

   -- QUERY PARA CARGA INTELIGENTE
   IF @tipo = 13
   BEGIN
   
      SELECT 
      LQD.id_producto,
      SUM(LQD.venta_neta) AS venta_neta, 
      AVG(CONVERT(DECIMAL, LQD.venta_neta)) AS promedio
	   INTO #CARGA_PROMEDIO
	   FROM (SELECT * FROM liquidaciones WHERE id_ruta = @ruta AND fecha_registro IN (DATEadd(DAY, -7, CONVERT(DATE, @fecha_calculo)),DATEadd(DAY, -14, CONVERT(DATE, @fecha_calculo)), DATEADD(DAY, -21, CONVERT(DATE, @fecha_calculo)), DATEADD(DAY, -28, CONVERT(DATE, @fecha_calculo)))) liquidacion 
	   INNER JOIN liquidaciones_detalle LQD ON liquidacion.id_liquidacion = LQD.id_liquidacion 
	   WHERE venta_neta > 0 
	   GROUP BY LQD.id_producto 

	   SELECT 
      CONCAT(cat_proveedores_grupo.orden,' - ', cat_proveedores_grupo.nombre, ' - ', cat_lineas.orden, ' - ', cat_lineas.nombre) AS proveedor_linea,
	   cat_lineas.id_linea AS id_linea,
	   #TABLA_PRODUCTOS_CARGAS.id_producto AS id_producto,
	   cat_productos.nombre AS producto,
	   #PRECIO.precio_unitario AS precio,
	   INV_ALMACEN AS inventario_almacen,
	   INV_VEHICULO AS inv_vehiculo,
	   IIF(IIF(INV_ALMACEN <= CONVERT(INT, ROUND(( #CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0)),
										   INV_ALMACEN, CONVERT(INT, ROUND((#CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0)))<0,0,IIF(INV_ALMACEN <= CONVERT(INT, ROUND(( #CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0)),
										   INV_ALMACEN, CONVERT(INT, ROUND((#CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0)))) AS carga_inteligente,
	   0 AS quitar, 
      0 AS agregar,
	   IIF(IIF(INV_ALMACEN <= CONVERT(INT, ROUND(( #CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0)),
						   INV_ALMACEN, CONVERT(INT, ROUND((#CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0)))<0,0,IIF(INV_ALMACEN <= CONVERT(INT, ROUND(( #CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0)),
						   INV_ALMACEN, CONVERT(INT, ROUND((#CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0)))) AS carga,

	   (INV_VEHICULO+IIF(IIF(INV_ALMACEN <= CONVERT(INT, ROUND(( #CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0)),
						   INV_ALMACEN, CONVERT(INT, ROUND((#CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0)))<0,0,IIF(INV_ALMACEN <= CONVERT(INT, ROUND(( #CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0)),
						   INV_ALMACEN, CONVERT(INT, ROUND((#CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0))))) AS inv_final_vehiculo,

	   CONVERT(INT,ROUND(#CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)),0)) AS carga_optima,
	   CONVERT(INT,ROUND((#CARGA_PROMEDIO.PROMEDIO * (1 + (200/100))),0)-(IIF(IIF(INV_ALMACEN <= CONVERT(INT, ROUND(( #CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0)),
						   INV_ALMACEN, CONVERT(INT, ROUND((#CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0)))<0,0,IIF(INV_ALMACEN <= CONVERT(INT, ROUND(( #CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0)),
						   INV_ALMACEN, CONVERT(INT, ROUND((#CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0))))+INV_VEHICULO))as variacion,
	   0 AS totalquitar, 
      0 AS totalagregar,
	   (#PRECIO.precio_unitario * IIF(INV_ALMACEN <= CONVERT(INT, ROUND(( #CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0)),
						   INV_ALMACEN, CONVERT(INT, ROUND((#CARGA_PROMEDIO.PROMEDIO * (1 + (200/100)) - INV_VEHICULO),0)))) AS carga_inteligente_dinero,
	   IIF(Dias_caducidad = 0, 50, Dias_caducidad) AS dias_caducar
	   INTO #CARGA_INTELIGENTE 
	   FROM #TABLA_PRODUCTOS_CARGAS
	   INNER JOIN cat_productos ON #TABLA_PRODUCTOS_CARGAS.id_producto = cat_productos.id_producto 
	   INNER JOIN cat_lineas ON cat_productos.id_linea = cat_lineas.id_linea 
	   INNER JOIN cat_proveedores_grupo ON cat_productos.id_grupo_proveedor = cat_proveedores_grupo.id_grupo_proveedor 
	   INNER JOIN cat_familias ON cat_productos.id_familia = cat_familias.id_familia 
	   INNER JOIN cat_subfamilias ON cat_productos.id_subfamilia = cat_subfamilias.id_subfamilia 
	   INNER JOIN #PRECIO ON #PRECIO.id_producto = #TABLA_PRODUCTOS_CARGAS.id_producto
	   LEFT JOIN #CARGA_PROMEDIO ON #CARGA_PROMEDIO.id_producto = #TABLA_PRODUCTOS_CARGAS.id_producto
	

	   SELECT 
      proveedor_linea,
	   id_linea,
	   id_producto,
	   producto,
	   precio,
	   inventario_almacen,
	   INV_VEHICULO AS inv_vehiculo,
	   COALESCE(carga_inteligente,0) AS carga_inteligente,
	   quitar, 
      agregar,
	   COALESCE(carga,0) AS carga,
	   COALESCE(inv_final_vehiculo,0) AS inv_final_vehiculo,
	   COALESCE(carga_optima,0) AS carga_optima,
	   COALESCE(variacion,0) AS variacion,
	   totalquitar, 
      totalagregar,
	   COALESCE(carga_inteligente_dinero, 0) AS carga_inteligente_dinero,
	   dias_caducar
	   FROM #CARGA_INTELIGENTE

   END 

   -- QUERY PARA CARGAR PREVENTAS EN RUTA UNILEVER
   IF @tipo = 14
   BEGIN

	   SELECT  
	   vd.id_producto AS id_producto,
      SUM(vd.cantidad) AS venta_anticipada
	   INTO #PREVENTAS  
	   FROM preventas v  
	   INNER JOIN preventas_detalle vd ON vd.id_preventa = v.id_preventa  
	   WHERE v.activo = 1 AND v.id_ruta IN (SELECT id_ruta FROM cat_rutas WHERE id_ruta_reparto = @ruta) AND vd.cantidad  > 0 AND (  
	   v.fecha_preventa > COALESCE((SELECT MAX(fecha_registro) FROM cargas WHERE id_ruta IN (SELECT id_ruta FROM cat_rutas WHERE id_ruta_reparto = @ruta) AND fecha_registro < @fecha), '1990-01-01')  
	   AND v.fecha_preventa = @fecha) 
	   GROUP BY vd.id_producto 

	   SELECT 
      CONCAT(cat_proveedores_grupo.orden, ' - ', cat_proveedores_grupo.nombre, ' - ', cat_lineas.orden, ' - ', cat_lineas.nombre) AS proveedor_linea,
	   cat_lineas.id_linea AS id_linea,
	   #TABLA_PRODUCTOS_CARGAS.id_producto AS id_producto,
	   cat_productos.nombre AS producto,
	   #PRECIO.precio_unitario AS precio,    
	   INV_ALMACEN AS Inventario_Maximo,
	   INV_VEHICULO AS Inv_Vehiculo,				
	   0 AS 'carga_inteligente', 	
	   0 AS 'quitar',
	   0 AS 'agregar',
	   COALESCE(#PREVENTAS.venta_anticipada,0) AS 'carga',
	   INV_VEHICULO AS inv_final_vehiculo,
	   0 AS 'carga_optima',
	   0 AS 'variacion',
	   0 AS 'totalquitar',
	   0 AS 'totalagregar',
	   COALESCE(#PRECIO.precio_unitario, 0) * COALESCE(#PREVENTAS.venta_anticipada, 0) AS carga_inteligente_dinero,
	   IIF(Dias_caducidad = 0, 50, Dias_caducidad) AS dias_caducar,
	   INV_ALMACEN, 
	   #PRECIO.precio_unitario
	   FROM #TABLA_PRODUCTOS_CARGAS
	   INNER JOIN cat_productos ON #TABLA_PRODUCTOS_CARGAS.id_producto = cat_productos.id_producto 
	   INNER JOIN cat_lineas ON cat_productos.id_linea = cat_lineas.id_linea 
	   INNER JOIN cat_proveedores_grupo ON cat_productos.id_grupo_proveedor = cat_proveedores_grupo.id_grupo_proveedor 
	   INNER JOIN cat_familias ON cat_productos.id_familia = cat_familias.id_familia 
	   INNER JOIN cat_subfamilias ON cat_productos.id_subfamilia = cat_subfamilias.id_subfamilia 
	   INNER JOIN #PRECIO ON #PRECIO.id_producto = #TABLA_PRODUCTOS_CARGAS.id_producto
	   LEFT JOIN #PREVENTAS ON #PREVENTAS.id_producto = #TABLA_PRODUCTOS_CARGAS.id_producto
	
   END

   /*IF @tipo = 15 -- query para existencia 
   BEGIN
	
   SELECT  INV_ALMACEN AS existencia FROM #TABLA_PRODUCTOS_CARGAS WHERE id_producto=@id_producto

   END */


   IF @tipo=16
   BEGIN
      
      SELECT 
      TODO.folio, 
      TODO.fecha, 
      TODO.movimiento, 
      CP.id_grupo_proveedor, 
      PG.orden, 
      PG.nombre AS grupo_proveedor,
      CP.id_linea, 
      CL.orden AS orden_linea, 
      CL.nombre AS linea,
      CP.id_familia, 
      CF.orden AS orden_familia, 
      CF.nombre AS familia,
      CP.id_subfamilia, 
      CS.orden AS orden_subfamilia, 
      CS.nombre AS subfamilia,
      TODO.id_producto, 
      CP.nombre AS producto, 
      TODO.cantidad
      FROM (
            SELECT 
		      CAR.id_carga AS folio, 
		      CAR.fecha,
		      movimiento = CASE CAR.movimiento
			               WHEN 'CARGA' THEN '2-Carga'
				            WHEN 'RECARGA' THEN '3-Recarga'
				            WHEN 'DESCARGA' THEN '4-Descarga'
            END,
	         CD.id_producto, 
		      IIF(CAR.movimiento = 'CARGA' OR CAR.movimiento = 'RECARGA', CD.cantidad * -1,  CD.cantidad) AS cantidad
            FROM (
                  SELECT CA.id_carga, CA.id_ruta, CA.movimiento, CA.fecha
                  FROM cargas CA WHERE fecha_registro >= @fecha AND ca.fecha_registro <> ca.fecha
		      ) CAR
			   INNER JOIN cargas_detalle CD ON CD.id_carga = CAR.id_carga 
            
            UNION
            SELECT 
            0 AS folio, 
            @fecha AS fecha,
            '1-Inv Inicial' AS movimiento, 
            id_producto AS id_producto, 
            cantidad 
            FROM inventarios_fisicos 
            WHERE fecha = @fecha
      ) TODO
      INNER JOIN cat_productos CP ON CP.id_producto = TODO.id_producto
      INNER JOIN cat_proveedores_grupo PG ON PG.id_grupo_proveedor = CP.id_grupo_proveedor
      INNER JOIN cat_lineas CL ON CL.id_linea = CP.id_linea
      INNER JOIN cat_familias CF ON CF.id_familia = CP.id_familia
      INNER JOIN cat_subfamilias CS ON CS.id_subfamilia = CP.id_subfamilia
      ORDER BY PG.orden, CL.orden, CF.orden, CS.orden, CP.nombre

   END 

END
