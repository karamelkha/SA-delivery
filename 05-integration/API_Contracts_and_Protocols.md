# API Contracts and Integration Protocols — Delivery

## 1. Назначение документа

Документ определяет детальные API-контракты и интеграционные протоколы для информационной системы сервиса доставки еды «Delivery».

Документ является логическим продолжением артефактов:

- `01-requirements/Functional_Requirements.md`
- `01-requirements/NonFunctional_Requirements.md`
- `01-requirements/Order_Statuses.md`
- `01-requirements/Use_Case.md`
- `02-process-modeling/README.md`

## 2. Архитектурные предложения

### 2.1 Подход к взаимодействиям

1. Система должна предоставлять клиентским и операционным ролям синхронные REST API.
2. Система должна обрабатывать внешние интеграции в режиме at-least-once delivery с обязательной идемпотентностью.
3. Система должна фиксировать интеграционные события в `OrderHistoryEvent`.
4. Система должна разделять:

- жизненный цикл заказа в Delivery (in scope);
- внешний процесс возвратов (out of scope), но с формализованной интерфейсной границей.

### 2.2 Протоколы и стандарты

- Транспорт: HTTPS (TLS 1.2+).
- Формат: JSON UTF-8.
- Временные поля: RFC 3339 (`2026-02-13T10:15:30Z`).
- Денежные значения: `DECIMAL(10,2)` в JSON-строке (`"1250.50"`).
- Версионирование API: URL-префикс `/api/v1`.

## 3. Общие правила контрактов

### 3.1 Аутентификация и авторизация

1. Система должна использовать `Authorization: Bearer <JWT>` для ролей `Customer`, `Restaurant`, `Courier`, `Administrator`.
2. Система должна ограничивать доступ к ресурсам в соответствии с ролью (NFR-6, NFR-7).
3. Система должна использовать `mTLS` для исходящих system-to-system вызовов (`Delivery -> внешняя система`).
4. Система должна использовать `HMAC-SHA256` подпись для входящих webhook/callback (`внешняя система -> Delivery`).

### 3.2 Обязательные заголовки

- `X-Correlation-Id` — обязателен для всех запросов; формат `UUIDv4`.
- `Idempotency-Key` — обязателен для операций, изменяющих состояние (`POST`/`PATCH`/`PUT`); длина от `8` до `128` символов.
- `X-Request-Timestamp` — обязателен для интеграционных webhook/callback; формат RFC 3339 UTC.
- `X-Signature` — обязателен для интеграционных webhook/callback; алгоритм `HMAC-SHA256`.

Правила проверки заголовков:

1. Система должна отклонять запрос с некорректным `X-Correlation-Id` кодом `400 VALIDATION_ERROR`.
2. Система должна отклонять webhook/callback при отклонении времени `X-Request-Timestamp` от системного времени более чем на `300` секунд кодом `401 SIGNATURE_INVALID`.
3. Система должна вычислять `X-Signature` по канонической строке `{method}\n{path}\n{x-request-timestamp}\n{raw-body}`.

### 3.3 Идемпотентность и конкурентность

1. Система должна сохранять результат операции, изменяющей состояние, по ключу `Idempotency-Key`:
- не менее `24` часов для клиентских и внутренних API;
- не менее `7` суток для интеграционных операций оплаты/возврата.
2. Система должна возвращать ранее зафиксированный результат при повторе запроса с тем же `Idempotency-Key`, тем же методом и тем же нормализованным телом запроса.
3. Система должна возвращать `409 IDEMPOTENCY_CONFLICT`, если `Idempotency-Key` повторно используется с отличающимся телом запроса.
4. Система должна отклонять недопустимые переходы статусов с кодом `409 ORDER_STATUS_CONFLICT`.
5. Система должна применять optimistic locking для операций изменения статуса заказа через поле `version` в запросе.
6. Система должна возвращать `409 VERSION_CONFLICT`, если значение `version` в запросе не совпадает с текущей версией заказа.

### 3.4 Единая модель ошибок

Ошибка должна возвращаться в формате:

```json
{
  "error_code": "ORDER_STATUS_CONFLICT",
  "message": "Недопустимый переход статуса заказа",
  "details": {
    "order_id": 1254,
    "current_status": "PAID"
  },
  "correlation_id": "5c5f5d86-1e9f-4fdf-9f5f-3f2be8bd3f4a",
  "timestamp": "2026-02-13T10:15:30Z"
}
```

Базовые коды:

- `VALIDATION_ERROR`
- `UNAUTHORIZED`
- `FORBIDDEN`
- `NOT_FOUND`
- `ORDER_STATUS_CONFLICT`
- `VERSION_CONFLICT`
- `IDEMPOTENCY_CONFLICT`
- `SIGNATURE_INVALID`
- `INTEGRATION_UNAVAILABLE`
- `INTERNAL_ERROR`

## 4. Канонические доменные enum

### 4.1 Статусы заказа (API-значения)

| API enum                     | Бизнес-статус              |
| ---------------------------- | -------------------------- |
| `WAITING_PAYMENT`            | Ожидает оплаты             |
| `UNPAID`                     | Заказ не оплачен           |
| `PAID`                       | Оплачен                    |
| `RESTAURANT_CONFIRMED`       | Подтверждён рестораном     |
| `REJECTED`                   | Отклонён                   |
| `READY_FOR_DELIVERY`         | Готов к доставке           |
| `WAITING_COURIER_ASSIGNMENT` | Ожидает назначения курьера |
| `COURIER_NOT_ASSIGNED`       | Курьер не назначен         |
| `IN_TRANSIT`                 | В пути                     |
| `DELIVERED`                  | Доставлен                  |
| `CANCELLED`                  | Отменён                    |

### 4.2 Статусы оплаты

- `PAYMENT_PENDING`
- `PAYMENT_SUCCEEDED`
- `PAYMENT_FAILED`
- `PAYMENT_TIMED_OUT`

### 4.3 Статусы возврата (внешний процесс)

- `REFUND_REQUIRED`
- `REFUND_IN_PROGRESS`
- `REFUND_COMPLETED`
- `REFUND_FAILED`

### 4.4 Канонические коды ролей

| Role code | Бизнес-роль |
| --- | --- |
| `Customer` | Клиент |
| `Restaurant` | Ресторан |
| `Courier` | Курьер |
| `Administrator` | Администратор |
| `System` | Система |

### 4.5 Канонические `reason_code`

#### Причины отклонения заказа рестораном

- `OUT_OF_STOCK`
- `OUT_OF_CAPACITY`
- `TECHNICAL_UNAVAILABLE`

#### Причины недоставки

- `CLIENT_NOT_AVAILABLE`
- `CLIENT_REFUSED`
- `ADDRESS_UNREACHABLE`
- `SAFETY_RISK`
- `OTHER`

#### Причины отмены заказа администратором

- `NO_AVAILABLE_COURIER`
- `DELIVERY_IMPOSSIBLE`
- `OPERATIONAL_INCIDENT`

#### Причины инициирования возврата

- `RESTAURANT_REJECTED`
- `ADMIN_CANCELLED`

## 5. API-контракты по ролям

## 5.1 Клиентские API

### C-1. Получить список ресторанов

- `GET /api/v1/restaurants?page=1&page_size=20`
- Роль: `Customer`
- Связанные FR: `FR-1`
- Правила пагинации:
- `page` — целое число `>= 1`;
- `page_size` — целое число от `1` до `100`.
- Ответ `200 OK`:

```json
{
  "page": 1,
  "page_size": 20,
  "total": 1,
  "items": [
    {
      "restaurant_id": 101,
      "name": "Pizza Hub",
      "is_open": true
    }
  ]
}
```

### C-2. Получить меню ресторана

- `GET /api/v1/restaurants/{restaurant_id}/menu`
- Роль: `Customer`
- Связанные FR: `FR-2`

### C-3. Создать заказ

- `POST /api/v1/orders`
- Роль: `Customer`
- Заголовки: `X-Correlation-Id`, `Idempotency-Key`
- Связанные FR: `FR-3..FR-8`

Запрос:

```json
{
  "restaurant_id": 101,
  "delivery_address_id": 501,
  "items": [
    { "menu_item_id": 9001, "quantity": 2 },
    { "menu_item_id": 9008, "quantity": 1 }
  ]
}
```

Ответ `201 Created`:

```json
{
  "order_id": 1254,
  "order_status": "WAITING_PAYMENT",
  "payment_status": "PAYMENT_PENDING",
  "total_amount": "1290.00",
  "payment_deadline_at": "2026-02-13T10:30:00Z"
}
```

### C-4. Получить карточку заказа

- `GET /api/v1/orders/{order_id}`
- Роль: `Customer` (только свой заказ)
- Связанные FR: `FR-37`

### C-5. Инициировать оплату

- `POST /api/v1/orders/{order_id}/payments`
- Роль: `Customer`
- Заголовки: `X-Correlation-Id`, `Idempotency-Key`
- Связанные FR: `FR-9..FR-13`

Запрос:

```json
{
  "payment_method_token": "pm_tok_abc123"
}
```

Ответ `202 Accepted`:

```json
{
  "order_id": 1254,
  "payment_id": 7781,
  "payment_status": "PAYMENT_PENDING",
  "provider_redirect_url": "https://pay.example.com/session/xyz"
}
```

## 5.2 API ресторана

### R-1. Получить оплаченные заказы

- `GET /api/v1/restaurant/orders?status=PAID&page=1&page_size=20`
- Роль: `Restaurant`
- Связанные FR: `FR-19`

### R-2. Подтвердить или отклонить заказ

- `POST /api/v1/restaurant/orders/{order_id}/decision`
- Роль: `Restaurant`
- Заголовки: `X-Correlation-Id`, `Idempotency-Key`
- Связанные FR: `FR-20..FR-22`

Запрос:

```json
{
  "version": 7,
  "decision": "CONFIRM",
  "reason_code": null
}
```

Или:

```json
{
  "version": 7,
  "decision": "REJECT",
  "reason_code": "OUT_OF_STOCK"
}
```

### R-3. Отметить заказ как готовый к доставке

- `POST /api/v1/restaurant/orders/{order_id}/ready`
- Роль: `Restaurant`
- Связанные FR: `FR-23`

Запрос:

```json
{
  "version": 8
}
```

## 5.3 API курьера

### D-1. Получить назначенные заказы

- `GET /api/v1/courier/orders/assigned?page=1&page_size=20`
- Роль: `Courier`
- Связанные FR: `FR-26`, `FR-38`

### D-2. Подтвердить получение заказа

- `POST /api/v1/courier/orders/{order_id}/pickup-confirmation`
- Роль: `Courier`
- Связанные FR: `FR-29`

Запрос:

```json
{
  "version": 11
}
```

### D-3. Завершить доставку

- `POST /api/v1/courier/orders/{order_id}/deliver`
- Роль: `Courier`
- Связанные FR: `FR-30`

Запрос:

```json
{
  "version": 12
}
```

### D-4. Зафиксировать недоставку

- `POST /api/v1/courier/orders/{order_id}/delivery-failed`
- Роль: `Courier`
- Связанные FR: `FR-32`

Запрос:

```json
{
  "version": 12,
  "reason_code": "CLIENT_NOT_AVAILABLE",
  "comment": "Клиент не отвечает 15 минут"
}
```

## 5.4 API администратора

### A-1. Получить список заказов

- `GET /api/v1/admin/orders?status=...&from=...&to=...&page=1&page_size=50`
- Роль: `Administrator`
- Связанные FR: `FR-39`

### A-2. Получить детали заказа и историю

- `GET /api/v1/admin/orders/{order_id}`
- Роль: `Administrator`
- Связанные FR: `FR-40`

### A-3. Назначить курьера вручную

- `POST /api/v1/admin/orders/{order_id}/assign-courier`
- Роль: `Administrator`
- Связанные FR: `FR-35`

Запрос:

```json
{
  "version": 9,
  "courier_id": 410
}
```

### A-4. Отменить заказ

- `POST /api/v1/admin/orders/{order_id}/cancel`
- Роль: `Administrator`
- Связанные FR: `FR-36`

Запрос:

```json
{
  "version": 9,
  "reason_code": "NO_AVAILABLE_COURIER",
  "comment": "Отмена по итогам эскалации"
}
```

## 6. Интеграционные протоколы

## 6.1 Платёжный сервис

### P-1. Исходящий запрос на создание платёжной сессии

- Направление: Delivery -> Платёжный сервис
- Протокол: HTTPS REST
- Метод: `POST /payments`
- Связанные FR: `FR-10`, `FR-11`, `FR-12`

Запрос:

```json
{
  "merchant_order_id": "1254",
  "amount": "1290.00",
  "currency": "RUB",
  "callback_url": "https://delivery.example.com/api/v1/integrations/payment/results",
  "expires_at": "2026-02-13T10:30:00Z"
}
```

### P-2. Входящий webhook с результатом оплаты

- Направление: Платёжный сервис -> Delivery
- Протокол: HTTPS REST + HMAC подпись
- Метод: `POST /api/v1/integrations/payment/results`
- Связанные FR: `FR-11..FR-18`, `NFR-10`, `NFR-11`

Тело:

```json
{
  "provider_event_id": "evt_991827",
  "provider_payment_id": "pay_741852",
  "order_id": 1254,
  "result_status": "SUCCEEDED",
  "result_code": "00",
  "processed_at": "2026-02-13T10:16:02Z"
}
```

Правила обработки:

1. Система должна валидировать `X-Signature` и `X-Request-Timestamp`.
2. Система должна обрабатывать повтор webhook идемпотентно по `provider_event_id`.
3. Система должна переводить заказ в `PAID` только при `result_status=SUCCEEDED`.
4. Система должна оставлять заказ в `WAITING_PAYMENT` при `result_status=FAILED`.
5. Система должна переводить заказ в `UNPAID` только по таймеру оплаты (15 минут).
6. Система должна отклонять webhook как replay-атаку при отклонении `X-Request-Timestamp` более `300` секунд от системного времени.
7. Система должна возвращать `200 OK` не позднее `2` секунд после успешной валидации подписи и постановки события в обработку.

## 6.2 Интерфейсная граница с внешним процессом возвратов

### RF-1. Исходящее событие `RefundRequired`

- Направление: Delivery -> Внешний процесс возвратов
- Протокол: HTTPS REST (JSON)
- Базовый контракт: `POST /api/v1/integrations/refunds/requests`
- Связанные FR: `FR-42`, `FR-43`

Тело:

```json
{
  "refund_request_id": "rreq_20260213_0001",
  "order_id": 1254,
  "payment_id": 7781,
  "provider_payment_id": "pay_741852",
  "amount": "1290.00",
  "reason_code": "RESTAURANT_REJECTED",
  "initiated_at": "2026-02-13T11:05:00Z"
}
```

### RF-2. Входящий callback по возврату

- Направление: Внешний процесс возвратов -> Delivery
- Протокол: HTTPS REST + подпись
- Метод: `POST /api/v1/integrations/refunds/results`
- Связанные FR: `FR-44`, `FR-45`

Тело:

```json
{
  "refund_request_id": "rreq_20260213_0001",
  "order_id": 1254,
  "refund_status": "REFUND_COMPLETED",
  "provider_refund_id": "ref_557799",
  "reason_code": null,
  "processed_at": "2026-02-13T11:08:20Z"
}
```

Правила обработки:

1. Система должна фиксировать `REFUND_COMPLETED`/`REFUND_FAILED` в истории заказа.
2. Система не должна изменять финальный статус заказа (`REJECTED`/`CANCELLED`) по результату возврата.
3. Система должна обрабатывать дубликаты callback идемпотентно.
4. Система должна отклонять callback как replay-атаку при отклонении `X-Request-Timestamp` более `300` секунд от системного времени.
5. Система должна возвращать `200 OK` не позднее `2` секунд после успешной валидации подписи и постановки события в обработку.

## 7. Надёжность и производительность интеграций

1. Система должна применять retry policy для внешних вызовов: `3` попытки, backoff `5s -> 15s -> 45s`.
2. Система должна помещать неуспешные интеграционные сообщения в DLQ после исчерпания retry.
3. Система должна выполнять retry только для ошибок `408`, `429`, `5xx` и сетевых таймаутов.
4. Система должна поддерживать таймаут исходящего интеграционного HTTP-вызова:
- `connect timeout` не более `3` секунд;
- `read timeout` не более `10` секунд.
5. Система должна хранить сообщения в DLQ не менее `7` суток.
6. Система должна обеспечивать показатели из `NFR-17..NFR-27`.

## 8. Безопасность и аудит интеграций

1. Система должна при записи технических и аудиторных логов выполнять необратимое маскирование чувствительных данных по следующим правилам:

- значения `Authorization`, `X-Signature`, `payment_method_token` система должна заменять на `[REDACTED]`;
- значения `phone` система должна маскировать до формата `+7******1234`;
- значения `email` система должна маскировать до формата `u***@domain.tld`;
- значения `full_address` и `comment` система должна логировать только в маскированном виде `[REDACTED_ADDRESS]` и `[REDACTED_COMMENT]`;
- значения карточных реквизитов (`pan`, `cvv`, `expiry`) система не должна писать в логи ни при каких условиях.

2. Система должна хранить только разрешённые платёжные атрибуты (без карточных реквизитов) (NFR-9).
3. Система должна логировать:

- `correlation_id`;
- интеграционный endpoint;
- код ответа;
- длительность вызова;
- итоговый бизнес-результат.

## 9. Критерии приемки API-контрактов

1. Все методы, изменяющие состояние, поддерживают `Idempotency-Key`.
2. Все внешние webhook/callback валидируют подпись.
3. Недопустимые переходы статусов возвращают `409 ORDER_STATUS_CONFLICT`.
4. Повторные интеграционные сообщения не приводят к дублям заказа/платежа/событий.
5. Конкурентное изменение статуса с неактуальной `version` возвращает `409 VERSION_CONFLICT`.
6. Webhook/callback с отклонением `X-Request-Timestamp` более `300` секунд отклоняются.
7. Зафиксирована трассировка endpoint/событий к FR/NFR/UC.
## 10. Примеры и runbook

Практические примеры HTTP-запросов/ответов и операционный runbook вынесены в отдельный документ:

- `05-integration/API_Examples_and_Runbook.md`
