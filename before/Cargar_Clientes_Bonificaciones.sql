USE [dsd_tepic]
GO
/****** Object:  StoredProcedure [dbo].[Cargar_Clientes_Bonificaciones]    Script Date: 12/11/2018 04:11:42 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[Cargar_Clientes_Bonificaciones]
	@id_ruta int,
	@fecha varchar(50)
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

	Declare @base_datos varchar(50) = (SELECT DB_NAME() AS [ Base de datos actual])

    -- Insert statements for procedure here
	Declare @id_lista_precio INT = (select id_lista_precio from cat_cedis where basedatos = @base_datos)
	 
    create table #tmp (id_producto int, nombre varchar(200),precio_unitario float,id_linea int,tasa_iva float,tasa_ieps float, 
                rmi_autorizado int, precio_neto float,inventario int,id_proveedor int, proveedor varchar(200),orden_proveedor int) 
                insert #tmp 
                Exec Cat_Productos_Inventario @id_ruta,@fecha,@id_lista_precio  
                SELECT id_cliente,id_producto,porcentaje,afecta_precio,activo FROM cat_clientes_productos_bonificaciones  
                WHERE id_cliente in(SELECT cat_clientes.id_cliente FROM cat_clientes 
                INNER JOIN cat_clientes_datos_venta on cat_clientes.id_cliente = cat_clientes_datos_venta.id_cliente 
                WHERE cat_clientes_datos_venta.id_ruta = @id_ruta  AND cat_clientes_productos_bonificaciones.activo = 1) AND id_producto in (select id_producto from #tmp) 
                DROP TABLE #tmp 
END