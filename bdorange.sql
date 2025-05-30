PGDMP  -    .                }           kraken    17.4    17.4 �   �           0    0    ENCODING    ENCODING        SET client_encoding = 'UTF8';
                           false            �           0    0 
   STDSTRINGS 
   STDSTRINGS     (   SET standard_conforming_strings = 'on';
                           false            �           0    0 
   SEARCHPATH 
   SEARCHPATH     8   SELECT pg_catalog.set_config('search_path', '', false);
                           false            �           1262    16387    kraken    DATABASE     l   CREATE DATABASE kraken WITH TEMPLATE = template0 ENCODING = 'UTF8' LOCALE_PROVIDER = libc LOCALE = 'es-MX';
    DROP DATABASE kraken;
                     postgres    false            �           0    0    DATABASE kraken    COMMENT     0   COMMENT ON DATABASE kraken IS 'punto de venta';
                        postgres    false    5542            Q           1255    16970 !   actualizar_timestamp_inventario()    FUNCTION     �   CREATE FUNCTION public.actualizar_timestamp_inventario() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.actualizado_en := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;
 8   DROP FUNCTION public.actualizar_timestamp_inventario();
       public               postgres    false            S           1255    25521 /   sp_eliminar_relaciones_duplicadas_y_verificar() 	   PROCEDURE     �  CREATE PROCEDURE public.sp_eliminar_relaciones_duplicadas_y_verificar()
    LANGUAGE plpgsql
    AS $$
DECLARE 
    r RECORD;
    contador INTEGER := 0;
BEGIN
    -- 1. Eliminar constraints duplicadas
    FOR r IN
        SELECT
            con.oid,
            con.conname,
            con.conrelid::regclass AS tabla,
            ROW_NUMBER() OVER (
                PARTITION BY con.conrelid, con.confrelid, con.conkey, con.confkey 
                ORDER BY con.conname
            ) AS rn
        FROM pg_constraint con
        WHERE con.contype = 'f'
    LOOP
        IF r.rn > 1 THEN
            RAISE NOTICE 'Eliminando constraint duplicada % en tabla %', r.conname, r.tabla;
            EXECUTE format('ALTER TABLE %s DROP CONSTRAINT %I;', r.tabla, r.conname);
            contador := contador + 1;
        END IF;
    END LOOP;

    RAISE NOTICE 'Total de constraints eliminadas: %', contador;

    -- 2. Mostrar si aún existen duplicadas
    RAISE NOTICE 'Verificando si aún existen relaciones duplicadas...';

    FOR r IN
        SELECT 
            con.conrelid::regclass::TEXT AS tabla,
            con.confrelid::regclass::TEXT AS tabla_referenciada,
            array_agg(att.attname ORDER BY att.attname) AS columnas,
            array_agg(att2.attname ORDER BY att2.attname) AS columnas_referenciadas,
            COUNT(*) AS repeticiones
        FROM pg_constraint con
        JOIN pg_attribute att 
            ON att.attrelid = con.conrelid 
            AND att.attnum = ANY(con.conkey)
        JOIN pg_attribute att2 
            ON att2.attrelid = con.confrelid 
            AND att2.attnum = ANY(con.confkey)
        WHERE con.contype = 'f'
        GROUP BY con.conrelid, con.confrelid, con.conkey, con.confkey
        HAVING COUNT(*) > 1
    LOOP
        RAISE NOTICE 'Aún existe duplicada: % → % columnas: % → % (veces: %)', 
            r.tabla, r.tabla_referenciada, r.columnas, r.columnas_referenciadas, r.repeticiones;
    END LOOP;

END;
$$;
 G   DROP PROCEDURE public.sp_eliminar_relaciones_duplicadas_y_verificar();
       public               postgres    false            R           1255    25520 "   verificar_constraints_duplicadas()    FUNCTION     �  CREATE FUNCTION public.verificar_constraints_duplicadas() RETURNS TABLE(constraint_name text, table_name text, referenced_table text, local_columns text[], referenced_columns text[], duplicate_count integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        con.conname AS constraint_name,
        con.conrelid::regclass::TEXT AS table_name,
        con.confrelid::regclass::TEXT AS referenced_table,
        array_agg(att.attname ORDER BY att.attname) AS local_columns,
        array_agg(att2.attname ORDER BY att2.attname) AS referenced_columns,
        COUNT(*) AS duplicate_count
    FROM pg_constraint con
    JOIN pg_attribute att 
      ON att.attrelid = con.conrelid 
      AND att.attnum = ANY(con.conkey)
    JOIN pg_attribute att2 
      ON att2.attrelid = con.confrelid 
      AND att2.attnum = ANY(con.confkey)
    WHERE con.contype = 'f'
    GROUP BY con.conrelid, con.confrelid, con.conkey, con.confkey, con.conname
    HAVING COUNT(*) > 1;
END;
$$;
 9   DROP FUNCTION public.verificar_constraints_duplicadas();
       public               postgres    false            �            1259    16805    accion    TABLE     q   CREATE TABLE public.accion (
    id integer NOT NULL,
    nombre character varying(100),
    descripcion text
);
    DROP TABLE public.accion;
       public         heap r       postgres    false            �            1259    16804    accion_id_seq    SEQUENCE     �   CREATE SEQUENCE public.accion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE public.accion_id_seq;
       public               postgres    false    244            �           0    0    accion_id_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE public.accion_id_seq OWNED BY public.accion.id;
          public               postgres    false    243            �            1259    16798    area    TABLE     Y   CREATE TABLE public.area (
    id integer NOT NULL,
    nombre character varying(100)
);
    DROP TABLE public.area;
       public         heap r       postgres    false            �            1259    16797    area_id_seq    SEQUENCE     �   CREATE SEQUENCE public.area_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 "   DROP SEQUENCE public.area_id_seq;
       public               postgres    false    242            �           0    0    area_id_seq    SEQUENCE OWNED BY     ;   ALTER SEQUENCE public.area_id_seq OWNED BY public.area.id;
          public               postgres    false    241            �            1259    16408    atributo    TABLE     ]   CREATE TABLE public.atributo (
    id integer NOT NULL,
    nombre character varying(100)
);
    DROP TABLE public.atributo;
       public         heap r       postgres    false            �            1259    16407    atributo_id_seq    SEQUENCE     �   CREATE SEQUENCE public.atributo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE public.atributo_id_seq;
       public               postgres    false    222            �           0    0    atributo_id_seq    SEQUENCE OWNED BY     C   ALTER SEQUENCE public.atributo_id_seq OWNED BY public.atributo.id;
          public               postgres    false    221            �            1259    16389 	   categoria    TABLE     �   CREATE TABLE public.categoria (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    state_id integer,
    descripcion character varying(100),
    estado boolean
);
    DROP TABLE public.categoria;
       public         heap r       postgres    false            �            1259    16388    categoria_id_seq    SEQUENCE     �   CREATE SEQUENCE public.categoria_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.categoria_id_seq;
       public               postgres    false    218            �           0    0    categoria_id_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE public.categoria_id_seq OWNED BY public.categoria.id;
          public               postgres    false    217            ?           1259    25391    celda_id_seq    SEQUENCE     u   CREATE SEQUENCE public.celda_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE public.celda_id_seq;
       public               postgres    false                       1259    17219    celda    TABLE       CREATE TABLE public.celda (
    id integer DEFAULT nextval('public.celda_id_seq'::regclass) NOT NULL,
    contenedor_fisico_id integer,
    fila integer,
    columna integer,
    activa boolean DEFAULT true,
    capacidad_minima numeric(10,2),
    capacidad_maxima numeric(10,2)
);
    DROP TABLE public.celda;
       public         heap r       postgres    false    319                       1259    17218    celda_id_celda_seq    SEQUENCE     �   CREATE SEQUENCE public.celda_id_celda_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 )   DROP SEQUENCE public.celda_id_celda_seq;
       public               postgres    false    274            �           0    0    celda_id_celda_seq    SEQUENCE OWNED BY     C   ALTER SEQUENCE public.celda_id_celda_seq OWNED BY public.celda.id;
          public               postgres    false    273            �            1259    16854    cliente    TABLE     �  CREATE TABLE public.cliente (
    id integer NOT NULL,
    nombre character varying(150),
    telefono character varying(20),
    direccion text,
    state_id integer,
    codigo_cliente character varying(50),
    apellidos character varying(150),
    foto character varying,
    correo character varying(150),
    fecha_nacimiento date,
    comentarios character varying(150),
    estado boolean,
    tipo_cliente_id integer
);
    DROP TABLE public.cliente;
       public         heap r       postgres    false            �            1259    16853    cliente_id_seq    SEQUENCE     �   CREATE SEQUENCE public.cliente_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE public.cliente_id_seq;
       public               postgres    false    248            �           0    0    cliente_id_seq    SEQUENCE OWNED BY     A   ALTER SEQUENCE public.cliente_id_seq OWNED BY public.cliente.id;
          public               postgres    false    247            �            1259    16483 
   componente    TABLE     �   CREATE TABLE public.componente (
    id integer NOT NULL,
    detalle_producto_padre_id integer NOT NULL,
    detalle_producto_hijo_id integer NOT NULL,
    cantidad numeric(10,2)
);
    DROP TABLE public.componente;
       public         heap r       postgres    false            �            1259    16482    componente_id_seq    SEQUENCE     �   CREATE SEQUENCE public.componente_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.componente_id_seq;
       public               postgres    false    228            �           0    0    componente_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.componente_id_seq OWNED BY public.componente.id;
          public               postgres    false    227            >           1259    25389    configuracion_extra_json_id_seq    SEQUENCE     �   CREATE SEQUENCE public.configuracion_extra_json_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 6   DROP SEQUENCE public.configuracion_extra_json_id_seq;
       public               postgres    false            .           1259    17380    configuracion_extra_json    TABLE     J  CREATE TABLE public.configuracion_extra_json (
    id integer DEFAULT nextval('public.configuracion_extra_json_id_seq'::regclass) NOT NULL,
    tipo_entidad integer,
    id_referencia integer,
    json_config jsonb,
    fecha_creacion timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    configuracion_negocio_id integer
);
 ,   DROP TABLE public.configuracion_extra_json;
       public         heap r       postgres    false    318            -           1259    17379 &   configuracion_extra_json_id_config_seq    SEQUENCE     �   CREATE SEQUENCE public.configuracion_extra_json_id_config_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 =   DROP SEQUENCE public.configuracion_extra_json_id_config_seq;
       public               postgres    false    302            �           0    0 &   configuracion_extra_json_id_config_seq    SEQUENCE OWNED BY     j   ALTER SEQUENCE public.configuracion_extra_json_id_config_seq OWNED BY public.configuracion_extra_json.id;
          public               postgres    false    301            =           1259    25387    configuracion_negocio_id_seq    SEQUENCE     �   CREATE SEQUENCE public.configuracion_negocio_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.configuracion_negocio_id_seq;
       public               postgres    false            ,           1259    17369    configuracion_negocio    TABLE     �  CREATE TABLE public.configuracion_negocio (
    id integer DEFAULT nextval('public.configuracion_negocio_id_seq'::regclass) NOT NULL,
    negocio_id integer,
    moneda character varying(10),
    idioma character varying(5),
    permite_venta boolean DEFAULT true,
    permite_descuento boolean DEFAULT false,
    mostrar_codigo boolean DEFAULT true,
    formato_ticket character varying(50),
    redondear_precio boolean DEFAULT false
);
 )   DROP TABLE public.configuracion_negocio;
       public         heap r       postgres    false    317            +           1259    17368 *   configuracion_negocio_id_configuracion_seq    SEQUENCE     �   CREATE SEQUENCE public.configuracion_negocio_id_configuracion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 A   DROP SEQUENCE public.configuracion_negocio_id_configuracion_seq;
       public               postgres    false    300            �           0    0 *   configuracion_negocio_id_configuracion_seq    SEQUENCE OWNED BY     k   ALTER SEQUENCE public.configuracion_negocio_id_configuracion_seq OWNED BY public.configuracion_negocio.id;
          public               postgres    false    299                       1259    17246    contenedor_figura    TABLE     �   CREATE TABLE public.contenedor_figura (
    punto_orden integer,
    pos_x integer,
    pos_y integer,
    largo character(10),
    alto character(10),
    ancho character(10),
    color_hex character varying,
    id integer NOT NULL
);
 %   DROP TABLE public.contenedor_figura;
       public         heap r       postgres    false            :           1259    25367    contenedor_figura_id_seq    SEQUENCE     �   CREATE SEQUENCE public.contenedor_figura_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.contenedor_figura_id_seq;
       public               postgres    false    279            �           0    0    contenedor_figura_id_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.contenedor_figura_id_seq OWNED BY public.contenedor_figura.id;
          public               postgres    false    314            K           1259    25416    contenedor_fisico_id_seq    SEQUENCE     �   CREATE SEQUENCE public.contenedor_fisico_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.contenedor_fisico_id_seq;
       public               postgres    false                       1259    17210    contenedor_fisico    TABLE     A  CREATE TABLE public.contenedor_fisico (
    id integer DEFAULT nextval('public.contenedor_fisico_id_seq'::regclass) NOT NULL,
    contenedor_instancia_id integer,
    nombre character varying(100),
    descripcion text,
    ubicacion_fisica_id integer,
    contenedor_figura_id integer,
    tipo_contenedor_id integer
);
 %   DROP TABLE public.contenedor_fisico;
       public         heap r       postgres    false    331                       1259    17209 *   contenedor_fisico_id_contenedor_fisico_seq    SEQUENCE     �   CREATE SEQUENCE public.contenedor_fisico_id_contenedor_fisico_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 A   DROP SEQUENCE public.contenedor_fisico_id_contenedor_fisico_seq;
       public               postgres    false    272            �           0    0 *   contenedor_fisico_id_contenedor_fisico_seq    SEQUENCE OWNED BY     g   ALTER SEQUENCE public.contenedor_fisico_id_contenedor_fisico_seq OWNED BY public.contenedor_fisico.id;
          public               postgres    false    271            5           1259    24590    contenedor_instancia    TABLE     �   CREATE TABLE public.contenedor_instancia (
    empresa_id integer,
    nombre_personalizado character varying,
    visible boolean,
    rotacion integer,
    escala numeric(4,2),
    z_indez integer,
    id integer NOT NULL
);
 (   DROP TABLE public.contenedor_instancia;
       public         heap r       postgres    false            9           1259    25358    contenedor_instancia_id_seq    SEQUENCE     �   CREATE SEQUENCE public.contenedor_instancia_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.contenedor_instancia_id_seq;
       public               postgres    false    309            �           0    0    contenedor_instancia_id_seq    SEQUENCE OWNED BY     [   ALTER SEQUENCE public.contenedor_instancia_id_seq OWNED BY public.contenedor_instancia.id;
          public               postgres    false    313            	           1259    16954 
   corte_caja    TABLE     �   CREATE TABLE public.corte_caja (
    id_usuario integer,
    fecha_inicio timestamp without time zone,
    fecha_fin timestamp without time zone,
    monto_inicio numeric(10,2),
    monto_final numeric(10,2),
    id integer NOT NULL
);
    DROP TABLE public.corte_caja;
       public         heap r       postgres    false            ;           1259    25376    corte_caja_id_seq    SEQUENCE     �   CREATE SEQUENCE public.corte_caja_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.corte_caja_id_seq;
       public               postgres    false    265            �           0    0    corte_caja_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.corte_caja_id_seq OWNED BY public.corte_caja.id;
          public               postgres    false    315            �            1259    16415    detalle_atributo    TABLE     �   CREATE TABLE public.detalle_atributo (
    id integer NOT NULL,
    id_atributo integer NOT NULL,
    valor character varying(100)
);
 $   DROP TABLE public.detalle_atributo;
       public         heap r       postgres    false            �            1259    16414    detalle_atributo_id_seq    SEQUENCE     �   CREATE SEQUENCE public.detalle_atributo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.detalle_atributo_id_seq;
       public               postgres    false    224            �           0    0    detalle_atributo_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.detalle_atributo_id_seq OWNED BY public.detalle_atributo.id;
          public               postgres    false    223                       1259    16927    detalle_ingreso    TABLE     �   CREATE TABLE public.detalle_ingreso (
    id integer NOT NULL,
    ingreso_id integer,
    detalle_producto_id integer,
    cantidad numeric(10,2),
    precio_costo numeric(10,2),
    subtotal numeric(10,2),
    state_id integer
);
 #   DROP TABLE public.detalle_ingreso;
       public         heap r       postgres    false                       1259    16926    detalle_ingreso_id_seq    SEQUENCE     �   CREATE SEQUENCE public.detalle_ingreso_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.detalle_ingreso_id_seq;
       public               postgres    false    262            �           0    0    detalle_ingreso_id_seq    SEQUENCE OWNED BY     Q   ALTER SEQUENCE public.detalle_ingreso_id_seq OWNED BY public.detalle_ingreso.id;
          public               postgres    false    261            �            1259    16434    detalle_producto    TABLE     M  CREATE TABLE public.detalle_producto (
    id integer NOT NULL,
    medida numeric(10,2),
    unidad_medida character varying(20),
    marca_id character varying(100),
    descripcion text,
    nombre_calculado text,
    activo boolean DEFAULT true,
    producto_id integer NOT NULL,
    atributo_id integer,
    state_id integer
);
 $   DROP TABLE public.detalle_producto;
       public         heap r       postgres    false            2           1259    17506     detalle_producto_atributo_id_seq    SEQUENCE     �   CREATE SEQUENCE public.detalle_producto_atributo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public.detalle_producto_atributo_id_seq;
       public               postgres    false    226            �           0    0     detalle_producto_atributo_id_seq    SEQUENCE OWNED BY     e   ALTER SEQUENCE public.detalle_producto_atributo_id_seq OWNED BY public.detalle_producto.atributo_id;
          public               postgres    false    306            J           1259    25414    detalle_producto_celda_id_seq    SEQUENCE     �   CREATE SEQUENCE public.detalle_producto_celda_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.detalle_producto_celda_id_seq;
       public               postgres    false                       1259    17259    detalle_producto_celda    TABLE       CREATE TABLE public.detalle_producto_celda (
    id integer DEFAULT nextval('public.detalle_producto_celda_id_seq'::regclass) NOT NULL,
    contenedor_fisico_id integer,
    celda_id integer,
    detalle_producto_id integer,
    inventario_id integer,
    cantidad integer
);
 *   DROP TABLE public.detalle_producto_celda;
       public         heap r       postgres    false    330                       1259    17258 1   detalle_producto_contenedor_id_producto_celda_seq    SEQUENCE     �   CREATE SEQUENCE public.detalle_producto_contenedor_id_producto_celda_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 H   DROP SEQUENCE public.detalle_producto_contenedor_id_producto_celda_seq;
       public               postgres    false    281            �           0    0 1   detalle_producto_contenedor_id_producto_celda_seq    SEQUENCE OWNED BY     s   ALTER SEQUENCE public.detalle_producto_contenedor_id_producto_celda_seq OWNED BY public.detalle_producto_celda.id;
          public               postgres    false    280            �            1259    16433    detalle_producto_id_seq    SEQUENCE     �   CREATE SEQUENCE public.detalle_producto_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.detalle_producto_id_seq;
       public               postgres    false    226            �           0    0    detalle_producto_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.detalle_producto_id_seq OWNED BY public.detalle_producto.id;
          public               postgres    false    225            1           1259    17496     detalle_producto_producto_id_seq    SEQUENCE     �   CREATE SEQUENCE public.detalle_producto_producto_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public.detalle_producto_producto_id_seq;
       public               postgres    false    226            �           0    0     detalle_producto_producto_id_seq    SEQUENCE OWNED BY     e   ALTER SEQUENCE public.detalle_producto_producto_id_seq OWNED BY public.detalle_producto.producto_id;
          public               postgres    false    305            3           1259    17514    detalle_producto_state_id_seq    SEQUENCE     �   CREATE SEQUENCE public.detalle_producto_state_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 4   DROP SEQUENCE public.detalle_producto_state_id_seq;
       public               postgres    false    226            �           0    0    detalle_producto_state_id_seq    SEQUENCE OWNED BY     _   ALTER SEQUENCE public.detalle_producto_state_id_seq OWNED BY public.detalle_producto.state_id;
          public               postgres    false    307            �            1259    16527    detalle_state    TABLE       CREATE TABLE public.detalle_state (
    id integer NOT NULL,
    state_id integer,
    id_usuario integer,
    accion_id integer,
    descripcion text,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    estado boolean,
    area_id integer
);
 !   DROP TABLE public.detalle_state;
       public         heap r       postgres    false            �            1259    16526    detalle_state_id_seq    SEQUENCE     �   CREATE SEQUENCE public.detalle_state_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.detalle_state_id_seq;
       public               postgres    false    235            �           0    0    detalle_state_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE public.detalle_state_id_seq OWNED BY public.detalle_state.id;
          public               postgres    false    234                       1259    16902    detalle_venta    TABLE       CREATE TABLE public.detalle_venta (
    id integer NOT NULL,
    venta_id integer,
    detalle_producto_id integer,
    cantidad numeric(10,2),
    precio_venta numeric(10,2),
    subtotal numeric(10,2),
    descuento numeric(10,2),
    empleado_id integer
);
 !   DROP TABLE public.detalle_venta;
       public         heap r       postgres    false                       1259    16901    detalle_venta_id_seq    SEQUENCE     �   CREATE SEQUENCE public.detalle_venta_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.detalle_venta_id_seq;
       public               postgres    false    258            �           0    0    detalle_venta_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE public.detalle_venta_id_seq OWNED BY public.detalle_venta.id;
          public               postgres    false    257            F           1259    25406    empleado_id_seq    SEQUENCE     x   CREATE SEQUENCE public.empleado_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE public.empleado_id_seq;
       public               postgres    false                       1259    17194    empleado    TABLE     �  CREATE TABLE public.empleado (
    id integer DEFAULT nextval('public.empleado_id_seq'::regclass) NOT NULL,
    codigo_empleado character varying(50),
    nombre character varying(100),
    apellidos character varying(100),
    foto character varying(255),
    direccion character varying(255),
    telefono character varying(50),
    correo character varying(100),
    fecha_nacimiento timestamp without time zone,
    comentarios text,
    estado character varying(20),
    state_id integer
);
    DROP TABLE public.empleado;
       public         heap r       postgres    false    326                       1259    17193    empleado_idempleado_seq    SEQUENCE     �   CREATE SEQUENCE public.empleado_idempleado_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.empleado_idempleado_seq;
       public               postgres    false    268            �           0    0    empleado_idempleado_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE public.empleado_idempleado_seq OWNED BY public.empleado.id;
          public               postgres    false    267            B           1259    25398    empresa_id_seq    SEQUENCE     w   CREATE SEQUENCE public.empresa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE public.empresa_id_seq;
       public               postgres    false            *           1259    17349    empresa    TABLE     t  CREATE TABLE public.empresa (
    id integer DEFAULT nextval('public.empresa_id_seq'::regclass) NOT NULL,
    nombre character varying(150),
    rfc character varying(30),
    correo_contacto character varying(150),
    telefono_contacto character varying(30),
    logo text,
    estado boolean,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);
    DROP TABLE public.empresa;
       public         heap r       postgres    false    322            )           1259    17348    empresa_id_empresa_seq    SEQUENCE     �   CREATE SEQUENCE public.empresa_id_empresa_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.empresa_id_empresa_seq;
       public               postgres    false    298            �           0    0    empresa_id_empresa_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.empresa_id_empresa_seq OWNED BY public.empresa.id;
          public               postgres    false    297            0           1259    17390    etiqueta_producto    TABLE       CREATE TABLE public.etiqueta_producto (
    id integer NOT NULL,
    detalle_producto_id integer,
    tipo character varying(50),
    alias character varying(200),
    visible boolean DEFAULT true,
    state_id character varying,
    presentacion_id integer
);
 %   DROP TABLE public.etiqueta_producto;
       public         heap r       postgres    false            /           1259    17389    etiqueta_producto_id_seq    SEQUENCE     �   CREATE SEQUENCE public.etiqueta_producto_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.etiqueta_producto_id_seq;
       public               postgres    false    304            �           0    0    etiqueta_producto_id_seq    SEQUENCE OWNED BY     U   ALTER SEQUENCE public.etiqueta_producto_id_seq OWNED BY public.etiqueta_producto.id;
          public               postgres    false    303                       1259    16919    ingreso    TABLE     ]  CREATE TABLE public.ingreso (
    id integer NOT NULL,
    usuario_id integer,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    total numeric(10,2),
    proveedor_id integer,
    state_id character varying,
    metodo_pago character varying(80),
    comprobante character varying(50),
    iva numeric(4,2),
    pagado boolean
);
    DROP TABLE public.ingreso;
       public         heap r       postgres    false                       1259    16918    ingreso_id_seq    SEQUENCE     �   CREATE SEQUENCE public.ingreso_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE public.ingreso_id_seq;
       public               postgres    false    260            �           0    0    ingreso_id_seq    SEQUENCE OWNED BY     A   ALTER SEQUENCE public.ingreso_id_seq OWNED BY public.ingreso.id;
          public               postgres    false    259            �            1259    16500 
   inventario    TABLE     a  CREATE TABLE public.inventario (
    id integer NOT NULL,
    detalle_producto_id integer NOT NULL,
    stock_actual numeric(10,2),
    stock_minimo numeric(10,2),
    precio_costo numeric(10,2),
    actualizado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    ubicacion_fisica_id integer,
    proveedor_id integer,
    state_id integer
);
    DROP TABLE public.inventario;
       public         heap r       postgres    false            �            1259    16499    inventario_id_seq    SEQUENCE     �   CREATE SEQUENCE public.inventario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.inventario_id_seq;
       public               postgres    false    230            �           0    0    inventario_id_seq    SEQUENCE OWNED BY     G   ALTER SEQUENCE public.inventario_id_seq OWNED BY public.inventario.id;
          public               postgres    false    229            E           1259    25404    licencia_empresa_id_seq    SEQUENCE     �   CREATE SEQUENCE public.licencia_empresa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.licencia_empresa_id_seq;
       public               postgres    false                       1259    17286    licencia_empresa    TABLE     i  CREATE TABLE public.licencia_empresa (
    id integer DEFAULT nextval('public.licencia_empresa_id_seq'::regclass) NOT NULL,
    empresa_id integer,
    tipo character varying(50),
    limite_modulos integer,
    limite_usuarios integer,
    fecha_inicio timestamp without time zone,
    fecha_fin timestamp without time zone,
    activa boolean DEFAULT true
);
 $   DROP TABLE public.licencia_empresa;
       public         heap r       postgres    false    325                       1259    17285     licencia_empresa_id_licencia_seq    SEQUENCE     �   CREATE SEQUENCE public.licencia_empresa_id_licencia_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 7   DROP SEQUENCE public.licencia_empresa_id_licencia_seq;
       public               postgres    false    285            �           0    0     licencia_empresa_id_licencia_seq    SEQUENCE OWNED BY     \   ALTER SEQUENCE public.licencia_empresa_id_licencia_seq OWNED BY public.licencia_empresa.id;
          public               postgres    false    284            <           1259    25383    log_acceso_id_seq    SEQUENCE     z   CREATE SEQUENCE public.log_acceso_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 (   DROP SEQUENCE public.log_acceso_id_seq;
       public               postgres    false            !           1259    17303 
   log_acceso    TABLE     G  CREATE TABLE public.log_acceso (
    id integer DEFAULT nextval('public.log_acceso_id_seq'::regclass) NOT NULL,
    usuario_id integer,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    ip character varying(100),
    navegador character varying(100),
    exito boolean,
    sistema character varying(100)
);
    DROP TABLE public.log_acceso;
       public         heap r       postgres    false    316                        1259    17302    log_acceso_id_log_seq    SEQUENCE     �   CREATE SEQUENCE public.log_acceso_id_log_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public.log_acceso_id_log_seq;
       public               postgres    false    289            �           0    0    log_acceso_id_log_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE public.log_acceso_id_log_seq OWNED BY public.log_acceso.id;
          public               postgres    false    288            D           1259    25402    modulo_empresa_id_seq    SEQUENCE     ~   CREATE SEQUENCE public.modulo_empresa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 ,   DROP SEQUENCE public.modulo_empresa_id_seq;
       public               postgres    false                       1259    17276    modulo_empresa    TABLE       CREATE TABLE public.modulo_empresa (
    id integer DEFAULT nextval('public.modulo_empresa_id_seq'::regclass) NOT NULL,
    nombre character varying(100) NOT NULL,
    fecha timestamp without time zone,
    activo boolean DEFAULT true,
    empresa_id integer
);
 "   DROP TABLE public.modulo_empresa;
       public         heap r       postgres    false    324                       1259    17275    modulo_empresa_id_modulo_seq    SEQUENCE     �   CREATE SEQUENCE public.modulo_empresa_id_modulo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 3   DROP SEQUENCE public.modulo_empresa_id_modulo_seq;
       public               postgres    false    283            �           0    0    modulo_empresa_id_modulo_seq    SEQUENCE OWNED BY     V   ALTER SEQUENCE public.modulo_empresa_id_modulo_seq OWNED BY public.modulo_empresa.id;
          public               postgres    false    282            P           1259    25729    movimiento_stock    TABLE     5  CREATE TABLE public.movimiento_stock (
    id integer NOT NULL,
    empresa_id integer NOT NULL,
    producto_id integer NOT NULL,
    detalle_producto_id integer,
    ubicacion_id integer NOT NULL,
    cantidad numeric(10,2) NOT NULL,
    precio_costo numeric(10,2),
    tipo_movimiento character varying(50) NOT NULL,
    motivo text,
    usuario_id integer,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    ubicacion_origen_id integer,
    ubicacion_destino_id integer,
    referencia_id integer,
    referencia_tipo character varying(50)
);
 $   DROP TABLE public.movimiento_stock;
       public         heap r       postgres    false            O           1259    25728    movimiento_stock_id_seq    SEQUENCE     �   CREATE SEQUENCE public.movimiento_stock_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.movimiento_stock_id_seq;
       public               postgres    false    336            �           0    0    movimiento_stock_id_seq    SEQUENCE OWNED BY     S   ALTER SEQUENCE public.movimiento_stock_id_seq OWNED BY public.movimiento_stock.id;
          public               postgres    false    335            C           1259    25400    negocio_id_seq    SEQUENCE     w   CREATE SEQUENCE public.negocio_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE public.negocio_id_seq;
       public               postgres    false            (           1259    17339    negocio    TABLE     	  CREATE TABLE public.negocio (
    id integer DEFAULT nextval('public.negocio_id_seq'::regclass) NOT NULL,
    empresa_id integer,
    nombre character varying(100),
    giro_comercial character varying(100),
    descripcion text,
    activo boolean DEFAULT true
);
    DROP TABLE public.negocio;
       public         heap r       postgres    false    323            '           1259    17338    negocio_id_negocio_seq    SEQUENCE     �   CREATE SEQUENCE public.negocio_id_negocio_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.negocio_id_negocio_seq;
       public               postgres    false    296            �           0    0    negocio_id_negocio_seq    SEQUENCE OWNED BY     I   ALTER SEQUENCE public.negocio_id_negocio_seq OWNED BY public.negocio.id;
          public               postgres    false    295            A           1259    25396    pago_empresa_id_seq    SEQUENCE     |   CREATE SEQUENCE public.pago_empresa_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.pago_empresa_id_seq;
       public               postgres    false                       1259    17294    pago_empresa    TABLE       CREATE TABLE public.pago_empresa (
    id integer DEFAULT nextval('public.pago_empresa_id_seq'::regclass) NOT NULL,
    empresa_id integer,
    monto numeric(10,2),
    fecha_pago timestamp without time zone,
    metodo_pago character varying(50),
    descripcion text
);
     DROP TABLE public.pago_empresa;
       public         heap r       postgres    false    321                       1259    17293    pago_empresa_id_pago_seq    SEQUENCE     �   CREATE SEQUENCE public.pago_empresa_id_pago_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 /   DROP SEQUENCE public.pago_empresa_id_pago_seq;
       public               postgres    false    287            �           0    0    pago_empresa_id_pago_seq    SEQUENCE OWNED BY     P   ALTER SEQUENCE public.pago_empresa_id_pago_seq OWNED BY public.pago_empresa.id;
          public               postgres    false    286            �            1259    16872    precio    TABLE     �  CREATE TABLE public.precio (
    id integer NOT NULL,
    detalle_producto_id integer NOT NULL,
    ubicacion_fisica_id integer,
    precio_venta numeric(10,2),
    vigente boolean DEFAULT true,
    fecha_inicio timestamp without time zone,
    fecha_fin timestamp without time zone,
    cliente_id integer,
    tipo_cliente_id integer,
    cantidad_minima numeric(10,2),
    precio_base numeric(10,2),
    prioridad smallint,
    descripcion character varying(150),
    presentacion_id integer
);
    DROP TABLE public.precio;
       public         heap r       postgres    false            �            1259    16871    precio_id_seq    SEQUENCE     �   CREATE SEQUENCE public.precio_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE public.precio_id_seq;
       public               postgres    false    252            �           0    0    precio_id_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE public.precio_id_seq OWNED BY public.precio.id;
          public               postgres    false    251            N           1259    25423    presentacion_id_seq    SEQUENCE     |   CREATE SEQUENCE public.presentacion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.presentacion_id_seq;
       public               postgres    false            4           1259    24583    presentacion    TABLE     �   CREATE TABLE public.presentacion (
    id integer DEFAULT nextval('public.presentacion_id_seq'::regclass) NOT NULL,
    detalle_producto_id integer,
    nombre character varying,
    cantidad numeric(10,4),
    descripcion character varying
);
     DROP TABLE public.presentacion;
       public         heap r       postgres    false    334            "           1259    17311    producto    TABLE     �   CREATE TABLE public.producto (
    categoria_id integer,
    nombre character varying(100),
    descripcion text,
    activo boolean DEFAULT true,
    state_id integer,
    id integer NOT NULL
);
    DROP TABLE public.producto;
       public         heap r       postgres    false            6           1259    24939    producto_id_seq    SEQUENCE     �   CREATE SEQUENCE public.producto_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 &   DROP SEQUENCE public.producto_id_seq;
       public               postgres    false    290            �           0    0    producto_id_seq    SEQUENCE OWNED BY     C   ALTER SEQUENCE public.producto_id_seq OWNED BY public.producto.id;
          public               postgres    false    310            H           1259    25410    producto_multimedia_id_seq    SEQUENCE     �   CREATE SEQUENCE public.producto_multimedia_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.producto_multimedia_id_seq;
       public               postgres    false                       1259    17227    producto_multimedia    TABLE     �  CREATE TABLE public.producto_multimedia (
    id integer DEFAULT nextval('public.producto_multimedia_id_seq'::regclass) NOT NULL,
    detalle_producto_id integer,
    tipo_archivo character varying(20),
    url_archivo character varying(255),
    extension character varying(10),
    formato_especial character varying(50),
    prioridad integer,
    descripcion text,
    activo boolean DEFAULT true,
    fecha_registro timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);
 '   DROP TABLE public.producto_multimedia;
       public         heap r       postgres    false    328                       1259    17226 %   producto_multimedia_id_multimedia_seq    SEQUENCE     �   CREATE SEQUENCE public.producto_multimedia_id_multimedia_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 <   DROP SEQUENCE public.producto_multimedia_id_multimedia_seq;
       public               postgres    false    276            �           0    0 %   producto_multimedia_id_multimedia_seq    SEQUENCE OWNED BY     d   ALTER SEQUENCE public.producto_multimedia_id_multimedia_seq OWNED BY public.producto_multimedia.id;
          public               postgres    false    275            I           1259    25412    producto_ubicacion_id_seq    SEQUENCE     �   CREATE SEQUENCE public.producto_ubicacion_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 0   DROP SEQUENCE public.producto_ubicacion_id_seq;
       public               postgres    false            $           1259    17321    producto_ubicacion    TABLE     3  CREATE TABLE public.producto_ubicacion (
    id integer DEFAULT nextval('public.producto_ubicacion_id_seq'::regclass) NOT NULL,
    detalle_producto_id integer,
    inventario_id integer,
    negocio_id integer,
    ubicacion_fisica_id integer,
    precio_id integer,
    compartir boolean DEFAULT false
);
 &   DROP TABLE public.producto_ubicacion;
       public         heap r       postgres    false    329            G           1259    25408    producto_visual_tag_id_seq    SEQUENCE     �   CREATE SEQUENCE public.producto_visual_tag_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.producto_visual_tag_id_seq;
       public               postgres    false                       1259    17238    producto_visual_tag    TABLE     D  CREATE TABLE public.producto_visual_tag (
    id integer DEFAULT nextval('public.producto_visual_tag_id_seq'::regclass) NOT NULL,
    detalle_producto_id integer,
    tag character varying(100),
    fuente character varying(50),
    confianza numeric(5,2),
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);
 '   DROP TABLE public.producto_visual_tag;
       public         heap r       postgres    false    327                       1259    17237    producto_visual_tag_id_tag_seq    SEQUENCE     �   CREATE SEQUENCE public.producto_visual_tag_id_tag_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 5   DROP SEQUENCE public.producto_visual_tag_id_tag_seq;
       public               postgres    false    278            �           0    0    producto_visual_tag_id_tag_seq    SEQUENCE OWNED BY     ]   ALTER SEQUENCE public.producto_visual_tag_id_tag_seq OWNED BY public.producto_visual_tag.id;
          public               postgres    false    277            #           1259    17320 -   productos_ubicacion_id_producto_ubicacion_seq    SEQUENCE     �   CREATE SEQUENCE public.productos_ubicacion_id_producto_ubicacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 D   DROP SEQUENCE public.productos_ubicacion_id_producto_ubicacion_seq;
       public               postgres    false    292            �           0    0 -   productos_ubicacion_id_producto_ubicacion_seq    SEQUENCE OWNED BY     k   ALTER SEQUENCE public.productos_ubicacion_id_producto_ubicacion_seq OWNED BY public.producto_ubicacion.id;
          public               postgres    false    291            �            1259    16885 	   promocion    TABLE     �   CREATE TABLE public.promocion (
    id integer NOT NULL,
    descripcion text,
    tipo character varying(50),
    valor numeric(10,2),
    fecha_inicio timestamp without time zone,
    fecha_fin timestamp without time zone
);
    DROP TABLE public.promocion;
       public         heap r       postgres    false            �            1259    16884    promocion_id_seq    SEQUENCE     �   CREATE SEQUENCE public.promocion_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.promocion_id_seq;
       public               postgres    false    254            �           0    0    promocion_id_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE public.promocion_id_seq OWNED BY public.promocion.id;
          public               postgres    false    253            �            1259    16863 	   proveedor    TABLE     M  CREATE TABLE public.proveedor (
    id integer NOT NULL,
    nombre character varying(150),
    contacto character varying(100),
    telefono character varying(20),
    direccion text,
    state_id integer,
    codigo_proveedor character varying(100),
    rfc character varying(50),
    foto character varying,
    estado boolean
);
    DROP TABLE public.proveedor;
       public         heap r       postgres    false            �            1259    16862    proveedor_id_seq    SEQUENCE     �   CREATE SEQUENCE public.proveedor_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 '   DROP SEQUENCE public.proveedor_id_seq;
       public               postgres    false    250            �           0    0    proveedor_id_seq    SEQUENCE OWNED BY     E   ALTER SEQUENCE public.proveedor_id_seq OWNED BY public.proveedor.id;
          public               postgres    false    249            @           1259    25394    restriccion_usuario_id_seq    SEQUENCE     �   CREATE SEQUENCE public.restriccion_usuario_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 1   DROP SEQUENCE public.restriccion_usuario_id_seq;
       public               postgres    false            �            1259    16833    restriccion_usuario    TABLE     �   CREATE TABLE public.restriccion_usuario (
    id integer DEFAULT nextval('public.restriccion_usuario_id_seq'::regclass) NOT NULL,
    usuario_id integer NOT NULL,
    area_id integer NOT NULL,
    accion_id integer NOT NULL
);
 '   DROP TABLE public.restriccion_usuario;
       public         heap r       postgres    false    320                       1259    16944    retiro    TABLE     �   CREATE TABLE public.retiro (
    id integer NOT NULL,
    usuario_id integer,
    corte_caja_id text,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    monto numeric(10,2),
    motivo character varying(250)
);
    DROP TABLE public.retiro;
       public         heap r       postgres    false                       1259    16943    retiro_id_seq    SEQUENCE     �   CREATE SEQUENCE public.retiro_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 $   DROP SEQUENCE public.retiro_id_seq;
       public               postgres    false    264            �           0    0    retiro_id_seq    SEQUENCE OWNED BY     ?   ALTER SEQUENCE public.retiro_id_seq OWNED BY public.retiro.id;
          public               postgres    false    263            �            1259    16774    rol    TABLE     �   CREATE TABLE public.rol (
    id integer NOT NULL,
    empresa_id integer,
    nombre text,
    descripcion character varying
);
    DROP TABLE public.rol;
       public         heap r       postgres    false            �            1259    16773 
   rol_id_seq    SEQUENCE     �   CREATE SEQUENCE public.rol_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 !   DROP SEQUENCE public.rol_id_seq;
       public               postgres    false    239            �           0    0 
   rol_id_seq    SEQUENCE OWNED BY     9   ALTER SEQUENCE public.rol_id_seq OWNED BY public.rol.id;
          public               postgres    false    238            �            1259    16813    rol_permiso    TABLE     {   CREATE TABLE public.rol_permiso (
    id integer NOT NULL,
    area_id integer NOT NULL,
    accion_id integer NOT NULL
);
    DROP TABLE public.rol_permiso;
       public         heap r       postgres    false            �            1259    16519    state    TABLE     �   CREATE TABLE public.state (
    id integer NOT NULL,
    tabla_afectada character varying(100),
    id_tabla integer,
    estado character varying(50),
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP
);
    DROP TABLE public.state;
       public         heap r       postgres    false            �            1259    16518    state_id_seq    SEQUENCE     �   CREATE SEQUENCE public.state_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE public.state_id_seq;
       public               postgres    false    233            �           0    0    state_id_seq    SEQUENCE OWNED BY     =   ALTER SEQUENCE public.state_id_seq OWNED BY public.state.id;
          public               postgres    false    232            �            1259    16396    sub_categoria    TABLE     �   CREATE TABLE public.sub_categoria (
    id integer NOT NULL,
    categoria_id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion character varying
);
 !   DROP TABLE public.sub_categoria;
       public         heap r       postgres    false            �            1259    16395    sub_categoria_id_seq    SEQUENCE     �   CREATE SEQUENCE public.sub_categoria_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 +   DROP SEQUENCE public.sub_categoria_id_seq;
       public               postgres    false    220            �           0    0    sub_categoria_id_seq    SEQUENCE OWNED BY     M   ALTER SEQUENCE public.sub_categoria_id_seq OWNED BY public.sub_categoria.id;
          public               postgres    false    219            8           1259    25140    tipo_cliente    TABLE     O   CREATE TABLE public.tipo_cliente (
    id integer NOT NULL,
    nombre text
);
     DROP TABLE public.tipo_cliente;
       public         heap r       postgres    false            7           1259    25139    tipo_cliente_id_seq    SEQUENCE     �   CREATE SEQUENCE public.tipo_cliente_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 *   DROP SEQUENCE public.tipo_cliente_id_seq;
       public               postgres    false    312            �           0    0    tipo_cliente_id_seq    SEQUENCE OWNED BY     K   ALTER SEQUENCE public.tipo_cliente_id_seq OWNED BY public.tipo_cliente.id;
          public               postgres    false    311            M           1259    25420    tipo_contenedor_id_seq    SEQUENCE        CREATE SEQUENCE public.tipo_contenedor_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 -   DROP SEQUENCE public.tipo_contenedor_id_seq;
       public               postgres    false                       1259    17203    tipo_contenedor    TABLE     �   CREATE TABLE public.tipo_contenedor (
    id integer DEFAULT nextval('public.tipo_contenedor_id_seq'::regclass) NOT NULL,
    nombre character varying(100) NOT NULL,
    color_default character varying(20),
    icon_url character varying(255)
);
 #   DROP TABLE public.tipo_contenedor;
       public         heap r       postgres    false    333                       1259    17202    tipo_contenedor_id_tipo_seq    SEQUENCE     �   CREATE SEQUENCE public.tipo_contenedor_id_tipo_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 2   DROP SEQUENCE public.tipo_contenedor_id_tipo_seq;
       public               postgres    false    270            �           0    0    tipo_contenedor_id_tipo_seq    SEQUENCE OWNED BY     V   ALTER SEQUENCE public.tipo_contenedor_id_tipo_seq OWNED BY public.tipo_contenedor.id;
          public               postgres    false    269            L           1259    25418    ubicacion_fisica_id_seq    SEQUENCE     �   CREATE SEQUENCE public.ubicacion_fisica_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 .   DROP SEQUENCE public.ubicacion_fisica_id_seq;
       public               postgres    false            &           1259    17329    ubicacion_fisica    TABLE     �  CREATE TABLE public.ubicacion_fisica (
    id integer DEFAULT nextval('public.ubicacion_fisica_id_seq'::regclass) NOT NULL,
    negocio_id integer,
    nombre character varying(100),
    tipo character varying(50),
    direccion character varying(150),
    ciudad character varying(100),
    estado character varying(100),
    latitud numeric(10,6),
    longitud numeric(10,6),
    activa boolean DEFAULT true
);
 $   DROP TABLE public.ubicacion_fisica;
       public         heap r       postgres    false    332            %           1259    17328 !   ubicacion_fisica_id_ubicacion_seq    SEQUENCE     �   CREATE SEQUENCE public.ubicacion_fisica_id_ubicacion_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 8   DROP SEQUENCE public.ubicacion_fisica_id_ubicacion_seq;
       public               postgres    false    294            �           0    0 !   ubicacion_fisica_id_ubicacion_seq    SEQUENCE OWNED BY     ]   ALTER SEQUENCE public.ubicacion_fisica_id_ubicacion_seq OWNED BY public.ubicacion_fisica.id;
          public               postgres    false    293            �            1259    16761    usuario    TABLE     Z  CREATE TABLE public.usuario (
    id integer NOT NULL,
    empresa_id integer,
    nombre_usuario character varying(100) NOT NULL,
    password_hash character varying(255) NOT NULL,
    correo character varying(150),
    activo boolean DEFAULT true,
    creado_en timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    empleado_id integer
);
    DROP TABLE public.usuario;
       public         heap r       postgres    false            �            1259    16760    usuario_id_seq    SEQUENCE     �   CREATE SEQUENCE public.usuario_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 %   DROP SEQUENCE public.usuario_id_seq;
       public               postgres    false    237            �           0    0    usuario_id_seq    SEQUENCE OWNED BY     A   ALTER SEQUENCE public.usuario_id_seq OWNED BY public.usuario.id;
          public               postgres    false    236            �            1259    16782    usuario_rol    TABLE     Z   CREATE TABLE public.usuario_rol (
    id integer NOT NULL,
    rol_id integer NOT NULL
);
    DROP TABLE public.usuario_rol;
       public         heap r       postgres    false                        1259    16894    venta    TABLE     p  CREATE TABLE public.venta (
    id integer NOT NULL,
    usuario_id integer,
    cliente_id integer,
    fecha timestamp without time zone DEFAULT CURRENT_TIMESTAMP,
    total numeric(10,2),
    forma_pago character varying(50),
    state_id integer,
    comprobante character varying(50),
    iva numeric(4,2),
    pagado boolean,
    estado character varying(50)
);
    DROP TABLE public.venta;
       public         heap r       postgres    false            �            1259    16893    venta_id_seq    SEQUENCE     �   CREATE SEQUENCE public.venta_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
 #   DROP SEQUENCE public.venta_id_seq;
       public               postgres    false    256            �           0    0    venta_id_seq    SEQUENCE OWNED BY     =   ALTER SEQUENCE public.venta_id_seq OWNED BY public.venta.id;
          public               postgres    false    255            
           1259    16963    vista_productos_disponibles    VIEW     �  CREATE VIEW public.vista_productos_disponibles AS
 SELECT dp.id AS id_detalle_producto,
    dp.nombre_calculado,
    i.stock_actual,
    i.precio_costo,
    p.precio_venta,
    i.id AS id_inventario,
    i.ubicacion_fisica_id AS id_ubicacion_fisica
   FROM ((public.inventario i
     JOIN public.detalle_producto dp ON ((dp.id = i.detalle_producto_id)))
     LEFT JOIN public.precio p ON (((p.detalle_producto_id = dp.id) AND (p.ubicacion_fisica_id = i.ubicacion_fisica_id) AND (p.vigente = true))));
 .   DROP VIEW public.vista_productos_disponibles;
       public       v       postgres    false    230    252    252    252    230    252    230    230    226    226    230            �            1259    16514    vista_stock_actual    VIEW     �   CREATE VIEW public.vista_stock_actual AS
 SELECT i.id,
    dp.nombre_calculado,
    i.stock_actual,
    i.precio_costo,
    i.actualizado_en
   FROM (public.inventario i
     JOIN public.detalle_producto dp ON ((dp.id = i.detalle_producto_id)));
 %   DROP VIEW public.vista_stock_actual;
       public       v       postgres    false    230    230    230    230    230    226    226            �           2604    16808 	   accion id    DEFAULT     f   ALTER TABLE ONLY public.accion ALTER COLUMN id SET DEFAULT nextval('public.accion_id_seq'::regclass);
 8   ALTER TABLE public.accion ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    244    243    244            �           2604    16801    area id    DEFAULT     b   ALTER TABLE ONLY public.area ALTER COLUMN id SET DEFAULT nextval('public.area_id_seq'::regclass);
 6   ALTER TABLE public.area ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    241    242    242            �           2604    16411    atributo id    DEFAULT     j   ALTER TABLE ONLY public.atributo ALTER COLUMN id SET DEFAULT nextval('public.atributo_id_seq'::regclass);
 :   ALTER TABLE public.atributo ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    221    222    222            �           2604    16392    categoria id    DEFAULT     l   ALTER TABLE ONLY public.categoria ALTER COLUMN id SET DEFAULT nextval('public.categoria_id_seq'::regclass);
 ;   ALTER TABLE public.categoria ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    218    217    218            �           2604    16857 
   cliente id    DEFAULT     h   ALTER TABLE ONLY public.cliente ALTER COLUMN id SET DEFAULT nextval('public.cliente_id_seq'::regclass);
 9   ALTER TABLE public.cliente ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    248    247    248            �           2604    16486    componente id    DEFAULT     n   ALTER TABLE ONLY public.componente ALTER COLUMN id SET DEFAULT nextval('public.componente_id_seq'::regclass);
 <   ALTER TABLE public.componente ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    228    227    228            �           2604    25368    contenedor_figura id    DEFAULT     |   ALTER TABLE ONLY public.contenedor_figura ALTER COLUMN id SET DEFAULT nextval('public.contenedor_figura_id_seq'::regclass);
 C   ALTER TABLE public.contenedor_figura ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    314    279            �           2604    25359    contenedor_instancia id    DEFAULT     �   ALTER TABLE ONLY public.contenedor_instancia ALTER COLUMN id SET DEFAULT nextval('public.contenedor_instancia_id_seq'::regclass);
 F   ALTER TABLE public.contenedor_instancia ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    313    309            �           2604    25377    corte_caja id    DEFAULT     n   ALTER TABLE ONLY public.corte_caja ALTER COLUMN id SET DEFAULT nextval('public.corte_caja_id_seq'::regclass);
 <   ALTER TABLE public.corte_caja ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    315    265            �           2604    16418    detalle_atributo id    DEFAULT     z   ALTER TABLE ONLY public.detalle_atributo ALTER COLUMN id SET DEFAULT nextval('public.detalle_atributo_id_seq'::regclass);
 B   ALTER TABLE public.detalle_atributo ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    224    223    224            �           2604    16930    detalle_ingreso id    DEFAULT     x   ALTER TABLE ONLY public.detalle_ingreso ALTER COLUMN id SET DEFAULT nextval('public.detalle_ingreso_id_seq'::regclass);
 A   ALTER TABLE public.detalle_ingreso ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    261    262    262            �           2604    16437    detalle_producto id    DEFAULT     z   ALTER TABLE ONLY public.detalle_producto ALTER COLUMN id SET DEFAULT nextval('public.detalle_producto_id_seq'::regclass);
 B   ALTER TABLE public.detalle_producto ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    225    226    226            �           2604    16530    detalle_state id    DEFAULT     t   ALTER TABLE ONLY public.detalle_state ALTER COLUMN id SET DEFAULT nextval('public.detalle_state_id_seq'::regclass);
 ?   ALTER TABLE public.detalle_state ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    235    234    235            �           2604    16905    detalle_venta id    DEFAULT     t   ALTER TABLE ONLY public.detalle_venta ALTER COLUMN id SET DEFAULT nextval('public.detalle_venta_id_seq'::regclass);
 ?   ALTER TABLE public.detalle_venta ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    257    258    258            �           2604    17393    etiqueta_producto id    DEFAULT     |   ALTER TABLE ONLY public.etiqueta_producto ALTER COLUMN id SET DEFAULT nextval('public.etiqueta_producto_id_seq'::regclass);
 C   ALTER TABLE public.etiqueta_producto ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    303    304    304            �           2604    16922 
   ingreso id    DEFAULT     h   ALTER TABLE ONLY public.ingreso ALTER COLUMN id SET DEFAULT nextval('public.ingreso_id_seq'::regclass);
 9   ALTER TABLE public.ingreso ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    260    259    260            �           2604    16503    inventario id    DEFAULT     n   ALTER TABLE ONLY public.inventario ALTER COLUMN id SET DEFAULT nextval('public.inventario_id_seq'::regclass);
 <   ALTER TABLE public.inventario ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    229    230    230            �           2604    25732    movimiento_stock id    DEFAULT     z   ALTER TABLE ONLY public.movimiento_stock ALTER COLUMN id SET DEFAULT nextval('public.movimiento_stock_id_seq'::regclass);
 B   ALTER TABLE public.movimiento_stock ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    335    336    336            �           2604    16875 	   precio id    DEFAULT     f   ALTER TABLE ONLY public.precio ALTER COLUMN id SET DEFAULT nextval('public.precio_id_seq'::regclass);
 8   ALTER TABLE public.precio ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    252    251    252            �           2604    24940    producto id    DEFAULT     j   ALTER TABLE ONLY public.producto ALTER COLUMN id SET DEFAULT nextval('public.producto_id_seq'::regclass);
 :   ALTER TABLE public.producto ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    310    290            �           2604    16888    promocion id    DEFAULT     l   ALTER TABLE ONLY public.promocion ALTER COLUMN id SET DEFAULT nextval('public.promocion_id_seq'::regclass);
 ;   ALTER TABLE public.promocion ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    253    254    254            �           2604    16866    proveedor id    DEFAULT     l   ALTER TABLE ONLY public.proveedor ALTER COLUMN id SET DEFAULT nextval('public.proveedor_id_seq'::regclass);
 ;   ALTER TABLE public.proveedor ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    249    250    250            �           2604    16947 	   retiro id    DEFAULT     f   ALTER TABLE ONLY public.retiro ALTER COLUMN id SET DEFAULT nextval('public.retiro_id_seq'::regclass);
 8   ALTER TABLE public.retiro ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    263    264    264            �           2604    16777    rol id    DEFAULT     `   ALTER TABLE ONLY public.rol ALTER COLUMN id SET DEFAULT nextval('public.rol_id_seq'::regclass);
 5   ALTER TABLE public.rol ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    238    239    239            �           2604    16522    state id    DEFAULT     d   ALTER TABLE ONLY public.state ALTER COLUMN id SET DEFAULT nextval('public.state_id_seq'::regclass);
 7   ALTER TABLE public.state ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    233    232    233            �           2604    16399    sub_categoria id    DEFAULT     t   ALTER TABLE ONLY public.sub_categoria ALTER COLUMN id SET DEFAULT nextval('public.sub_categoria_id_seq'::regclass);
 ?   ALTER TABLE public.sub_categoria ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    220    219    220            �           2604    25143    tipo_cliente id    DEFAULT     r   ALTER TABLE ONLY public.tipo_cliente ALTER COLUMN id SET DEFAULT nextval('public.tipo_cliente_id_seq'::regclass);
 >   ALTER TABLE public.tipo_cliente ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    311    312    312            �           2604    16764 
   usuario id    DEFAULT     h   ALTER TABLE ONLY public.usuario ALTER COLUMN id SET DEFAULT nextval('public.usuario_id_seq'::regclass);
 9   ALTER TABLE public.usuario ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    237    236    237            �           2604    16897    venta id    DEFAULT     d   ALTER TABLE ONLY public.venta ALTER COLUMN id SET DEFAULT nextval('public.venta_id_seq'::regclass);
 7   ALTER TABLE public.venta ALTER COLUMN id DROP DEFAULT;
       public               postgres    false    255    256    256            E          0    16805    accion 
   TABLE DATA           9   COPY public.accion (id, nombre, descripcion) FROM stdin;
    public               postgres    false    244   =Q      C          0    16798    area 
   TABLE DATA           *   COPY public.area (id, nombre) FROM stdin;
    public               postgres    false    242   ZQ      0          0    16408    atributo 
   TABLE DATA           .   COPY public.atributo (id, nombre) FROM stdin;
    public               postgres    false    222   wQ      ,          0    16389 	   categoria 
   TABLE DATA           N   COPY public.categoria (id, nombre, state_id, descripcion, estado) FROM stdin;
    public               postgres    false    218   bR      b          0    17219    celda 
   TABLE DATA           t   COPY public.celda (id, contenedor_fisico_id, fila, columna, activa, capacidad_minima, capacidad_maxima) FROM stdin;
    public               postgres    false    274   �R      I          0    16854    cliente 
   TABLE DATA           �   COPY public.cliente (id, nombre, telefono, direccion, state_id, codigo_cliente, apellidos, foto, correo, fecha_nacimiento, comentarios, estado, tipo_cliente_id) FROM stdin;
    public               postgres    false    248   �R      6          0    16483 
   componente 
   TABLE DATA           g   COPY public.componente (id, detalle_producto_padre_id, detalle_producto_hijo_id, cantidad) FROM stdin;
    public               postgres    false    228   S      ~          0    17380    configuracion_extra_json 
   TABLE DATA           �   COPY public.configuracion_extra_json (id, tipo_entidad, id_referencia, json_config, fecha_creacion, configuracion_negocio_id) FROM stdin;
    public               postgres    false    302   nS      |          0    17369    configuracion_negocio 
   TABLE DATA           �   COPY public.configuracion_negocio (id, negocio_id, moneda, idioma, permite_venta, permite_descuento, mostrar_codigo, formato_ticket, redondear_precio) FROM stdin;
    public               postgres    false    300   �S      g          0    17246    contenedor_figura 
   TABLE DATA           i   COPY public.contenedor_figura (punto_orden, pos_x, pos_y, largo, alto, ancho, color_hex, id) FROM stdin;
    public               postgres    false    279   �S      `          0    17210    contenedor_fisico 
   TABLE DATA           �   COPY public.contenedor_fisico (id, contenedor_instancia_id, nombre, descripcion, ubicacion_fisica_id, contenedor_figura_id, tipo_contenedor_id) FROM stdin;
    public               postgres    false    272   �S      �          0    24590    contenedor_instancia 
   TABLE DATA           x   COPY public.contenedor_instancia (empresa_id, nombre_personalizado, visible, rotacion, escala, z_indez, id) FROM stdin;
    public               postgres    false    309   T      Z          0    16954 
   corte_caja 
   TABLE DATA           h   COPY public.corte_caja (id_usuario, fecha_inicio, fecha_fin, monto_inicio, monto_final, id) FROM stdin;
    public               postgres    false    265   @T      2          0    16415    detalle_atributo 
   TABLE DATA           B   COPY public.detalle_atributo (id, id_atributo, valor) FROM stdin;
    public               postgres    false    224   ]T      W          0    16927    detalle_ingreso 
   TABLE DATA           z   COPY public.detalle_ingreso (id, ingreso_id, detalle_producto_id, cantidad, precio_costo, subtotal, state_id) FROM stdin;
    public               postgres    false    262   �U      4          0    16434    detalle_producto 
   TABLE DATA           �   COPY public.detalle_producto (id, medida, unidad_medida, marca_id, descripcion, nombre_calculado, activo, producto_id, atributo_id, state_id) FROM stdin;
    public               postgres    false    226   �U      i          0    17259    detalle_producto_celda 
   TABLE DATA           �   COPY public.detalle_producto_celda (id, contenedor_fisico_id, celda_id, detalle_producto_id, inventario_id, cantidad) FROM stdin;
    public               postgres    false    281   �X      <          0    16527    detalle_state 
   TABLE DATA           q   COPY public.detalle_state (id, state_id, id_usuario, accion_id, descripcion, fecha, estado, area_id) FROM stdin;
    public               postgres    false    235   ]Y      S          0    16902    detalle_venta 
   TABLE DATA           �   COPY public.detalle_venta (id, venta_id, detalle_producto_id, cantidad, precio_venta, subtotal, descuento, empleado_id) FROM stdin;
    public               postgres    false    258   zY      \          0    17194    empleado 
   TABLE DATA           �   COPY public.empleado (id, codigo_empleado, nombre, apellidos, foto, direccion, telefono, correo, fecha_nacimiento, comentarios, estado, state_id) FROM stdin;
    public               postgres    false    268   �Y      z          0    17349    empresa 
   TABLE DATA           t   COPY public.empresa (id, nombre, rfc, correo_contacto, telefono_contacto, logo, estado, fecha_registro) FROM stdin;
    public               postgres    false    298   �Y      �          0    17390    etiqueta_producto 
   TABLE DATA           u   COPY public.etiqueta_producto (id, detalle_producto_id, tipo, alias, visible, state_id, presentacion_id) FROM stdin;
    public               postgres    false    304   �Y      U          0    16919    ingreso 
   TABLE DATA           ~   COPY public.ingreso (id, usuario_id, fecha, total, proveedor_id, state_id, metodo_pago, comprobante, iva, pagado) FROM stdin;
    public               postgres    false    260   \      8          0    16500 
   inventario 
   TABLE DATA           �   COPY public.inventario (id, detalle_producto_id, stock_actual, stock_minimo, precio_costo, actualizado_en, ubicacion_fisica_id, proveedor_id, state_id) FROM stdin;
    public               postgres    false    230   ;\      m          0    17286    licencia_empresa 
   TABLE DATA           �   COPY public.licencia_empresa (id, empresa_id, tipo, limite_modulos, limite_usuarios, fecha_inicio, fecha_fin, activa) FROM stdin;
    public               postgres    false    285   H`      q          0    17303 
   log_acceso 
   TABLE DATA           Z   COPY public.log_acceso (id, usuario_id, fecha, ip, navegador, exito, sistema) FROM stdin;
    public               postgres    false    289   e`      k          0    17276    modulo_empresa 
   TABLE DATA           O   COPY public.modulo_empresa (id, nombre, fecha, activo, empresa_id) FROM stdin;
    public               postgres    false    283   �`      �          0    25729    movimiento_stock 
   TABLE DATA           �   COPY public.movimiento_stock (id, empresa_id, producto_id, detalle_producto_id, ubicacion_id, cantidad, precio_costo, tipo_movimiento, motivo, usuario_id, fecha, ubicacion_origen_id, ubicacion_destino_id, referencia_id, referencia_tipo) FROM stdin;
    public               postgres    false    336   �`      x          0    17339    negocio 
   TABLE DATA           ^   COPY public.negocio (id, empresa_id, nombre, giro_comercial, descripcion, activo) FROM stdin;
    public               postgres    false    296   �d      o          0    17294    pago_empresa 
   TABLE DATA           c   COPY public.pago_empresa (id, empresa_id, monto, fecha_pago, metodo_pago, descripcion) FROM stdin;
    public               postgres    false    287   9e      M          0    16872    precio 
   TABLE DATA           �   COPY public.precio (id, detalle_producto_id, ubicacion_fisica_id, precio_venta, vigente, fecha_inicio, fecha_fin, cliente_id, tipo_cliente_id, cantidad_minima, precio_base, prioridad, descripcion, presentacion_id) FROM stdin;
    public               postgres    false    252   Ve      �          0    24583    presentacion 
   TABLE DATA           ^   COPY public.presentacion (id, detalle_producto_id, nombre, cantidad, descripcion) FROM stdin;
    public               postgres    false    308   h      r          0    17311    producto 
   TABLE DATA           [   COPY public.producto (categoria_id, nombre, descripcion, activo, state_id, id) FROM stdin;
    public               postgres    false    290   �i      d          0    17227    producto_multimedia 
   TABLE DATA           �   COPY public.producto_multimedia (id, detalle_producto_id, tipo_archivo, url_archivo, extension, formato_especial, prioridad, descripcion, activo, fecha_registro) FROM stdin;
    public               postgres    false    276   �i      t          0    17321    producto_ubicacion 
   TABLE DATA           �   COPY public.producto_ubicacion (id, detalle_producto_id, inventario_id, negocio_id, ubicacion_fisica_id, precio_id, compartir) FROM stdin;
    public               postgres    false    292   �k      f          0    17238    producto_visual_tag 
   TABLE DATA           e   COPY public.producto_visual_tag (id, detalle_producto_id, tag, fuente, confianza, fecha) FROM stdin;
    public               postgres    false    278   �n      O          0    16885 	   promocion 
   TABLE DATA           Z   COPY public.promocion (id, descripcion, tipo, valor, fecha_inicio, fecha_fin) FROM stdin;
    public               postgres    false    254   �n      K          0    16863 	   proveedor 
   TABLE DATA           }   COPY public.proveedor (id, nombre, contacto, telefono, direccion, state_id, codigo_proveedor, rfc, foto, estado) FROM stdin;
    public               postgres    false    250   o      G          0    16833    restriccion_usuario 
   TABLE DATA           Q   COPY public.restriccion_usuario (id, usuario_id, area_id, accion_id) FROM stdin;
    public               postgres    false    246   #o      Y          0    16944    retiro 
   TABLE DATA           U   COPY public.retiro (id, usuario_id, corte_caja_id, fecha, monto, motivo) FROM stdin;
    public               postgres    false    264   @o      @          0    16774    rol 
   TABLE DATA           B   COPY public.rol (id, empresa_id, nombre, descripcion) FROM stdin;
    public               postgres    false    239   ]o      F          0    16813    rol_permiso 
   TABLE DATA           =   COPY public.rol_permiso (id, area_id, accion_id) FROM stdin;
    public               postgres    false    245   zo      :          0    16519    state 
   TABLE DATA           L   COPY public.state (id, tabla_afectada, id_tabla, estado, fecha) FROM stdin;
    public               postgres    false    233   �o      .          0    16396    sub_categoria 
   TABLE DATA           N   COPY public.sub_categoria (id, categoria_id, nombre, descripcion) FROM stdin;
    public               postgres    false    220   �r      �          0    25140    tipo_cliente 
   TABLE DATA           2   COPY public.tipo_cliente (id, nombre) FROM stdin;
    public               postgres    false    312   �r      ^          0    17203    tipo_contenedor 
   TABLE DATA           N   COPY public.tipo_contenedor (id, nombre, color_default, icon_url) FROM stdin;
    public               postgres    false    270   �r      v          0    17329    ubicacion_fisica 
   TABLE DATA           ~   COPY public.ubicacion_fisica (id, negocio_id, nombre, tipo, direccion, ciudad, estado, latitud, longitud, activa) FROM stdin;
    public               postgres    false    294   �r      >          0    16761    usuario 
   TABLE DATA           x   COPY public.usuario (id, empresa_id, nombre_usuario, password_hash, correo, activo, creado_en, empleado_id) FROM stdin;
    public               postgres    false    237   Us      A          0    16782    usuario_rol 
   TABLE DATA           1   COPY public.usuario_rol (id, rol_id) FROM stdin;
    public               postgres    false    240   rs      Q          0    16894    venta 
   TABLE DATA           �   COPY public.venta (id, usuario_id, cliente_id, fecha, total, forma_pago, state_id, comprobante, iva, pagado, estado) FROM stdin;
    public               postgres    false    256   �s      �           0    0    accion_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('public.accion_id_seq', 1, false);
          public               postgres    false    243            �           0    0    area_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('public.area_id_seq', 1, false);
          public               postgres    false    241            �           0    0    atributo_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.atributo_id_seq', 131, true);
          public               postgres    false    221            �           0    0    categoria_id_seq    SEQUENCE SET     >   SELECT pg_catalog.setval('public.categoria_id_seq', 4, true);
          public               postgres    false    217            �           0    0    celda_id_celda_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.celda_id_celda_seq', 1, false);
          public               postgres    false    273            �           0    0    celda_id_seq    SEQUENCE SET     :   SELECT pg_catalog.setval('public.celda_id_seq', 2, true);
          public               postgres    false    319            �           0    0    cliente_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.cliente_id_seq', 1, false);
          public               postgres    false    247            �           0    0    componente_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.componente_id_seq', 77, true);
          public               postgres    false    227            �           0    0 &   configuracion_extra_json_id_config_seq    SEQUENCE SET     U   SELECT pg_catalog.setval('public.configuracion_extra_json_id_config_seq', 1, false);
          public               postgres    false    301            �           0    0    configuracion_extra_json_id_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.configuracion_extra_json_id_seq', 1, true);
          public               postgres    false    318            �           0    0 *   configuracion_negocio_id_configuracion_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.configuracion_negocio_id_configuracion_seq', 1, false);
          public               postgres    false    299            �           0    0    configuracion_negocio_id_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.configuracion_negocio_id_seq', 1, true);
          public               postgres    false    317            �           0    0    contenedor_figura_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.contenedor_figura_id_seq', 1, true);
          public               postgres    false    314            �           0    0 *   contenedor_fisico_id_contenedor_fisico_seq    SEQUENCE SET     Y   SELECT pg_catalog.setval('public.contenedor_fisico_id_contenedor_fisico_seq', 1, false);
          public               postgres    false    271            �           0    0    contenedor_fisico_id_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.contenedor_fisico_id_seq', 2, true);
          public               postgres    false    331            �           0    0    contenedor_instancia_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.contenedor_instancia_id_seq', 1, true);
          public               postgres    false    313            �           0    0    corte_caja_id_seq    SEQUENCE SET     @   SELECT pg_catalog.setval('public.corte_caja_id_seq', 1, false);
          public               postgres    false    315            �           0    0    detalle_atributo_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.detalle_atributo_id_seq', 160, true);
          public               postgres    false    223            �           0    0    detalle_ingreso_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.detalle_ingreso_id_seq', 1, false);
          public               postgres    false    261            �           0    0     detalle_producto_atributo_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.detalle_producto_atributo_id_seq', 1, false);
          public               postgres    false    306            �           0    0    detalle_producto_celda_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.detalle_producto_celda_id_seq', 43, true);
          public               postgres    false    330            �           0    0 1   detalle_producto_contenedor_id_producto_celda_seq    SEQUENCE SET     `   SELECT pg_catalog.setval('public.detalle_producto_contenedor_id_producto_celda_seq', 1, false);
          public               postgres    false    280            �           0    0    detalle_producto_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.detalle_producto_id_seq', 144, true);
          public               postgres    false    225            �           0    0     detalle_producto_producto_id_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.detalle_producto_producto_id_seq', 1, false);
          public               postgres    false    305            �           0    0    detalle_producto_state_id_seq    SEQUENCE SET     L   SELECT pg_catalog.setval('public.detalle_producto_state_id_seq', 1, false);
          public               postgres    false    307            �           0    0    detalle_state_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.detalle_state_id_seq', 1, false);
          public               postgres    false    234            �           0    0    detalle_venta_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.detalle_venta_id_seq', 1, false);
          public               postgres    false    257            �           0    0    empleado_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.empleado_id_seq', 1, true);
          public               postgres    false    326            �           0    0    empleado_idempleado_seq    SEQUENCE SET     F   SELECT pg_catalog.setval('public.empleado_idempleado_seq', 1, false);
          public               postgres    false    267            �           0    0    empresa_id_empresa_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.empresa_id_empresa_seq', 1, false);
          public               postgres    false    297            �           0    0    empresa_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('public.empresa_id_seq', 2, true);
          public               postgres    false    322            �           0    0    etiqueta_producto_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.etiqueta_producto_id_seq', 87, true);
          public               postgres    false    303            �           0    0    ingreso_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.ingreso_id_seq', 1, false);
          public               postgres    false    259            �           0    0    inventario_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.inventario_id_seq', 117, true);
          public               postgres    false    229            �           0    0     licencia_empresa_id_licencia_seq    SEQUENCE SET     O   SELECT pg_catalog.setval('public.licencia_empresa_id_licencia_seq', 1, false);
          public               postgres    false    284            �           0    0    licencia_empresa_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.licencia_empresa_id_seq', 1, true);
          public               postgres    false    325            �           0    0    log_acceso_id_log_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.log_acceso_id_log_seq', 1, false);
          public               postgres    false    288            �           0    0    log_acceso_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.log_acceso_id_seq', 1, true);
          public               postgres    false    316            �           0    0    modulo_empresa_id_modulo_seq    SEQUENCE SET     K   SELECT pg_catalog.setval('public.modulo_empresa_id_modulo_seq', 1, false);
          public               postgres    false    282                        0    0    modulo_empresa_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.modulo_empresa_id_seq', 1, true);
          public               postgres    false    324                       0    0    movimiento_stock_id_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.movimiento_stock_id_seq', 131, true);
          public               postgres    false    335                       0    0    negocio_id_negocio_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.negocio_id_negocio_seq', 1, false);
          public               postgres    false    295                       0    0    negocio_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.negocio_id_seq', 23, true);
          public               postgres    false    323                       0    0    pago_empresa_id_pago_seq    SEQUENCE SET     G   SELECT pg_catalog.setval('public.pago_empresa_id_pago_seq', 1, false);
          public               postgres    false    286                       0    0    pago_empresa_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.pago_empresa_id_seq', 1, true);
          public               postgres    false    321                       0    0    precio_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.precio_id_seq', 126, true);
          public               postgres    false    251                       0    0    presentacion_id_seq    SEQUENCE SET     B   SELECT pg_catalog.setval('public.presentacion_id_seq', 67, true);
          public               postgres    false    334                       0    0    producto_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.producto_id_seq', 2, true);
          public               postgres    false    310            	           0    0 %   producto_multimedia_id_multimedia_seq    SEQUENCE SET     T   SELECT pg_catalog.setval('public.producto_multimedia_id_multimedia_seq', 1, false);
          public               postgres    false    275            
           0    0    producto_multimedia_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.producto_multimedia_id_seq', 35, true);
          public               postgres    false    328                       0    0    producto_ubicacion_id_seq    SEQUENCE SET     I   SELECT pg_catalog.setval('public.producto_ubicacion_id_seq', 139, true);
          public               postgres    false    329                       0    0    producto_visual_tag_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.producto_visual_tag_id_seq', 1, true);
          public               postgres    false    327                       0    0    producto_visual_tag_id_tag_seq    SEQUENCE SET     M   SELECT pg_catalog.setval('public.producto_visual_tag_id_tag_seq', 1, false);
          public               postgres    false    277                       0    0 -   productos_ubicacion_id_producto_ubicacion_seq    SEQUENCE SET     \   SELECT pg_catalog.setval('public.productos_ubicacion_id_producto_ubicacion_seq', 1, false);
          public               postgres    false    291                       0    0    promocion_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.promocion_id_seq', 1, false);
          public               postgres    false    253                       0    0    proveedor_id_seq    SEQUENCE SET     ?   SELECT pg_catalog.setval('public.proveedor_id_seq', 1, false);
          public               postgres    false    249                       0    0    restriccion_usuario_id_seq    SEQUENCE SET     H   SELECT pg_catalog.setval('public.restriccion_usuario_id_seq', 1, true);
          public               postgres    false    320                       0    0    retiro_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('public.retiro_id_seq', 1, false);
          public               postgres    false    263                       0    0 
   rol_id_seq    SEQUENCE SET     9   SELECT pg_catalog.setval('public.rol_id_seq', 1, false);
          public               postgres    false    238                       0    0    state_id_seq    SEQUENCE SET     <   SELECT pg_catalog.setval('public.state_id_seq', 143, true);
          public               postgres    false    232                       0    0    sub_categoria_id_seq    SEQUENCE SET     C   SELECT pg_catalog.setval('public.sub_categoria_id_seq', 1, false);
          public               postgres    false    219                       0    0    tipo_cliente_id_seq    SEQUENCE SET     A   SELECT pg_catalog.setval('public.tipo_cliente_id_seq', 3, true);
          public               postgres    false    311                       0    0    tipo_contenedor_id_seq    SEQUENCE SET     D   SELECT pg_catalog.setval('public.tipo_contenedor_id_seq', 1, true);
          public               postgres    false    333                       0    0    tipo_contenedor_id_tipo_seq    SEQUENCE SET     J   SELECT pg_catalog.setval('public.tipo_contenedor_id_tipo_seq', 1, false);
          public               postgres    false    269                       0    0    ubicacion_fisica_id_seq    SEQUENCE SET     E   SELECT pg_catalog.setval('public.ubicacion_fisica_id_seq', 9, true);
          public               postgres    false    332                       0    0 !   ubicacion_fisica_id_ubicacion_seq    SEQUENCE SET     P   SELECT pg_catalog.setval('public.ubicacion_fisica_id_ubicacion_seq', 1, false);
          public               postgres    false    293                       0    0    usuario_id_seq    SEQUENCE SET     =   SELECT pg_catalog.setval('public.usuario_id_seq', 1, false);
          public               postgres    false    236                       0    0    venta_id_seq    SEQUENCE SET     ;   SELECT pg_catalog.setval('public.venta_id_seq', 1, false);
          public               postgres    false    255                       2606    16812    accion accion_pkey 
   CONSTRAINT     P   ALTER TABLE ONLY public.accion
    ADD CONSTRAINT accion_pkey PRIMARY KEY (id);
 <   ALTER TABLE ONLY public.accion DROP CONSTRAINT accion_pkey;
       public                 postgres    false    244                       2606    16803    area area_pkey 
   CONSTRAINT     L   ALTER TABLE ONLY public.area
    ADD CONSTRAINT area_pkey PRIMARY KEY (id);
 8   ALTER TABLE ONLY public.area DROP CONSTRAINT area_pkey;
       public                 postgres    false    242            �           2606    16413    atributo atributo_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.atributo
    ADD CONSTRAINT atributo_pkey PRIMARY KEY (id);
 @   ALTER TABLE ONLY public.atributo DROP CONSTRAINT atributo_pkey;
       public                 postgres    false    222            �           2606    16394    categoria categoria_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY public.categoria
    ADD CONSTRAINT categoria_pkey PRIMARY KEY (id);
 B   ALTER TABLE ONLY public.categoria DROP CONSTRAINT categoria_pkey;
       public                 postgres    false    218            '           2606    17225    celda celda_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.celda
    ADD CONSTRAINT celda_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.celda DROP CONSTRAINT celda_pkey;
       public                 postgres    false    274            
           2606    16861    cliente cliente_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.cliente
    ADD CONSTRAINT cliente_pkey PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.cliente DROP CONSTRAINT cliente_pkey;
       public                 postgres    false    248            �           2606    16488    componente componente_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.componente
    ADD CONSTRAINT componente_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.componente DROP CONSTRAINT componente_pkey;
       public                 postgres    false    228            E           2606    17388 6   configuracion_extra_json configuracion_extra_json_pkey 
   CONSTRAINT     t   ALTER TABLE ONLY public.configuracion_extra_json
    ADD CONSTRAINT configuracion_extra_json_pkey PRIMARY KEY (id);
 `   ALTER TABLE ONLY public.configuracion_extra_json DROP CONSTRAINT configuracion_extra_json_pkey;
       public                 postgres    false    302            C           2606    17378 0   configuracion_negocio configuracion_negocio_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.configuracion_negocio
    ADD CONSTRAINT configuracion_negocio_pkey PRIMARY KEY (id);
 Z   ALTER TABLE ONLY public.configuracion_negocio DROP CONSTRAINT configuracion_negocio_pkey;
       public                 postgres    false    300            -           2606    25375 (   contenedor_figura contenedor_figura_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.contenedor_figura
    ADD CONSTRAINT contenedor_figura_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.contenedor_figura DROP CONSTRAINT contenedor_figura_pkey;
       public                 postgres    false    279            %           2606    17217 (   contenedor_fisico contenedor_fisico_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.contenedor_fisico
    ADD CONSTRAINT contenedor_fisico_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.contenedor_fisico DROP CONSTRAINT contenedor_fisico_pkey;
       public                 postgres    false    272            K           2606    25366 .   contenedor_instancia contenedor_instancia_pkey 
   CONSTRAINT     l   ALTER TABLE ONLY public.contenedor_instancia
    ADD CONSTRAINT contenedor_instancia_pkey PRIMARY KEY (id);
 X   ALTER TABLE ONLY public.contenedor_instancia DROP CONSTRAINT contenedor_instancia_pkey;
       public                 postgres    false    309                       2606    25382    corte_caja corte_caja_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.corte_caja
    ADD CONSTRAINT corte_caja_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.corte_caja DROP CONSTRAINT corte_caja_pkey;
       public                 postgres    false    265            �           2606    16420 &   detalle_atributo detalle_atributo_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.detalle_atributo
    ADD CONSTRAINT detalle_atributo_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.detalle_atributo DROP CONSTRAINT detalle_atributo_pkey;
       public                 postgres    false    224                       2606    16932 $   detalle_ingreso detalle_ingreso_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.detalle_ingreso
    ADD CONSTRAINT detalle_ingreso_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.detalle_ingreso DROP CONSTRAINT detalle_ingreso_pkey;
       public                 postgres    false    262            /           2606    17264 7   detalle_producto_celda detalle_producto_contenedor_pkey 
   CONSTRAINT     u   ALTER TABLE ONLY public.detalle_producto_celda
    ADD CONSTRAINT detalle_producto_contenedor_pkey PRIMARY KEY (id);
 a   ALTER TABLE ONLY public.detalle_producto_celda DROP CONSTRAINT detalle_producto_contenedor_pkey;
       public                 postgres    false    281            �           2606    16442 &   detalle_producto detalle_producto_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.detalle_producto
    ADD CONSTRAINT detalle_producto_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.detalle_producto DROP CONSTRAINT detalle_producto_pkey;
       public                 postgres    false    226            �           2606    16535     detalle_state detalle_state_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.detalle_state
    ADD CONSTRAINT detalle_state_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.detalle_state DROP CONSTRAINT detalle_state_pkey;
       public                 postgres    false    235                       2606    16907     detalle_venta detalle_venta_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.detalle_venta
    ADD CONSTRAINT detalle_venta_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.detalle_venta DROP CONSTRAINT detalle_venta_pkey;
       public                 postgres    false    258            !           2606    17201    empleado empleado_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.empleado
    ADD CONSTRAINT empleado_pkey PRIMARY KEY (id);
 @   ALTER TABLE ONLY public.empleado DROP CONSTRAINT empleado_pkey;
       public                 postgres    false    268            A           2606    17357    empresa empresa_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.empresa
    ADD CONSTRAINT empresa_pkey PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.empresa DROP CONSTRAINT empresa_pkey;
       public                 postgres    false    298            G           2606    17396 (   etiqueta_producto etiqueta_producto_pkey 
   CONSTRAINT     f   ALTER TABLE ONLY public.etiqueta_producto
    ADD CONSTRAINT etiqueta_producto_pkey PRIMARY KEY (id);
 R   ALTER TABLE ONLY public.etiqueta_producto DROP CONSTRAINT etiqueta_producto_pkey;
       public                 postgres    false    304                       2606    16925    ingreso ingreso_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.ingreso
    ADD CONSTRAINT ingreso_pkey PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.ingreso DROP CONSTRAINT ingreso_pkey;
       public                 postgres    false    260            �           2606    16506    inventario inventario_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.inventario
    ADD CONSTRAINT inventario_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.inventario DROP CONSTRAINT inventario_pkey;
       public                 postgres    false    230            3           2606    17292 &   licencia_empresa licencia_empresa_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.licencia_empresa
    ADD CONSTRAINT licencia_empresa_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.licencia_empresa DROP CONSTRAINT licencia_empresa_pkey;
       public                 postgres    false    285            7           2606    17309    log_acceso log_acceso_pkey 
   CONSTRAINT     X   ALTER TABLE ONLY public.log_acceso
    ADD CONSTRAINT log_acceso_pkey PRIMARY KEY (id);
 D   ALTER TABLE ONLY public.log_acceso DROP CONSTRAINT log_acceso_pkey;
       public                 postgres    false    289            1           2606    17284 "   modulo_empresa modulo_empresa_pkey 
   CONSTRAINT     `   ALTER TABLE ONLY public.modulo_empresa
    ADD CONSTRAINT modulo_empresa_pkey PRIMARY KEY (id);
 L   ALTER TABLE ONLY public.modulo_empresa DROP CONSTRAINT modulo_empresa_pkey;
       public                 postgres    false    283            O           2606    25737 &   movimiento_stock movimiento_stock_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.movimiento_stock
    ADD CONSTRAINT movimiento_stock_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.movimiento_stock DROP CONSTRAINT movimiento_stock_pkey;
       public                 postgres    false    336            ?           2606    17347    negocio negocio_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.negocio
    ADD CONSTRAINT negocio_pkey PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.negocio DROP CONSTRAINT negocio_pkey;
       public                 postgres    false    296            5           2606    17301    pago_empresa pago_empresa_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.pago_empresa
    ADD CONSTRAINT pago_empresa_pkey PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.pago_empresa DROP CONSTRAINT pago_empresa_pkey;
       public                 postgres    false    287                       2606    16878    precio precio_pkey 
   CONSTRAINT     P   ALTER TABLE ONLY public.precio
    ADD CONSTRAINT precio_pkey PRIMARY KEY (id);
 <   ALTER TABLE ONLY public.precio DROP CONSTRAINT precio_pkey;
       public                 postgres    false    252            I           2606    24589    presentacion presentacion_pk 
   CONSTRAINT     Z   ALTER TABLE ONLY public.presentacion
    ADD CONSTRAINT presentacion_pk PRIMARY KEY (id);
 F   ALTER TABLE ONLY public.presentacion DROP CONSTRAINT presentacion_pk;
       public                 postgres    false    308            )           2606    17236 ,   producto_multimedia producto_multimedia_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.producto_multimedia
    ADD CONSTRAINT producto_multimedia_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.producto_multimedia DROP CONSTRAINT producto_multimedia_pkey;
       public                 postgres    false    276            9           2606    24942    producto producto_pkey 
   CONSTRAINT     T   ALTER TABLE ONLY public.producto
    ADD CONSTRAINT producto_pkey PRIMARY KEY (id);
 @   ALTER TABLE ONLY public.producto DROP CONSTRAINT producto_pkey;
       public                 postgres    false    290            +           2606    17244 ,   producto_visual_tag producto_visual_tag_pkey 
   CONSTRAINT     j   ALTER TABLE ONLY public.producto_visual_tag
    ADD CONSTRAINT producto_visual_tag_pkey PRIMARY KEY (id);
 V   ALTER TABLE ONLY public.producto_visual_tag DROP CONSTRAINT producto_visual_tag_pkey;
       public                 postgres    false    278            ;           2606    17327 +   producto_ubicacion productos_ubicacion_pkey 
   CONSTRAINT     i   ALTER TABLE ONLY public.producto_ubicacion
    ADD CONSTRAINT productos_ubicacion_pkey PRIMARY KEY (id);
 U   ALTER TABLE ONLY public.producto_ubicacion DROP CONSTRAINT productos_ubicacion_pkey;
       public                 postgres    false    292                       2606    16892    promocion promocion_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY public.promocion
    ADD CONSTRAINT promocion_pkey PRIMARY KEY (id);
 B   ALTER TABLE ONLY public.promocion DROP CONSTRAINT promocion_pkey;
       public                 postgres    false    254                       2606    16870    proveedor proveedor_pkey 
   CONSTRAINT     V   ALTER TABLE ONLY public.proveedor
    ADD CONSTRAINT proveedor_pkey PRIMARY KEY (id);
 B   ALTER TABLE ONLY public.proveedor DROP CONSTRAINT proveedor_pkey;
       public                 postgres    false    250                       2606    16837 ,   restriccion_usuario restriccion_usuario_pkey 
   CONSTRAINT        ALTER TABLE ONLY public.restriccion_usuario
    ADD CONSTRAINT restriccion_usuario_pkey PRIMARY KEY (id, usuario_id, area_id);
 V   ALTER TABLE ONLY public.restriccion_usuario DROP CONSTRAINT restriccion_usuario_pkey;
       public                 postgres    false    246    246    246                       2606    16952    retiro retiro_pkey 
   CONSTRAINT     P   ALTER TABLE ONLY public.retiro
    ADD CONSTRAINT retiro_pkey PRIMARY KEY (id);
 <   ALTER TABLE ONLY public.retiro DROP CONSTRAINT retiro_pkey;
       public                 postgres    false    264                       2606    16817    rol_permiso rol_permiso_pkey 
   CONSTRAINT     n   ALTER TABLE ONLY public.rol_permiso
    ADD CONSTRAINT rol_permiso_pkey PRIMARY KEY (id, area_id, accion_id);
 F   ALTER TABLE ONLY public.rol_permiso DROP CONSTRAINT rol_permiso_pkey;
       public                 postgres    false    245    245    245            �           2606    16781    rol rol_pkey 
   CONSTRAINT     J   ALTER TABLE ONLY public.rol
    ADD CONSTRAINT rol_pkey PRIMARY KEY (id);
 6   ALTER TABLE ONLY public.rol DROP CONSTRAINT rol_pkey;
       public                 postgres    false    239            �           2606    16525    state state_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.state
    ADD CONSTRAINT state_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.state DROP CONSTRAINT state_pkey;
       public                 postgres    false    233            �           2606    16401     sub_categoria sub_categoria_pkey 
   CONSTRAINT     ^   ALTER TABLE ONLY public.sub_categoria
    ADD CONSTRAINT sub_categoria_pkey PRIMARY KEY (id);
 J   ALTER TABLE ONLY public.sub_categoria DROP CONSTRAINT sub_categoria_pkey;
       public                 postgres    false    220            M           2606    25147    tipo_cliente tipo_cliente_pkey 
   CONSTRAINT     \   ALTER TABLE ONLY public.tipo_cliente
    ADD CONSTRAINT tipo_cliente_pkey PRIMARY KEY (id);
 H   ALTER TABLE ONLY public.tipo_cliente DROP CONSTRAINT tipo_cliente_pkey;
       public                 postgres    false    312            #           2606    17208 $   tipo_contenedor tipo_contenedor_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.tipo_contenedor
    ADD CONSTRAINT tipo_contenedor_pkey PRIMARY KEY (id);
 N   ALTER TABLE ONLY public.tipo_contenedor DROP CONSTRAINT tipo_contenedor_pkey;
       public                 postgres    false    270            =           2606    17337 &   ubicacion_fisica ubicacion_fisica_pkey 
   CONSTRAINT     d   ALTER TABLE ONLY public.ubicacion_fisica
    ADD CONSTRAINT ubicacion_fisica_pkey PRIMARY KEY (id);
 P   ALTER TABLE ONLY public.ubicacion_fisica DROP CONSTRAINT ubicacion_fisica_pkey;
       public                 postgres    false    294            �           2606    16772 "   usuario usuario_nombre_usuario_key 
   CONSTRAINT     g   ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_nombre_usuario_key UNIQUE (nombre_usuario);
 L   ALTER TABLE ONLY public.usuario DROP CONSTRAINT usuario_nombre_usuario_key;
       public                 postgres    false    237            �           2606    16770    usuario usuario_pkey 
   CONSTRAINT     R   ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT usuario_pkey PRIMARY KEY (id);
 >   ALTER TABLE ONLY public.usuario DROP CONSTRAINT usuario_pkey;
       public                 postgres    false    237                        2606    16786    usuario_rol usuario_rol_pkey 
   CONSTRAINT     b   ALTER TABLE ONLY public.usuario_rol
    ADD CONSTRAINT usuario_rol_pkey PRIMARY KEY (id, rol_id);
 F   ALTER TABLE ONLY public.usuario_rol DROP CONSTRAINT usuario_rol_pkey;
       public                 postgres    false    240    240                       2606    16900    venta venta_pkey 
   CONSTRAINT     N   ALTER TABLE ONLY public.venta
    ADD CONSTRAINT venta_pkey PRIMARY KEY (id);
 :   ALTER TABLE ONLY public.venta DROP CONSTRAINT venta_pkey;
       public                 postgres    false    256            �           1259    16513    idx_componente_padre    INDEX     `   CREATE INDEX idx_componente_padre ON public.componente USING btree (detalle_producto_padre_id);
 (   DROP INDEX public.idx_componente_padre;
       public                 postgres    false    228                       1259    16962    idx_detalle_ingreso_producto    INDEX     g   CREATE INDEX idx_detalle_ingreso_producto ON public.detalle_ingreso USING btree (detalle_producto_id);
 0   DROP INDEX public.idx_detalle_ingreso_producto;
       public                 postgres    false    262                       1259    16961    idx_detalle_venta_producto    INDEX     c   CREATE INDEX idx_detalle_venta_producto ON public.detalle_venta USING btree (detalle_producto_id);
 .   DROP INDEX public.idx_detalle_venta_producto;
       public                 postgres    false    258            �           1259    16512    idx_inv_detalle_producto    INDEX     ^   CREATE INDEX idx_inv_detalle_producto ON public.inventario USING btree (detalle_producto_id);
 ,   DROP INDEX public.idx_inv_detalle_producto;
       public                 postgres    false    230                       1259    16960    idx_precio_lookup    INDEX     q   CREATE INDEX idx_precio_lookup ON public.precio USING btree (ubicacion_fisica_id, detalle_producto_id, vigente);
 %   DROP INDEX public.idx_precio_lookup;
       public                 postgres    false    252    252    252            �           2620    16971    inventario trg_actualizado_en    TRIGGER     �   CREATE TRIGGER trg_actualizado_en BEFORE UPDATE ON public.inventario FOR EACH ROW EXECUTE FUNCTION public.actualizar_timestamp_inventario();
 6   DROP TRIGGER trg_actualizado_en ON public.inventario;
       public               postgres    false    230    337            U           2606    16494 +   componente componente_id_producto_hijo_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.componente
    ADD CONSTRAINT componente_id_producto_hijo_fkey FOREIGN KEY (detalle_producto_hijo_id) REFERENCES public.detalle_producto(id);
 U   ALTER TABLE ONLY public.componente DROP CONSTRAINT componente_id_producto_hijo_fkey;
       public               postgres    false    5102    226    228            V           2606    16489 ,   componente componente_id_producto_padre_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.componente
    ADD CONSTRAINT componente_id_producto_padre_fkey FOREIGN KEY (detalle_producto_padre_id) REFERENCES public.detalle_producto(id);
 V   ALTER TABLE ONLY public.componente DROP CONSTRAINT componente_id_producto_padre_fkey;
       public               postgres    false    226    228    5102            Q           2606    16421 2   detalle_atributo detalle_atributo_id_atributo_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.detalle_atributo
    ADD CONSTRAINT detalle_atributo_id_atributo_fkey FOREIGN KEY (id_atributo) REFERENCES public.atributo(id);
 \   ALTER TABLE ONLY public.detalle_atributo DROP CONSTRAINT detalle_atributo_id_atributo_fkey;
       public               postgres    false    224    222    5098            u           2606    16938 8   detalle_ingreso detalle_ingreso_id_detalle_producto_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.detalle_ingreso
    ADD CONSTRAINT detalle_ingreso_id_detalle_producto_fkey FOREIGN KEY (detalle_producto_id) REFERENCES public.detalle_producto(id);
 b   ALTER TABLE ONLY public.detalle_ingreso DROP CONSTRAINT detalle_ingreso_id_detalle_producto_fkey;
       public               postgres    false    262    5102    226            v           2606    16933 /   detalle_ingreso detalle_ingreso_id_ingreso_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.detalle_ingreso
    ADD CONSTRAINT detalle_ingreso_id_ingreso_fkey FOREIGN KEY (ingreso_id) REFERENCES public.ingreso(id);
 Y   ALTER TABLE ONLY public.detalle_ingreso DROP CONSTRAINT detalle_ingreso_id_ingreso_fkey;
       public               postgres    false    5144    260    262            ~           2606    17270 @   detalle_producto_celda detalle_producto_contenedor_id_celda_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.detalle_producto_celda
    ADD CONSTRAINT detalle_producto_contenedor_id_celda_fkey FOREIGN KEY (celda_id) REFERENCES public.celda(id);
 j   ALTER TABLE ONLY public.detalle_producto_celda DROP CONSTRAINT detalle_producto_contenedor_id_celda_fkey;
       public               postgres    false    5159    274    281                       2606    17265 L   detalle_producto_celda detalle_producto_contenedor_id_contenedor_fisico_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.detalle_producto_celda
    ADD CONSTRAINT detalle_producto_contenedor_id_contenedor_fisico_fkey FOREIGN KEY (contenedor_fisico_id) REFERENCES public.contenedor_fisico(id);
 v   ALTER TABLE ONLY public.detalle_producto_celda DROP CONSTRAINT detalle_producto_contenedor_id_contenedor_fisico_fkey;
       public               postgres    false    281    272    5157            [           2606    16536 )   detalle_state detalle_state_id_state_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.detalle_state
    ADD CONSTRAINT detalle_state_id_state_fkey FOREIGN KEY (state_id) REFERENCES public.state(id);
 S   ALTER TABLE ONLY public.detalle_state DROP CONSTRAINT detalle_state_id_state_fkey;
       public               postgres    false    235    5110    233            p           2606    16913 4   detalle_venta detalle_venta_id_detalle_producto_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.detalle_venta
    ADD CONSTRAINT detalle_venta_id_detalle_producto_fkey FOREIGN KEY (detalle_producto_id) REFERENCES public.detalle_producto(id);
 ^   ALTER TABLE ONLY public.detalle_venta DROP CONSTRAINT detalle_venta_id_detalle_producto_fkey;
       public               postgres    false    258    5102    226            q           2606    16908 )   detalle_venta detalle_venta_id_venta_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.detalle_venta
    ADD CONSTRAINT detalle_venta_id_venta_fkey FOREIGN KEY (venta_id) REFERENCES public.venta(id);
 S   ALTER TABLE ONLY public.detalle_venta DROP CONSTRAINT detalle_venta_id_venta_fkey;
       public               postgres    false    5139    256    258            {           2606    25547    celda fk_celda_contendor_fisico    FK CONSTRAINT     �   ALTER TABLE ONLY public.celda
    ADD CONSTRAINT fk_celda_contendor_fisico FOREIGN KEY (contenedor_fisico_id) REFERENCES public.contenedor_fisico(id);
 I   ALTER TABLE ONLY public.celda DROP CONSTRAINT fk_celda_contendor_fisico;
       public               postgres    false    5157    274    272            h           2606    25522    cliente fk_cliente_tipo_cliente    FK CONSTRAINT     �   ALTER TABLE ONLY public.cliente
    ADD CONSTRAINT fk_cliente_tipo_cliente FOREIGN KEY (tipo_cliente_id) REFERENCES public.tipo_cliente(id);
 I   ALTER TABLE ONLY public.cliente DROP CONSTRAINT fk_cliente_tipo_cliente;
       public               postgres    false    5197    312    248            �           2606    24911 B   configuracion_extra_json fk_configuracion_extra_json_configuracion    FK CONSTRAINT     �   ALTER TABLE ONLY public.configuracion_extra_json
    ADD CONSTRAINT fk_configuracion_extra_json_configuracion FOREIGN KEY (configuracion_negocio_id) REFERENCES public.configuracion_negocio(id);
 l   ALTER TABLE ONLY public.configuracion_extra_json DROP CONSTRAINT fk_configuracion_extra_json_configuracion;
       public               postgres    false    300    302    5187            w           2606    25435 8   contenedor_fisico fk_contenedor_fisico_contenedor_figura    FK CONSTRAINT     �   ALTER TABLE ONLY public.contenedor_fisico
    ADD CONSTRAINT fk_contenedor_fisico_contenedor_figura FOREIGN KEY (contenedor_figura_id) REFERENCES public.contenedor_figura(id);
 b   ALTER TABLE ONLY public.contenedor_fisico DROP CONSTRAINT fk_contenedor_fisico_contenedor_figura;
       public               postgres    false    279    272    5165            x           2606    25425 ;   contenedor_fisico fk_contenedor_fisico_contenedor_instancia    FK CONSTRAINT     �   ALTER TABLE ONLY public.contenedor_fisico
    ADD CONSTRAINT fk_contenedor_fisico_contenedor_instancia FOREIGN KEY (contenedor_instancia_id) REFERENCES public.contenedor_instancia(id);
 e   ALTER TABLE ONLY public.contenedor_fisico DROP CONSTRAINT fk_contenedor_fisico_contenedor_instancia;
       public               postgres    false    272    5195    309            y           2606    25353 6   contenedor_fisico fk_contenedor_fisico_tipo_contenedor    FK CONSTRAINT     �   ALTER TABLE ONLY public.contenedor_fisico
    ADD CONSTRAINT fk_contenedor_fisico_tipo_contenedor FOREIGN KEY (tipo_contenedor_id) REFERENCES public.tipo_contenedor(id);
 `   ALTER TABLE ONLY public.contenedor_fisico DROP CONSTRAINT fk_contenedor_fisico_tipo_contenedor;
       public               postgres    false    272    5155    270            z           2606    25430 7   contenedor_fisico fk_contenedor_fisico_ubicacion_fisica    FK CONSTRAINT     �   ALTER TABLE ONLY public.contenedor_fisico
    ADD CONSTRAINT fk_contenedor_fisico_ubicacion_fisica FOREIGN KEY (ubicacion_fisica_id) REFERENCES public.ubicacion_fisica(id);
 a   ALTER TABLE ONLY public.contenedor_fisico DROP CONSTRAINT fk_contenedor_fisico_ubicacion_fisica;
       public               postgres    false    272    294    5181            �           2606    25542 4   contenedor_instancia fk_contenedor_instancia_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.contenedor_instancia
    ADD CONSTRAINT fk_contenedor_instancia_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 ^   ALTER TABLE ONLY public.contenedor_instancia DROP CONSTRAINT fk_contenedor_instancia_empresa;
       public               postgres    false    298    309    5185            �           2606    25763    movimiento_stock fk_destino    FK CONSTRAINT     �   ALTER TABLE ONLY public.movimiento_stock
    ADD CONSTRAINT fk_destino FOREIGN KEY (ubicacion_destino_id) REFERENCES public.ubicacion_fisica(id);
 E   ALTER TABLE ONLY public.movimiento_stock DROP CONSTRAINT fk_destino;
       public               postgres    false    294    5181    336            �           2606    25748 $   movimiento_stock fk_detalle_producto    FK CONSTRAINT     �   ALTER TABLE ONLY public.movimiento_stock
    ADD CONSTRAINT fk_detalle_producto FOREIGN KEY (detalle_producto_id) REFERENCES public.detalle_producto(id);
 N   ALTER TABLE ONLY public.movimiento_stock DROP CONSTRAINT fk_detalle_producto;
       public               postgres    false    226    336    5102            R           2606    24974 -   detalle_producto fk_detalle_producto_atributo    FK CONSTRAINT     �   ALTER TABLE ONLY public.detalle_producto
    ADD CONSTRAINT fk_detalle_producto_atributo FOREIGN KEY (atributo_id) REFERENCES public.atributo(id);
 W   ALTER TABLE ONLY public.detalle_producto DROP CONSTRAINT fk_detalle_producto_atributo;
       public               postgres    false    226    5098    222            �           2606    25233 A   detalle_producto_celda fk_detalle_producto_celda_detalle_producto    FK CONSTRAINT     �   ALTER TABLE ONLY public.detalle_producto_celda
    ADD CONSTRAINT fk_detalle_producto_celda_detalle_producto FOREIGN KEY (detalle_producto_id) REFERENCES public.detalle_producto(id);
 k   ALTER TABLE ONLY public.detalle_producto_celda DROP CONSTRAINT fk_detalle_producto_celda_detalle_producto;
       public               postgres    false    281    5102    226            �           2606    25218 ;   detalle_producto_celda fk_detalle_producto_celda_inventario    FK CONSTRAINT     �   ALTER TABLE ONLY public.detalle_producto_celda
    ADD CONSTRAINT fk_detalle_producto_celda_inventario FOREIGN KEY (inventario_id) REFERENCES public.inventario(id);
 e   ALTER TABLE ONLY public.detalle_producto_celda DROP CONSTRAINT fk_detalle_producto_celda_inventario;
       public               postgres    false    230    5108    281            S           2606    24979 +   detalle_producto fk_detalle_producto_estado    FK CONSTRAINT     �   ALTER TABLE ONLY public.detalle_producto
    ADD CONSTRAINT fk_detalle_producto_estado FOREIGN KEY (state_id) REFERENCES public.state(id);
 U   ALTER TABLE ONLY public.detalle_producto DROP CONSTRAINT fk_detalle_producto_estado;
       public               postgres    false    226    5110    233            T           2606    24949 -   detalle_producto fk_detalle_producto_producto    FK CONSTRAINT     �   ALTER TABLE ONLY public.detalle_producto
    ADD CONSTRAINT fk_detalle_producto_producto FOREIGN KEY (producto_id) REFERENCES public.producto(id);
 W   ALTER TABLE ONLY public.detalle_producto DROP CONSTRAINT fk_detalle_producto_producto;
       public               postgres    false    226    290    5177            r           2606    25490 '   detalle_venta fk_detalle_venta_empleado    FK CONSTRAINT     �   ALTER TABLE ONLY public.detalle_venta
    ADD CONSTRAINT fk_detalle_venta_empleado FOREIGN KEY (empleado_id) REFERENCES public.empleado(id);
 Q   ALTER TABLE ONLY public.detalle_venta DROP CONSTRAINT fk_detalle_venta_empleado;
       public               postgres    false    5153    258    268            �           2606    25738    movimiento_stock fk_empresa    FK CONSTRAINT        ALTER TABLE ONLY public.movimiento_stock
    ADD CONSTRAINT fk_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 E   ALTER TABLE ONLY public.movimiento_stock DROP CONSTRAINT fk_empresa;
       public               postgres    false    5185    298    336            �           2606    25059 .   etiqueta_producto fk_etiqueta_detalle_producto    FK CONSTRAINT     �   ALTER TABLE ONLY public.etiqueta_producto
    ADD CONSTRAINT fk_etiqueta_detalle_producto FOREIGN KEY (detalle_producto_id) REFERENCES public.detalle_producto(id);
 X   ALTER TABLE ONLY public.etiqueta_producto DROP CONSTRAINT fk_etiqueta_detalle_producto;
       public               postgres    false    304    226    5102            �           2606    25064 *   etiqueta_producto fk_etiqueta_presentacion    FK CONSTRAINT     �   ALTER TABLE ONLY public.etiqueta_producto
    ADD CONSTRAINT fk_etiqueta_presentacion FOREIGN KEY (presentacion_id) REFERENCES public.presentacion(id);
 T   ALTER TABLE ONLY public.etiqueta_producto DROP CONSTRAINT fk_etiqueta_presentacion;
       public               postgres    false    308    304    5193            s           2606    24916    ingreso fk_ingreso_proveedor    FK CONSTRAINT     �   ALTER TABLE ONLY public.ingreso
    ADD CONSTRAINT fk_ingreso_proveedor FOREIGN KEY (proveedor_id) REFERENCES public.proveedor(id);
 F   ALTER TABLE ONLY public.ingreso DROP CONSTRAINT fk_ingreso_proveedor;
       public               postgres    false    260    5132    250            t           2606    25537    ingreso fk_ingreso_usuario    FK CONSTRAINT     ~   ALTER TABLE ONLY public.ingreso
    ADD CONSTRAINT fk_ingreso_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 D   ALTER TABLE ONLY public.ingreso DROP CONSTRAINT fk_ingreso_usuario;
       public               postgres    false    237    5116    260            W           2606    25203 "   inventario fk_inventario_proveedor    FK CONSTRAINT     �   ALTER TABLE ONLY public.inventario
    ADD CONSTRAINT fk_inventario_proveedor FOREIGN KEY (proveedor_id) REFERENCES public.proveedor(id);
 L   ALTER TABLE ONLY public.inventario DROP CONSTRAINT fk_inventario_proveedor;
       public               postgres    false    250    230    5132            X           2606    25208    inventario fk_inventario_state    FK CONSTRAINT     ~   ALTER TABLE ONLY public.inventario
    ADD CONSTRAINT fk_inventario_state FOREIGN KEY (state_id) REFERENCES public.state(id);
 H   ALTER TABLE ONLY public.inventario DROP CONSTRAINT fk_inventario_state;
       public               postgres    false    233    230    5110            Y           2606    25213 )   inventario fk_inventario_ubicacion_fisica    FK CONSTRAINT     �   ALTER TABLE ONLY public.inventario
    ADD CONSTRAINT fk_inventario_ubicacion_fisica FOREIGN KEY (ubicacion_fisica_id) REFERENCES public.ubicacion_fisica(id);
 S   ALTER TABLE ONLY public.inventario DROP CONSTRAINT fk_inventario_ubicacion_fisica;
       public               postgres    false    5181    230    294            �           2606    25338 $   licencia_empresa fk_licencia_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.licencia_empresa
    ADD CONSTRAINT fk_licencia_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 N   ALTER TABLE ONLY public.licencia_empresa DROP CONSTRAINT fk_licencia_empresa;
       public               postgres    false    285    5185    298            �           2606    25333     log_acceso fk_log_acceso_usuario    FK CONSTRAINT     �   ALTER TABLE ONLY public.log_acceso
    ADD CONSTRAINT fk_log_acceso_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 J   ALTER TABLE ONLY public.log_acceso DROP CONSTRAINT fk_log_acceso_usuario;
       public               postgres    false    289    5116    237            �           2606    25343     modulo_empresa fk_modulo_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.modulo_empresa
    ADD CONSTRAINT fk_modulo_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 J   ALTER TABLE ONLY public.modulo_empresa DROP CONSTRAINT fk_modulo_empresa;
       public               postgres    false    283    5185    298            �           2606    25758    movimiento_stock fk_origen    FK CONSTRAINT     �   ALTER TABLE ONLY public.movimiento_stock
    ADD CONSTRAINT fk_origen FOREIGN KEY (ubicacion_origen_id) REFERENCES public.ubicacion_fisica(id);
 D   ALTER TABLE ONLY public.movimiento_stock DROP CONSTRAINT fk_origen;
       public               postgres    false    294    336    5181            �           2606    25348    pago_empresa fk_pago_empresa    FK CONSTRAINT     �   ALTER TABLE ONLY public.pago_empresa
    ADD CONSTRAINT fk_pago_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 F   ALTER TABLE ONLY public.pago_empresa DROP CONSTRAINT fk_pago_empresa;
       public               postgres    false    287    5185    298            i           2606    25163    precio fk_precio_cliente    FK CONSTRAINT     |   ALTER TABLE ONLY public.precio
    ADD CONSTRAINT fk_precio_cliente FOREIGN KEY (cliente_id) REFERENCES public.cliente(id);
 B   ALTER TABLE ONLY public.precio DROP CONSTRAINT fk_precio_cliente;
       public               postgres    false    252    5130    248            j           2606    25148 !   precio fk_precio_detalle_producto    FK CONSTRAINT     �   ALTER TABLE ONLY public.precio
    ADD CONSTRAINT fk_precio_detalle_producto FOREIGN KEY (detalle_producto_id) REFERENCES public.detalle_producto(id);
 K   ALTER TABLE ONLY public.precio DROP CONSTRAINT fk_precio_detalle_producto;
       public               postgres    false    5102    252    226            k           2606    25158    precio fk_precio_presentacion    FK CONSTRAINT     �   ALTER TABLE ONLY public.precio
    ADD CONSTRAINT fk_precio_presentacion FOREIGN KEY (presentacion_id) REFERENCES public.presentacion(id);
 G   ALTER TABLE ONLY public.precio DROP CONSTRAINT fk_precio_presentacion;
       public               postgres    false    308    5193    252            l           2606    25168    precio fk_precio_tipo_cliente    FK CONSTRAINT     �   ALTER TABLE ONLY public.precio
    ADD CONSTRAINT fk_precio_tipo_cliente FOREIGN KEY (tipo_cliente_id) REFERENCES public.tipo_cliente(id);
 G   ALTER TABLE ONLY public.precio DROP CONSTRAINT fk_precio_tipo_cliente;
       public               postgres    false    5197    312    252            m           2606    25153    precio fk_precio_ubicacion    FK CONSTRAINT     �   ALTER TABLE ONLY public.precio
    ADD CONSTRAINT fk_precio_ubicacion FOREIGN KEY (ubicacion_fisica_id) REFERENCES public.ubicacion_fisica(id);
 D   ALTER TABLE ONLY public.precio DROP CONSTRAINT fk_precio_ubicacion;
       public               postgres    false    252    294    5181            �           2606    24984 -   presentacion fk_presentacion_detalle_producto    FK CONSTRAINT     �   ALTER TABLE ONLY public.presentacion
    ADD CONSTRAINT fk_presentacion_detalle_producto FOREIGN KEY (detalle_producto_id) REFERENCES public.detalle_producto(id);
 W   ALTER TABLE ONLY public.presentacion DROP CONSTRAINT fk_presentacion_detalle_producto;
       public               postgres    false    226    5102    308            �           2606    25743    movimiento_stock fk_producto    FK CONSTRAINT     �   ALTER TABLE ONLY public.movimiento_stock
    ADD CONSTRAINT fk_producto FOREIGN KEY (producto_id) REFERENCES public.producto(id);
 F   ALTER TABLE ONLY public.movimiento_stock DROP CONSTRAINT fk_producto;
       public               postgres    false    290    5177    336            �           2606    25527    producto fk_producto_categoria    FK CONSTRAINT     �   ALTER TABLE ONLY public.producto
    ADD CONSTRAINT fk_producto_categoria FOREIGN KEY (categoria_id) REFERENCES public.categoria(id);
 H   ALTER TABLE ONLY public.producto DROP CONSTRAINT fk_producto_categoria;
       public               postgres    false    290    218    5094            |           2606    25089 *   producto_multimedia fk_producto_multimedia    FK CONSTRAINT     �   ALTER TABLE ONLY public.producto_multimedia
    ADD CONSTRAINT fk_producto_multimedia FOREIGN KEY (detalle_producto_id) REFERENCES public.detalle_producto(id);
 T   ALTER TABLE ONLY public.producto_multimedia DROP CONSTRAINT fk_producto_multimedia;
       public               postgres    false    5102    226    276            �           2606    25178 9   producto_ubicacion fk_producto_ubicacion_detalle_producto    FK CONSTRAINT     �   ALTER TABLE ONLY public.producto_ubicacion
    ADD CONSTRAINT fk_producto_ubicacion_detalle_producto FOREIGN KEY (detalle_producto_id) REFERENCES public.detalle_producto(id);
 c   ALTER TABLE ONLY public.producto_ubicacion DROP CONSTRAINT fk_producto_ubicacion_detalle_producto;
       public               postgres    false    5102    226    292            �           2606    25183 3   producto_ubicacion fk_producto_ubicacion_inventario    FK CONSTRAINT     �   ALTER TABLE ONLY public.producto_ubicacion
    ADD CONSTRAINT fk_producto_ubicacion_inventario FOREIGN KEY (inventario_id) REFERENCES public.inventario(id);
 ]   ALTER TABLE ONLY public.producto_ubicacion DROP CONSTRAINT fk_producto_ubicacion_inventario;
       public               postgres    false    292    5108    230            �           2606    25188 0   producto_ubicacion fk_producto_ubicacion_negocio    FK CONSTRAINT     �   ALTER TABLE ONLY public.producto_ubicacion
    ADD CONSTRAINT fk_producto_ubicacion_negocio FOREIGN KEY (negocio_id) REFERENCES public.negocio(id);
 Z   ALTER TABLE ONLY public.producto_ubicacion DROP CONSTRAINT fk_producto_ubicacion_negocio;
       public               postgres    false    296    292    5183            �           2606    25198 /   producto_ubicacion fk_producto_ubicacion_precio    FK CONSTRAINT     �   ALTER TABLE ONLY public.producto_ubicacion
    ADD CONSTRAINT fk_producto_ubicacion_precio FOREIGN KEY (precio_id) REFERENCES public.precio(id);
 Y   ALTER TABLE ONLY public.producto_ubicacion DROP CONSTRAINT fk_producto_ubicacion_precio;
       public               postgres    false    5135    252    292            �           2606    25193 2   producto_ubicacion fk_producto_ubicacion_ubicacion    FK CONSTRAINT     �   ALTER TABLE ONLY public.producto_ubicacion
    ADD CONSTRAINT fk_producto_ubicacion_ubicacion FOREIGN KEY (ubicacion_fisica_id) REFERENCES public.ubicacion_fisica(id);
 \   ALTER TABLE ONLY public.producto_ubicacion DROP CONSTRAINT fk_producto_ubicacion_ubicacion;
       public               postgres    false    292    5181    294            }           2606    25094 *   producto_visual_tag fk_producto_visual_tag    FK CONSTRAINT     �   ALTER TABLE ONLY public.producto_visual_tag
    ADD CONSTRAINT fk_producto_visual_tag FOREIGN KEY (detalle_producto_id) REFERENCES public.detalle_producto(id);
 T   ALTER TABLE ONLY public.producto_visual_tag DROP CONSTRAINT fk_producto_visual_tag;
       public               postgres    false    226    5102    278            d           2606    25532 1   restriccion_usuario fk_restriccion_usuario_accion    FK CONSTRAINT     �   ALTER TABLE ONLY public.restriccion_usuario
    ADD CONSTRAINT fk_restriccion_usuario_accion FOREIGN KEY (accion_id) REFERENCES public.accion(id);
 [   ALTER TABLE ONLY public.restriccion_usuario DROP CONSTRAINT fk_restriccion_usuario_accion;
       public               postgres    false    244    5124    246            ^           2606    25288    rol fk_rol_empresa    FK CONSTRAINT     v   ALTER TABLE ONLY public.rol
    ADD CONSTRAINT fk_rol_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 <   ALTER TABLE ONLY public.rol DROP CONSTRAINT fk_rol_empresa;
       public               postgres    false    5185    239    298            a           2606    25303 !   rol_permiso fk_rol_permiso_accion    FK CONSTRAINT     �   ALTER TABLE ONLY public.rol_permiso
    ADD CONSTRAINT fk_rol_permiso_accion FOREIGN KEY (accion_id) REFERENCES public.accion(id);
 K   ALTER TABLE ONLY public.rol_permiso DROP CONSTRAINT fk_rol_permiso_accion;
       public               postgres    false    5124    245    244            b           2606    25298    rol_permiso fk_rol_permiso_area    FK CONSTRAINT     }   ALTER TABLE ONLY public.rol_permiso
    ADD CONSTRAINT fk_rol_permiso_area FOREIGN KEY (area_id) REFERENCES public.area(id);
 I   ALTER TABLE ONLY public.rol_permiso DROP CONSTRAINT fk_rol_permiso_area;
       public               postgres    false    5122    245    242            c           2606    25293    rol_permiso fk_rol_permiso_rol    FK CONSTRAINT     v   ALTER TABLE ONLY public.rol_permiso
    ADD CONSTRAINT fk_rol_permiso_rol FOREIGN KEY (id) REFERENCES public.rol(id);
 H   ALTER TABLE ONLY public.rol_permiso DROP CONSTRAINT fk_rol_permiso_rol;
       public               postgres    false    5118    239    245            �           2606    25753    movimiento_stock fk_ubicacion    FK CONSTRAINT     �   ALTER TABLE ONLY public.movimiento_stock
    ADD CONSTRAINT fk_ubicacion FOREIGN KEY (ubicacion_id) REFERENCES public.ubicacion_fisica(id);
 G   ALTER TABLE ONLY public.movimiento_stock DROP CONSTRAINT fk_ubicacion;
       public               postgres    false    294    5181    336            \           2606    25328    usuario fk_usuario_empleado    FK CONSTRAINT     �   ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT fk_usuario_empleado FOREIGN KEY (empleado_id) REFERENCES public.empleado(id);
 E   ALTER TABLE ONLY public.usuario DROP CONSTRAINT fk_usuario_empleado;
       public               postgres    false    237    268    5153            ]           2606    25323    usuario fk_usuario_empresa    FK CONSTRAINT     ~   ALTER TABLE ONLY public.usuario
    ADD CONSTRAINT fk_usuario_empresa FOREIGN KEY (empresa_id) REFERENCES public.empresa(id);
 D   ALTER TABLE ONLY public.usuario DROP CONSTRAINT fk_usuario_empresa;
       public               postgres    false    5185    237    298            _           2606    25283    usuario_rol fk_usuario_rol_rol    FK CONSTRAINT     z   ALTER TABLE ONLY public.usuario_rol
    ADD CONSTRAINT fk_usuario_rol_rol FOREIGN KEY (rol_id) REFERENCES public.rol(id);
 H   ALTER TABLE ONLY public.usuario_rol DROP CONSTRAINT fk_usuario_rol_rol;
       public               postgres    false    240    239    5118            `           2606    25278 "   usuario_rol fk_usuario_rol_usuario    FK CONSTRAINT     ~   ALTER TABLE ONLY public.usuario_rol
    ADD CONSTRAINT fk_usuario_rol_usuario FOREIGN KEY (id) REFERENCES public.usuario(id);
 L   ALTER TABLE ONLY public.usuario_rol DROP CONSTRAINT fk_usuario_rol_usuario;
       public               postgres    false    240    237    5116            n           2606    25505    venta fk_venta_cliente    FK CONSTRAINT     z   ALTER TABLE ONLY public.venta
    ADD CONSTRAINT fk_venta_cliente FOREIGN KEY (cliente_id) REFERENCES public.cliente(id);
 @   ALTER TABLE ONLY public.venta DROP CONSTRAINT fk_venta_cliente;
       public               postgres    false    248    5130    256            o           2606    25500    venta fk_venta_usuario    FK CONSTRAINT     z   ALTER TABLE ONLY public.venta
    ADD CONSTRAINT fk_venta_usuario FOREIGN KEY (usuario_id) REFERENCES public.usuario(id);
 @   ALTER TABLE ONLY public.venta DROP CONSTRAINT fk_venta_usuario;
       public               postgres    false    5116    237    256            Z           2606    16507 .   inventario inventario_id_detalle_producto_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.inventario
    ADD CONSTRAINT inventario_id_detalle_producto_fkey FOREIGN KEY (detalle_producto_id) REFERENCES public.detalle_producto(id);
 X   ALTER TABLE ONLY public.inventario DROP CONSTRAINT inventario_id_detalle_producto_fkey;
       public               postgres    false    226    230    5102            e           2606    16848 6   restriccion_usuario restriccion_usuario_id_accion_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.restriccion_usuario
    ADD CONSTRAINT restriccion_usuario_id_accion_fkey FOREIGN KEY (area_id) REFERENCES public.accion(id);
 `   ALTER TABLE ONLY public.restriccion_usuario DROP CONSTRAINT restriccion_usuario_id_accion_fkey;
       public               postgres    false    5124    246    244            f           2606    16843 4   restriccion_usuario restriccion_usuario_id_area_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.restriccion_usuario
    ADD CONSTRAINT restriccion_usuario_id_area_fkey FOREIGN KEY (usuario_id) REFERENCES public.area(id);
 ^   ALTER TABLE ONLY public.restriccion_usuario DROP CONSTRAINT restriccion_usuario_id_area_fkey;
       public               postgres    false    246    5122    242            g           2606    16838 7   restriccion_usuario restriccion_usuario_id_usuario_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.restriccion_usuario
    ADD CONSTRAINT restriccion_usuario_id_usuario_fkey FOREIGN KEY (id) REFERENCES public.usuario(id);
 a   ALTER TABLE ONLY public.restriccion_usuario DROP CONSTRAINT restriccion_usuario_id_usuario_fkey;
       public               postgres    false    5116    237    246            P           2606    16402 -   sub_categoria sub_categoria_id_categoria_fkey    FK CONSTRAINT     �   ALTER TABLE ONLY public.sub_categoria
    ADD CONSTRAINT sub_categoria_id_categoria_fkey FOREIGN KEY (categoria_id) REFERENCES public.categoria(id);
 W   ALTER TABLE ONLY public.sub_categoria DROP CONSTRAINT sub_categoria_id_categoria_fkey;
       public               postgres    false    5094    218    220            E      x������ � �      C      x������ � �      0   �   x�e�;n�0Dk�{�����A��"e�Pa���Ƚ�=�/��p���Hqм�+O�͕+k�㲎/�9�_����C�?�z�Z�y��w�P��5������ռ��0n��Ά=�l�`���������t�Y=r����*�J����Z�E��>����Z���$��V?��E/nFaJ
���U�ZR8����:�S;� � � � � ��x�';���      ,   L   x�3�LO�K-J����LI-N.�,H���S�	�pq�Cن�E�)��%��
��J�a��0$�eBXU	W� ��0�      b      x�3�4��? ����� %�u      I      x������ � �      6   [   x�-�� !D�3c ��������y��L�)�t22�Z(���;m�m�gIf�IR!\�(Z҆��`�a�Lq2��;㐈=�����      ~      x������ � �      |      x������ � �      g      x����4��CA�\1z\\\ RfP      `   3   x�3�4�L�,�L�W0TH-.I�+I�L��y�)�E
09N������� �?X      �      x�3�L-.I�+IU0��C C�=... ��8      Z      x������ � �      2   C  x�m�MN1��/��	P�wu�H��tT�iڲ�6�S�b8�iv�g?�~qtp7y�v]3{^/�uV��QC�ן�N�H�S"�٪��\�q����g����*	��|4�v~�aA��.����t�V��
��L�d�M�I���� L����p���O!�X<y�_���M�|e"I7�8���.�L����;m�$��!�`?$0�{VV��hG3��ZPk]	��V�����X�
iF���y�٢߷۬d@S9(ÚS�`aM�W�T�po����JB�ǒ[�[H�3�M`�v�BV��}�Y���J)� l�*      W      x������ � �      4     x��VAn�0<�B�+.IQ<&��$H{̅��B�,�� �M��'�c]JNb;��֊m�Ȑ��̈��$Ma��o_(��:)��?;��6 �E�����a4O�������wE��~Ӵ�[T�M�.�M�Wmv�@�A�(�<��@z�dz3����R$y�(��T���T9�Dk[��vv��+\�E�tI�M������[��ʃ��܂���#���Ak��BTV�-\�k��m�uQ65�tOn��,��j����\�X�e3P�;��m(��"��i9O�I9H�kPdfOC�e9%�lŶ�A��
yvm���V���I J�ϗ��J	2G����,-*k/!oLuӮ\�Z��:4�opo�0\Γ5��z���O��h]����!Y*x�"��c�JTف'��־(]�Y�w�lj�ѐ�S��fQe��c�	O(�	�� s��^�����'AY�bL�5�I�A�rL�4�VcR���2�P�pZ�><�Ρ��h�Y������s�CK�y	�c�#c�#	�c��G]��_D�`ÍE�숛�2�E���)ҨD��ˠ���Z(�w"�b��:����.�b0rYy�:����SYOb�)&z�<��=l��ã��M
�ד1]�dd��U�e94��C9,��_�����w�=��w�~ۛ'w��7wחW�<���&�k�ӛ��~y�����,��J�f�5��,ɎJ٬pO�:�Y��Y�HvT�Ȏʠp��P*_I���/ÇS�"���	u��*��cT$�=&�~����M      i   T   x�Mɱ�0њ?Lc�K��#t��I�Aj��=����{��m2�-1�_�ǡ}ɡ1�0nr�L�^� _�u��> >�`      <      x������ � �      S      x������ � �      \      x������ � �      z   6   x�3��.J�N���C�N##S]]#SC+3+CS=SK#SK�=... m��      �     x���ێ�@�����d5'����7E���ޤ4��E@R���		)��ZH ���?�x�@xY����v�W �a�XK��xj
�@��XW�氯vWP�H>o��r�O����}�T$s�4�÷��	��!�Čg�h%���[�+3 v��U����ޟە��z�
e���s��U��P���Vm�{[��y+6��g�>�I�D�m\k�I���.����6mڀ�}����i`ƈjc@H����B[T6�S-q5��F���ΨG"�]�@*W�+P���+j5�v;&%��Q���&�~���t��M?gR��ܿ�	�Q���{󾘙�ey]�A>/RAڿ(ˮ�$�C����y�;<�uE-�|��)��!�0�.x�ޛ�)y�RE�E@CQ�w�[��w�$�y�*2.�@�9$L �ÅB>RE΅F�\d]P ��w�Z1Rd\h�VFAօ��$T�������*?��X;\9^ApPW�X���|C^O����&��@�9=M�{�Eo��M�{�ǗD��g&a      U      x������ � �      8   �  x����q�8�Q8�E��#��`�c_S�d�H��*ڮ�n�__��n���Suڄ��!�G��x�O�ڢ�l�/�����5H���h�~dD&K2�2|��ZX7틒��EEZ%^5<t�A[a�t�S�u(��E�¾���}q��S��`��u���e�'%4�&sm}4n��0*��dA��Ȩ�a����m��!�����〼o�>Jpc����p�Ed���LyS���r����{ �$��-�F���Oӣ����;�"���@Γ����\?2�N�:B�-*o�S�� ŧՈ�v�ܵH��ϐ�4Hr0�8 +26�Z@�A�:�q��Ey�~�Ȍ�`^��V��c����Ç���X�j'e9.=zQ��.�ĸ6���ר@U��qmҮ&d��^���h}�?0�b�5#�>j����4!�E��t�Q��p�$���������TGM�})dD���Kޟ��SR2`��e��+�j�z(l���5�g�oHY�l(]�FS�ULH�8�^B�2���E�s�-�y=��p5�c��q[a!.����{��޸/RJ ��.�>	ru����%\4�xP?~}���t�W�"t���J�	t�?�[6.wo����'�~���w2枡��-2Jûy�1\�O,������W�W���~c�Ij邌)R�7���Q2�?H�cg�2qF"4�h��4�n�
���d�&���%i ɭ=I.Y�n���zA��a@;�')��m��j� ��a�miSa��dj��H��
Q3�+b%�қdj(.Ȗm�Bؗn�K��d�M�����Lk���(}�%�&�E�ߑ��~i�f���JV�����oߑ���V�>�gsQ3���Q���#�26�Ր޶Ď�X��%z��þ�n��o���c. �x��'�?����J�Μ�#!<X�"��`D�r-��b�����E}k��[��)7��Y�x��$���F��9����Xs6�*�i�MN��G9�b>�N�P.9�`ͺ@��$��X)k�lN9fh�IXH� 
k�W-���6��      m      x������ � �      q      x������ � �      k      x������ � �      �     x���[n7E�G����w�����`�C�`������ "9�t7�jApϐ�[�/_�^� �GR�<����ק��ߞ�<?�\~{y}��_�_����������߿�������ㅀ���+`E�����x{J'��D�ʒ�i""t���ԜX�LL�L>�IT�S��.L��/�HJ�����%U�Ħ�<#�#�H�T���!ې��_ѫ`%LTPJ��ޙomB0	*@8%y.�>3sgR�rG��>��E\uB2u��s�z���5co�e�H?�4)"�T)q�2GP7�E&��l$C`Yv����;�RA�X�ec{�*N�R���/��#V�p�bK(��G�僉��b�2#{޹���x<�e�9���sQ=)R%�uAp��=�љ �Q�!qq��"�]��p��V0��+=`������,�SF�="=b�8[v�U.�����b��h���^aKwQ��Uz��� ژ����ӷ���3�@��F{���B��Fq̩�߃���p�J{J,�<{���s���N){ВD"!�9��o�}xW�{���5}{?h�я�iƐ�Y�������]�l[1��'�C_���
�j��?�E��u�݁��+h�L��3��Fx�T�y�Y�آi�M�_��qS�3�6�2��^}�آ���d֡_v�k���KG��������[%J��i����ñ������n�Q����]⧜�_�d��b������>��?�ۯs�חڦ>ΐ}9Y��_��я�V��g�;Y��_ݡ�9�dN&B8�ϒOֿ����{�}�u�?p6 ��,�� �'#]C�w@��l����8����RYڠ�����yO��+�֌�PY x6`l�v%i��칊�`��Ֆ���%�ꝧ�+�BV'n� �� �� �.�@#�m׉��@D�J��7�!ܻ�_�t!{B��^o]#��j�Dw&`xAp �01�rA�4� t?��+�
b�7���&�� ѹ{��[j#����8^.@>�����b�z�      x   w   x�u�1�0D��>'��%r���%�V�ʒ��	��V���

/ś)ok���e_ÒB���ɷ��s3�Q�?<	^=�@0�	Ԣ�Pp�p�p�0���0���a��,��	���1      o      x������ � �      M   �  x���Kn�@���)�@Pף�Ƈ�jV�XE�#"�\l�0�j���P&��e��_��z4 ����W G����҅���*�������;�'r�����,�+���	�����k��e�>���]������������m�����c�c���z[�|�-I9��]��Z��Ap�k�=ɓ�>�ɬn�}�=v����� !�ܼn�ݯ��-ۗg��A�I�W6p.�3���NK�_��.rЯ��>!x\%$�J��y�P��*��W	�UEA|\%l 4k��^�GP�k�ZoM=N�<:D�~��ձ����O}3Q�4�H� :��Rh-���y8��r��Ǉ���+�wo��������IVGD�В�}!� M�>�:��#�XhK����v����E�^�.üS���e_��e)��;���&�ǆ+��8VX���>_�:�0�P���P�r�lh���I3Ak��E;JvT3��	;��"����j�Hlh��)[ބFgGю�l�vT�h�VmC���h��)[ф6Ύ���b[s���r_ۋ�-MeV2k�!�+FBf>ԙ5���eo����]}=D��8�����S��r`g�9��h���9�<ۙ�N<;�{,hc� ����BF�n`u��ʣЄ�X��� 4a�������Y�      �   l  x���Mn�0F�3������U�U�n�q�U�F$
�ʽz�^�cZbHD���͛7 �H�<�nTO���k_}�uط5�*�+IтI�O���X�-s�SR�yVHt`d�^�%R>�o��fpuWH�:Ǐ�>T��N����bÃ�B�	��H��j�l��E$S��2�6+֐x�ͼ��9�C*b뜵�5�y��?g������wEy��������1l����)�*��Ť�o߼���R�uw�Uė�UE�\�(��ԼY�Y=XׇІ�����̶�nOC������@r�vg#Ԃ+���i������ش�os���a[��RYk�q1d&W��꣄��K��Q�Y >��[R��$ܬ�Z�      r   F   x�3�L�I,ˇ�
)�
��y�E�%�
�9e�y�U�)��%�1~��\����ɉ���9� ��W� \!$      d   �  x���K�1 �u��@����Cp�ل2A�5�w#�`���ܒ��ܪ��D���>�������>_�����|���y>?�����~�2�HY�T��L�����ڙ����tY~�0��Q�l;�Fܬd#��I����}���lY�\$ٶ����H�B�b[���0>vM�1e�����-OJ}Ɔ؈r��hc�Ay���K�0K$�>�'i9�W@Ͽ��H�w_mZ{�)*%��}7{W9��P��?6�����ൡf���*������f�ٔ�#����f��3�X$&0��g_�z�Ρ�g�q{��K?�݋�&0�6��0<����ݷ&���%6���ߗ޺��D��c�{�C;�%�����+���/?�ӯ�~�_!���?���I��ŷhbٱ���B�����]�Ӵ����0�������$ܭ�\C΢N�%噘��|�Ǹ
����.#(�2JMb��|�}�)����K      t   �  x�e�ˑ[;D�P0.�|�p^;��=4���jjC�K�� N�K��������d�/���$���R���DДU3�E
�d�s�ڲ+�u��^�Ȟ�N�AB��$^�k�v�J�u��I� *g�H}����Gᤉ�,9S�!� [N����\���2��>19Gf��S
��@RNȢZ9b��&	��7p��wB@��#���AbK1P8�Y�inK��?4e��Jt�ظ���R�7�zǂ����O��L�ycYŪ�@���9U�B�XHC-��������JӘb���Od���O��-��@��h�\����c}���8|7���1V��b7V��������5��7֖�8��U��a(��qU��r��U�;��!�1�x'55���̪�c19�q���a;j\7Ʃޡ>�����u����#�;�g��f�;ԧQ�C}B��X�6�ݬ:��,
��0�Po�H'����"�x�l�/<�v�:@�wD3m�t���<&#���<Z�nn���{j�CF�ͬٳ�t8��~�f��u9�9/��6[�����(P]��8fS��\����ύ4ޠ������h�h����	B�N��ϯ�r��'��ۯ�y�" L�v���񆍸��'���yi;E�_�	Ц����}��RUBIe�x���o���mF#mH����~�:Mx$��3�}O��*�W��6P�A�S� |���I�X��@�n~�^����KU      f      x������ � �      O      x������ � �      K      x������ � �      G      x������ � �      Y      x������ � �      @      x������ � �      F      x������ � �      :   �  x���Kn1D��)����C�� ��@����=ëH��>P*��o_�����IH�����\j�sczz~y��������_���z'?CE,�}�0��� YbUI}zh�}%�/�e���M�q�B��D�=Hq�6��~-J8�1,���t#��t�`E�q�2�bB:ۜ� "�n�!h��MT�a�
j����X]x$P�?�Q>Jǭ��I��#\�r���t�:��|�y׀�Pi��'H�O�n�QP�)��p��6g����&�._�39���a6ƴto�g+l���q�������&�dd�l/��O=`��N�+b.�n1r6?1/�Ir�#�0���l��|,y%�.�>C��{�^���10���2[&='SF��B�QיD���K�Y����1o�w\d�.�nC��5xs�*k�=�jmS��X U:u�w�'��Nr���K��Q�FE�H��*��[m
�b�au�!G�|Q��2[l�E|��[�}��Je:J�bꮃF��ުJawL�pO�D��n�~*gLO�.G.��PK�Lΐ#��:���W��\�W0i��	�\xQ��'��VpAt'�ν[G&KF����@x=��@��A�˔w+�� ���U�]���O!���]U��FuԮQ�����[QG�B�����ZG��f�������P�B�K����[�U+��gx��:irQH� T	x�N�\T6lH�7��Z���'�      .      x������ � �      �   !   x�3�L��L�+IU(I-.�2B��rc���� �S�      ^      x������ � �      v   J   x�3�4�t�OIMOTp�H,H,*J́
p��9c���˘UI���)n)3�R��,qKᖊ���� g�:%      >      x������ � �      A      x������ � �      Q      x������ � �     