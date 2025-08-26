WITH session_order_match AS (
	SELECT
		o.order_id,
		o.customer_id,
		o.order_date,
		o.revenue,
		s.session_id,
		s.campaign_id,
		s.date AS session_date,
		ROW_NUMBER() OVER (
			PARTITION BY o.order_id
			ORDER BY s.date DESC
		) AS rn
	FROM orders o
	JOIN web_sessions s
		ON o.customer_id = s.customer_id
		AND s.date <= o.order_date
),
attributed_orders AS (
	SELECT order_id, campaign_id, order_date, revenue
	FROM session_order_match
	WHERE rn = 1
),
revenue_by_channel AS (
	SELECT
		c.channel,
		SUM(ao.revenue) AS total_revenue
	FROM attributed_orders ao
	JOIN campaigns c
		ON ao.campaign_id = c.campaign_id
	GROUP BY c.channel
),
spend_by_channel AS (
	SELECT
		c.channel,
		SUM(sp.spend) AS total_spend
	FROM ad_spend_daily sp
	JOIN campaigns c
		ON sp.campaign_id = c.campaign_id
	GROUP BY c.channel
)
SELECT
	r.channel,
	r.total_revenue,
	s.total_spend,
	CASE
		WHEN s.total_spend = 0 THEN NULL
		ELSE r.total_revenue * 1.0 / s.total_spend
	END AS roas
FROM revenue_by_channel r
LEFT JOIN spend_by_channel s
	ON r.channel = s.channel
	
UNION ALL

-- Add unattributed
SELECT
	'Unattributed' AS channel,
	SUM(o.revenue) AS total_revenue,
	0 AS total_spend,
	NULL AS roas
FROM orders o
LEFT JOIN attributed_orders ao
	ON o.order_id = ao.order_id
WHERE ao.order_id IS NULL;

-- Attributed revenue total
WITH session_order_match AS (
	SELECT
		o.order_id,
		o.customer_id,
		o.order_date,
		o.revenue,
		s.session_id,
		s.campaign_id,
		s.date AS session_date,
		ROW_NUMBER() OVER (
			PARTITION BY o.order_id
			ORDER BY s.date DESC
		) AS rn
	FROM orders o
	JOIN web_sessions s
		ON o.customer_id = s.customer_id
		AND s.date <= o.order_date
),
attributed_orders AS (
	SELECT order_id, campaign_id, order_date, revenue
	FROM session_order_match
	WHERE rn = 1
)
SELECT ROUND(SUM(revenue),2) AS attributed_revenue
FROM attributed_orders;