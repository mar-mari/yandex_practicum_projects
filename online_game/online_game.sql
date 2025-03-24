/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Мария Мартынова
 * Дата: 03/10/2024
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь

SELECT 
	(SELECT COUNT(id) FROM fantasy.users u) AS total_users,
	COUNT(id) AS payer_users,
	ROUND(COUNT(id)::numeric/(SELECT COUNT(id) FROM fantasy.users u), 2) AS ratio_payer
FROM fantasy.users u 
WHERE payer=1;

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь

WITH users_race AS (
SELECT 
	r.race,
	COUNT(u.id) AS total_race_users
FROM fantasy.users u 
LEFT JOIN fantasy.race r USING(race_id)
GROUP BY r.race
)
SELECT 
	r.race AS race,
	COUNT(u.id) AS payer_race_user, 
	total_race_users,
	ROUND(COUNT(u.id)::numeric /total_race_users, 3) AS ratio_race_payer
FROM fantasy.users u
LEFT JOIN fantasy.race r USING (race_id)
LEFT JOIN users_race USING(race)
WHERE payer=1
GROUP BY r.race, total_race_users
ORDER BY ratio_race_payer DESC, 
		total_race_users DESC, 
		payer_race_user DESC;

--Дополнительное иследование: доля платящих игроков по расам
-- от общего числа игроков
WITH total_users AS (
SELECT 
	COUNT(u.id) AS total_users
FROM fantasy.users u 
)
SELECT 
	r.race AS race,
	COUNT(u.id) AS payer_race_user, 
	total_users,
	ROUND(COUNT(u.id)::numeric /total_users, 3) AS ratio_race_payer
FROM fantasy.users u
LEFT JOIN fantasy.race r USING (race_id)
CROSS JOIN total_users
WHERE payer=1
GROUP BY r.race, total_users
ORDER BY payer_race_user DESC;

--Рейтиг и доля рас вне зависимости от платежей
WITH total_users AS (
SELECT 
	COUNT(u.id) AS total_users
FROM fantasy.users u 
)
SELECT 
	r.race AS race,
	COUNT(u.id) AS race_user, 
	total_users,
	ROUND(COUNT(u.id)::numeric /total_users, 3) AS ratio_race
FROM fantasy.users u
LEFT JOIN fantasy.race r USING (race_id)
CROSS JOIN total_users
GROUP BY r.race, total_users
ORDER BY race_user DESC;
	

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь

SELECT 
	COUNT(amount) AS count_amount,
	SUM(amount) AS sum_amount,
	MIN(amount) AS  min_amount,
	MAX(amount) AS max_amount,
	ROUND(AVG(amount)::numeric,2) AS avg_amount,
	ROUND((PERCENTILE_CONT(0.5)  WITHIN GROUP (ORDER BY amount))::NUMERIC, 2) AS median_amount,
	ROUND(STDDEV(amount)::NUMERIC, 2) AS stand_dev_amount
FROM fantasy.events e; 


-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь

SELECT 
	COUNT(amount) AS amount_0,
	(SELECT COUNT(amount) FROM fantasy.events e) AS total_amount,
	COUNT(amount)::numeric / (SELECT COUNT(amount) FROM fantasy.events e) AS ratio_amount0
FROM fantasy.events e 
WHERE amount=0;

--Эпические предметы с нулевой стоимостью
SELECT 
	DISTINCT e.item_code,
	i.game_items,
	e.amount
FROM fantasy.events e 
LEFT JOIN fantasy.items i USING(item_code)
WHERE amount=0
ORDER BY item_code;

--Проверка стоимости транзакций по предмету с нулевой стоимостью
SELECT 
	item_code,
	amount
FROM fantasy.events e 
WHERE item_code IN (SELECT item_code 
					FROM fantasy.events e
					WHERE amount=0);

-- 2.3: Сравнительный анализ активности платящих и неплатящих игроков:
-- Напишите ваш запрос здесь

--CTE для подсчета количества покупок и суммы на каждого игрока
WITH data_user AS (
SELECT 
	id,
	COUNT(transaction_id) AS count_tr,
	SUM(amount) AS sum_amount
FROM fantasy.events e 
--условие исключения нулевых покупок
WHERE amount!=0
GROUP BY id
)
--Основной запрос для подсчета данных
SELECT 
	CASE 
		WHEN u.payer=0 THEN 'неплатящие'
		WHEN u.payer=1 THEN 'платящие'
	END AS payer,
	COUNT(da.id) AS count_user,
	--среднее количество покупок
	ROUND(AVG(da.count_tr)::numeric,0) AS avg_count,
	--среднюю суммарную стоимость покупок
	ROUND(AVG(da.sum_amount)::numeric,2) AS avg_amount
FROM data_user AS da
LEFT JOIN fantasy.users u USING(id)
GROUP BY u.payer;
	

-- 2.4: Популярные эпические предметы:
-- Напишите ваш запрос здесь

--CTE для подсчета доли игроков использующих предметы
WITH rat_us AS (
SELECT i.game_items,
--Уникальные игроки купившие предметы:
	count(DISTINCT id),
--Доля игроков, купившие предмет от общего числа игроков
	count(DISTINCT id)::NUMERIC/(SELECT count(id) FROM fantasy.users u) AS ratio_users_game
FROM fantasy.events e 
LEFT JOIN fantasy.users u USING(id)
LEFT JOIN fantasy.items i USING(item_code)
GROUP BY i.game_items
ORDER BY ratio_users_game DESC
)
--общий запрос с подсчетом
SELECT
	DISTINCT i.game_items ,
	--общее количество внутриигровых продаж предмета
	COUNT(e.transaction_id) OVER (PARTITION BY e.item_code) AS count_game,
	--доля продажи каждого предмета от всех продаж 
	ROUND(COUNT(e.transaction_id) OVER (PARTITION BY e.item_code)::NUMERIC /
	COUNT(e.transaction_id) OVER (),2) AS ratio_game,
	--долю игроков, которые хотя бы раз покупали этот предмет
	ROUND(r_u.ratio_users_game, 2) AS ratio_users_game
FROM fantasy.events e 
LEFT JOIN fantasy.users u USING(id)
LEFT JOIN fantasy.items i USING(item_code)
LEFT JOIN rat_us AS r_u USING(game_items)
--условие исключения нулевых покупок
WHERE e.amount!=0
ORDER BY ratio_users_game DESC;

--второй вариант решения задачи
SELECT game_items,
    COUNT(e.transaction_id) AS total_amount,
    --доля продажи каждого предмета от всех продаж 
    COUNT(e.transaction_id)::NUMERIC / (SELECT count(*) FROM fantasy.events) AS ratio_game,
    --доля игроков, которые хотя бы раз покупали этот предмет
    COUNT(DISTINCT id)::NUMERIC / (SELECT count(*) FROM fantasy.users u) AS ratio_users_game
FROM fantasy.events e 
LEFT JOIN fantasy.items i USING(item_code)
WHERE e.amount !=0
GROUP BY game_items
ORDER BY ratio_users_game DESC; 


-- Часть 2. Решение ad hoc-задач
-- Задача 1. Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь

--Общие количество игроков по расам
WITH user_race AS (
SELECT 
	r.race AS race,
	COUNT(u.id) AS count_race_user
FROM fantasy.users u
LEFT JOIN fantasy.race r USING (race_id)
GROUP BY r.race
ORDER BY count_race_user DESC
),
--количество игроков, которые совершают внутриигровые покупки
buy_user AS (
SELECT 
	r.race AS race,
	COUNT(u.id) AS buy_user
FROM fantasy.users u 
LEFT JOIN fantasy.race r USING (race_id)
--LEFT JOIN user_race AS ur USING (race)
WHERE u.id IN (SELECT id FROM fantasy.events WHERE amount <> 0)
GROUP BY r.race
),
--количество  платящих игроков
payer_race_user AS (
SELECT 
	r.race AS race,
	COUNT(u.id) AS count_race_payer
FROM fantasy.users u
LEFT JOIN fantasy.race r USING (race_id)
WHERE u.payer=1 
	AND id IN (SELECT id FROM fantasy.events WHERE amount > 0)
GROUP BY r.race
),
--активности игроков
activity_user AS (
SELECT 
	u.race_id,
	e.id,
	COUNT(e.transaction_id) AS count_tr,
	AVG(e.amount) AS avg_amount,
	SUM(e.amount) AS sum_amont
FROM fantasy.events e
LEFT JOIN fantasy.users u USING(id)
WHERE id IS NOT NULL
	AND amount!=0
GROUP BY e.id, u.race_id
),
--активности игроков с учетом расы
activity_user_race AS (
SELECT 
	r.race AS race,
	--среднее количество покупок на одного игрока
	AVG(au.count_tr) AS avg_count_per,
	--средняя суммарная стоимость всех покупок на одного игрока
	AVG(au.sum_amont) AS avg_sum_per
FROM activity_user AS au
LEFT JOIN fantasy.race r USING (race_id) 
GROUP BY race
)
SELECT 
	ur.race,
	--общее количество зарегистрированных игроков
	ur.count_race_user,
	--количество игроков, которые совершают внутриигровые покупки
	bu.buy_user,
	--их доля от общего количества
	ROUND(bu.buy_user::NUMERIC /ur.count_race_user,2) AS ratio_buy_user,
	--доля платящих игроков от количества игроков, 
	--которые совершили покупки
	ROUND(pru.count_race_payer::NUMERIC/bu.buy_user, 2) AS ratio_buy_payer,
	--среднее количество покупок на одного игрока
	ROUND(aur.avg_count_per::numeric,0) AS avg_count_per,
	--средняя стоимость одной покупки на одного игрока
	ROUND(aur.avg_sum_per::numeric,2)/
		ROUND(aur.avg_count_per::numeric,0) AS avg_amount_per,
	--ROUND(aur.avg_amount_per::numeric,2) AS avg_amount_per,
	--средняя суммарная стоимость всех покупок на одного игрока
	ROUND(aur.avg_sum_per::numeric,2) AS avg_sum_per
FROM user_race AS ur
LEFT JOIN buy_user AS bu USING(race)
LEFT JOIN payer_race_user AS pru USING(race)
LEFT JOIN activity_user_race AS aur USING(race)
ORDER BY ur.count_race_user DESC;

-- Задача 2: Частота покупок
-- Напишите ваш запрос здесь

--Считаем количество покупок на игрока. Выделяем игроков
-- у которых больше 25 покупок и нет нулевых покупок
WITH count_transaction AS (
SELECT 
	id,
	COUNT(transaction_id) AS count_tr
FROM fantasy.events e 
WHERE amount!=0
GROUP BY id
HAVING COUNT(transaction_id)>=25
),
--Подсчитываем количество платящих игроков из первого условия (cte)
payer_id AS (
SELECT 
	ct.id
FROM count_transaction AS ct
LEFT JOIN fantasy.users u USING (id)
WHERE u.payer=1
),
--Считаем интервал меджу покупками на каждого игрока
interval_tr AS (
SELECT 
	ct.id AS id,
	e.transaction_id,
	e.date::date AS date_tr, 
	LAG(e.date,1, e.date) OVER (PARTITION BY ct.id ORDER BY e.date)::date AS prev_date,
	e.date::date
		-LAG(e.date,1, e.date) OVER (PARTITION BY ct.id ORDER BY e.date)::date AS interval_tr
FROM count_transaction AS ct 
LEFT JOIN fantasy.events e USING (id)
ORDER BY ct.id, e.date
),
--сдедний интервал на игрока
avg_interval_tr AS (
SELECT 
	id,
	ROUND(AVG(interval_tr),2) AS avg_interval_user,
	NTILE (3) OVER (ORDER BY ROUND(AVG(interval_tr),2) ) AS num
FROM interval_tr AS it
GROUP BY id
)
--итоговый запрос
SELECT 
	ait.num,
	CASE 
		WHEN ait.num=1 THEN 'высокая частота'
		WHEN ait.num=2 THEN 'умеренная частота'
		WHEN ait.num=3 THEN 'низкая частота'
	END AS group_users,
	--количество игроков в группе
	COUNT(ait.id) AS count_users,
	--количество платящих игроков, совершивших покупки
	COUNT(pi.id) AS count_payer_user,
	--доля платящих игроков от общего количества игроков, совершивших покупку
	ROUND(COUNT(pi.id)::NUMERIC /COUNT(ait.id),2) AS ratio_payer_user,
	--среднее количество покупок на одного игрока
	ROUND(AVG(ct.count_tr),0) AS avg_count_trans_user,
	--среднее количество дней между покупками на одного игрока
	ROUND(AVG(ait.avg_interval_user),1) AS avg_interval
FROM avg_interval_tr AS ait
LEFT JOIN count_transaction AS ct USING (id)
LEFT JOIN payer_id AS pi ON ait.id=pi.id
GROUP BY num, group_users
ORDER BY num;



