-- создаем view с новым столбцом - дата регистрации
CREATE VIEW DataWithRegDate AS
SELECT
	*,
	MIN(purchase_date) OVER(PARTITION BY user_id) AS registration_date
FROM RawData

-- проверяем есть ли дубликаты в пробный период 
SELECT
	user_id,
	SUM(quantity)
FROM DataWithRegDate
WHERE is_trial_period = 1
GROUP BY user_id
HAVING SUM(quantity) > 1    -- 77 user_id с дубликатами

-- Проверка: user_id = 8955671  3 записи в пробный период
SELECT *
FROM DataWithRegDate
WHERE user_id = 8955671
ORDER BY purchase_date
 
-- Проверяем есть ли дубликаты (списания оплаты больше 1 раза) после пробного периода
SELECT
	user_id,
	SUM(quantity),
	COUNT(DISTINCT purchase_date)
FROM DataWithRegDate
WHERE is_trial_period = 0
GROUP BY user_id
HAVING SUM(quantity) != COUNT(DISTINCT purchase_date) -- 14 user_id с дубликатами

-- Проверка: user_id = 9584301 9 списаний в 3 разных purchase_date
-- user_id = 9584301 reg_date = 2020-02-01, следующие списания 2020-02-08, 2020-02-15, и еще 7 ошибочных списаний 2020-02-16, так как тип подписки - недельная
SELECT *
FROM DataWithRegDate
WHERE user_id =  9584301
ORDER BY purchase_date

-- Проверка: user_id = 8604538 7 списаний в 6 разных purchase_date
-- user_id = 9584301 reg_date = 2020-01-12, следующие списания 01-19, 01-26, 02-02, 02-09, 2 раза в 02-10 и 02-17.
-- Так как возможен вариант что пользователь отписался 9го, но 10го обратно подписался, не будем считать 1 списание 10го ошибкой.

SELECT *
FROM DataWithRegDate
WHERE user_id = 8604538
ORDER BY purchase_date

/* Выводим таблицу без дубликатов, ошибочных списаний
В пробный период убликатами считаем все записи после первичной регистрации: is_trial_period = 1 AND row_num_trial =1
После пробного периода ошибочными списаниями, дубликатами считаем больше 1 списания в день: is_trial_period = 0  AND row_num_not_trial = 1
*/

-- создаем view c clean data
CREATE VIEW SubsSales AS
 WITH CTE AS(
	SELECT 
		*,
		ROW_NUMBER() OVER (PARTITION BY user_id, is_trial_period ORDER BY purchase_date) AS row_num_trial,
		ROW_NUMBER() OVER (PARTITION BY user_id, is_trial_period, purchase_date ORDER BY purchase_date ) AS row_num_not_trial
	FROM DataWithRegDate
	)
SELECT
	product_id,
	quantity,
	is_trial_period,
	purchase_date,
	user_id,
	registration_date,
       CONCAT('Week ', DATEDIFF(DAY, registration_date, purchase_date) / 7) AS week_number
FROM CTE
WHERE (is_trial_period = 0  AND row_num_not_trial = 1) OR( is_trial_period = 1 AND row_num_trial =1) -- rows decreased from 114200 to 114081

-- создаем view c purchase_number
CREATE VIEW SalesData AS
SELECT 
	*,
	ROW_NUMBER() OVER (PARTITION BY user_id, is_trial_period ORDER BY purchase_date) as purchase_number
FROM SubsSales


-- Daily NEW Users
CREATE VIEW DailyNewUsers AS
SELECT
	registration_date,
	COUNT(DISTINCT user_id) AS new_users
FROM SubsSales
GROUP BY registration_date


-- Daily Revenue from subscriptions
CREATE VIEW Revenue AS
SELECT
	purchase_date,
	SUM(quantity) * 4.99 AS Revenue
FROM SubsSales
WHERE is_trial_period = 0
GROUP BY purchase_date







