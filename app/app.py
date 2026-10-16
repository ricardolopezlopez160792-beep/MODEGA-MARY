"""Sistema de gestión de Bodega Mary (Flask + PostgreSQL 16, esquema bodega)."""
from decimal import Decimal

import psycopg
from psycopg.rows import dict_row
from flask import Flask, flash, redirect, render_template, request, url_for

from config import DB

app = Flask(__name__)
app.secret_key = "bodega-mary-local"


def conectar():
    return psycopg.connect(**DB, row_factory=dict_row, options="-c search_path=bodega")


def consultar(sql, params=None, uno=False):
    with conectar() as cn:
        cur = cn.execute(sql, params)
        return cur.fetchone() if uno else cur.fetchall()


def ejecutar(sql, params=None):
    with conectar() as cn:  # el bloque hace COMMIT al salir o ROLLBACK si hay error
        cn.execute(sql, params)


def mensaje_error(e):
    diag = getattr(e, "diag", None)
    texto = (diag.message_primary if diag and diag.message_primary else str(e))
    if diag and diag.constraint_name == "inventario_stock_actual_check":
        return "Stock insuficiente: la venta se canceló completa (ROLLBACK)."
    return texto


@app.template_filter("soles")
def soles(valor):
    return f"S/ {Decimal(valor or 0):,.2f}"


# ---------------------------------------------------------------- Panel
@app.route("/")
def panel():
    hoy = consultar("""
        SELECT COUNT(*) AS n_ventas, COALESCE(SUM(total), 0) AS total
        FROM venta WHERE fecha_hora::date = CURRENT_DATE AND estado <> 'ANULADA'""", uno=True)
    totales = consultar("""
        SELECT (SELECT COUNT(*) FROM producto WHERE activo) AS productos,
               (SELECT COUNT(*) FROM cliente) AS clientes,
               (SELECT COUNT(*) FROM venta) AS ventas,
               (SELECT COALESCE(SUM(deuda), 0) FROM v_deuda_cliente) AS fiado""", uno=True)
    alertas = consultar("SELECT * FROM v_alerta_stock ORDER BY stock_actual")
    ultimas = consultar("SELECT * FROM v_ventas ORDER BY fecha_hora DESC LIMIT 8")
    return render_template("panel.html", hoy=hoy, totales=totales,
                           alertas=alertas, ultimas=ultimas)


# ---------------------------------------------------------------- Ventas
@app.route("/ventas")
def ventas():
    desde = request.args.get("desde") or ""
    hasta = request.args.get("hasta") or ""
    estado = request.args.get("estado") or ""
    filtros, params = [], []
    if desde:
        filtros.append("fecha_hora >= %s"); params.append(desde)
    if hasta:
        filtros.append("fecha_hora < %s::date + 1"); params.append(hasta)
    if estado:
        filtros.append("estado = %s"); params.append(estado)
    where = ("WHERE " + " AND ".join(filtros)) if filtros else ""
    filas = consultar(f"SELECT * FROM v_ventas {where} ORDER BY fecha_hora DESC LIMIT 200", params)
    return render_template("ventas.html", ventas=filas, desde=desde, hasta=hasta, estado=estado)


@app.route("/ventas/nueva", methods=["GET", "POST"])
def nueva_venta():
    if request.method == "POST":
        id_cliente = request.form.get("id_cliente") or None
        id_medio = int(request.form["id_medio_pago"])
        estado = request.form.get("estado", "PAGADA")
        items = {}
        for pid, cant in zip(request.form.getlist("producto"), request.form.getlist("cantidad")):
            if pid and cant and int(cant) > 0:
                items[int(pid)] = items.get(int(pid), 0) + int(cant)
        if not items:
            flash("Agrega al menos un producto.", "error")
            return redirect(url_for("nueva_venta"))
        if estado == "FIADO" and not id_cliente:
            flash("Una venta al fiado necesita un cliente registrado.", "error")
            return redirect(url_for("nueva_venta"))
        try:
            # Una sola transacción: cabecera + detalle + descuento de stock (trigger).
            with conectar() as cn:
                id_venta = cn.execute(
                    "INSERT INTO venta (id_cliente, id_medio_pago, estado) VALUES (%s, %s, %s) RETURNING id_venta",
                    (id_cliente, id_medio, estado)).fetchone()["id_venta"]
                for pid, cant in items.items():
                    cn.execute("""
                        INSERT INTO detalle_venta (id_venta, id_producto, cantidad, precio_unitario)
                        SELECT %s, id_producto, %s, precio_venta FROM producto WHERE id_producto = %s""",
                        (id_venta, cant, pid))
                if estado == "FIADO":
                    c = cn.execute("SELECT limite_credito, deuda FROM v_deuda_cliente WHERE id_cliente = %s",
                                   (id_cliente,)).fetchone()
                    if c["deuda"] > c["limite_credito"]:
                        raise ValueError(f"Supera el límite de crédito del cliente ({soles(c['limite_credito'])}). "
                                         "La venta se canceló (ROLLBACK).")
        except (psycopg.Error, ValueError) as e:
            flash(mensaje_error(e) if isinstance(e, psycopg.Error) else str(e), "error")
            return redirect(url_for("nueva_venta"))
        flash(f"Venta #{id_venta} registrada.", "ok")
        return redirect(url_for("detalle_venta", id_venta=id_venta))

    productos = consultar("""SELECT id_producto, nombre, precio_venta, stock_actual
                             FROM v_catalogo WHERE activo ORDER BY nombre""")
    clientes = consultar("SELECT id_cliente, dni, nombres, apellidos FROM cliente ORDER BY apellidos, nombres")
    medios = consultar("SELECT * FROM medio_pago ORDER BY id_medio_pago")
    return render_template("venta_nueva.html", productos=productos, clientes=clientes, medios=medios)


@app.route("/ventas/<int:id_venta>")
def detalle_venta(id_venta):
    venta = consultar("SELECT * FROM v_ventas WHERE id_venta = %s", (id_venta,), uno=True)
    if not venta:
        flash("La venta no existe.", "error")
        return redirect(url_for("ventas"))
    items = consultar("""
        SELECT p.nombre, d.cantidad, d.precio_unitario, d.subtotal
        FROM detalle_venta d JOIN producto p ON p.id_producto = d.id_producto
        WHERE d.id_venta = %s ORDER BY p.nombre""", (id_venta,))
    return render_template("venta_detalle.html", venta=venta, items=items)


@app.post("/ventas/<int:id_venta>/anular")
def anular_venta(id_venta):
    try:
        ejecutar("SELECT fn_anular_venta(%s)", (id_venta,))
        flash(f"Venta #{id_venta} anulada y stock devuelto.", "ok")
    except psycopg.Error as e:
        flash(mensaje_error(e), "error")
    return redirect(url_for("detalle_venta", id_venta=id_venta))


@app.post("/ventas/<int:id_venta>/cobrar")
def cobrar_fiado(id_venta):
    ejecutar("UPDATE venta SET estado = 'PAGADA' WHERE id_venta = %s AND estado = 'FIADO'", (id_venta,))
    flash(f"Fiado de la venta #{id_venta} cobrado.", "ok")
    return redirect(url_for("detalle_venta", id_venta=id_venta))


# ---------------------------------------------------------------- Clientes
@app.route("/clientes")
def clientes():
    q = (request.args.get("q") or "").strip()
    filas = consultar("""
        SELECT * FROM v_deuda_cliente
        WHERE %(q)s = '' OR dni LIKE %(like)s OR nombres ILIKE %(like)s OR apellidos ILIKE %(like)s
        ORDER BY deuda DESC, apellidos LIMIT 200""", {"q": q, "like": f"%{q}%"})
    return render_template("clientes.html", clientes=filas, q=q)


@app.route("/clientes/nuevo", methods=["GET", "POST"])
@app.route("/clientes/<int:id_cliente>/editar", methods=["GET", "POST"])
def form_cliente(id_cliente=None):
    if request.method == "POST":
        f = request.form
        datos = (f.get("dni") or None, f["nombres"].strip(), f["apellidos"].strip(),
                 f.get("telefono") or None, f.get("direccion") or None,
                 Decimal(f.get("limite_credito") or 0))
        try:
            if id_cliente:
                ejecutar("""UPDATE cliente SET dni=%s, nombres=%s, apellidos=%s, telefono=%s,
                            direccion=%s, limite_credito=%s WHERE id_cliente=%s""", datos + (id_cliente,))
                flash("Cliente actualizado.", "ok")
            else:
                ejecutar("""INSERT INTO cliente (dni, nombres, apellidos, telefono, direccion, limite_credito)
                            VALUES (%s, %s, %s, %s, %s, %s)""", datos)
                flash("Cliente registrado.", "ok")
            return redirect(url_for("clientes"))
        except psycopg.Error as e:
            flash(mensaje_error(e), "error")
            cliente = dict(zip(["dni", "nombres", "apellidos", "telefono", "direccion", "limite_credito"], datos))
            return render_template("cliente_form.html", cliente=cliente, id_cliente=id_cliente)
    cliente = consultar("SELECT * FROM cliente WHERE id_cliente = %s", (id_cliente,), uno=True) if id_cliente else {}
    return render_template("cliente_form.html", cliente=cliente, id_cliente=id_cliente)


@app.route("/clientes/<int:id_cliente>")
def ver_cliente(id_cliente):
    cliente = consultar("SELECT * FROM v_deuda_cliente WHERE id_cliente = %s", (id_cliente,), uno=True)
    compras = consultar("SELECT * FROM v_ventas WHERE id_cliente = %s ORDER BY fecha_hora DESC LIMIT 50",
                        (id_cliente,))
    return render_template("cliente_ver.html", cliente=cliente, compras=compras)


# ---------------------------------------------------------------- Inventario
@app.route("/inventario")
def inventario():
    categoria = request.args.get("categoria") or ""
    solo_alerta = request.args.get("alerta") == "1"
    filas = consultar("""
        SELECT * FROM v_catalogo
        WHERE (%(cat)s = '' OR categoria = %(cat)s) AND (NOT %(alerta)s OR requiere_reposicion)
        ORDER BY categoria, nombre""", {"cat": categoria, "alerta": solo_alerta})
    categorias = consultar("SELECT nombre FROM categoria ORDER BY nombre")
    return render_template("inventario.html", productos=filas, categorias=categorias,
                           categoria=categoria, solo_alerta=solo_alerta)


@app.post("/inventario/<int:id_producto>/reponer")
def reponer(id_producto):
    cantidad = int(request.form.get("cantidad") or 0)
    if cantidad <= 0:
        flash("La cantidad a reponer debe ser mayor que cero.", "error")
    else:
        ejecutar("""UPDATE inventario SET stock_actual = stock_actual + %s,
                    fecha_vencimiento = COALESCE(%s, fecha_vencimiento),
                    ultima_actualizacion = CURRENT_TIMESTAMP WHERE id_producto = %s""",
                 (cantidad, request.form.get("fecha_vencimiento") or None, id_producto))
        flash(f"Se repusieron {cantidad} unidades.", "ok")
    return redirect(request.referrer or url_for("inventario"))


@app.route("/productos/nuevo", methods=["GET", "POST"])
@app.route("/productos/<int:id_producto>/editar", methods=["GET", "POST"])
def form_producto(id_producto=None):
    if request.method == "POST":
        f = request.form
        datos = (f.get("codigo_barras") or None, f["nombre"].strip(), int(f["id_categoria"]),
                 int(f["id_proveedor"]), f["unidad_venta"].strip(),
                 Decimal(f["precio_compra"]), Decimal(f["precio_venta"]))
        try:
            with conectar() as cn:
                if id_producto:
                    cn.execute("""UPDATE producto SET codigo_barras=%s, nombre=%s, id_categoria=%s, id_proveedor=%s,
                                  unidad_venta=%s, precio_compra=%s, precio_venta=%s, activo=%s
                                  WHERE id_producto=%s""", datos + ("activo" in f, id_producto))
                    cn.execute("UPDATE inventario SET stock_minimo=%s WHERE id_producto=%s",
                               (int(f.get("stock_minimo") or 0), id_producto))
                else:
                    nuevo = cn.execute("""INSERT INTO producto (codigo_barras, nombre, id_categoria, id_proveedor,
                                          unidad_venta, precio_compra, precio_venta)
                                          VALUES (%s,%s,%s,%s,%s,%s,%s) RETURNING id_producto""", datos).fetchone()
                    cn.execute("INSERT INTO inventario (id_producto, stock_actual, stock_minimo) VALUES (%s,%s,%s)",
                               (nuevo["id_producto"], int(f.get("stock_actual") or 0),
                                int(f.get("stock_minimo") or 0)))
            flash("Producto guardado.", "ok")
            return redirect(url_for("inventario"))
        except psycopg.Error as e:
            flash(mensaje_error(e), "error")
            return redirect(request.url)
    producto = consultar("""SELECT p.*, i.stock_actual, i.stock_minimo FROM producto p
                            JOIN inventario i USING (id_producto) WHERE id_producto = %s""",
                         (id_producto,), uno=True) if id_producto else {"activo": True}
    categorias = consultar("SELECT * FROM categoria ORDER BY nombre")
    proveedores = consultar("SELECT * FROM proveedor WHERE activo ORDER BY razon_social")
    return render_template("producto_form.html", p=producto, id_producto=id_producto,
                           categorias=categorias, proveedores=proveedores)


# ---------------------------------------------------------------- Reportes
@app.route("/reportes")
def reportes():
    mensual = consultar("SELECT * FROM v_ventas_mensuales ORDER BY mes")
    top = consultar("SELECT * FROM v_top_productos ORDER BY venta DESC LIMIT 10")
    categorias = consultar("""
        SELECT categoria, SUM(unidades) AS unidades, SUM(venta) AS venta, SUM(ganancia) AS ganancia
        FROM v_top_productos GROUP BY categoria ORDER BY venta DESC""")
    medios = consultar("""
        SELECT medio_pago, COUNT(*) AS n_ventas, SUM(total) AS total
        FROM v_ventas WHERE estado <> 'ANULADA' GROUP BY medio_pago ORDER BY total DESC""")
    deudores = consultar("SELECT * FROM v_deuda_cliente WHERE deuda > 0 ORDER BY deuda DESC LIMIT 10")
    max_mes = max((m["venta"] for m in mensual), default=1) or 1
    return render_template("reportes.html", mensual=mensual, top=top, categorias=categorias,
                           medios=medios, deudores=deudores, max_mes=max_mes)


@app.post("/reportes/actualizar")
def actualizar_reportes():
    # Cierre de caja: refresca la vista materializada sin bloquear lecturas
    with psycopg.connect(**DB, autocommit=True, options="-c search_path=bodega") as cn:
        cn.execute("REFRESH MATERIALIZED VIEW CONCURRENTLY mv_ventas_diarias")
    flash("Reportes actualizados (vista materializada refrescada).", "ok")
    return redirect(url_for("reportes"))


if __name__ == "__main__":
    app.run(debug=True, port=5000)
