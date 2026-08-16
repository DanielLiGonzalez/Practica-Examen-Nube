let productsCache = [];
let customersCache = [];


async function api(url, options = {}) {
    const response = await fetch(url, options);

    if (response.status === 204) {
        return null;
    }

    const contentType =
        response.headers.get("content-type") || "";

    const data = contentType.includes("application/json")
        ? await response.json()
        : await response.text();

    if (!response.ok) {
        throw new Error(
            typeof data === "string"
                ? data
                : JSON.stringify(data)
        );
    }

    return data;
}


function showMessage(text) {
    const element = document.getElementById("message");

    element.textContent = text;
    element.style.display = "block";

    setTimeout(() => {
        element.style.display = "none";
    }, 3000);
}


async function healthCheck(url, elementId) {
    const element = document.getElementById(elementId);

    try {
        const result = await api(url);

        if (result.status === "ok") {
            element.textContent = "OK";
            element.className = "status-ok";
            return;
        }

        throw new Error("Estado inválido");
    } catch (error) {
        element.textContent = "ERROR";
        element.className = "status-error";
    }
}


async function loadHealth() {
    await Promise.all([
        healthCheck(
            "/api/catalog/healthz",
            "catalog-status"
        ),
        healthCheck(
            "/api/customers/healthz",
            "customers-status"
        ),
        healthCheck(
            "/api/orders/healthz",
            "orders-status"
        ),
    ]);
}


async function loadProducts() {
    try {
        productsCache = await api(
            "/api/catalog/products"
        );

        const body =
            document.getElementById("products-body");

        body.innerHTML = "";

        for (const product of productsCache) {
            const row = document.createElement("tr");

            row.innerHTML = `
                <td>${product.id}</td>
                <td>${product.nombre}</td>
                <td>₡${product.precio}</td>
                <td>${product.stock}</td>
                <td>
                    <button
                        onclick="editProduct(${product.id})"
                    >
                        Editar
                    </button>

                    <button
                        class="secondary"
                        onclick="deleteProduct(${product.id})"
                    >
                        Eliminar
                    </button>
                </td>
            `;

            body.appendChild(row);
        }
    } catch (error) {
        showMessage(
            "Error cargando productos: " +
            error.message
        );
    }
}


function editProduct(id) {
    const product = productsCache.find(
        item => item.id === id
    );

    if (!product) {
        return;
    }

    document.getElementById("product-id").value =
        product.id;

    document.getElementById("product-nombre").value =
        product.nombre;

    document.getElementById("product-precio").value =
        product.precio;

    document.getElementById("product-stock").value =
        product.stock;

    document.getElementById(
        "product-descripcion"
    ).value = product.descripcion || "";

    document.getElementById("productos")
        .scrollIntoView();
}


async function deleteProduct(id) {
    const confirmed = confirm(
        "¿Desea eliminar este producto?"
    );

    if (!confirmed) {
        return;
    }

    try {
        await api(
            `/api/catalog/products/${id}`,
            {
                method: "DELETE",
            }
        );

        showMessage("Producto eliminado");
        await loadProducts();
    } catch (error) {
        showMessage(
            "Error eliminando producto: " +
            error.message
        );
    }
}



function resetProductForm() {
    document.getElementById("product-form").reset();
    document.getElementById("product-id").value = "";
}


document.getElementById("product-form")
    .addEventListener("submit", async event => {
        event.preventDefault();

        const id =
            document.getElementById("product-id").value;

        const payload = {
            nombre:
                document.getElementById(
                    "product-nombre"
                ).value,
            precio:
                Number(
                    document.getElementById(
                        "product-precio"
                    ).value
                ),
            stock:
                Number(
                    document.getElementById(
                        "product-stock"
                    ).value
                ),
            descripcion:
                document.getElementById(
                    "product-descripcion"
                ).value || null,
            imagen: null,
        };

        try {
            if (id) {
                await api(
                    `/api/catalog/products/${id}`,
                    {
                        method: "PUT",
                        headers: {
                            "Content-Type":
                                "application/json",
                        },
                        body: JSON.stringify(payload),
                    }
                );

                showMessage("Producto actualizado");
            } else {
                await api(
                    "/api/catalog/products",
                    {
                        method: "POST",
                        headers: {
                            "Content-Type":
                                "application/json",
                        },
                        body: JSON.stringify(payload),
                    }
                );

                showMessage("Producto creado");
            }

            resetProductForm();
            await loadProducts();
        } catch (error) {
            showMessage(
                "Error: " + error.message
            );
        }
    });


async function loadCustomers() {
    try {
        customersCache = await api(
            "/api/customers/customers"
        );

        const body =
            document.getElementById("customers-body");

        body.innerHTML = "";

        for (const customer of customersCache) {
            const row = document.createElement("tr");

            row.innerHTML = `
                <td>${customer.id}</td>
                <td>${customer.nombre}</td>
                <td>${customer.email}</td>
                <td>${customer.numero_identidad}</td>
                <td>
                    <button
                        onclick="editCustomer(${customer.id})"
                    >
                        Editar
                    </button>
                </td>
            `;

            body.appendChild(row);
        }
    } catch (error) {
        showMessage(
            "Error cargando clientes: " +
            error.message
        );
    }
}


function editCustomer(id) {
    const customer = customersCache.find(
        item => item.id === id
    );

    if (!customer) {
        return;
    }

    document.getElementById("customer-id").value =
        customer.id;

    document.getElementById(
        "customer-nombre"
    ).value = customer.nombre;

    document.getElementById(
        "customer-email"
    ).value = customer.email;

    document.getElementById(
        "customer-identidad"
    ).value = customer.numero_identidad;

    document.getElementById("clientes")
        .scrollIntoView();
}


function resetCustomerForm() {
    document.getElementById("customer-form").reset();
    document.getElementById("customer-id").value = "";
}


document.getElementById("customer-form")
    .addEventListener("submit", async event => {
        event.preventDefault();

        const id =
            document.getElementById(
                "customer-id"
            ).value;

        const payload = {
            nombre:
                document.getElementById(
                    "customer-nombre"
                ).value,
            email:
                document.getElementById(
                    "customer-email"
                ).value,
            numero_identidad:
                document.getElementById(
                    "customer-identidad"
                ).value,
        };

        try {
            if (id) {
                await api(
                    `/api/customers/customers/${id}`,
                    {
                        method: "PUT",
                        headers: {
                            "Content-Type":
                                "application/json",
                        },
                        body: JSON.stringify(payload),
                    }
                );

                showMessage("Cliente actualizado");
            } else {
                await api(
                    "/api/customers/customers",
                    {
                        method: "POST",
                        headers: {
                            "Content-Type":
                                "application/json",
                        },
                        body: JSON.stringify(payload),
                    }
                );

                showMessage("Cliente creado");
            }

            resetCustomerForm();
            await loadCustomers();
        } catch (error) {
            showMessage(
                "Error: " + error.message
            );
        }
    });


async function loadOrders() {
    try {
        const orders = await api(
            "/api/orders/orders"
        );

        const body =
            document.getElementById("orders-body");

        body.innerHTML = "";

        for (const order of orders) {
            const items = order.items
                .map(
                    item =>
                        `Producto ${item.product_id} x ${item.quantity}`
                )
                .join("<br>");

            const row = document.createElement("tr");

            row.innerHTML = `
                <td>${order.id}</td>
                <td>${order.customer_id}</td>
                <td>₡${order.total}</td>
                <td>${order.created_at}</td>
                <td>${items}</td>
            `;

            body.appendChild(row);
        }
    } catch (error) {
        showMessage(
            "Error cargando pedidos: " +
            error.message
        );
    }
}


document.getElementById("order-form")
    .addEventListener("submit", async event => {
        event.preventDefault();

        const payload = {
            customer_id:
                Number(
                    document.getElementById(
                        "order-customer"
                    ).value
                ),

            items: [
                {
                    product_id:
                        Number(
                            document.getElementById(
                                "order-product"
                            ).value
                        ),

                    quantity:
                        Number(
                            document.getElementById(
                                "order-quantity"
                            ).value
                        ),
                },
            ],
        };

        try {
            const order = await api(
                "/api/orders/orders",
                {
                    method: "POST",
                    headers: {
                        "Content-Type":
                            "application/json",
                    },
                    body: JSON.stringify(payload),
                }
            );

            showMessage(
                `Pedido ${order.id} creado. Total ₡${order.total}`
            );

            document.getElementById(
                "order-form"
            ).reset();

            await Promise.all([
                loadOrders(),
                loadProducts(),
            ]);
        } catch (error) {
            showMessage(
                "Error: " + error.message
            );
        }
    });


async function loadLegacy() {
    const sku =
        document.getElementById(
            "legacy-sku"
        ).value.trim();

    const url = sku
        ? `/legacy/inventory?sku=${encodeURIComponent(sku)}`
        : "/legacy/inventory";

    try {
        const result = await api(url);

        document.getElementById(
            "legacy-result"
        ).textContent =
            JSON.stringify(result, null, 2);
    } catch (error) {
        document.getElementById(
            "legacy-result"
        ).textContent =
            error.message;
    }
}


function normalizeName(name) {
    return name
        .toLowerCase()
        .replace(" legacy", "")
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .trim();
}


async function compareInventory() {
    try {
        const [legacy, catalog] =
            await Promise.all([
                api("/legacy/inventory"),
                api("/api/catalog/products"),
            ]);

        const body =
            document.getElementById(
                "comparison-body"
            );

        body.innerHTML = "";

        for (const legacyItem of legacy.items) {
            const normalizedLegacy =
                normalizeName(legacyItem.nombre);

            const catalogItem = catalog.find(
                product =>
                    normalizeName(product.nombre) ===
                    normalizedLegacy
            );

            const catalogStock = catalogItem
                ? catalogItem.stock
                : "N/A";

            const difference = catalogItem
                ? Number(catalogItem.stock) -
                  Number(legacyItem.stock)
                : "N/A";

            const row =
                document.createElement("tr");

            row.innerHTML = `
                <td>
                    ${legacyItem.sku}
                    ${legacyItem.nombre}
                </td>

                <td>${legacyItem.stock}</td>

                <td>
                    ${
                        catalogItem
                            ? catalogItem.nombre
                            : "No encontrado"
                    }
                </td>

                <td>${catalogStock}</td>

                <td>${difference}</td>
            `;

            body.appendChild(row);
        }

        showMessage(
            "Comparación completada"
        );
    } catch (error) {
        showMessage(
            "Error comparando inventarios: " +
            error.message
        );
    }
}


async function initialize() {
    await loadHealth();

    await Promise.all([
        loadProducts(),
        loadCustomers(),
        loadOrders(),
        loadLegacy(),
    ]);
}


initialize();
