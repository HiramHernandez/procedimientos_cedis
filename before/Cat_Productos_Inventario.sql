USE [dsd_tepic]
GO
/****** Object:  StoredProcedure [dbo].[Cat_Productos_Inventario]    Script Date: 12/11/2018 03:44:42 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Cat_Productos_Inventario]
       -- Add the parameters for the stored procedure here
       @id_ruta AS int,
       @fecha AS Varchar(10),
       @id_lista_precio AS int
      
AS
BEGIN
       -- SET NOCOUNT ON added to prevent extra result sets from
       -- interfering with SELECT statements.
       SET NOCOUNT ON;
       Declare @tipo_ruta Int;
       Set @tipo_ruta = (Select id_ruta_tipo From cat_rutas Where id_ruta = @id_ruta)
       Declare @contador_cargas Int =0;
       If @tipo_ruta = 2 And @contador_cargas = 0
       BEGIN
             --RUTAS DE PREVENTA
             Set @contador_cargas = (Select ISNULL(COUNT(id_carga),0) From cargas Where id_ruta = @id_ruta);
             SELECT
        cat_lista_precios_detalle.id_producto as id_producto,
        cat_productos.nombre as nombre,
        MAX(cat_lista_precios_detalle.precio_unitario) AS precio_unitario,
        cat_tasa_iva.importe*iva as tasa_iva,
        cat_tasa_ieps.importe*iva as tasa_ieps,
        COALESCE(MAX(cat_lista_precios_detalle.importe_iva),
        MAX(cat_lista_precios_detalle.precio_unitario)) AS importe_iva,
        COALESCE(MAX(cat_lista_precios_detalle.importe_ieps),
        MAX(cat_lista_precios_detalle.precio_unitario)) AS importe_ieps,
        cat_productos.rmi as rmi_autorizado,
        cat_lista_precios_detalle.precio_unitario + (cat_tasa_iva.importe * cat_lista_precios_detalle.precio_unitario * cat_productos.iva) + (cat_tasa_ieps.importe * cat_lista_precios_detalle.precio_unitario * cat_productos.ieps) as precio_neto,
        cat_productos.existencia as inventario,
        cat_productos.id_linea,
        cat_proveedores_grupo.id_grupo_proveedor as id_proveedor,
        cat_proveedores_grupo.nombre as proveedor,
        cat_proveedores_grupo.orden as orden_proveedor
        INTO #Pss
        FROM cat_lista_precios_detalle
        inner join cat_productos on cat_lista_precios_detalle.id_producto=cat_productos.id_producto
        inner join cat_lineas ON cat_productos.id_linea = cat_productos.id_linea
        inner join cat_proveedores_grupo ON cat_productos.id_grupo_proveedor = cat_proveedores_grupo.id_grupo_proveedor
        inner join cat_tasa_iva ON 4 = cat_tasa_iva.id_tasa_iva
        inner join cat_tasa_ieps ON 1 = cat_tasa_ieps.id_tasa_ieps
        WHERE id_lista_precio =   2   AND @fecha BETWEEN cat_lista_precios_detalle.fecha_inicio AND cat_lista_precios_detalle.fecha_fin /*AND cat_lista_precios_detalle.fecha_inicio >= '2016-01-01'*/
        GROUP BY
        cat_lista_precios_detalle.id_producto,
             cat_lista_precios_detalle.precio_unitario,
             cat_tasa_iva.importe,
             cat_productos.iva,
             cat_tasa_ieps.importe,
             cat_productos.ieps,
        cat_productos.nombre,
        cat_productos.id_linea,
        cat_productos.rmi,
             cat_productos.existencia ,
        cat_proveedores_grupo.id_grupo_proveedor,
        cat_proveedores_grupo.nombre,
        cat_proveedores_grupo.orden,
        cat_tasa_iva.importe * iva,
        cat_tasa_ieps.importe * iva
        select id_producto,nombre,precio_unitario,id_linea,tasa_iva,tasa_ieps,rmi_autorizado, precio_neto,inventario,id_proveedor,proveedor,orden_proveedor from #Pss
       END
       else
       BEgin
    -- Insert statements for procedure here
       --AUTOVENTA, REPARTO, ADMINISTRATIVA, ESPECIAL
                           SELECT
                                  cat_productos.id_producto,
                                  cat_productos.nombre,
                                  precio_unitario,
                                  id_linea,
                                  cat_tasa_iva.importe * iva AS tasa_iva,
                                  cat_tasa_ieps.importe * ieps AS tasa_ieps,
                                  rmi AS rmi_autorizado,
                                  precio_unitario + (cat_tasa_iva.importe * precio_unitario * cat_productos.iva) + (cat_tasa_ieps.importe * precio_unitario * cat_productos.ieps) as precio_neto,
                                  0 AS inventario,
                                  cat_proveedores_grupo.id_grupo_proveedor as id_proveedor,
                                  cat_proveedores_grupo.nombre as proveedor, 
                                  cat_proveedores_grupo.orden as orden_proveedor
                           INTO #CATALOGO_COMPLETO
                           FROM cat_productos
                           INNER JOIN cat_proveedores_grupo ON cat_productos.id_grupo_proveedor = cat_proveedores_grupo.id_grupo_proveedor
                           INNER JOIN cat_lista_precios_detalle ON cat_productos.id_producto = cat_lista_precios_detalle.id_producto AND cat_lista_precios_detalle.id_lista_precio = @id_lista_precio AND @fecha between cat_lista_precios_detalle.fecha_inicio and cat_lista_precios_detalle.fecha_fin 
                           INNER JOIN cat_tasa_iva ON 4 = cat_tasa_iva.id_tasa_iva
                           INNER JOIN cat_tasa_ieps ON 1 = cat_tasa_ieps.id_tasa_ieps
                           WHERE cat_productos.activo = 1
 
 
                SELECT  
                       Inve.id_producto,
                       Inve.Producto as nombre,
                       Inve.precio_unitario,
                       Inve.id_linea,
                       Inve.iva_importe * Inve.iva_producto as tasa_iva,
                       Inve.ieps_importe * Inve.ieps_producto as tasa_ieps,
                       Inve.rmi as rmi_autorizado,
                       Inve.precio_unitario +(Inve.iva_importe * Inve.precio_unitario * Inve.iva_producto) + (Inve.ieps_importe * Inve.precio_unitario*Inve.ieps_producto) as precio_neto, 
                       COALESCE(Inve.inventario,0) AS inventario,
                       id_proveedor, 
                       grupo_proveedor as proveedor, 
                       orden_grupo_proveedor as orden_proveedor
                           --INTO #CATALOGO_INVE         
                FROM ( 
                        SELECT 
                            cat_productos.id_producto,
                            cat_productos.nombre as Producto,
                            sum(Inventario.cantidad) as inventario,
                            cat_proveedores_grupo.id_grupo_proveedor as id_proveedor,
                            cat_proveedores_grupo.nombre as grupo_proveedor,
                            cat_proveedores_grupo.orden as orden_grupo_proveedor,
                            cat_lineas.id_linea,
                            cat_lineas.orden as 'orden_linea',
                            cat_lineas.nombre as 'Linea',
                            cat_familias.id_familia,
                            cat_familias.orden as 'orden_familia',
                            cat_familias.nombre as 'Familia',
                            cat_subfamilias.id_subfamilia,
                            cat_subfamilias.orden as 'orden_subfamilia',
                            cat_subfamilias.nombre as 'subFamilia',
                            /*inventario.movimiento,*/
                            cat_rutas.id_ruta,
                            cat_rutas.ruta,
                            cat_rutas.nombre as 'nombre_ruta',
                            cat_empleados.nombre as 'nombre_empleado',
                            cat_empleados.apellido_paterno,
                            cat_empleados.apellido_materno,
                            cat_tasa_iva.importe AS iva_importe,
                            cat_tasa_ieps.importe AS ieps_importe,
                            cat_productos.iva AS iva_producto,
                            cat_productos.ieps AS ieps_producto,
                            cat_productos.rmi,
                            cast(cat_lista_precios_detalle.precio_unitario as float) as precio_unitario 
                    FROM 
           (SELECT 
                  id_producto,
                  inventario_final as 'cantidad',
                   'CARGA' as 'movimiento', 
                   liquidaciones.id_ruta 
             FROM liquidaciones 
             INNER JOIN liquidaciones_detalle on liquidaciones.id_liquidacion = liquidaciones_detalle.id_liquidacion 
             WHERE fecha_registro = isnull((select max(fecha) from liquidaciones where fecha < @fecha and id_ruta =   @id_ruta ),'1999-01-01') and id_ruta =  @id_ruta
             UNION ALL 
             SELECT 
                id_producto, 
                iif(cargas.movimiento = 'DESCARGA',cantidad * - 1,cantidad) as cantidad, 
                cargas.movimiento,
                cargas.id_ruta 
                FROM cargas 
                   INNER JOIN cargas_detalle on cargas.id_carga = cargas_detalle.id_carga 
                 WHERE fecha > isnull((SELECT max(fecha) FROM liquidaciones WHERE fecha < @fecha and id_ruta =  @id_ruta ),'1999-01-01') and id_ruta =  @id_ruta  and fecha<= @fecha) AS Inventario 
                 INNER JOIN cat_productos on Inventario.id_producto = cat_productos.id_producto 
                 INNER JOIN cat_lineas on cat_productos.id_linea = cat_lineas.id_linea 
                 INNER JOIN cat_proveedores_grupo on cat_productos.id_grupo_proveedor = cat_proveedores_grupo.id_grupo_proveedor 
                 INNER JOIN cat_familias on cat_productos.id_familia = cat_familias.id_familia 
                 INNER JOIN cat_subfamilias on cat_subfamilias.id_subfamilia = cat_productos.id_subfamilia 
                 INNER JOIN cat_rutas on Inventario.id_ruta = cat_rutas.id_ruta 
                 INNER JOIN (SELECT id_ruta,id_empleado 
                             FROM rutas_asignacion 
                  WHERE fecha_ruta_asignacion = (SELECT MAX(fecha_ruta_asignacion) FROM rutas_asignacion WHERE id_ruta =  @id_ruta )) AS asignasion ON cat_rutas.id_ruta = asignasion.id_ruta 
                  INNER JOIN cat_empleados on asignasion.id_empleado = cat_empleados.id_empleado 
                  INNER JOIN cat_lista_precios_detalle on cat_productos.id_producto = cat_lista_precios_detalle.id_producto 
                  INNER JOIN cat_tasa_iva ON  4 = cat_tasa_iva.id_tasa_iva 
                  INNER JOIN cat_tasa_ieps ON 1 = cat_tasa_ieps.id_tasa_ieps 
                  WHERE cat_lista_precios_detalle.id_lista_precio = @id_lista_precio AND @fecha between cat_lista_precios_detalle.fecha_inicio and cat_lista_precios_detalle.fecha_fin 
               GROUP BY cat_productos.id_producto, 
               cat_productos.nombre, 
               cat_proveedores_grupo.id_grupo_proveedor, 
               cat_proveedores_grupo.nombre, 
               cat_proveedores_grupo.orden, 
               cat_lineas.id_linea, 
               cat_lineas.orden, 
               cat_lineas.nombre,
               cat_familias.id_familia, 
               cat_familias.orden,
               cat_familias.nombre, 
               cat_subfamilias.id_subfamilia,
               cat_subfamilias.orden,
               cat_subfamilias.nombre,
               /*inventario.movimiento,*/
               cat_rutas.id_ruta,
               cat_rutas.ruta,
               cat_rutas.nombre,
               cat_empleados.nombre,
               cat_empleados.apellido_paterno,
               cat_empleados.apellido_materno,
               cat_tasa_iva.importe, 
               cat_tasa_ieps.importe,
               cat_productos.iva,
               cat_productos.ieps,
               cat_productos.rmi,
               cat_lista_precios_detalle.precio_unitario 
               ) Inve 
               order by Inve.orden_grupo_proveedor, Inve.grupo_proveedor , Inve.orden_linea, Inve.Linea, Inve.orden_familia,Inve.orden_subfamilia,Inve.Producto
 
       End
 
 
       /*SELECT
             Inve.id_producto,
             Inve.nombre,
             Inve.precio_unitario,
             Inve.id_linea,
             Inve.tasa_iva,
             Inve.tasa_ieps,
             Inve.rmi_autorizado,
             Inve.precio_neto,
             SUM(Inve.inventario) AS inventario,
             Inve.id_proveedor,
             Inve.proveedor, 
        Inve.orden_proveedor
       FROM
       (
       SELECT * FROM #CATALOGO_COMPLETO
       UNION ALL
       SELECT * FROM #CATALOGO_INVE
       ) AS Inve
       GROUP BY
             Inve.id_producto,
             Inve.nombre,
             Inve.precio_unitario,
             Inve.id_linea,
             Inve.tasa_iva,
             Inve.tasa_ieps,
             Inve.rmi_autorizado,
             Inve.precio_neto,
             Inve.id_proveedor,
             Inve.proveedor, 
        Inve.orden_proveedor */
 
       --order by Inve.orden_grupo_proveedor, Inve.grupo_proveedor , Inve.orden_linea, Inve.Linea, Inve.orden_familia,Inve.orden_subfamilia,Inve.Producto
 
       /*SELECT * FROM #CATALOGO_COMPLETO
       UNION ALL
       SELECT * FROM #CATALOGO_INVE*/
 
END
