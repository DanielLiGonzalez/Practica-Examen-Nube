<?php

$dbPath = __DIR__ . '/data/inventory.sqlite';

if (file_exists($dbPath)) {
    unlink($dbPath);
}

$pdo = new PDO('sqlite:' . $dbPath);
$pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

$pdo->exec('
CREATE TABLE inventory (
    sku TEXT PRIMARY KEY,
    nombre TEXT NOT NULL,
    stock INTEGER NOT NULL,
    precio REAL NOT NULL
)
');

$items = [
    ['LEG-001', 'Café Americano Legacy', 45, 1500.00],
    ['LEG-002', 'Café Latte Legacy', 30, 2200.00],
    ['LEG-003', 'Cappuccino Legacy', 25, 2500.00],
    ['LEG-004', 'Chocolate Caliente Legacy', 18, 2300.00],
    ['LEG-005', 'Té Chai Legacy', 20, 2100.00],
];

$stmt = $pdo->prepare(
    'INSERT INTO inventory (sku, nombre, stock, precio)
     VALUES (:sku, :nombre, :stock, :precio)'
);

foreach ($items as $item) {
    $stmt->execute([
        ':sku' => $item[0],
        ':nombre' => $item[1],
        ':stock' => $item[2],
        ':precio' => $item[3],
    ]);
}

echo "Legacy SQLite creado correctamente\n";
echo "Registros: " . count($items) . "\n";
echo "BD: {$dbPath}\n";
