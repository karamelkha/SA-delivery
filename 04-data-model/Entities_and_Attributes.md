# Entities and Attributes — Delivery (Target MVP)

## 1. Назначение документа

Документ фиксирует целевую логическую ER-структуру MVP для системы доставки еды «Delivery».

Система должна использовать данную модель как единый источник для:

- проектирования API и интеграционных контрактов;
- реализации бизнес-процессов и таймеров;
- обеспечения целостности данных и аудита.

Документ описывает логическую модель данных (сущности, атрибуты, связи, ключевые ограничения) и не содержит DDL-реализацию.

---

## 2. Принципы модели MVP

1. Система должна хранить один актуальный статус заказа и полную историю изменений.
2. Система должна поддерживать повторные попытки оплаты в рамках одного заказа.
3. Система должна поддерживать optimistic locking для конкурентных изменений статуса.
4. Система должна обеспечивать идемпотентную обработку mutating-операций API и внешних webhook/callback.
5. Система должна фиксировать интерфейсную границу с внешним процессом возвратов через отдельную сущность.
6. Система не должна хранить карточные реквизиты (`pan`, `cvv`, `expiry`).
7. Система должна иметь выделенную модель учетных записей пользователей для реализации `FR-41` (управление пользователями, блокировка, деактивация, аудит изменений учетной записи).

---

## 3. Канонические справочники (enum/коды)

### 3.1 Статус заказа (`order_status`)

- `WAITING_PAYMENT`
- `UNPAID`
- `PAID`
- `RESTAURANT_CONFIRMED`
- `REJECTED`
- `READY_FOR_DELIVERY`
- `WAITING_COURIER_ASSIGNMENT`
- `COURIER_NOT_ASSIGNED`
- `IN_TRANSIT`
- `DELIVERED`
- `CANCELLED`

### 3.2 Статус оплаты (`payment_status`)

- `PAYMENT_PENDING`
- `PAYMENT_SUCCEEDED`
- `PAYMENT_FAILED`
- `PAYMENT_TIMED_OUT`

### 3.3 Статус возврата (`refund_status`)

- `REFUND_REQUIRED`
- `REFUND_IN_PROGRESS`
- `REFUND_COMPLETED`
- `REFUND_FAILED`

### 3.4 Роль инициатора (`actor_role`)

- `Customer`
- `Restaurant`
- `Courier`
- `Administrator`
- `System`

### 3.5 Статус учетной записи (`account_status`)

- `ACTIVE`
- `BLOCKED`
- `DISABLED`
- `DELETED`

---

## 4. Сущности и атрибуты

### 4.1 Клиент (`Customer`)

| Поле          | Тип          | Описание                         | Ключ             |
| ------------- | ------------ | -------------------------------- | ---------------- |
| `customer_id` | BIGINT       | Идентификатор клиента            | PK               |
| `user_account_id` | BIGINT    | Учетная запись клиента           | FK -> UserAccount.user_account_id, UNIQUE |
| `full_name`   | VARCHAR(200) | Отображаемое имя                 |                  |
| `phone`       | VARCHAR(20)  | Телефон (нормализованный формат) | UNIQUE           |
| `email`       | VARCHAR(254) | Email                            | UNIQUE, nullable |
| `is_active`   | BOOLEAN      | Признак активности               |                  |
| `created_at`  | TIMESTAMP    | Дата создания                    |                  |
| `updated_at`  | TIMESTAMP    | Дата обновления                  |                  |

---

### 4.2 Адрес клиента (`CustomerAddress`)

| Поле           | Тип          | Описание                       | Ключ                       |
| -------------- | ------------ | ------------------------------ | -------------------------- |
| `address_id`   | BIGINT       | Идентификатор адреса           | PK                         |
| `customer_id`  | BIGINT       | Владелец адреса                | FK -> Customer.customer_id |
| `label`        | VARCHAR(100) | Метка адреса (`Дом`, `Работа`) |                            |
| `full_address` | VARCHAR(500) | Полный адрес доставки          |                            |
| `comment`      | VARCHAR(500) | Комментарий для курьера        | nullable                   |
| `is_default`   | BOOLEAN      | Адрес по умолчанию             |                            |
| `is_active`    | BOOLEAN      | Признак актуальности адреса    |                            |
| `created_at`   | TIMESTAMP    | Дата создания                  |                            |
| `updated_at`   | TIMESTAMP    | Дата обновления                |                            |

Критичное ограничение:

- Система должна обеспечивать, что `Order.delivery_address_id` принадлежит тому же `customer_id`, что и заказ.
- Система должна иметь техническое ограничение `UNIQUE(customer_id, address_id)` в `CustomerAddress`.

---

### 4.3 Ресторан (`Restaurant`)

| Поле            | Тип          | Описание                        | Ключ |
| --------------- | ------------ | ------------------------------- | ---- |
| `restaurant_id` | BIGINT       | Идентификатор ресторана         | PK   |
| `user_account_id` | BIGINT     | Учетная запись ресторана-оператора (MVP: 1 основная учетная запись) | FK -> UserAccount.user_account_id, UNIQUE |
| `name`          | VARCHAR(255) | Название ресторана              |      |
| `address`       | VARCHAR(500) | Адрес ресторана                 |      |
| `phone`         | VARCHAR(20)  | Контактный телефон              |      |
| `is_open`       | BOOLEAN      | Признак доступности для заказов |      |
| `is_active`     | BOOLEAN      | Признак активности в системе    |      |
| `created_at`    | TIMESTAMP    | Дата создания                   |      |
| `updated_at`    | TIMESTAMP    | Дата обновления                 |      |

---

### 4.4 Позиция меню (`MenuItem`)

| Поле            | Тип           | Описание              | Ключ                           |
| --------------- | ------------- | --------------------- | ------------------------------ |
| `menu_item_id`  | BIGINT        | Идентификатор позиции | PK                             |
| `restaurant_id` | BIGINT        | Ресторан-владелец     | FK -> Restaurant.restaurant_id |
| `name`          | VARCHAR(255)  | Наименование блюда    |                                |
| `description`   | VARCHAR(1000) | Описание              | nullable                       |
| `price`         | DECIMAL(10,2) | Цена                  |                                |
| `currency`      | CHAR(3)       | Валюта (`RUB`)        |                                |
| `is_available`  | BOOLEAN       | Доступность позиции   |                                |
| `created_at`    | TIMESTAMP     | Дата создания         |                                |
| `updated_at`    | TIMESTAMP     | Дата обновления       |                                |

---

### 4.5 Курьер (`Courier`)

| Поле             | Тип          | Описание                                             | Ключ   |
| ---------------- | ------------ | ---------------------------------------------------- | ------ |
| `courier_id`     | BIGINT       | Идентификатор курьера                                | PK     |
| `user_account_id`| BIGINT       | Учетная запись курьера                               | FK -> UserAccount.user_account_id, UNIQUE |
| `full_name`      | VARCHAR(200) | Имя курьера                                          |        |
| `phone`          | VARCHAR(20)  | Телефон                                              | UNIQUE |
| `courier_status` | VARCHAR(32)  | Текущая доступность (`AVAILABLE`, `BUSY`, `OFFLINE`) |        |
| `is_active`      | BOOLEAN      | Признак активности                                   |        |
| `created_at`     | TIMESTAMP    | Дата создания                                        |        |
| `updated_at`     | TIMESTAMP    | Дата обновления                                      |        |

---

### 4.6 Администратор (`Administrator`)

| Поле         | Тип          | Описание                     | Ключ   |
| ------------ | ------------ | ---------------------------- | ------ |
| `admin_id`   | BIGINT       | Идентификатор администратора | PK     |
| `user_account_id` | BIGINT   | Учетная запись администратора| FK -> UserAccount.user_account_id, UNIQUE |
| `full_name`  | VARCHAR(200) | Имя                          |        |
| `email`      | VARCHAR(254) | Логин/email                  | UNIQUE |
| `is_active`  | BOOLEAN      | Признак активности           |        |
| `created_at` | TIMESTAMP    | Дата создания                |        |
| `updated_at` | TIMESTAMP    | Дата обновления              |        |

---

### 4.6.1 Учетная запись пользователя (`UserAccount`)

| Поле | Тип | Описание | Ключ |
| --- | --- | --- | --- |
| `user_account_id` | BIGINT | Идентификатор учетной записи | PK |
| `login` | VARCHAR(120) | Уникальный логин (email/phone/usercode) | UNIQUE |
| `password_hash` | VARCHAR(255) | Хэш пароля (для `auth_provider=LOCAL`) | nullable |
| `auth_provider` | VARCHAR(32) | Провайдер аутентификации (`LOCAL`, `EXTERNAL`) |  |
| `external_subject_id` | VARCHAR(128) | Идентификатор пользователя во внешнем IdP | UNIQUE, nullable |
| `account_status` | VARCHAR(32) | Статус учетной записи (`account_status`) |  |
| `failed_login_attempts` | INTEGER | Количество подряд неуспешных входов |  |
| `blocked_until` | TIMESTAMP | Время до окончания блокировки | nullable |
| `last_login_at` | TIMESTAMP | Время последнего успешного входа | nullable |
| `created_at` | TIMESTAMP | Дата создания |  |
| `updated_at` | TIMESTAMP | Дата обновления |  |
| `deactivated_at` | TIMESTAMP | Время деактивации/удаления | nullable |

Критичные ограничения:

- Система должна обеспечивать связь `1:1` между `UserAccount` и профильной сущностью роли (`Customer`, `Restaurant`, `Courier`, `Administrator`) через `user_account_id`.
- Система должна обеспечивать одну роль на одну учетную запись в рамках MVP.
- Система должна запрещать активные учетные записи без профильной сущности роли.
- Система должна фиксировать изменения `account_status` в выделенном журнале `UserAccountAudit`.

---

### 4.7 Заказ (`Order`)

| Поле                             | Тип           | Описание                                      | Ключ                                      |
| -------------------------------- | ------------- | --------------------------------------------- | ----------------------------------------- |
| `order_id`                       | BIGINT        | Идентификатор заказа                          | PK                                        |
| `customer_id`                    | BIGINT        | Клиент                                        | FK -> Customer.customer_id                |
| `restaurant_id`                  | BIGINT        | Ресторан                                      | FK -> Restaurant.restaurant_id            |
| `delivery_address_id`            | BIGINT        | Адрес доставки                                | FK -> CustomerAddress.address_id          |
| `courier_id`                     | BIGINT        | Назначенный курьер                            | FK -> Courier.courier_id, nullable        |
| `order_status`                   | VARCHAR(64)   | Текущий статус заказа (`order_status`)        |                                           |
| `current_payment_status`         | VARCHAR(64)   | Актуальный статус оплаты (`payment_status`)   |                                           |
| `current_payment_id`             | BIGINT        | Ссылка на последнюю актуальную попытку оплаты | FK -> PaymentAttempt.payment_id, nullable |
| `total_amount`                   | DECIMAL(10,2) | Итоговая сумма заказа                         |                                           |
| `currency`                       | CHAR(3)       | Валюта заказа                                 |                                           |
| `payment_deadline_at`            | TIMESTAMP     | Дедлайн оплаты (таймер 15 минут)              |                                           |
| `courier_assignment_deadline_at` | TIMESTAMP     | Предельный срок назначения курьера            | nullable                                  |
| `next_assignment_attempt_at`     | TIMESTAMP     | Следующая попытка назначения курьера          | nullable                                  |
| `version`                        | BIGINT        | Версия агрегата для optimistic locking        |                                           |
| `created_at`                     | TIMESTAMP     | Дата создания                                 |                                           |
| `updated_at`                     | TIMESTAMP     | Дата обновления                               |                                           |
| `closed_at`                      | TIMESTAMP     | Дата финализации заказа                       | nullable                                  |

Критичные ограничения:

- Система должна повышать `version` при каждом изменении статуса заказа.
- Система должна хранить только один актуальный `order_status` на заказ.
- Система должна считать финальными статусы `UNPAID`, `REJECTED`, `DELIVERED`, `CANCELLED`.
- Система должна обеспечивать составной внешний ключ `FK (customer_id, delivery_address_id) -> CustomerAddress(customer_id, address_id)`.

---

### 4.8 Строка заказа (`OrderItem`)

| Поле                 | Тип           | Описание                             | Ключ                        |
| -------------------- | ------------- | ------------------------------------ | --------------------------- |
| `order_item_id`      | BIGINT        | Идентификатор строки                 | PK                          |
| `order_id`           | BIGINT        | Ссылка на заказ                      | FK -> Order.order_id        |
| `menu_item_id`       | BIGINT        | Ссылка на позицию меню               | FK -> MenuItem.menu_item_id |
| `item_name_snapshot` | VARCHAR(255)  | Наименование на момент оформления    |                             |
| `unit_price`         | DECIMAL(10,2) | Цена за единицу на момент оформления |                             |
| `quantity`           | INTEGER       | Количество                           |                             |
| `line_total`         | DECIMAL(10,2) | Итог по строке                       |                             |
| `created_at`         | TIMESTAMP     | Дата создания                        |                             |

---

### 4.9 Попытка оплаты (`PaymentAttempt`)

| Поле                   | Тип           | Описание                                        | Ключ                         |
| ---------------------- | ------------- | ----------------------------------------------- | ---------------------------- |
| `payment_id`           | BIGINT        | Идентификатор попытки оплаты                    | PK                           |
| `order_id`             | BIGINT        | Ссылка на заказ                                 | FK -> Order.order_id         |
| `attempt_no`           | INTEGER       | Номер попытки оплаты в рамках заказа            | UNIQUE(order_id, attempt_no) |
| `payment_status`       | VARCHAR(64)   | Статус попытки (`payment_status`)               |                              |
| `amount`               | DECIMAL(10,2) | Сумма попытки оплаты                            |                              |
| `currency`             | CHAR(3)       | Валюта                                          |                              |
| `payment_provider`     | VARCHAR(100)  | Провайдер оплаты                                |                              |
| `provider_payment_id`  | VARCHAR(128)  | Идентификатор платежа у провайдера              | UNIQUE, nullable             |
| `provider_result_code` | VARCHAR(64)   | Код результата провайдера                       | nullable                     |
| `provider_event_id`    | VARCHAR(128)  | Идентификатор входящего webhook-события         | UNIQUE, nullable             |
| `idempotency_key`      | VARCHAR(128)  | Ключ идемпотентности клиентской операции оплаты | nullable                     |
| `requested_at`         | TIMESTAMP     | Время создания платежной сессии                 |                              |
| `result_received_at`   | TIMESTAMP     | Время получения итогового результата            | nullable                     |
| `expires_at`           | TIMESTAMP     | Срок действия платёжной сессии                  |                              |
| `created_at`           | TIMESTAMP     | Дата создания записи                            |                              |
| `updated_at`           | TIMESTAMP     | Дата обновления записи                          |                              |

Критичные ограничения:

- `Order 1 -> N PaymentAttempt`.
- Для одного заказа система должна иметь не более одной успешной попытки (`PAYMENT_SUCCEEDED`).
- Система должна иметь техническое ограничение вида `UNIQUE(order_id) WHERE payment_status='PAYMENT_SUCCEEDED'`.

---

### 4.10 Запрос на возврат (`RefundRequest`)

| Поле                 | Тип           | Описание                                           | Ключ                            |
| -------------------- | ------------- | -------------------------------------------------- | ------------------------------- |
| `refund_request_id`  | VARCHAR(64)   | Идентификатор запроса возврата                     | PK                              |
| `order_id`           | BIGINT        | Заказ-источник                                     | FK -> Order.order_id, UNIQUE    |
| `payment_id`         | BIGINT        | Успешная оплата, по которой требуется возврат      | FK -> PaymentAttempt.payment_id |
| `reason_code`        | VARCHAR(64)   | Причина (`RESTAURANT_REJECTED`, `ADMIN_CANCELLED`) |                                 |
| `refund_status`      | VARCHAR(64)   | Состояние возврата (`refund_status`)               |                                 |
| `amount`             | DECIMAL(10,2) | Сумма возврата                                     |                                 |
| `provider_refund_id` | VARCHAR(128)  | Идентификатор возврата у внешней системы           | UNIQUE, nullable                |
| `last_error_code`    | VARCHAR(64)   | Код последней ошибки внешнего процесса             | nullable                        |
| `last_error_message` | VARCHAR(500)  | Текст последней ошибки                             | nullable                        |
| `initiated_at`       | TIMESTAMP     | Время формирования `RefundRequired`                |                                 |
| `processed_at`       | TIMESTAMP     | Время получения финального результата возврата     | nullable                        |
| `created_at`         | TIMESTAMP     | Дата создания                                      |                                 |
| `updated_at`         | TIMESTAMP     | Дата обновления                                    |                                 |

Критичные ограничения:

- Система должна создавать `RefundRequest` только для заказов в `REJECTED` или `CANCELLED` при успешной оплате.
- Результат возврата не должен менять финальный `order_status`.

---

### 4.11 История заказа (`OrderHistoryEvent`)

| Поле                 | Тип          | Описание                                                                                                                                                       | Ключ                 |
| -------------------- | ------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------- |
| `event_id`           | BIGINT       | Идентификатор события                                                                                                                                          | PK                   |
| `order_id`           | BIGINT       | Заказ                                                                                                                                                          | FK -> Order.order_id |
| `event_type`         | VARCHAR(64)  | Тип события (`ORDER_STATUS_CHANGED`, `PAYMENT_STATUS_CHANGED`, `REFUND_REQUIRED`, `REFUND_COMPLETED`, `REFUND_FAILED`, `DELIVERY_FAILED`, `INTEGRATION_ERROR`) |                      |
| `actor_role`         | VARCHAR(32)  | Роль инициатора (`actor_role`)                                                                                                                                 |                      |
| `actor_id`           | BIGINT       | Идентификатор инициатора в своей роли                                                                                                                          | nullable             |
| `previous_value`     | VARCHAR(128) | Предыдущее значение                                                                                                                                            | nullable             |
| `new_value`          | VARCHAR(128) | Новое значение                                                                                                                                                 | nullable             |
| `reason_code`        | VARCHAR(64)  | Код причины                                                                                                                                                    | nullable             |
| `description`        | VARCHAR(500) | Комментарий или пояснение                                                                                                                                      | nullable             |
| `correlation_id`     | UUID         | Сквозной идентификатор запроса/процесса                                                                                                                        |                      |
| `event_payload_json` | JSON         | Технические детали события (без чувствительных данных)                                                                                                         | nullable             |
| `created_at`         | TIMESTAMP    | Время фиксации события                                                                                                                                         |                      |

---

### 4.12 Идемпотентность API (`IdempotencyRecord`)

| Поле                    | Тип          | Описание                                                                  | Ключ     |
| ----------------------- | ------------ | ------------------------------------------------------------------------- | -------- |
| `idempotency_record_id` | BIGINT       | Идентификатор записи                                                      | PK       |
| `idempotency_key`       | VARCHAR(128) | Ключ идемпотентности                                                      |          |
| `operation_name`        | VARCHAR(100) | Имя операции (`CREATE_ORDER`, `INIT_PAYMENT`, `RESTAURANT_DECISION`, ...) |          |
| `actor_role`            | VARCHAR(32)  | Роль инициатора                                                           |          |
| `actor_id`              | BIGINT       | Идентификатор инициатора                                                  |          |
| `request_hash`          | CHAR(64)     | Хеш нормализованного запроса                                              |          |
| `response_status_code`  | INTEGER      | HTTP-код сохраненного результата                                          |          |
| `response_body_json`    | JSON         | Сохраненный ответ операции                                                |          |
| `resource_type`         | VARCHAR(64)  | Тип ресурса (`Order`, `PaymentAttempt`, ...)                              | nullable |
| `resource_id`           | VARCHAR(64)  | Идентификатор ресурса                                                     | nullable |
| `expires_at`            | TIMESTAMP    | Срок хранения ключа                                                       |          |
| `created_at`            | TIMESTAMP    | Дата создания                                                             |          |

Критичное ограничение:

- `UNIQUE (operation_name, actor_role, actor_id, idempotency_key)`.

---

### 4.13 Интеграционные сообщения (`IntegrationMessage`)

| Поле                     | Тип          | Описание                                                        | Ключ                                            |
| ------------------------ | ------------ | --------------------------------------------------------------- | ----------------------------------------------- |
| `integration_message_id` | BIGINT       | Идентификатор сообщения                                         | PK                                              |
| `direction`              | VARCHAR(16)  | Направление (`OUTBOUND`, `INBOUND`)                             |                                                 |
| `message_type`           | VARCHAR(64)  | Тип (`PAYMENT_RESULT`, `REFUND_REQUIRED`, `REFUND_RESULT`)      |                                                 |
| `external_event_id`      | VARCHAR(128) | Идентификатор внешнего события                                  | UNIQUE, nullable                                |
| `order_id`               | BIGINT       | Связанный заказ                                                 | FK -> Order.order_id, nullable                  |
| `payment_id`             | BIGINT       | Связанная попытка оплаты                                        | FK -> PaymentAttempt.payment_id, nullable       |
| `refund_request_id`      | VARCHAR(64)  | Связанный запрос возврата                                       | FK -> RefundRequest.refund_request_id, nullable |
| `correlation_id`         | UUID         | Сквозной идентификатор                                          |                                                 |
| `payload_json`           | JSON         | Тело интеграционного сообщения                                  |                                                 |
| `processing_status`      | VARCHAR(32)  | Состояние (`RECEIVED`, `PENDING`, `PROCESSED`, `FAILED`, `DLQ`) |                                                 |
| `retry_count`            | INTEGER      | Число попыток обработки/отправки                                |                                                 |
| `next_retry_at`          | TIMESTAMP    | Время следующей попытки                                         | nullable                                        |
| `last_error`             | VARCHAR(500) | Последняя ошибка                                                | nullable                                        |
| `created_at`             | TIMESTAMP    | Дата создания                                                   |                                                 |
| `updated_at`             | TIMESTAMP    | Дата обновления                                                 |                                                 |

---

### 4.14 Аудит учетных записей (`UserAccountAudit`)

| Поле | Тип | Описание | Ключ |
| --- | --- | --- | --- |
| `user_account_audit_id` | BIGINT | Идентификатор записи аудита | PK |
| `user_account_id` | BIGINT | Учетная запись | FK -> UserAccount.user_account_id |
| `event_type` | VARCHAR(64) | Тип события (`ACCOUNT_CREATED`, `ACCOUNT_STATUS_CHANGED`, `ACCOUNT_UPDATED`) |  |
| `actor_role` | VARCHAR(32) | Роль инициатора (`actor_role`) |  |
| `actor_id` | BIGINT | Идентификатор инициатора | nullable |
| `previous_value` | VARCHAR(128) | Предыдущее значение статуса/поля | nullable |
| `new_value` | VARCHAR(128) | Новое значение статуса/поля | nullable |
| `reason_code` | VARCHAR(64) | Причина изменения | nullable |
| `correlation_id` | UUID | Сквозной идентификатор запроса |  |
| `created_at` | TIMESTAMP | Время фиксации изменения |  |

---

## 5. Ключевые связи (кардинальности)

- `Customer 1 -> N CustomerAddress`
- `Customer 1 -> N Order`
- `UserAccount 1 -> 0..1 Customer`
- `UserAccount 1 -> 0..1 Restaurant`
- `UserAccount 1 -> 0..1 Courier`
- `UserAccount 1 -> 0..1 Administrator`
- `UserAccount 1 -> N UserAccountAudit`
- `Restaurant 1 -> N MenuItem`
- `Restaurant 1 -> N Order`
- `Courier 1 -> N Order` (опционально по `Order.courier_id`)
- `Order 1 -> N OrderItem`
- `Order 1 -> N PaymentAttempt`
- `Order 1 -> 0..1 RefundRequest`
- `Order 1 -> N OrderHistoryEvent`
- `Order 1 -> N IntegrationMessage`
- `PaymentAttempt 1 -> N IntegrationMessage` (опционально)
- `RefundRequest 1 -> N IntegrationMessage` (опционально)

---

## 6. Обязательные ограничения целостности MVP

1. Система должна отклонять недопустимые переходы `order_status`.
2. Система должна обеспечивать согласованность `Order.current_payment_status` с последней релевантной записью `PaymentAttempt`.
3. Система должна переводить заказ в `UNPAID` только по факту истечения `payment_deadline_at`.
4. Система должна вести аудит всех переходов статусов заказа и оплаты через `OrderHistoryEvent`.
5. Система должна обеспечивать идемпотентность:

- внешних событий по `provider_event_id` и `external_event_id`;
- mutating API-операций по `IdempotencyRecord`.

6. Система должна обеспечивать конкурентную целостность изменений заказа через `Order.version`.
7. Система должна обеспечивать целостность владельца адреса доставки через составной FK `Order(customer_id, delivery_address_id) -> CustomerAddress(customer_id, address_id)`.
8. Система должна обеспечивать ограничение единственной успешной оплаты на заказ через частичный уникальный индекс по `PaymentAttempt(order_id)` для `payment_status='PAYMENT_SUCCEEDED'`.
9. Система должна обеспечивать управление учетными записями пользователей (`FR-41`) через `UserAccount`, связи `1:1` с профильными сущностями ролей и журнал `UserAccountAudit`.

---

## 7. Минимальные индексы для MVP

- `Order(order_status, created_at)`
- `Order(customer_id, created_at)`
- `Order(restaurant_id, order_status)`
- `Order(courier_id, order_status)`
- `Order(payment_deadline_at)`
- `Order(courier_assignment_deadline_at)`
- `Order(customer_id, delivery_address_id)` (для составного FK на `CustomerAddress`)
- `CustomerAddress(customer_id, address_id)` UNIQUE
- `PaymentAttempt(order_id, attempt_no)`
- `PaymentAttempt(order_id)` UNIQUE WHERE `payment_status='PAYMENT_SUCCEEDED'`
- `PaymentAttempt(provider_event_id)`
- `RefundRequest(order_id)`
- `OrderHistoryEvent(order_id, created_at)`
- `IntegrationMessage(processing_status, next_retry_at)`
- `IdempotencyRecord(operation_name, actor_role, actor_id, idempotency_key)`
- `UserAccount(login)` UNIQUE
- `UserAccount(external_subject_id)` UNIQUE WHERE `external_subject_id IS NOT NULL`
- `Customer(user_account_id)` UNIQUE
- `Restaurant(user_account_id)` UNIQUE
- `Courier(user_account_id)` UNIQUE
- `Administrator(user_account_id)` UNIQUE
- `UserAccountAudit(user_account_id, created_at)`

---

## 8. Соответствие требованиям

Целевая модель покрывает:

- жизненный цикл заказа и статусы из `01-requirements/Order_Statuses.md`;
- требования по оплате и таймерам (`FR-9..FR-18`, `FR-24..FR-33`);
- пост-процесс возвратов (`FR-42..FR-45`, `UC-7`);
- администрирование учетных записей пользователей (`FR-41`);
- аудит, идемпотентность и конкурентность (`NFR-1`, `NFR-2`, `NFR-10`, `NFR-14..NFR-16`, `NFR-22`, `NFR-25..NFR-27`).
