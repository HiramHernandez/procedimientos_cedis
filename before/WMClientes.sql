USE [dsd_tepic]
GO
/****** Object:  StoredProcedure [dbo].[WMClientes]    Script Date: 12/11/2018 03:46:23 p. m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER PROCEDURE [dbo].[WMClientes] 
	-- Add the parameters for the stored procedure here
										 @id_cliente int,@id_sio int, @clave_contable varchar(9), @matriz bit, @id_cliente_matriz int, @persona_fisica bit,@rfc varchar(15), @nombre varchar(50),
										 @apellido_paterno varchar(50), @apellido_materno varchar(50), @razon_social varchar(100), @establecimiento varchar(100), 
										 @calle varchar(50), @numero varchar(10), @colonia varchar(50), @codigo_postal varchar(20), @localidad varchar(50), 
										 @ciudad varchar(50), @estado varchar(50), @telefono varchar(10), @correo varchar(50), @fecha_registro date, 
										 @usuario_registro int, @activo bit,@metodo_de_pago varchar(50),@banco varchar(50),@cuenta_bancaria varchar(50),
										 /*_____________________________________________________________________________________________________________________________________________*/
										 @id_cedis as int, @id_ruta int, @id_tipo_cliente int, @id_giro int, @limite_credito float, @id_lista_precios int, @plazo int ,
										 @tipo_visita  int,@dia_visita  int,@orden  int,@latitud varchar(50),  @longitud varchar(50), @servicio varchar(10), @concepto_baja varchar(10),
										 @id_clasificacion int, @dia_reprogramado int, @orden_reprogramado int
AS
BEGIN
	Declare @existencia int = 1
	IF(@id_cliente <> @id_sio) 
		begin
			set @existencia = (SELECT count (id_cliente) FROM cat_clientes WHERE clave_contable=@clave_contable and matriz= @matriz and id_cliente_matriz = @id_cliente_matriz and persona_fisica = @persona_fisica
			and nombre= @nombre and apellido_paterno = @apellido_paterno and apellido_materno = @apellido_materno and establecimiento = @establecimiento and calle = @calle and numero= @numero and colonia= @colonia
			and codigo_postal= @codigo_postal and localidad= @localidad and ciudad= @ciudad and estado = @estado and telefono = @telefono and correo = @correo and fecha_registro = @fecha_registro
			and usuario_registro = @usuario_registro and activo = @activo and metodo_de_pago = @metodo_de_pago and banco = @banco and cuenta_bancaria = @cuenta_bancaria  and id_clasificacion = @id_clasificacion)

			IF( @existencia = 0) BEGIN
				INSERT INTO CAT_CLIENTES (clave_contable,matriz,id_cliente_matriz,persona_fisica,nombre,apellido_paterno,apellido_materno,establecimiento,calle,numero,colonia,codigo_postal,localidad,ciudad,estado,telefono,correo,fecha_registro,usuario_registro,activo,metodo_de_pago,banco,cuenta_bancaria,id_cedis_matriz,id_clasificacion) 
				VALUES (@clave_contable,@matriz,@id_cliente_matriz,@persona_fisica,@nombre,@apellido_paterno,@apellido_materno,@establecimiento,@calle,@numero,@colonia,@codigo_postal,@localidad,@ciudad,@estado,@telefono,@correo,@fecha_registro,@usuario_registro,@activo,@metodo_de_pago,@banco,@cuenta_bancaria,0,@id_clasificacion)
				SET @id_cliente = (SELECT IDENT_CURRENT('cat_clientes') AS id)
			END
		end
	ELSE
		begin
			UPDATE CAT_CLIENTES SET nombre=@nombre,apellido_paterno=@apellido_paterno,apellido_materno=@apellido_materno,establecimiento=@establecimiento,calle=@calle,numero=@numero,colonia=@colonia,
			codigo_postal=@codigo_postal,localidad=@localidad,ciudad=@ciudad,estado=@estado,telefono=@telefono,correo=@correo,activo=@activo ,fecha_modifico = getdate(),usuario_modifico = @usuario_registro, id_clasificacion = @id_clasificacion where id_cliente=@id_cliente 
		end


	declare @RS as int
	set @RS = (Select count(*) from cat_clientes_datos_venta where id_cliente=@id_cliente)
	


	IF(@RS=0)
		begin
			IF @existencia = 0 BEGIN
				insert into cat_clientes_datos_venta 
				(id_cliente,id_ruta_cedis,id_ruta,id_cliente_tipo,id_giro,limite_credito,id_lista_precios,plazo,tipo_visita,concepto_baja,latitud,longitud,servicio,id_cedis,dia,orden,dia_reprogramado,orden_reprogramado)
				values (@id_cliente,0,@id_ruta,@id_tipo_cliente,@id_giro,@limite_credito,@id_lista_precios,@plazo,@tipo_visita,@concepto_baja,@latitud,@longitud,@servicio,@id_cedis,@dia_visita,@orden,0,0)	
			END
		end
	ELSE
		begin
			UPDATE cat_clientes_datos_venta SET id_cedis=@id_cedis,id_cliente_tipo=@id_tipo_cliente,id_giro=@id_giro,id_lista_precios=@id_lista_precios,
			tipo_visita=@tipo_visita,concepto_baja=@concepto_baja,latitud=@latitud,longitud=@longitud,servicio=@servicio,dia=@dia_visita,orden=@orden,dia_reprogramado=@dia_reprogramado,orden_reprogramado=@orden_reprogramado WHERE ID_CLIENTE=@ID_CLIENTE AND id_ruta = @id_ruta
		end

END