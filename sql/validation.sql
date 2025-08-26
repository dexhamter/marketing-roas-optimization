-- Orders: totals and date range
SELECT COUNT(*) AS orders_n,
		ROUND(SUM(revenue),2) AS total_order_revenue,
		MIN(order_date) AS min_order_dt,
		MAX(order_date) AS max_order_dt
FROM orders;

-- Spend: totals and date range
SELECT COUNT(*) AS spend_rows,
		ROUND(SUM(spend),2) AS total_spend,
		MIN(date) AS min_spend_dt,
		MAX(date) AS max_spend_dt
FROM ad_spend_daily;

-- attribution build
WITH session_order_match AS (
	SELECT
		o.order_id, o.customer_id, o.order_date, o.revenue,
		s.session_id, s.campaign_id, s.date AS session_date,
		ROW_NUMBER() OVER (
			PARTITION BY o.order_id
			ORDER BY s.date DESC, s.session_id DESC    -- tie breaker
		) AS rn
	FROM orders o
	JOIN web_sessions s
	ON o.customer_id = s.customer_id
	AND s.date <= o.order_date
),
attributed_orders AS (
	SELECT order_id, campaign_id, order_date, session_date, revenue
	FROM session_order_match
	WHERE rn = 1
)

-- (A) Attributed revenue (should be < total orders if some are unattributed)
SELECT ROUND(SUM(revenue), 2) AS attributed_revenue
FROM attributed_orders;

-- (B) Unattributed revenue = orders not in attributed_orders
WITH session_order_match AS (
	SELECT
		o.order_id, o.customer_id, o.order_date, o.revenue,
		s.session_id, s.campaign_id, s.date AS session_date,
		ROW_NUMBER() OVER (
			PARTITION BY o.order_id
			ORDER BY s.date DESC, s.session_id DESC    -- tie breaker
		) AS rn
	FROM orders o
	JOIN web_sessions s
	ON o.customer_id = s.customer_id
	AND s.date <= o.order_date
),
attributed_orders AS (
	SELECT order_id, campaign_id, order_date, session_date, revenue
	FROM session_order_match
	WHERE rn = 1
)
SELECT ROUND(SUM(o.revenue),2) AS unattributed_revenue
FROM orders o
LEFT JOIN attributed_orders ao ON o.order_id = ao.order_id
WHERE ao.order_id IS NULL;

-- Baseline: attributed revenue, no spend join
WITH session_order_match AS (
	SELECT
		o.order_id, o.customer_id, o.order_date, o.revenue,
		s.session_id, s.campaign_id, s.date AS session_date,
		ROW_NUMBER() OVER (
			PARTITION BY o.order_id
			ORDER BY s.date DESC, s.session_id DESC    -- tie breaker
		) AS rn
	FROM orders o
	JOIN web_sessions s
	ON o.customer_id = s.customer_id
	AND s.date <= o.order_date
),
attributed_orders AS (
	SELECT order_id, campaign_id, order_date, session_date, revenue
	FROM session_order_match
	WHERE rn = 1
)
SELECT ROUND(SUM(revenue),2) AS attr_rev_no_spend
FROM attributed_orders;

-- Risky join (DO NOT use in production-only to test inflation)
WITH session_order_match AS (
	SELECT
		o.order_id, o.customer_id, o.order_date, o.revenue,
		s.session_id, s.campaign_id, s.date AS session_date,
		ROW_NUMBER() OVER (
			PARTITION BY o.order_id
			ORDER BY s.date DESC, s.session_id DESC    -- tie breaker
		) AS rn
	FROM orders o
	JOIN web_sessions s
	ON o.customer_id = s.customer_id
	AND s.date <= o.order_date
),
attributed_orders AS (
	SELECT order_id, campaign_id, order_date, session_date, revenue
	FROM session_order_match
	WHERE rn = 1
)
SELECT ROUND(SUM(ao.revenue),2) AS attr_rev_after_join
FROM attributed_orders ao
JOIN ad_spend_daily sp
ON ao.campaign_id = sp.campaign_id;    -- no date; causes duplication

-- If attr_rev_after_join > attr_rev_no_spend -> you hit a many-to-many duplication

-- Duplicate spend rows per campaign/date
SELECT campaign_id, date, COUNT(*) AS rows
FROM ad_spend_daily
GROUP BY campaign_id, date
HAVING COUNT(*) > 1;

--- Spend that references unknown campaigns
SELECT sp.campaign_id, MIN(sp.date) AS first_dt, MAX(sp.date) AS last_dt, SUM(sp.spend) AS spend
FROM ad_spend_daily sp
LEFT JOIN campaigns c ON sp.campaign_id = c.campaign_id
WHERE c.campaign_id IS NULL
GROUP BY sp.campaign_id;

-- Attributed orders pointing to unknown campaigns (should be none)
WITH session_order_match AS (
	SELECT
		o.order_id, o.customer_id, o.order_date, o.revenue,
		s.session_id, s.campaign_id, s.date AS session_date,
		ROW_NUMBER() OVER (
			PARTITION BY o.order_id
			ORDER BY s.date DESC, s.session_id DESC    -- tie breaker
		) AS rn
	FROM orders o
	JOIN web_sessions s
	ON o.customer_id = s.customer_id
	AND s.date <= o.order_date
),
attributed_orders AS (
	SELECT order_id, campaign_id, order_date, session_date, revenue
	FROM session_order_match
	WHERE rn = 1
)
SELECT ao.campaign_id, COUNT(*) AS orders_n, SUM(ao.revenue) AS revenue
FROM attributed_orders ao
LEFT JOIN campaigns c ON ao.campaign_id = c.campaign_id
WHERE c.campaign_id IS NULL
GROUP BY ao.campaign_id;

-- Negative or zero anomalies
SELECT * FROM ad_spend_daily WHERE spend < 0;
SELECT * FROM orders WHERE revenue < 0;

-- Distribution of lookback lag (days between session and order)
WITH session_order_match AS (
	SELECT
		o.order_id, o.customer_id, o.order_date, o.revenue,
		s.session_id, s.campaign_id, s.date AS session_date,
		ROW_NUMBER() OVER (
			PARTITION BY o.order_id
			ORDER BY s.date DESC, s.session_id DESC    -- tie breaker
		) AS rn
	FROM orders o
	JOIN web_sessions s
	ON o.customer_id = s.customer_id
	AND s.date <= o.order_date
),
attributed_orders AS (
	SELECT order_id, campaign_id, order_date, session_date, revenue
	FROM session_order_match
	WHERE rn = 1
)
SELECT
	CASE
		WHEN julianday(order_date) - julianday(session_date) <= 1 THEN '0-1d'
		WHEN julianday(order_date) - julianday(session_date) <= 7 THEN '2-7d'
		WHEN julianday(order_date) - julianday(session_date) <= 30 THEN '8-30d'
		ELSE '31d+'
	END AS lookback_bucket,
	COUNT(*) AS orders_n
FROM attributed_orders
GROUP BY lookback_bucket
ORDER BY lookback_bucket;

-- OPTIONAL rule check: how many orders would be dropped if you enforced a 30-day lookback window?
WITH session_order_match AS (
	SELECT
		o.order_id, o.customer_id, o.order_date, o.revenue,
		s.session_id, s.campaign_id, s.date AS session_date,
		ROW_NUMBER() OVER (
			PARTITION BY o.order_id
			ORDER BY s.date DESC, s.session_id DESC    -- tie breaker
		) AS rn
	FROM orders o
	JOIN web_sessions s
	ON o.customer_id = s.customer_id
	AND s.date <= o.order_date
),
attributed_orders AS (
	SELECT *
	FROM (
		SELECT order_id, campaign_id, order_date, session_date, revenue,
			ROW_NUMBER() OVER (
				PARTITION BY order_id
				ORDER BY session_date DESC, campaign_id DESC
			) rn
		FROM session_order_match
		WHERE julianday(order_date) - julianday(session_date) <= 30
	)
	WHERE rn = 1
)
SELECT
	(SELECT ROUND(SUM(revenue),2) FROM attributed_orders) AS attr_rev_30d,
	(SELECT ROUND(SUM(revenue),2) FROM orders) AS total_orders_rev;
	
-- How many orders had >=1 prior session?
WITH session_order_match AS (
	SELECT
		o.order_id, o.customer_id, o.order_date, o.revenue,
		s.session_id, s.campaign_id, s.date AS session_date,
		ROW_NUMBER() OVER (
			PARTITION BY o.order_id
			ORDER BY s.date DESC, s.session_id DESC    -- tie breaker
		) AS rn
	FROM orders o
	JOIN web_sessions s
	ON o.customer_id = s.customer_id
	AND s.date <= o.order_date
)
SELECT COUNT(DISTINCT order_id) AS orders_with_session
FROM session_order_match;

-- Count of attributed orders
WITH session_order_match AS (
	SELECT
		o.order_id, o.customer_id, o.order_date, o.revenue,
		s.session_id, s.campaign_id, s.date AS session_date,
		ROW_NUMBER() OVER (
			PARTITION BY o.order_id
			ORDER BY s.date DESC, s.session_id DESC    -- tie breaker
		) AS rn
	FROM orders o
	JOIN web_sessions s
	ON o.customer_id = s.customer_id
	AND s.date <= o.order_date
),
attributed_orders AS (
	SELECT order_id, campaign_id, order_date, session_date, revenue
	FROM session_order_match
	WHERE rn = 1
)
SELECT COUNT(DISTINCT order_id) AS attributed_orders_n
FROM attributed_orders;

-- Unattributed orders count (should equal orders_with_session - attributed_orders_n)
WITH session_order_match AS (
	SELECT
		o.order_id, o.customer_id, o.order_date, o.revenue,
		s.session_id, s.campaign_id, s.date AS session_date,
		ROW_NUMBER() OVER (
			PARTITION BY o.order_id
			ORDER BY s.date DESC, s.session_id DESC    -- tie breaker
		) AS rn
	FROM orders o
	JOIN web_sessions s
	ON o.customer_id = s.customer_id
	AND s.date <= o.order_date
),
attributed_orders AS (
	SELECT order_id, campaign_id, order_date, session_date, revenue
	FROM session_order_match
	WHERE rn = 1
)
SELECT COUNT(*) AS unattributed_orders_n
FROM orders o
LEFT JOIN attributed_orders ao ON o.order_id = ao.order_id
WHERE ao.order_id IS NULL;

SELECT COUNT(*) FROM orders;

-- Revenue by channel (attributed only) should sum to attributed_revenue
WITH session_order_match AS (
	SELECT
		o.order_id, o.customer_id, o.order_date, o.revenue,
		s.session_id, s.campaign_id, s.date AS session_date,
		ROW_NUMBER() OVER (
			PARTITION BY o.order_id
			ORDER BY s.date DESC, s.session_id DESC    -- tie breaker
		) AS rn
	FROM orders o
	JOIN web_sessions s
	ON o.customer_id = s.customer_id
	AND s.date <= o.order_date
),
attributed_orders AS (
	SELECT order_id, campaign_id, order_date, session_date, revenue
	FROM session_order_match
	WHERE rn = 1
)
SELECT c.channel, ROUND(SUM(ao.revenue),2) AS revenue
FROM attributed_orders ao
JOIN campaigns c ON ao.campaign_id = c.campaign_id
GROUP BY c.channel
ORDER BY revenue DESC;

-- Spend by channel should sum to total spend
SELECT c.channel, ROUND(SUM(sp.spend),2) AS spend
FROM ad_spend_daily sp
JOIN campaigns c ON sp.campaign_id = c.campaign_id
GROUP BY c.channel
ORDER BY spend DESC;

-- Orders revenue by week (ground truth)
SELECT STRFTIME('%Y-%W', order_date) AS week,
		ROUND(SUM(revenue),2) AS orders_rev
FROM orders
GROUP BY week
ORDER BY week;

-- Attributed revenue by week (sum should be < or = orders_rev per week)
WITH session_order_match AS (
	SELECT
		o.order_id, o.customer_id, o.order_date, o.revenue,
		s.session_id, s.campaign_id, s.date AS session_date,
		ROW_NUMBER() OVER (
			PARTITION BY o.order_id
			ORDER BY s.date DESC, s.session_id DESC    -- tie breaker
		) AS rn
	FROM orders o
	JOIN web_sessions s
	ON o.customer_id = s.customer_id
	AND s.date <= o.order_date
),
attributed_orders AS (
	SELECT order_id, campaign_id, order_date, session_date, revenue
	FROM session_order_match
	WHERE rn = 1
)
SELECT STRFTIME('%Y-%W', order_date) AS week,
		ROUND(SUM(revenue),2) AS attr_rev
FROM attributed_orders
GROUP BY week
ORDER BY week;

-- Spend by week
SELECT STRFTIME('%Y-%W', date) AS week,
		ROUND(SUM(spend),2) AS spend
FROM ad_spend_daily
GROUP BY week
ORDER BY week;