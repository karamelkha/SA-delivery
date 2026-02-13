Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$outputPath = Join-Path $scriptDir "ER-diagram.jpg"

$width = 3400
$height = 1450
$clearance = 12.0
$laneStep = 18.0

$bmp = New-Object System.Drawing.Bitmap($width, $height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
$g.Clear([System.Drawing.Color]::FromArgb(248, 250, 252))

$titleFont = New-Object System.Drawing.Font("Segoe UI", 22, [System.Drawing.FontStyle]::Bold)
$subtitleFont = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Regular)
$entityTitleFont = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$entityFieldFont = New-Object System.Drawing.Font("Consolas", 9, [System.Drawing.FontStyle]::Regular)
$relationFont = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)

$textBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30, 41, 59))
$mutedBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(71, 85, 105))
$cardBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 255, 255))
$linePen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(148, 163, 184), 1.6)

function P {
    param(
        [float]$X,
        [float]$Y
    )
    return [System.Drawing.PointF]::new($X, $Y)
}

function Draw-Entity {
    param(
        [System.Drawing.Graphics]$G,
        [float]$X,
        [float]$Y,
        [float]$W,
        [float]$H,
        [string]$Title,
        [string[]]$Fields,
        [System.Drawing.Color]$HeaderColor,
        [System.Drawing.Font]$TitleFont,
        [System.Drawing.Font]$FieldFont,
        [System.Drawing.Brush]$TextBrush,
        [System.Drawing.Pen]$BorderPen,
        [System.Drawing.Brush]$CardBrush
    )

    $cardRect = [System.Drawing.RectangleF]::new($X, $Y, $W, $H)
    $headerRect = [System.Drawing.RectangleF]::new($X, $Y, $W, 34)
    $headerBrush = New-Object System.Drawing.SolidBrush($HeaderColor)

    $G.FillRectangle($CardBrush, $cardRect)
    $G.FillRectangle($headerBrush, $headerRect)
    $G.DrawRectangle($BorderPen, $X, $Y, $W, $H)
    $G.DrawLine($BorderPen, $X, $Y + 34, $X + $W, $Y + 34)
    $G.DrawString($Title, $TitleFont, $TextBrush, $X + 8, $Y + 8)

    $lineY = $Y + 42
    foreach ($field in $Fields) {
        if ($lineY -gt ($Y + $H - 16)) { break }
        $G.DrawString($field, $FieldFont, $TextBrush, $X + 8, $lineY)
        $lineY += 14
    }

    $headerBrush.Dispose()

    return @{
        X = $X
        Y = $Y
        W = $W
        H = $H
    }
}

function Anchor {
    param(
        [hashtable]$Entity,
        [string]$Side,
        [float]$Ratio = 0.5,
        [float]$Gap = 12.0
    )

    if ($Ratio -lt 0.0) { $Ratio = 0.0 }
    if ($Ratio -gt 1.0) { $Ratio = 1.0 }

    $x = [float]$Entity.X
    $y = [float]$Entity.Y
    $w = [float]$Entity.W
    $h = [float]$Entity.H

    switch ($Side) {
        "Left"   { return (P ($x - $Gap) ($y + $h * $Ratio)) }
        "Right"  { return (P ($x + $w + $Gap) ($y + $h * $Ratio)) }
        "Top"    { return (P ($x + $w * $Ratio) ($y - $Gap)) }
        "Bottom" { return (P ($x + $w * $Ratio) ($y + $h + $Gap)) }
        default  { return (P ($x + $w / 2.0) ($y + $h / 2.0)) }
    }
}

function Draw-RelationPath {
    param(
        [System.Drawing.Graphics]$G,
        [System.Drawing.PointF[]]$Points,
        [string]$Label,
        [System.Drawing.Color]$Color,
        [System.Drawing.Font]$Font,
        [int]$LabelSegmentIndex = 0
    )

    if (-not $Points -or $Points.Count -lt 2) { return }

    $pen = New-Object System.Drawing.Pen($Color, 2.0)
    for ($i = 0; $i -lt $Points.Count - 1; $i++) {
        $G.DrawLine($pen, $Points[$i], $Points[$i + 1])
    }

    $from = $Points[$Points.Count - 2]
    $to = $Points[$Points.Count - 1]
    $angle = [Math]::Atan2(($to.Y - $from.Y), ($to.X - $from.X))
    $arrowLen = 11.0
    $arrowAngle = [Math]::PI / 7.0

    $p1 = [System.Drawing.PointF]::new(
        [float]($to.X - $arrowLen * [Math]::Cos($angle - $arrowAngle)),
        [float]($to.Y - $arrowLen * [Math]::Sin($angle - $arrowAngle))
    )
    $p2 = [System.Drawing.PointF]::new(
        [float]($to.X - $arrowLen * [Math]::Cos($angle + $arrowAngle)),
        [float]($to.Y - $arrowLen * [Math]::Sin($angle + $arrowAngle))
    )
    $G.DrawLine($pen, $to, $p1)
    $G.DrawLine($pen, $to, $p2)

    if ($Label) {
        if ($LabelSegmentIndex -lt 0) { $LabelSegmentIndex = 0 }
        if ($LabelSegmentIndex -gt ($Points.Count - 2)) { $LabelSegmentIndex = $Points.Count - 2 }
        $a = $Points[$LabelSegmentIndex]
        $b = $Points[$LabelSegmentIndex + 1]
        $mx = ($a.X + $b.X) / 2.0
        $my = ($a.Y + $b.Y) / 2.0
        $size = $G.MeasureString($Label, $Font)
        $labelRect = [System.Drawing.RectangleF]::new(
            [float]($mx - $size.Width / 2),
            [float]($my - $size.Height / 2),
            [float]($size.Width + 6),
            [float]($size.Height + 2)
        )
        $labelBg = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(230, 255, 255, 255))
        $labelText = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30, 41, 59))
        $G.FillRectangle($labelBg, $labelRect)
        $G.DrawString($Label, $Font, $labelText, $labelRect.X + 3, $labelRect.Y + 1)
        $labelBg.Dispose()
        $labelText.Dispose()
    }

    $pen.Dispose()
}

$g.DrawString("ER Diagram (MVP) - Delivery", $titleFont, $textBrush, 30, 16)
$g.DrawString("Pixel-perfect routing: orthogonal lanes, fixed spacing, and no line-to-box contact.", $subtitleFont, $mutedBrush, 32, 56)
$g.DrawString("One attribute per line in every entity for implementation-grade readability.", $subtitleFont, $mutedBrush, 32, 76)

$entities = @{}

$entities.Customer = Draw-Entity -G $g -X 50 -Y 120 -W 420 -H 170 -Title "Customer" -Fields @(
    "PK customer_id",
    "full_name",
    "phone UNIQUE",
    "email UNIQUE?",
    "is_active",
    "created_at",
    "updated_at"
) -HeaderColor ([System.Drawing.Color]::FromArgb(226, 232, 240)) -TitleFont $entityTitleFont -FieldFont $entityFieldFont -TextBrush $textBrush -BorderPen $linePen -CardBrush $cardBrush

$entities.CustomerAddress = Draw-Entity -G $g -X 50 -Y 340 -W 420 -H 200 -Title "CustomerAddress" -Fields @(
    "PK address_id",
    "FK customer_id -> Customer.customer_id",
    "label",
    "full_address",
    "comment?",
    "is_default",
    "is_active",
    "created_at",
    "updated_at"
) -HeaderColor ([System.Drawing.Color]::FromArgb(226, 232, 240)) -TitleFont $entityTitleFont -FieldFont $entityFieldFont -TextBrush $textBrush -BorderPen $linePen -CardBrush $cardBrush

$entities.Administrator = Draw-Entity -G $g -X 50 -Y 590 -W 420 -H 160 -Title "Administrator" -Fields @(
    "PK admin_id",
    "full_name",
    "email UNIQUE",
    "is_active",
    "created_at",
    "updated_at"
) -HeaderColor ([System.Drawing.Color]::FromArgb(226, 232, 240)) -TitleFont $entityTitleFont -FieldFont $entityFieldFont -TextBrush $textBrush -BorderPen $linePen -CardBrush $cardBrush

$entities.Order = Draw-Entity -G $g -X 620 -Y 220 -W 450 -H 340 -Title "Order (aggregate root)" -Fields @(
    "PK order_id",
    "FK customer_id -> Customer.customer_id",
    "FK restaurant_id -> Restaurant.restaurant_id",
    "FK delivery_address_id -> CustomerAddress.address_id",
    "FK courier_id? -> Courier.courier_id",
    "order_status",
    "current_payment_status",
    "FK current_payment_id? -> PaymentAttempt.payment_id",
    "total_amount",
    "currency",
    "payment_deadline_at",
    "courier_assignment_deadline_at?",
    "next_assignment_attempt_at?",
    "version",
    "created_at",
    "updated_at",
    "closed_at?"
) -HeaderColor ([System.Drawing.Color]::FromArgb(254, 249, 195)) -TitleFont $entityTitleFont -FieldFont $entityFieldFont -TextBrush $textBrush -BorderPen $linePen -CardBrush $cardBrush

$entities.OrderItem = Draw-Entity -G $g -X 620 -Y 620 -W 450 -H 180 -Title "OrderItem" -Fields @(
    "PK order_item_id",
    "FK order_id -> Order.order_id",
    "FK menu_item_id -> MenuItem.menu_item_id",
    "item_name_snapshot",
    "unit_price",
    "quantity",
    "line_total",
    "created_at"
) -HeaderColor ([System.Drawing.Color]::FromArgb(254, 249, 195)) -TitleFont $entityTitleFont -FieldFont $entityFieldFont -TextBrush $textBrush -BorderPen $linePen -CardBrush $cardBrush

$entities.Restaurant = Draw-Entity -G $g -X 1230 -Y 100 -W 520 -H 180 -Title "Restaurant" -Fields @(
    "PK restaurant_id",
    "name",
    "address",
    "phone",
    "is_open",
    "is_active",
    "created_at",
    "updated_at"
) -HeaderColor ([System.Drawing.Color]::FromArgb(220, 252, 231)) -TitleFont $entityTitleFont -FieldFont $entityFieldFont -TextBrush $textBrush -BorderPen $linePen -CardBrush $cardBrush

$entities.MenuItem = Draw-Entity -G $g -X 1230 -Y 320 -W 520 -H 200 -Title "MenuItem" -Fields @(
    "PK menu_item_id",
    "FK restaurant_id -> Restaurant.restaurant_id",
    "name",
    "description?",
    "price",
    "currency",
    "is_available",
    "created_at",
    "updated_at"
) -HeaderColor ([System.Drawing.Color]::FromArgb(220, 252, 231)) -TitleFont $entityTitleFont -FieldFont $entityFieldFont -TextBrush $textBrush -BorderPen $linePen -CardBrush $cardBrush

$entities.Courier = Draw-Entity -G $g -X 1230 -Y 560 -W 520 -H 170 -Title "Courier" -Fields @(
    "PK courier_id",
    "full_name",
    "phone UNIQUE",
    "courier_status",
    "is_active",
    "created_at",
    "updated_at"
) -HeaderColor ([System.Drawing.Color]::FromArgb(220, 252, 231)) -TitleFont $entityTitleFont -FieldFont $entityFieldFont -TextBrush $textBrush -BorderPen $linePen -CardBrush $cardBrush

$entities.PaymentAttempt = Draw-Entity -G $g -X 1840 -Y 80 -W 620 -H 300 -Title "PaymentAttempt" -Fields @(
    "PK payment_id",
    "FK order_id -> Order.order_id",
    "attempt_no",
    "UNIQUE(order_id, attempt_no)",
    "payment_status",
    "amount",
    "currency",
    "payment_provider",
    "provider_payment_id UNIQUE?",
    "provider_result_code?",
    "provider_event_id UNIQUE?",
    "idempotency_key?",
    "requested_at",
    "result_received_at?",
    "expires_at",
    "created_at",
    "updated_at"
) -HeaderColor ([System.Drawing.Color]::FromArgb(219, 234, 254)) -TitleFont $entityTitleFont -FieldFont $entityFieldFont -TextBrush $textBrush -BorderPen $linePen -CardBrush $cardBrush

$entities.RefundRequest = Draw-Entity -G $g -X 1840 -Y 430 -W 620 -H 260 -Title "RefundRequest" -Fields @(
    "PK refund_request_id",
    "FK order_id -> Order.order_id",
    "UNIQUE(order_id)",
    "FK payment_id -> PaymentAttempt.payment_id",
    "reason_code",
    "refund_status",
    "amount",
    "provider_refund_id UNIQUE?",
    "last_error_code?",
    "last_error_message?",
    "initiated_at",
    "processed_at?",
    "created_at",
    "updated_at"
) -HeaderColor ([System.Drawing.Color]::FromArgb(219, 234, 254)) -TitleFont $entityTitleFont -FieldFont $entityFieldFont -TextBrush $textBrush -BorderPen $linePen -CardBrush $cardBrush

$entities.OrderHistoryEvent = Draw-Entity -G $g -X 1840 -Y 740 -W 620 -H 280 -Title "OrderHistoryEvent (audit)" -Fields @(
    "PK event_id",
    "FK order_id -> Order.order_id",
    "event_type",
    "actor_role",
    "actor_id?",
    "previous_value?",
    "new_value?",
    "reason_code?",
    "description?",
    "correlation_id",
    "event_payload_json?",
    "created_at"
) -HeaderColor ([System.Drawing.Color]::FromArgb(219, 234, 254)) -TitleFont $entityTitleFont -FieldFont $entityFieldFont -TextBrush $textBrush -BorderPen $linePen -CardBrush $cardBrush

$entities.IdempotencyRecord = Draw-Entity -G $g -X 2520 -Y 120 -W 820 -H 250 -Title "IdempotencyRecord" -Fields @(
    "PK idempotency_record_id",
    "idempotency_key",
    "operation_name",
    "actor_role",
    "actor_id",
    "request_hash",
    "response_status_code",
    "response_body_json",
    "resource_type?",
    "resource_id?",
    "expires_at",
    "created_at",
    "UNIQUE(operation_name, actor_role, actor_id, idempotency_key)"
) -HeaderColor ([System.Drawing.Color]::FromArgb(243, 232, 255)) -TitleFont $entityTitleFont -FieldFont $entityFieldFont -TextBrush $textBrush -BorderPen $linePen -CardBrush $cardBrush

$entities.IntegrationMessage = Draw-Entity -G $g -X 2520 -Y 500 -W 820 -H 290 -Title "IntegrationMessage (inbox/outbox)" -Fields @(
    "PK integration_message_id",
    "direction",
    "message_type",
    "external_event_id UNIQUE?",
    "FK order_id? -> Order.order_id",
    "FK payment_id? -> PaymentAttempt.payment_id",
    "FK refund_request_id? -> RefundRequest.refund_request_id",
    "correlation_id",
    "payload_json",
    "processing_status",
    "retry_count",
    "next_retry_at?",
    "last_error?",
    "created_at",
    "updated_at"
) -HeaderColor ([System.Drawing.Color]::FromArgb(243, 232, 255)) -TitleFont $entityTitleFont -FieldFont $entityFieldFont -TextBrush $textBrush -BorderPen $linePen -CardBrush $cardBrush

$relMain = [System.Drawing.Color]::FromArgb(51, 65, 85)
$relSystem = [System.Drawing.Color]::FromArgb(30, 64, 175)

$laneL1 = 560.0
$laneL2 = $laneL1 + $laneStep
$laneM1 = 1160.0
$laneM2 = $laneM1 + $laneStep
$laneM3 = $laneM2 + $laneStep
$laneM4 = $laneM3 + $laneStep
$laneR1 = 2490.0
$laneR2 = $laneR1 + $laneStep

# Left-side relations
Draw-RelationPath -G $g -Points @(
    (Anchor $entities.Customer "Bottom" 0.5 $clearance),
    (Anchor $entities.CustomerAddress "Top" 0.5 $clearance)
) -Label "1 : N" -Color $relMain -Font $relationFont -LabelSegmentIndex 0

Draw-RelationPath -G $g -Points @(
    (Anchor $entities.Customer "Right" 0.52 $clearance),
    (P $laneL1 210),
    (P $laneL1 280),
    (Anchor $entities.Order "Left" 0.18 $clearance)
) -Label "1 : N" -Color $relMain -Font $relationFont -LabelSegmentIndex 1

Draw-RelationPath -G $g -Points @(
    (Anchor $entities.CustomerAddress "Right" 0.62 $clearance),
    (P $laneL2 465),
    (P $laneL2 410),
    (Anchor $entities.Order "Left" 0.56 $clearance)
) -Label "1 : N (address ownership)" -Color $relMain -Font $relationFont -LabelSegmentIndex 1

# Mid relations
Draw-RelationPath -G $g -Points @(
    (Anchor $entities.Restaurant "Bottom" 0.5 $clearance),
    (Anchor $entities.MenuItem "Top" 0.5 $clearance)
) -Label "1 : N" -Color $relMain -Font $relationFont -LabelSegmentIndex 0

Draw-RelationPath -G $g -Points @(
    (Anchor $entities.Restaurant "Left" 0.52 $clearance),
    (P $laneM1 194),
    (P $laneM1 190),
    (P 908 190),
    (Anchor $entities.Order "Top" 0.75 $clearance)
) -Label "1 : N" -Color $relMain -Font $relationFont -LabelSegmentIndex 2

Draw-RelationPath -G $g -Points @(
    (Anchor $entities.Courier "Left" 0.52 $clearance),
    (P $laneM2 648),
    (P $laneM2 452),
    (Anchor $entities.Order "Right" 0.68 $clearance)
) -Label "1 : N (order.courier_id?)" -Color $relMain -Font $relationFont -LabelSegmentIndex 1

Draw-RelationPath -G $g -Points @(
    (Anchor $entities.Order "Bottom" 0.42 $clearance),
    (Anchor $entities.OrderItem "Top" 0.42 $clearance)
) -Label "1 : N" -Color $relMain -Font $relationFont -LabelSegmentIndex 0

Draw-RelationPath -G $g -Points @(
    (Anchor $entities.MenuItem "Left" 0.62 $clearance),
    (P $laneM3 444),
    (P $laneM3 708),
    (Anchor $entities.OrderItem "Right" 0.36 $clearance)
) -Label "1 : N" -Color $relMain -Font $relationFont -LabelSegmentIndex 1

# Order to right-side domain
Draw-RelationPath -G $g -Points @(
    (Anchor $entities.Order "Right" 0.24 $clearance),
    (P $laneM1 300),
    (P 1828 300),
    (P 1828 230),
    (Anchor $entities.PaymentAttempt "Left" 0.50 $clearance)
) -Label "1 : N" -Color $relSystem -Font $relationFont -LabelSegmentIndex 1

Draw-RelationPath -G $g -Points @(
    (Anchor $entities.Order "Right" 0.46 $clearance),
    (P $laneM2 380),
    (P $laneM2 546),
    (P 1828 546),
    (P 1828 560),
    (Anchor $entities.RefundRequest "Left" 0.50 $clearance)
) -Label "1 : 0..1" -Color $relSystem -Font $relationFont -LabelSegmentIndex 2

Draw-RelationPath -G $g -Points @(
    (Anchor $entities.Order "Right" 0.70 $clearance),
    (P $laneM3 460),
    (P $laneM3 880),
    (Anchor $entities.OrderHistoryEvent "Left" 0.52 $clearance)
) -Label "1 : N" -Color $relSystem -Font $relationFont -LabelSegmentIndex 2

Draw-RelationPath -G $g -Points @(
    (Anchor $entities.Order "Right" 0.92 $clearance),
    (P $laneM4 540),
    (P $laneM4 1120),
    (P 2510 1120),
    (P 2510 646),
    (Anchor $entities.IntegrationMessage "Left" 0.50 $clearance)
) -Label "1 : N" -Color $relSystem -Font $relationFont -LabelSegmentIndex 3

# Optional links to IntegrationMessage (dedicated lanes, fixed spacing)
Draw-RelationPath -G $g -Points @(
    (Anchor $entities.PaymentAttempt "Right" 0.50 $clearance),
    (P $laneR1 230),
    (P $laneR1 620),
    (Anchor $entities.IntegrationMessage "Left" 0.40 $clearance)
) -Label "1 : N (optional)" -Color $relSystem -Font $relationFont -LabelSegmentIndex 1

Draw-RelationPath -G $g -Points @(
    (Anchor $entities.RefundRequest "Right" 0.50 $clearance),
    (P $laneR2 560),
    (P $laneR2 700),
    (Anchor $entities.IntegrationMessage "Left" 0.68 $clearance)
) -Label "1 : N (optional)" -Color $relSystem -Font $relationFont -LabelSegmentIndex 1

$g.DrawString("Operational notes:", $subtitleFont, $textBrush, 2520, 840)
$g.DrawString("- Final order statuses: UNPAID, REJECTED, DELIVERED, CANCELLED", $subtitleFont, $mutedBrush, 2520, 862)
$g.DrawString("- Refund result does not change final order status", $subtitleFont, $mutedBrush, 2520, 881)
$g.DrawString("- Timers are persisted in Order", $subtitleFont, $mutedBrush, 2520, 900)
$g.DrawString("- Line spacing is fixed to $laneStep px for routing lanes", $subtitleFont, $mutedBrush, 2520, 919)
$g.DrawString("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')", $subtitleFont, $mutedBrush, 2520, 948)

$encoder = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$encoderParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encoderParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, 92L)
$bmp.Save($outputPath, $encoder, $encoderParams)

$encoderParams.Dispose()
$linePen.Dispose()
$textBrush.Dispose()
$mutedBrush.Dispose()
$cardBrush.Dispose()
$titleFont.Dispose()
$subtitleFont.Dispose()
$entityTitleFont.Dispose()
$entityFieldFont.Dispose()
$relationFont.Dispose()
$g.Dispose()
$bmp.Dispose()
