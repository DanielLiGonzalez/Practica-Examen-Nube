<?php

header('Content-Type: application/json; charset=utf-8');

echo json_encode(
    [
        'service' => 'cafe-boreal-legacy',
        'status' => 'ok',
        'endpoint' => '/legacy/inventory',
    ],
    JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT
);
