<?php

header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);

    echo json_encode(
        ['error' => 'Method not allowed'],
        JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT
    );

    exit;
}

$dbPath = __DIR__ . '/data/inventory.sqlite';

if (!file_exists($dbPath)) {
    http_response_code(503);

    echo json_encode(
        ['error' => 'Legacy database unavailable'],
        JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT
    );

    exit;
}

try {
    $pdo = new PDO('sqlite:' . $dbPath);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);

    $sku = isset($_GET['sku'])
        ? trim($_GET['sku'])
        : '';

    if ($sku !== '') {
        $stmt = $pdo->prepare(
            'SELECT sku, nombre, stock, precio
             FROM inventory
             WHERE sku = :sku'
        );

        $stmt->execute([':sku' => $sku]);

        $item = $stmt->fetch();

        if (!$item) {
            http_response_code(404);

            echo json_encode(
                [
                    'count' => 0,
                    'items' => [],
                    'error' => 'SKU not found',
                ],
                JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT
            );

            exit;
        }

        echo json_encode(
            [
                'count' => 1,
                'items' => [$item],
            ],
            JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT
        );

        exit;
    }

    $stmt = $pdo->query(
        'SELECT sku, nombre, stock, precio
         FROM inventory
         ORDER BY sku'
    );

    $items = $stmt->fetchAll();

    echo json_encode(
        [
            'count' => count($items),
            'items' => $items,
        ],
        JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT
    );
} catch (Throwable $exception) {
    http_response_code(500);

    echo json_encode(
        ['error' => 'Legacy internal error'],
        JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT
    );
}
