# API Examples and Runbook — Delivery

## 1. Назначение документа

Документ содержит практические примеры использования контрактов API и минимальный операционный runbook для MVP-интеграций.

Документ дополняет «чистый» контракт:

- `05-integration/API_Contracts_and_Protocols.md`

## 2. Примеры HTTP-контрактов (MVP)

Ниже приведены ключевые контракты MVP в формате, приближенном к публичным REST API-эталонам: endpoint, пример URL, полный HTTP-запрос и полный HTTP-ответ.

### 10.1 Создание заказа

Компания: Delivery  
Endpoint: `POST /api/v1/orders`

Пример:

`POST https://delivery.example.com/api/v1/orders`

Полный пример HTTP-запроса:

```bash
curl -X POST "https://delivery.example.com/api/v1/orders" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt>" \
  -H "X-Correlation-Id: 6cf2d607-7e7f-4fb1-b9cb-194d00f5b285" \
  -H "Idempotency-Key: create-order-1254" \
  -d '{
    "restaurant_id": 101,
    "delivery_address_id": 501,
    "items": [
      { "menu_item_id": 9001, "quantity": 2 },
      { "menu_item_id": 9008, "quantity": 1 }
    ]
  }'
```

Полный пример HTTP-ответа:

```json
{
  "order_id": 1254,
  "order_status": "WAITING_PAYMENT",
  "payment_status": "PAYMENT_PENDING",
  "total_amount": "1290.00",
  "payment_deadline_at": "2026-02-13T10:30:00Z",
  "version": 1
}
```

Коды ответа:

- `201 Created` — заказ создан;
- `400 VALIDATION_ERROR` — ошибка в структуре/значениях запроса;
- `401 UNAUTHORIZED` — отсутствует/некорректный JWT;
- `409 IDEMPOTENCY_CONFLICT` — конфликт повторного `Idempotency-Key`.

### 10.2 Инициирование оплаты

Компания: Delivery  
Endpoint: `POST /api/v1/orders/{order_id}/payments`

Пример:

`POST https://delivery.example.com/api/v1/orders/1254/payments`

Полный пример HTTP-запроса:

```bash
curl -X POST "https://delivery.example.com/api/v1/orders/1254/payments" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt>" \
  -H "X-Correlation-Id: 0f1309dd-474d-47f0-a0fb-fd596fd02ad8" \
  -H "Idempotency-Key: pay-order-1254-attempt-1" \
  -d '{
    "payment_method_token": "pm_tok_abc123"
  }'
```

Полный пример HTTP-ответа:

```json
{
  "order_id": 1254,
  "payment_id": 7781,
  "payment_status": "PAYMENT_PENDING",
  "provider_redirect_url": "https://pay.example.com/session/xyz"
}
```

Коды ответа:

- `202 Accepted` — платёжная операция инициирована;
- `400 VALIDATION_ERROR`;
- `401 UNAUTHORIZED`;
- `409 ORDER_STATUS_CONFLICT` — заказ не в статусе `WAITING_PAYMENT`.

### 10.3 Webhook результата оплаты

Компания: Delivery  
Endpoint: `POST /api/v1/integrations/payment/results`

Пример:

`POST https://delivery.example.com/api/v1/integrations/payment/results`

Полный пример HTTP-запроса:

```bash
curl -X POST "https://delivery.example.com/api/v1/integrations/payment/results" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "X-Request-Timestamp: 2026-02-13T10:16:02Z" \
  -H "X-Signature: <hmac-sha256>" \
  -H "X-Correlation-Id: 6fd0e3ea-8f49-4372-a17f-bf8528b0ba17" \
  -d '{
    "provider_event_id": "evt_991827",
    "provider_payment_id": "pay_741852",
    "order_id": 1254,
    "result_status": "SUCCEEDED",
    "result_code": "00",
    "processed_at": "2026-02-13T10:16:02Z"
  }'
```

Полный пример HTTP-ответа:

```json
{
  "status": "accepted",
  "correlation_id": "6fd0e3ea-8f49-4372-a17f-bf8528b0ba17"
}
```

Коды ответа:

- `200 OK` — событие принято в обработку;
- `401 SIGNATURE_INVALID` — подпись или timestamp невалидны;
- `409 IDEMPOTENCY_CONFLICT` — конфликт дубликата с разным payload.

### 10.4 Решение ресторана по заказу

Компания: Delivery  
Endpoint: `POST /api/v1/restaurant/orders/{order_id}/decision`

Пример:

`POST https://delivery.example.com/api/v1/restaurant/orders/1254/decision`

Полный пример HTTP-запроса:

```bash
curl -X POST "https://delivery.example.com/api/v1/restaurant/orders/1254/decision" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt>" \
  -H "X-Correlation-Id: a6ff9d5f-c5bc-4b9d-8b31-5f9f105f7969" \
  -H "Idempotency-Key: restaurant-decision-1254-v7" \
  -d '{
    "version": 7,
    "decision": "REJECT",
    "reason_code": "OUT_OF_STOCK"
  }'
```

Полный пример HTTP-ответа:

```json
{
  "order_id": 1254,
  "order_status": "REJECTED",
  "version": 8,
  "refund_status": "REFUND_REQUIRED"
}
```

Коды ответа:

- `200 OK`;
- `409 VERSION_CONFLICT`;
- `409 ORDER_STATUS_CONFLICT`.

### 10.5 Отмена заказа администратором

Компания: Delivery  
Endpoint: `POST /api/v1/admin/orders/{order_id}/cancel`

Пример:

`POST https://delivery.example.com/api/v1/admin/orders/1254/cancel`

Полный пример HTTP-запроса:

```bash
curl -X POST "https://delivery.example.com/api/v1/admin/orders/1254/cancel" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <jwt>" \
  -H "X-Correlation-Id: 17ef7b0d-36bf-4bd3-afdd-a3e6dfb8e194" \
  -H "Idempotency-Key: admin-cancel-1254-v9" \
  -d '{
    "version": 9,
    "reason_code": "NO_AVAILABLE_COURIER",
    "comment": "Отмена по итогам эскалации"
  }'
```

Полный пример HTTP-ответа:

```json
{
  "order_id": 1254,
  "order_status": "CANCELLED",
  "version": 10,
  "refund_status": "REFUND_REQUIRED"
}
```

Коды ответа:

- `200 OK`;
- `409 VERSION_CONFLICT`;
- `409 ORDER_STATUS_CONFLICT`;
- `403 FORBIDDEN`.

### 10.6 Исходящий запрос `RefundRequired`

Компания: Delivery  
Endpoint: `POST /api/v1/integrations/refunds/requests`

Пример:

`POST https://refunds.example.com/api/v1/integrations/refunds/requests`

Полный пример HTTP-запроса:

```bash
curl -X POST "https://refunds.example.com/api/v1/integrations/refunds/requests" \
  -H "Accept: application/json" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: 7f3c6fcc-2c5f-4f24-a299-c8d15a5338f3" \
  -H "Idempotency-Key: refund-required-1254-1" \
  -d '{
    "refund_request_id": "rreq_20260213_0001",
    "order_id": 1254,
    "payment_id": 7781,
    "provider_payment_id": "pay_741852",
    "amount": "1290.00",
    "reason_code": "ADMIN_CANCELLED",
    "initiated_at": "2026-02-13T11:05:00Z"
  }'
```

Примечание: mTLS применяется на уровне TLS-соединения; отдельный HTTP-заголовок для mTLS в контракте не используется.

Полный пример HTTP-ответа:

```json
{
  "refund_request_id": "rreq_20260213_0001",
  "refund_status": "REFUND_IN_PROGRESS",
  "accepted_at": "2026-02-13T11:05:03Z"
}
```

Коды ответа:

- `202 Accepted` — запрос возврата принят;
- `400 VALIDATION_ERROR`;
- `409 IDEMPOTENCY_CONFLICT`;
- `503 INTEGRATION_UNAVAILABLE`.

## 3. Runbook интеграций (MVP)

### 3.1 Инцидент: не принимаются webhook оплаты

1. Проверить валидность `X-Signature` и формат `X-Request-Timestamp`.
2. Проверить отклонение времени между источником и системой (не более 300 секунд).
3. Проверить, что `provider_event_id` не был ранее обработан с иным payload.
4. При недоступности внешнего провайдера зафиксировать событие интеграционной ошибки и перевести обработку в retry.

### 3.2 Инцидент: повторяющиеся callback возвратов

1. Проверить идемпотентность по `refund_request_id`.
2. Проверить, что повторные callback не изменяют финальный статус заказа (`REJECTED`/`CANCELLED`).
3. Проверить наличие записи `RefundCompleted`/`RefundFailed` в истории заказа.

### 3.3 Инцидент: конфликт версии при смене статуса

1. Проверить актуальное значение `version` заказа.
2. Повторить операцию с обновлённой `version` только после повторного чтения карточки заказа.
3. Убедиться, что возврат ошибки соответствует коду `409 VERSION_CONFLICT`.

### 3.4 Контрольный чек-лист перед релизом интеграции

1. Все state-changing endpoint поддерживают `Idempotency-Key`.
2. Все webhook/callback валидируют подпись и timestamp.
3. Настроены retry, DLQ и мониторинг длительности внешних вызовов.
4. Логи маскируют чувствительные данные в соответствии с контрактом.
5. Трассировка endpoint/событий к FR/NFR/UC актуальна.
